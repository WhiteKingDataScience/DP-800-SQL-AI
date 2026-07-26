/*═══════════════════════════════════════════════════════════════════════════════
  DP-800 | MIỀN 2 | LAB 04 — TỐI ƯU HIỆU NĂNG
  Đi kèm: Claude_DP800_D2_SecurityPerfDeploy_Guide.md  (mục 7)

  PHẦN A — Query Store, plan forcing, statistics, parameter sniffing  (S1..S6)
  PHẦN B — Wait stats, isolation level & RCSI, tempdb, cấu hình       (S7..S11)

  MẸO: bật "Include Actual Execution Plan" (Ctrl+M) trong SSMS.
═══════════════════════════════════════════════════════════════════════════════*/

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
IF DB_ID('DP800_Perf') IS NOT NULL
BEGIN
    ALTER DATABASE DP800_Perf SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DP800_Perf;
END;
GO
CREATE DATABASE DP800_Perf;
GO
USE DP800_Perf;
GO

/*  Dữ liệu LỆCH nặng — điều kiện tiên quyết để thấy parameter sniffing:
    Region 1 chiếm ~97% số dòng, Region 2..50 rất ít.                            */
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) PRIMARY KEY,
    RegionId   INT           NOT NULL,
    CustomerId INT           NOT NULL,
    OrderDate  DATE          NOT NULL,
    Amount     DECIMAL(19,4) NOT NULL,
    Filler     CHAR(100)     NOT NULL DEFAULT 'x'
);
GO
INSERT dbo.Orders (RegionId, CustomerId, OrderDate, Amount)
SELECT TOP (400000)
       CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 97
            THEN 1                                        -- 97% dồn vào Region 1
            ELSE (ABS(CHECKSUM(NEWID())) % 49) + 2 END,
       ABS(CHECKSUM(NEWID())) % 5000 + 1,
       DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 1095), CAST('2026-07-01' AS DATE)),
       ABS(CHECKSUM(NEWID())) % 1000000 / 100.0
FROM   sys.all_objects a CROSS JOIN sys.all_objects b CROSS JOIN sys.all_objects c;

CREATE INDEX IX_Orders_RegionId ON dbo.Orders(RegionId);
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
SELECT RegionId, COUNT(*) AS Cnt FROM dbo.Orders
GROUP BY RegionId ORDER BY Cnt DESC OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;
GO


/*═══════════════════ PHẦN A — QUERY STORE & PLAN ═════════════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 1 — BẬT & CẤU HÌNH QUERY STORE
───────────────────────────────────────────────────────────────────────────────*/
ALTER DATABASE DP800_Perf SET QUERY_STORE = ON;
GO
ALTER DATABASE DP800_Perf SET QUERY_STORE
(
    OPERATION_MODE              = READ_WRITE,   -- READ_WRITE | READ_ONLY | OFF
    QUERY_CAPTURE_MODE          = ALL,          -- ALL | AUTO (mặc định 2019+) | NONE | CUSTOM
    MAX_STORAGE_SIZE_MB         = 500,
    DATA_FLUSH_INTERVAL_SECONDS = 60,
    INTERVAL_LENGTH_MINUTES     = 1,            -- để lab thấy dữ liệu nhanh; production dùng 60
    SIZE_BASED_CLEANUP_MODE     = AUTO,
    -- ⚠ STALE_QUERY_THRESHOLD_DAYS phải nằm TRONG CLEANUP_POLICY, không đặt trực tiếp
    CLEANUP_POLICY              = (STALE_QUERY_THRESHOLD_DAYS = 30),
    MAX_PLANS_PER_QUERY         = 200
);
GO
SELECT  actual_state_desc, desired_state_desc, readonly_reason,
        current_storage_size_mb, max_storage_size_mb,
        query_capture_mode_desc, interval_length_minutes
FROM    sys.database_query_store_options;
GO
/*  ĐIỂM THI VỀ QUERY STORE:
      - Bật MẶC ĐỊNH trên Azure SQL và SQL Server 2022+ (DB mới).
      - Dữ liệu nằm TRONG database ⇒ sống sót qua restart (khác plan cache) và
        đi theo backup/restore.
      - actual_state có thể tự chuyển sang READ_ONLY khi ĐẦY (readonly_reason ≠ 0)
        ⇒ triệu chứng "Query Store ngừng thu thập" ⇒ tăng MAX_STORAGE_SIZE_MB
        hoặc bật SIZE_BASED_CLEANUP_MODE = AUTO.
      - QUERY_CAPTURE_MODE = AUTO bỏ qua truy vấn không đáng kể (rẻ hơn ALL).    */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 2 — PARAMETER SNIFFING: tái hiện vấn đề kinh điển
