# DP-800 Miền 3 — Thiết kế model, chia đoạn và tạo biểu diễn vector

> **Miền 3:** Triển khai khả năng AI trong giải pháp cơ sở dữ liệu (25–30%)  
> **Chủ đề:** Chọn model, cắt tài liệu thành đoạn và biến nội dung thành vector  
> **Blueprint dùng để cập nhật:** DP-800 Skills measured as of **March 12, 2026**  
> **Cập nhật cách trình bày:** 12/08/2026  
> **Mục tiêu:** Hiểu dữ liệu đi từ văn bản gốc đến vector như thế nào, rồi chọn đúng model và cách cập nhật embedding.

## Chương này nằm ở đâu trong một hệ thống AI?

Giả sử doanh nghiệp có 10.000 tài liệu hướng dẫn. Người dùng hỏi “làm sao trả lại sản phẩm bị lỗi?”, nhưng tài liệu lại dùng cụm từ “quy trình hoàn hàng”. Tìm kiếm theo từ khóa có thể bỏ sót vì hai câu không dùng cùng từ.

Để tìm theo **ý nghĩa**, hệ thống thực hiện ba việc:

```text
Tài liệu dài
   ↓ cắt thành các đoạn nhỏ có đủ ngữ cảnh
Chunk
   ↓ gửi qua embedding model
Vector — một dãy số biểu diễn ý nghĩa
   ↓ lưu cùng nội dung và metadata trong SQL
Sẵn sàng cho Vector Search
```

Chương này tập trung vào phần chuẩn bị đó. File 09 sẽ dùng các vector để tìm kiếm; File 10 sẽ dùng kết quả tìm kiếm để xây RAG.

> **Điểm mấu chốt:** embedding không phải bản tóm tắt, không phải mã hóa và không phải câu trả lời của AI. Nó chỉ là biểu diễn số để máy so sánh mức độ gần nghĩa.

---

## 0. Bạn phải nắm được gì trước khi đi thi?

Theo DP-800 Study Guide hiện hành, phần **Design and implement models and embeddings** yêu cầu bạn có thể:

1. Đánh giá external model theo khả năng đa phương thức, đa ngôn ngữ, kích thước và structured output.
2. Tạo và quản lý external model.
3. Chọn **embedding maintenance method** phù hợp: table trigger, Change Tracking, Azure Functions SQL trigger binding, Azure Logic Apps, CDC, Change Event Streaming (CES), Microsoft Foundry.
4. Chọn đúng cột và nội dung để đưa vào embedding.
5. Thiết kế cách chia tài liệu thành các đoạn nhỏ — **chunking**.
6. Sinh embedding bằng các khả năng tích hợp trong Microsoft SQL.

> **Tư duy thi:** Microsoft thường không chỉ hỏi “cú pháp là gì?”, mà hỏi “với khối lượng công việc này, giải pháp nào phù hợp nhất và vì sao?”. Vì vậy tài liệu này luôn đi theo thứ tự **khái niệm → quyết định → cú pháp → bài thực hành → bẫy thi**.

### Ma trận nền tảng và trạng thái tính năng (chốt ngày 09/08/2026)

| Khả năng | SQL Server 2025 (17.x) | Azure SQL Database | Azure SQL Managed Instance | SQL database in Fabric |
|---|---|---|---|---|
| `VECTOR` (`float32`) và vector scalar functions | Có | Có | Có theo servicing policy | Có |
| `VECTOR(..., float16)` | **Preview**, cần `PREVIEW_FEATURES` | Kiểm tra `Applies to`/rollout hiện hành | Kiểm tra servicing policy | Kiểm tra docs hiện hành |
| `CREATE EXTERNAL MODEL`, `AI_GENERATE_EMBEDDINGS` | Có | Có | Có với **Always-up-to-date update policy** | Có |
| `AI_GENERATE_CHUNKS` | Có; compatibility level ≥ 170 | Có; compatibility level ≥ 170 | Có theo servicing policy; compatibility level ≥ 170 | Có; compatibility level ≥ 170 |
| Local `ONNX Runtime` | **Developer Preview**, chỉ Windows; cần Machine Learning Services, `PREVIEW_FEATURES` và external AI runtime | Không áp dụng | Không áp dụng | Không áp dụng |

