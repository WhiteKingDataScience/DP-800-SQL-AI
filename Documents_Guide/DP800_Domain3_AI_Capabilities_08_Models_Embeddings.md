# DP-800 Domain 3: Design and Implement Models and Embeddings

> **Miền 3:** Implement AI Capabilities in Database Solutions (25–30%)  
> **Chủ đề:** Design and Implement Models and Embeddings  
> **Blueprint dùng để cập nhật:** DP-800 Skills measured as of **March 12, 2026**  
> **Ngày rà soát tài liệu:** 09/08/2026  
> **Mục tiêu:** Học từ nền tảng đến mức có thể đọc scenario, chọn đúng giải pháp và viết được T-SQL cần thiết trong kỳ thi.

---

## 0. Bạn phải nắm được gì để “exam-ready”?

Theo DP-800 Study Guide hiện hành, phần **Design and implement models and embeddings** yêu cầu bạn có thể:

1. **Evaluate external models**: đánh giá model theo multimodal, multilingual, model size, structured output và yêu cầu bài toán.
2. **Create and manage external models**.
3. Chọn **embedding maintenance method** phù hợp: table trigger, Change Tracking, Azure Functions SQL trigger binding, Azure Logic Apps, CDC, Change Event Streaming (CES), Microsoft Foundry.
4. Chọn đúng cột/dữ liệu để đưa vào embedding.
5. Thiết kế và triển khai **chunking**.
6. Sinh embeddings bằng các khả năng native của Microsoft SQL.

> **Tư duy thi:** Microsoft thường không chỉ hỏi “cú pháp là gì?”, mà hỏi “với workload này, giải pháp nào phù hợp nhất và vì sao?”. Vì vậy tài liệu này luôn đi theo thứ tự **khái niệm → quyết định → cú pháp → lab → bẫy thi**.

---

# 📘 PHẦN 1 — NỀN TẢNG MODELS, EMBEDDINGS VÀ VECTOR

## 1. Vector embedding là gì?

**Embedding** là cách biến dữ liệu có ý nghĩa (text, hình ảnh hoặc loại dữ liệu mà model hỗ trợ) thành một dãy số gọi là **vector**.

Ví dụ:

```text
"quy trình đổi trả hàng"
       ↓ embedding model
[0.012, -0.045, 0.812, ..., 0.104]
```

Các câu có ý nghĩa gần nhau thường sinh ra các vector “gần nhau” theo một distance metric như **cosine**, **euclidean** hoặc **dot product**.

### Điều cần nhớ

- Embedding **không phải encryption** và không dùng để giấu dữ liệu.
- Embedding **không phải keyword index**.
- Embedding dùng cho **semantic similarity**: tìm dữ liệu có ý nghĩa tương đồng dù từ ngữ không giống hệt nhau.
- Một vector có **dimension cố định**. Cột SQL lưu vector phải phù hợp với dimension mà model trả về.

---

## 2. Native `VECTOR` trong Microsoft SQL

SQL Server 2025, Azure SQL Database, Azure SQL Managed Instance (theo policy hỗ trợ tương ứng) và SQL database in Microsoft Fabric hỗ trợ kiểu dữ liệu native `VECTOR`.

```sql
CREATE TABLE dbo.VectorDemo
(
    Id        int PRIMARY KEY,
    Embedding vector(3) NOT NULL
);

INSERT dbo.VectorDemo (Id, Embedding)
VALUES
    (1, '[0.1, 0.2, 0.3]'),
    (2, '[0.4, 0.5, 0.6]');
```

### Giới hạn dimension rất quan trọng

`VECTOR` hiện hỗ trợ tối đa **1,998 dimensions**.

Vì vậy:

- Model trả 1,536 dimensions → `VECTOR(1536)` phù hợp.
- Nếu một model mặc định trả hơn 1,998 dimensions, **không được tạo `VECTOR(3072)`**. Bạn cần chọn/điều chỉnh output dimension xuống giá trị được SQL hỗ trợ nếu endpoint/model hỗ trợ tham số `dimensions`, hoặc chọn model/output khác.

> **Bẫy thi:** Đừng chỉ nhớ dimension mặc định của một model rồi tạo cột theo máy móc. Hãy kiểm tra giới hạn của SQL `VECTOR` và output thực tế của deployment/model.

### `float32` và `float16`

