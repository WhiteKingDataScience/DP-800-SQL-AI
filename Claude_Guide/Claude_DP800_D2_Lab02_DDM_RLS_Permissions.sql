/*═══════════════════════════════════════════════════════════════════════════════
  DP-800 | MIỀN 2 | LAB 02 — DDM, ROW-LEVEL SECURITY & QUYỀN
  Đi kèm: Claude_DP800_D2_SecurityPerfDeploy_Guide.md  (mục 3, 4, 5)

  PHẦN A — Dynamic Data Masking      (S1..S3)
  PHẦN B — Row-Level Security        (S4..S7)
  PHẦN C — Quyền & ownership chaining (S8..S11)

  Lab dùng EXECUTE AS USER để "đóng vai" từng người dùng — không cần tạo login thật.
═══════════════════════════════════════════════════════════════════════════════*/

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
IF DB_ID('DP800_Sec') IS NOT NULL
BEGIN
    ALTER DATABASE DP800_Sec SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DP800_Sec;
END;
GO
CREATE DATABASE DP800_Sec;
GO
/*  ⚠ Đặt chủ sở hữu database về một principal PHÂN GIẢI ĐƯỢC.
    Nếu 'dbo' đang ánh xạ tới một tài khoản Windows không còn tồn tại (máy đổi tên,
    user bị xoá khỏi domain), mọi 'WITH EXECUTE AS OWNER' sẽ hỏng với lỗi
    "Could not obtain information about Windows NT group/user ... error code 0x534".
    Đây cũng là sự cố thường gặp ngoài production sau khi khôi phục DB sang máy khác. */
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'sa')
    ALTER AUTHORIZATION ON DATABASE::DP800_Sec TO sa;
GO
USE DP800_Sec;
GO
CREATE SCHEMA Sales;
GO
CREATE SCHEMA Security;
GO


/*═══════════════════ PHẦN A — DYNAMIC DATA MASKING ═══════════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 1 — KHAI BÁO MASK
───────────────────────────────────────────────────────────────────────────────*/
CREATE TABLE Sales.Customer
(
    CustomerId  INT IDENTITY PRIMARY KEY,
    TenantId    INT           NOT NULL,
    FullName    NVARCHAR(100) NOT NULL,
    Email       NVARCHAR(100) MASKED WITH (FUNCTION = 'email()')            NULL,
    Phone       VARCHAR(20)   MASKED WITH (FUNCTION = 'partial(3,"XXXX",2)') NULL,
    NationalId  VARCHAR(12)   MASKED WITH (FUNCTION = 'default()')          NULL,
    CreditLimit DECIMAL(19,4) MASKED WITH (FUNCTION = 'random(1, 100)')     NULL,
    BirthDate   DATE          MASKED WITH (FUNCTION = 'default()')          NULL
);
GO
INSERT Sales.Customer (TenantId, FullName, Email, Phone, NationalId, CreditLimit, BirthDate) VALUES
 (1, N'Công ty A', 'ceo@congtya.vn',  '0912345678', '001099001234', 500000000, '1985-03-12'),
 (1, N'Công ty B', 'kt@congtyb.vn',   '0987654321', '001099005678', 250000000, '1990-07-25'),
 (2, N'Công ty C', 'admin@ctyc.com',  '0901112223', '001099009012', 900000000, '1978-11-02'),
 (2, N'Công ty D', 'info@ctyd.com',   '0934445556', '001099003456', 120000000, '1995-01-30');
GO

-- Xem metadata mask
SELECT  c.name AS ColumnName, c.is_masked, c.masking_function
FROM    sys.masked_columns c
WHERE   c.object_id = OBJECT_ID('Sales.Customer');
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 2 — AI THẤY GÌ? (UNMASK vs không)
───────────────────────────────────────────────────────────────────────────────*/
CREATE USER SupportUser WITHOUT LOGIN;      -- nhân viên hỗ trợ
CREATE USER PrivacyUser WITHOUT LOGIN;      -- người được xem dữ liệu thật
GO
GRANT SELECT ON SCHEMA::Sales TO SupportUser, PrivacyUser;
GRANT UNMASK TO PrivacyUser;                -- cấp toàn database
GO

