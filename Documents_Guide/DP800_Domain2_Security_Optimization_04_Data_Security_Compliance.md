# DP-800 Domain 2: Implement Data Security and Compliance

> **Miền 2:** Secure, Optimize, and Deploy Database Solutions (35–40%)  
> **Chủ đề:** Implement Data Security and Compliance  
> **Trọng tâm thi:** Encryption (Always Encrypted / TDE CMK AKV), Dynamic Data Masking (DDM), Row-Level Security (RLS), Managed Identity Passwordless Access, Securing Endpoints.

---

## 📘 PHẦN 1: LÝ THUYẾT & KIẾN THỨC CỐT LÕI (CORE THEORY)

### 1. Mã Hóa Dữ Liệu (Data Encryption Strategies)
- **Transparent Data Encryption (TDE):**
  - Mã hóa dữ liệu lưu trữ trên đĩa (Data files, Log files, Backups và TempDB) ở cấp Database.
  - *Customer-Managed Keys (CMK / BYOK):* Lưu Column Master Key trong **Azure Key Vault (AKV)** để doanh nghiệp tự quản lý và xoay vòng khoá mã hóa.
- **Always Encrypted (Mã Hóa Trực Tiếp Trên Client):**
  - Bảo vệ dữ liệu nhạy cảm (Số thẻ tín dụng, SSN, Lương) ngay tại Client Driver. Dữ liệu khi truyền qua mạng và nằm trong bộ nhớ SQL Server luôn ở dạng mã hóa (DBA cũng không xem được dữ liệu thật).
  - *Column Master Key (CMK):* Lưu tại Client Certificate Store hoặc Azure Key Vault.
  - *Column Encryption Key (CEK):* Dùng để mã hóa dữ liệu cột thật.
  - *Deterministic vs Randomized Encryption:*
    - **Deterministic (Xác định):** Cùng giá trị đầu vào sinh ra cùng ciphertext ➔ Cho phép tìm kiếm `WHERE Column = 'Val'`, `GROUP BY`, `JOIN`.
    - **Randomized (Ngẫu nhiên):** Cùng giá trị sinh ra ciphertext khác nhau ➔ Bảo mật cao hơn nhưng không cho phép tìm kiếm/JOIN.
  - *Always Encrypted với Secure Enclaves:* Cho phép tính năng bảo mật phần cứng (Intel SGX / VBS) giải mã an toàn trong enclave để thực hiện phép so sánh `LIKE`, `RANGE`, `ORDER BY`.

### 2. Che Dữ Liệu Động (Dynamic Data Masking - DDM)
- DDM **KHÔNG** mã hóa dữ liệu thật trên đĩa; DDM chỉ che dữ liệu khi trả về Result Set cho người dùng không có quyền `UNMASK`.
- Các hàm Mask phổ biến: `default()`, `email()`, `partial(prefix, padding, suffix)`, `random(min, max)`, `datetime("YYYY")`.
- Cấp quyền xem dữ liệu thật: `GRANT UNMASK TO UserOrRole`.

### 3. Bảo Mật Cấp Dòng (Row-Level Security - RLS)
- RLS kiểm soát quyền truy cập dòng dữ liệu dựa trên User hoặc `SESSION_CONTEXT`.
- **Filter Predicate:** Ẩn các dòng người dùng không có quyền xem khỏi tập kết quả (`SELECT`).
- **Block Predicate:** Ngăn chặn người dùng `INSERT`, `UPDATE`, `DELETE` các dòng dữ liệu không hợp lệ (`BEFORE/AFTER` predicate).
- Dùng `sp_set_session_context` trong middleware ứng dụng để truyền `TenantId` hoặc `UserId` an toàn.