- Mặc định: `VECTOR(n)` dùng `float32`.
- SQL Server 2025 có `VECTOR(n, float16)` ở trạng thái Preview và cần `PREVIEW_FEATURES` khi nền tảng yêu cầu.

```sql
-- Chỉ dùng khi nền tảng/version của bạn hỗ trợ Preview feature này.
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
GO

CREATE TABLE dbo.VectorHalfPrecisionDemo
(
    Id        int PRIMARY KEY,
    Embedding vector(384, float16)
);
```

### Khi nào cân nhắc `float16`?

- Muốn giảm storage/memory footprint.
- Chấp nhận giảm precision.
- Chỉ khi nền tảng/version đang dùng hỗ trợ.

Trong kỳ thi, nếu đề không yêu cầu Preview-specific optimization, mặc định an toàn là hiểu `VECTOR(n)` = `float32`.

---

# 📘 PHẦN 2 — EVALUATE EXTERNAL MODELS

## 3. “External model” trong DP-800 nghĩa là gì?

External model là AI model chạy ngoài database engine nhưng được SQL đăng ký thành object để T-SQL có thể gọi một cách có quản lý.

Trong phạm vi `CREATE EXTERNAL MODEL` hiện hành, model object được dùng cho **embedding inference** (`MODEL_TYPE = EMBEDDINGS`).

### Các tiêu chí cần đánh giá model

| Tiêu chí | Câu hỏi cần đặt ra | Tác động |
|---|---|---|
| **Task fit** | Model dùng cho embedding hay generation? | Chọn sai model → không giải được bài toán |
| **Multilingual** | Có hiểu tốt tiếng Việt + tiếng Anh không? | Quan trọng cho kho tri thức đa ngôn ngữ |
| **Multimodal** | Có cần text + image/audio không? | Ảnh hưởng model/architecture |
| **Dimensions** | Output vector bao nhiêu chiều? | Ảnh hưởng storage, index, compatibility |
| **Latency** | SLA tìm kiếm/ingestion là bao nhiêu? | Model lớn thường tốn thời gian hơn |
| **Cost** | Tần suất tạo/rebuild embeddings? | Ảnh hưởng chi phí inference |
| **Context/input limits** | Một request nhận tối đa bao nhiêu input? | Ảnh hưởng chunk size |
| **Structured output** | Downstream có cần JSON/schema ổn định không? | Quan trọng với generation workflow |
| **Data residency/security** | Dữ liệu có được phép rời region/service boundary? | Ảnh hưởng endpoint và identity |

> **Exam pattern:** “Cần semantic search đa ngôn ngữ, dữ liệu thay đổi thường xuyên, cần latency thấp” → bạn phải cân bằng **quality + vector size + inference latency + maintenance cost**, không phải cứ chọn model lớn nhất.

### Remote endpoint vs local ONNX runtime

Current `CREATE EXTERNAL MODEL` documentation còn hỗ trợ các API formats như Azure OpenAI/OpenAI/Ollama và **ONNX Runtime** (local runtime trên SQL Server trong điều kiện hỗ trợ). Đây là kiến thức mở rộng hữu ích cho câu hỏi “model chạy ở đâu / security boundary / latency”.

- Remote model: dễ dùng managed cloud model nhưng có network/auth/data-egress considerations.
- Local ONNX: inference gần SQL Server hơn nhưng phải quản lý runtime/model files và security của third-party model.

Trong DP-800, hãy ưu tiên nắm chắc external embedding model + Managed Identity; ONNX là related/current feature để nhận diện scenario.

---

# 📘 PHẦN 3 — `CREATE EXTERNAL MODEL` VÀ QUẢN LÝ MODEL

## 4. Syntax hiện hành của `CREATE EXTERNAL MODEL`

Cú pháp trọng yếu:

```sql
CREATE EXTERNAL MODEL model_name
WITH
(
    LOCATION    = '<model-inference-endpoint>',
    API_FORMAT  = 'Azure OpenAI',
    MODEL_TYPE  = EMBEDDINGS,
    MODEL       = '<embedding-model-name>',
    CREDENTIAL  = [<database-scoped-credential-name>],
    PARAMETERS  = '{"dimensions":1536}'
);
```

### Các thành phần cần thuộc

