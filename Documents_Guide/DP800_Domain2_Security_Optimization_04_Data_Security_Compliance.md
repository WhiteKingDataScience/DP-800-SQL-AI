# DP-800 Miền 2 — Bảo mật dữ liệu và đáp ứng yêu cầu tuân thủ

> **Miền 2:** Bảo mật, tối ưu và triển khai giải pháp cơ sở dữ liệu (35–40%)  
> **Chủ đề:** Mã hóa, che dữ liệu, lọc dòng, phân quyền, kiểm toán và bảo vệ endpoint  
> **Cập nhật:** 09/08/2026  
> **Blueprint áp dụng:** DP-800 — Skills measured as of March 12, 2026  
> **Cập nhật cách trình bày:** 12/08/2026

## Chương này giúp bạn bảo vệ điều gì?

“Bảo mật database” không phải một nút bật duy nhất. Mỗi cơ chế ngăn một loại rủi ro khác nhau.

Ví dụ, một hệ thống bệnh viện có thể đồng thời yêu cầu:

- người lấy được file backup không đọc được dữ liệu;
- DBA không nhìn thấy số căn cước của bệnh nhân;
- bác sĩ chỉ xem được bệnh nhân thuộc khoa của mình;
- nhân viên tổng đài vẫn thấy dòng bệnh nhân nhưng số điện thoại bị che;
- mọi lần xem hoặc sửa hồ sơ đều được ghi lại để kiểm toán;
- ứng dụng gọi Azure OpenAI mà không lưu API key trong mã nguồn.

Không một tính năng nào giải quyết tất cả yêu cầu trên. Bạn phải xác định **đang bảo vệ dữ liệu khỏi ai, ở trạng thái nào và cần để lại bằng chứng gì**. Đây là cách đề thi phân biệt TDE, Always Encrypted, DDM, RLS, permissions và auditing.

---

## 0. PHẠM VI THI CHÍNH THỨC VÀ CÁCH DÙNG TÀI LIỆU

Theo Study Guide DP-800 hiện hành, bạn phải nắm:

- Mã hóa dữ liệu, bao gồm **Always Encrypted** và **mã hóa cấp cột**.
- **Dynamic Data Masking (DDM)**.
- **Row-Level Security (RLS)**.
- **Quyền trên đối tượng**.
- Truy cập database an toàn, đặc biệt là **kết nối không dùng mật khẩu**.
- **Kiểm toán**.
- Bảo vệ model endpoint, đặc biệt **Managed Identity**.
- Bảo vệ **GraphQL, REST và MCP endpoint**.

> **Lưu ý thi:** Microsoft nói các gạch đầu dòng trong Study Guide chỉ mô tả cách đánh giá; các chủ đề liên quan vẫn có thể xuất hiện. Vì vậy tài liệu này giữ thêm TDE, Key Vault, Entra ID và bảo mật DAB vì chúng giúp bạn phân biệt đúng các tình huống.