───────────────────────────────────────────────────────────────────────────────*/
CREATE OR ALTER PROCEDURE dbo.usp_OrdersByRegion @RegionId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT OrderId, CustomerId, OrderDate, Amount
    FROM   dbo.Orders
    WHERE  RegionId = @RegionId;
END;
GO

-- Lần chạy ĐẦU TIÊN quyết định plan được cache cho MỌI lần sau
DBCC FREEPROCCACHE WITH NO_INFOMSGS;
SET STATISTICS IO ON;

PRINT '=== Biên dịch với @RegionId = 5 (ít dòng) → plan SEEK + Key Lookup ===';
EXEC dbo.usp_OrdersByRegion @RegionId = 5;

PRINT '=== Dùng LẠI plan đó cho @RegionId = 1 (388.000 dòng) → THẢM HOẠ ===';
EXEC dbo.usp_OrdersByRegion @RegionId = 1;   -- hàng trăm nghìn key lookup

SET STATISTICS IO OFF;
GO

DBCC FREEPROCCACHE WITH NO_INFOMSGS;
SET STATISTICS IO ON;

PRINT '=== Biên dịch với @RegionId = 1 trước → plan SCAN ===';
EXEC dbo.usp_OrdersByRegion @RegionId = 1;

PRINT '=== Dùng lại plan SCAN cho @RegionId = 5 → lãng phí nhưng không thảm hoạ ===';
EXEC dbo.usp_OrdersByRegion @RegionId = 5;

SET STATISTICS IO OFF;
GO
/*  🎯 TRIỆU CHỨNG TRONG ĐỀ THI:
      "Cùng một stored procedure, có lúc chạy 50ms có lúc 30 giây, không theo quy luật
       rõ ràng; restart server hoặc rebuild index thì tự hết một thời gian."
      ⇒ PARAMETER SNIFFING.                                                      */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 3 — 5 CÁCH XỬ LÝ PARAMETER SNIFFING (theo thứ tự ưu tiên)
───────────────────────────────────────────────────────────────────────────────*/
-- CÁCH 1 (2022+, TỐT NHẤT): Parameter Sensitive Plan optimization — TỰ ĐỘNG
--         Chỉ cần compatibility level 160; engine giữ NHIỀU plan cho các "dải" giá trị.
IF CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) >= 16
BEGIN
    EXEC(N'ALTER DATABASE DP800_Perf SET COMPATIBILITY_LEVEL = 160');
    PRINT 'Đã bật compat 160 ⇒ PSP optimization hoạt động (không cần sửa code).';
END
ELSE
    PRINT 'SQL Server < 2022: chưa có PSP optimization. Dùng cách 2-5 bên dưới.';
GO

-- CÁCH 2: OPTION (RECOMPILE) — plan tối ưu mỗi lần, đổi lại tốn CPU biên dịch
CREATE OR ALTER PROCEDURE dbo.usp_OrdersByRegion_Recompile @RegionId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT OrderId, CustomerId, Amount FROM dbo.Orders
    WHERE  RegionId = @RegionId
    OPTION (RECOMPILE);
END;
GO

-- CÁCH 3: OPTIMIZE FOR UNKNOWN — dùng ước lượng TRUNG BÌNH từ histogram
CREATE OR ALTER PROCEDURE dbo.usp_OrdersByRegion_Unknown @RegionId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT OrderId, CustomerId, Amount FROM dbo.Orders
    WHERE  RegionId = @RegionId
    OPTION (OPTIMIZE FOR UNKNOWN);
END;
GO

-- CÁCH 4: OPTIMIZE FOR <giá trị cụ thể> — ép theo trường hợp phổ biến nhất
CREATE OR ALTER PROCEDURE dbo.usp_OrdersByRegion_OptFor @RegionId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT OrderId, CustomerId, Amount FROM dbo.Orders
    WHERE  RegionId = @RegionId
    OPTION (OPTIMIZE FOR (@RegionId = 1));
END;
GO

