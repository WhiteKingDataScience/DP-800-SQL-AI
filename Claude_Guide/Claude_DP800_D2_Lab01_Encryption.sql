/*═══════════════════════════════════════════════════════════════════════════════
  DP-800 | MIỀN 2 | LAB 01 — MÃ HOÁ (ENCRYPTION)
  Đi kèm: Claude_DP800_D2_SecurityPerfDeploy_Guide.md  (mục 2)

  PHẦN A — Key hierarchy, TDE, Backup encryption   (S1..S5)
  PHẦN B — Column-level encryption, Always Encrypted (S6..S9)

  ⚠ CHỈ CHẠY TRÊN INSTANCE TEST. Lab tạo database, certificate và bật TDE.
    Mọi thứ đều được dọn ở Section 10.
═══════════════════════════════════════════════════════════════════════════════*/

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
SELECT  @@VERSION                                       AS ServerVersion,
        SERVERPROPERTY('ProductMajorVersion')           AS MajorVer,   -- 15=2019 16=2022 17=2025
        SERVERPROPERTY('Edition')                       AS Edition,
        SERVERPROPERTY('EngineEdition')                 AS EngineEdition,  -- 3=Enterprise/Dev, 5=Azure SQL DB
        SERVERPROPERTY('IsIntegratedSecurityOnly')      AS WindowsAuthOnly;
GO


/*═══════════════════ PHẦN A — TDE & KEY HIERARCHY ════════════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 1 — SOI CHUỖI KHOÁ CÓ SẴN
───────────────────────────────────────────────────────────────────────────────*/
/*  Service Master Key (SMK) — tạo tự động khi cài đặt, bảo vệ bởi Windows DPAPI.
    Đây là gốc của toàn bộ cây khoá, KHÔNG tạo bằng tay được.                    */
SELECT name, key_length, algorithm_desc, create_date
FROM   sys.symmetric_keys
WHERE  name = '##MS_ServiceMasterKey##';

/*  CÂY KHOÁ ĐẦY ĐỦ (thứ tự này hay ra đề dạng drag-and-drop):
        Service Master Key (SMK)      ← DPAPI của Windows bảo vệ
              ↓
        Database Master Key (DMK)     ← trong master, bảo vệ bằng PASSWORD
              ↓
        Certificate / Asymmetric Key
              ↓
        Database Encryption Key (DEK) ← trong DB người dùng, AES_256
              ↓
        Toàn bộ data file + log file + tempdb                                    */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 2 — BẬT TDE ĐÚNG 5 BƯỚC
───────────────────────────────────────────────────────────────────────────────*/
USE master;
GO
-- BƯỚC 1: Database Master Key trong master
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Str0ng!MasterKey#2026';
GO

-- BƯỚC 2: Certificate bảo vệ DEK
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'TDE_Cert_DP800')
    CREATE CERTIFICATE TDE_Cert_DP800
    WITH SUBJECT = 'DP-800 Lab TDE Certificate',
         EXPIRY_DATE = '2030-12-31';
GO

-- BƯỚC 3: ⚠⚠ SAO LƯU CERTIFICATE + PRIVATE KEY — BƯỚC HAY BỊ QUÊN NHẤT ⚠⚠
DECLARE @bak NVARCHAR(400) =
        CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(400));
