-- ====================================================================================
-- BÀI TẬP VÀ VÍ DỤ THỰC HÀNH KỲ THI DP-800 (MICROSOFT CERTIFIED: AI-ENABLED DATABASE SOLUTIONS)
-- PHÂN LOẠI: MODULE 2 — CODE THỰC HÀNH LAB 1
-- CHUYÊN ĐỀ: BẢO MẬT, TỐI ƯU HÓA, ISOLATION LEVELS & CHANGE TRACKING
-- Tác giả: Microsoft Principal Database Solutions Architect
-- Tên file: Antigravity_DP800_Mod2_Lab01_Security_Optimization_Deploy.sql
-- ====================================================================================

USE DP800_Review_DB;
GO

-- ====================================================================================
-- PHẦN 1: BẢO MẬT DỮ LIỆU & TUÂN THỦ (SECURITY & COMPLIANCE)
-- ====================================================================================

/*
   MẸO THI DP-800:
   1. Dynamic Data Masking (DDM): Che mờ dữ liệu ở tầng hiển thị cho user không có quyền UNMASK.
      - Các loại mask: default(), email(), partial(prefix, padding, suffix), random(start, end).
      - KHÔNG thay đổi dữ liệu lưu trữ vật lý trên đĩa.
   2. Row-Level Security (RLS): Phân quyền truy cập từng dòng dữ liệu dựa trên User/Role.
      - Sử dụng **Inline Table-Valued Function (Filter Predicate)** và **SECURITY POLICY**.
      - FILTER PREDICATE: Lọc các dòng người dùng được SELECT/UPDATE.
      - BLOCK PREDICATE: Ngăn người dùng INSERT/UPDATE dòng dữ liệu vi phạm điều kiện.
   3. Always Encrypted: Mã hóa dữ liệu tại phía Client (Client-side encryption). Server SQL hoàn toàn không có Master Key (nằm ở Azure Key Vault).
*/

-- 1.1 Dynamic Data Masking (DDM)
IF OBJECT_ID('dbo.CustomerSensitiveInfo', 'U') IS NOT NULL DROP TABLE dbo.CustomerSensitiveInfo;

CREATE TABLE dbo.CustomerSensitiveInfo (
    CustomerID INT PRIMARY KEY,
    FullName NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) MASKED WITH (FUNCTION = 'email()') NOT NULL,
    CreditCard NVARCHAR(20) MASKED WITH (FUNCTION = 'partial(2, "XXXX-XXXX-XXXX-", 4)') NOT NULL,
    Salary DECIMAL(18,2) MASKED WITH (FUNCTION = 'default()') NOT NULL,
    BonusCode INT MASKED WITH (FUNCTION = 'random(1000, 9999)') NOT NULL
);

INSERT INTO dbo.CustomerSensitiveInfo VALUES
(1, N'Nguyen Van A', 'anv@example.com', '4111-2222-3333-4444', 25000000.00, 5678),
(2, N'Tran Thi B', 'btt@example.com', '5500-8888-9999-1234', 40000000.00, 1234);

-- Thử nghiệm Phân quyền & Test DDM
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'AppUserReadOnly') DROP USER AppUserReadOnly;
CREATE USER AppUserReadOnly WITHOUT LOGIN;
GRANT SELECT ON dbo.CustomerSensitiveInfo TO AppUserReadOnly;

-- Giả lập truy vấn dưới quyền AppUserReadOnly (Dữ liệu sẽ bị Mask)
EXECUTE AS USER = 'AppUserReadOnly';
SELECT * FROM dbo.CustomerSensitiveInfo;
REVERT;
GO

-- 1.2 Row-Level Security (RLS) - Lọc dữ liệu theo chi nhánh / User
IF OBJECT_ID('dbo.SalesDataByRegion', 'U') IS NOT NULL DROP TABLE dbo.SalesDataByRegion;
IF EXISTS (SELECT * FROM sys.security_policies WHERE name = 'SecPol_SalesDataByRegion') DROP SECURITY POLICY SecPol_SalesDataByRegion;
IF OBJECT_ID('dbo.fn_SalesRegionSecurityPredicate', 'IF') IS NOT NULL DROP FUNCTION dbo.fn_SalesRegionSecurityPredicate;

CREATE TABLE dbo.SalesDataByRegion (
    SaleID INT PRIMARY KEY,
    Region VARCHAR(20) NOT NULL, -- 'North', 'South', 'Central'
    Amount DECIMAL(18,2) NOT NULL
);

INSERT INTO dbo.SalesDataByRegion VALUES 
(101, 'North', 1500.00), (102, 'South', 2300.00), (103, 'Central', 950.00);
GO

-- Inline TVF đóng vai trò Predicate Function cho RLS
CREATE FUNCTION dbo.fn_SalesRegionSecurityPredicate (@Region AS VARCHAR(20))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN (
    SELECT 1 AS fn_securitypredicate_result
    WHERE 
        -- Admin xem được tất cả
        IS_MEMBER('db_owner') = 1 
        -- Hoặc USER name trùng khớp với tên Region
        OR USER_NAME() = @Region
);
GO