-- CÁCH 5: tách thành 2 procedure theo độ chọn lọc (giải pháp "thủ công" nhưng hiệu quả)
CREATE OR ALTER PROCEDURE dbo.usp_OrdersByRegion_BigRegion @RegionId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT OrderId, CustomerId, Amount FROM dbo.Orders WHERE RegionId = @RegionId;
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_OrdersByRegion_SmallRegion @RegionId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT OrderId, CustomerId, Amount FROM dbo.Orders WHERE RegionId = @RegionId;
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_OrdersByRegion_Split @RegionId INT
AS
BEGIN
    SET NOCOUNT ON;
    IF @RegionId = 1
        EXEC dbo.usp_OrdersByRegion_BigRegion @RegionId;
    ELSE
        EXEC dbo.usp_OrdersByRegion_SmallRegion @RegionId;
END;
GO
/*  Mỗi proc con có plan cache RIÊNG ⇒ mỗi bên tối ưu cho hình dạng dữ liệu của mình.

    ⚠ Cách 3 & 4 KHÔNG phải lúc nào cũng tốt: chúng "đóng băng" một giả định.
    ⚠ Biến cục bộ (DECLARE @x; SET @x = @param) cũng vô hiệu hoá sniffing —
      cùng hiệu ứng với OPTIMIZE FOR UNKNOWN, nhưng khó đọc hơn ⇒ tránh.
    ⚠ ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SNIFFING = OFF tắt cho
      TOÀN database — quá thô bạo, hiếm khi là đáp án đúng.                      */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 4 — ĐỌC QUERY STORE & ÉP PLAN (PLAN FORCING)
───────────────────────────────────────────────────────────────────────────────*/
-- Sinh dữ liệu cho Query Store
EXEC dbo.usp_OrdersByRegion           @RegionId = 1;
EXEC dbo.usp_OrdersByRegion           @RegionId = 5;
EXEC dbo.usp_OrdersByRegion_Recompile @RegionId = 1;
EXEC dbo.usp_OrdersByRegion_Unknown   @RegionId = 5;
EXEC dbo.usp_OrdersByRegion_Split     @RegionId = 1;
EXEC dbo.usp_OrdersByRegion_Split     @RegionId = 5;
GO
EXEC sys.sp_query_store_flush_db;      -- ép xả buffer ra đĩa ngay
GO

-- TOP truy vấn tốn kém nhất — truy vấn "xương sống" cần thuộc
SELECT TOP (10)
       q.query_id,
       p.plan_id,
       OBJECT_NAME(q.object_id)                        AS ObjectName,
       LEFT(qt.query_sql_text, 90)                     AS QueryText,
       rs.count_executions,
       CAST(rs.avg_duration    / 1000.0 AS DECIMAL(12,2)) AS AvgDurationMs,
       CAST(rs.avg_cpu_time    / 1000.0 AS DECIMAL(12,2)) AS AvgCpuMs,
       rs.avg_logical_io_reads                         AS AvgLogicalReads,
       p.is_forced_plan
FROM   sys.query_store_query          q
JOIN   sys.query_store_query_text     qt ON qt.query_text_id = q.query_text_id
JOIN   sys.query_store_plan           p  ON p.query_id       = q.query_id
JOIN   sys.query_store_runtime_stats  rs ON rs.plan_id       = p.plan_id
ORDER BY rs.avg_duration DESC;
GO

-- Truy vấn có NHIỀU plan ⇒ ứng viên bị "plan regression"
SELECT  q.query_id, COUNT(DISTINCT p.plan_id) AS PlanCount,
        LEFT(qt.query_sql_text, 90) AS QueryText
FROM    sys.query_store_query q
JOIN    sys.query_store_query_text qt ON qt.query_text_id = q.query_text_id
JOIN    sys.query_store_plan p ON p.query_id = q.query_id
GROUP BY q.query_id, LEFT(qt.query_sql_text, 90)
HAVING  COUNT(DISTINCT p.plan_id) > 1;
GO

-- ÉP PLAN: chọn plan nhanh nhất của truy vấn tốn kém nhất
DECLARE @query_id INT, @plan_id INT;

SELECT TOP (1) @query_id = q.query_id
FROM   sys.query_store_query q
JOIN   sys.query_store_plan p  ON p.query_id = q.query_id
JOIN   sys.query_store_runtime_stats rs ON rs.plan_id = p.plan_id
WHERE  q.object_id = OBJECT_ID('dbo.usp_OrdersByRegion')
GROUP BY q.query_id
ORDER BY MAX(rs.avg_duration) DESC;

