/*═══════════════════════════════════════════════════════════════════════════════
  DP-800 | MIỀN 2 | LAB 05 — TRIỂN KHAI, CI/CD & KIỂM THỬ
  Đi kèm: Claude_DP800_D2_SecurityPerfDeploy_Guide.md  (mục 8)

  SECTION 1..3  — DACPAC / BACPAC / SqlPackage (tham chiếu lệnh CLI)
  SECTION 4..5  — SQL Database Project & pipeline CI/CD
  SECTION 6..8  — Kiểm thử: khung tSQLt tự viết, chạy được ngay
  SECTION 9..11 — Migration, nâng cấp có kiểm soát, backup/restore, Azure

  ⚠ Phần CLI (sqlpackage, dotnet, YAML) để dạng chú thích — đọc và ghi nhớ cú pháp.
    Phần T-SQL đều chạy được thật.
═══════════════════════════════════════════════════════════════════════════════*/

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
IF DB_ID('DP800_Deploy') IS NOT NULL
BEGIN
    ALTER DATABASE DP800_Deploy SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DP800_Deploy;
END;
GO
CREATE DATABASE DP800_Deploy;
GO
USE DP800_Deploy;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 1 — DACPAC vs BACPAC (câu hỏi gần như chắc chắn có trong đề)
───────────────────────────────────────────────────────────────────────────────*/
/*
 ┌──────────────┬────────────────────────────┬───────────────────────────────────┐
 │              │ .dacpac                    │ .bacpac                           │
 ├──────────────┼────────────────────────────┼───────────────────────────────────┤
 │ Chứa         │ CHỈ SCHEMA (định nghĩa)    │ SCHEMA + DỮ LIỆU                  │
 │ Mục đích     │ Triển khai/đồng bộ schema  │ Di chuyển, lưu trữ, sao chép DB   │
 │ Hành động    │ Extract / Publish          │ Export / Import                   │
 │ Tính chất    │ Tăng dần (so sánh & cập nhật)│ Toàn bộ (tạo DB mới)            │
 │ Dùng khi     │ CI/CD, cập nhật schema     │ Đưa DB on-prem lên Azure SQL      │
 │ Giữ dữ liệu? │ CÓ (dữ liệu đích giữ nguyên)│ Thay thế hoàn toàn               │
 └──────────────┴────────────────────────────┴───────────────────────────────────┘
 🎯 MẸO NHỚ: chữ "B" trong BACPAC = "Backup-like" = có DATA.

 ⚠ .bacpac KHÔNG phải backup: không nhất quán về mặt giao dịch (transactionally
   inconsistent) nếu database đang có hoạt động ⇒ export từ bản sao/copy,
   hoặc dùng backup thật (.bak) khi cần khôi phục.
*/


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 2 — SQLPACKAGE: 6 ACTION VÀ THAM SỐ AN TOÀN
───────────────────────────────────────────────────────────────────────────────*/
/*
 # 1) EXTRACT — DB đang chạy  →  .dacpac (chỉ schema)
 sqlpackage /Action:Extract ^
   /SourceServerName:"localhost" /SourceDatabaseName:"DP800_Deploy" ^
   /TargetFile:"C:\build\DP800.dacpac" ^
   /p:ExtractAllTableData=False

 # 2) PUBLISH — .dacpac  →  DB đích (so sánh và cập nhật TĂNG DẦN)
 sqlpackage /Action:Publish ^
   /SourceFile:"C:\build\DP800.dacpac" ^
   /TargetServerName:"prod.database.windows.net" /TargetDatabaseName:"AppDb" ^
   /TargetUser:"deployer" /TargetPassword:"$(SqlPassword)" ^
   /p:BlockOnPossibleDataLoss=True ^
   /p:DropObjectsNotInSource=False ^
   /p:GenerateSmartDefaults=True ^
   /p:BackupDatabaseBeforeChanges=True

 # 3) SCRIPT — chỉ SINH script T-SQL để người duyệt xem trước
 #    🎯 BẮT BUỘC cho production: không bao giờ publish thẳng mà không review
 sqlpackage /Action:Script ^
   /SourceFile:"C:\build\DP800.dacpac" ^
   /TargetServerName:"prod..." /TargetDatabaseName:"AppDb" ^
   /OutputPath:"C:\build\deploy.sql"

 # 4) DEPLOYREPORT — báo cáo XML các thay đổi + CẢNH BÁO MẤT DỮ LIỆU
 sqlpackage /Action:DeployReport /SourceFile:... /OutputPath:"C:\build\report.xml"

 # 5) EXPORT — DB  →  .bacpac (schema + data)
 sqlpackage /Action:Export ^
   /SourceServerName:"localhost" /SourceDatabaseName:"DP800_Deploy" ^
   /TargetFile:"C:\build\DP800.bacpac"

 # 6) IMPORT — .bacpac  →  DB MỚI (thường là Azure SQL)
 sqlpackage /Action:Import ^
   /SourceFile:"C:\build\DP800.bacpac" ^
   /TargetServerName:"myserver.database.windows.net" /TargetDatabaseName:"AppDb" ^
   /TargetUser:"admin" /TargetPassword:"$(SqlPassword)"

 THAM SỐ AN TOÀN CẦN THUỘC:
   /p:BlockOnPossibleDataLoss=True   (MẶC ĐỊNH True) — dừng nếu thao tác có thể mất dữ liệu
                                      🎯 Đề hỏi "vì sao deploy thất bại với thông báo
                                         possible data loss?" ⇒ đổi kiểu/thu hẹp cột.
   /p:DropObjectsNotInSource=True    — NGUY HIỂM: xoá mọi thứ không có trong dacpac
   /p:IncludeTransactionalScripts=True — bọc trong transaction để rollback được
   /p:ExcludeObjectTypes=Users;Logins;RoleMembership — không đè quyền của môi trường đích
   /p:GenerateSmartDefaults=True     — tự thêm DEFAULT khi thêm cột NOT NULL vào bảng có dữ liệu
   /p:CommandTimeout=600
   /p:VerifyDeployment=True

 XÁC THỰC HIỆN ĐẠI (Azure — KHÔNG dùng mật khẩu trong pipeline):
   /AccessToken:$(token)
   /UniversalAuthentication:True
   /p:AuthenticationType=ActiveDirectoryManagedIdentity
*/


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 3 — MÔ PHỎNG "POSSIBLE DATA LOSS" NGAY TRONG T-SQL
───────────────────────────────────────────────────────────────────────────────*/
CREATE TABLE dbo.Product
(
    ProductId INT IDENTITY PRIMARY KEY,
    Name      NVARCHAR(200) NOT NULL,
    Price     DECIMAL(19,4) NOT NULL
);
INSERT dbo.Product (Name, Price) VALUES (N'Sản phẩm có tên rất dài để minh hoạ', 100);
GO