- `LOCATION`: endpoint inference.
- `API_FORMAT`: format/provider contract, ví dụ `'Azure OpenAI'`, `'OpenAI'`, `'Ollama'` theo nền tảng hỗ trợ.
- `MODEL_TYPE = EMBEDDINGS`: mục đích model object.
- `MODEL`: tên model.
- `CREDENTIAL`: database scoped credential dùng để authenticate.
- `PARAMETERS`: JSON optional; có thể khai báo tham số như dimension nếu endpoint hỗ trợ.

> **Sửa lỗi từ tài liệu cũ:** Không dùng mẫu `PROVIDER = AZURE_OPENAI`. Blueprint hiện hành cần học syntax `API_FORMAT`, `MODEL_TYPE`, `MODEL`, `CREDENTIAL`.

---

## 5. Authentication: ưu tiên Managed Identity khi scenario yêu cầu passwordless

### 5.1. Database scoped credential

Ví dụ khung cấu hình Managed Identity:

```sql
CREATE DATABASE SCOPED CREDENTIAL [https://<your-ai-resource-host>]
WITH
    IDENTITY = 'Managed Identity',
    SECRET   = '{"resourceid":"https://cognitiveservices.azure.com"}';
GO
```

Sau đó external model tham chiếu credential này.

> **Lưu ý quan trọng:** Role RBAC cụ thể cần cấp cho Managed Identity phụ thuộc loại resource, endpoint và tính năng đang gọi. Hãy dùng **least privilege** và kiểm tra tài liệu hiện hành của endpoint. Trong câu hỏi thi, nếu yêu cầu “không secrets/password/API key”, lựa chọn passwordless bằng **Managed Identity** thường là điểm mấu chốt.

### 5.2. External REST endpoint setting

Trên SQL Server 2025 và một số cấu hình Azure SQL Managed Instance, tính năng gọi external REST cần được bật:

```sql
EXECUTE sys.sp_configure 'external rest endpoint enabled', 1;
RECONFIGURE WITH OVERRIDE;
GO
```

Azure SQL Database và SQL database in Fabric có hành vi khác; luôn đọc phần **Applies to / prerequisites** của docs khi lab.

---

## 6. Lab: đăng ký embedding model

> Thay các placeholder `<...>` bằng endpoint/deployment thật của bạn.

```sql
-- ============================================================
-- LAB 8.1 - CREATE EXTERNAL MODEL
-- ============================================================

-- 1) Tạo credential passwordless
CREATE DATABASE SCOPED CREDENTIAL [https://<resource>.openai.azure.com]
WITH
    IDENTITY = 'Managed Identity',
    SECRET   = '{"resourceid":"https://cognitiveservices.azure.com"}';
GO

-- 2) Đăng ký embedding model
CREATE EXTERNAL MODEL DP800_EmbeddingModel
WITH
(
    LOCATION = 'https://<resource>.openai.azure.com/openai/deployments/<embedding-deployment>/embeddings?api-version=<supported-api-version>',
    API_FORMAT = 'Azure OpenAI',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'text-embedding-3-small',
    CREDENTIAL = [https://<resource>.openai.azure.com],
    PARAMETERS = '{"dimensions":1536}'
);
GO
```

### Kiểm tra model objects

```sql
SELECT *
FROM sys.external_models;
GO
```

### Permission để tạo và sử dụng external model

External model là database-level object (tên phải unique trong database; không học nó như một schema-qualified table object). Các permission hiện hành đáng biết:

```sql
-- Cho phép principal tạo external model
GRANT CREATE EXTERNAL MODEL TO [AIDeveloper];
GO

-- Hoặc quyền quản lý rộng hơn
GRANT ALTER ANY EXTERNAL MODEL TO [AIModelAdmin];
GO

-- Cho phép principal dùng model trong AI functions
GRANT EXECUTE ON EXTERNAL MODEL::DP800_EmbeddingModel TO [AIDeveloper];
GO
```

> **Bẫy thi:** Có model object chưa đủ; principal còn phải có permission thích hợp để sử dụng model.

### Retry cho embedding inference

Current `CREATE EXTERNAL MODEL` hỗ trợ cấu hình retry qua `PARAMETERS`:

```sql
ALTER EXTERNAL MODEL DP800_EmbeddingModel
SET
(
    LOCATION = 'https://<resource>.openai.azure.com/openai/deployments/<embedding-deployment>/embeddings?api-version=<supported-api-version>',
    API_FORMAT = 'Azure OpenAI',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'text-embedding-3-small',
    CREDENTIAL = [https://<resource>.openai.azure.com],
    PARAMETERS = '{"dimensions":1536,"sql_rest_options":{"retry_count":3}}'
);
GO
```

