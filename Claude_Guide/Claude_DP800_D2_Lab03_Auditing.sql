/*═══════════════════════════════════════════════════════════════════════════════
  DP-800 | MIỀN 2 | LAB 03 — KIỂM TOÁN & THEO DÕI THAY ĐỔI
  Đi kèm: Claude_DP800_D2_SecurityPerfDeploy_Guide.md  (mục 6)

  SECTION 1..4 — SQL Server Audit
  SECTION 5..6 — Change Tracking vs Change Data Capture
  SECTION 7    — Extended Events
  SECTION 8    — Bảng chọn công cụ + dọn dẹp

  ⚠ Lab ghi file audit ra thư mục dữ liệu mặc định của instance. Chạy trên TEST.
═══════════════════════════════════════════════════════════════════════════════*/

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
SELECT SERVERPROPERTY('Edition') AS Edition,
       SERVERPROPERTY('ProductMajorVersion') AS MajorVer;
/*  ⚠ SQL Server Audit ở mức DATABASE có trên mọi edition từ 2016 SP1;
    audit mức SERVER trước đó chỉ có ở Enterprise. Azure SQL dùng
    "Auditing" ghi ra Blob Storage / Log Analytics / Event Hub.                  */
GO

IF DB_ID('DP800_Audit') IS NOT NULL
BEGIN
    ALTER DATABASE DP800_Audit SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DP800_Audit;
END;
GO
CREATE DATABASE DP800_Audit;
GO
USE DP800_Audit;
GO
CREATE TABLE dbo.Payroll
(
    EmpId    INT IDENTITY PRIMARY KEY,
    FullName NVARCHAR(100) NOT NULL,
    Salary   DECIMAL(19,4) NOT NULL,
    DeptId   INT NOT NULL
);
INSERT dbo.Payroll (FullName, Salary, DeptId) VALUES
 (N'Nguyễn Văn A', 50000000, 10),
 (N'Trần Thị B',   72000000, 20),
 (N'Lê Văn C',     41000000, 10);
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 1 — SERVER AUDIT: ghi ra ĐÂU
───────────────────────────────────────────────────────────────────────────────*/
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'Audit_DP800')
BEGIN
    ALTER SERVER AUDIT Audit_DP800 WITH (STATE = OFF);
    DROP SERVER AUDIT Audit_DP800;
END;
GO
DECLARE @path NVARCHAR(400) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(400));
DECLARE @cmd  NVARCHAR(MAX) =
N'CREATE SERVER AUDIT Audit_DP800
  TO FILE (FILEPATH   = ''' + @path + N''',
           MAXSIZE    = 20 MB,
           MAX_ROLLOVER_FILES = 5,
           RESERVE_DISK_SPACE = OFF)
  WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);';
EXEC sys.sp_executesql @cmd;
GO
ALTER SERVER AUDIT Audit_DP800 WITH (STATE = ON);
GO
/*  BA THAM SỐ HAY RA ĐỀ:
      ON_FAILURE = CONTINUE       — vẫn chạy dù không ghi được audit (mặc định)
      ON_FAILURE = SHUTDOWN       — 🎯 TẮT INSTANCE nếu không ghi được audit
                                    ⇒ đáp án cho "không được phép có thao tác nào
                                       không được ghi vết" (tuân thủ nghiêm ngặt)
      ON_FAILURE = FAIL_OPERATION — chỉ huỷ thao tác đang bị audit
      QUEUE_DELAY = 0             — ghi ĐỒNG BỘ (synchronous), chậm nhưng không mất bản ghi
      QUEUE_DELAY = 1000          — ghi bất đồng bộ, tối đa trễ 1 giây

    ĐÍCH GHI: FILE | APPLICATION_LOG | SECURITY_LOG (Windows Event Log).
      SECURITY_LOG an toàn nhất (DBA không xoá được) nhưng cần cấu hình quyền
      "generate security audits" cho service account.
      Azure SQL: Blob Storage / Log Analytics / Event Hub.                       */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 2 — SERVER AUDIT SPECIFICATION: ghi CÁI GÌ (mức server)
───────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'Spec_Server_DP800')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION Spec_Server_DP800 WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION Spec_Server_DP800;
END;
GO
CREATE SERVER AUDIT SPECIFICATION Spec_Server_DP800
FOR SERVER AUDIT Audit_DP800
    ADD (FAILED_LOGIN_GROUP),                    -- dò mật khẩu
    ADD (SUCCESSFUL_LOGIN_GROUP),
    ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP),       -- ai được thêm vào sysadmin
    ADD (SERVER_PERMISSION_CHANGE_GROUP),
    ADD (DATABASE_CHANGE_GROUP)                  -- CREATE/ALTER/DROP DATABASE