**Nguồn chuẩn:**
- [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
- [Microsoft Learn — Implement data security and compliance](https://learn.microsoft.com/en-us/training/modules/implement-data-security-compliance/)

---

# PHẦN 1 — LÝ THUYẾT CỐT LÕI

## 1. Chọn đúng cơ chế bảo vệ dữ liệu

Đây là bảng nên thuộc theo **mục tiêu bảo vệ**, không học theo tên sản phẩm.

| Cơ chế | Bảo vệ cái gì? | SQL Engine/DBA có thấy dữ liệu rõ? | Có thay đổi ứng dụng? | Tình huống thường gặp |
|---|---|---:|---:|---|
| **TDE** | Data/log/backup **at rest** | Có, khi truy vấn bình thường | Thường không | “Mất file backup/disk vẫn không đọc được” |
| **Column-level encryption** | Một số cột, mã hóa/giải mã bằng T-SQL | Có thể, nếu principal có key/quyền | Có | Ứng dụng chủ động gọi `EncryptByKey`/`DecryptByKey` |
| **Always Encrypted** | Cột nhạy cảm; mã hóa/giải mã phía client driver | Mục tiêu là DB engine không thấy plaintext | Có, driver phải hỗ trợ AE | PII/SSN/card data và DBA không được xem |
| **Always Encrypted + secure enclaves** | AE nhưng cho phép một số phép toán phong phú hơn trong enclave | Plaintext chỉ được xử lý trong vùng tin cậy | Có | Cần so sánh/range/pattern trên dữ liệu AE tùy cấu hình |
| **DDM** | Chỉ **che kết quả hiển thị** | Dữ liệu gốc vẫn tồn tại | Thường không | Helpdesk được SELECT nhưng không được xem PII |
| **RLS** | Kiểm soát **dòng nào** user được xem/sửa | Không phải mã hóa | Có thể không | Multi-tenant, salesperson chỉ thấy khu vực của mình |
| **Permissions** | User được phép làm thao tác gì trên object nào | — | — | Least privilege |
| **Auditing** | Ghi lại ai đã làm gì | — | — | Compliance/forensics |

### Bẫy quan trọng trong đề

- **DDM ≠ encryption.**
- **RLS ≠ DDM.** RLS loại bỏ dòng không được phép; DDM vẫn trả dòng nhưng che giá trị.
- **TDE ≠ Always Encrypted.** TDE bảo vệ dữ liệu at rest; AE bảo vệ cột nhạy cảm khỏi cả database engine theo mô hình client-side encryption.
- **TDE customer-managed key ≠ Always Encrypted Column Master Key.** Hai khái niệm đều có thể dùng Azure Key Vault nhưng phục vụ hai cơ chế khác nhau.

Tham khảo:
- [Transparent Data Encryption](https://learn.microsoft.com/en-us/sql/relational-databases/security/encryption/transparent-data-encryption?view=sql-server-ver17)
- [Always Encrypted](https://learn.microsoft.com/en-us/sql/relational-databases/security/encryption/always-encrypted-database-engine?view=sql-server-ver17)

---

## 2. Mã hóa ở cấp cột (Column-level encryption) — phần dễ bị bỏ sót

Column-level encryption dùng **Database Master Key → Certificate → Symmetric Key**, rồi ứng dụng/T-SQL chủ động mở key để mã hóa hoặc giải mã.

### Cách hình dung chuỗi khóa

Sơ đồ sau cho thấy khóa cấp trên bảo vệ khóa cấp dưới. Muốn giải mã cột, hệ thống phải đi đúng chuỗi từ Database Master Key tới symmetric key.

```text
Database Master Key
        ↓ bảo vệ
Certificate
        ↓ bảo vệ
Symmetric Key
        ↓ EncryptByKey / DecryptByKey
Sensitive Column
```

### Bài thực hành đầy đủ

> Chạy trên cơ sở dữ liệu thực hành riêng, không dùng môi trường thật.

```sql
USE YourLabDatabase;
GO

-- 1. Database Master Key
CREATE MASTER KEY
ENCRYPTION BY PASSWORD = 'Use-A-Strong-Lab-Password-Only!';
GO

-- 2. Certificate
CREATE CERTIFICATE CustomerDataCertificate
WITH SUBJECT = 'Protect customer sensitive columns';
GO

-- 3. Symmetric key
CREATE SYMMETRIC KEY CustomerDataKey
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE CustomerDataCertificate;
GO

-- 4. Bảng lưu ciphertext.
-- varbinary phù hợp vì EncryptByKey trả varbinary.
CREATE TABLE dbo.CustomerSecrets
(
    CustomerId int NOT NULL
        CONSTRAINT PK_CustomerSecrets PRIMARY KEY,
    NationalIdEncrypted varbinary(256) NOT NULL
);
GO

-- 5. Mở key trước khi mã hóa
OPEN SYMMETRIC KEY CustomerDataKey
DECRYPTION BY CERTIFICATE CustomerDataCertificate;
GO

INSERT dbo.CustomerSecrets(CustomerId, NationalIdEncrypted)
VALUES
(
    1,
    EncryptByKey(
        Key_GUID('CustomerDataKey'),
        CONVERT(nvarchar(30), N'012345678901')
    )
);
GO

-- 6. Giải mã
SELECT
    CustomerId,
    CONVERT(nvarchar(30),
        DecryptByKey(NationalIdEncrypted)
    ) AS NationalId
FROM dbo.CustomerSecrets;
GO

-- 7. Đóng key khi xong
CLOSE SYMMETRIC KEY CustomerDataKey;
GO
```

**Khi nào chọn?** Khi yêu cầu nói mã trong cơ sở dữ liệu chủ động mã hóa/giải mã cột và người có quyền dùng khóa có thể giải mã. Nếu yêu cầu nói **bộ máy cơ sở dữ liệu hoặc DBA không được thấy dữ liệu rõ**, nghĩ đến **Always Encrypted**.

Tham khảo: [SQL Server column-level encryption functions](https://learn.microsoft.com/en-us/sql/relational-databases/security/encryption/sql-server-encryption?view=sql-server-ver17)

---

## 3. Always Encrypted

### 3.1 Hai loại khóa

- **Column Master Key (CMK):** metadata trong database trỏ tới key thực ở nơi tin cậy, ví dụ Windows Certificate Store hoặc Azure Key Vault.
- **Column Encryption Key (CEK):** key dùng để mã hóa giá trị trong cột; bản CEK được lưu trong metadata ở dạng đã được CMK bảo vệ.

### 3.2 Mã hóa tất định và mã hóa ngẫu nhiên

| Loại | Cùng plaintext → cùng ciphertext? | Khả năng truy vấn | Bảo mật |
|---|---:|---|---|
| Deterministic | Có | Equality lookup/join trong các trường hợp được hỗ trợ | Thấp hơn randomized vì lộ pattern |
| Randomized | Không | Hạn chế hơn nếu không dùng secure enclave | Cao hơn |
| Secure enclave | — | Cho phép thêm các phép toán được hỗ trợ bên trong enclave | Cần cấu hình enclave/attestation phù hợp |

**Exam keywords:**
- “exact equality search / equality join” → cân nhắc **deterministic**.
- “maximum confidentiality, không cần tìm kiếm trên cột” → **randomized**.
- “DBA/database engine không được xem plaintext” → **Always Encrypted**, không phải TDE/DDM.
- “cần richer comparison trên dữ liệu Always Encrypted” → xem **secure enclaves**.

### 3.3 T-SQL metadata minh họa

CMK/CEK thường được tạo qua SSMS, PowerShell hoặc driver để tạo đúng encrypted CEK blob. Đừng tự chế giá trị cryptographic trong bài thực hành.

```sql
-- Mẫu metadata CMK dùng Azure Key Vault.
-- KEY_PATH phải trỏ đến key thật mà client có quyền sử dụng.
CREATE COLUMN MASTER KEY CMK_AzureKeyVault
WITH
(
    KEY_STORE_PROVIDER_NAME = N'AZURE_KEY_VAULT',
    KEY_PATH = N'https://<vault-name>.vault.azure.net/keys/<key-name>/<key-version>'
);
GO

-- CEK cần ENCRYPTED_VALUE được công cụ/driver tạo bằng CMK.
-- Đây là skeleton để nhớ cấu trúc, KHÔNG phải blob giả để chạy production.
CREATE COLUMN ENCRYPTION KEY CEK_PII
WITH VALUES
(
    COLUMN_MASTER_KEY = CMK_AzureKeyVault,
    ALGORITHM = 'RSA_OAEP',
    ENCRYPTED_VALUE = 0x<GENERATED_BY_SUPPORTED_TOOL>
);
GO
```

Tham khảo:
- [Always Encrypted overview](https://learn.microsoft.com/en-us/sql/relational-databases/security/encryption/always-encrypted-database-engine?view=sql-server-ver17)
- [Always Encrypted with secure enclaves](https://learn.microsoft.com/en-us/sql/relational-databases/security/encryption/always-encrypted-enclaves?view=sql-server-ver17)

---

## 4. Che dữ liệu động (Dynamic Data Masking — DDM)

DDM **không biến dữ liệu thật thành ciphertext**. User có quyền SELECT vẫn truy vấn bảng, nhưng nếu không có `UNMASK`, giá trị nhạy cảm bị che trong result set.

### 4.1 Năm cách che dữ liệu cần nhận diện

- `default()`
- `email()`
- `random(start, end)` — numeric.
- `partial(prefix, "padding", suffix)`
- `datetime("Y"|"M"|"D"|"h"|"m"|"s")` — SQL Server 2022+.

### 4.2 Bài thực hành

```sql
CREATE TABLE dbo.Customers
(
    CustomerId int IDENTITY
        CONSTRAINT PK_Customers PRIMARY KEY,
    FullName nvarchar(100) NOT NULL,
    Email varchar(100)
        MASKED WITH (FUNCTION = 'email()') NOT NULL,
    CreditCard varchar(19)
        MASKED WITH (FUNCTION = 'partial(0,"XXXX-XXXX-XXXX-",4)') NOT NULL,
    Salary decimal(18,2)
        MASKED WITH (FUNCTION = 'default()') NOT NULL,
    BirthDate date
        MASKED WITH (FUNCTION = 'datetime("Y")') NULL
);
GO

CREATE USER SupportUser WITHOUT LOGIN;
GRANT SELECT ON dbo.Customers TO SupportUser;
GO

EXECUTE AS USER = 'SupportUser';
SELECT * FROM dbo.Customers; -- thấy masked values
REVERT;
GO

-- Database-level UNMASK
GRANT UNMASK TO SupportUser;
GO

EXECUTE AS USER = 'SupportUser';
SELECT * FROM dbo.Customers; -- thấy giá trị thật
REVERT;
GO

REVOKE UNMASK FROM SupportUser;
GO
```

SQL Server 2022+ hỗ trợ **granular UNMASK** ở database/schema/table/column level. Trong exam, hãy chọn phạm vi nhỏ nhất đáp ứng yêu cầu.

**Bẫy:** DDM không phải ranh giới bảo mật hoàn chỉnh. Người dùng có quyền truy vấn vẫn có thể suy luận dữ liệu qua biểu thức, tùy quyền được cấp. Khi yêu cầu bảo mật cao, luôn kết hợp quyền truy cập, RLS và mã hóa.

Tham khảo: [Dynamic Data Masking](https://learn.microsoft.com/en-us/sql/relational-databases/security/dynamic-data-masking?view=sql-server-ver17)

---

## 5. Bảo mật theo dòng (Row-Level Security — RLS)

RLS dùng:
1. **Inline table-valued function (iTVF)** làm predicate.
2. **Security Policy** gắn predicate vào bảng.

### 5.1 Điều kiện lọc và điều kiện chặn

- **FILTER PREDICATE:** lọc các dòng mà principal không được phép truy cập. Nó có tác dụng với các thao tác đọc và các thao tác DML liên quan theo cơ chế RLS, không chỉ riêng `SELECT`.
- **BLOCK PREDICATE:** chặn thao tác ghi làm cho row vi phạm policy. Có thể dùng `BEFORE`/`AFTER` cho các operation phù hợp.

### 5.2 Hệ thống nhiều khách hàng dùng chung với `SESSION_CONTEXT`

Ví dụ đặt `TenantId` vào session hiện tại, rồi RLS dùng giá trị đó để tự động lọc các dòng thuộc tenant khác.

```sql
CREATE SCHEMA Security;
GO

CREATE TABLE dbo.SalesData
(
    SaleId bigint IDENTITY
        CONSTRAINT PK_SalesData PRIMARY KEY,
    TenantId int NOT NULL,
    Product nvarchar(100) NOT NULL,
    Amount decimal(18,2) NOT NULL
);
GO

CREATE OR ALTER FUNCTION Security.fn_TenantPredicate
(
    @TenantId int
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS Allowed
    WHERE @TenantId =
          TRY_CONVERT(int, SESSION_CONTEXT(N'TenantId'))
);
GO

CREATE SECURITY POLICY Security.TenantPolicy
ADD FILTER PREDICATE
    Security.fn_TenantPredicate(TenantId)
    ON dbo.SalesData,
ADD BLOCK PREDICATE
    Security.fn_TenantPredicate(TenantId)
    ON dbo.SalesData AFTER INSERT,
ADD BLOCK PREDICATE
    Security.fn_TenantPredicate(TenantId)
    ON dbo.SalesData AFTER UPDATE
WITH (STATE = ON);
GO

-- Ứng dụng/middleware thiết lập tenant cho connection/session.
EXEC sys.sp_set_session_context
    @key = N'TenantId',
    @value = 10;
GO

SELECT * FROM dbo.SalesData;
GO
```

### Cách chọn trong đề

- “User chỉ được thấy rows của tenant mình” → FILTER.
- “User không được INSERT/UPDATE row sang tenant khác” → BLOCK.
- “Ứng dụng dùng connection pool” → phải set/reset `SESSION_CONTEXT` đúng trên từng session; đừng tin input tenant từ client nếu chưa xác thực.

Tham khảo: [Row-Level Security](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security?view=sql-server-ver17)

---

## 6. Quyền ở cấp đối tượng — nội dung bắt buộc

### 6.1 Ba động từ cần thuộc

- `GRANT`: cho phép.
- `DENY`: từ chối rõ ràng; thường thắng grant ở scope liên quan.
- `REVOKE`: gỡ GRANT/DENY trước đó, không có nghĩa là tự động DENY.

### 6.2 Ưu tiên vai trò (role) thay vì cấp quyền rải rác cho từng người dùng

Đoạn lệnh sau cấp quyền cho một vai trò rồi thêm người dùng vào vai trò đó. Khi nhân sự thay đổi, bạn chỉ quản lý thành viên mà không phải sửa hàng loạt lệnh cấp quyền.

```sql
CREATE ROLE reporting_reader;
GO

GRANT SELECT ON SCHEMA::Reporting
TO reporting_reader;
GO

ALTER ROLE reporting_reader
ADD MEMBER ReportUser;
GO
```

### 6.3 Chỉ cấp quyền `EXECUTE` cho stored procedure

```sql
CREATE ROLE app_executor;
GO

GRANT EXECUTE ON OBJECT::dbo.usp_CreateOrder
TO app_executor;
GO
```

**Exam principle: Least privilege.** Nếu app chỉ cần chạy SP thì không cấp `db_owner`, không cấp SELECT/UPDATE trực tiếp toàn schema nếu không cần.

Tham khảo: [Database Engine permissions](https://learn.microsoft.com/en-us/sql/relational-databases/security/permissions-database-engine?view=sql-server-ver17)

---

## 7. Truy cập cơ sở dữ liệu không mật khẩu với Microsoft Entra ID và Managed Identity

### 7.1 Cách hình dung

Luồng sau tách xác thực danh tính khỏi phân quyền trong database: Entra xác nhận “ai”, còn SQL quyết định danh tính đó “được làm gì”.

```text
Azure resource (App Service / Function / Container App)
    │ có Managed Identity
    ↓ lấy Entra token
Azure SQL
    │ user được tạo FROM EXTERNAL PROVIDER
    ↓
GRANT đúng quyền cần thiết
```

### 7.2 Tạo người dùng cho danh tính Entra hoặc Managed Identity

```sql
-- Chạy trong target database với Entra admin / principal đủ quyền
CREATE USER [my-app-managed-identity]
FROM EXTERNAL PROVIDER;
GO

GRANT EXECUTE ON SCHEMA::api
TO [my-app-managed-identity];
GO
```

Connection string của app dùng authentication dựa trên Microsoft Entra/Managed Identity, không chứa password SQL.

**Exam keywords:**
- “No password / no secret / credential rotation burden” → Managed Identity hoặc federated identity.
- “Azure resource accessing Azure SQL” → Managed Identity là lựa chọn ưu tiên khi được hỗ trợ.
- “Least privilege” → tạo contained user + chỉ GRANT phạm vi cần thiết.

Tham khảo:
- [Microsoft Entra authentication for Azure SQL](https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-overview?view=azuresql)
- [Azure SQL passwordless connections](https://learn.microsoft.com/en-us/azure/azure-sql/database/azure-sql-passwordless-migration?view=azuresql)

---

## 8. Ghi nhật ký kiểm toán (Auditing)

### 8.1 Phân biệt

**SQL Server:**
- `SERVER AUDIT` định nghĩa target.
- `SERVER AUDIT SPECIFICATION` chọn server-level audit actions.
- `DATABASE AUDIT SPECIFICATION` chọn database-level actions.

**Azure SQL Database:**
- Auditing có thể gửi đến các target Azure phù hợp như Storage/Log Analytics/Event Hubs tùy cấu hình.
- Log Analytics phù hợp khi cần KQL, alert, centralized monitoring.

### 8.2 Bài thực hành SQL Server Audit

```sql
USE master;
GO

CREATE SERVER AUDIT DP800_Audit
TO FILE
(
    FILEPATH = 'C:\SQLAudit\'
);
GO

ALTER SERVER AUDIT DP800_Audit
WITH (STATE = ON);
GO

USE YourLabDatabase;
GO

CREATE DATABASE AUDIT SPECIFICATION DP800_DbAuditSpec
FOR SERVER AUDIT DP800_Audit
ADD (SELECT ON OBJECT::dbo.Customers BY public),
ADD (INSERT ON OBJECT::dbo.Customers BY public),
ADD (UPDATE ON OBJECT::dbo.Customers BY public);
GO

ALTER DATABASE AUDIT SPECIFICATION DP800_DbAuditSpec
WITH (STATE = ON);
GO
```

KQL khi audit được đưa vào Log Analytics thường bắt đầu từ category security audit phù hợp với resource/configuration:

```kusto
AzureDiagnostics
| where Category == "SQLSecurityAuditEvents"
| project TimeGenerated, ResourceId, action_name_s, statement_s
| order by TimeGenerated desc
```

Tham khảo:
- [SQL Server Audit](https://learn.microsoft.com/en-us/sql/relational-databases/security/auditing/sql-server-audit-database-engine?view=sql-server-ver17)
- [Azure SQL auditing](https://learn.microsoft.com/en-us/azure/azure-sql/database/auditing-overview?view=azuresql)

---

## 9. Bảo vệ model endpoint bằng Managed Identity

DP-800 có thể đưa ra tình huống Azure SQL gọi Azure OpenAI hoặc REST endpoint qua `sp_invoke_external_rest_endpoint`.

### 9.1 Các mảnh cần hiểu

1. Azure SQL có Managed Identity.
2. MI được cấp role phù hợp trên Azure resource đích.
3. Database scoped credential đại diện cho authentication.
4. Chỉ principal cần thiết mới có quyền gọi external endpoint.

### 9.2 Khả năng hỗ trợ và cách bật theo từng nền tảng

| Platform | Availability/enablement ngày 09/08/2026 |
|---|---|
| Azure SQL Database | Có và enabled mặc định |
| SQL database in Fabric | Có và enabled mặc định |
| Azure SQL Managed Instance | Cần update policy SQL Server 2025/Always-up-to-date; disabled mặc định |
| SQL Server 2025 | Có; disabled mặc định |

Trên **SQL Server 2025** và **Azure SQL Managed Instance**, principal có `ALTER SETTINGS` (hoặc role phù hợp như `sysadmin`/`serveradmin`) bật tính năng một lần ở server/instance:

```sql
EXECUTE sys.sp_configure 'external rest endpoint enabled', 1;
RECONFIGURE WITH OVERRIDE;
GO

-- Riêng SQL Server 2025: cần thêm option này nếu credential
-- dùng Managed Identity.
EXECUTE sys.sp_configure 'allow server scoped db credentials', 1;
RECONFIGURE WITH OVERRIDE;
GO
```

> **Bẫy:** không chạy hai lệnh `sp_configure` này trên Azure SQL Database/Fabric chỉ vì thấy chúng trong ví dụ SQL Server. Luôn đọc kỹ nền tảng trong tình huống.

### 9.3 Thông tin xác thực dùng Managed Identity và quyền tối thiểu

```sql
CREATE DATABASE SCOPED CREDENTIAL
    [https://my-openai-resource.openai.azure.com]
WITH
    IDENTITY = 'Managed Identity',
    SECRET = '{"resourceid":"https://cognitiveservices.azure.com"}';
GO

-- Principal ứng dụng minh họa. Trong Azure, thường là Entra user/Managed Identity.
CREATE USER RestEndpointCaller WITHOUT LOGIN;
GO

-- Quyền gọi external endpoint và quyền dùng credential là HAI quyền khác nhau.
GRANT EXECUTE ANY EXTERNAL ENDPOINT TO RestEndpointCaller;
GRANT REFERENCES ON DATABASE SCOPED CREDENTIAL::
    [https://my-openai-resource.openai.azure.com]
TO RestEndpointCaller;
GO
```

Ngoài database, Managed Identity của SQL resource phải được cấp đúng data-plane role trên resource đích (ví dụ role Azure OpenAI phù hợp). Credential name phải là URL không có query string, và protocol/FQDN/path phải khớp hoặc là prefix hợp lệ của request URL.

Ví dụ gọi endpoint:

```sql
DECLARE @response nvarchar(max);

DECLARE @http_status int;

EXEC @http_status = sys.sp_invoke_external_rest_endpoint
    @url = N'https://my-openai-resource.openai.azure.com/openai/deployments/my-model/chat/completions?api-version=<supported-api-version>',
    @method = N'POST',
    @credential = N'https://my-openai-resource.openai.azure.com',
    @headers = N'{"Content-Type":"application/json"}',
    @payload = N'{
        "messages": [
            {"role":"user","content":"Tóm tắt nội dung này"}
        ]
    }',
    @response = @response OUTPUT;

SELECT @http_status AS HttpStatus, @response AS ResponseBody;
GO
```

> Phiên bản API và tên model phải dùng giá trị mà tài nguyên của bạn đang hỗ trợ. Không ghi thẳng API key vào mã nếu tình huống yêu cầu xác thực không mật khẩu.

Chỉ **HTTPS/TLS** được hỗ trợ; procedure không tự đi theo chuyển hướng HTTP. Mã trả về là `0` khi nhận HTTP 2xx, là mã trạng thái HTTP nếu phản hồi không thuộc nhóm 2xx; lỗi khiến không thể thực hiện lời gọi sẽ được ném thành exception. Vì vậy phải kiểm tra cả mã trả về lẫn `@response`.

Tham khảo: [sp_invoke_external_rest_endpoint](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-invoke-external-rest-endpoint-transact-sql?view=sql-server-ver17)

---

## 10. Bảo vệ các endpoint REST, GraphQL và MCP

Đây là phần thường bị học quá sơ sài.

### 10.1 Ba lớp bảo mật

Một endpoint an toàn cần đủ ba lớp: xác thực request, giới hạn thao tác ở API và tiếp tục thực thi quyền thật trong database.

```text
Authentication  → Bạn là ai?
Authorization   → Bạn được làm gì?
Database policy → Row/object nào thực sự được phép?
```

### 10.2 Danh sách kiểm tra bảo mật DAB

- Ở môi trường thật (production), không để endpoint nhạy cảm cho phép truy cập ẩn danh nếu không có yêu cầu rõ ràng.
- Dùng Microsoft Entra ID/JWT provider khi phù hợp.
- Entity permissions phải **allow-list** action/field cần thiết.
- DAB → Azure SQL nên dùng Managed Identity/passwordless nếu có thể.
- Với RLS phụ thuộc **identity thật của caller**, DAB 2.0 có **On-Behalf-Of (OBO)** cho Microsoft SQL; khi đó SQL thấy caller thực thay vì chỉ service identity.
- GraphQL introspection nên cân nhắc tắt ở production nếu threat model yêu cầu giảm schema discovery.
- MCP: chỉ expose tool/action cần thiết; read-only nếu agent chỉ cần đọc. Stored procedure custom tools nên có contract nhỏ, permission rõ ràng và validation phía SQL.
- Không đưa connection string/API key vào prompt, source repository hoặc `dab-config.json`.

### 10.3 Vì sao OBO quan trọng?

Mặc định một API service có thể kết nối DB bằng **identity của service**. Nếu RLS dựa vào database user thực của người gọi, DB chỉ thấy service identity. OBO cho phép DAB đổi user token thành SQL token để downstream SQL thấy caller thực.

Tham khảo:
- [DAB authentication](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/security/authentication)
- [DAB authorization](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/security/authorization)
- [DAB 2.0 — OBO và MCP](https://learn.microsoft.com/en-us/azure/data-api-builder/whats-new/version-2-0)
- [Configure DAB On-Behalf-Of](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/security/authenticate-on-behalf-of)

---

# PHẦN 2 — BÀI THỰC HÀNH TỔNG HỢP

## Bài thực hành A — kết hợp RLS, DDM và phân quyền theo tầng

Mục tiêu: cùng một bảng nhưng:
- RLS giới hạn row theo tenant.
- DDM che email.
- role chỉ có SELECT.
- `UNMASK` chỉ cấp khi thật sự cần.

```sql
CREATE TABLE dbo.TenantCustomers
(
    CustomerId int IDENTITY PRIMARY KEY,
    TenantId int NOT NULL,
    FullName nvarchar(100) NOT NULL,
    Email varchar(200)
        MASKED WITH (FUNCTION='email()') NOT NULL
);
GO

CREATE ROLE tenant_reader;
GRANT SELECT ON dbo.TenantCustomers TO tenant_reader;
GO

-- Predicate function
CREATE OR ALTER FUNCTION Security.fn_TenantCustomerPredicate(@TenantId int)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS Allowed
    WHERE @TenantId =
          TRY_CONVERT(int, SESSION_CONTEXT(N'TenantId'))
);
GO

CREATE SECURITY POLICY Security.TenantCustomerPolicy
ADD FILTER PREDICATE
    Security.fn_TenantCustomerPredicate(TenantId)
    ON dbo.TenantCustomers,
ADD BLOCK PREDICATE
    Security.fn_TenantCustomerPredicate(TenantId)
    ON dbo.TenantCustomers AFTER INSERT,
ADD BLOCK PREDICATE
    Security.fn_TenantCustomerPredicate(TenantId)
    ON dbo.TenantCustomers AFTER UPDATE
WITH (STATE=ON);
GO
```

**Tự kiểm tra:** Nếu user có SELECT nhưng không UNMASK, họ chỉ thấy row tenant của mình **và** email vẫn bị masked.

---

# PHẦN 3 — BẢNG CHỌN GIẢI PHÁP

| Từ khóa trong câu hỏi | Nghĩ đến |
|---|---|
| Protect database files/backups at rest | TDE |
| DBA/database engine không xem plaintext cột | Always Encrypted |
| Exact equality trên classic AE | Deterministic encryption |
| Che dữ liệu khi hiển thị cho support user | DDM |
| User chỉ thấy row của tenant mình | RLS FILTER |
| Ngăn insert/update sang tenant khác | RLS BLOCK |
| App Azure → Azure SQL, no passwords | Managed Identity + Entra |
| Chỉ được chạy SP, không được đọc bảng | `GRANT EXECUTE` đúng object/schema |
| Ai đã SELECT/UPDATE dữ liệu? | Auditing |
| SQL gọi Azure model endpoint không API key | Managed Identity + database scoped credential |
| DB phải thấy danh tính người gọi DAB thật | DAB OBO (khi phù hợp) |
| AI agent chỉ cần query read-only | Giới hạn MCP tools/permissions, least privilege |

---

# PHẦN 4 — CÂU HỎI THI THỬ

### Câu 1
Một DBA phải quản trị SQL nhưng không được phép xem SSN plaintext ngay cả khi truy vấn bảng. Giải pháp phù hợp nhất?

A. TDE  
B. DDM  
C. Always Encrypted  
D. RLS

**Đáp án: C.** TDE không ngăn DB engine đọc plaintext; DDM chỉ che presentation; RLS kiểm soát row.

### Câu 2
Support team được SELECT bảng Customer nhưng chỉ được xem email dạng masked. Khi nào dùng `UNMASK`?

**Đáp án:** Chỉ cấp cho danh tính thực sự có yêu cầu xem giá trị thật. `SELECT` và `UNMASK` là hai quyền khác nhau.

### Câu 3
Ứng dụng multi-tenant đã có filter predicate nhưng user vẫn chèn row mang TenantId khác. Cần gì?

**Đáp án:** Thêm **BLOCK PREDICATE** cho operation ghi phù hợp.

### Câu 4
Bạn cần bỏ quyền đã GRANT trước đó nhưng không muốn tạo explicit deny. Dùng?

**Đáp án:** `REVOKE`.

### Câu 5
Azure Function cần kết nối Azure SQL, policy cấm password. Chọn?

**Đáp án:** Managed Identity + tạo Entra user trong DB + GRANT least privilege.

### Câu 6
Cần mã hóa riêng một cột bằng key trong database và T-SQL phải gọi hàm mã hóa/giải mã. Chọn?

**Đáp án:** Column-level encryption (`EncryptByKey` / `DecryptByKey`), không phải DDM.

### Câu 7
Cần biết ai đã truy vấn object nhạy cảm để phục vụ forensics. Chọn?

**Đáp án:** Auditing với audit action/specification phù hợp; trên Azure có thể đưa log tới Log Analytics để truy vấn/alert.

### Câu 8
DAB dùng một service identity để vào SQL nhưng policy RLS cần nhận dạng actual caller. Tính năng DAB 2.0 nào đáng cân nhắc?

**Đáp án:** On-Behalf-Of (OBO) user delegation, nếu các prerequisite phù hợp.

---

# PHẦN 5 — DANH SÁCH TỰ KIỂM TRA

Bạn chỉ nên đánh dấu `[x]` nếu có thể **giải thích bằng lời + viết syntax chính mà không nhìn tài liệu**.

- [ ] Phân biệt TDE / column-level encryption / Always Encrypted / DDM.
- [ ] Giải thích CMK và CEK của Always Encrypted.
- [ ] Chọn mã hóa tất định (deterministic) hay ngẫu nhiên (randomized) theo tình huống.
- [ ] Tạo DDM và giải thích `UNMASK`.
- [ ] Tạo RLS iTVF + FILTER + BLOCK predicate.
- [ ] Phân biệt GRANT / DENY / REVOKE và role-based permissions.
- [ ] Thiết kế Azure SQL passwordless với Managed Identity.
- [ ] Giải thích SQL Server/Azure SQL auditing và Log Analytics.
- [ ] Tạo database scoped credential cho Managed Identity.
- [ ] Giải thích cách bảo vệ REST/GraphQL/MCP bằng authentication + authorization + least privilege.
- [ ] Giải thích khi nào DAB OBO hữu ích cho RLS/auditing.

---

# TÀI LIỆU THAM KHẢO

1. [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
2. [Implement data security and compliance — Microsoft Learn](https://learn.microsoft.com/en-us/training/modules/implement-data-security-compliance/)
3. [Always Encrypted](https://learn.microsoft.com/en-us/sql/relational-databases/security/encryption/always-encrypted-database-engine?view=sql-server-ver17)
4. [Dynamic Data Masking](https://learn.microsoft.com/en-us/sql/relational-databases/security/dynamic-data-masking?view=sql-server-ver17)
5. [Row-Level Security](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security?view=sql-server-ver17)
6. [Permissions](https://learn.microsoft.com/en-us/sql/relational-databases/security/permissions-database-engine?view=sql-server-ver17)
7. [Azure SQL auditing](https://learn.microsoft.com/en-us/azure/azure-sql/database/auditing-overview?view=azuresql)
8. [DAB 2.0](https://learn.microsoft.com/en-us/azure/data-api-builder/whats-new/version-2-0)