`retry_count` là để xử lý lỗi transient phù hợp; không thay thế việc sửa sai credential/RBAC/URL.

### Thay đổi model definition

```sql
ALTER EXTERNAL MODEL DP800_EmbeddingModel
SET
(
    LOCATION = 'https://<resource>.openai.azure.com/openai/deployments/<new-deployment>/embeddings?api-version=<supported-api-version>',
    API_FORMAT = 'Azure OpenAI',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'text-embedding-3-small',
    CREDENTIAL = [https://<resource>.openai.azure.com],
    PARAMETERS = '{"dimensions":1536}'
);
GO
```

### Xóa model

```sql
DROP EXTERNAL MODEL DP800_EmbeddingModel;
GO
```

> `DROP EXTERNAL MODEL` **không tự xóa credential** đã được model dùng.

---

# 📘 PHẦN 4 — CHỌN DỮ LIỆU ĐỂ EMBED

## 7. Cột nào nên đưa vào embedding?

### Nguyên tắc

Chỉ đưa những trường giúp model hiểu **semantic meaning** của entity.

Ví dụ bảng sản phẩm:

```text
ProductId      -> Không cần (technical identifier)
SKU            -> Thường không cần cho semantic embedding; phù hợp keyword/full-text/B-tree
ProductName    -> Có
CategoryName   -> Có
Description    -> Có
Features       -> Có
Price          -> Thường dùng filter, không cần embed
UpdatedAt      -> Không
```

### Ví dụ tạo text đầu vào

```sql
SELECT
    ProductId,
    CONCAT_WS(N' | ',
        N'Tên: ' + ProductName,
        N'Danh mục: ' + CategoryName,
        N'Mô tả: ' + Description
    ) AS TextForEmbedding
FROM dbo.Products;
```

### Không nên embed dữ liệu nào?

- Primary key/timestamps thuần kỹ thuật.
- Dữ liệu PII/secret nếu không có nhu cầu và approval rõ ràng.
- Dữ liệu thường xuyên thay đổi nhưng không mang semantic value.
- Các giá trị cần **exact match** như invoice number, SKU; chúng thường nên ở keyword/B-tree/full-text/filter layer.

> **Bẫy thi:** Embedding không thay thế mọi index. Metadata có cấu trúc nên để riêng để filter/join; semantic text mới là nội dung chính để embed.

---

# 📘 PHẦN 5 — CHUNKING

## 8. Vì sao phải chunk?

Một tài liệu dài nếu embed nguyên khối có các vấn đề:

1. Có thể vượt input limit của model.
2. Một vector duy nhất “trộn” quá nhiều chủ đề → retrieval kém chính xác.
3. Khi chỉ một đoạn thay đổi, phải re-embed cả tài liệu.
4. RAG phải gửi context quá lớn cho LLM.

### Trade-off chunk size

| Chunk | Ưu điểm | Nhược điểm |
|---|---|---|
| Quá nhỏ | Retrieval rất cụ thể | Mất ngữ cảnh |
| Vừa phải | Cân bằng context + precision | Thường tốt nhất |
| Quá lớn | Giữ nhiều context | Semantic signal loãng, tốn token |

### Overlap

Overlap giúp ý nghĩa không bị “cắt đôi” ở biên chunk, nhưng:

- tăng số chunk,
- tăng chi phí embedding,
- tăng storage,
- có thể sinh kết quả gần-duplicate.

---

## 9. `AI_GENERATE_CHUNKS` — syntax cần biết

`AI_GENERATE_CHUNKS` là **table-valued function**.

```sql
AI_GENERATE_CHUNKS
(
    SOURCE = <text_expression>,
    CHUNK_TYPE = FIXED,
    CHUNK_SIZE = <positive_integer>,
    OVERLAP = <0_to_50>,
    ENABLE_CHUNK_SET_ID = <0_or_1>
)
```

Điểm thi quan trọng:

- Yêu cầu **database compatibility level >= 170**.
- Hiện `CHUNK_TYPE = FIXED` là loại được hỗ trợ trong function này.
- `CHUNK_SIZE` tính theo **characters** trong function hiện hành, không phải “tokens”.
- `OVERLAP` là **phần trăm**, integer từ 0 đến 50; không phải “số token overlap”.
- Output hữu ích gồm `chunk`, `chunk_order`, `chunk_offset`, `chunk_length`; có thể có `chunk_set_id` khi bật.

