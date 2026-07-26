/*═══════════════════════════════════════════════════════════════════════════════
  DP-800 | MIỀN 1 | LAB 04 — PHÂN VÙNG BẢNG (TABLE PARTITIONING)
  Đi kèm: Claude_DP800_D1_Design_Guide.md  (mục 7)

  Đây là lab QUAN TRỌNG NHẤT về mặt "thứ tự thao tác" — đề thi hay ra dạng
  drag-and-drop sắp xếp các bước. Hãy chạy đúng thứ tự và ghi nhớ.
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
IF DB_ID('DP800_Part') IS NOT NULL
BEGIN
    ALTER DATABASE DP800_Part SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DP800_Part;
END;
GO
CREATE DATABASE DP800_Part;
GO
USE DP800_Part;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 1 — BƯỚC 0: FILEGROUP (tùy chọn nhưng là thực hành chuẩn)
  Lợi ích: backup/restore theo filegroup, đặt dữ liệu nóng/lạnh trên đĩa khác nhau,
           đặt filegroup dữ liệu cũ ở chế độ READ_ONLY.
───────────────────────────────────────────────────────────────────────────────*/
DECLARE @dataPath NVARCHAR(400) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(400));
DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql = @sql + N'
ALTER DATABASE DP800_Part ADD FILEGROUP FG' + y + N';
ALTER DATABASE DP800_Part ADD FILE (NAME = N''DP800_' + y + N''',
     FILENAME = N''' + @dataPath + N'DP800_' + y + N'.ndf'', SIZE = 8MB, FILEGROWTH = 8MB)
     TO FILEGROUP FG' + y + N';'
FROM (VALUES ('Old'),('2024'),('2025'),('2026'),('Future')) AS v(y);

EXEC sys.sp_executesql @sql;

SELECT name, type_desc, is_read_only FROM sys.filegroups;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 2 — BƯỚC 1: PARTITION FUNCTION (định nghĩa BIÊN)
───────────────────────────────────────────────────────────────────────────────*/
CREATE PARTITION FUNCTION PF_ByYear (DATE)
AS RANGE RIGHT FOR VALUES ('2024-01-01', '2025-01-01', '2026-01-01');
/*  3 biên ⇒ 4 partition (đánh số từ 1):
      P1: (-vô cực, 2024-01-01)
      P2: [2024-01-01, 2025-01-01)
      P3: [2025-01-01, 2026-01-01)
      P4: [2026-01-01, +vô cực)
    n biên ⇒ n+1 partition. LUÔN nhớ công thức này.                            */

SELECT  pf.name, pf.boundary_value_on_right, rv.boundary_id, rv.value AS BoundaryValue
FROM    sys.partition_functions pf
LEFT JOIN sys.partition_range_values rv ON rv.function_id = pf.function_id
ORDER BY rv.boundary_id;


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 3 — RANGE LEFT vs RANGE RIGHT (bẫy kinh điển)
───────────────────────────────────────────────────────────────────────────────*/
CREATE PARTITION FUNCTION PF_Left (DATE)
AS RANGE LEFT FOR VALUES ('2024-01-01', '2025-01-01', '2026-01-01');

SELECT  TestValue,
        $PARTITION.PF_ByYear(TestValue) AS RangeRIGHT_Partition,
        $PARTITION.PF_Left  (TestValue) AS RangeLEFT_Partition
FROM (VALUES (CAST('2023-12-31' AS DATE)), ('2024-01-01'), ('2024-06-15'),
             ('2024-12-31'), ('2025-01-01'), ('2026-01-01')) AS v(TestValue);
/*  ĐỌC KẾT QUẢ:
      '2025-01-01' → RANGE RIGHT: partition 3 (BÊN PHẢI biên — partition MỚI)
                     RANGE LEFT : partition 2 (BÊN TRÁI biên — partition CŨ)

    QUY TẮC NHỚ: tên nói giá trị BIÊN thuộc về phía nào.
      RANGE LEFT  ⇒ biên thuộc partition bên TRÁI  ⇒ khoảng (a, b]
      RANGE RIGHT ⇒ biên thuộc partition bên PHẢI  ⇒ khoảng [a, b)

    🎯 VỚI DỮ LIỆU NGÀY THÁNG LUÔN DÙNG RANGE RIGHT:
       biên là ngày ĐẦU kỳ (2025-01-01), tránh hoàn toàn vấn đề
       '2024-12-31 23:59:59.997' của RANGE LEFT với kiểu DATETIME.              */
DROP PARTITION FUNCTION PF_Left;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 4 — BƯỚC 2: PARTITION SCHEME (ánh xạ partition → filegroup)
───────────────────────────────────────────────────────────────────────────────*/
CREATE PARTITION SCHEME PS_ByYear
AS PARTITION PF_ByYear TO (FGOld, FG2024, FG2025, FG2026);
/*  Số filegroup phải = số partition (n+1 = 4).
    Muốn tất cả vào PRIMARY: CREATE PARTITION SCHEME ... ALL TO ([PRIMARY]);   */

SELECT  ps.name AS SchemeName, dds.destination_id AS PartitionNumber, fg.name AS FileGroup
FROM    sys.partition_schemes ps
JOIN    sys.destination_data_spaces dds ON dds.partition_scheme_id = ps.data_space_id
JOIN    sys.filegroups fg ON fg.data_space_id = dds.data_space_id
ORDER BY dds.destination_id;


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 5 — BƯỚC 3: TẠO BẢNG TRÊN PARTITION SCHEME
───────────────────────────────────────────────────────────────────────────────*/
CREATE TABLE dbo.FactSales
(
    SaleId      BIGINT IDENTITY(1,1) NOT NULL,
    OrderDate   DATE          NOT NULL,     -- cột phân vùng (partitioning column)
    CustomerId  INT           NOT NULL,
    Amount      DECIMAL(19,4) NOT NULL,
    -- ⚠ Cột phân vùng BẮT BUỘC nằm trong khóa của MỌI unique index / PK
    CONSTRAINT PK_FactSales PRIMARY KEY CLUSTERED (SaleId, OrderDate)
) ON PS_ByYear (OrderDate);
GO
/*  [LỖI CỐ Ý] thử tạo PK không chứa cột phân vùng:
      CONSTRAINT PK PRIMARY KEY CLUSTERED (SaleId)   ⇒ Msg 1908:
      "Column 'OrderDate' is partitioning column of the index 'PK'.
       Partition columns for a unique index must be a subset of the index key."  */

INSERT dbo.FactSales (OrderDate, CustomerId, Amount)
SELECT  DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 1095, CAST('2023-06-01' AS DATE)),
        ABS(CHECKSUM(NEWID())) % 1000,
        ABS(CHECKSUM(NEWID())) % 100000 / 100.0
FROM (SELECT TOP (200000) 1 AS x FROM sys.all_objects a, sys.all_objects b) t;

GO
-- Truy vấn "vàng" để soi phân vùng (thuộc lòng truy vấn này)
-- ⚠ CREATE VIEW/PROC/FUNCTION/TRIGGER phải là câu lệnh ĐẦU TIÊN của batch ⇒ cần GO ở trên.
CREATE OR ALTER VIEW dbo.vPartitionInfo
AS
SELECT  OBJECT_SCHEMA_NAME(p.object_id) + '.' + OBJECT_NAME(p.object_id) AS TableName,
        i.name          AS IndexName,
        p.partition_number,
        fg.name         AS FileGroupName,
        p.rows          AS RowCnt,
        p.data_compression_desc,
        CASE WHEN pf.boundary_value_on_right = 1 THEN 'RANGE RIGHT' ELSE 'RANGE LEFT' END AS RangeType,
        rv.value        AS BoundaryValue
FROM    sys.partitions p
JOIN    sys.indexes i        ON i.object_id = p.object_id AND i.index_id = p.index_id
JOIN    sys.partition_schemes ps ON ps.data_space_id = i.data_space_id
JOIN    sys.partition_functions pf ON pf.function_id = ps.function_id
JOIN    sys.destination_data_spaces dds ON dds.partition_scheme_id = ps.data_space_id
                                       AND dds.destination_id = p.partition_number
JOIN    sys.filegroups fg    ON fg.data_space_id = dds.data_space_id
LEFT JOIN sys.partition_range_values rv ON rv.function_id = pf.function_id
                                       AND rv.boundary_id = p.partition_number
                                            - CASE WHEN pf.boundary_value_on_right = 1 THEN 1 ELSE 0 END
WHERE   i.index_id <= 1;
GO
SELECT * FROM dbo.vPartitionInfo ORDER BY partition_number;


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 6 — PARTITION ELIMINATION (và cách làm HỎNG nó)
───────────────────────────────────────────────────────────────────────────────*/
SET STATISTICS IO ON;

-- ✅ Lọc TRỰC TIẾP trên cột phân vùng ⇒ chỉ đọc 1 partition
SELECT COUNT(*) FROM dbo.FactSales
WHERE OrderDate >= '2025-01-01' AND OrderDate < '2026-01-01';

-- ❌ Bọc hàm quanh cột phân vùng ⇒ đọc TẤT CẢ partition
SELECT COUNT(*) FROM dbo.FactSales WHERE YEAR(OrderDate) = 2025;

SET STATISTICS IO OFF;
/*  Xem trên execution plan, thuộc tính của Clustered Index Scan:
      "Actual Partition Count" và "Actual Partitions Accessed" (vd: 3 vs 1..4).
    Đây là bằng chứng partition elimination có hoạt động hay không.

    ⚠ Elimination cũng hỏng khi: kiểu dữ liệu không khớp gây implicit conversion,
      hoặc dùng biến/tham số mà optimizer không "sniff" được (thêm OPTION(RECOMPILE)). */

-- Đếm số dòng theo partition mà không quét bảng
SELECT  $PARTITION.PF_ByYear(OrderDate) AS PartitionNo,
        MIN(OrderDate) AS MinDate, MAX(OrderDate) AS MaxDate, COUNT(*) AS Rows
FROM    dbo.FactSales
GROUP BY $PARTITION.PF_ByYear(OrderDate)
ORDER BY PartitionNo;


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 7 — ALIGNED vs NON-ALIGNED INDEX (điều kiện để SWITCH được)
───────────────────────────────────────────────────────────────────────────────*/
-- Index ALIGNED: tạo trên CÙNG partition scheme, CÙNG cột phân vùng
CREATE INDEX IX_FactSales_Customer
    ON dbo.FactSales (CustomerId, OrderDate)
    ON PS_ByYear (OrderDate);                     -- ✅ aligned

-- Index NON-ALIGNED: đặt trên filegroup riêng ⇒ sẽ CHẶN thao tác SWITCH
CREATE INDEX IX_FactSales_Amount
    ON dbo.FactSales (Amount)
    ON [PRIMARY];                                 -- ❌ non-aligned

-- Truy vấn kiểm tra alignment
SELECT  i.name AS IndexName,
        CASE WHEN ps.name IS NULL THEN 'NON-ALIGNED (nằm trên ' + ds.name + ')'
             ELSE 'ALIGNED (' + ps.name + ')' END AS Alignment
FROM    sys.indexes i
JOIN    sys.data_spaces ds ON ds.data_space_id = i.data_space_id
LEFT JOIN sys.partition_schemes ps ON ps.data_space_id = i.data_space_id
WHERE   i.object_id = OBJECT_ID('dbo.FactSales') AND i.index_id > 0;

DROP INDEX IX_FactSales_Amount ON dbo.FactSales;   -- gỡ để SWITCH được ở Section 8


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 8 — SLIDING WINDOW: SWITCH OUT (lưu trữ dữ liệu cũ tức thời)
───────────────────────────────────────────────────────────────────────────────*/
/*  Nghiệp vụ: cuối năm, đẩy dữ liệu 2024 (partition 2) ra bảng lưu trữ.
    DELETE 50 triệu dòng = hàng giờ + phình log. SWITCH = < 1 giây, metadata-only. */

-- (1) Bảng staging phải: cùng cấu trúc cột, CÙNG FILEGROUP với partition nguồn
CREATE TABLE dbo.FactSales_Archive
(
    SaleId      BIGINT IDENTITY(1,1) NOT NULL,
    OrderDate   DATE          NOT NULL,
    CustomerId  INT           NOT NULL,
    Amount      DECIMAL(19,4) NOT NULL,
    CONSTRAINT PK_FactSales_Archive PRIMARY KEY CLUSTERED (SaleId, OrderDate)
) ON FG2024;                                  -- ⚠ partition 2 nằm trên FG2024

-- (2) Mọi index của bảng nguồn phải có bản tương ứng ở bảng đích
CREATE INDEX IX_FactSales_Customer ON dbo.FactSales_Archive (CustomerId, OrderDate) ON FG2024;
GO
DECLARE @before BIGINT = (SELECT COUNT(*) FROM dbo.FactSales);

-- (3) SWITCH — thao tác metadata, gần như tức thời
ALTER TABLE dbo.FactSales SWITCH PARTITION 2 TO dbo.FactSales_Archive;

SELECT @before AS RowsBefore,
       (SELECT COUNT(*) FROM dbo.FactSales)         AS RowsAfter,
       (SELECT COUNT(*) FROM dbo.FactSales_Archive) AS RowsMovedToArchive;

SELECT * FROM dbo.vPartitionInfo ORDER BY partition_number;   -- partition 2 giờ = 0 dòng
GO

/*  [LỖI CỐ Ý] thử SWITCH sang bảng KHÁC FILEGROUP */
CREATE TABLE dbo.FactSales_WrongFG
(
    SaleId BIGINT IDENTITY(1,1) NOT NULL, OrderDate DATE NOT NULL,
    CustomerId INT NOT NULL, Amount DECIMAL(19,4) NOT NULL,
    CONSTRAINT PK_Wrong PRIMARY KEY CLUSTERED (SaleId, OrderDate)
) ON [PRIMARY];
GO
BEGIN TRY
    ALTER TABLE dbo.FactSales SWITCH PARTITION 3 TO dbo.FactSales_WrongFG;
END TRY
BEGIN CATCH
    SELECT 'SWITCH sai filegroup' AS Demo, ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS Msg;
END CATCH;
GO
/*  Msg 4904 — "...they are not in the same filegroup."
    5 ĐIỀU KIỆN SWITCH (học thuộc, đề hỏi rất nhiều):
      1. Cùng filegroup.
      2. Cấu trúc cột giống hệt (kiểu, độ dài, nullability, collation, thứ tự).
      3. Mọi index phải ALIGNED và tồn tại ở cả hai bên.
      4. Bảng/partition ĐÍCH phải RỖNG.
      5. Không có FK trỏ TỚI bảng đích; các thuộc tính khác (compression,
         indexed view, replication) phải khớp. Khi switch IN cần CHECK constraint
         giới hạn đúng khoảng giá trị của partition đích.                        */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 9 — SWITCH IN: NẠP DỮ LIỆU MỚI KHÔNG DOWNTIME
───────────────────────────────────────────────────────────────────────────────*/
-- (1) Nạp và xử lý dữ liệu ngoài bảng chính (không ảnh hưởng người dùng)
CREATE TABLE dbo.FactSales_Staging
(
    SaleId      BIGINT IDENTITY(1,1) NOT NULL,
    OrderDate   DATE          NOT NULL,
    CustomerId  INT           NOT NULL,
    Amount      DECIMAL(19,4) NOT NULL,
    CONSTRAINT PK_Staging PRIMARY KEY CLUSTERED (SaleId, OrderDate)
) ON FG2024;

SET IDENTITY_INSERT dbo.FactSales_Staging ON;
INSERT dbo.FactSales_Staging (SaleId, OrderDate, CustomerId, Amount)
SELECT SaleId, OrderDate, CustomerId, Amount FROM dbo.FactSales_Archive;
SET IDENTITY_INSERT dbo.FactSales_Staging OFF;

CREATE INDEX IX_FactSales_Customer ON dbo.FactSales_Staging (CustomerId, OrderDate) ON FG2024;

-- (2) CHECK CONSTRAINT BẮT BUỘC — chứng minh dữ liệu nằm đúng khoảng của partition 2
ALTER TABLE dbo.FactSales_Staging WITH CHECK
    ADD CONSTRAINT CK_Staging_Range
    CHECK (OrderDate >= '2024-01-01' AND OrderDate < '2025-01-01');
/*  ⚠ Phải là WITH CHECK (trusted). Nếu untrusted ⇒ SWITCH thất bại Msg 4982.
    Với RANGE RIGHT dùng >= và < (KHÔNG dùng BETWEEN — BETWEEN gồm cả biên phải). */

-- (3) SWITCH IN
ALTER TABLE dbo.FactSales_Staging SWITCH TO dbo.FactSales PARTITION 2;

SELECT * FROM dbo.vPartitionInfo ORDER BY partition_number;   -- partition 2 có lại dữ liệu
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 10 — SPLIT & MERGE: TRƯỢT CỬA SỔ SANG NĂM MỚI
───────────────────────────────────────────────────────────────────────────────*/
/*  ⚠ QUY TẮC VÀNG: LUÔN SPLIT/MERGE trên partition RỖNG.
    Split partition có dữ liệu ⇒ di chuyển dữ liệu vật lý + khoá bảng + phình log. */

-- (1) NEXT USED trước, SPLIT sau (thiếu bước này ⇒ Msg 7710 warning / lỗi)
ALTER PARTITION SCHEME  PS_ByYear NEXT USED FGFuture;
ALTER PARTITION FUNCTION PF_ByYear() SPLIT RANGE ('2027-01-01');

SELECT * FROM dbo.vPartitionInfo ORDER BY partition_number;   -- giờ có 5 partition

-- (2) Đẩy partition cũ nhất (P1 - dữ liệu trước 2024) ra ngoài rồi MERGE
CREATE TABLE dbo.FactSales_Old
(
    SaleId      BIGINT IDENTITY(1,1) NOT NULL,
    OrderDate   DATE          NOT NULL,
    CustomerId  INT           NOT NULL,
    Amount      DECIMAL(19,4) NOT NULL,
    CONSTRAINT PK_Old PRIMARY KEY CLUSTERED (SaleId, OrderDate)
) ON FGOld;
CREATE INDEX IX_FactSales_Customer ON dbo.FactSales_Old (CustomerId, OrderDate) ON FGOld;

ALTER TABLE dbo.FactSales SWITCH PARTITION 1 TO dbo.FactSales_Old;

-- (3) MERGE biên của partition đã RỖNG
ALTER PARTITION FUNCTION PF_ByYear() MERGE RANGE ('2024-01-01');

SELECT * FROM dbo.vPartitionInfo ORDER BY partition_number;
/*  CHU TRÌNH SLIDING WINDOW ĐẦY ĐỦ (nhớ đúng thứ tự — đề hay hỏi):
      1. ALTER PARTITION SCHEME  ... NEXT USED <filegroup>
      2. ALTER PARTITION FUNCTION ... SPLIT RANGE (<biên mới>)   ← tạo chỗ cho kỳ mới
      3. ALTER TABLE ... SWITCH PARTITION <cũ nhất> TO <archive> ← đẩy dữ liệu cũ ra
      4. ALTER PARTITION FUNCTION ... MERGE RANGE (<biên cũ>)    ← gộp partition rỗng

    ⚠ MERGE RANGE xoá partition ở BÊN TRÁI biên (với RANGE RIGHT) và dữ liệu
      của nó chuyển sang partition kế — nên partition đó phải rỗng.             */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 11 — NÉN & TRUNCATE THEO PARTITION
───────────────────────────────────────────────────────────────────────────────*/
-- Nén khác nhau cho dữ liệu nóng / lạnh trên cùng một bảng
ALTER TABLE dbo.FactSales REBUILD PARTITION = 1
     WITH (DATA_COMPRESSION = PAGE);
ALTER TABLE dbo.FactSales REBUILD PARTITION = ALL
     WITH (DATA_COMPRESSION = PAGE ON PARTITIONS (1, 2));

-- Xoá nhanh nguyên partition (SQL 2016+) — không cần SWITCH, log tối thiểu
TRUNCATE TABLE dbo.FactSales WITH (PARTITIONS (1));

SELECT * FROM dbo.vPartitionInfo ORDER BY partition_number;

-- Đặt filegroup dữ liệu cũ thành chỉ đọc (tiết kiệm backup, chống sửa)
-- ALTER DATABASE DP800_Part MODIFY FILEGROUP FGOld READ_ONLY;

-- REBUILD/REORGANIZE index chỉ trên 1 partition
ALTER INDEX IX_FactSales_Customer ON dbo.FactSales
      REBUILD PARTITION = 3 WITH (ONLINE = ON);
/*  ⚠ ONLINE rebuild ở mức PARTITION chỉ hỗ trợ từ SQL Server 2014+.            */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 12 — PARTITIONED COLUMNSTORE (kết hợp Lab 02)
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS dbo.FactSales_CS_Part;
CREATE TABLE dbo.FactSales_CS_Part
(
    SaleId     BIGINT        NOT NULL,
    OrderDate  DATE          NOT NULL,
    CustomerId INT           NOT NULL,
    Amount     DECIMAL(19,4) NOT NULL
) ON PS_ByYear (OrderDate);

CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactSales_Part
    ON dbo.FactSales_CS_Part ON PS_ByYear (OrderDate);

INSERT dbo.FactSales_CS_Part
SELECT SaleId, OrderDate, CustomerId, Amount FROM dbo.FactSales;

-- Nén archive cho partition dữ liệu lạnh, nén thường cho dữ liệu nóng
ALTER TABLE dbo.FactSales_CS_Part
      REBUILD PARTITION = 2 WITH (DATA_COMPRESSION = COLUMNSTORE_ARCHIVE);

SELECT  p.partition_number, p.rows, p.data_compression_desc,
        SUM(rg.size_in_bytes)/1024 AS SizeKB
FROM    sys.partitions p
LEFT JOIN sys.dm_db_column_store_row_group_physical_stats rg
       ON rg.object_id = p.object_id AND rg.partition_number = p.partition_number
WHERE   p.object_id = OBJECT_ID('dbo.FactSales_CS_Part')
GROUP BY p.partition_number, p.rows, p.data_compression_desc
ORDER BY p.partition_number;
/*  Đây là kiến trúc data warehouse chuẩn của DP-800:
      CCI (nén + batch mode) + PARTITION theo ngày (quản trị vòng đời)
      + COLUMNSTORE_ARCHIVE cho partition lạnh (nén thêm ~30%)
      + SWITCH để nạp/lưu trữ tức thời.                                        */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 13 — GHI NHỚ NHANH
───────────────────────────────────────────────────────────────────────────────*/
/*
  THỨ TỰ TẠO   : FILEGROUP → PARTITION FUNCTION → PARTITION SCHEME → TABLE/INDEX
  THỨ TỰ TRƯỢT : NEXT USED → SPLIT → SWITCH OUT → MERGE
  THỨ TỰ XOÁ   : DROP TABLE → DROP PARTITION SCHEME → DROP PARTITION FUNCTION
                 (không xoá được function khi còn scheme dùng nó)

  SỐ LIỆU CẦN NHỚ
    - n biên ⇒ n+1 partition.
    - Tối đa 15.000 partition/bảng (từ SQL 2012).
    - Cột phân vùng phải nằm trong khóa của mọi unique index/PK.
    - $PARTITION.<Fn>(<giá trị>) cho biết partition số mấy.

  MỤC ĐÍCH CHÍNH CỦA PARTITIONING = QUẢN TRỊ DỮ LIỆU
    (nạp/lưu trữ/bảo trì/nén theo vùng), KHÔNG phải để tăng tốc OLTP.
    Nếu đề đưa đáp án "partition để tăng tốc truy vấn OLTP" ⇒ thường là mồi nhử.
    Lợi ích hiệu năng thực sự chỉ đến từ partition elimination trên truy vấn quét lớn.

  PHÂN BIỆT VỚI PARTITIONED VIEW (kiến thức cũ nhưng vẫn hỏi)
    Partitioned view = UNION ALL nhiều bảng + CHECK constraint phân biệt.
    Dùng khi cần trải dữ liệu qua nhiều SERVER (distributed partitioned view)
    hoặc bản Standard cũ. Nay ưu tiên partitioned table.
*/


/*───────────────────────────────────────────────────────────────────────────────
  DỌN DẸP
───────────────────────────────────────────────────────────────────────────────*/
-- USE master; ALTER DATABASE DP800_Part SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
-- DROP DATABASE DP800_Part;

/*═══════════════════════════════════════════════════════════════════════════════
  CHECKLIST SAU LAB 04
  □ Đọc một PARTITION FUNCTION và nói ngay có bao nhiêu partition, biên nào ở đâu.
  □ Xác định đúng partition của một giá trị với RANGE LEFT và RANGE RIGHT.
  □ Liệt kê 5 điều kiện để SWITCH thành công.
  □ Viết đúng thứ tự 4 bước sliding window.
  □ Giải thích vì sao phải SPLIT/MERGE trên partition rỗng.
  □ Biết cách kiểm tra index có aligned hay không.
  □ Nêu lý do partition elimination không hoạt động.
═══════════════════════════════════════════════════════════════════════════════*/
