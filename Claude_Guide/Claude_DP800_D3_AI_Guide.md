# DP-800 — MIỀN 3: TRIỂN KHAI KHẢ NĂNG AI TRONG GIẢI PHÁP CSDL (25–30%)

> **Cẩm nang ôn thi chuyên sâu** — góc nhìn AI Database Developer.
> **Nền tảng mục tiêu:** SQL Server 2025 / Azure SQL Database / Azure SQL Managed Instance.
> **Bộ lab đi kèm:**
> - [Claude_DP800_D3_Lab01_Vectors_Embeddings.sql](./Claude_DP800_D3_Lab01_Vectors_Embeddings.sql)
> - [Claude_DP800_D3_Lab02_ExternalEndpoints_Models.sql](./Claude_DP800_D3_Lab02_ExternalEndpoints_Models.sql)
> - [Claude_DP800_D3_Lab03_RAG_Pipeline.sql](./Claude_DP800_D3_Lab03_RAG_Pipeline.sql)
> - [Claude_DP800_D3_Quiz.md](./Claude_DP800_D3_Quiz.md) — 45 câu tự kiểm tra kèm giải thích

---

## 0. CÁCH ĐỀ THI HỎI MIỀN NÀY

Miền 3 chiếm 25–30% → khoảng **13–18 câu**. Đây là miền **mới nhất** và cũng là lý do
DP-800 mang tên "**AI Developer**". Đề tập trung vào 4 nhóm:

| Nhóm | Khuôn mẫu câu hỏi |
|---|---|
| **Khái niệm AI/vector** | "Embedding là gì? Khi nào dùng cosine vs euclidean? Chunking thế nào?" |
| **Cú pháp T-SQL mới** | `VECTOR(n)`, `VECTOR_DISTANCE`, `VECTOR_SEARCH`, `AI_GENERATE_EMBEDDINGS`, `CREATE EXTERNAL MODEL` |
| **Tích hợp bên ngoài** | `sp_invoke_external_rest_endpoint`, credential, firewall, xử lý lỗi |
| **Kiến trúc RAG** | Sắp xếp bước, chọn hybrid search, xử lý độ trễ và chi phí |

> **Nguyên tắc vàng:** miền này thưởng cho người hiểu **quy trình end-to-end**, không phải
> người thuộc lòng tham số. Nếu bạn vẽ được sơ đồ "tài liệu → chunk → embedding → lưu
> VECTOR → truy vấn lân cận → ghép prompt → gọi LLM → trả lời", bạn trả lời được đa số câu.

---

## 1. NỀN TẢNG: EMBEDDING & VECTOR

### 1.1. Embedding là gì

**Embedding** = biểu diễn ngữ nghĩa của một đoạn văn bản (hoặc ảnh, âm thanh) dưới dạng
**mảng số thực nhiều chiều**. Hai nội dung **gần nghĩa** thì hai vector **gần nhau trong
không gian**, dù không dùng chung một từ nào.

```
"chính sách hoàn tiền"   → [0.021, -0.144, 0.087, ... ]   (1536 chiều)
"quy định trả hàng"      → [0.019, -0.139, 0.091, ... ]   ← RẤT GẦN
"lịch nghỉ lễ"           → [-0.312, 0.455, -0.201, ... ]  ← RẤT XA
```

Đây chính là điều **full-text search không làm được**: full-text tìm theo **từ khoá**,
vector tìm theo **ý nghĩa**.

| | Full-text search | Vector search |
|---|---|---|
| Tìm theo | Từ khoá, biến thể từ (stemming) | **Ý nghĩa** (semantic) |
| "trả hàng" tìm được "hoàn tiền"? | ❌ | ✅ |
| Tìm mã sản phẩm chính xác "SKU-A17"? | ✅ | ⚠️ kém |
| Chi phí | Thấp | Cao (phải gọi model để sinh embedding) |
| Kết quả | Chính xác từ khoá | Xấp xỉ ngữ nghĩa |

> 🎯 **Đáp án hay bị bỏ sót: HYBRID SEARCH** — kết hợp cả hai rồi hợp nhất thứ hạng
> (Reciprocal Rank Fusion). Đề mô tả "cần tìm cả theo ý nghĩa lẫn theo mã/thuật ngữ
> chính xác" ⇒ **hybrid**, không chọn riêng vector hay full-text.

