# DP-800 — Miền 2 và Miền 3

> Theo mục tiêu Microsoft hiện hành ngày 12/03/2026: **Bảo mật, tối ưu hóa và triển khai** chiếm 35–40%; **Triển khai khả năng AI trong giải pháp cơ sở dữ liệu** chiếm 25–30%.

## PHẦN A — Bảo mật, tối ưu hóa và triển khai

## 1. Mô hình bảo mật SQL

Phân biệt:

- **Authentication**: xác thực người dùng là ai.
- **Authorization**: người dùng được phép làm gì.
- **Encryption**: bảo vệ dữ liệu khỏi bị đọc trái phép.
- **Auditing**: ghi nhận ai đã làm gì.

Nguyên tắc chính: **least privilege** — chỉ cấp đúng quyền cần thiết.

```sql
CREATE ROLE app_reader;
CREATE USER AppUser WITHOUT LOGIN;

GRANT SELECT ON SCHEMA::dbo TO app_reader;
ALTER ROLE app_reader ADD MEMBER AppUser;

DENY DELETE ON dbo.Customer TO AppUser;
```

Ưu tiên cấp quyền cho role, sau đó thêm user vào role; tránh cấp quyền trực tiếp cho từng user.

## 2. Mã hóa

| Công nghệ | Mục tiêu |
|---|---|
| TDE | Mã hóa dữ liệu lưu trên đĩa và backup ở cấp database |
| Always Encrypted | Bảo vệ cột nhạy cảm, kể cả trước DBA; client giữ khóa |
| Column-level encryption | Mã hóa chọn lọc từng cột bằng khóa/certificate |
| TLS | Mã hóa đường truyền |
| Dynamic Data Masking | Che dữ liệu trong result set; dữ liệu gốc không đổi |

Always Encrypted cần client driver hỗ trợ và ứng dụng phải có quyền truy cập column master key. DDM không phải mã hóa và không thay thế kiểm soát truy cập.

Ví dụ mã hóa cột ở mức database bằng certificate:

```sql
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Strong_password_ChangeMe!';
CREATE CERTIFICATE DataCert
    WITH SUBJECT = 'Column encryption certificate';

CREATE SYMMETRIC KEY DataKey
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE DataCert;

OPEN SYMMETRIC KEY DataKey
    DECRYPTION BY CERTIFICATE DataCert;

INSERT INTO dbo.SecretData(SecretValue)
VALUES (EncryptByKey(Key_GUID('DataKey'), N'confidential'));

SELECT CONVERT(nvarchar(200), DecryptByKey(SecretValue))
FROM dbo.SecretData;

CLOSE SYMMETRIC KEY DataKey;
```

## 3. Dynamic Data Masking

DDM che dữ liệu khi trả về, không thay đổi dữ liệu thật.

```sql
ALTER TABLE dbo.Customer
ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');

ALTER TABLE dbo.Customer
ADD Phone varchar(20) MASKED WITH (FUNCTION = 'partial(0,"******",4)');

GRANT UNMASK ON dbo.Customer TO SupportManager;
```

Bẫy: administrator hoặc user có quyền cao vẫn có thể xem dữ liệu không bị mask. DDM không bảo vệ khỏi mọi kỹ thuật truy vấn; cần kết hợp quyền, RLS và encryption.

## 4. Row-Level Security (RLS)

RLS lọc hàng dựa trên user hoặc context của phiên.

```sql
CREATE FUNCTION Security.fn_TenantPredicate(@TenantId int)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS Allowed
    WHERE @TenantId = CAST(SESSION_CONTEXT(N'TenantId') AS int)
);
GO

CREATE SECURITY POLICY Security.TenantPolicy
ADD FILTER PREDICATE Security.fn_TenantPredicate(TenantId)
ON dbo.Orders
WITH (STATE = ON);
```

Ứng dụng middleware có thể đặt context:

```sql
EXEC sys.sp_set_session_context
    @key = N'TenantId', @value = 10;
```

- `FILTER PREDICATE`: ẩn các dòng không được xem.
- `BLOCK PREDICATE`: ngăn insert/update/delete không hợp lệ.
- RLS bảo vệ ở database, không phụ thuộc hoàn toàn vào ứng dụng.

## 5. Auditing

Audit dùng để biết ai truy cập hoặc thay đổi dữ liệu. Không nhầm audit với backup hay temporal table.