SELECT TOP (1) @plan_id = p.plan_id
FROM   sys.query_store_plan p
JOIN   sys.query_store_runtime_stats rs ON rs.plan_id = p.plan_id
WHERE  p.query_id = @query_id
ORDER BY rs.avg_duration ASC;          -- chọn plan NHANH NHẤT

IF @query_id IS NOT NULL AND @plan_id IS NOT NULL
BEGIN
    EXEC sys.sp_query_store_force_plan @query_id = @query_id, @plan_id = @plan_id;
    SELECT @query_id AS ForcedQueryId, @plan_id AS ForcedPlanId, 'ĐÃ ÉP PLAN' AS Status;
END;
GO

SELECT query_id, plan_id, is_forced_plan, force_failure_count, last_force_failure_reason_desc
FROM   sys.query_store_plan WHERE is_forced_plan = 1;
GO
/*  🎯 KỊCH BẢN THI KINH ĐIỂN:
      "Sau khi nâng cấp SQL Server / cập nhật statistics, một truy vấn quan trọng
       chậm hẳn. Cần khôi phục hiệu năng NGAY mà không sửa mã nguồn."
      ⇒ Query Store → tìm plan cũ → sp_query_store_force_plan.

    Bỏ ép: EXEC sys.sp_query_store_unforce_plan @query_id, @plan_id;
    ⚠ Ép plan có thể THẤT BẠI về sau (index bị xoá, schema đổi) — kiểm tra
      force_failure_count và last_force_failure_reason_desc.
    ⚠ Ép plan là giải pháp TẠM THỜI để dập lửa, không thay cho việc sửa gốc.     */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 5 — QUERY STORE HINTS (SQL 2022+ / Azure SQL) — không sửa được mã nguồn
───────────────────────────────────────────────────────────────────────────────*/
IF CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) >= 16
BEGIN
    DECLARE @qid INT = (SELECT TOP (1) q.query_id FROM sys.query_store_query q
                        WHERE q.object_id = OBJECT_ID('dbo.usp_OrdersByRegion'));
    IF @qid IS NOT NULL
    BEGIN
        EXEC(N'EXEC sys.sp_query_store_set_hints @query_id = ' + @qid +
             N', @query_hints = N''OPTION(RECOMPILE)''');
        PRINT 'Đã áp hint OPTION(RECOMPILE) mà KHÔNG sửa mã nguồn.';
    END;
END
ELSE
    PRINT 'Query Store hints cần SQL Server 2022+ / Azure SQL.';
GO
/*  🎯 CÂU HỎI TỦ CỦA SQL 2022:
      "Ứng dụng của bên thứ ba, không sửa được câu lệnh, nhưng cần thêm query hint."
      ⇒ QUERY STORE HINTS (sp_query_store_set_hints).
      Xem: sys.query_store_query_hints. Gỡ: sp_query_store_clear_hints.

    Trước 2022, giải pháp tương đương (kém hơn) là PLAN GUIDE
      (sp_create_plan_guide) — vẫn có thể xuất hiện trong đề như đáp án nhiễu.   */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 6 — STATISTICS
───────────────────────────────────────────────────────────────────────────────*/
SELECT  s.name AS StatsName, s.auto_created, s.user_created, s.is_incremental,
        sp.last_updated, sp.rows, sp.rows_sampled, sp.modification_counter,
        CAST(100.0 * sp.rows_sampled / NULLIF(sp.rows,0) AS DECIMAL(5,2)) AS SampledPct
FROM    sys.stats s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE   s.object_id = OBJECT_ID('dbo.Orders');

-- Xem histogram (nơi optimizer lấy ước lượng số dòng)
DBCC SHOW_STATISTICS('dbo.Orders', 'IX_Orders_RegionId') WITH HISTOGRAM;
GO

-- Làm lệch statistics rồi quan sát ước lượng sai
INSERT dbo.Orders (RegionId, CustomerId, OrderDate, Amount)
SELECT TOP (50000) 99, 1, '2026-07-01', 100
FROM   sys.all_objects a CROSS JOIN sys.all_objects b;