### 1.2. Kiểu dữ liệu `VECTOR` (SQL Server 2025 / Azure SQL)

```sql
CREATE TABLE dbo.DocChunk
(
    ChunkId   INT IDENTITY PRIMARY KEY,
    DocId     INT           NOT NULL,
    Content   NVARCHAR(MAX) NOT NULL,
    Embedding VECTOR(1536)  NOT NULL      -- n = SỐ CHIỀU, cố định theo model
);
```

**Điểm phải nhớ:**
- `n` = số chiều, **phải khớp chính xác** với model sinh embedding. Sai chiều ⇒ lỗi khi ghi.
- Tối đa **1998 chiều** khi dùng vector index (DiskANN); kiểu `VECTOR` bản thân hỗ trợ tới 1998.
- Lưu trữ **nhị phân nén** (float32), hiệu quả hơn nhiều so với `NVARCHAR(MAX)` chứa JSON.
- Gán giá trị bằng **chuỗi JSON mảng**: `CAST('[0.1,0.2,...]' AS VECTOR(3))`.
- **Không** dùng làm khoá của index B-Tree thông thường; **không** so sánh bằng `=`;
  không `GROUP BY`/`ORDER BY` trực tiếp trên cột vector.
- Trước SQL 2025, cách thay thế là `VARBINARY(8000)` hoặc `NVARCHAR(MAX)` + hàm tự viết —
  đề có thể đưa vào làm đáp án nhiễu "cách cũ".

### 1.3. Số chiều theo model (nhớ vài mốc phổ biến)

| Model | Số chiều |
|---|---|
| `text-embedding-ada-002` | 1536 |
| `text-embedding-3-small` | 1536 (rút gọn được) |
| `text-embedding-3-large` | 3072 (rút gọn được) |
| `all-MiniLM-L6-v2` (local/ONNX) | 384 |

> ⚠️ **Đổi model = phải sinh lại TOÀN BỘ embedding.** Vector của model A không so sánh
> được với vector của model B. Đây là câu hỏi tình huống hay gặp: "sau khi đổi sang model
> mới, kết quả tìm kiếm trở nên vô nghĩa — vì sao?".

---

## 2. ĐO KHOẢNG CÁCH: `VECTOR_DISTANCE`

```sql
DECLARE @q VECTOR(1536) = AI_GENERATE_EMBEDDINGS(N'chính sách hoàn tiền' USE MODEL MyEmbedder);

SELECT TOP (5) ChunkId, Content,
       VECTOR_DISTANCE('cosine', Embedding, @q) AS Distance
FROM   dbo.DocChunk
ORDER  BY Distance;            -- ⚠ DISTANCE: càng NHỎ càng GIỐNG
```

| Metric | Ý nghĩa | Dùng khi |
|---|---|---|
| `'cosine'` | Góc giữa 2 vector, bỏ qua độ dài | **Mặc định cho văn bản** — phổ biến nhất |
| `'euclidean'` | Khoảng cách L2 (đường thẳng) | Khi độ lớn vector có ý nghĩa |
| `'dot'` | Tích vô hướng (negative inner product) | Model đã chuẩn hoá; nhanh nhất |

**Ba điều cực dễ nhầm trong đề:**
1. `VECTOR_DISTANCE` trả **khoảng cách**, không phải độ tương đồng ⇒ `ORDER BY ... ASC` và
   dùng `TOP`, **không** phải `DESC`.
2. `cosine distance = 1 − cosine similarity`. Distance 0 = giống hệt; 1 = trực giao; 2 = ngược hẳn.
3. Metric dùng khi **truy vấn** phải **khớp** metric đã khai báo khi **tạo vector index**.

`VECTOR_DISTANCE` là **exact KNN**: quét toàn bộ bảng, chính xác 100%, nhưng chậm dần
tuyến tính theo số dòng.

---

## 3. VECTOR INDEX & `VECTOR_SEARCH` (ANN)

```sql
CREATE VECTOR INDEX VI_DocChunk ON dbo.DocChunk(Embedding)
WITH (METRIC = 'cosine', TYPE = 'diskann');

SELECT t.ChunkId, t.Content, s.distance
FROM   VECTOR_SEARCH(
           TABLE      = dbo.DocChunk AS t,
           COLUMN     = Embedding,
           SIMILAR_TO = @q,
           METRIC     = 'cosine',
           TOP_N      = 10
       ) AS s
ORDER BY s.distance;
```