```sql
CREATE SERVER AUDIT AuditServer
TO FILE (FILEPATH = 'C:\SQLAudit\');
ALTER SERVER AUDIT AuditServer WITH (STATE = ON);

CREATE DATABASE AUDIT SPECIFICATION AuditDatabase
FOR SERVER AUDIT AuditServer
ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.Customer BY public)
WITH (STATE = ON);
```

Trong Azure, cân nhắc SQL Auditing, Azure Monitor, Log Analytics và Microsoft Defender for SQL.

## 6. Passwordless và Managed Identity

Trong Azure, ưu tiên Microsoft Entra ID và Managed Identity thay vì lưu password hoặc API key trong code.

Mẫu quyền cho identity:

```sql
CREATE USER [my-app-identity] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [my-app-identity];
GRANT EXECUTE ON SCHEMA::dbo TO [my-app-identity];
```

Trong ứng dụng:

- Lấy token bằng Managed Identity.
- Lưu secrets còn bắt buộc trong Azure Key Vault.
- Không đưa connection string, token hoặc API key vào Git.

## 7. Tối ưu hiệu suất

Quy trình chuẩn:

1. Đo trước khi sửa.
2. Xem Actual Execution Plan.
3. Kiểm tra logical reads bằng `STATISTICS IO`.
4. Kiểm tra CPU/thời gian bằng `STATISTICS TIME`.
5. Kiểm tra Query Store và DMVs.
6. Sửa query/index/schema.
7. Đo lại sau khi sửa.

```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT CustomerId, COUNT(*)
FROM dbo.SalesOrder
WHERE OrderDate >= '2026-01-01'
GROUP BY CustomerId;

SELECT TOP (20)
    total_elapsed_time,
    execution_count,
    total_logical_reads,
    last_execution_time,
    st.text
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
ORDER BY total_elapsed_time DESC;
```

Query Store:

```sql
ALTER DATABASE CURRENT SET QUERY_STORE = ON;
```

Tối ưu thường gặp:

- Tránh `SELECT *`.
- Tránh hàm trên cột trong `WHERE` nếu làm mất khả năng seek.
- Dùng tham số hóa để giảm plan cache bloat và SQL injection.
- Cập nhật statistics.
- Chọn index theo workload thực tế.
- Xử lý blocking/deadlock bằng transaction ngắn và thứ tự truy cập nhất quán.

## 8. Isolation và concurrency

| Isolation | Đặc điểm |
|---|---|
| Read Uncommitted | Có dirty read; ít blocking |
| Read Committed | Mặc định; không đọc dữ liệu chưa commit |
| Repeatable Read | Giữ khóa các dòng đã đọc |
| Serializable | Mạnh nhất; có thể blocking cao |
| Snapshot / RCSI | Dùng row versioning, giảm reader-writer blocking |

```sql
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRANSACTION;

UPDATE dbo.Account
SET Balance = Balance - 100
WHERE AccountId = 1;

COMMIT;
```

Deadlock thường giảm bằng cách:

- Transaction ngắn.
- Truy cập bảng theo cùng thứ tự.
- Có index tốt để giảm thời gian giữ khóa.
- Retry ở application khi nhận lỗi deadlock.

## 9. CI/CD với SQL Database Projects

Luồng khuyến nghị:

```text
Branch → Pull Request → Build → Unit test → Integration test
       → DACPAC/Artifact → Deploy test → Approval → Production
```

Các điểm cần nhớ:

- Schema nên nằm trong source control.
- Static/reference data nên được quản lý riêng, có kiểm soát.
- Dùng SQL Database Project để build model và phát hiện schema drift.
- Secret nằm trong Key Vault hoặc secret store, không nằm trong Git.
- Dùng migration/DACPAC phù hợp với chiến lược deployment.
- Có approval, code owner, branch policy và rollback plan.

Ví dụ build SDK-style project:

```powershell
dotnet build MyDatabase.sqlproj
```

## 10. Tích hợp Azure

### Data API builder (DAB)

DAB có thể expose bảng, view, stored procedure qua REST hoặc GraphQL. Cần chú ý:

- Authentication/authorization.
- Pagination, filtering, searching.
- Caching.
- Không expose trực tiếp bảng nhạy cảm.
- Chỉ expose view hoặc stored procedure cần thiết.

### Theo dõi và thay đổi dữ liệu