WITH (STATE = ON);
GO
SELECT name, is_state_enabled FROM sys.server_audit_specifications;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 3 — DATABASE AUDIT SPECIFICATION: audit tới từng bảng/thao tác
───────────────────────────────────────────────────────────────────────────────*/
USE DP800_Audit;
GO
CREATE DATABASE AUDIT SPECIFICATION Spec_Db_DP800
FOR SERVER AUDIT Audit_DP800
    -- Ghi vết MỌI truy vấn đọc/sửa bảng lương, của MỌI người dùng (public)
    ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.Payroll BY public),
    -- Thay đổi cấu trúc đối tượng
    ADD (SCHEMA_OBJECT_CHANGE_GROUP),
    -- Thay đổi thành viên role trong database
    ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP),
    -- Thay đổi quyền
    ADD (DATABASE_OBJECT_PERMISSION_CHANGE_GROUP)
WITH (STATE = ON);
GO
/*  ⚠ 'BY public' là cách bao trùm mọi principal — nếu chỉ định 'BY SomeUser' thì
    người khác đọc bảng sẽ KHÔNG bị ghi vết. Đây là lỗi cấu hình hay ra đề.      */

SELECT  s.name AS SpecName, s.is_state_enabled,
        d.audit_action_name, d.class_desc, d.major_id, d.audited_principal_id
FROM    sys.database_audit_specifications s
JOIN    sys.database_audit_specification_details d
        ON d.database_specification_id = s.database_specification_id;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 4 — SINH SỰ KIỆN & ĐỌC LOG AUDIT
───────────────────────────────────────────────────────────────────────────────*/
CREATE USER HrUser WITHOUT LOGIN;
GRANT SELECT, UPDATE ON dbo.Payroll TO HrUser;
GO

-- Sinh vài thao tác để audit ghi lại
SELECT * FROM dbo.Payroll;                                   -- dbo đọc
UPDATE dbo.Payroll SET Salary = Salary * 1.1 WHERE DeptId = 10;

EXECUTE AS USER = 'HrUser';
    SELECT FullName, Salary FROM dbo.Payroll WHERE DeptId = 20;
REVERT;
GO
CREATE TABLE dbo.TempObj (Id INT);      -- kích SCHEMA_OBJECT_CHANGE_GROUP
DROP TABLE dbo.TempObj;
GO

WAITFOR DELAY '00:00:03';               -- chờ QUEUE_DELAY xả ra file
GO

-- ĐỌC FILE AUDIT — truy vấn cần thuộc lòng
DECLARE @path NVARCHAR(400) =
        CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(400)) + N'Audit_DP800*.sqlaudit';
DECLARE @cmd NVARCHAR(MAX) = N'
SELECT TOP (30)
        f.event_time,
        f.action_id,
        f.succeeded,
        f.server_principal_name,
        f.database_principal_name,
        f.database_name,
        f.object_name,
        f.statement
FROM    sys.fn_get_audit_file(''' + @path + N''', DEFAULT, DEFAULT) f
WHERE   f.database_name = ''DP800_Audit''
ORDER BY f.event_time DESC;';
EXEC sys.sp_executesql @cmd;
GO
/*  ĐỌC KẾT QUẢ:
      action_id: SL = SELECT, IN = INSERT, UP = UPDATE, DL = DELETE,
                 CR = CREATE, AL = ALTER, DR = DROP, LGIF = login failed
      server_principal_name  = login thật (ORIGINAL_LOGIN)
      database_principal_name= user đang thực thi (thấy rõ khi EXECUTE AS)
      statement              = nguyên văn câu lệnh
    🎯 Đây chính là thứ trigger KHÔNG làm được: audit ghi được cả hành vi ĐỌC (SELECT),
      và không thể bị vô hiệu bằng TRUNCATE/BULK INSERT.                          */

-- Xem trạng thái toàn bộ audit đang chạy
SELECT  sa.name AS AuditName, sa.type_desc AS Destination, sa.on_failure_desc,
        sa.queue_delay, sas.status_desc, sas.audit_file_path
FROM    sys.server_audits sa
LEFT JOIN sys.dm_server_audit_status sas ON sas.audit_id = sa.audit_id;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 5 — CHANGE TRACKING (nhẹ: chỉ biết DÒNG NÀO đổi)
───────────────────────────────────────────────────────────────────────────────*/
ALTER DATABASE DP800_Audit
SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);
GO
ALTER TABLE dbo.Payroll
ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
GO
/*  ⚠ ĐIỀU KIỆN: bảng BẮT BUỘC có PRIMARY KEY. Change Tracking bám theo khoá chính. */