| | `VECTOR_DISTANCE` | `VECTOR_SEARCH` + vector index |
|---|---|---|
| Thuật toán | **Exact KNN** (quét toàn bảng) | **ANN** — xấp xỉ (DiskANN) |
| Độ chính xác | 100% | ~95–99% (**recall** đánh đổi lấy tốc độ) |
| Tốc độ | Chậm tuyến tính | Nhanh, gần như không đổi theo kích thước |
| Dùng khi | Bảng nhỏ (< ~50.000 dòng), cần chính xác tuyệt đối | Bảng lớn, chấp nhận sai số nhỏ |

**Điều kiện & lưu ý của vector index (hay ra đề):**
- Bảng phải có **clustered index / primary key**.
- `METRIC` khi tạo index phải **trùng** với metric khi truy vấn, nếu không index bị bỏ qua.
- Index xây dựng **offline** trên ảnh chụp dữ liệu; dữ liệu thêm sau đó ban đầu chưa nằm
  trong index ⇒ cần **rebuild định kỳ** để giữ recall.
- Không hỗ trợ trên bảng memory-optimized, external table.
- Chỉ số chiều ≤ **1998**.

> 🎯 Câu hỏi tủ: "Bảng có 50 triệu chunk, cần trả về top-5 trong vài chục ms."
> ⇒ **vector index + `VECTOR_SEARCH`**, không phải `VECTOR_DISTANCE`.

---

## 4. SINH EMBEDDING NGAY TRONG SQL

### 4.1. `CREATE EXTERNAL MODEL` — cách hiện đại (SQL 2025 / Azure SQL)

```sql
-- (1) Credential trỏ tới endpoint (tên credential = ĐÚNG URL gốc)
CREATE DATABASE SCOPED CREDENTIAL [https://myres.openai.azure.com]
WITH IDENTITY = 'HTTPEndpointHeaders',
     SECRET   = '{"api-key":"<KEY>"}';
-- Khuyến nghị hơn: IDENTITY = 'Managed Identity' (không lưu khoá)

-- (2) Khai báo model
CREATE EXTERNAL MODEL MyEmbedder
WITH (
    LOCATION   = 'https://myres.openai.azure.com/openai/deployments/emb/embeddings?api-version=2024-02-01',
    API_FORMAT = 'Azure OpenAI',
    MODEL_TYPE = EMBEDDINGS,
    MODEL      = 'text-embedding-3-small',
    CREDENTIAL = [https://myres.openai.azure.com]
);

-- (3) Dùng
SELECT AI_GENERATE_EMBEDDINGS(N'nội dung cần nhúng' USE MODEL MyEmbedder);
```

- `MODEL_TYPE`: `EMBEDDINGS` | `CHAT_COMPLETIONS`.
- `API_FORMAT`: `'Azure OpenAI'`, `'OpenAI'`, `'Ollama'` (model chạy cục bộ).
- Catalog view: `sys.external_models`.
- Quyền cần: `CREATE EXTERNAL MODEL` và `EXECUTE ANY EXTERNAL MODEL`.

### 4.2. `AI_GENERATE_CHUNKS` — cắt văn bản ngay trong SQL (SQL 2025)

```sql
SELECT c.chunk_ordinal, c.chunk
FROM   dbo.Document d
CROSS APPLY AI_GENERATE_CHUNKS(
        source = d.Content,
        chunk_type = N'FIXED',
        chunk_size = 400,
        overlap = 50) AS c;
```

Trước đó phải tự cắt bằng T-SQL (`SUBSTRING` + vòng lặp) hoặc ở tầng ứng dụng.

### 4.3. `sp_invoke_external_rest_endpoint` — cách tổng quát nhất

Đây là **thủ tục quan trọng nhất của miền này** vì nó gọi được **bất kỳ REST API nào**,
không riêng embedding.

