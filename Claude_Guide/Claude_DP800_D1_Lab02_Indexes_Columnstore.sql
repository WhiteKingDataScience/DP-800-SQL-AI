/*═══════════════════════════════════════════════════════════════════════════════
  DP-800 | MIỀN 1 | LAB 02 — CHỈ MỤC ROWSTORE & COLUMNSTORE
  Đi kèm: Claude_DP800_D1_Design_Guide.md  (mục 3 và 4)

  PHẦN A — Rowstore B-Tree (Section 1..7)
  PHẦN B — Columnstore     (Section 8..13)

  MẸO: bật "Include Actual Execution Plan" (Ctrl+M trong SSMS) trước khi chạy.
       Nhiều bài học chỉ thấy được trên execution plan, không thấy ở kết quả.
═══════════════════════════════════════════════════════════════════════════════*/

SET NOCOUNT ON;
-- Bắt buộc cho filtered index / index trên computed column / indexed view.
-- SSMS mặc định đã ON; sqlcmd, osql, một số driver thì OFF ⇒ luôn khai báo tường minh.
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET ANSI_WARNINGS ON;
SET ANSI_PADDING ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO
IF DB_ID('DP800_Lab') IS NULL CREATE DATABASE DP800_Lab;
GO
USE DP800_Lab;
GO
IF SCHEMA_ID('Sales') IS NULL EXEC('CREATE SCHEMA Sales');
GO

/*═══════════════════ PHẦN A — ROWSTORE ═══════════════════════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 1 — DỰNG DỮ LIỆU MẪU (~500.000 dòng)
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS Sales.OrderHeader;
CREATE TABLE Sales.OrderHeader
(
    OrderId     INT IDENTITY(1,1) NOT NULL,
    CustomerId  INT           NOT NULL,
    OrderDate   DATE          NOT NULL,
    Status      TINYINT       NOT NULL,     -- 1=New 2=Paid 3=Shipped 4=Cancelled
    TotalAmount DECIMAL(19,4) NOT NULL,
    Notes       NVARCHAR(200) NULL,
    CONSTRAINT PK_OrderHeader PRIMARY KEY CLUSTERED (OrderId)
);

INSERT Sales.OrderHeader (CustomerId, OrderDate, Status, TotalAmount, Notes)
SELECT TOP (500000)
       ABS(CHECKSUM(NEWID())) % 20000 + 1,
       DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 1460), CAST('2026-01-01' AS DATE)),
       CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 97 THEN 3 ELSE 4 END,  -- 3% Cancelled
       ABS(CHECKSUM(NEWID())) % 500000 / 100.0,
       N'note'
FROM   sys.all_objects a CROSS JOIN sys.all_objects b CROSS JOIN sys.all_objects c;

UPDATE STATISTICS Sales.OrderHeader WITH FULLSCAN;
SELECT COUNT(*) AS RowsLoaded FROM Sales.OrderHeader;


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 2 — KEY COLUMN vs INCLUDED COLUMN & "COVERING INDEX"
───────────────────────────────────────────────────────────────────────────────*/
SET STATISTICS IO ON;

-- (a) Chưa có index phụ ⇒ Clustered Index SCAN toàn bảng
SELECT CustomerId, OrderDate, TotalAmount
FROM   Sales.OrderHeader
WHERE  CustomerId = 12345;

-- (b) Index chỉ có key ⇒ Seek + KEY LOOKUP (phải quay về CI lấy cột thiếu)
CREATE INDEX IX_OH_Customer ON Sales.OrderHeader(CustomerId);
SELECT CustomerId, OrderDate, TotalAmount
FROM   Sales.OrderHeader
WHERE  CustomerId = 12345;
--     → Plan: Index Seek + Key Lookup + Nested Loops

-- (c) Thêm INCLUDE ⇒ covering index, mất hẳn Key Lookup, logical reads giảm mạnh
CREATE INDEX IX_OH_Customer_Covering
    ON Sales.OrderHeader(CustomerId)
    INCLUDE (OrderDate, TotalAmount);
SELECT CustomerId, OrderDate, TotalAmount
FROM   Sales.OrderHeader
WHERE  CustomerId = 12345;
--     → Plan: Index Seek duy nhất