### 4. Truy Cập Không Mật Khẩu & Managed Identity (Passwordless Access)
- **Microsoft Entra ID (Azure AD) Authentication:** Loại bỏ SQL Authentication truyền thống (User/Password).
- **Managed Identity (System-Assigned & User-Assigned):** Cho phép các dịch vụ Azure (Azure App Service, Azure Functions, Azure OpenAI, Data API builder) truy cập Azure SQL Database mà **KHÔNG** cần lưu mật khẩu hay Connection String chứa password trong mã nguồn.
- **Database Scoped Credential với Managed Identity:**  
  Dùng cho `sp_invoke_external_rest_endpoint` gọi REST API/Azure OpenAI.

### 5. Kiểm Toán Hệ Thống (SQL Server & Azure SQL Auditing)
- **SQL Server Audit 3 phần:** `SQL Server Audit` (nơi lưu tệp audit) ➔ `Server Audit Specification` (sự kiện cấp server như Login) ➔ `Database Audit Specification` (sự kiện DML `SELECT/INSERT/UPDATE` trên bảng).
- Đẩy log kiểm toán Azure SQL sang **Azure Monitor Log Analytics Workspace** để thiết lập Alert cảnh báo truy cập bất thường.

---

## 💻 PHẦN 2: THỰC HÀNH T-SQL (HANDS-ON LABS)

```sql
-- ============================================================================
-- LAB 4.1: DYNAMIC DATA MASKING (DDM) & UNMASK PERMISSION
-- ============================================================================
USE tempdb;
GO

CREATE TABLE dbo.Customers (
    CustomerId INT IDENTITY PRIMARY KEY,
    FullName NVARCHAR(100) NOT NULL,
    Email VARCHAR(100) MASKED WITH (FUNCTION = 'email()') NOT NULL,
    CreditCard VARCHAR(20) MASKED WITH (FUNCTION = 'partial(0, "XXXX-XXXX-XXXX-", 4)') NOT NULL,
    Salary DECIMAL(18,2) MASKED WITH (FUNCTION = 'default()') NOT NULL
);

INSERT INTO dbo.Customers VALUES ('Kien Bach', 'kien.bach@example.com', '4111-2222-3333-4444', 15000.00);

-- Tạo User kiểm thử bị DDM che
CREATE USER SupportUser WITHOUT LOGIN;
GRANT SELECT ON dbo.Customers TO SupportUser;

-- Kiểm tra dưới quyền SupportUser (Kết quả bị MASK)
EXECUTE AS USER = 'SupportUser';
SELECT * FROM dbo.Customers;
REVERT;

-- Cấp quyền UNMASK
GRANT UNMASK TO SupportUser;
GO

-- ============================================================================
-- LAB 4.2: ROW-LEVEL SECURITY (RLS) VỚI FILTER & BLOCK PREDICATE
-- ============================================================================
CREATE SCHEMA Security;
GO

CREATE TABLE dbo.SalesData (
    SaleId INT IDENTITY PRIMARY KEY,
    TenantId INT NOT NULL,
    Product NVARCHAR(50) NOT NULL,
    Amount DECIMAL(18,2) NOT NULL
);
GO

-- 1. Hàm Security Predicate dựa trên SESSION_CONTEXT
CREATE FUNCTION Security.fn_SecurityPredicate (@TenantId INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN (
    SELECT 1 AS fn_Result
    WHERE @TenantId = CAST(SESSION_CONTEXT(N'TenantId') AS INT)
       OR IS_MEMBER('db_owner') = 1
);
GO

-- 2. Tạo Security Policy gắn FILTER & BLOCK Predicate
CREATE SECURITY POLICY Security.SalesTenantPolicy
ADD FILTER PREDICATE Security.fn_SecurityPredicate(TenantId) ON dbo.SalesData,
ADD BLOCK PREDICATE Security.fn_SecurityPredicate(TenantId) ON dbo.SalesData AFTER INSERT
WITH (STATE = ON);
GO

-- ============================================================================
-- LAB 4.3: MANAGED IDENTITY & DATABASE SCOPED CREDENTIAL (PASSWORDLESS)
-- ============================================================================
-- Tạo Database Scoped Credential kết nối Azure OpenAI hoàn toàn Passwordless
CREATE DATABASE SCOPED CREDENTIAL [https://my-openai-resource.openai.azure.com]
WITH 
    IDENTITY = 'Managed Identity',
    SECRET = '{"resourceid":"https://cognitiveservices.azure.com"}';
GO
```

