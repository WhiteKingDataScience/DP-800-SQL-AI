# DP-800 — MIỀN 3: TRIỂN KHAI KHẢ NĂNG AI TRONG GIẢI PHÁP CSDL (25–30%)

> **Cập nhật:** 14/08/2026  
> **Blueprint:** Skills measured as of March 12, 2026.
>
> Nguồn:
> - [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
> - [CREATE EXTERNAL MODEL](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-model-transact-sql?view=sql-server-ver17)
> - [AI_GENERATE_EMBEDDINGS](https://learn.microsoft.com/en-us/sql/t-sql/functions/ai-generate-embeddings-transact-sql?view=sql-server-ver17)
> - [AI_GENERATE_CHUNKS](https://learn.microsoft.com/en-us/sql/t-sql/functions/ai-generate-chunks-transact-sql?view=sql-server-ver17)
> - [Vector search](https://learn.microsoft.com/en-us/sql/sql-server/ai/vectors?view=sql-server-ver17)
> - [VECTOR_SEARCH](https://learn.microsoft.com/en-us/sql/t-sql/functions/vector-search-transact-sql?view=sql-server-ver17)
> - [sp_invoke_external_rest_endpoint](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-invoke-external-rest-endpoint-transact-sql?view=sql-server-ver17)

---

# 0. SƠ ĐỒ TOÀN MIỀN

```text
Document
   ↓
Chunk
   ↓
Embedding model
   ↓
VECTOR column
   ↓
Full-text / Vector / Hybrid retrieval
   ↓
RRF / Top-K context
   ↓
JSON + prompt
   ↓
LLM
   ↓
Parse/validate response
```

DP-800 thường hỏi bạn **chọn kiến trúc phù hợp**, không chỉ syntax.

---

# 1. EMBEDDING & VECTOR

Embedding biến text/data thành vector số để so sánh semantic similarity.

```text
"đổi trả sản phẩm"
     ↓
[0.012, -0.044, ...]
```

### Điều phải nhớ

- vector dimension phải phù hợp output của model;
- vectors từ model/version khác nhau không nên trộn để so sánh;
- `VECTOR` hiện có giới hạn tối đa 1,998 dimensions;
- đừng tạo `VECTOR(3072)` chỉ vì model mặc định trả 3,072 chiều;
- `VECTOR(1536)` là ví dụ phổ biến với `text-embedding-3-small`.

```sql
CREATE TABLE dbo.DocumentChunks
(
    ChunkId    bigint IDENTITY PRIMARY KEY,
    DocumentId bigint NOT NULL,
    ChunkText  nvarchar(max) NOT NULL,
    Embedding  vector(1536) NULL
);
GO
```

---

# 2. CHỌN MODEL

Các tiêu chí:
- multilingual;
- multimodal requirement;
- dimension;
- quality/recall;
- latency;
- cost;
- input/context limit;
- data residency/security.

Không mặc định model lớn nhất luôn tốt nhất.

---

# 3. `CREATE EXTERNAL MODEL` — SYNTAX HIỆN HÀNH

## Sửa lỗi cũ

Current `CREATE EXTERNAL MODEL` dùng:

```sql
MODEL_TYPE = EMBEDDINGS
```

Không học:

```sql
MODEL_TYPE = CHAT_COMPLETIONS
```

như accepted `CREATE EXTERNAL MODEL` value hiện hành.

Example:

```sql
CREATE DATABASE SCOPED CREDENTIAL
    [https://my-resource.openai.azure.com/]
WITH
(
    IDENTITY = 'Managed Identity',
    SECRET = '{"resourceid":"https://cognitiveservices.azure.com"}'
);
GO

CREATE EXTERNAL MODEL DP800_EmbeddingModel
WITH
(
    LOCATION =
      'https://my-resource.openai.azure.com/openai/deployments/my-embedding/embeddings?api-version=2024-02-01',
    API_FORMAT = 'Azure OpenAI',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'text-embedding-3-small',
    CREDENTIAL =
      [https://my-resource.openai.azure.com/],
    PARAMETERS = '{"dimensions":1536}'
);
GO
```

Model object này dành cho embedding inference.

---

# 4. `AI_GENERATE_EMBEDDINGS`

```sql
DECLARE @q vector(1536);

SET @q =
    AI_GENERATE_EMBEDDINGS
    (
        N'chính sách hoàn tiền'
        USE MODEL DP800_EmbeddingModel
    );

SELECT @q;
GO
```

---

# 5. CHUNKING

Native function hiện hành:

```sql
SELECT *
FROM AI_GENERATE_CHUNKS
(
    SOURCE = N'Văn bản dài cần chia...',
    CHUNK_TYPE = FIXED,
    CHUNK_SIZE = 400,
    OVERLAP = 10
);
```

`OVERLAP` là **phần trăm** của chunk trước được lặp lại (0–50), không phải số ký tự.

Mental model:
- chunk quá lớn → retrieval ít chính xác, tốn token;
- chunk quá nhỏ → mất context;
- overlap giúp giữ context qua boundary nhưng tăng storage/cost.

---

# 6. MAINTAIN EMBEDDINGS

| Requirement | Candidate |
|---|---|
| detect changed rows nhẹ | Change Tracking |
| detailed change history | CDC |
| SQL change → serverless processing | Azure Functions SQL trigger |
| event stream near-real-time | CES |
| low-code orchestration | Logic Apps |
| immediate transaction-side update | DML trigger, coi chừng latency/blocking |
| external AI workflow | Microsoft Foundry/app pipeline |

---

# 7. EXACT VECTOR SEARCH — `VECTOR_DISTANCE`

```sql
DECLARE @q vector(1536) =
    AI_GENERATE_EMBEDDINGS
    (
        N'cách đổi trả hàng'
        USE MODEL DP800_EmbeddingModel
    );

SELECT TOP (10)
    ChunkId,
    ChunkText,
    VECTOR_DISTANCE
    (
        'cosine',
        Embedding,
        @q
    ) AS Distance
FROM dbo.DocumentChunks
WHERE Embedding IS NOT NULL
ORDER BY Distance ASC;
GO
```

Distance càng nhỏ → gần hơn.

Metrics:
- `cosine`;
- `euclidean`;
- `dot`.

---

# 8. ANN: VECTOR INDEX + `VECTOR_SEARCH`

SQL Database Engine dùng **DiskANN** cho vector index.

```sql
CREATE VECTOR INDEX IX_DocumentChunks_Embedding
ON dbo.DocumentChunks(Embedding)
WITH
(
    METRIC = 'cosine',
    TYPE = 'diskann'
);
GO
```

## Latest query syntax (vector index v3)

**Platform/version rất quan trọng:** tại ngày 14/08/2026, Microsoft ghi latest vector index v3 hiện chỉ có trên **Azure SQL Database** và **SQL database in Microsoft Fabric** theo rollout. SQL Server 2025 vẫn có Preview vector index nhưng có thể ở earlier index generation.

```sql
DECLARE @q vector(1536) = '...';

SELECT TOP (10) WITH APPROXIMATE
    t.ChunkId,
    t.ChunkText,
    r.distance
FROM VECTOR_SEARCH
(
    TABLE = dbo.DocumentChunks AS t,
    COLUMN = Embedding,
    SIMILAR_TO = @q,
    METRIC = 'cosine'
) AS r
ORDER BY r.distance;
GO
```

### Earlier vector index compatibility

Earlier vector indexes use:

```sql
TOP_N = 10
```

trong `VECTOR_SEARCH`.

**Không học `TOP_N` như syntax mặc định mới**, nhưng vẫn phải nhận diện vì platform/index generation matters.

---

# 9. ANN vs ENN

| | ENN / exact | ANN |
|---|---|---|
| Kết quả | exact | approximate |
| Cách | `VECTOR_DISTANCE` | vector index + `VECTOR_SEARCH` |
| Scale | candidate set nhỏ hơn | corpus lớn |
| Trade-off | accuracy | latency/recall |

Metric query phải tương thích metric index để ANN index được tận dụng.

---

# 10. FULL-TEXT SEARCH

Full-text ≠ `LIKE`.

```sql
CREATE FULLTEXT CATALOG DP800_FTC AS DEFAULT;
GO

CREATE FULLTEXT INDEX ON dbo.Documents
(
    Title,
    ContentText
)
KEY INDEX PK_Documents
WITH CHANGE_TRACKING AUTO;
GO
```

Ranked query:

```sql
SELECT
    d.DocumentId,
    d.Title,
    ft.[RANK]
FROM CONTAINSTABLE
(
    dbo.Documents,
    (Title, ContentText),
    N'"bảo hành"',
    20
) AS ft
JOIN dbo.Documents AS d
  ON d.DocumentId = ft.[KEY]
ORDER BY ft.[RANK] DESC;
```

---

# 11. HYBRID SEARCH + RRF

Hybrid = lexical/full-text + semantic/vector.

Không cộng trực tiếp raw scores vì thang điểm khác nhau. Một cách phổ biến là **Reciprocal Rank Fusion (RRF)**.

```text
FT rank list
   \
    → RRF → final rank
   /
Vector rank list
```

RRF formula concept:

```text
1 / (k + rank)
```

---

# 12. RAG

```text
Question
   ↓
retrieve relevant data
   ↓
apply security filters
   ↓
build JSON/context
   ↓
augment prompt
   ↓
call LLM
   ↓
parse/validate
```

RAG **giảm** hallucination nhờ grounding, không đảm bảo hết hallucination.

---

# 13. STRUCTURED DATA → JSON

```sql
DECLARE @ContextJson nvarchar(max);

SET @ContextJson =
(
    SELECT TOP (5)
        ChunkId,
        DocumentId,
        ChunkText
    FROM dbo.DocumentChunks
    ORDER BY ChunkId
    FOR JSON PATH
);

SELECT @ContextJson;
```

Các hàm cần biết:
- `FOR JSON PATH`;
- `JSON_OBJECT`;
- `JSON_ARRAY`;
- `JSON_VALUE`;
- `JSON_QUERY`;
- `OPENJSON`.

---

# 14. `sp_invoke_external_rest_endpoint`

Applies to:
- SQL Server 2025;
- Azure SQL Database;
- Azure SQL Managed Instance với policy phù hợp;
- SQL database in Fabric.

Enablement:
- **Azure SQL Database / SQL database in Fabric:** enabled by default;
- **SQL Server 2025 / Azure SQL MI:** disabled by default.

```sql
EXECUTE sp_configure
    'external rest endpoint enabled',
    1;
RECONFIGURE WITH OVERRIDE;
GO
```

Core call:

```sql
DECLARE @response nvarchar(max),
        @rc int;

EXEC @rc =
    sys.sp_invoke_external_rest_endpoint
        @url = N'https://<endpoint>',
        @method = N'POST',
        @payload = @Payload,
        @credential = [https://<credential-prefix>],
        @timeout = 60,
        @retry_count = 2,
        @response = @response OUTPUT;
```

Return:
- `0` = HTTP 2xx;
- non-2xx → HTTP status code;
- cannot perform call → exception.

```sql
GRANT EXECUTE ANY EXTERNAL ENDPOINT
TO [RagExecutor];
```

---

# 15. RESPONSE WRAPPER

Concept:

```json
{
  "response": {
    "status": {
      "http": {
        "code": 200
      }
    }
  },
  "result": {}
}
```

Parse:

```sql
SELECT JSON_VALUE
(
    @response,
    '$.response.status.http.code'
);
```

Với scalar dài, cân nhắc `OPENJSON` thay vì phụ thuộc `JSON_VALUE` 4000-char behavior trên `nvarchar`.

---

# 16. SECURITY RAG

Filter quyền **trước khi gửi context tới model**.

```text
RLS / Tenant filter / ACL
          ↓
retrieve
          ↓
only authorized context
          ↓
LLM
```

Retrieved text là **untrusted data**; không để document override system policy.

---

# 17. ONNX LOCAL — CURRENT PATTERN

Developer Preview trên SQL Server 2025/Windows theo prerequisites hiện hành.

```sql
ALTER DATABASE SCOPED CONFIGURATION
SET PREVIEW_FEATURES = ON;
GO

EXECUTE sys.sp_configure
    'external AI runtimes enabled',
    1;
RECONFIGURE WITH OVERRIDE;
GO

CREATE EXTERNAL MODEL LocalEmbeddingModel
WITH
(
    LOCATION = 'C:\onnx_runtime\model\all-MiniLM-L6-v2-onnx',
    API_FORMAT = 'ONNX Runtime',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'allMiniLM',
    PARAMETERS = '{"valid":"JSON"}',
    LOCAL_RUNTIME_PATH = 'C:\onnx_runtime\'
);
GO
```

Không dùng syntax cũ `WITH (ONNX, LOCATION=...)`.

---

# 18. EXAM TRAPS

1. `MODEL_TYPE = CHAT_COMPLETIONS` trong `CREATE EXTERNAL MODEL` → **không phải current accepted value**.
2. Latest v3 ANN → `SELECT TOP(N) WITH APPROXIMATE`; `TOP_N` là earlier-index path.
3. `VECTOR_DISTANCE` trả distance → thường `ORDER BY ... ASC`.
4. Full-text ≠ `LIKE`.
5. RAG không "eliminate hallucination".
6. SQL database in Fabric ≠ Fabric Warehouse/SQL analytics endpoint.
7. Preview availability/platform phải đọc `Applies to`.
8. Model đổi → cần chiến lược re-embedding đồng bộ.

---

# 19. CHECKLIST

- [ ] Tự giải thích embedding/chunking/vector.
- [ ] Biết `CREATE EXTERNAL MODEL` hiện dùng `MODEL_TYPE=EMBEDDINGS`.
- [ ] Tự viết `AI_GENERATE_EMBEDDINGS`.
- [ ] Phân biệt exact/ANN.
- [ ] Biết DiskANN.
- [ ] Biết latest `WITH APPROXIMATE` và earlier `TOP_N` theo platform/index version.
- [ ] Biết Full-Text + Hybrid + RRF.
- [ ] Tự vẽ RAG pipeline.
- [ ] Biết JSON functions cần cho RAG.
- [ ] Biết `sp_invoke_external_rest_endpoint` enablement theo platform.
- [ ] Biết security filter xảy ra trước LLM.