SET STATISTICS IO OFF;
/*  QUY TẮC THI:
    - KEY column   : dùng để TÌM (WHERE, JOIN), SẮP XẾP (ORDER BY, GROUP BY).
      Có mặt ở mọi tầng của B-Tree ⇒ tốn chỗ, giới hạn 32 cột / 1700 bytes.
    - INCLUDE column: chỉ nằm ở tầng LEAF, chỉ để "che phủ" (covering) SELECT list.
      Không giới hạn kiểu (kể cả nvarchar(max)), không tính vào 1700 bytes.
    Cột chỉ xuất hiện ở SELECT ⇒ INCLUDE. Cột ở WHERE/JOIN/ORDER BY ⇒ KEY.        */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 3 — THỨ TỰ CỘT KHÓA: EQUALITY TRƯỚC, RANGE SAU
───────────────────────────────────────────────────────────────────────────────*/
DROP INDEX IF EXISTS IX_Bad  ON Sales.OrderHeader;
DROP INDEX IF EXISTS IX_Good ON Sales.OrderHeader;

CREATE INDEX IX_Bad  ON Sales.OrderHeader(OrderDate, CustomerId);  -- range trước
CREATE INDEX IX_Good ON Sales.OrderHeader(CustomerId, OrderDate);  -- equality trước

SET STATISTICS IO ON;
SELECT OrderId FROM Sales.OrderHeader WITH (INDEX(IX_Bad))
WHERE  CustomerId = 500 AND OrderDate >= '2025-01-01';

SELECT OrderId FROM Sales.OrderHeader WITH (INDEX(IX_Good))
WHERE  CustomerId = 500 AND OrderDate >= '2025-01-01';
SET STATISTICS IO OFF;
/*  IX_Good đọc ít trang hơn hẳn: seek trực tiếp tới CustomerId=500 rồi
    quét một dải liên tục theo OrderDate.
    IX_Bad phải quét cả dải ngày rồi mới lọc CustomerId (residual predicate).
    → Đề thi: "sắp xếp thứ tự cột trong index" ⇒ Equality → Range → (Include).   */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 4 — SARGABLE: ĐỪNG BỌC HÀM QUANH CỘT
───────────────────────────────────────────────────────────────────────────────*/
SET STATISTICS IO ON;
-- ❌ NON-SARGABLE: hàm bọc quanh cột ⇒ index scan
SELECT COUNT(*) FROM Sales.OrderHeader WHERE YEAR(OrderDate) = 2025;

-- ✅ SARGABLE: viết lại thành dải giá trị ⇒ index seek
SELECT COUNT(*) FROM Sales.OrderHeader
WHERE OrderDate >= '2025-01-01' AND OrderDate < '2026-01-01';
SET STATISTICS IO OFF;
/*  Các dạng non-sargable kinh điển cần nhận diện trong đề:
      WHERE YEAR(col) = ...        WHERE CONVERT(varchar,col) = ...
      WHERE col + 0 = ...          WHERE ISNULL(col,0) = ...
      WHERE col LIKE '%abc'        (wildcard ở đầu)
      WHERE col <> ...             (thường buộc scan)
    Ngoại lệ hữu ích: nếu bắt buộc phải dùng hàm ⇒ tạo COMPUTED COLUMN PERSISTED
    trên chính biểu thức đó rồi đánh index lên nó.                              */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 5 — FILTERED INDEX
───────────────────────────────────────────────────────────────────────────────*/
CREATE INDEX IX_OH_Cancelled
    ON Sales.OrderHeader(OrderDate, CustomerId)
    WHERE Status = 4;                          -- chỉ ~3% số dòng

SELECT  i.name, ps.row_count, ps.used_page_count * 8 AS SizeKB
FROM    sys.indexes i
JOIN    sys.dm_db_partition_stats ps ON ps.object_id = i.object_id AND ps.index_id = i.index_id
WHERE   i.object_id = OBJECT_ID('Sales.OrderHeader')
ORDER BY SizeKB DESC;
/*  Index nhỏ hơn ~30 lần, thống kê chính xác hơn cho tập con.
    ⚠ ĐIỀU KIỆN ĐỂ OPTIMIZER DÙNG ĐƯỢC FILTERED INDEX:
      - Vị từ trong WHERE của truy vấn phải BAO HÀM vị từ của index.
      - Phiên phải có SET ANSI_NULLS ON, QUOTED_IDENTIFIER ON.
      - Tham số hoá (@Status) thường KHÔNG khớp được ⇒ thêm OPTION (RECOMPILE).
    ⚠ Filtered index KHÔNG hỗ trợ: cột computed, biểu thức phức tạp trong
      WHERE (không dùng được LIKE, hàm), và không tạo được trên view.           */