### Kiểm tra compatibility

```sql
SELECT name, compatibility_level
FROM sys.databases
WHERE database_id = DB_ID();
GO

-- Chạy khi phù hợp với môi trường của bạn
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 170;
GO
```

---

## 10. Lab: chunk một tài liệu bằng native function

```sql
-- ============================================================
-- LAB 8.2 - AI_GENERATE_CHUNKS
-- ============================================================

DECLARE @Text nvarchar(max) = N'
Microsoft SQL hỗ trợ vector, embeddings và AI functions.
DP-800 yêu cầu hiểu cách chia tài liệu thành chunks.
Chunk quá lớn làm retrieval kém chính xác; chunk quá nhỏ có thể mất ngữ cảnh.
Overlap giúp giữ thông tin ở ranh giới giữa các chunk.';

SELECT
    c.chunk,
    c.chunk_order,
    c.chunk_offset,
    c.chunk_length
FROM AI_GENERATE_CHUNKS
(
    SOURCE = @Text,
    CHUNK_TYPE = FIXED,
    CHUNK_SIZE = 120,
    OVERLAP = 20
) AS c
ORDER BY c.chunk_order;
GO
```

### Chunk nhiều dòng bằng `CROSS APPLY`

```sql
CREATE TABLE dbo.Documents
(
    DocumentId  int IDENTITY(1,1) CONSTRAINT PK_Documents PRIMARY KEY,
    Title       nvarchar(200) NOT NULL,
    ContentText nvarchar(max) NOT NULL,
    UpdatedAt   datetime2(3) NOT NULL CONSTRAINT DF_Documents_UpdatedAt DEFAULT sysutcdatetime()
);
GO

INSERT dbo.Documents (Title, ContentText)
VALUES
(N'Bảo hành', N'Sản phẩm điện tử được bảo hành 12 tháng. Khách hàng cần giữ hóa đơn. Trường hợp vào nước không thuộc phạm vi bảo hành.'),
(N'Đổi trả', N'Khách hàng có thể yêu cầu đổi trả trong thời hạn quy định nếu sản phẩm đáp ứng các điều kiện của chính sách.');
GO

SELECT
    d.DocumentId,
    c.chunk_order,
    c.chunk,
    c.chunk_offset,
    c.chunk_length
FROM dbo.Documents AS d
CROSS APPLY AI_GENERATE_CHUNKS
(
    SOURCE = d.ContentText,
    CHUNK_TYPE = FIXED,
    CHUNK_SIZE = 100,
    OVERLAP = 15
) AS c
ORDER BY d.DocumentId, c.chunk_order;
GO
```

---

# 📘 PHẦN 6 — GENERATE EMBEDDINGS

## 11. `AI_GENERATE_EMBEDDINGS`

Cú pháp:

```sql
AI_GENERATE_EMBEDDINGS
(
    source
    USE MODEL model_identifier
    [ PARAMETERS valid_json ]
)
```

Nó dùng external model đã đăng ký trong database để sinh vector embedding.

### Sinh một embedding

```sql
DECLARE @Embedding vector(1536);

SET @Embedding = AI_GENERATE_EMBEDDINGS
(
    N'chính sách bảo hành thiết bị điện tử'
    USE MODEL DP800_EmbeddingModel
);

SELECT @Embedding AS Embedding;
GO
```

### Override parameter khi endpoint hỗ trợ

```sql
DECLARE @Embedding vector(768);

SET @Embedding = AI_GENERATE_EMBEDDINGS
(
    N'Azure SQL semantic search'
    USE MODEL DP800_EmbeddingModel
    PARAMETERS JSON_OBJECT('dimensions': 768)
);
GO
```

> Dimension override phải được model/endpoint hỗ trợ, và biến/cột `VECTOR(n)` phải khớp output dimension.

---

## 12. Lab end-to-end: Documents → chunks → embeddings