-- Thu hẹp cột = thao tác SqlPackage sẽ CHẶN với BlockOnPossibleDataLoss=True
BEGIN TRY
    ALTER TABLE dbo.Product ALTER COLUMN Name NVARCHAR(10) NOT NULL;
END TRY
BEGIN CATCH
    SELECT 'Thu hẹp cột gây mất dữ liệu' AS Demo, ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS Msg;
END CATCH;
GO

-- Thêm cột NOT NULL vào bảng ĐÃ CÓ dữ liệu mà không có DEFAULT
BEGIN TRY
    ALTER TABLE dbo.Product ADD CategoryId INT NOT NULL;
END TRY
BEGIN CATCH
    SELECT 'Thêm cột NOT NULL không DEFAULT' AS Demo, ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS Msg;
END CATCH;
GO
-- Cách đúng (chính là điều /p:GenerateSmartDefaults=True làm giúp bạn)
ALTER TABLE dbo.Product ADD CategoryId INT NOT NULL CONSTRAINT DF_Product_Category DEFAULT (0);
GO
SELECT * FROM dbo.Product;
GO
/*  🎯 BÀI HỌC TRIỂN KHAI:
      Các thay đổi schema KHÔNG tương thích ngược cần chiến lược nhiều bước
      (expand → migrate → contract):
        Bước 1 (expand)  : thêm cột mới, cho phép NULL, deploy
        Bước 2 (migrate) : nạp dữ liệu vào cột mới, ứng dụng ghi cả 2 cột
        Bước 3 (contract): sau khi mọi phiên bản ứng dụng đã lên, siết NOT NULL,
                           xoá cột cũ
      Đây là cách deploy KHÔNG DOWNTIME, hay được hỏi ở dạng "rolling deployment".  */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 4 — SQL DATABASE PROJECT (SDK-style) & PIPELINE