DECLARE @baseline BIGINT = CHANGE_TRACKING_CURRENT_VERSION();
SELECT @baseline AS BaselineVersion;

-- Thực hiện thay đổi
UPDATE dbo.Payroll SET Salary = 99000000 WHERE EmpId = 1;
INSERT dbo.Payroll (FullName, Salary, DeptId) VALUES (N'Phạm Thị D', 38000000, 30);
DELETE dbo.Payroll WHERE EmpId = 3;

-- Lấy danh sách thay đổi kể từ baseline
SELECT  ct.EmpId,
        ct.SYS_CHANGE_VERSION,
        ct.SYS_CHANGE_OPERATION,          -- I / U / D
        ct.SYS_CHANGE_COLUMNS,
        p.FullName, p.Salary              -- ⚠ dòng đã DELETE sẽ là NULL
FROM    CHANGETABLE(CHANGES dbo.Payroll, @baseline) AS ct
LEFT JOIN dbo.Payroll p ON p.EmpId = ct.EmpId
ORDER BY ct.SYS_CHANGE_VERSION;

-- Biết cột nào bị đổi
SELECT  ct.EmpId, ct.SYS_CHANGE_OPERATION,
        CHANGE_TRACKING_IS_COLUMN_IN_MASK(
            COLUMNPROPERTY(OBJECT_ID('dbo.Payroll'),'Salary','ColumnId'),
            ct.SYS_CHANGE_COLUMNS) AS SalaryChanged
FROM    CHANGETABLE(CHANGES dbo.Payroll, @baseline) AS ct;
GO
/*  ĐẶC ĐIỂM CHANGE TRACKING:
      ✅ Chi phí rất thấp (đồng bộ, chỉ ghi khoá + phiên bản).
      ✅ Không cần SQL Server Agent.
      ✅ Có trên MỌI edition, kể cả Azure SQL Database.
      ❌ KHÔNG lưu giá trị cũ/mới — chỉ biết "dòng có khoá X đã đổi".
      ❌ Không giữ lịch sử nhiều lần đổi: chỉ biết trạng thái mới nhất.
    ⇒ Dùng cho ĐỒNG BỘ tăng dần (sync client, cache invalidation, ETL delta).     */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 6 — CHANGE DATA CAPTURE (nặng hơn: lưu CẢ giá trị cũ/mới)
───────────────────────────────────────────────────────────────────────────────*/
BEGIN TRY
    EXEC sys.sp_cdc_enable_db;
    PRINT 'Đã bật CDC ở cấp database.';

    EXEC sys.sp_cdc_enable_table
         @source_schema      = N'dbo',
         @source_name        = N'Payroll',
         @role_name          = NULL,           -- NULL = không giới hạn role truy cập
         @supports_net_changes = 1;            -- cần PK; cho phép dùng ..._net_changes_
    PRINT 'Đã bật CDC cho dbo.Payroll.';
END TRY
BEGIN CATCH
    SELECT 'CDC' AS Step, ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS Msg;
END CATCH;
GO

-- ⚠ sys.databases có is_cdc_enabled nhưng KHÔNG có cột cho Change Tracking;
--   trạng thái Change Tracking nằm ở catalog view riêng.
SELECT name, is_cdc_enabled FROM sys.databases WHERE name = 'DP800_Audit';
SELECT DB_NAME(database_id) AS DbName, is_auto_cleanup_on, retention_period, retention_period_units_desc
FROM   sys.change_tracking_databases;
SELECT OBJECT_NAME(object_id) AS TableName, is_track_columns_updated_on
FROM   sys.change_tracking_tables;
SELECT name, is_tracked_by_cdc FROM sys.tables WHERE name = 'Payroll';
GO

UPDATE dbo.Payroll SET Salary = 123000000 WHERE EmpId = 2;
GO
/*  ⚠ CDC đọc TRANSACTION LOG bằng JOB "cdc.<db>_capture" của SQL Server Agent.
    Nếu Agent KHÔNG chạy, bảng cdc.*_CT sẽ RỖNG dù dữ liệu đã đổi.
    Đây là sự cố vận hành kinh điển và cũng là câu hỏi tình huống hay gặp.        */
SELECT  CASE WHEN EXISTS (SELECT 1 FROM sys.dm_server_services
                          WHERE servicename LIKE '%Agent%' AND status_desc = 'Running')
             THEN 'SQL Agent ĐANG CHẠY — capture job hoạt động'
             ELSE 'SQL Agent KHÔNG CHẠY — bảng CDC sẽ rỗng (chạy sp_cdc_scan thủ công để test)'
        END AS AgentStatus;