SET STATISTICS IO ON;
SELECT COUNT(*) FROM dbo.Orders WHERE RegionId = 99;   -- ước lượng LỆCH (Region 99 chưa có trong histogram)
SET STATISTICS IO OFF;

UPDATE STATISTICS dbo.Orders WITH FULLSCAN;            -- sửa: cập nhật statistics
GO
SELECT modification_counter, last_updated, rows
FROM   sys.stats s CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id)
WHERE  s.object_id = OBJECT_ID('dbo.Orders') AND s.name = 'IX_Orders_RegionId';
GO
/*  KIẾN THỨC THI:
      - AUTO_UPDATE_STATISTICS mặc định ON; ngưỡng hiện đại (compat ≥130):
        SQRT(1000 * số_dòng) thay vì "20% + 500" của bản cũ ⇒ bảng lớn cập nhật
        thường xuyên hơn.
      - AUTO_UPDATE_STATISTICS_ASYNC = ON để truy vấn KHÔNG phải chờ cập nhật xong.
      - ASCENDING KEY PROBLEM: dữ liệu mới (ngày hôm nay, ID mới nhất) nằm NGOÀI
        histogram ⇒ ước lượng 1 dòng ⇒ plan tệ. Xử lý: cập nhật statistics thường
        xuyên hơn, hoặc OPTION(RECOMPILE), hoặc dùng incremental statistics với bảng
        phân vùng.
      - Statistics ĐỘC LẬP với index: có thể tồn tại statistics không đi kèm index
        (auto-created, tên _WA_Sys_...).
      - Rebuild index ⇒ cập nhật statistics FULLSCAN. Reorganize ⇒ KHÔNG.        */


/*═══════════════════ PHẦN B — CHỜ, KHOÁ, TÀI NGUYÊN ══════════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 7 — WAIT STATISTICS
───────────────────────────────────────────────────────────────────────────────*/
-- Wait tích luỹ từ lúc khởi động, đã lọc các wait "vô hại"
WITH Waits AS
(
    SELECT  wait_type,
            wait_time_ms / 1000.0                       AS WaitSec,
            (wait_time_ms - signal_wait_time_ms)/1000.0 AS ResourceSec,
            signal_wait_time_ms / 1000.0                AS SignalSec,   -- chờ CPU
            waiting_tasks_count                         AS WaitCount,
            100.0 * wait_time_ms / SUM(wait_time_ms) OVER() AS Pct
    FROM    sys.dm_os_wait_stats
    WHERE   waiting_tasks_count > 0
      AND   wait_type NOT IN (
            'CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE','SLEEP_TASK',
            'SLEEP_SYSTEMTASK','SQLTRACE_BUFFER_FLUSH','WAITFOR','LOGMGR_QUEUE',
            'CHECKPOINT_QUEUE','REQUEST_FOR_DEADLOCK_SEARCH','XE_TIMER_EVENT',
            'BROKER_TO_FLUSH','BROKER_TASK_STOP','CLR_MANUAL_EVENT','CLR_AUTO_EVENT',
            'DISPATCHER_QUEUE_SEMAPHORE','FT_IFTS_SCHEDULER_IDLE_WAIT','XE_DISPATCHER_WAIT',
            'XE_DISPATCHER_JOIN','SQLTRACE_INCREMENTAL_FLUSH_SLEEP','DIRTY_PAGE_POLL',
            'HADR_FILESTREAM_IOMGR_IOCOMPLETION','SP_SERVER_DIAGNOSTICS_SLEEP',
            'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP','QDS_ASYNC_QUEUE','QDS_SHUTDOWN_QUEUE',
            'PREEMPTIVE_XE_GETTARGETSTATE','BROKER_EVENTHANDLER','SLEEP_DBSTARTUP')
)
SELECT TOP (15) wait_type,
       CAST(WaitSec AS DECIMAL(14,2))     AS WaitSec,
       CAST(ResourceSec AS DECIMAL(14,2)) AS ResourceSec,
       CAST(SignalSec AS DECIMAL(14,2))   AS SignalSec_ChoCPU,
       WaitCount,
       CAST(Pct AS DECIMAL(5,2))          AS Pct
FROM   Waits ORDER BY WaitSec DESC;
GO

-- Ai đang chờ NGAY LÚC NÀY (và bị ai chặn)
SELECT  r.session_id, r.status, r.wait_type, r.wait_time, r.blocking_session_id,
        r.command, DB_NAME(r.database_id) AS DbName,
        LEFT(t.text, 100) AS SqlText