-- Chứng minh vấn đề tham số hoá:
DECLARE @st TINYINT = 4;
SELECT COUNT(*) FROM Sales.OrderHeader WHERE Status = @st;                      -- không dùng filtered index
SELECT COUNT(*) FROM Sales.OrderHeader WHERE Status = @st OPTION (RECOMPILE);   -- dùng được
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 6 — PHÂN MẢNH & BẢO TRÌ: REORGANIZE vs REBUILD
───────────────────────────────────────────────────────────────────────────────*/
UPDATE Sales.OrderHeader SET Notes = REPLICATE(N'x', 200)
WHERE OrderId % 3 = 0;      -- tạo page split ⇒ phân mảnh

SELECT  i.name, ips.avg_fragmentation_in_percent AS FragPct, ips.page_count
FROM    sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('Sales.OrderHeader'), NULL, NULL, 'LIMITED') ips
JOIN    sys.indexes i ON i.object_id = ips.object_id AND i.index_id = ips.index_id
WHERE   ips.page_count > 100;

/*  NGƯỠNG CHUẨN CỦA MICROSOFT (rất hay ra đề):
      5%  < frag <= 30%  ⇒ REORGANIZE  (luôn ONLINE, có thể dừng giữa chừng,
                                        không cập nhật statistics)
      frag > 30%         ⇒ REBUILD     (tạo lại index, CẬP NHẬT statistics FULLSCAN)
      page_count < 1000  ⇒ BỎ QUA
    REORGANIZE cũng nén LOB (LOB_COMPACTION), REBUILD thì không tự động.        */

ALTER INDEX IX_OH_Customer_Covering ON Sales.OrderHeader REORGANIZE;

-- REBUILD không downtime + có thể tạm dừng (Enterprise/Developer/Azure SQL)
ALTER INDEX PK_OrderHeader ON Sales.OrderHeader
REBUILD WITH (ONLINE = ON, RESUMABLE = ON, MAXDOP = 2, FILLFACTOR = 90,
              DATA_COMPRESSION = PAGE);
/*  ONLINE = ON      : không chặn đọc/ghi (SQL 2019+ hỗ trợ cả clustered CS index).
    RESUMABLE = ON   : ALTER INDEX ... PAUSE / RESUME / ABORT — sống sót qua failover.
    WAIT_AT_LOW_PRIORITY : tránh khoá dài khi chuyển pha SCH-M.
    FILLFACTOR       : chừa chỗ trống trong page để giảm page split (chỉ áp dụng
                       lúc rebuild/create, KHÔNG duy trì tự động sau đó).       */

SELECT name, state_desc, percent_complete
FROM sys.index_resumable_operations;    -- theo dõi khi có thao tác resumable

-- Rà index không dùng / thiếu index (kỹ năng thực chiến, hay hỏi khái niệm)
SELECT  OBJECT_NAME(s.object_id) AS TableName, i.name AS IndexName,
        s.user_seeks, s.user_scans, s.user_lookups, s.user_updates
FROM    sys.dm_db_index_usage_stats s
JOIN    sys.indexes i ON i.object_id = s.object_id AND i.index_id = s.index_id
WHERE   s.database_id = DB_ID() AND i.object_id = OBJECT_ID('Sales.OrderHeader')
ORDER BY s.user_updates DESC;
/*  user_seeks + user_scans + user_lookups = 0 nhưng user_updates lớn
    ⇒ index chỉ tốn chi phí ghi, ứng viên để DROP.                              */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 7 — CHỐNG NGHẼN CHÈN "LAST PAGE" (PAGELATCH_EX)
───────────────────────────────────────────────────────────────────────────────*/
/*  Bảng có clustered key TĂNG DẦN (IDENTITY, datetime) + nhiều phiên chèn song song
    ⇒ tất cả cùng tranh trang cuối ⇒ chờ PAGELATCH_EX ("hot page" / last-page insert
    contention). Giải pháp DP-800 mong đợi:                                      */
-- ⚠ OPTIMIZE_FOR_SEQUENTIAL_KEY là tuỳ chọn của CREATE INDEX và ALTER INDEX ... SET,
--   KHÔNG dùng được trong ALTER INDEX ... REBUILD WITH (...) ⇒ Msg 155.
ALTER INDEX PK_OrderHeader ON Sales.OrderHeader
SET (OPTIMIZE_FOR_SEQUENTIAL_KEY = ON);            -- SQL 2019+, đáp án ưu tiên
/*  Các phương án khác (biết để loại trừ): đảo cột khóa/hash key, dùng
    memory-optimized table, hoặc partition theo hash.                            */