───────────────────────────────────────────────────────────────────────────────*/
/*
 CẤU TRÚC PROJECT (Microsoft.Build.Sql — thay thế SSDT cũ, chạy đa nền tảng):

   AppDb/
     AppDb.sqlproj              ← <Project Sdk="Microsoft.Build.Sql/1.x">
     Tables/Product.sql         ← mỗi đối tượng 1 file, CREATE (không phải ALTER)
     Tables/Order.sql
     Views/vSales.sql
     Procedures/usp_GetOrders.sql
     Security/Roles.sql
     Scripts/PostDeployment.sql ← dữ liệu tham chiếu (dùng MERGE để idempotent)
     Scripts/PreDeployment.sql
     AppDb.publish.xml          ← hồ sơ publish cho từng môi trường

 BUILD:   dotnet build AppDb.sqlproj -c Release      →  bin/Release/AppDb.dacpac

 ─────────────────────────────────────────────────────────────────────────────
 AZURE DEVOPS PIPELINE (azure-pipelines.yml) — cấu trúc chuẩn:

 trigger: [ main ]
 stages:
 - stage: Build
   jobs:
   - job: BuildDacpac
     steps:
     - task: DotNetCoreCLI@2
       inputs: { command: build, projects: 'src/AppDb/AppDb.sqlproj', arguments: '-c Release' }
     - publish: 'src/AppDb/bin/Release/AppDb.dacpac'
       artifact: dacpac

 - stage: DeployDev
   jobs:
   - deployment: Dev
     environment: dev
     strategy: { runOnce: { deploy: { steps:
       - task: SqlAzureDacpacDeployment@1
         inputs:
           azureSubscription: 'sc-dev'          # service connection (managed identity)
           ServerName: 'dev.database.windows.net'
           DatabaseName: 'AppDb'
           DacpacFile: '$(Pipeline.Workspace)/dacpac/AppDb.dacpac'
           AdditionalArguments: '/p:BlockOnPossibleDataLoss=True'
       - script: |                              # chạy unit test tSQLt
           sqlcmd -S dev... -d AppDb -Q "EXEC tSQLt.RunAll"
     }}}

 - stage: DeployProd
   dependsOn: DeployDev
   jobs:
   - deployment: Prod
     environment: prod          # ← gắn APPROVAL GATE ở đây
     strategy: { runOnce: { deploy: { steps:
       - task: SqlAzureDacpacDeployment@1
         inputs:
           DeploymentAction: 'Script'           # SINH SCRIPT trước để review
           ...
       - task: SqlAzureDacpacDeployment@1       # sau khi duyệt mới publish
           DeploymentAction: 'Publish'
     }}}

 ─────────────────────────────────────────────────────────────────────────────
 NGUYÊN TẮC CI/CD CHO DATABASE (hay được hỏi dạng "best practice"):
   1. Schema nằm trong SOURCE CONTROL — một nguồn chân lý duy nhất.
   2. Build ra artifact MỘT LẦN, deploy artifact ĐÓ lên mọi môi trường.
   3. Không bao giờ deploy thẳng lên production — luôn có approval gate + script review.
   4. Xác thực bằng managed identity / service principal, bí mật để trong Key Vault.
   5. Idempotent: chạy lại pipeline nhiều lần phải cho cùng kết quả
      (post-deployment script dùng MERGE, không dùng INSERT trần).
   6. Có kế hoạch ROLLBACK: backup trước khi deploy, hoặc script hoàn tác.
*/

-- Ví dụ post-deployment script IDEMPOTENT bằng MERGE (chạy lại bao nhiêu lần cũng đúng)
CREATE TABLE dbo.Category (CategoryId INT PRIMARY KEY, Name NVARCHAR(50) NOT NULL);
GO
MERGE dbo.Category AS tgt
USING (VALUES (1, N'Điện tử'), (2, N'Gia dụng'), (3, N'Thời trang')) AS src(CategoryId, Name)
    ON tgt.CategoryId = src.CategoryId