```sql
-- ============================================================
-- LAB 8.3 - CHUNK + EMBEDDING END TO END
-- ============================================================

CREATE TABLE dbo.DocumentChunks
(
    ChunkId        bigint IDENTITY(1,1) CONSTRAINT PK_DocumentChunks PRIMARY KEY,
    DocumentId     int NOT NULL,
    ChunkOrder     int NOT NULL,
    ChunkText      nvarchar(max) NOT NULL,
    Embedding      vector(1536) NULL,
    EmbeddingModel sysname NOT NULL CONSTRAINT DF_DocumentChunks_Model DEFAULT N'DP800_EmbeddingModel',
    EmbeddedAt     datetime2(3) NULL,
    CONSTRAINT FK_DocumentChunks_Documents
        FOREIGN KEY (DocumentId) REFERENCES dbo.Documents(DocumentId)
        ON DELETE CASCADE,
    CONSTRAINT UQ_DocumentChunks_DocOrder UNIQUE (DocumentId, ChunkOrder)
);
GO

-- 1) Tạo chunks và embeddings trong một INSERT...SELECT
INSERT dbo.DocumentChunks
(
    DocumentId,
    ChunkOrder,
    ChunkText,
    Embedding,
    EmbeddedAt
)
SELECT
    d.DocumentId,
    c.chunk_order,
    c.chunk,
    AI_GENERATE_EMBEDDINGS
    (
        c.chunk USE MODEL DP800_EmbeddingModel
    ),
    sysutcdatetime()
FROM dbo.Documents AS d
CROSS APPLY AI_GENERATE_CHUNKS
(
    SOURCE = d.ContentText,
    CHUNK_TYPE = FIXED,
    CHUNK_SIZE = 500,
    OVERLAP = 15
) AS c;
GO

SELECT TOP (20)
    ChunkId,
    DocumentId,
    ChunkOrder,
    LEFT(ChunkText, 100) AS ChunkPreview,
    VECTORPROPERTY(Embedding, 'Dimensions') AS VectorDimensions,
    EmbeddedAt
FROM dbo.DocumentChunks
ORDER BY ChunkId;
GO
```

---

# 📘 PHẦN 7 — EMBEDDING MAINTENANCE

## 13. Vì sao phải maintain embeddings?

Nếu source text thay đổi nhưng embedding cũ không đổi, semantic search sẽ trả về **stale meaning**.

Bạn cần quyết định giữa **synchronous** và **asynchronous maintenance**.

### Decision matrix cần thuộc

| Phương pháp | Khi nên dùng | Ưu điểm | Nhược điểm |
|---|---|---|---|
| **DML trigger** | Ít thay đổi, yêu cầu đồng bộ ngay | Đơn giản về consistency | Không nên gọi AI endpoint chậm trong transaction OLTP |
| **Change Tracking** | Chỉ cần biết row nào đổi để re-process | Nhẹ | Không giữ đầy đủ before/after values |
| **CDC** | Cần lịch sử change chi tiết, downstream ETL/event process | Giàu dữ liệu change | Phức tạp/overhead hơn CT |
| **Azure Functions SQL trigger binding** | Serverless/event-driven re-embedding | Tách workload khỏi transaction | Cần Functions runtime |
| **Azure Logic Apps** | Low-code orchestration | Dễ tích hợp workflow | Không phải lựa chọn tối ưu cho ultra-high-throughput |
| **CES** | Near-real-time stream DML changes đến event system | Phù hợp event-driven architecture | Availability/Preview phụ thuộc nền tảng |
| **Microsoft Foundry workflow** | AI orchestration/model lifecycle | Tích hợp hệ sinh thái AI | Cần quản lý service bên ngoài SQL |

### Quy tắc chọn nhanh

- **High-write OLTP** → ưu tiên asynchronous pipeline (CT/CDC/CES + worker/Function).
- **Low-volume, strict immediate consistency** → trigger có thể phù hợp, nhưng tránh network inference dài trong transaction.
- **Low-code business workflow** → Logic Apps.
- **Event streaming near-real-time** → CES.

---

## 14. Mẫu “dirty flag” an toàn hơn gọi AI trong trigger

Trigger chỉ đánh dấu dòng cần re-embed, worker xử lý sau:

```sql
ALTER TABLE dbo.Documents
ADD EmbeddingNeedsRefresh bit NOT NULL
    CONSTRAINT DF_Documents_EmbeddingNeedsRefresh DEFAULT (1);
GO

CREATE OR ALTER TRIGGER dbo.trg_Documents_MarkEmbeddingDirty
ON dbo.Documents
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(ContentText)
    BEGIN
        UPDATE d
        SET EmbeddingNeedsRefresh = 1,
            UpdatedAt = sysutcdatetime()
        FROM dbo.Documents AS d
        INNER JOIN inserted AS i
            ON i.DocumentId = d.DocumentId;
    END;
END;
GO
```