GO

-- Xem cấu trúc CDC sinh ra
SELECT name, type_desc FROM sys.objects
WHERE  SCHEMA_NAME(schema_id) = 'cdc' ORDER BY type_desc, name;

BEGIN TRY
    -- Bảng thay đổi: __$operation 1=DELETE 2=INSERT 3=trước UPDATE 4=sau UPDATE
    EXEC(N'SELECT TOP (20) __$start_lsn, __$operation,
                  CASE __$operation WHEN 1 THEN ''DELETE'' WHEN 2 THEN ''INSERT''
                                    WHEN 3 THEN ''UPDATE (giá trị CŨ)''
                                    WHEN 4 THEN ''UPDATE (giá trị MỚI)'' END AS OpDesc,
                  EmpId, FullName, Salary
           FROM   cdc.dbo_Payroll_CT ORDER BY __$start_lsn;');
END TRY
BEGIN CATCH
    SELECT 'Đọc bảng CDC' AS Step, ERROR_MESSAGE() AS Msg;
END CATCH;
GO
/*  ĐẶC ĐIỂM CDC:
      ✅ Lưu ĐẦY ĐỦ giá trị TRƯỚC và SAU của mỗi thay đổi.
      ✅ Giữ mọi lần đổi trung gian (không chỉ trạng thái cuối).
      ✅ Hàm truy vấn: cdc.fn_cdc_get_all_changes_<capture>, ..._net_changes_<capture>
      ❌ Cần SQL Server Agent (trên Azure SQL DB, CDC dùng scheduler nội bộ).
      ❌ Đọc transaction log ⇒ ảnh hưởng hiệu năng, log giữ lâu hơn.
      ❌ Chiếm dung lượng đáng kể.
    ⇒ Dùng cho ETL vào DATA WAREHOUSE khi cần biết giá trị cũ/mới (slowly changing dimension).

    🎯 PHÂN BIỆT NHANH (câu hỏi gần như chắc chắn có):
       "Chỉ cần biết dòng nào đổi, chi phí thấp nhất"       ⇒ CHANGE TRACKING
       "Cần cả giá trị trước và sau để nạp vào DW"          ⇒ CDC
       "Cần truy vấn dữ liệu ở một thời điểm trong quá khứ" ⇒ TEMPORAL TABLE
       "Cần chứng minh bằng mật mã chưa ai sửa"             ⇒ LEDGER
       "Cần biết AI đã ĐỌC dữ liệu"                         ⇒ SQL AUDIT
                                                              (chỉ audit làm được điều này) */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 7 — EXTENDED EVENTS (thay thế SQL Profiler / SQL Trace đã deprecated)
───────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'XE_DP800_SlowQueries')
    DROP EVENT SESSION XE_DP800_SlowQueries ON SERVER;
GO
CREATE EVENT SESSION XE_DP800_SlowQueries ON SERVER
ADD EVENT sqlserver.sql_batch_completed
(
    ACTION (sqlserver.database_name, sqlserver.sql_text, sqlserver.username,
            sqlserver.client_app_name, sqlserver.session_id)
    WHERE  (duration > 100000)                      -- micro giây ⇒ > 100 ms
),
ADD EVENT sqlserver.rpc_completed
(
    ACTION (sqlserver.database_name, sqlserver.sql_text)
    WHERE  (duration > 100000)
),
ADD EVENT sqlserver.xml_deadlock_report,            -- bắt deadlock graph
ADD EVENT sqlserver.error_reported
(
    ACTION (sqlserver.sql_text, sqlserver.database_name)
    WHERE  (severity >= 16)
)
ADD TARGET package0.ring_buffer (SET max_events_limit = 200)
WITH (MAX_DISPATCH_LATENCY = 5 SECONDS, STARTUP_STATE = OFF);
GO
ALTER EVENT SESSION XE_DP800_SlowQueries ON SERVER STATE = START;
GO

-- Sinh một truy vấn chậm để bắt
SELECT COUNT_BIG(*) AS Cnt
FROM sys.all_objects a CROSS JOIN sys.all_objects b CROSS JOIN sys.all_columns c;
GO
WAITFOR DELAY '00:00:06';
GO

-- Đọc ring buffer
SELECT TOP (10)
       x.value('(@timestamp)[1]',              'DATETIME2')     AS EventTime,
       x.value('(@name)[1]',                   'VARCHAR(60)')   AS EventName,
       x.value('(data[@name="duration"]/value)[1]','BIGINT')/1000 AS DurationMs,
       x.value('(action[@name="database_name"]/value)[1]','VARCHAR(128)') AS DbName,
       LEFT(x.value('(action[@name="sql_text"]/value)[1]','NVARCHAR(MAX)'), 120) AS SqlText