WHEN MATCHED AND tgt.Name <> src.Name THEN UPDATE SET tgt.Name = src.Name
WHEN NOT MATCHED BY TARGET THEN INSERT (CategoryId, Name) VALUES (src.CategoryId, src.Name)
WHEN NOT MATCHED BY SOURCE THEN DELETE;   -- ⚠ cân nhắc kỹ: xoá dữ liệu ngoài danh sách
SELECT * FROM dbo.Category;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 5 — MIGRATION-BASED: theo dõi phiên bản schema
───────────────────────────────────────────────────────────────────────────────*/
CREATE TABLE dbo.SchemaVersion
(
    VersionId   INT           NOT NULL PRIMARY KEY,
    ScriptName  NVARCHAR(200) NOT NULL,
    Checksum    VARBINARY(32) NULL,
    AppliedAt   DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    AppliedBy   SYSNAME       NOT NULL DEFAULT SUSER_SNAME(),
    DurationMs  INT           NULL
);
GO
-- Mỗi script migration bắt đầu bằng kiểm tra "đã chạy chưa" ⇒ idempotent
CREATE OR ALTER PROCEDURE dbo.usp_ApplyMigration
    @VersionId INT, @ScriptName NVARCHAR(200), @Sql NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE VersionId = @VersionId)
    BEGIN
        PRINT CONCAT('Bỏ qua V', @VersionId, ' — đã áp dụng trước đó.');
        RETURN;
    END;

    DECLARE @t0 DATETIME2(3) = SYSUTCDATETIME();
    BEGIN TRAN;
    BEGIN TRY
        EXEC sys.sp_executesql @Sql;
        INSERT dbo.SchemaVersion (VersionId, ScriptName, Checksum, DurationMs)
        VALUES (@VersionId, @ScriptName, HASHBYTES('SHA2_256', @Sql),
                DATEDIFF(MILLISECOND, @t0, SYSUTCDATETIME()));
        COMMIT;
        PRINT CONCAT('Đã áp dụng V', @VersionId, ' — ', @ScriptName);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;                          -- để pipeline FAIL, không nuốt lỗi
    END CATCH;
END;
GO

EXEC dbo.usp_ApplyMigration 1, N'V001_AddProductSku.sql',
     N'ALTER TABLE dbo.Product ADD Sku VARCHAR(20) NULL;';
EXEC dbo.usp_ApplyMigration 2, N'V002_IndexProductSku.sql',
     N'CREATE INDEX IX_Product_Sku ON dbo.Product(Sku);';
EXEC dbo.usp_ApplyMigration 1, N'V001_AddProductSku.sql',
     N'ALTER TABLE dbo.Product ADD Sku VARCHAR(20) NULL;';   -- chạy lại: BỎ QUA

SELECT * FROM dbo.SchemaVersion ORDER BY VersionId;
GO
/*  🎯 SO SÁNH HAI TRƯỜNG PHÁI:
      STATE-BASED (DACPAC/SSDT): mô tả TRẠNG THÁI MONG MUỐN, công cụ tự sinh script diff.
        ✅ Đơn giản, luôn hội tụ, dễ review schema trong Git.
        ❌ Đổi tên cột bị hiểu là DROP + ADD ⇒ MẤT DỮ LIỆU (dùng refactorlog để xử lý).
      MIGRATION-BASED (Flyway/Liquibase/EF Core/DbUp): chuỗi script CÓ THỨ TỰ.
        ✅ Kiểm soát tuyệt đối, xử lý được refactor phức tạp + biến đổi dữ liệu.
        ❌ Phải tự bảo đảm thứ tự, dễ trôi (drift) so với thực tế.
      Nhiều tổ chức dùng LAI: state-based cho schema, migration cho biến đổi dữ liệu. */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 6 — KIỂM THỬ: KHUNG UNIT TEST TỰ VIẾT (tinh thần tSQLt)