```sql
DECLARE @response NVARCHAR(MAX), @ret INT;

EXEC @ret = sys.sp_invoke_external_rest_endpoint
     @url        = N'https://myres.openai.azure.com/openai/deployments/emb/embeddings?api-version=2024-02-01',
     @method     = N'POST',                        -- GET | POST | PUT | PATCH | DELETE | HEAD
     @headers    = N'{"api-key":"<KEY>"}',
     @payload    = N'{"input":"nội dung cần nhúng"}',
     @timeout    = 30,                             -- giây, 1..230
     @credential = [https://myres.openai.azure.com],
     @response   = @response OUTPUT;

SELECT JSON_QUERY(@response, '$.result.data[0].embedding') AS EmbeddingJson;
```

**Danh sách phải thuộc:**

| Điểm | Chi tiết |
|---|---|
| Nền tảng | **Azure SQL Database / Managed Instance / SQL Server 2025**. Không có trên SQL Server ≤ 2022. |
| Bật tính năng | Azure SQL DB: `sp_configure 'external rest endpoint enabled', 1` |
| Giao thức | **Chỉ HTTPS** — HTTP bị từ chối |
| Timeout | 1–230 giây (mặc định 30) |
| Trả về | `@response` là JSON có 3 nhánh: `$.response` (status, headers), `$.result` (body), `$.error` |
| Mã trả về | `@ret = 0` là thành công; khác 0 ⇒ đọc `$.error` |
| Quyền | `GRANT EXECUTE ANY EXTERNAL ENDPOINT TO <user>` |
| Xác thực | Header trực tiếp, hoặc **database scoped credential** (an toàn hơn), hoặc **Managed Identity** (tốt nhất — không lưu khoá) |
| Tên credential | **PHẢI trùng URL gốc** của endpoint (ví dụ `https://myres.openai.azure.com`) |
| Firewall | Endpoint phải cho phép truy cập từ dịch vụ Azure SQL |

> ⚠️ **Đây là lời gọi ĐỒNG BỘ** — transaction giữ khoá trong suốt thời gian chờ mạng.
> **Không bao giờ** gọi trong trigger hoặc trong transaction dài. Với khối lượng lớn,
> hãy xử lý theo lô ngoài giờ hoặc đẩy sang tầng ứng dụng / Azure Function.

---

## 5. KIẾN TRÚC RAG (Retrieval-Augmented Generation)

### 5.1. Vì sao cần RAG

LLM chỉ biết dữ liệu tới thời điểm huấn luyện, và **bịa** khi không biết (hallucination).
RAG giải quyết bằng cách **truy xuất dữ liệu thật của bạn** rồi đưa vào prompt làm ngữ cảnh.

### 5.2. Hai pha — nhớ đúng thứ tự

```
PHA 1 — NẠP (offline, làm một lần / định kỳ)
  1. Thu thập tài liệu
  2. CHUNKING       — cắt thành đoạn 200–800 token, chồng lấn 10–20%
  3. EMBEDDING      — sinh vector cho từng chunk
  4. LƯU TRỮ        — bảng có cột VECTOR(n) + metadata (DocId, nguồn, ngày)
  5. VECTOR INDEX   — tạo index để tìm nhanh

PHA 2 — TRUY VẤN (online, mỗi lần người dùng hỏi)
  6. EMBED CÂU HỎI  — cùng model với bước 3 (bắt buộc!)
  7. RETRIEVE       — VECTOR_SEARCH / VECTOR_DISTANCE lấy top-K chunk
  8. (tuỳ chọn) RERANK / HYBRID với full-text
  9. LẮP PROMPT     — system prompt + chunk + câu hỏi
 10. GỌI LLM        — AI_GENERATE_CHAT / sp_invoke_external_rest_endpoint
 11. TRẢ LỜI + TRÍCH DẪN nguồn
```

> 🎯 Câu hỏi sắp xếp bước gần như chắc chắn xuất hiện. Điểm hay bị sai: **chunking trước
> embedding**, và **câu hỏi phải embed bằng đúng model đã embed tài liệu**.

### 5.3. Chunking — chi tiết quyết định chất lượng

| Tham số | Khuyến nghị | Vì sao |
|---|---|---|
| Kích thước | **200–800 token** (~400–1500 ký tự) | Quá nhỏ ⇒ mất ngữ cảnh; quá lớn ⇒ pha loãng ngữ nghĩa, tốn token |
| Chồng lấn (overlap) | **10–20%** | Tránh cắt đứt câu/ý ở ranh giới chunk |
| Ranh giới | Theo câu / đoạn / tiêu đề, không cắt giữa từ | Giữ ngữ nghĩa trọn vẹn |
| Metadata | Luôn lưu DocId, tiêu đề, số trang, ngày | Cần cho trích dẫn và cho lọc trước khi tìm |