Worker/SQL job/Azure Function có thể đọc các dòng `EmbeddingNeedsRefresh = 1`, rebuild chunks/embeddings rồi reset về 0.

> **Exam trap:** Trigger **có thể** là maintenance method, nhưng gọi remote AI synchronous cho hàng nghìn updates/giờ thường là lựa chọn xấu vì kéo dài transaction và tăng blocking/latency.

---

# 📘 PHẦN 8 — TROUBLESHOOTING & OBSERVABILITY

## 15. Khi embedding generation lỗi, kiểm tra gì?

1. External model tồn tại chưa?
2. Credential đúng chưa?
3. Managed Identity có RBAC phù hợp chưa?
4. Endpoint/API deployment có tồn tại không?
5. External REST capability đã enabled trên platform cần enable chưa?
6. Input có vượt model limit không?
7. Output dimensions có khớp `VECTOR(n)` không?
8. Endpoint có throttling/rate limit không?

`AI_GENERATE_EMBEDDINGS` có Extended Events phục vụ troubleshooting, trong đó có event liên quan embedding generation và external REST request/response.

---

# 🧠 PHẦN 9 — EXAM TRAPS

## 16. Các bẫy rất dễ sai

### Bẫy 1 — “Model càng lớn càng tốt”
Sai. Phải xét quality, latency, cost, dimension, language và workload.

### Bẫy 2 — `VECTOR(3072)`
Native `VECTOR` hiện tối đa 1,998 dimensions. Không tạo cột vượt giới hạn chỉ vì model mặc định có output lớn.

### Bẫy 3 — `AI_GENERATE_CHUNKS` overlap là số token
Sai. Trong syntax hiện hành, overlap là **percentage 0–50**; `CHUNK_SIZE` là characters.

### Bẫy 4 — Semantic/paragraph chunking là tham số hiện có của `AI_GENERATE_CHUNKS`
Sai. Conceptually semantic chunking là chiến lược tốt, nhưng function hiện hành hỗ trợ `CHUNK_TYPE = FIXED`.

### Bẫy 5 — Embed mọi cột
Sai. Embed semantic content; giữ IDs/price/status/date ở metadata/filter layer.

### Bẫy 6 — Update text nhưng không update embedding
Sai. Đây là stale embedding; cần maintenance strategy.

### Bẫy 7 — Gọi AI synchronous trong trigger của high-write OLTP
Thường là đáp án kém nhất vì network call kéo dài transaction.

---

# 📝 PHẦN 10 — MOCK QUESTIONS

## Question 1 — Native vector limit
Một deployment trả embedding mặc định 3,072 dimensions. Bạn muốn lưu trực tiếp vào native vector column của SQL Server 2025. Giải pháp phù hợp nhất là gì?

- A. Tạo `VECTOR(3072)`.
- B. Tạo `NVARCHAR(3072)` và coi như vector native.
- C. Nếu model hỗ trợ, cấu hình output dimensions <= 1,998 rồi tạo `VECTOR(n)` tương ứng.
- D. Dùng `FLOAT(3072)`.

**Đáp án: C.** Native `VECTOR` hiện giới hạn tối đa 1,998 dimensions.

---

## Question 2 — Chunking syntax
Bạn cần chunk text bằng native SQL AI function và muốn 20% overlap. Cách hiểu nào đúng?

- A. `OVERLAP = 20` nghĩa là 20 tokens.
- B. `OVERLAP = 20` nghĩa là 20%.
- C. `CHUNK_SIZE` luôn tính bằng tokens.
- D. `CHUNK_TYPE = SEMANTIC` là bắt buộc.

**Đáp án: B.** `OVERLAP` là phần trăm; current native chunk type là `FIXED`.

---

## Question 3 — High-write embedding maintenance
Catalog có hàng nghìn update/giờ. Embedding phải được cập nhật nhưng không được làm chậm transaction chính. Chọn giải pháp tốt nhất:

- A. `AFTER UPDATE` trigger gọi AI endpoint trực tiếp.
- B. CT/CDC/CES để phát hiện change và Azure Function/worker re-embed bất đồng bộ.
- C. Recreate database sau mỗi batch.
- D. Không cần re-embed.