FROM    sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE   r.session_id <> @@SPID AND r.status <> 'background';
GO
/*  BẢNG TRA CỨU WAIT TYPE (học thuộc):
    ┌──────────────────────┬───────────────────────┬──────────────────────────────────┐
    │ Wait type            │ Nghĩa                 │ Hướng xử lý                      │
    ├──────────────────────┼───────────────────────┼──────────────────────────────────┤
    │ CXPACKET/CXCONSUMER  │ Song song hoá         │ MAXDOP, Cost Threshold (25-50)   │
    │ PAGEIOLATCH_*        │ Chờ đọc trang từ đĩa  │ Thiếu RAM/index, I/O chậm        │
    │ PAGELATCH_*          │ Tranh trang trong RAM │ Hot page, tempdb contention      │
    │ LCK_M_*              │ Chờ khoá              │ Transaction dài, cân nhắc RCSI   │
    │ WRITELOG             │ Chờ ghi log           │ Đĩa log, Delayed Durability      │
    │ RESOURCE_SEMAPHORE   │ Chờ cấp bộ nhớ        │ Memory grant quá lớn             │
    │ SOS_SCHEDULER_YIELD  │ Nghẽn CPU             │ Truy vấn tốn CPU, thiếu index    │
    │ THREADPOOL           │ Hết worker thread     │ Blocking nặng, quá nhiều kết nối │
    │ ASYNC_NETWORK_IO     │ Client đọc kết quả chậm│ Lỗi ỨNG DỤNG, không phải SQL    │
    └──────────────────────┴───────────────────────┴──────────────────────────────────┘
    ⚠ ASYNC_NETWORK_IO cao = ứng dụng xử lý từng dòng chậm (RBAR ở client),
      KHÔNG phải lỗi mạng hay SQL Server. Đây là bẫy hay gặp.
    Đặt lại bộ đếm: DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR);                 */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 8 — RCSI: người đọc không chặn người ghi
───────────────────────────────────────────────────────────────────────────────*/
SELECT  name,
        is_read_committed_snapshot_on   AS RCSI,
        snapshot_isolation_state_desc   AS SnapshotIsolation
FROM    sys.databases WHERE name = 'DP800_Perf';

ALTER DATABASE DP800_Perf SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
ALTER DATABASE DP800_Perf SET ALLOW_SNAPSHOT_ISOLATION ON;
GO
SELECT  name, is_read_committed_snapshot_on AS RCSI, snapshot_isolation_state_desc
FROM    sys.databases WHERE name = 'DP800_Perf';
GO
/*  PHÂN BIỆT HAI CÔNG TẮC (rất hay bị nhầm):
      READ_COMMITTED_SNAPSHOT ON  → đổi HÀNH VI CỦA READ COMMITTED (mức mặc định)
                                    ⇒ ứng dụng KHÔNG phải sửa dòng nào.
      ALLOW_SNAPSHOT_ISOLATION ON → chỉ MỞ KHẢ NĂNG dùng
                                    SET TRANSACTION ISOLATION LEVEL SNAPSHOT
                                    ⇒ ứng dụng phải khai báo tường minh.

    🎯 "Báo cáo chạy lâu đang chặn nghiệp vụ ghi, không được đọc dữ liệu bẩn,
        không được sửa ứng dụng" ⇒ BẬT RCSI. (KHÔNG chọn NOLOCK!)

    CÁI GIÁ CỦA ROW VERSIONING:
      - tempdb phình vì version store ⇒ theo dõi sys.dm_tran_version_store_space_usage
      - mỗi dòng thêm 14 byte con trỏ phiên bản
      - có thể gặp lỗi 3960 "snapshot isolation transaction aborted due to update conflict"
        khi dùng SNAPSHOT isolation (RCSI thì không).
    RCSI mặc định: BẬT trên Azure SQL Database, TẮT trên SQL Server on-prem.     */