-- Tạo Security Policy kết nối Predicate với Bảng
CREATE SECURITY POLICY SecPol_SalesDataByRegion
ADD FILTER PREDICATE dbo.fn_SalesRegionSecurityPredicate(Region) ON dbo.SalesDataByRegion,
ADD BLOCK PREDICATE dbo.fn_SalesRegionSecurityPredicate(Region) ON dbo.SalesDataByRegion AFTER INSERT
WITH (STATE = ON);
GO

-- 1.3 Phân quyền đối tượng (Object-Level Permissions & Granular Access)
-- Tạo Role chuyên biệt cho Báo cáo
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'ReportingRole') DROP ROLE ReportingRole;
CREATE ROLE ReportingRole;

-- Cấp quyền hạn chế (Nội dung thi DP-800: Principle of Least Privilege)
GRANT SELECT ON dbo.SalesOrderHeader TO ReportingRole;
DENY SELECT ON dbo.CustomerSensitiveInfo TO ReportingRole;
GO


-- ====================================================================================
-- PHẦN 2: TỐI ƯU HÓA HIỆU SUẤT & TRANSACTION ISOLATION LEVELS
-- ====================================================================================

/*
   MẸO THI DP-800:
   1. Read Committed Snapshot Isolation (RCSI):
      - Bật `SET READ_COMMITTED_SNAPSHOT ON` trên database giúp người đọc (SELECT) không khóa người viết (UPDATE) và ngược lại (No Reader/Writer blocking). Dùng Row Versioning trong TempDB.
   2. Snapshot Isolation (SI):
      - Cần bật `ALLOW_SNAPSHOT_ISOLATION ON`. Cho phép giao dịch đọc nhất quán tại thời điểm bắt đầu transaction mà không gây lock.
   3. Diagnosing Performance Issues (DMVs & Query Store):
      - `sys.dm_exec_requests`, `sys.dm_tran_locks`: Tìm blocking / deadlocks.
      - Query Store (`sys.query_store_runtime_stats`): Phát hiện Parameter Sniffing và Regression Plan.
*/

-- 2.1 Bật Read Committed Snapshot Isolation (RCSI)
ALTER DATABASE CURRENT SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
ALTER DATABASE CURRENT SET ALLOW_SNAPSHOT_ISOLATION ON;
GO

-- 2.2 Đọc thông tin Blocking & Deadlocks từ DMVs (DP-800 Diagnostic Queries)
-- Tìm các Session đang bị Blocking
SELECT 
    r.session_id AS BlockedSessionID,
    r.blocking_session_id AS BlockingSessionID,
    r.wait_type,
    r.wait_time,
    r.wait_resource,
    t.text AS BlockedQueryText
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.blocking_session_id <> 0;
GO

-- 2.3 Cấu hình Query Store tối ưu cho Azure SQL / SQL Server
ALTER DATABASE CURRENT SET QUERY_STORE = ON (
    OPERATION_MODE = READ_WRITE,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    MAX_STORAGE_SIZE_MB = 1000,
    QUERY_CAPTURE_MODE = AUTO
);
GO


-- ====================================================================================
-- PHẦN 3: INTEGRATE WITH AZURE SERVICES & DATA CHANGE TRACKING (CDC, CT, CES)
-- ====================================================================================

/*
   MẸO THI DP-800:
   - Change Data Capture (CDC): Bắt trọn vẹn toàn bộ các thay đổi DML (INSERT, UPDATE, DELETE) cùng với dữ liệu cũ/mới để đồng bộ sang Data Lake/Event Hubs.
   - Change Tracking (CT): Chỉ ghi nhận "Dòng nào đã bị sửa" (Primary Key + Version) mà không lưu dữ liệu cũ. Nhẹ hơn CDC.
   - Change Event Streaming (CES): Đẩy sự kiện theo thời gian thực tới Azure Event Grid/Functions.
*/

-- 3.1 Bật Change Tracking ở cấp Database & Table
ALTER DATABASE CURRENT SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);

ALTER TABLE dbo.SalesOrderHeader
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);
GO

-- Truy vấn các dòng bị thay đổi từ phiên làm việc trước (Change Tracking query)
DECLARE @last_sync_version BIGINT = 0;

SELECT 
    ct.OrderID,
    ct.SYS_CHANGE_OPERATION, -- 'I' (Insert), 'U' (Update), 'D' (Delete)
    ct.SYS_CHANGE_COLUMNS,
    h.CustomerID,
    h.TotalAmount
FROM CHANGETABLE(CHANGES dbo.SalesOrderHeader, @last_sync_version) AS ct
LEFT JOIN dbo.SalesOrderHeader h ON ct.OrderID = h.OrderID;
GO