───────────────────────────────────────────────────────────────────────────────*/
CREATE SCHEMA UnitTest;
GO
CREATE TABLE UnitTest.Result
(
    ResultId  INT IDENTITY PRIMARY KEY,
    TestName  NVARCHAR(200) NOT NULL,
    Passed    BIT           NOT NULL,
    Message   NVARCHAR(MAX) NULL,
    RunAt     DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
CREATE OR ALTER PROCEDURE UnitTest.AssertEquals
    @TestName NVARCHAR(200), @Expected SQL_VARIANT, @Actual SQL_VARIANT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ok BIT =
        CASE WHEN (@Expected IS NULL AND @Actual IS NULL)
               OR (@Expected = @Actual) THEN 1 ELSE 0 END;
    INSERT UnitTest.Result (TestName, Passed, Message)
    VALUES (@TestName, @ok,
            CASE WHEN @ok = 1 THEN N'OK'
                 ELSE CONCAT(N'Mong đợi [', CONVERT(NVARCHAR(100), @Expected),
                             N'] nhưng nhận [', CONVERT(NVARCHAR(100), @Actual), N']') END);
END;
GO

-- Đối tượng cần kiểm thử
CREATE OR ALTER FUNCTION dbo.fnCalcDiscount (@Amount DECIMAL(19,4), @IsVip BIT)
RETURNS DECIMAL(19,4)
AS
BEGIN
    RETURN CASE
             WHEN @Amount IS NULL THEN 0
             WHEN @IsVip = 1 AND @Amount >= 1000000 THEN @Amount * 0.20
             WHEN @IsVip = 1                        THEN @Amount * 0.10
             WHEN @Amount >= 1000000                THEN @Amount * 0.05
             ELSE 0
           END;
END;
GO

-- Bộ test: mỗi test chạy TRONG transaction rồi ROLLBACK ⇒ không để lại rác
CREATE OR ALTER PROCEDURE UnitTest.Run_fnCalcDiscount
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN;

    /*  ⚠ KHÔNG truyền trực tiếp lời gọi hàm vào tham số của EXEC
        (EXEC ... @p = dbo.fn(...) ⇒ Msg 102). Tham số của EXEC chỉ nhận
        hằng hoặc BIẾN ⇒ luôn gán ra biến trước.                                */
    DECLARE @actual DECIMAL(19,4);

    SET @actual = dbo.fnCalcDiscount(1000000, 1);
    EXEC UnitTest.AssertEquals N'VIP + đơn lớn  → 20%', 200000.0000, @actual;

    SET @actual = dbo.fnCalcDiscount(500000, 1);
    EXEC UnitTest.AssertEquals N'VIP + đơn nhỏ  → 10%', 50000.0000, @actual;

    SET @actual = dbo.fnCalcDiscount(1000000, 0);
    EXEC UnitTest.AssertEquals N'Thường + lớn   → 5%', 50000.0000, @actual;

    SET @actual = dbo.fnCalcDiscount(500000, 0);
    EXEC UnitTest.AssertEquals N'Thường + nhỏ   → 0', 0.0000, @actual;

    SET @actual = dbo.fnCalcDiscount(999999, 1);
    EXEC UnitTest.AssertEquals N'Biên: ngay dưới ngưỡng → 10%', 99999.9000, @actual;

    SET @actual = dbo.fnCalcDiscount(NULL, 1);
    EXEC UnitTest.AssertEquals N'NULL đầu vào   → 0', 0.0000, @actual;

    SET @actual = dbo.fnCalcDiscount(100, 0);
    EXEC UnitTest.AssertEquals N'TEST CỐ Ý SAI (minh hoạ báo lỗi)', 999.0000, @actual;

    COMMIT;   -- kết quả test được giữ; dữ liệu nghiệp vụ thì rollback trong test thật
END;
GO

DELETE UnitTest.Result;
EXEC UnitTest.Run_fnCalcDiscount;

SELECT TestName, CASE WHEN Passed = 1 THEN N'✓ PASS' ELSE N'✗ FAIL' END AS Status, Message
FROM   UnitTest.Result ORDER BY ResultId;

SELECT COUNT(*) AS Total,
       SUM(CAST(Passed AS INT)) AS Passed,
       SUM(1 - CAST(Passed AS INT)) AS Failed
FROM   UnitTest.Result;
GO

-- Trả mã lỗi cho pipeline khi có test hỏng ⇒ build FAIL
IF EXISTS (SELECT 1 FROM UnitTest.Result WHERE Passed = 0)
BEGIN
    DECLARE @failed INT = (SELECT COUNT(*) FROM UnitTest.Result WHERE Passed = 0);
    PRINT CONCAT('CÓ ', @failed, ' TEST THẤT BẠI — pipeline phải dừng tại đây.');
    -- THROW 50001, 'Unit tests failed', 1;   -- bỏ chú thích để pipeline thật fail
END;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 7 — tSQLt: khung chuẩn công nghiệp (cú pháp cần nhận diện)
───────────────────────────────────────────────────────────────────────────────*/
/*
 tSQLt là khung unit test T-SQL mã nguồn mở, được nhắc tới trong tài liệu Microsoft.
 Cài: chạy tSQLt.class.sql (cần bật CLR: sp_configure 'clr enabled', 1).

   EXEC tSQLt.NewTestClass 'DiscountTests';
   GO
   CREATE PROCEDURE DiscountTests.[test VIP nhận 20% cho đơn lớn]
   AS
   BEGIN
       -- ISOLATION: thay bảng thật bằng bảng RỖNG cùng cấu trúc, bỏ mọi constraint
       EXEC tSQLt.FakeTable 'dbo.Product';
       EXEC tSQLt.FakeFunction 'dbo.fnGetRate', 'dbo.fnGetRateMock';

       INSERT dbo.Product (ProductId, Name, Price) VALUES (1, 'X', 1000000);

       DECLARE @actual DECIMAL(19,4) = dbo.fnCalcDiscount(1000000, 1);
       EXEC tSQLt.AssertEquals 200000.0000, @actual;
   END;
   GO
   EXEC tSQLt.RunAll;                 -- hoặc tSQLt.Run 'DiscountTests'
   SELECT * FROM tSQLt.TestResult;

 CÁC API CHÍNH CẦN NHỚ:
   tSQLt.NewTestClass      — tạo schema chứa test
   tSQLt.FakeTable         — 🎯 cô lập test khỏi dữ liệu & constraint thật
   tSQLt.FakeFunction / SpyProcedure — mock hàm/proc phụ thuộc
   tSQLt.ApplyConstraint   — bật lại ĐÚNG constraint cần kiểm thử
   tSQLt.AssertEquals / AssertEqualsTable / AssertObjectExists / ExpectException
   tSQLt.RunAll / Run      — chạy test

 ĐẶC ĐIỂM QUAN TRỌNG: mỗi test tự động chạy trong TRANSACTION và ROLLBACK khi kết thúc
   ⇒ không để lại dữ liệu rác, các test độc lập nhau, thứ tự chạy không quan trọng.

 🎯 Đề hỏi "làm sao unit test một stored procedure mà không phụ thuộc dữ liệu
    trong bảng và không vi phạm foreign key?" ⇒ tSQLt.FakeTable.
*/


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 8 — KIỂM THỬ HIỆU NĂNG HỒI QUY
───────────────────────────────────────────────────────────────────────────────*/
CREATE TABLE dbo.PerfBaseline
(
    BaselineId   INT IDENTITY PRIMARY KEY,
    ReleaseTag   NVARCHAR(50)  NOT NULL,
    QueryName    NVARCHAR(200) NOT NULL,
    AvgDurationMs DECIMAL(12,2) NOT NULL,
    AvgCpuMs      DECIMAL(12,2) NOT NULL,
    AvgLogicalReads BIGINT      NOT NULL,
    CapturedAt   DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
/*  QUY TRÌNH KIỂM THỬ HIỆU NĂNG TRONG PIPELINE:
      1. Trước deploy: chụp baseline từ Query Store trên môi trường staging
      2. Deploy phiên bản mới
      3. Chạy lại tải chuẩn (workload replay)
      4. So sánh: nếu AvgDurationMs tăng > ngưỡng (vd 20%) ⇒ FAIL build

    Truy vấn chụp baseline từ Query Store (dùng ở môi trường có Query Store bật):

    INSERT dbo.PerfBaseline (ReleaseTag, QueryName, AvgDurationMs, AvgCpuMs, AvgLogicalReads)
    SELECT 'v1.4.0',
           LEFT(qt.query_sql_text, 200),
           AVG(rs.avg_duration)/1000.0,
           AVG(rs.avg_cpu_time)/1000.0,
           AVG(rs.avg_logical_io_reads)
    FROM   sys.query_store_query q
    JOIN   sys.query_store_query_text qt ON qt.query_text_id = q.query_text_id
    JOIN   sys.query_store_plan p ON p.query_id = q.query_id
    JOIN   sys.query_store_runtime_stats rs ON rs.plan_id = p.plan_id
    GROUP BY LEFT(qt.query_sql_text, 200);

    CÔNG CỤ KHÁC: Distributed Replay (phát lại tải production),
      ostress/RML Utilities, SQLQueryStress.                                      */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 9 — BACKUP / RESTORE & RECOVERY MODEL
───────────────────────────────────────────────────────────────────────────────*/
SELECT name, recovery_model_desc, log_reuse_wait_desc, state_desc
FROM   sys.databases WHERE name IN ('DP800_Deploy','master','tempdb','model','msdb');

ALTER DATABASE DP800_Deploy SET RECOVERY FULL;
GO
DECLARE @p NVARCHAR(400) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(400));
DECLARE @c NVARCHAR(MAX) = N'
BACKUP DATABASE DP800_Deploy TO DISK = ''' + @p + N'DP800_Deploy_FULL.bak''
   WITH INIT, COMPRESSION, CHECKSUM, STATS = 25;
BACKUP LOG DP800_Deploy TO DISK = ''' + @p + N'DP800_Deploy_LOG.trn''
   WITH INIT, COMPRESSION, CHECKSUM;';
BEGIN TRY
    EXEC sys.sp_executesql @c;
    PRINT 'Backup FULL + LOG thành công.';
END TRY
BEGIN CATCH
    SELECT 'Backup' AS Step, ERROR_MESSAGE() AS Msg;
END CATCH;
GO
SELECT TOP (5) database_name, type, backup_start_date, backup_finish_date,
       CAST(backup_size/1024.0/1024 AS DECIMAL(10,2)) AS SizeMB,
       CAST(compressed_backup_size/1024.0/1024 AS DECIMAL(10,2)) AS CompressedMB
FROM   msdb.dbo.backupset WHERE database_name = 'DP800_Deploy'
ORDER BY backup_start_date DESC;
GO
/*  RECOVERY MODEL:
      FULL        — mọi thao tác ghi log đầy đủ ⇒ PITR (point-in-time restore).
                    BẮT BUỘC backup log định kỳ, nếu không log phình vô hạn.
      BULK_LOGGED — log tối thiểu cho thao tác bulk ⇒ nhanh hơn nhưng PITR bị hạn chế
                    trong khoảng có bulk operation.
      SIMPLE      — log tự cắt tại checkpoint, KHÔNG PITR, không backup log được.

    CHUỖI RESTORE (đề hay hỏi thứ tự và từ khoá):
      RESTORE DATABASE X FROM DISK='full.bak'  WITH NORECOVERY;
      RESTORE DATABASE X FROM DISK='diff.bak'  WITH NORECOVERY;
      RESTORE LOG      X FROM DISK='log1.trn'  WITH NORECOVERY;
      RESTORE LOG      X FROM DISK='log2.trn'  WITH STOPAT = '2026-07-26 14:30', RECOVERY;
    ⚠ NORECOVERY ở mọi bước trung gian; RECOVERY chỉ ở bước CUỐI.
    ⚠ Muốn PITR thì recovery model phải là FULL từ TRƯỚC thời điểm sự cố.
    ⚠ Với DB bật TDE: phải khôi phục CERTIFICATE ở server đích TRƯỚC khi restore.  */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 10 — NÂNG CẤP CÓ KIỂM SOÁT & DI CHUYỂN LÊN AZURE
───────────────────────────────────────────────────────────────────────────────*/
SELECT name, compatibility_level FROM sys.databases WHERE name = 'DP800_Deploy';
GO
/*  🎯 QUY TRÌNH NÂNG CẤP CHUẨN CỦA MICROSOFT (câu hỏi sắp xếp bước):
      1. Chạy Data Migration Assistant (DMA) để đánh giá tương thích
      2. Nâng cấp engine, GIỮ NGUYÊN compatibility level cũ
      3. BẬT QUERY STORE, chạy tải thực tế để có baseline
      4. Nâng compatibility level lên mức mới
      5. Theo dõi "Regressed Queries" trong Query Store
      6. FORCE plan cũ cho truy vấn bị hồi quy
    ⇒ Nguyên tắc: TÁCH việc nâng cấp engine khỏi việc đổi hành vi optimizer.

    CÔNG CỤ DI CHUYỂN:
      Data Migration Assistant (DMA)        — đánh giá + di chuyển nhỏ
      Azure Database Migration Service (DMS)— di chuyển online/offline quy mô lớn
      Managed Instance link                 — đồng bộ gần thời gian thực, downtime tối thiểu
      Log Replay Service (LRS)              — restore chuỗi log lên MI
      BACPAC                                — đơn giản nhất, DB nhỏ, chấp nhận downtime

    CHỌN ĐÍCH TRÊN AZURE (bảng quyết định):
    ┌──────────────────────────────────────────────┬─────────────────────────────┐
    │ Yêu cầu                                      │ Chọn                        │
    ├──────────────────────────────────────────────┼─────────────────────────────┤
    │ Cần SQL Agent, cross-DB query, CLR, Broker   │ SQL Managed Instance        │
    │ Ứng dụng mới, 1 DB, quản trị tối thiểu       │ Azure SQL Database          │
    │ Cần toàn quyền OS, tính năng đặc thù         │ SQL Server on Azure VM      │
    │ DB > 4 TB, cần restore/scale nhanh           │ Hyperscale                  │
    │ Nhiều DB nhỏ, tải lệch giờ nhau              │ Elastic pool                │
    │ Tải gián đoạn, muốn tiết kiệm chi phí        │ Serverless (auto-pause)     │
    │ Cần đọc trên bản sao                         │ Read scale-out / read replica│
    │ DR liên vùng                                 │ Failover group / geo-replication│
    │ HA trong 1 vùng                              │ Zone-redundant config       │
    └──────────────────────────────────────────────┴─────────────────────────────┘

    KHÁC BIỆT AZURE SQL DATABASE CẦN NHỚ:
      ❌ Không có: USE <db>, cross-database query, SQL Agent, sp_configure,
                   Resource Governor, FILESTREAM, backup/restore thủ công.
      ✅ Có: PITR tự động (1–35 ngày), LTR tới 10 năm, Query Store bật sẵn,
             RCSI bật sẵn, TDE bật sẵn, contained user bắt buộc.
      ⇒ Kịch bản "chuyển ứng dụng dùng SQL Agent job lên Azure" ⇒ Managed Instance,
        hoặc thay Agent bằng Elastic Job / Azure Automation / Logic Apps.         */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 11 — DỌN DẸP
───────────────────────────────────────────────────────────────────────────────*/
-- USE master;
-- ALTER DATABASE DP800_Deploy SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
-- DROP DATABASE DP800_Deploy;

/*═══════════════════════════════════════════════════════════════════════════════
  CHECKLIST SAU LAB 05
  □ Nói ngay: .dacpac chứa gì, .bacpac chứa gì, action tương ứng của mỗi loại.
  □ Kể 6 action của SqlPackage và tham số an toàn quan trọng nhất.
  □ Giải thích BlockOnPossibleDataLoss và 2 thao tác kích hoạt nó.
  □ Mô tả chiến lược expand → migrate → contract cho deploy không downtime.
  □ Phân biệt state-based và migration-based, ưu nhược của từng bên.
  □ Nêu 6 nguyên tắc CI/CD cho database.
  □ Biết tSQLt.FakeTable dùng để làm gì và vì sao test tự rollback.
  □ Viết đúng chuỗi RESTORE với NORECOVERY/RECOVERY/STOPAT.
  □ Kể 6 bước nâng cấp có kiểm soát bằng Query Store.
  □ Chọn đúng đích Azure cho từng yêu cầu (MI vs SQL DB vs VM vs Hyperscale).
═══════════════════════════════════════════════════════════════════════════════*/