/*═══════════════════ PHẦN B — COLUMNSTORE ════════════════════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 8 — CLUSTERED COLUMNSTORE INDEX (CCI) CHO BẢNG FACT
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS Sales.FactSales_RS, Sales.FactSales_CS;

-- ⚠ SELECT ... INTO KẾ THỪA thuộc tính IDENTITY của cột nguồn. Dùng biểu thức
--   (OrderId + 0) để bảng đích thành cột thường, nếu không mọi INSERT tường minh
--   vào cột đó sẽ báo Msg 544.
-- Bản rowstore để so sánh
SELECT OrderId + 0 AS OrderId, CustomerId, OrderDate, Status, TotalAmount
INTO   Sales.FactSales_RS
FROM   Sales.OrderHeader;
CREATE CLUSTERED INDEX CIX_RS ON Sales.FactSales_RS(OrderDate);

-- Bản columnstore
SELECT OrderId + 0 AS OrderId, CustomerId, OrderDate, Status, TotalAmount
INTO   Sales.FactSales_CS
FROM   Sales.OrderHeader;
CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactSales ON Sales.FactSales_CS;

-- So sánh dung lượng
SELECT  OBJECT_NAME(object_id) AS TableName,
        SUM(used_page_count) * 8 / 1024.0 AS SizeMB,
        SUM(row_count) AS Rows
FROM    sys.dm_db_partition_stats
WHERE   object_id IN (OBJECT_ID('Sales.FactSales_RS'), OBJECT_ID('Sales.FactSales_CS'))
  AND   index_id < 2
GROUP BY object_id;

-- So sánh truy vấn tổng hợp
SET STATISTICS IO, TIME ON;
SELECT Status, COUNT_BIG(*) AS Cnt, SUM(TotalAmount) AS Total
FROM   Sales.FactSales_RS GROUP BY Status;

SELECT Status, COUNT_BIG(*) AS Cnt, SUM(TotalAmount) AS Total
FROM   Sales.FactSales_CS GROUP BY Status;
SET STATISTICS IO, TIME OFF;
/*  Quan sát trên plan của bản CS:
      - "Columnstore Index Scan"  với Storage = ColumnStore
      - Actual Execution Mode = BATCH (xử lý 900 dòng/lần thay vì từng dòng)
      - Segment elimination: chỉ đọc các segment liên quan
    Nén thường 5–10×, truy vấn tổng hợp nhanh hàng chục lần.                     */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 9 — SOI ROWGROUP & DELTA STORE (kiến thức lõi của đề)
───────────────────────────────────────────────────────────────────────────────*/
SELECT  rg.row_group_id, rg.state_desc, rg.total_rows, rg.deleted_rows,
        rg.size_in_bytes / 1024 AS SizeKB, rg.trim_reason_desc
FROM    sys.dm_db_column_store_row_group_physical_stats rg
WHERE   rg.object_id = OBJECT_ID('Sales.FactSales_CS')
ORDER BY rg.row_group_id;
/*  state_desc:
      OPEN        = delta store đang nhận dòng (lưu dạng ROWSTORE B-Tree!)
      CLOSED      = đã đủ 1.048.576 dòng, chờ Tuple Mover nén
      COMPRESSED  = đã nén thành column segment ⇒ mới có lợi ích columnstore
      TOMBSTONE   = rowgroup rỗng chờ dọn
    trim_reason_desc: vì sao rowgroup < 1.048.576 dòng (BULKLOAD, MEMORY_LIMITATION,
      DICTIONARY_SIZE, SPILLOVER...) — rowgroup quá nhỏ ⇒ mất hiệu năng.        */

-- Chèn nhỏ giọt ⇒ rơi vào DELTA STORE (OPEN), không được nén
INSERT Sales.FactSales_CS (OrderId, CustomerId, OrderDate, Status, TotalAmount)
SELECT TOP (1000) OrderId + 9000000, CustomerId, OrderDate, Status, TotalAmount
FROM   Sales.OrderHeader;

SELECT row_group_id, state_desc, total_rows
FROM   sys.dm_db_column_store_row_group_physical_stats
WHERE  object_id = OBJECT_ID('Sales.FactSales_CS') AND state_desc <> 'COMPRESSED';
/*  ⚠ NGƯỠNG VÀNG 102.400: bulk load ≥ 102.400 dòng/batch sẽ ghi THẲNG vào
    rowgroup nén, bỏ qua delta store. Dưới ngưỡng đó ⇒ vào delta store (rowstore).
    Đây là đáp án cho câu "vì sao nạp dữ liệu vào CCI mà không thấy nén".        */