-- Bảng so sánh isolation level
SELECT * FROM (VALUES
 ('READ UNCOMMITTED','Có','Có','Có','Không khoá đọc (NOLOCK)'),
 ('READ COMMITTED','Không','Có','Có','Shared lock ngắn (mặc định)'),
 ('READ COMMITTED + RCSI','Không','Có','Có','Row versioning - KHÔNG chặn'),
 ('REPEATABLE READ','Không','Không','Có','Giữ shared lock tới hết transaction'),
 ('SNAPSHOT','Không','Không','Không','Row versioning toàn transaction'),
 ('SERIALIZABLE','Không','Không','Không','Range lock - hạn chế đồng thời nhất')
) v(IsolationLevel, DocBan, NonRepeatableRead, PhantomRead, CoChe);
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 9 — TEMPDB & CẤU HÌNH CẤP DATABASE
───────────────────────────────────────────────────────────────────────────────*/
-- tempdb: bao nhiêu data file?
SELECT  name, type_desc, size * 8 / 1024 AS SizeMB,
        growth * 8 / 1024 AS GrowthMB, is_percent_growth
FROM    sys.master_files WHERE database_id = DB_ID('tempdb');

SELECT COUNT(*) AS TempdbDataFiles,
       (SELECT cpu_count FROM sys.dm_os_sys_info) AS LogicalCPUs
FROM   sys.master_files WHERE database_id = DB_ID('tempdb') AND type = 0;
/*  KHUYẾN NGHỊ CỦA MICROSOFT:
      - Số data file = số logical CPU, TỐI ĐA 8 (nếu vẫn nghẽn thì tăng dần thêm 4).
      - Mọi file BẰNG NHAU về kích thước và autogrowth (nếu không, thuật toán
        proportional fill sẽ dồn ghi vào file lớn nhất ⇒ vẫn nghẽn).
      - Không dùng autogrowth theo phần trăm.
      - Triệu chứng nghẽn tempdb: PAGELATCH_UP/EX trên trang 2:1:1 (PFS),
        2:1:3 (SGAM) — SQL 2019+ đã giảm nhiều nhờ tối ưu PFS.                   */

-- Ai đang tiêu thụ tempdb
SELECT TOP (5) session_id,
       (user_objects_alloc_page_count - user_objects_dealloc_page_count) * 8 / 1024 AS UserObjMB,
       (internal_objects_alloc_page_count - internal_objects_dealloc_page_count) * 8 / 1024 AS InternalObjMB
FROM   sys.dm_db_session_space_usage
ORDER BY InternalObjMB DESC;

-- Cấu hình cấp DATABASE (dùng được cả trên Azure SQL, nơi không có sp_configure)
SELECT configuration_id, name, value, value_for_secondary
FROM   sys.database_scoped_configurations;
GO
/*  CÁC CẤU HÌNH SCOPED HAY RA ĐỀ:
      MAXDOP                          — giới hạn song song ở cấp database
      LEGACY_CARDINALITY_ESTIMATION   — quay về CE cũ (SQL 2012) khi nâng cấp gây hồi quy
      PARAMETER_SNIFFING              — tắt sniffing toàn DB (thô bạo)
      QUERY_OPTIMIZER_HOTFIXES        — bật các bản vá optimizer
      IDENTITY_CACHE                  — tắt để tránh nhảy IDENTITY sau khi restart bất ngờ
      CLEAR PROCEDURE_CACHE           — xoá plan cache CHỈ của database này
      OPTIMIZE_FOR_AD_HOC_WORKLOADS   — (2019+) giảm phình plan cache
    Cú pháp: ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 4;                 */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 10 — TÌM TRUY VẤN TỐN KÉM KHÔNG QUA QUERY STORE
───────────────────────────────────────────────────────────────────────────────*/
SELECT TOP (10)
       qs.execution_count,
       qs.total_worker_time / 1000                      AS TotalCpuMs,
       qs.total_worker_time / qs.execution_count / 1000  AS AvgCpuMs,
       qs.total_elapsed_time / qs.execution_count / 1000 AS AvgDurationMs,
       qs.total_logical_reads / qs.execution_count       AS AvgLogicalReads,
       qs.total_spills                                   AS TotalSpills,
       DB_NAME(st.dbid)                                  AS DbName,
       LEFT(SUBSTRING(st.text, (qs.statement_start_offset/2) + 1,
            ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)
              ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1), 120) AS StatementText
FROM   sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
WHERE  st.dbid = DB_ID('DP800_Perf') OR st.dbid IS NULL
ORDER BY qs.total_worker_time DESC;