---

## 3. CÂU HỎI THI THỬ & TÌNH HUỐNG (MOCK TEST QUESTIONS)

#### Question 1 (Always Encrypted Encryption Types Scenario):
**Scenario:** You are designing a security strategy for a sensitive database table `dbo.Patients`. The column `SocialSecurityNumber` (SSN) must be encrypted using Always Encrypted. Application queries need to perform exact point lookups (`WHERE SocialSecurityNumber = @SSN`) and equality joins. Which Always Encrypted encryption type should you select?
- A. Randomized Encryption
- B. Deterministic Encryption
- C. Transparent Data Encryption (TDE)
- D. Dynamic Data Masking `partial()`

**👉 Correct Answer: B**  
*Explanation (Giải thích):* **Deterministic Encryption** luôn sinh ra cùng một giá trị chuỗi mã hóa cho cùng một giá trị đầu vào plaintext, cho phép ứng dụng thực hiện các truy vấn tìm kiếm chính xác (`WHERE SSN = @val`), `GROUP BY` và equality `JOIN`. (Trong khi Randomized Encryption không cho phép tìm kiếm/JOIN).

---

#### Question 2 (Passwordless Azure OpenAI Integration Scenario):
**Scenario:** You need to configure Azure SQL Database to call Azure OpenAI endpoints via `sp_invoke_external_rest_endpoint`. Your company's DevSecOps policy strictly prohibits storing API Keys, Passwords, or Secrets inside SQL Database credentials or configuration files. What authentication configuration should you implement?
- A. Create a Database Scoped Credential with `IDENTITY = 'Managed Identity'` and enable System-Assigned Managed Identity on Azure SQL.
- B. Store the Azure OpenAI API Key inside a SQL Server Table encrypted with Always Encrypted.
- C. Hardcode the API Key in the `@payload` parameter of `sp_invoke_external_rest_endpoint`.
- D. Use SQL Server Authentication with `sysadmin` privileges.

**👉 Correct Answer: A**  
*Explanation (Giải thích):* Để truy cập Azure OpenAI hoàn toàn Passwordless (không lưu API Key/Password), giải pháp chuẩn Microsoft là bật **Managed Identity** trên Azure SQL Server và tạo **Database Scoped Credential** sử dụng `IDENTITY = 'Managed Identity'`.

---

#### Question 3 (Row-Level Security Block Predicate Scenario):
**Scenario:** You implemented Row-Level Security (RLS) on a multi-tenant database table `dbo.Orders`. Users can currently view only their tenant's orders via a FILTER PREDICATE. However, a malicious user attempted to insert a row with a different tenant's ID (`TenantId = 999`), and the insert succeeded even though the user cannot view the inserted row. How should you fix this security vulnerability?
- A. Add a BLOCK PREDICATE `AFTER INSERT` to the Security Policy.
- B. Enable Transparent Data Encryption (TDE).
- C. Grant `UNMASK` permission to the user.
- D. Add a Foreign Key constraint on `TenantId`.

**👉 Correct Answer: A**  
*Explanation (Giải thích):* `FILTER PREDICATE` chỉ ẩn dữ liệu khi truy vấn (`SELECT`), không ngăn chặn người dùng `INSERT/UPDATE` dữ liệu của tenant khác. Để ngăn chặn việc chèn/sửa dữ liệu trái phép, bắt buộc phải thêm **BLOCK PREDICATE** (`AFTER INSERT / AFTER UPDATE`) vào RLS Security Policy.