DECLARE @cmd NVARCHAR(MAX) =
    N'BACKUP CERTIFICATE TDE_Cert_DP800 TO FILE = ''' + @bak + N'TDE_Cert_DP800.cer''
      WITH PRIVATE KEY (FILE = ''' + @bak + N'TDE_Cert_DP800.pvk'',
                        ENCRYPTION BY PASSWORD = ''Str0ng!CertBackup#2026'');';
BEGIN TRY
    EXEC sys.sp_executesql @cmd;
    PRINT 'Đã backup certificate + private key.';
END TRY
BEGIN CATCH
    SELECT 'Backup certificate' AS Step, ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS Msg;
END CATCH;
GO
/*  🎯 KHÔNG CÓ FILE NÀY = KHÔNG BAO GIỜ RESTORE ĐƯỢC BACKUP Ở SERVER KHÁC.
    Backup của DB bật TDE luôn ở dạng mã hoá; muốn restore nơi khác phải:
      1. Tạo DMK ở server đích
      2. CREATE CERTIFICATE ... FROM FILE = '...cer' WITH PRIVATE KEY (FILE = '...pvk', ...)
      3. RESTORE DATABASE bình thường
    Đây là câu hỏi tình huống rất hay gặp.                                       */

-- Tạo DB thử nghiệm
IF DB_ID('DP800_TDE') IS NOT NULL
BEGIN
    ALTER DATABASE DP800_TDE SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DP800_TDE;
END;
GO
CREATE DATABASE DP800_TDE;
GO

-- BƯỚC 4: Database Encryption Key trong DB đích
USE DP800_TDE;
GO
CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE TDE_Cert_DP800;
GO

-- BƯỚC 5: Bật mã hoá
ALTER DATABASE DP800_TDE SET ENCRYPTION ON;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 3 — THEO DÕI TRẠNG THÁI MÃ HOÁ
───────────────────────────────────────────────────────────────────────────────*/
USE master;
GO
SELECT  DB_NAME(dek.database_id)        AS DatabaseName,
        dek.encryption_state,
        CASE dek.encryption_state
             WHEN 0 THEN 'Không có DEK'
             WHEN 1 THEN 'Chưa mã hoá'
             WHEN 2 THEN 'ĐANG mã hoá (encryption in progress)'
             WHEN 3 THEN 'ĐÃ mã hoá'
             WHEN 4 THEN 'Đang đổi khoá'
             WHEN 5 THEN 'ĐANG giải mã'
             WHEN 6 THEN 'Đang bảo vệ lại khoá'
        END                              AS StateDesc,
        dek.percent_complete,
        dek.key_algorithm, dek.key_length,
        c.name                           AS CertificateName
FROM    sys.dm_database_encryption_keys dek
LEFT JOIN sys.certificates c ON c.thumbprint = dek.encryptor_thumbprint;

-- ⚠ tempdb bị mã hoá TỰ ĐỘNG khi có BẤT KỲ DB nào bật TDE (ảnh hưởng toàn instance)
SELECT name, is_encrypted FROM sys.databases WHERE name IN ('tempdb','DP800_TDE','master');
/*  Hệ quả cần nhớ:
      - Mọi DB dùng chung tempdb đều chịu chi phí CPU mã hoá.
      - Backup của DB có TDE nén rất kém (dữ liệu đã ngẫu nhiên hoá).
      - TDE KHÔNG chống được người có quyền truy vấn: engine giải mã khi đọc lên RAM. */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 4 — CHỨNG MINH: TDE KHÔNG CHỐNG ĐƯỢC DBA
───────────────────────────────────────────────────────────────────────────────*/
USE DP800_TDE;
GO
CREATE TABLE dbo.Salary (EmpId INT PRIMARY KEY, FullName NVARCHAR(50), Amount DECIMAL(19,4));
GO
INSERT dbo.Salary VALUES (1, N'Nguyễn Văn A', 50000000), (2, N'Trần Thị B', 72000000);
SELECT * FROM dbo.Salary;   -- ✅ đọc bình thường, thấy plaintext
/*  🎯 KẾT LUẬN THI:
      TDE bảo vệ dữ liệu AT REST (file .mdf/.ldf/.bak bị lấy cắp).
      TDE KHÔNG bảo vệ trước người có quyền truy vấn — kể cả DBA.
      Muốn giấu cả DBA ⇒ ALWAYS ENCRYPTED (Phần B).                             */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 5 — BACKUP ENCRYPTION (độc lập với TDE)
───────────────────────────────────────────────────────────────────────────────*/
USE master;
GO
DECLARE @bakPath NVARCHAR(400) =
        CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(400)) + N'DP800_TDE_enc.bak';
DECLARE @sql NVARCHAR(MAX) =
    N'BACKUP DATABASE DP800_TDE TO DISK = ''' + @bakPath + N'''
      WITH ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = TDE_Cert_DP800),
           INIT, STATS = 25;';
BEGIN TRY
    EXEC sys.sp_executesql @sql;
    PRINT 'Backup mã hoá thành công.';
END TRY
BEGIN CATCH
    SELECT 'Backup encryption' AS Step, ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS Msg;
END CATCH;
GO
/*  PHÂN BIỆT (đề hay hỏi):
      TDE               = mã hoá DỮ LIỆU TRONG DATABASE (và backup của nó theo).
      Backup encryption = mã hoá RIÊNG file backup, dùng được cho DB KHÔNG bật TDE.
    Xem thông tin mã hoá của backup:
      RESTORE HEADERONLY FROM DISK = '...'  →  cột KeyAlgorithm, EncryptorType.       */


/*═══════════════════ PHẦN B — MÃ HOÁ CẤP CỘT ═════════════════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 6 — COLUMN-LEVEL (CELL) ENCRYPTION — cách "cổ điển"
───────────────────────────────────────────────────────────────────────────────*/
USE DP800_TDE;
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Str0ng!DbMasterKey#2026';
GO
CREATE CERTIFICATE Cert_Column WITH SUBJECT = 'Column encryption cert';
GO
CREATE SYMMETRIC KEY SymKey_CreditCard
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE Cert_Column;
GO

CREATE TABLE dbo.Payment
(
    PaymentId     INT IDENTITY PRIMARY KEY,
    CardNumber    VARCHAR(20)    NULL,   -- plaintext để đối chiếu
    CardEncrypted VARBINARY(256) NULL    -- ⚠ kiểu bắt buộc là VARBINARY
);
GO

OPEN SYMMETRIC KEY SymKey_CreditCard DECRYPTION BY CERTIFICATE Cert_Column;

INSERT dbo.Payment (CardNumber, CardEncrypted)
VALUES ('4111-1111-1111-1111',
        ENCRYPTBYKEY(KEY_GUID('SymKey_CreditCard'), '4111-1111-1111-1111'));

SELECT  PaymentId,
        CardNumber                                                    AS Plaintext,
        CardEncrypted                                                 AS Ciphertext,
        CONVERT(VARCHAR(20), DECRYPTBYKEY(CardEncrypted))             AS Decrypted
FROM    dbo.Payment;

CLOSE SYMMETRIC KEY SymKey_CreditCard;

-- Không mở khoá ⇒ DECRYPTBYKEY trả NULL (không báo lỗi!)
SELECT PaymentId, CONVERT(VARCHAR(20), DECRYPTBYKEY(CardEncrypted)) AS Decrypted_KhongMoKhoa
FROM   dbo.Payment;
GO
/*  ĐẶC ĐIỂM CELL ENCRYPTION:
      - Phải sửa MỌI câu lệnh của ứng dụng (OPEN KEY / ENCRYPTBYKEY / DECRYPTBYKEY).
      - Không tìm kiếm/JOIN/index được trên cột đã mã.
      - Khoá vẫn nằm TRONG database ⇒ DBA có quyền CONTROL vẫn giải mã được.
      - Kích thước phình: VARBINARY lớn hơn nhiều so với plaintext.
    ⇒ Ngày nay chỉ dùng khi không thể triển khai Always Encrypted.                */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 7 — ALWAYS ENCRYPTED: khai báo khoá
───────────────────────────────────────────────────────────────────────────────*/
/*  ⚠ Always Encrypted cần thiết lập CMK ở kho khoá NGOÀI database
    (Windows Certificate Store / Azure Key Vault / HSM). Việc tạo CMK thật phải làm
    từ SSMS ("Encrypt Columns…" wizard), Azure Data Studio, hoặc PowerShell
    (New-SqlColumnMasterKeySettings / New-SqlColumnEncryptionKey), KHÔNG làm được
    thuần T-SQL vì cần truy cập kho khoá phía client.

    Dưới đây là ĐÚNG cú pháp T-SQL sinh ra bởi wizard — học thuộc cấu trúc:

    -- (1) Column Master Key: chỉ là "con trỏ" tới kho khoá ngoài
    CREATE COLUMN MASTER KEY CMK_Auto1
    WITH (
        KEY_STORE_PROVIDER_NAME = 'MSSQL_CERTIFICATE_STORE',   -- hoặc 'AZURE_KEY_VAULT'
        KEY_PATH = 'CurrentUser/My/A1B2C3D4E5...'              -- thumbprint / URL Key Vault
    );

    -- (2) Column Encryption Key: giá trị đã được CMK mã hoá (client sinh ra)
    CREATE COLUMN ENCRYPTION KEY CEK_Auto1
    WITH VALUES (
        COLUMN_MASTER_KEY = CMK_Auto1,
        ALGORITHM = 'RSA_OAEP',
        ENCRYPTED_VALUE = 0x016E000001630075...
    );

    -- (3) Khai báo cột
    CREATE TABLE dbo.Patient
    (
        PatientId INT IDENTITY PRIMARY KEY,

        -- DETERMINISTIC: cùng plaintext → cùng ciphertext
        --   ✅ =, JOIN, GROUP BY, DISTINCT, INDEX
        --   ⚠ cột chuỗi BẮT BUỘC collation _BIN2
        SSN VARCHAR(11) COLLATE Latin1_General_BIN2
            ENCRYPTED WITH (COLUMN_ENCRYPTION_KEY = CEK_Auto1,
                            ENCRYPTION_TYPE = DETERMINISTIC,
                            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'),

        -- RANDOMIZED: an toàn hơn nhưng KHÔNG truy vấn được gì
        Salary MONEY
            ENCRYPTED WITH (COLUMN_ENCRYPTION_KEY = CEK_Auto1,
                            ENCRYPTION_TYPE = RANDOMIZED,
                            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256')
    );

    -- Kiểm tra metadata (chạy được ở bất kỳ đâu):
    SELECT * FROM sys.column_master_keys;
    SELECT * FROM sys.column_encryption_keys;
    SELECT name, encryption_type_desc, encryption_algorithm_name
    FROM   sys.columns WHERE encryption_type IS NOT NULL;                        */

SELECT 'sys.column_master_keys'     AS CatalogView, COUNT(*) AS RowCnt FROM sys.column_master_keys
UNION ALL
SELECT 'sys.column_encryption_keys', COUNT(*) FROM sys.column_encryption_keys;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 8 — ALWAYS ENCRYPTED: NHỮNG GÌ LÀM ĐƯỢC / KHÔNG LÀM ĐƯỢC
───────────────────────────────────────────────────────────────────────────────*/
/*
 ┌───────────────────────────┬────────────────┬──────────────┬────────────────────┐
 │ Thao tác                  │ DETERMINISTIC  │ RANDOMIZED   │ + Secure Enclaves  │
 ├───────────────────────────┼────────────────┼──────────────┼────────────────────┤
 │ INSERT / SELECT cả cột    │ ✅             │ ✅           │ ✅                 │
 │ WHERE col = @p            │ ✅             │ ❌           │ ✅                 │
 │ JOIN, GROUP BY, DISTINCT  │ ✅             │ ❌           │ ✅                 │
 │ Tạo index trên cột        │ ✅             │ ❌           │ ✅                 │
 │ WHERE col LIKE '%x%'      │ ❌             │ ❌           │ ✅                 │
 │ WHERE col > @p (dải)      │ ❌             │ ❌           │ ✅                 │
 │ ORDER BY                  │ ❌             │ ❌           │ ✅                 │
 │ SUM/AVG, hàm chuỗi        │ ❌             │ ❌           │ ❌                 │
 │ Mã hoá tại chỗ (in-place) │ ❌ (tải về máy)│ ❌           │ ✅                 │
 └───────────────────────────┴────────────────┴──────────────┴────────────────────┘

 ĐIỀU KIỆN PHÍA ỨNG DỤNG (câu hỏi hay bị bỏ sót):
   Connection string PHẢI có:  Column Encryption Setting = Enabled
   Driver phải hỗ trợ AE: .NET 4.6+, JDBC 6.0+, ODBC 13.1+, OLE DB 18+, Python/Node driver mới.
   Ứng dụng cần quyền đọc CMK ở kho khoá (chứng chỉ / Key Vault access policy).
   ⇒ Nếu đề nói "TUYỆT ĐỐI KHÔNG được sửa ứng dụng" thì Always Encrypted là ĐÁP ÁN SAI.

 KIỂU DỮ LIỆU KHÔNG HỖ TRỢ: xml, image, ntext/text, sql_variant, hierarchyid, geography/geometry,
   rowversion, cột IDENTITY, cột computed tham chiếu cột mã hoá, sparse column set,
   cột dùng trong FULLTEXT index.

 SECURE ENCLAVES (SQL 2019+ / Azure SQL):
   - Cấu hình: sp_configure 'column encryption enclave type', 1 (VBS) — cần attestation
     (Windows HGS on-prem, Microsoft Azure Attestation trên Azure SQL).
   - Connection string thêm: Attestation Protocol=HGS;Enclave Attestation Url=...
   - Cho phép ALTER cột để đổi kiểu mã hoá NGAY TRONG DATABASE (không kéo dữ liệu về client).
*/


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 9 — CHỌN CƠ CHẾ NÀO? (bảng ra quyết định)
───────────────────────────────────────────────────────────────────────────────*/
/*
 ┌──────────────────────────────────────────────────┬────────────────────────────┐
 │ Đề bài nói...                                    │ Đáp án                     │
 ├──────────────────────────────────────────────────┼────────────────────────────┤
 │ Mất ổ đĩa/băng backup, không được lộ dữ liệu     │ TDE                        │
 │ DB không bật TDE nhưng cần bảo vệ file backup    │ Backup encryption          │
 │ KỂ CẢ DBA/sysadmin/cloud operator không được xem │ Always Encrypted           │
 │ AE nhưng vẫn cần =, JOIN, index                  │ DETERMINISTIC              │
 │ AE nhưng vẫn cần LIKE / khoảng giá trị / ORDER BY│ Secure enclaves            │
 │ Tuyệt đối không sửa ứng dụng                     │ TDE (KHÔNG chọn AE)        │
 │ Tự quản lý khoá trên Azure SQL                   │ CMK/BYOK + Azure Key Vault │
 │ Bảo vệ dữ liệu ĐANG TRUYỀN trên mạng             │ TLS (Encrypt=True)         │
 │ Chỉ che khi hiển thị, không cần chống tấn công   │ Dynamic Data Masking (Lab02)│
 │ Chứng minh dữ liệu chưa bị sửa (toàn vẹn)        │ Ledger (Miền 1 Lab03)      │
 └──────────────────────────────────────────────────┴────────────────────────────┘
*/


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 10 — DỌN DẸP (chạy để trả instance về trạng thái ban đầu)
───────────────────────────────────────────────────────────────────────────────*/
USE DP800_TDE;
GO
IF EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'SymKey_CreditCard')
    DROP SYMMETRIC KEY SymKey_CreditCard;
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'Cert_Column')
    DROP CERTIFICATE Cert_Column;
GO

USE master;
GO
-- Phải TẮT mã hoá và ĐỢI xong trước khi DROP certificate
ALTER DATABASE DP800_TDE SET ENCRYPTION OFF;
GO
-- Chờ giải mã hoàn tất (encryption_state = 1)
WHILE EXISTS (SELECT 1 FROM sys.dm_database_encryption_keys
              WHERE database_id = DB_ID('DP800_TDE') AND encryption_state <> 1)
BEGIN
    WAITFOR DELAY '00:00:02';
END;
GO
USE DP800_TDE;
GO
DROP DATABASE ENCRYPTION KEY;
GO
USE master;
GO
ALTER DATABASE DP800_TDE SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE DP800_TDE;
GO
DROP CERTIFICATE TDE_Cert_DP800;
GO
/*  ⚠ Thứ tự bắt buộc khi gỡ TDE:
      SET ENCRYPTION OFF → chờ state = 1 → DROP DATABASE ENCRYPTION KEY
      → DROP DATABASE → DROP CERTIFICATE.
    Drop certificate khi còn DEK tham chiếu ⇒ Msg 3716.
    (Giữ lại Database Master Key ở master — nhiều thứ khác có thể đang dùng.)     */

SELECT name, is_encrypted FROM sys.databases WHERE name = 'tempdb';
/*  tempdb vẫn hiển thị is_encrypted = 1 cho tới khi RESTART instance —
    đây là hành vi bình thường, không phải lỗi.                                  */


/*═══════════════════════════════════════════════════════════════════════════════
  CHECKLIST SAU LAB 01
  □ Vẽ lại cây khoá SMK → DMK → Certificate → DEK từ trí nhớ.
  □ Kể 5 bước bật TDE, chỉ ra bước nào quên là mất dữ liệu vĩnh viễn.
  □ Nói được vì sao TDE không chống được DBA.
  □ Phân biệt TDE / backup encryption / cell encryption / Always Encrypted.
  □ Nêu chính xác DETERMINISTIC hỗ trợ gì, RANDOMIZED hỗ trợ gì.
  □ Nhớ điều kiện phía client của Always Encrypted (connection string + kho khoá).
  □ Biết secure enclaves giải quyết đúng hạn chế nào.
═══════════════════════════════════════════════════════════════════════════════*/