“Có” trong bảng nghĩa là trang Microsoft Learn hiện hành liệt kê ở mục **Applies to** và không gắn nhãn Preview cho toàn bộ câu lệnh; từng tùy chọn con vẫn có thể là Preview. Luôn kiểm tra lại trang [CREATE EXTERNAL MODEL](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-model-transact-sql?view=sql-server-ver17), [AI_GENERATE_EMBEDDINGS](https://learn.microsoft.com/en-us/sql/t-sql/functions/ai-generate-embeddings-transact-sql?view=sql-server-ver17) và [Vector data type](https://learn.microsoft.com/en-us/sql/t-sql/data-types/vector-data-type?view=sql-server-ver17) khi triển khai thật.

---

# PHẦN 1 — NỀN TẢNG VỀ MODEL, EMBEDDING VÀ VECTOR

## 1. Embedding — biểu diễn ý nghĩa bằng vector — là gì?

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

## 2. Kiểu dữ liệu `VECTOR` tích hợp trong Microsoft SQL

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

### Giới hạn số chiều rất quan trọng

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

# PHẦN 2 — ĐÁNH GIÁ MODEL BÊN NGOÀI

## 3. “Model bên ngoài” trong DP-800 nghĩa là gì?

External model là AI model chạy ngoài database engine nhưng được SQL đăng ký thành object để T-SQL có thể gọi một cách có quản lý.

Trong phạm vi `CREATE EXTERNAL MODEL` hiện hành, model object được dùng cho **embedding inference** (`MODEL_TYPE = EMBEDDINGS`).

### Các tiêu chí chọn model phù hợp

| Tiêu chí | Câu hỏi cần đặt ra | Tác động |
|---|---|---|
| **Phù hợp nhiệm vụ** | Model dùng để tạo embedding hay sinh nội dung? | Chọn sai model → không giải được bài toán |
| **Multilingual** | Có hiểu tốt tiếng Việt + tiếng Anh không? | Quan trọng cho kho tri thức đa ngôn ngữ |
| **Multimodal** | Có cần text + image/audio không? | Ảnh hưởng model/architecture |
| **Số chiều** | Vector đầu ra có bao nhiêu chiều? | Ảnh hưởng dung lượng, index và tính tương thích |
| **Độ trễ** | SLA tìm kiếm/nạp dữ liệu là bao nhiêu? | Model lớn thường tốn thời gian hơn |
| **Chi phí** | Tần suất tạo hoặc sinh lại embedding? | Ảnh hưởng chi phí suy luận |
| **Giới hạn đầu vào** | Một request nhận tối đa bao nhiêu nội dung? | Ảnh hưởng kích thước chunk |
| **Structured output** | Hệ thống phía sau có cần JSON/schema ổn định không? | Quan trọng với quy trình sinh nội dung |
| **Vị trí và bảo mật dữ liệu** | Dữ liệu có được phép rời region hoặc ranh giới dịch vụ không? | Ảnh hưởng endpoint và identity |

> **Mẫu câu hỏi thường gặp:** “Cần tìm kiếm ngữ nghĩa đa ngôn ngữ, dữ liệu thay đổi thường xuyên và độ trễ thấp” → phải cân bằng **chất lượng + kích thước vector + độ trễ suy luận + chi phí cập nhật**, không phải cứ chọn model lớn nhất.

### Chọn embedding model: ví dụ Microsoft Foundry/Azure OpenAI

Các con số dưới đây là thông số Microsoft công bố cho những model phổ biến, không phải lời khẳng định rằng một model luôn tốt nhất:

| Model | Default dimensions | Max input | Khi nên cân nhắc | Lưu trực tiếp vào SQL `VECTOR` |
|---|---:|---:|---|---|
| `text-embedding-3-small` | 1,536 | 8,192 tokens | Cân bằng chất lượng, latency, chi phí và storage; điểm bắt đầu hợp lý | `VECTOR(1536)` |
| `text-embedding-3-large` | 3,072 | 8,192 tokens | Cần chất lượng/multilingual tốt hơn và đã benchmark | **Không** dùng `VECTOR(3072)`; yêu cầu model trả `dimensions <= 1998` nếu deployment hỗ trợ |
| `text-embedding-ada-002` v2 | 1,536 | 8,192 tokens | Hệ thống cũ/compatibility; đánh giá migration thay vì chọn mặc định cho dự án mới | `VECTOR(1536)` |

`text-embedding-3-*` hỗ trợ rút gọn output qua tham số `dimensions`. Không tự ý đổi dimension/model cho một phần dữ liệu: vectors từ hai model hoặc hai cấu hình dimension **không cùng một vector space** để so sánh đáng tin cậy. Khi migrate model, hãy tạo version mới, re-embed corpus và query bằng cùng version, đo recall/latency rồi mới cut over. Xem [model catalog do Azure bán trực tiếp](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/concepts/models-sold-directly-by-azure) và [Embeddings REST API](https://learn.microsoft.com/en-us/rest/api/aifoundry/azureopenai/embeddings).

### Đa phương thức, đa ngôn ngữ, kích thước model và đầu ra có cấu trúc: hiểu đúng phạm vi

- **Multimodal:** nếu nguồn có ảnh/audio, cần model/processing pipeline chuyển nội dung đó thành representation phù hợp; `CREATE EXTERNAL MODEL ... MODEL_TYPE = EMBEDDINGS` hiện không biến mọi model sinh văn bản thành multimodal SQL function.
- **Multilingual:** benchmark bằng chính tiếng Việt, tiếng Anh và các cặp cross-language của doanh nghiệp; tên “multilingual” không thay thế evaluation dataset.
- **Model size:** model lớn hơn có thể tăng chất lượng nhưng thường tăng latency/cost; phải đo trên ground-truth queries.
- **Structured output:** rất quan trọng khi đánh giá model sinh nội dung cho RAG hoặc tool. Tuy nhiên external model của cú pháp SQL hiện hành chỉ nhận `MODEL_TYPE = EMBEDDINGS`; JSON có cấu trúc của LLM được xử lý trong quy trình REST/RAG ở file 10.

### So sánh endpoint từ xa và ONNX Runtime cục bộ

Tài liệu `CREATE EXTERNAL MODEL` hiện hành hỗ trợ các định dạng API như Azure OpenAI, OpenAI, Ollama và **ONNX Runtime**. ONNX cục bộ là **Developer Preview**, chỉ áp dụng cho SQL Server 2025 trên Windows; cần SQL Server Machine Learning Services, `PREVIEW_FEATURES = ON`, tùy chọn server `external AI runtimes enabled = 1`, các file runtime/model/tokenizer và quyền đọc file phù hợp.

- Model từ xa: dễ dùng model được dịch vụ cloud quản lý, nhưng phải cân nhắc mạng, xác thực và dữ liệu gửi ra ngoài.
- ONNX cục bộ: chạy suy luận gần SQL Server hơn nhưng phải tự quản lý file runtime/model và bảo mật model bên thứ ba.

Trong DP-800, hãy ưu tiên nắm chắc model embedding bên ngoài kết hợp Managed Identity; ONNX là tính năng liên quan hiện hành cần biết để nhận diện tình huống.

```sql
-- Chỉ dành cho lab ONNX Developer Preview trên SQL Server 2025/Windows.
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
GO
EXECUTE sys.sp_configure 'external AI runtimes enabled', 1;
RECONFIGURE WITH OVERRIDE;
GO

-- Sau khi Machine Learning Services, DLL runtime, tokenizer, model files
-- và filesystem permissions đã được cấu hình theo hướng dẫn Microsoft:
CREATE EXTERNAL MODEL DP800_LocalOnnxModel
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

SELECT AI_GENERATE_EMBEDDINGS
(
    N'Kiểm thử embedding local' USE MODEL DP800_LocalOnnxModel
) AS LocalEmbedding;
GO
```

> **Security:** Chỉ nạp ONNX model/runtime từ nguồn đã xác minh. Third-party model/DLL có thể đọc hoặc làm rò dữ liệu; giới hạn quyền, kiểm tra checksum/signature, audit và cô lập host theo chính sách. Xem phần [ONNX Runtime local example và security considerations](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-model-transact-sql?view=sql-server-ver17#example-with-onnx-runtime-running-locally).

---

# PHẦN 3 — TẠO VÀ QUẢN LÝ MODEL BÊN NGOÀI

## 4. Cú pháp hiện hành của `CREATE EXTERNAL MODEL`

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

## 5. Xác thực: ưu tiên Managed Identity khi yêu cầu không dùng mật khẩu

### 5.1. Thông tin xác thực ở phạm vi cơ sở dữ liệu

Ví dụ khung cấu hình Managed Identity:

```sql
CREATE DATABASE SCOPED CREDENTIAL [https://<your-ai-resource-host>]
WITH
    IDENTITY = 'Managed Identity',
    SECRET   = '{"resourceid":"https://cognitiveservices.azure.com"}';
GO
```

Sau đó external model tham chiếu credential này.

Riêng **SQL Server 2025**, Managed Identity ở đây là identity của SQL Server host đã được Azure Arc/VM cấu hình. Phải cho phép server-scoped database credentials trước khi tạo/dùng credential:

```sql
-- SQL Server 2025; cần ALTER SETTINGS ở server level.
EXECUTE sys.sp_configure 'allow server scoped db credentials', 1;
RECONFIGURE WITH OVERRIDE;
GO
```

> **Lưu ý quan trọng:** Role RBAC cụ thể phụ thuộc resource và thao tác. Ví dụ `CREATE EXTERNAL MODEL` với Azure OpenAI trên SQL Server 2025 hiện yêu cầu identity được cấp **Cognitive Services OpenAI Contributor** theo ví dụ chính thức; direct chat/completions thường dùng role inference hẹp hơn như **Cognitive Services OpenAI User** nếu đủ. Luôn dùng **least privilege** và xác nhận trong [Azure OpenAI RBAC](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/role-based-access-control). Trong câu hỏi thi, “không secrets/password/API key” thường trỏ tới **Managed Identity**.

### 5.2. Cấu hình REST endpoint bên ngoài

Trên SQL Server 2025 và một số cấu hình Azure SQL Managed Instance, tính năng gọi external REST cần được bật:

```sql
EXECUTE sys.sp_configure 'external rest endpoint enabled', 1;
RECONFIGURE WITH OVERRIDE;
GO
```

Azure SQL Database và SQL database in Fabric có hành vi khác; khi thực hành, luôn đọc phần **Applies to/Prerequisites** (áp dụng cho/điều kiện cần có) trong tài liệu Microsoft.

---

## 6. Bài thực hành: đăng ký model tạo embedding

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

### Kiểm tra các đối tượng model đã tạo

Truy vấn catalog sau xác nhận model đã được đăng ký và cho biết cấu hình mà SQL đang quản lý.

```sql
SELECT *
FROM sys.external_models;
GO
```

### Quyền để tạo và sử dụng model bên ngoài

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

### Thử lại khi gọi model tạo embedding

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

### Thay đổi định nghĩa model

Theo trang `Applies to` chốt ngày rà soát, `ALTER EXTERNAL MODEL` và `DROP EXTERNAL MODEL` liệt kê SQL Server 2025, Azure SQL Database và SQL database in Fabric; không nên tự suy rộng sang Managed Instance nếu trang version/platform bạn dùng chưa liệt kê.

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

# PHẦN 4 — CHỌN DỮ LIỆU ĐỂ TẠO EMBEDDING

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

Ví dụ ghép những cột có ý nghĩa tìm kiếm thành một chuỗi rõ ràng. Nhãn như “Tiêu đề” và “Nội dung” giúp model hiểu vai trò của từng phần.

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

### Không nên đưa dữ liệu nào vào embedding?

- Primary key/timestamps thuần kỹ thuật.
- Dữ liệu PII/secret nếu không có nhu cầu và approval rõ ràng.
- Dữ liệu thường xuyên thay đổi nhưng không mang semantic value.
- Các giá trị cần **exact match** như invoice number, SKU; chúng thường nên ở keyword/B-tree/full-text/filter layer.

> **Bẫy thi:** Embedding không thay thế mọi index. Metadata có cấu trúc nên để riêng để filter/join; semantic text mới là nội dung chính để embed.

---

# PHẦN 5 — CHIA TÀI LIỆU THÀNH CÁC ĐOẠN NHỎ

## 8. Vì sao phải chia tài liệu thành đoạn nhỏ (chunk)?

Một tài liệu dài nếu embed nguyên khối có các vấn đề:

1. Có thể vượt input limit của model.
2. Một vector duy nhất “trộn” quá nhiều chủ đề → retrieval kém chính xác.
3. Khi chỉ một đoạn thay đổi, phải re-embed cả tài liệu.
4. RAG phải gửi context quá lớn cho LLM.

### Đánh đổi khi chọn kích thước đoạn

| Chunk | Ưu điểm | Nhược điểm |
|---|---|---|
| Quá nhỏ | Retrieval rất cụ thể | Mất ngữ cảnh |
| Vừa phải | Cân bằng context + precision | Thường tốt nhất |
| Quá lớn | Giữ nhiều context | Semantic signal loãng, tốn token |

### Phần nội dung chồng lấn (overlap)

Overlap giúp ý nghĩa không bị “cắt đôi” ở biên chunk, nhưng:

- tăng số chunk,
- tăng chi phí embedding,
- tăng storage,
- có thể sinh kết quả gần-duplicate.

---

## 9. `AI_GENERATE_CHUNKS` — cú pháp cần biết

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

### Kiểm tra mức tương thích

`AI_GENERATE_CHUNKS` cần compatibility level phù hợp. Hãy kiểm tra trước khi cho rằng lỗi đến từ cú pháp.

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

## 10. Bài thực hành: chia tài liệu bằng hàm tích hợp

Ví dụ đưa một văn bản vào `AI_GENERATE_CHUNKS` và nhận nhiều dòng, mỗi dòng chứa thứ tự chunk và nội dung chunk.

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

### Chia nhiều dòng thành các đoạn bằng `CROSS APPLY`

`CROSS APPLY` gọi hàm tạo chunk cho từng tài liệu, nhờ đó một dòng tài liệu có thể mở rộng thành nhiều dòng chunk.

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

# PHẦN 6 — SINH EMBEDDING

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

Lệnh sau gửi một đoạn văn bản qua external model đã đăng ký và nhận lại một vector có số chiều cố định.

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

### Ghi đè tham số khi endpoint hỗ trợ

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

## 12. Bài thực hành hoàn chỉnh: tài liệu → đoạn nhỏ → embedding

Bài này nối toàn bộ chuỗi xử lý: tạo bảng tài liệu, chia nội dung thành chunk, sinh embedding và lưu vector cùng metadata để chuẩn bị cho tìm kiếm.

```sql
-- ============================================================
-- LAB 8.3 - CHUNK + EMBEDDING END TO END
-- ============================================================

CREATE TABLE dbo.DocumentChunks
(
    ChunkId        bigint IDENTITY(1,1) CONSTRAINT PK_DocumentChunks PRIMARY KEY,
    DocumentId     int NOT NULL,
    ChunkOrder     bigint NOT NULL, -- khớp output chunk_order của function
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

# PHẦN 7 — CẬP NHẬT EMBEDDING KHI DỮ LIỆU THAY ĐỔI

## 13. Vì sao phải cập nhật embedding theo dữ liệu nguồn?

Nếu source text thay đổi nhưng embedding cũ không đổi, semantic search sẽ trả về **stale meaning**.

Bạn cần quyết định giữa **synchronous** và **asynchronous maintenance**.

### Bảng chọn cơ chế cập nhật

| Phương pháp | Khi nên dùng | Ưu điểm | Nhược điểm |
|---|---|---|---|
| **DML trigger** | Ít thay đổi, yêu cầu đồng bộ ngay | Đơn giản về consistency | Không nên gọi AI endpoint chậm trong transaction OLTP |
| **Change Tracking** | Chỉ cần biết row nào đổi để re-process | Nhẹ | Không giữ đầy đủ before/after values |
| **CDC** | Cần lịch sử change chi tiết, downstream ETL/event process | Giàu dữ liệu change | Phức tạp/overhead hơn CT |
| **Azure Functions SQL trigger binding** | Serverless/event-driven re-embedding | Tách workload khỏi transaction | Cần Functions runtime |
| **Azure Logic Apps** | Điều phối ít code | Dễ tích hợp quy trình nghiệp vụ | Không tối ưu cho lưu lượng cực cao |
| **CES** | Near-real-time stream DML changes đến Azure Event Hubs | CloudEvents JSON/Avro, phù hợp event-driven architecture | **Preview**; SQL Server 2025 cần `PREVIEW_FEATURES`; Azure SQL DB/MI không cần bật preview config nhưng vẫn là Preview feature |
| **Quy trình Microsoft Foundry** | Điều phối AI và vòng đời model | Tích hợp hệ sinh thái AI | Cần quản lý dịch vụ bên ngoài SQL |

### Quy tắc chọn nhanh

- **High-write OLTP** → ưu tiên asynchronous pipeline (CT/CDC/CES + worker/Function).
- **Low-volume, strict immediate consistency** → trigger có thể phù hợp, nhưng tránh network inference dài trong transaction.
- **Quy trình nghiệp vụ ít code** → Logic Apps.
- **Event streaming near-real-time** → CES.

---

## 14. Mẫu “cờ đánh dấu cần cập nhật” an toàn hơn việc gọi AI trong trigger

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

Trong production nên lưu thêm `ContentHash`, tên/version model, dimensions và `EmbeddedAt`. Worker chỉ reset dirty flag sau khi embedding mới đã ghi thành công; dùng idempotency/retry để một change được xử lý lặp lại vẫn không làm hỏng dữ liệu. Khi đổi model hoặc dimension, tạo version/cột mới và re-embed toàn bộ corpus trước khi chuyển query traffic.

> **Bẫy thường gặp trong đề:** Trigger **có thể** đánh dấu dữ liệu cần cập nhật, nhưng gọi AI từ xa theo kiểu đồng bộ cho hàng nghìn lần cập nhật mỗi giờ thường là lựa chọn xấu vì kéo dài transaction, tăng blocking và độ trễ.

---

# PHẦN 8 — CHẨN ĐOÁN VÀ QUAN SÁT

## 15. Khi quá trình tạo embedding lỗi, cần kiểm tra gì?

1. External model tồn tại chưa?
2. Credential đúng chưa?
3. Managed Identity có RBAC phù hợp chưa?
4. Endpoint/API deployment có tồn tại không?
5. External REST capability đã enabled trên platform cần enable chưa?
6. Input có vượt model limit không?
7. Output dimensions có khớp `VECTOR(n)` không?
8. Endpoint có throttling/rate limit không?

`AI_GENERATE_EMBEDDINGS` có Extended Events phục vụ troubleshooting. Hai event cần nhớ cho remote model là `ai_generate_embeddings_summary` và `external_rest_endpoint_summary`; ONNX local có thêm `ai_generate_embeddings_airuntime_trace`. Không log raw prompt/content/credential nếu chúng chứa PII hoặc secrets.

### Chẩn đoán theo triệu chứng

| Triệu chứng | Nguyên nhân thường gặp | Hướng kiểm tra |
|---|---|---|
| 401/403 | Credential sai, Managed Identity chưa có RBAC, principal thiếu quyền model | Credential URL/identity, Azure role, `EXECUTE ON EXTERNAL MODEL` |
| 404 | Sai resource/deployment/path/API version | Copy endpoint đang được resource hỗ trợ; không học thuộc API version cũ |
| 429 | Quota/rate limit | Batch, backoff/retry, giảm concurrency, kiểm tra quota |
| Output không cast được vào `VECTOR(n)` | Model trả dimension khác cột/biến | Kiểm tra `PARAMETERS dimensions`, model deployment và `VECTORPROPERTY` |
| Input bị từ chối/quá dài | Chunk vượt input limit hoặc content filter | Giảm/điều chỉnh chunk, kiểm tra token limit và policy |
| Search trả “nghĩa cũ” | Source đổi nhưng embedding chưa refresh | Dirty flag/CT/CDC/CES queue, model version, `EmbeddedAt`/content hash |
| ONNX local không load | Thiếu runtime/tokenizer/DLL, filesystem permission hoặc feature flags | Machine Learning Services, `PREVIEW_FEATURES`, `external AI runtimes enabled`, XEvent airuntime trace |

---

# PHẦN 9 — BẪY THƯỜNG GẶP TRONG ĐỀ

## 16. Các bẫy rất dễ sai

### Bẫy 1 — “Model càng lớn càng tốt”
Sai. Phải xét quality, latency, cost, dimension, language và workload.

### Bẫy 2 — `VECTOR(3072)`
Native `VECTOR` hiện tối đa 1,998 dimensions. Không tạo cột vượt giới hạn chỉ vì model mặc định có output lớn.

### Bẫy 3 — phần chồng lấn của `AI_GENERATE_CHUNKS` được tính bằng số token
Sai. Trong syntax hiện hành, overlap là **percentage 0–50**; `CHUNK_SIZE` là characters.

### Bẫy 4 — Semantic/paragraph chunking là tham số hiện có của `AI_GENERATE_CHUNKS`
Sai. Conceptually semantic chunking là chiến lược tốt, nhưng function hiện hành hỗ trợ `CHUNK_TYPE = FIXED`.

### Bẫy 5 — đưa mọi cột vào embedding
Sai. Embed semantic content; giữ IDs/price/status/date ở metadata/filter layer.

### Bẫy 6 — cập nhật văn bản nhưng không cập nhật embedding
Sai. Đây là stale embedding; cần maintenance strategy.

### Bẫy 7 — gọi AI đồng bộ trong trigger của hệ thống OLTP ghi dữ liệu nhiều
Thường là đáp án kém nhất vì network call kéo dài transaction.

### Bẫy 8 — trộn model hoặc phiên bản embedding trong cùng không gian tìm kiếm
Sai. Corpus và query phải được embed bằng cùng model/version/dimension; đổi model thường đòi hỏi re-embed và cutover có kiểm soát.

### Bẫy 9 — dùng `CREATE EXTERNAL MODEL` để đăng ký model sinh nội dung có đầu ra cấu trúc
Sai trong cú pháp SQL hiện hành: `MODEL_TYPE` đang nhận `EMBEDDINGS`. Đầu ra có cấu trúc của model sinh nội dung thuộc quy trình REST/RAG, không phải một loại external model tích hợp khác.

---

# PHẦN 10 — CÂU HỎI TỰ KIỂM TRA

## Câu 1 — Giới hạn của vector tích hợp
Một deployment trả embedding mặc định 3,072 dimensions. Bạn muốn lưu trực tiếp vào native vector column của SQL Server 2025. Giải pháp phù hợp nhất là gì?

- A. Tạo `VECTOR(3072)`.
- B. Tạo `NVARCHAR(3072)` và coi như vector native.
- C. Nếu model hỗ trợ, cấu hình output dimensions <= 1,998 rồi tạo `VECTOR(n)` tương ứng.
- D. Dùng `FLOAT(3072)`.

**Đáp án: C.** Native `VECTOR` hiện giới hạn tối đa 1,998 dimensions.

---

## Câu 2 — Cú pháp chia đoạn
Bạn cần chunk text bằng native SQL AI function và muốn 20% overlap. Cách hiểu nào đúng?

- A. `OVERLAP = 20` nghĩa là 20 tokens.
- B. `OVERLAP = 20` nghĩa là 20%.
- C. `CHUNK_SIZE` luôn tính bằng tokens.
- D. `CHUNK_TYPE = SEMANTIC` là bắt buộc.

**Đáp án: B.** `OVERLAP` là phần trăm; current native chunk type là `FIXED`.

---

## Câu 3 — Cập nhật embedding trong hệ thống ghi nhiều
Catalog có hàng nghìn update/giờ. Embedding phải được cập nhật nhưng không được làm chậm transaction chính. Chọn giải pháp tốt nhất:

- A. `AFTER UPDATE` trigger gọi AI endpoint trực tiếp.
- B. CT/CDC/CES để phát hiện change và Azure Function/worker re-embed bất đồng bộ.
- C. Recreate database sau mỗi batch.
- D. Không cần re-embed.

**Đáp án: B.** Tách inference khỏi OLTP transaction.

---

## Câu 4 — Cú pháp model bên ngoài
Thuộc tính nào mô tả loại model object dùng cho embedding trong `CREATE EXTERNAL MODEL`?

- A. `MODEL_TYPE = EMBEDDINGS`
- B. `PROVIDER = VECTOR`
- C. `SEMANTIC = ON`
- D. `AI_TYPE = RAG`

**Đáp án: A.**

---

## Câu 5 — Chọn cột dữ liệu
Bảng sản phẩm gồm `ProductId`, `SKU`, `Name`, `Description`, `Category`, `Price`, `UpdatedAt`. Semantic search theo mô tả sản phẩm nên ưu tiên embed:

- A. `ProductId + UpdatedAt`
- B. `Name + Description + Category`
- C. `Price`
- D. Tất cả cột không phân biệt

**Đáp án: B.** Các cột đó mang semantic meaning; SKU/price vẫn có thể dùng làm keyword/filter metadata riêng.

---

# PHẦN 11 — DANH SÁCH TỰ KIỂM TRA

Bạn chỉ nên coi phần này là đã vững khi có thể trả lời **không nhìn tài liệu**:

- [ ] Embedding là gì? Khác keyword search ở đâu?
- [ ] `VECTOR(n)` lưu gì và maximum dimensions hiện tại là bao nhiêu?
- [ ] Khi nào dùng `float32`, khi nào có thể cân nhắc `float16`?
- [ ] 6 tiêu chí chính để evaluate external model?
- [ ] Chọn được `text-embedding-3-small`/`3-large` theo quality, dimensions, latency, cost và biết không tạo `VECTOR(3072)`.
- [ ] Viết được `CREATE EXTERNAL MODEL` với `API_FORMAT`, `MODEL_TYPE`, `MODEL`, `CREDENTIAL`.
- [ ] Viết được `ALTER EXTERNAL MODEL`, `DROP EXTERNAL MODEL` và query `sys.external_models`.
- [ ] Giải thích Managed Identity/passwordless.
- [ ] Nhớ SQL Server 2025 cần Arc/host identity và `allow server scoped db credentials` khi dùng Managed Identity.
- [ ] Biết cột nào nên và không nên embed.
- [ ] Viết được `AI_GENERATE_CHUNKS` + `CROSS APPLY`.
- [ ] Nhớ `CHUNK_TYPE = FIXED`, `CHUNK_SIZE` characters, `OVERLAP` percentage.
- [ ] Viết được `AI_GENERATE_EMBEDDINGS(... USE MODEL ...)`.
- [ ] Thiết kế được Documents → Chunks → Embeddings.
- [ ] Chọn maintenance method giữa trigger / CT / CDC / Function / Logic Apps / CES / Foundry.
- [ ] Nhớ CES hiện là Preview và biết version/hash/timestamp để phát hiện stale embedding.
- [ ] Nhận ra stale embedding và tránh remote inference trong high-write transaction.

---

# PHẦN 12 — TÀI LIỆU THAM KHẢO CHÍNH THỨC

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
10. [Microsoft Foundry models sold directly by Azure — embedding model dimensions/input limits](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/concepts/models-sold-directly-by-azure)
11. [Azure OpenAI embeddings REST API](https://learn.microsoft.com/en-us/rest/api/aifoundry/azureopenai/embeddings)
12. [Change Event Streaming overview](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/overview?view=sql-server-ver17)
13. [Azure OpenAI role-based access control](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/role-based-access-control)
14. [Microsoft Learn module — Design and implement models and embeddings with SQL](https://learn.microsoft.com/en-us/training/modules/design-implement-models-embeddings-with-sql/)

---

## Ghi chú cập nhật

Tài liệu này cố tình phân biệt rõ **GA và Preview** và tránh “đóng đinh” các phiên bản API đám mây dễ thay đổi. Khi thực hành với Azure OpenAI/Microsoft Foundry, hãy lấy endpoint và phiên bản API đang được hỗ trợ trực tiếp từ tài nguyên hiện tại của bạn.