FROM (
    SELECT CAST(t.target_data AS XML) AS td
    FROM   sys.dm_xe_session_targets t
    JOIN   sys.dm_xe_sessions s ON s.address = t.event_session_address
    WHERE  s.name = 'XE_DP800_SlowQueries' AND t.target_name = 'ring_buffer'
) src
CROSS APPLY src.td.nodes('RingBufferTarget/event') AS e(x)
ORDER BY EventTime DESC;
GO
/*  KIẾN THỨC THI VỀ EXTENDED EVENTS:
      - Thay thế hoàn toàn SQL Trace/Profiler (đã deprecated) — nhẹ hơn nhiều.
      - TARGET: ring_buffer (RAM, tạm), event_file (bền vững, dùng cho production),
                histogram (đếm nhóm), pair_matching (tìm sự kiện chưa kết thúc).
      - duration tính bằng MICRO GIÂY (1 giây = 1.000.000).
      - Phiên dựng sẵn `system_health` LUÔN CHẠY và tự lưu deadlock — nơi đầu tiên
        cần xem khi được hỏi "làm sao điều tra deadlock đã xảy ra tuần trước?".
      - Azure SQL Database hỗ trợ XEvent ở cấp DATABASE (ON DATABASE thay vì ON SERVER),
        target ghi ra Azure Blob Storage.

    PHÂN BIỆT VỚI AUDIT: XEvents để CHẨN ĐOÁN HIỆU NĂNG; SQL Audit để TUÂN THỦ
      (audit có bảo đảm ghi vết, ON_FAILURE, và không bị bỏ sót sự kiện).        */

SELECT name, event_retention_mode_desc, startup_state
FROM   sys.server_event_sessions WHERE name IN ('system_health','XE_DP800_SlowQueries');
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 8 — DỌN DẸP
───────────────────────────────────────────────────────────────────────────────*/
ALTER EVENT SESSION XE_DP800_SlowQueries ON SERVER STATE = STOP;
DROP EVENT SESSION XE_DP800_SlowQueries ON SERVER;
GO
USE DP800_Audit;
GO
ALTER DATABASE AUDIT SPECIFICATION Spec_Db_DP800 WITH (STATE = OFF);
DROP DATABASE AUDIT SPECIFICATION Spec_Db_DP800;
GO
BEGIN TRY
    EXEC sys.sp_cdc_disable_db;
END TRY
BEGIN CATCH
    PRINT 'CDC chưa bật hoặc đã tắt.';
END CATCH;
GO
USE master;
GO
ALTER SERVER AUDIT SPECIFICATION Spec_Server_DP800 WITH (STATE = OFF);
DROP SERVER AUDIT SPECIFICATION Spec_Server_DP800;
GO
ALTER SERVER AUDIT Audit_DP800 WITH (STATE = OFF);
DROP SERVER AUDIT Audit_DP800;
GO
ALTER DATABASE DP800_Audit SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE DP800_Audit;
GO
/*  ⚠ THỨ TỰ GỠ BẮT BUỘC (ngược với thứ tự tạo):
      1. Tắt + drop DATABASE audit specification
      2. Tắt + drop SERVER audit specification
      3. Tắt + drop SERVER AUDIT
    Drop server audit khi còn specification tham chiếu ⇒ báo lỗi.
    File .sqlaudit đã ghi vẫn nằm trên đĩa — xoá thủ công nếu cần.               */


/*═══════════════════════════════════════════════════════════════════════════════
  CHECKLIST SAU LAB 03
  □ Nêu 3 phần của SQL Server Audit và thứ tự tạo/gỡ.
  □ Nhớ ON_FAILURE = SHUTDOWN dùng cho yêu cầu nào.
  □ Biết vì sao 'BY public' quan trọng trong database audit specification.
  □ Viết được truy vấn sys.fn_get_audit_file để đọc log.
  □ Phân biệt Change Tracking vs CDC trong 1 câu, và điều kiện tiên quyết của mỗi cái.
  □ Nhớ CDC cần SQL Server Agent; Change Tracking thì không.
  □ Biết __$operation 1/2/3/4 nghĩa là gì.
  □ Nêu 4 loại target của Extended Events và phiên system_health dùng để làm gì.
  □ Phân biệt khi nào dùng XEvents, khi nào dùng SQL Audit.
═══════════════════════════════════════════════════════════════════════════════*/