| Công nghệ | Khi dùng |
|---|---|
| Change Tracking | Biết dòng nào thay đổi, nhẹ hơn CDC |
| CDC | Cần dữ liệu thay đổi chi tiết hơn |
| Azure Function SQL trigger | Xử lý sự kiện bằng code |
| Logic Apps | Workflow ít code |
| Azure Monitor | Metrics, logs và alerts |
| Application Insights | Theo dõi ứng dụng/API |

---

# PHẦN B — Triển khai khả năng AI trong database

## 11. Embedding là gì?

Embedding biến văn bản, hình ảnh hoặc dữ liệu thành vector số biểu diễn ý nghĩa.

Ví dụ:

```text
"Cách đổi mật khẩu" → [0.12, -0.44, 0.81, ...]
```

Hai nội dung gần nghĩa thường có vector gần nhau hơn. Embedding không phải bản thân văn bản và không thay thế dữ liệu gốc.

## 12. Thiết kế dữ liệu embedding

Một bảng thường có:

```sql
CREATE TABLE dbo.DocumentChunk
(
    ChunkId bigint IDENTITY PRIMARY KEY,
    DocumentId bigint NOT NULL,
    ChunkText nvarchar(max) NOT NULL,
    Metadata nvarchar(max) NULL,
    Embedding vector(1536) NULL,
    ModelName varchar(100) NULL,
    EmbeddingVersion int NOT NULL DEFAULT 1,
    CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME()
);
```

Thiết kế tốt cần xác định:

- Chia tài liệu thành chunk theo đoạn/ngữ nghĩa, không cắt tùy tiện.
- Giữ metadata như `DocumentId`, tiêu đề, quyền truy cập, ngôn ngữ.
- Lưu model và version để có thể re-embed.
- Chỉ embedding các cột chứa thông tin có ý nghĩa tìm kiếm.
- Không đưa dữ liệu bí mật vào dịch vụ embedding nếu chưa có quyền và chính sách phù hợp.

## 13. Tạo embedding

Trên phiên bản hỗ trợ, có thể dùng hàm AI hoặc gọi model endpoint. Ví dụ khái niệm:

```sql
UPDATE dbo.DocumentChunk
SET Embedding = AI_GENERATE_EMBEDDINGS(
    ChunkText USE MODEL dbo.EmbeddingModel
);
```

Trong thực tế cần kiểm tra:

- Model có đúng số chiều vector không.
- Model có hỗ trợ ngôn ngữ cần tìm không.
- Chi phí, latency và quota.
- Cách cập nhật embedding khi văn bản thay đổi.

Microsoft liệt kê các cơ chế duy trì embedding như trigger, Change Tracking, CDC, CES, Azure Functions, Logic Apps hoặc Microsoft Foundry.

## 14. Vector search

Các khái niệm cần nhớ:

- **Vector distance**: đo khoảng cách giữa hai vector.
- **Cosine**: so sánh hướng vector, thường dùng cho semantic similarity.
- **Euclidean**: khoảng cách hình học.
- **ENN**: Exact Nearest Neighbor, chính xác hơn nhưng có thể chậm.
- **ANN**: Approximate Nearest Neighbor, nhanh hơn trên tập dữ liệu lớn nhưng gần đúng.

```sql
DECLARE @QueryVector vector(1536) = ...;

SELECT TOP (5)
    ChunkId,
    ChunkText,
    VECTOR_DISTANCE('cosine', Embedding, @QueryVector) AS Distance
FROM dbo.DocumentChunk
WHERE Embedding IS NOT NULL
ORDER BY Distance;
```

Chọn số chiều phải khớp giữa query vector và stored vector. Vector index cần đánh giá theo kích thước dữ liệu, độ chính xác mong muốn, metric và latency.

## 15. Full-text, vector và hybrid search

| Loại tìm kiếm | Tốt cho |
|---|---|
| Full-text | Từ khóa chính xác, tên, mã, thuật ngữ |
| Vector | Tìm theo ý nghĩa, câu hỏi diễn đạt khác nhau |
| Hybrid | Kết hợp từ khóa và ý nghĩa |

Hybrid search thường:

1. Chạy keyword search.
2. Chạy vector search.
3. Gộp hai danh sách.
4. Xếp hạng lại bằng RRF hoặc scoring khác.

Vector search không luôn thay thế full-text. Câu hỏi chứa mã sản phẩm, số hiệu hoặc tên chính xác thường cần keyword search.

## 16. RAG — Retrieval-Augmented Generation

Luồng RAG:

```text
Tài liệu → Chunk → Embedding → Vector store
          ↑                         ↓
Câu hỏi → Embedding → Retrieve top-k chunks
                         ↓
              Prompt + Context → LLM → Câu trả lời
```

RAG giúp model trả lời dựa trên dữ liệu doanh nghiệp cập nhật mà không nhất thiết phải fine-tune model.

Prompt nên chứa:

- Câu hỏi người dùng.
- Các chunk được truy xuất.
- Metadata hoặc nguồn trích dẫn.
- Quy tắc: chỉ trả lời dựa trên context; nếu thiếu thông tin thì nói không biết.

## 17. `sp_invoke_external_rest_endpoint`

Stored procedure này gọi HTTPS REST endpoint từ SQL Server 2025, Azure SQL Managed Instance phù hợp và SQL database trong Fabric theo khả năng hỗ trợ. Cần kiểm tra phiên bản, bật tính năng và cấp quyền an toàn.

```sql
DECLARE @response nvarchar(max);
DECLARE @payload nvarchar(max) =
    JSON_OBJECT('input': 'Explain row-level security in SQL Server');

EXEC sys.sp_invoke_external_rest_endpoint
    @url = N'https://<endpoint>/openai/deployments/<model>/chat/completions',
    @method = 'POST',
    @payload = @payload,
    @response = @response OUTPUT;

SELECT @response;
```

Không hard-code API key. Ưu tiên Managed Identity và database scoped credential:

```sql
CREATE DATABASE SCOPED CREDENTIAL [https://<endpoint>]
WITH IDENTITY = 'Managed Identity',
     SECRET = '{"resourceid":"https://cognitiveservices.azure.com"}';
```

Procedure này có thể truyền dữ liệu ra bên ngoài; cần least privilege, auditing, endpoint allow-list và kiểm soát dữ liệu nhạy cảm.

## 18. Bẫy thường gặp về AI

1. Embedding model và chat/generative model là hai loại model khác nhau.
2. Vector dimension phải giống nhau giữa dữ liệu và query.
3. Semantic search không bảo đảm đúng dữ liệu nghiệp vụ nếu không có filter metadata.
4. RAG cần retrieve context trước khi gọi LLM.
5. Top-k quá nhỏ có thể thiếu thông tin; quá lớn làm prompt dài và tăng chi phí.
6. Cần filter quyền truy cập trước hoặc trong bước retrieval.
7. Dữ liệu embedding cũ phải được cập nhật khi nội dung gốc thay đổi.
8. Không gửi PII hoặc secret tới external endpoint nếu chưa có chính sách bảo vệ.
9. ANN nhanh hơn nhưng có thể bỏ sót kết quả tốt nhất; ENN chính xác hơn nhưng tốn tài nguyên.
10. Hybrid search thường tốt hơn khi dữ liệu có cả từ khóa chính xác và nội dung ngữ nghĩa.

## 19. Bài lab tổng hợp

Xây dựng chatbot hỏi đáp tài liệu nội bộ:

1. Tạo bảng `Document` và `DocumentChunk`.
2. Chia tài liệu thành chunk, lưu metadata và quyền truy cập.
3. Tạo embedding cho mỗi chunk.
4. Tìm kiếm top-k bằng vector search.
5. Kết hợp keyword search nếu có mã/tên chính xác.
6. Dùng RRF để xếp hạng hybrid results.
7. Tạo prompt chứa context và nguồn.
8. Gọi model qua Azure endpoint hoặc `sp_invoke_external_rest_endpoint`.
9. Áp dụng RLS/filter theo tenant hoặc người dùng.
10. Audit truy cập và theo dõi latency, token, lỗi, chi phí.

## Tài liệu Microsoft

- [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
- [SQL security and compliance training](https://learn.microsoft.com/en-us/training/modules/implement-data-security-compliance/)
- [Dynamic Data Masking](https://learn.microsoft.com/en-us/sql/relational-databases/security/dynamic-data-masking)
- [Always Encrypted](https://learn.microsoft.com/en-us/sql/relational-databases/security/encryption/always-encrypted-how-queries-against-encrypted-columns-work)
- [sp_invoke_external_rest_endpoint](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-invoke-external-rest-endpoint-transact-sql)
- [AI_GENERATE_EMBEDDINGS](https://learn.microsoft.com/en-us/sql/t-sql/functions/ai-generate-embeddings-transact-sql)