**Ba chiến lược chunking:**
- **Fixed-size**: đơn giản nhất, `AI_GENERATE_CHUNKS(chunk_type = 'FIXED')`.
- **Semantic / recursive**: cắt theo cấu trúc (chương → đoạn → câu) — chất lượng cao hơn.
- **Document-based**: mỗi bản ghi/mục là một chunk — hợp với dữ liệu có cấu trúc sẵn.

### 5.4. Các kỹ thuật nâng chất lượng (đề hay hỏi "làm sao cải thiện")

| Vấn đề | Giải pháp |
|---|---|
| Kết quả không liên quan | Tăng **top-K**, thêm **reranking**, cải thiện chunking |
| Bỏ sót khi người dùng gõ mã/thuật ngữ chính xác | **Hybrid search** (vector + full-text) |
| Truy xuất chậm trên bảng lớn | **Vector index + `VECTOR_SEARCH`** |
| Tìm trong phạm vi hẹp (1 phòng ban, 1 khoảng thời gian) | **Pre-filter bằng metadata** rồi mới tìm vector |
| LLM vẫn bịa | Bắt buộc trích dẫn nguồn; prompt "chỉ trả lời dựa trên ngữ cảnh, nếu không có thì nói không biết" |
| Chi phí embedding cao | Cache embedding, chỉ sinh lại chunk đã thay đổi (so checksum) |
| Bảo mật: người dùng chỉ được thấy tài liệu của mình | **RLS trên bảng chunk** (Miền 2!) |

> 💡 Câu hỏi liên miền rất hay ra: "làm sao đảm bảo RAG chỉ trả về tài liệu người dùng
> được phép xem?" ⇒ **Row-Level Security trên bảng chunk**, không phải lọc ở tầng ứng dụng.

### 5.5. Sinh câu trả lời

```sql
-- SQL Server 2025: model kiểu CHAT_COMPLETIONS
SELECT AI_GENERATE_CHAT(
         N'Chỉ trả lời dựa trên ngữ cảnh sau. Nếu không có thông tin, hãy nói không biết.'
         + @context + N'\nCâu hỏi: ' + @question
         USE MODEL MyChatModel);
```

Hoặc dựng JSON payload thủ công rồi `sp_invoke_external_rest_endpoint` — cách này
chạy được trên mọi nền tảng có hỗ trợ thủ tục đó.

---

## 6. CÁC KHẢ NĂNG AI KHÁC CỦA NỀN TẢNG

| Khả năng | Công nghệ | Ghi chú |
|---|---|---|
| Suy luận mô hình ML **trong** SQL | **`PREDICT`** + model ONNX lưu trong `VARBINARY` | Không cần gọi ra ngoài, độ trễ thấp |
| Chạy Python/R trong SQL | **Machine Learning Services** (`sp_execute_external_script`) | SQL Server on-prem; không có trên Azure SQL DB |
| Tìm kiếm từ khoá | **Full-Text Search** (`CONTAINS`, `FREETEXT`) | Kết hợp với vector thành hybrid |
| Phân loại/gắn nhãn dữ liệu nhạy cảm | **Data Discovery & Classification** | Liên quan Miền 2 |
| Trợ lý ngôn ngữ tự nhiên | **Copilot in Azure SQL / SSMS** | NL→SQL, giải thích lỗi |
| Điều phối AI ngoài DB | **Azure AI Foundry, Azure AI Search, Semantic Kernel, LangChain** | Khi cần pipeline phức tạp |

> 🎯 **Phân biệt `PREDICT` và external model**: `PREDICT` chạy model ONNX **cục bộ trong
> engine** (nhanh, không phụ thuộc mạng, hợp cho scoring hàng loạt như dự đoán rời bỏ);
> external model/REST endpoint **gọi ra dịch vụ ngoài** (dùng cho LLM/embedding).

---

## 7. VẬN HÀNH: BẢO MẬT, CHI PHÍ, ĐỘ TRỄ