PRINT '--- Chủ sở hữu (dbo) luôn thấy dữ liệu THẬT ---';
SELECT TOP (2) FullName, Email, Phone, NationalId, CreditLimit, BirthDate FROM Sales.Customer;

EXECUTE AS USER = 'SupportUser';
    PRINT '--- SupportUser: dữ liệu BỊ CHE ---';
    SELECT TOP (2) FullName, Email, Phone, NationalId, CreditLimit, BirthDate FROM Sales.Customer;
REVERT;

EXECUTE AS USER = 'PrivacyUser';
    PRINT '--- PrivacyUser (có UNMASK): dữ liệu THẬT ---';
    SELECT TOP (2) FullName, Email, Phone, NationalId, CreditLimit, BirthDate FROM Sales.Customer;
REVERT;
GO
/*  ĐỌC KẾT QUẢ:
      email()            → aXXX@XXXX.com
      partial(3,"XXXX",2)→ 091XXXX78   (giữ 3 đầu + 2 cuối)
      default() chuỗi    → xxxx
      default() ngày     → 1900-01-01
      random(1,100)      → số ngẫu nhiên, ĐỔI SAU MỖI LẦN CHẠY

    ⚠ Từ SQL Server 2022, UNMASK cấp được ở mức chi tiết:
        GRANT UNMASK ON Sales.Customer(Email) TO SupportUser;   -- chỉ mở 1 cột
        GRANT UNMASK ON SCHEMA::Sales TO SomeRole;
      Bản cũ chỉ có UNMASK ở cấp database (all-or-nothing).                      */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 3 — ⚠ DDM CÓ THỂ BỊ VƯỢT QUA — LÝ DO KHÔNG COI LÀ BẢO MẬT THẬT
───────────────────────────────────────────────────────────────────────────────*/
EXECUTE AS USER = 'SupportUser';

    PRINT '--- Tấn công 1: suy luận qua WHERE (dò nhị phân) ---';
    SELECT FullName, 'CreditLimit > 400 triệu' AS SuyLuan
    FROM   Sales.Customer
    WHERE  CreditLimit > 400000000;      -- mask KHÔNG áp dụng cho vị từ WHERE!

    PRINT '--- Tấn công 2: đẩy sang bảng tạm (bản cũ không kế thừa mask) ---';
    SELECT CustomerId, Email, NationalId INTO #leak FROM Sales.Customer;
    SELECT * FROM #leak;
    DROP TABLE #leak;

REVERT;
GO
/*  🎯 KẾT LUẬN THI:
      DDM chỉ CHE KHI HIỂN THỊ. Dữ liệu trên đĩa vẫn plaintext, vị từ WHERE vẫn
      chạy trên giá trị THẬT ⇒ người có quyền SELECT luôn dò được.
      ⇒ DDM = chống lộ vô ý trên màn hình, KHÔNG chống kẻ tấn công chủ đích.
      Nếu đề yêu cầu "chống được người dùng cố tình truy vấn" ⇒ chọn
      Always Encrypted / RLS / thu hồi quyền, KHÔNG chọn DDM.                    */