**Đáp án: B.** Tách inference khỏi OLTP transaction.

---

## Question 4 — External model syntax
Thuộc tính nào mô tả loại model object dùng cho embedding trong `CREATE EXTERNAL MODEL`?

- A. `MODEL_TYPE = EMBEDDINGS`
- B. `PROVIDER = VECTOR`
- C. `SEMANTIC = ON`
- D. `AI_TYPE = RAG`

**Đáp án: A.**

---

## Question 5 — Column selection
Bảng sản phẩm gồm `ProductId`, `SKU`, `Name`, `Description`, `Category`, `Price`, `UpdatedAt`. Semantic search theo mô tả sản phẩm nên ưu tiên embed:

- A. `ProductId + UpdatedAt`
- B. `Name + Description + Category`
- C. `Price`
- D. Tất cả cột không phân biệt

**Đáp án: B.** Các cột đó mang semantic meaning; SKU/price vẫn có thể dùng làm keyword/filter metadata riêng.

---

# ✅ PHẦN 11 — CHECKLIST “TÔI ĐÃ NẮM CHẮC FILE 08 CHƯA?”

Bạn chỉ nên coi phần này là đã vững khi có thể trả lời **không nhìn tài liệu**:

- [ ] Embedding là gì? Khác keyword search ở đâu?
- [ ] `VECTOR(n)` lưu gì và maximum dimensions hiện tại là bao nhiêu?
- [ ] Khi nào dùng `float32`, khi nào có thể cân nhắc `float16`?
- [ ] 6 tiêu chí chính để evaluate external model?
- [ ] Viết được `CREATE EXTERNAL MODEL` với `API_FORMAT`, `MODEL_TYPE`, `MODEL`, `CREDENTIAL`.
- [ ] Viết được `ALTER EXTERNAL MODEL`, `DROP EXTERNAL MODEL` và query `sys.external_models`.
- [ ] Giải thích Managed Identity/passwordless.
- [ ] Biết cột nào nên và không nên embed.
- [ ] Viết được `AI_GENERATE_CHUNKS` + `CROSS APPLY`.
- [ ] Nhớ `CHUNK_TYPE = FIXED`, `CHUNK_SIZE` characters, `OVERLAP` percentage.
- [ ] Viết được `AI_GENERATE_EMBEDDINGS(... USE MODEL ...)`.
- [ ] Thiết kế được Documents → Chunks → Embeddings.
- [ ] Chọn maintenance method giữa trigger / CT / CDC / Function / Logic Apps / CES / Foundry.
- [ ] Nhận ra stale embedding và tránh remote inference trong high-write transaction.

---

# 🔗 PHẦN 12 — TÀI LIỆU THAM KHẢO CHÍNH THỨC

> Các liên kết dưới đây nên được ưu tiên hơn blog/cheat-sheet không chính thức vì syntax AI/Vector thay đổi khá nhanh.

1. [DP-800 Study Guide — Microsoft Learn](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
2. [AI_GENERATE_EMBEDDINGS (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/functions/ai-generate-embeddings-transact-sql?view=sql-server-ver17)
3. [AI_GENERATE_CHUNKS (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/functions/ai-generate-chunks-transact-sql?view=sql-server-ver17)
4. [CREATE EXTERNAL MODEL (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-model-transact-sql?view=sql-server-ver17)
5. [ALTER EXTERNAL MODEL (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-external-model-transact-sql?view=sql-server-ver17)
6. [DROP EXTERNAL MODEL (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/drop-external-model-transact-sql?view=sql-server-ver17)
7. [Vector data type](https://learn.microsoft.com/en-us/sql/t-sql/data-types/vector-data-type?view=sql-server-ver17)
8. [Vector search and vector indexes in the SQL Database Engine](https://learn.microsoft.com/en-us/sql/sql-server/ai/vectors?view=sql-server-ver17)
9. [Microsoft Learn — Implement AI capabilities in database solutions](https://learn.microsoft.com/en-us/training/paths/implement-ai-capabilities-database-solutions/)

---

## Ghi chú cập nhật

Tài liệu này cố tình phân biệt rõ **GA vs Preview** và tránh “đóng đinh” các API-version cloud dễ thay đổi. Khi lab với Azure OpenAI/Microsoft Foundry, hãy lấy endpoint và API version đang được hỗ trợ trực tiếp từ resource hiện tại của bạn.