-- Ép Tuple Mover chạy ngay:
ALTER INDEX CCI_FactSales ON Sales.FactSales_CS REORGANIZE
     WITH (COMPRESS_ALL_ROW_GROUPS = ON);

SELECT row_group_id, state_desc, total_rows, deleted_rows
FROM   sys.dm_db_column_store_row_group_physical_stats
WHERE  object_id = OBJECT_ID('Sales.FactSales_CS')
ORDER BY row_group_id;


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 10 — UPDATE/DELETE TRÊN COLUMNSTORE VÀ "DELETE BITMAP"
───────────────────────────────────────────────────────────────────────────────*/
DELETE Sales.FactSales_CS WHERE Status = 4;

SELECT  SUM(total_rows) AS TotalRows, SUM(deleted_rows) AS DeletedRows,
        CAST(100.0 * SUM(deleted_rows) / NULLIF(SUM(total_rows),0) AS DECIMAL(5,2)) AS DeletedPct
FROM    sys.dm_db_column_store_row_group_physical_stats
WHERE   object_id = OBJECT_ID('Sales.FactSales_CS');
/*  DELETE trên rowgroup đã nén KHÔNG xóa vật lý — chỉ đánh dấu vào delete bitmap.
    UPDATE = DELETE (bitmap) + INSERT (delta store) ⇒ tệ đôi.
    Khi deleted_rows nhiều (>10–20%) ⇒ REORGANIZE để dọn, hoặc REBUILD.
    ⇒ Bài học thi: columnstore dành cho INSERT hàng loạt + đọc, KHÔNG dành cho
      workload cập nhật từng dòng liên tục.                                     */
ALTER INDEX CCI_FactSales ON Sales.FactSales_CS REORGANIZE;


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 11 — NONCLUSTERED COLUMNSTORE (NCCI): HTAP / REAL-TIME OPERATIONAL ANALYTICS
───────────────────────────────────────────────────────────────────────────────*/
/*  Tình huống đề thi kinh điển:
    "Bảng OLTP đang ghi liên tục. Cần báo cáo tổng hợp REAL-TIME mà không ảnh
     hưởng hiệu năng ghi và không được sao chép dữ liệu sang hệ thống khác."
    ⇒ Đáp án: NONCLUSTERED COLUMNSTORE INDEX (giữ nguyên clustered rowstore).    */

CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_OrderHeader
    ON Sales.OrderHeader (CustomerId, OrderDate, Status, TotalAmount)
    WHERE Status = 3;                       -- filtered NCCI: chỉ index dữ liệu "nguội"
/*  Filtered NCCI (SQL 2016+) là mẹo giảm chi phí ghi: dữ liệu "nóng" đang được
    sửa liên tục (Status mới) không nằm trong columnstore.                       */

SET STATISTICS IO ON;
SELECT CustomerId, SUM(TotalAmount) AS Total
FROM   Sales.OrderHeader
WHERE  Status = 3
GROUP  BY CustomerId
HAVING SUM(TotalAmount) > 100000;
SET STATISTICS IO OFF;
/*  Plan dùng "Columnstore Index Scan (NonClustered)" + Batch Mode
    trong khi bảng vẫn là rowstore, vẫn seek nhanh theo PK cho OLTP.
    ⚠ NCCI làm CHẬM ghi (mỗi insert/update phải bảo trì thêm cấu trúc CS).       */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 12 — ORDERED CLUSTERED COLUMNSTORE (SQL Server 2022+)
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS Sales.FactSales_Ordered;
SELECT OrderId + 0 AS OrderId, CustomerId, OrderDate, Status, TotalAmount
INTO   Sales.FactSales_Ordered FROM Sales.OrderHeader;