/*═══════════════════ PHẦN B — ROW-LEVEL SECURITY ═════════════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 4 — DỰNG RLS ĐA KHÁCH THUÊ (MULTI-TENANT)
───────────────────────────────────────────────────────────────────────────────*/
CREATE TABLE Sales.[Order]
(
    OrderId   INT IDENTITY PRIMARY KEY,
    TenantId  INT           NOT NULL,
    Amount    DECIMAL(19,4) NOT NULL,
    OrderDate DATE          NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
-- ⚠ Index trên cột lọc là BẮT BUỘC về hiệu năng: vị từ RLS nối vào MỌI truy vấn
CREATE INDEX IX_Order_TenantId ON Sales.[Order](TenantId);
GO
INSERT Sales.[Order] (TenantId, Amount) VALUES
 (1, 1000), (1, 2000), (1, 3000), (2, 5000), (2, 6000);
GO

CREATE USER Tenant1User WITHOUT LOGIN;
CREATE USER Tenant2User WITHOUT LOGIN;
CREATE USER AppUser     WITHOUT LOGIN;   -- ứng dụng dùng chung, phân biệt bằng SESSION_CONTEXT
GO
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Sales TO Tenant1User, Tenant2User, AppUser;
GO

-- (1) HÀM VỊ TỪ: bắt buộc inline TVF + WITH SCHEMABINDING
CREATE FUNCTION Security.fn_TenantPredicate(@TenantId INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS fn_result
    WHERE
        -- Cách 1: ánh xạ theo tên user (đơn giản, hợp khi mỗi tenant 1 user DB)
        (@TenantId = 1 AND USER_NAME() = 'Tenant1User')
     OR (@TenantId = 2 AND USER_NAME() = 'Tenant2User')
        -- Cách 2 (KHUYẾN NGHỊ cho ứng dụng dùng connection pool): SESSION_CONTEXT
     OR (@TenantId = CAST(SESSION_CONTEXT(N'TenantId') AS INT))
        -- Lối thoát cho quản trị / job bảo trì
     OR (IS_MEMBER('db_owner') = 1);
GO

-- (2) SECURITY POLICY: gắn vị từ vào bảng
CREATE SECURITY POLICY Security.TenantFilter
ADD FILTER PREDICATE Security.fn_TenantPredicate(TenantId) ON Sales.[Order],
ADD BLOCK  PREDICATE Security.fn_TenantPredicate(TenantId) ON Sales.[Order] AFTER INSERT,
ADD BLOCK  PREDICATE Security.fn_TenantPredicate(TenantId) ON Sales.[Order] AFTER UPDATE
WITH (STATE = ON, SCHEMABINDING = ON);
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 5 — CHỨNG MINH FILTER PREDICATE
───────────────────────────────────────────────────────────────────────────────*/
PRINT '--- dbo (db_owner): thấy TẤT CẢ 5 dòng ---';
SELECT TenantId, COUNT(*) AS Cnt FROM Sales.[Order] GROUP BY TenantId;

EXECUTE AS USER = 'Tenant1User';
    PRINT '--- Tenant1User: chỉ thấy TenantId = 1 ---';
    SELECT OrderId, TenantId, Amount FROM Sales.[Order];
REVERT;

EXECUTE AS USER = 'Tenant2User';
    PRINT '--- Tenant2User: chỉ thấy TenantId = 2 ---';
    SELECT OrderId, TenantId, Amount FROM Sales.[Order];
REVERT;
GO
/*  ⚠ FILTER PREDICATE ẩn dòng KHÔNG BÁO LỖI — dòng chỉ "biến mất".
    Nó áp dụng cho cả SELECT, UPDATE và DELETE (không sửa/xoá được dòng không thấy). */

-- Chứng minh UPDATE/DELETE cũng bị lọc
EXECUTE AS USER = 'Tenant1User';
    DELETE Sales.[Order] WHERE TenantId = 2;   -- 0 dòng bị xoá, KHÔNG lỗi
    SELECT @@ROWCOUNT AS SoDongXoaDuoc_CuaTenant2;
REVERT;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 6 — BLOCK PREDICATE: vì sao chỉ FILTER là CHƯA ĐỦ
───────────────────────────────────────────────────────────────────────────────*/
EXECUTE AS USER = 'Tenant1User';
BEGIN TRY
    -- Cố chèn dòng thuộc tenant khác
    INSERT Sales.[Order] (TenantId, Amount) VALUES (2, 9999);
    PRINT 'ĐÃ CHÈN ĐƯỢC (nguy hiểm!)';
END TRY
BEGIN CATCH
    SELECT 'BLOCK PREDICATE chặn INSERT' AS Demo, ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS Msg;
END CATCH;
REVERT;
GO
/*  Msg 33504 — "The attempted operation failed because the target object
                 '...' has a block predicate..."

    🎯 CÂU HỎI TỦ: nếu policy CHỈ có FILTER PREDICATE, Tenant1User VẪN chèn được
       dòng TenantId = 2 thành công — rồi dòng đó biến mất khỏi mắt họ.
       Dữ liệu bị nhiễm bẩn âm thầm. Phải có BLOCK PREDICATE AFTER INSERT.

    4 loại BLOCK PREDICATE:
       AFTER INSERT   — chặn tạo dòng không thuộc về mình
       AFTER UPDATE   — chặn "đẩy" dòng sang tenant khác (sau khi sửa)
       BEFORE UPDATE  — chặn sửa dòng không thuộc về mình
       BEFORE DELETE  — chặn xoá dòng không thuộc về mình
       (BEFORE UPDATE/DELETE thường không cần nếu đã có FILTER, vì FILTER đã ẩn dòng.) */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 7 — SESSION_CONTEXT: cách chuẩn cho ứng dụng dùng connection pool
───────────────────────────────────────────────────────────────────────────────*/
EXECUTE AS USER = 'AppUser';

    PRINT '--- AppUser chưa set context: KHÔNG thấy dòng nào ---';
    SELECT COUNT(*) AS RowsVisible FROM Sales.[Order];

    -- Ứng dụng gọi ngay sau khi lấy connection từ pool
    EXEC sys.sp_set_session_context @key = N'TenantId', @value = 1, @read_only = 1;

    PRINT '--- Sau khi set TenantId = 1 ---';
    SELECT OrderId, TenantId, Amount FROM Sales.[Order];
    SELECT SESSION_CONTEXT(N'TenantId') AS CurrentTenant;

    -- @read_only = 1 ⇒ KHÔNG thể đổi trong cùng phiên (chống SQL injection leo thang)
    BEGIN TRY
        EXEC sys.sp_set_session_context @key = N'TenantId', @value = 2;
    END TRY
    BEGIN CATCH
        SELECT 'read_only chặn ghi đè' AS Demo, ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS Msg;
    END CATCH;

REVERT;
GO
/*  🎯 @read_only = 1 là chi tiết ĐẮT GIÁ trong đề: nếu không đặt, kẻ tấn công
    khai thác được SQL injection có thể tự đổi TenantId để đọc dữ liệu tenant khác.

    SO SÁNH CÁCH TRUYỀN DANH TÍNH:
      SESSION_CONTEXT()   ✅ khuyến nghị — hợp connection pool, có @read_only
      USER_NAME() / DATABASE_PRINCIPAL_ID()  ✅ an toàn, nhưng cần 1 DB user/tenant
      SUSER_SNAME()       ✅ an toàn (danh tính cấp server)
      APP_NAME()          ❌ KHÔNG an toàn — client tự đặt tuỳ ý trong connection string
      CONTEXT_INFO()      ⚠ cũ, chỉ 128 byte, không có read_only                 */

-- Kiểm tra policy hiện có
SELECT  p.name AS PolicyName, p.is_enabled, p.is_schema_bound,
        OBJECT_NAME(pr.target_object_id) AS TargetTable,
        pr.predicate_type_desc, pr.predicate_definition, pr.operation_desc
FROM    sys.security_policies p
JOIN    sys.security_predicates pr ON pr.object_id = p.object_id;

-- Tắt/bật policy (chỉ người có ALTER ANY SECURITY POLICY làm được ⇒ đừng cấp cho app)
-- ALTER SECURITY POLICY Security.TenantFilter WITH (STATE = OFF);
GO


/*═══════════════════ PHẦN C — QUYỀN & OWNERSHIP CHAINING ═════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 8 — THỨ TỰ ƯU TIÊN: DENY > GRANT
───────────────────────────────────────────────────────────────────────────────*/
CREATE TABLE dbo.Secret (Id INT PRIMARY KEY, Info NVARCHAR(100));
INSERT dbo.Secret VALUES (1, N'thông tin mật');
GO
CREATE ROLE ReaderRole;
GRANT SELECT ON dbo.Secret TO ReaderRole;

CREATE USER TestUser WITHOUT LOGIN;
ALTER ROLE ReaderRole ADD MEMBER TestUser;
GO

EXECUTE AS USER = 'TestUser';
    SELECT 'Qua role: đọc được' AS Step, COUNT(*) AS Cnt FROM dbo.Secret;
REVERT;
GO

-- Bây giờ DENY trực tiếp cho cá nhân
DENY SELECT ON dbo.Secret TO TestUser;
GO
EXECUTE AS USER = 'TestUser';
BEGIN TRY
    SELECT COUNT(*) FROM dbo.Secret;
END TRY
BEGIN CATCH
    SELECT 'DENY THẮNG GRANT của role' AS Demo, ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS Msg;
END CATCH;
REVERT;
GO

-- ⚠ GRANT thêm KHÔNG gỡ được DENY — phải REVOKE cái DENY
GRANT SELECT ON dbo.Secret TO TestUser;
GO
EXECUTE AS USER = 'TestUser';
BEGIN TRY
    SELECT COUNT(*) FROM dbo.Secret;
    PRINT 'Đọc được';
END TRY
BEGIN CATCH
    SELECT 'GRANT vẫn KHÔNG gỡ được DENY' AS Demo, ERROR_MESSAGE() AS Msg;
END CATCH;
REVERT;
GO
REVOKE SELECT ON dbo.Secret TO TestUser;   -- gỡ cả GRANT lẫn DENY cấp cá nhân
GO
EXECUTE AS USER = 'TestUser';
    SELECT 'Sau REVOKE, quyền của role có hiệu lực lại' AS Step, COUNT(*) AS Cnt FROM dbo.Secret;
REVERT;
GO
/*  🎯 GHI NHỚ: DENY > GRANT > (không có gì).
      REVOKE = "xoá dòng cấp quyền", KHÔNG phải "cấm".
      Ngoại lệ duy nhất: sysadmin bỏ qua mọi kiểm tra quyền.                     */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 9 — OWNERSHIP CHAINING: cho chạy proc mà không cấp quyền bảng
───────────────────────────────────────────────────────────────────────────────*/
CREATE TABLE dbo.Payroll (EmpId INT PRIMARY KEY, Salary DECIMAL(19,4));
INSERT dbo.Payroll VALUES (1, 50000000), (2, 72000000);
GO
CREATE PROCEDURE dbo.usp_GetPayrollTotal
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SUM(Salary) AS TotalPayroll FROM dbo.Payroll;
END;
GO
CREATE USER ReportUser WITHOUT LOGIN;
GRANT EXECUTE ON dbo.usp_GetPayrollTotal TO ReportUser;   -- KHÔNG cấp SELECT lên bảng
GO

EXECUTE AS USER = 'ReportUser';
    PRINT '--- Chạy proc: OK nhờ ownership chaining (proc và bảng cùng owner dbo) ---';
    EXEC dbo.usp_GetPayrollTotal;

    PRINT '--- Truy vấn bảng trực tiếp: BỊ CHẶN ---';
    BEGIN TRY
        SELECT * FROM dbo.Payroll;
    END TRY
    BEGIN CATCH
        SELECT 'Không có quyền trên bảng' AS Demo, ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS Msg;
    END CATCH;
REVERT;
GO
/*  🎯 ĐÂY LÀ ĐÁP ÁN CHUẨN cho "cho phép người dùng thực hiện thao tác mà không
      cấp quyền trực tiếp lên bảng" ⇒ OWNERSHIP CHAINING qua stored procedure/view. */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 10 — CHUỖI SỞ HỮU BỊ ĐỨT: SQL ĐỘNG
───────────────────────────────────────────────────────────────────────────────*/
CREATE PROCEDURE dbo.usp_GetPayrollDynamic
AS
BEGIN
    SET NOCOUNT ON;
    EXEC(N'SELECT SUM(Salary) AS TotalPayroll FROM dbo.Payroll;');   -- ⚠ SQL động
END;
GO
GRANT EXECUTE ON dbo.usp_GetPayrollDynamic TO ReportUser;
GO
EXECUTE AS USER = 'ReportUser';
BEGIN TRY
    EXEC dbo.usp_GetPayrollDynamic;
END TRY
BEGIN CATCH
    SELECT 'SQL động LÀM ĐỨT chuỗi sở hữu' AS Demo, ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS Msg;
END CATCH;
REVERT;
GO

/*  BA CÁCH SỬA — thứ tự ưu tiên trong đề thi: */

-- Cách 1: EXECUTE AS OWNER (đơn giản, nhưng MẤT danh tính người gọi cho audit)
CREATE PROCEDURE dbo.usp_GetPayrollAsOwner
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ORIGINAL_LOGIN() AS AiGoi, USER_NAME() AS DangChayDuoiDanhTinh;
    EXEC(N'SELECT SUM(Salary) AS TotalPayroll FROM dbo.Payroll;');
END;
GO
GRANT EXECUTE ON dbo.usp_GetPayrollAsOwner TO ReportUser;
GO
/*  ⚠ QUY TẮC AN TOÀN KHI DÙNG EXECUTE AS:
    Lỗi ở mức HUỶ BATCH sẽ bỏ qua câu REVERT còn lại ⇒ ngữ cảnh giả danh RÒ RỈ
    sang các batch sau (mọi lệnh quản trị tiếp theo sẽ báo "User does not have
    permission"). Luôn bọc TRY...CATCH và REVERT trong CATCH, hoặc REVERT ở batch riêng. */
BEGIN TRY
    EXECUTE AS USER = 'ReportUser';
    EXEC dbo.usp_GetPayrollAsOwner;
    REVERT;
END TRY
BEGIN CATCH
    SELECT 'EXECUTE AS OWNER' AS Demo, ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS Msg;
    IF ORIGINAL_LOGIN() <> SUSER_SNAME() REVERT;
END CATCH;
GO
-- Chốt chặn: bảo đảm đã quay về danh tính gốc trước khi chạy tiếp
IF USER_NAME() <> 'dbo' REVERT;
GO
/*  Ghi chú: bên trong EXECUTE AS OWNER, USER_NAME() trả về 'dbo' — audit chỉ thấy dbo.
    Dùng ORIGINAL_LOGIN() để lấy lại danh tính thật của người gọi.

    Cách 2 (SẠCH NHẤT, đáp án "best practice"): MODULE SIGNING
      CREATE CERTIFICATE SignCert WITH SUBJECT = 'Module signing';
      ADD SIGNATURE TO dbo.usp_GetPayrollDynamic BY CERTIFICATE SignCert;
      CREATE USER CertUser FROM CERTIFICATE SignCert;
      GRANT SELECT ON dbo.Payroll TO CertUser;
    ⇒ Quyền được "mượn" đúng phạm vi module, danh tính người gọi được GIỮ NGUYÊN
      (audit vẫn ghi đúng người), không cần EXECUTE AS.

    Cách 3 (KÉM NHẤT): cấp thẳng SELECT lên bảng — vi phạm least privilege.

    ⚠ Cross-database ownership chaining mặc định TẮT và nên để TẮT (rủi ro leo thang
      đặc quyền). Nếu buộc phải truy cập chéo DB ⇒ dùng module signing.            */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 11 — CẤP QUYỀN THEO SCHEMA & KIỂM KÊ QUYỀN
───────────────────────────────────────────────────────────────────────────────*/
-- ✅ Least privilege: cấp cho ROLE, ở mức SCHEMA (tự động áp cho bảng tạo sau này)
CREATE ROLE SalesReader;
GRANT SELECT ON SCHEMA::Sales TO SalesReader;
DENY  SELECT ON Sales.Customer(NationalId) TO SalesReader;   -- DENY tới từng CỘT
GO

-- Kiểm kê toàn bộ quyền tường minh trong database (dùng được ngoài đời thật)
SELECT  pr.name             AS Principal,
        pr.type_desc        AS PrincipalType,
        pe.state_desc       AS Action,          -- GRANT / DENY / GRANT_WITH_GRANT_OPTION
        pe.permission_name,
        pe.class_desc,
        CASE pe.class
             WHEN 0 THEN DB_NAME()
             WHEN 1 THEN OBJECT_SCHEMA_NAME(pe.major_id) + '.' + OBJECT_NAME(pe.major_id)
                         + ISNULL(' (cột: ' + COL_NAME(pe.major_id, pe.minor_id) + ')', '')
             WHEN 3 THEN 'SCHEMA::' + SCHEMA_NAME(pe.major_id)
             ELSE CAST(pe.major_id AS VARCHAR(20))
        END                 AS SecurableName
FROM    sys.database_permissions pe
JOIN    sys.database_principals pr ON pr.principal_id = pe.grantee_principal_id
WHERE   pr.name NOT IN ('public','dbo','guest','INFORMATION_SCHEMA','sys')
ORDER BY Principal, SecurableName;

-- Quyền HIỆU DỤNG của một người dùng cụ thể (gộp cả role) — rất hữu ích khi debug
EXECUTE AS USER = 'ReportUser';
    SELECT  entity_name, permission_name, subentity_name
    FROM    sys.fn_my_permissions('dbo.Payroll', 'OBJECT');
    SELECT  USER_NAME()                       AS CurrentUser,
            IS_MEMBER('db_owner')             AS IsDbOwner,
            HAS_PERMS_BY_NAME('dbo.Payroll','OBJECT','SELECT') AS CanSelectPayroll,
            HAS_PERMS_BY_NAME('dbo.usp_GetPayrollTotal','OBJECT','EXECUTE') AS CanExecProc;
REVERT;
GO
/*  DATABASE ROLE DỰNG SẴN cần nhớ:
      db_owner              — toàn quyền trong DB
      db_datareader/writer  — đọc/ghi MỌI bảng (thô, thường KHÔNG nên dùng)
      db_ddladmin           — tạo/sửa/xoá đối tượng
      db_securityadmin      — quản lý quyền và role  ⚠ có thể tự leo thang đặc quyền
      db_accessadmin        — quản lý quyền truy cập DB
      db_backupoperator     — sao lưu
      db_denydatareader/writer — chặn đọc/ghi mọi bảng

    SERVER ROLE:
      sysadmin, securityadmin (⚠ tương đương sysadmin vì cấp được quyền), serveradmin,
      dbcreator, bulkadmin, processadmin, diskadmin, setupadmin, public
    ⇒ Trên Azure SQL Database KHÔNG có server role truyền thống; dùng
      loginmanager/dbmanager trong `master`, hoặc các server-level role mới
      (##MS_DatabaseConnector##, ##MS_DefinitionReader##, ...).                   */


/*───────────────────────────────────────────────────────────────────────────────
  DỌN DẸP
───────────────────────────────────────────────────────────────────────────────*/
-- USE master;
-- ALTER DATABASE DP800_Sec SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
-- DROP DATABASE DP800_Sec;

/*═══════════════════════════════════════════════════════════════════════════════
  CHECKLIST SAU LAB 02
  □ Kể 5 hàm mask và kết quả của từng hàm.
  □ Nêu 2 cách vượt qua DDM ⇒ giải thích vì sao DDM không phải bảo mật thật.
  □ Viết được hàm vị từ RLS đúng chuẩn (inline TVF + SCHEMABINDING).
  □ Giải thích hậu quả nếu chỉ có FILTER mà thiếu BLOCK PREDICATE.
  □ Biết vì sao SESSION_CONTEXT phải đặt @read_only = 1.
  □ Nhớ APP_NAME() KHÔNG an toàn để nhận diện người dùng.
  □ Giải thích DENY > GRANT và vì sao GRANT thêm không gỡ được DENY.
  □ Nêu 3 cách xử lý khi chuỗi sở hữu bị đứt, và cách nào là best practice.
═══════════════════════════════════════════════════════════════════════════════*/