-- Index còn thiếu (gợi ý của optimizer — CHỈ tham khảo, đừng tạo mù quáng)
SELECT TOP (5)
       ROUND(s.avg_total_user_cost * s.avg_user_impact * (s.user_seeks + s.user_scans), 0) AS ImpactScore,
       d.statement AS TableName,
       'CREATE INDEX IX_Suggested ON ' + d.statement + ' (' +
       ISNULL(d.equality_columns, '') +
       CASE WHEN d.equality_columns IS NOT NULL AND d.inequality_columns IS NOT NULL THEN ',' ELSE '' END +
       ISNULL(d.inequality_columns, '') + ')' +
       ISNULL(' INCLUDE (' + d.included_columns + ')', '') AS SuggestedIndex
FROM   sys.dm_db_missing_index_groups g
JOIN   sys.dm_db_missing_index_group_stats s ON s.group_handle = g.index_group_handle
JOIN   sys.dm_db_missing_index_details d ON d.index_handle = g.index_handle
WHERE  d.database_id = DB_ID()
ORDER BY ImpactScore DESC;
GO
/*  ⚠ Gợi ý missing index KHÔNG xét tới index đã có, không gộp các gợi ý trùng nhau,
    và đặt thứ tự cột theo quy tắc máy móc. Luôn đối chiếu với index hiện có trước
    khi tạo. Đề thi có thể hỏi "có nên tạo tất cả index được gợi ý không?" ⇒ KHÔNG.  */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 11 — INTELLIGENT QUERY PROCESSING: KIỂM TRA MỨC HỖ TRỢ
───────────────────────────────────────────────────────────────────────────────*/
SELECT  name, compatibility_level,
        CASE
            WHEN compatibility_level >= 160 THEN 'IQP đầy đủ: PSP optimization, DOP feedback, CE feedback, memory grant persistence'
            WHEN compatibility_level >= 150 THEN 'IQP 2019: batch mode on rowstore, scalar UDF inlining, table variable deferred compilation, row mode memory grant feedback'
            WHEN compatibility_level >= 140 THEN 'IQP 2017: adaptive joins, interleaved execution, batch mode memory grant feedback'
            ELSE 'Chưa có IQP'
        END AS IqpLevel
FROM    sys.databases WHERE name = 'DP800_Perf';
GO
/*  🎯 QUY TRÌNH NÂNG CẤP CHUẨN CỦA MICROSOFT (đề hay hỏi dạng sắp xếp bước):
      1. Nâng cấp engine, GIỮ NGUYÊN compatibility level cũ
      2. BẬT QUERY STORE, chạy tải thực tế để thu thập baseline
      3. Nâng compatibility level lên mức mới
      4. Theo dõi hồi quy trong Query Store (Regressed Queries)
      5. FORCE lại plan cũ cho truy vấn bị hồi quy
      ⇒ Đây là lý do Query Store là công cụ trung tâm của mọi kịch bản nâng cấp.

    KIỂM CHỨNG NHANH IQP: chạy cùng truy vấn ở 2 compat level và so sánh plan:
      ALTER DATABASE ... SET COMPATIBILITY_LEVEL = 140;  -- rồi 150, 160          */


/*───────────────────────────────────────────────────────────────────────────────
  DỌN DẸP
───────────────────────────────────────────────────────────────────────────────*/
-- USE master;
-- ALTER DATABASE DP800_Perf SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
-- DROP DATABASE DP800_Perf;

/*═══════════════════════════════════════════════════════════════════════════════
  CHECKLIST SAU LAB 04
  □ Mô tả triệu chứng parameter sniffing và 5 cách xử lý theo thứ tự ưu tiên.
  □ Viết được truy vấn Query Store tìm truy vấn tốn kém nhất.
  □ Nhớ tên đúng: sp_query_store_force_plan / unforce / set_hints.
  □ Biết Query Store hints giải quyết tình huống nào (2022+).
  □ Giải thích ngưỡng auto-update statistics hiện đại và ascending key problem.
  □ Đọc bảng wait type, đặc biệt ASYNC_NETWORK_IO và PAGELATCH vs PAGEIOLATCH.
  □ Phân biệt READ_COMMITTED_SNAPSHOT và ALLOW_SNAPSHOT_ISOLATION.
  □ Nêu quy tắc cấu hình tempdb và triệu chứng nghẽn tempdb.
  □ Kể 5 bước của quy trình nâng cấp có kiểm soát bằng Query Store.
═══════════════════════════════════════════════════════════════════════════════*/