**Bảo mật**
- Ưu tiên **Managed Identity** > database scoped credential > khoá API trong header.
- Không bao giờ ghi khoá API vào mã nguồn hoặc log.
- Cấp quyền tối thiểu: `EXECUTE ANY EXTERNAL ENDPOINT`, `EXECUTE ANY EXTERNAL MODEL`.
- Endpoint dùng **private endpoint** khi có thể; kiểm soát firewall hai chiều.
- **RLS** trên bảng chunk để phân quyền theo người dùng.
- Cẩn trọng: nội dung gửi lên LLM là **dữ liệu rời khỏi database** — cân nhắc mask/lọc PII trước.

**Chi phí & độ trễ**
- Embedding tính tiền theo **token** ⇒ chunk nhỏ hơn không phải lúc nào cũng rẻ hơn (tổng token gần như không đổi, nhưng số lời gọi tăng).
- Gọi theo **lô (batch)** thay vì từng dòng.
- Cache embedding của câu hỏi lặp lại.
- Chỉ sinh lại embedding cho chunk **đã thay đổi** (so `HASHBYTES` checksum).
- `sp_invoke_external_rest_endpoint` là **đồng bộ** ⇒ đừng đặt trong transaction/trigger.

---

## 8. BẢNG QUYẾT ĐỊNH NHANH (in ra ôn trước giờ thi)

| Đề bài nói... | Đáp án |
|---|---|
| Tìm tài liệu **gần nghĩa**, không cần trùng từ khoá | **Vector search (embedding)** |
| Tìm chính xác mã sản phẩm / thuật ngữ | **Full-text search** |
| Cần cả hai loại trên | **Hybrid search** (+ Reciprocal Rank Fusion) |
| Bảng 50 triệu chunk, cần trả lời trong vài chục ms | **Vector index (DiskANN) + `VECTOR_SEARCH`** |
| Bảng nhỏ, cần chính xác tuyệt đối | **`VECTOR_DISTANCE` + `ORDER BY` (exact KNN)** |
| Metric mặc định cho văn bản | **`'cosine'`** |
| Sắp xếp kết quả tìm kiếm vector | **`ORDER BY distance ASC`** (nhỏ = giống) |
| Sinh embedding ngay trong T-SQL, có khai báo model | **`CREATE EXTERNAL MODEL` + `AI_GENERATE_EMBEDDINGS`** |
| Gọi một REST API bất kỳ từ SQL | **`sp_invoke_external_rest_endpoint`** |
| Cắt tài liệu dài thành đoạn ngay trong SQL | **`AI_GENERATE_CHUNKS`** |
| Chạy model ONNX ngay trong engine, không gọi mạng | **`PREDICT`** |
| Chạy Python/R trong SQL Server | **Machine Learning Services** |
| Xác thực tới Azure OpenAI an toàn nhất | **Managed Identity** |
| Sau khi đổi model embedding, kết quả sai hết | **Phải sinh lại toàn bộ embedding** |
| Người dùng chỉ được tìm trong tài liệu của mình | **RLS trên bảng chunk** |
| LLM bịa câu trả lời | **RAG + bắt buộc trích dẫn + prompt ràng buộc ngữ cảnh** |
| Giảm chi phí embedding khi tài liệu ít thay đổi | **So checksum, chỉ embed chunk đã đổi** |
| Cần lọc theo phòng ban trước rồi mới tìm ngữ nghĩa | **Pre-filter metadata rồi mới vector search** |
| Không được để `sp_invoke_external_rest_endpoint` giữ khoá | **Không gọi trong transaction/trigger; xử lý theo lô** |

---

## 9. LỘ TRÌNH ÔN 4 NGÀY CHO MIỀN 3

| Ngày | Nội dung | Lab |
|---|---|---|
| 1 | Embedding, kiểu `VECTOR`, `VECTOR_DISTANCE`, 3 metric, exact vs ANN | Lab 01 |
| 2 | Vector index, hybrid search, `PREDICT`, so sánh full-text | Lab 01 (phần B) |
| 3 | `sp_invoke_external_rest_endpoint`, credential, external model, xử lý lỗi | Lab 02 |
| 4 | RAG end-to-end: chunking → embed → retrieve → prompt + làm Quiz | Lab 03 + Quiz |

**Cách học hiệu quả nhất:** với mỗi tính năng, tự hỏi **"cái này chạy TRONG engine hay
gọi RA ngoài?"** và **"chính xác hay xấp xỉ?"**. Hai câu hỏi đó phân loại được gần như
toàn bộ nội dung miền 3.