-- ⚠ ORDER (...) chỉ có từ SQL Server 2022 (v16). Trên SQL 2019 sẽ báo Msg 156.
IF CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) >= 16
    EXEC(N'CREATE CLUSTERED COLUMNSTORE INDEX CCI_Ordered
               ON Sales.FactSales_Ordered ORDER (OrderDate);');
ELSE
BEGIN
    PRINT 'SQL Server < 2022: tạo CCI thường (không ORDER). Đọc phần chú thích bên dưới.';
    EXEC(N'CREATE CLUSTERED COLUMNSTORE INDEX CCI_Ordered ON Sales.FactSales_Ordered;');
END;

-- Xem min/max của từng segment ⇒ chứng minh segment elimination hiệu quả hơn
SELECT  p.partition_number, s.segment_id, s.row_count,
        s.min_data_id, s.max_data_id
FROM    sys.column_store_segments s
JOIN    sys.partitions p ON p.partition_id = s.partition_id
JOIN    sys.columns c ON c.object_id = p.object_id AND c.column_id = s.column_id + 1
WHERE   p.object_id = OBJECT_ID('Sales.FactSales_Ordered') AND c.name = 'OrderDate'
ORDER BY s.segment_id;

SET STATISTICS IO ON;
SELECT COUNT_BIG(*) FROM Sales.FactSales_Ordered
WHERE  OrderDate BETWEEN '2025-06-01' AND '2025-06-30';
SET STATISTICS IO OFF;
/*  Với ORDER (OrderDate), các segment không chồng lấn ⇒ optimizer bỏ qua
    hầu hết rowgroup ("segment eliminated" trong plan / STATISTICS IO).
    ⚠ ORDER dùng sắp xếp TEMPDB, tốn kém khi tạo; thứ tự chỉ "gần đúng" và
      suy giảm dần khi nạp thêm ⇒ cần rebuild định kỳ.
    ⚠ Chỉ nên ORDER theo cột hay bị lọc theo dải (thường là cột ngày).           */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 13 — BẢNG QUYẾT ĐỊNH: CHỌN CẤU TRÚC NÀO?
───────────────────────────────────────────────────────────────────────────────*/
/*
 ┌──────────────────────────────────────────────┬──────────────────────────────┐
 │ Tình huống                                   │ Chọn                         │
 ├──────────────────────────────────────────────┼──────────────────────────────┤
 │ Tra cứu 1 dòng theo khóa, OLTP               │ Clustered rowstore + NCI     │
 │ Fact table > 1 triệu dòng, quét/tổng hợp     │ Clustered Columnstore (CCI)  │
 │ OLTP đang ghi + cần báo cáo real-time (HTAP) │ Nonclustered CS (NCCI)       │
 │ Chỉ phân tích dữ liệu đã "nguội"             │ Filtered NCCI                │
 │ CCI + hay lọc theo dải ngày                  │ ORDERED CCI (2022+)          │
 │ Bảng < ~100.000 dòng                         │ KHÔNG dùng columnstore       │
 │ Nhiều UPDATE/DELETE lẻ tẻ                    │ KHÔNG dùng columnstore       │
 │ Cần ép UNIQUE / PK                           │ Rowstore (CS không hỗ trợ)   │
 │ Truy vấn luôn trả về ít cột trên bảng rộng   │ Columnstore rất lợi          │
 └──────────────────────────────────────────────┴──────────────────────────────┘

 GIỚI HẠN CỦA COLUMNSTORE CẦN NHỚ:
   - Không hỗ trợ: PRIMARY KEY/UNIQUE/FOREIGN KEY trên chính CCI, sparse column,
     kiểu XML/CLR/(n)varchar(max) là cột key hiệu quả kém.
   - Không dùng được COLUMNSTORE_ARCHIVE cho dữ liệu truy vấn thường xuyên.
   - Rowgroup lý tưởng: 1.048.576 dòng. Ngưỡng bulk-load thẳng: 102.400 dòng.
   - Batch mode yêu cầu compatibility level ≥ 130 (SQL 2016); SQL 2019+ có
     "Batch Mode on Rowstore" nên rowstore cũng có thể chạy batch mode.
*/


/*───────────────────────────────────────────────────────────────────────────────
  DỌN DẸP
───────────────────────────────────────────────────────────────────────────────*/
-- DROP TABLE IF EXISTS Sales.FactSales_RS, Sales.FactSales_CS, Sales.FactSales_Ordered;

/*═══════════════════════════════════════════════════════════════════════════════
  CHECKLIST SAU LAB 02
  □ Phân biệt được KEY vs INCLUDE và biết khi nào dùng cái nào.
  □ Nêu quy tắc thứ tự cột khóa (equality → range).
  □ Nhận diện 5 dạng viết non-sargable.
  □ Nhớ ngưỡng bảo trì 5% / 30% / 1000 pages.
  □ Giải thích delta store, ngưỡng 102.400, ý nghĩa từng state_desc.
  □ Nói ngay được CCI vs NCCI trong tình huống HTAP.
  □ Biết ORDERED CCI giải quyết bài toán gì.
═══════════════════════════════════════════════════════════════════════════════*/
