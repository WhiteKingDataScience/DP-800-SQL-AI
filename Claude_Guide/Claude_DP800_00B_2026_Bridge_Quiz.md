# DP-800 — BRIDGE QUIZ 2026

> Bộ câu hỏi này **không thay thế** các quiz D1/D2/D3 của Claude. Nó lấp các khoảng trống giữa `Claude_Guide` cũ và blueprint DP-800 hiện hành.
>
> **Cách làm:** trả lời trước khi mở đáp án. Với mỗi câu sai, ghi lại *decision boundary* vào error log.
>
> **Nguồn chuẩn:** [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)

---

# PHẦN A — AI-ASSISTED TOOLS / MCP

## Câu 1
Bạn đang dùng GitHub Copilot in SSMS. Bạn muốn Copilot gọi một MCP server để thực hiện workflow nhiều bước. Nên dùng mode nào?

A. Ask mode  
B. Agent mode  
C. Query Designer mode  
D. SQLCMD mode

**Đáp án: B.** MCP tools trong SSMS gắn với Agent mode. Ask mode phù hợp hỏi/sinh/giải thích SQL nhưng không phải surface để agent tự gọi MCP tools.

---

## Câu 2
Repo có `.github/copilot-instructions.md` ghi “never delete production data”. MCP server vẫn expose delete tool và database login có `DELETE`. Cơ chế nào thực sự ngăn xóa?

A. Instruction file  
B. Prompt wording  
C. Giới hạn MCP tool/entity + database permission  
D. Chọn model mạnh hơn

**Đáp án: C.** Instruction ảnh hưởng behavior; permission/RBAC/tool surface mới là enforcement boundary.

---

## Câu 3
Một agent cần CRUD deterministic trên các SQL entities đã approve, không muốn model sinh arbitrary SQL. Chọn gì?

A. SQL MCP Server dựa trên Data API builder  
B. Full-Text Search  
C. Query Store  
D. SQL Audit

**Đáp án: A.**

---

## Câu 4
Chỉ các file `*.sql` trong repo cần rule “qualify every object with schema name”. Nơi phù hợp nhất?

A. README.md  
B. `.github/copilot-instructions.md` duy nhất  
C. `.github/instructions/<name>.instructions.md` với `applyTo`  
D. `.gitignore`

**Đáp án: C.**

---

## Câu 5
Một support agent chỉ cần xem tồn kho. Cấu hình an toàn nhất?

A. `db_owner`, tất cả MCP tools  
B. Read-only entity/tool + database permission tối thiểu  
C. Prompt “please don't update”  
D. Dùng model nhỏ hơn

**Đáp án: B.**

---

# PHẦN B — ADVANCED T-SQL GAP

## Câu 6
Bạn cần kiểm tra chuỗi có khớp regular expression. Hàm nào phù hợp nhất?

A. `REGEXP_LIKE`  
B. `EDIT_DISTANCE`  
C. `JSON_VALUE`  
D. `MATCH`

**Đáp án: A.**

---

## Câu 7
Bạn cần điểm tương đồng fuzzy theo phần trăm 0–100 giữa hai chuỗi. Chọn hàm nào?

A. `EDIT_DISTANCE`  
B. `EDIT_DISTANCE_SIMILARITY`  
C. `REGEXP_COUNT`  
D. `VECTOR_DISTANCE`

**Đáp án: B.**

---

## Câu 8
Bạn cần tách chuỗi thành nhiều row dựa trên regex delimiter. Chọn gì?

A. `REGEXP_SPLIT_TO_TABLE`  
B. `STRING_AGG`  
C. `JSON_ARRAY`  
D. `MATCH`

**Đáp án: A.**

---

# PHẦN C — AZURE INTEGRATION

## Câu 9
Cần expose SQL table/view/stored procedure thành REST và GraphQL mà không viết CRUD backend riêng. Chọn?

A. Azure Functions  
B. Data API builder (DAB)  
C. Change Tracking  
D. Query Store

**Đáp án: B.**

---

## Câu 10
DAB REST pagination hiện hành dùng pattern nào?

A. `$skip` + `$top`  
B. `$first` + `$after` continuation token  
C. `OFFSET` + `FETCH` bắt buộc từ client  
D. `ROW_NUMBER()`

**Đáp án: B.**

---

## Câu 11
Cần truy vấn centralized Azure resource logs bằng KQL. Chọn?

A. Application Insights only  
B. Log Analytics workspace  
C. SQL Audit file  
D. Extended Events only

**Đáp án: B.**

---

## Câu 12
Cần theo dõi request latency, dependency calls đến SQL và exceptions của API/application. Chọn?

A. Application Insights  
B. Change Tracking  
C. CDC  
D. Ledger

**Đáp án: A.**

---

## Câu 13
Ứng dụng đồng bộ chỉ cần biết primary key nào đã thay đổi kể từ checkpoint; không cần old/new image. Chọn?

A. CDC  
B. Change Tracking  
C. CES  
D. Audit

**Đáp án: B.**

---

## Câu 14
ETL cần cả before và after values của update. Chọn?

A. Change Tracking  
B. CDC  
C. RLS  
D. Query Store

**Đáp án: B.**

---

## Câu 15
Muốn chạy serverless C# khi row SQL thay đổi mà không tự viết polling logic. Chọn?

A. Azure Functions SQL trigger  
B. CDC only  
C. Ledger  
D. DAB cache

**Đáp án: A.** SQL trigger binding dùng Change Tracking phía dưới.

---

## Câu 16
Muốn đẩy change events gần real time ra event-streaming destination thay vì downstream polling DB. Chọn?

A. CES  
B. RCSI  
C. DDM  
D. Query Performance Insight

**Đáp án: A.**

---

## Câu 17
Workflow low-code cần khi row thay đổi thì gọi nhiều SaaS/Azure connectors. Chọn?

A. Azure Logic Apps  
B. Query Store  
C. Columnstore  
D. Full-Text Search

**Đáp án: A.**

---

## Câu 18
DAB chạy scale-out nhiều instance và cần distributed cache. Chọn cache level nào?

A. L1 only  
B. L1L2 với distributed Level 2 cache  
C. SQL buffer pool  
D. Query Store cache

**Đáp án: B.**

---

# PHẦN D — CI/CD DELTA

## Câu 19
Cần modern cross-platform SQL project build bằng `dotnet build`. Chọn?

A. SDK-style `Microsoft.Build.Sql` project  
B. BACPAC  
C. SQL Audit  
D. SSIS package

**Đáp án: A.**

---

## Câu 20
Muốn xem deployment DACPAC *sẽ thay đổi gì* mà chưa publish. Chọn?

A. `/Action:Publish`  
B. `/Action:DeployReport` hoặc `/Action:Script`  
C. `/Action:DriftReport` luôn luôn  
D. `/Action:Import`

**Đáp án: B.**

---

## Câu 21
Cần tìm ad-hoc schema changes trên database đã registered as DAC. Chọn?

A. `/Action:DriftReport`  
B. `JSON_VALUE`  
C. `VECTOR_SEARCH`  
D. `sp_query_store_force_plan`

**Đáp án: A.** Với generic project-vs-live comparison, nghĩ Schema Compare/extract+compare.

---

## Câu 22
GitHub Actions phải đăng nhập Azure nhưng policy cấm client secret lâu dài. Chọn?

A. Hardcode password  
B. OIDC/federated identity  
C. Commit `.env`  
D. Anonymous login

**Đáp án: B.**

---

# PHẦN E — VECTOR / AI DELTA 2026

## Câu 23
Latest SQL Database Engine vector index type trong `CREATE VECTOR INDEX` là gì?

A. HNSW  
B. DiskANN  
C. B-tree  
D. Hash

**Đáp án: B.**

---

## Câu 24
Với latest vector index generation, approximate search nên dùng pattern nào?

A. `SELECT TOP(N) WITH APPROXIMATE ... FROM VECTOR_SEARCH(...)`  
B. Chỉ `TOP_N` bên trong function  
C. `LIKE '%vector%'`  
D. `MATCH`

**Đáp án: A.** `TOP_N` thuộc syntax/index generation cũ và chỉ nên hiểu để backward compatibility.

---

## Câu 25
Model mặc định trả 3072-dimensional embedding. SQL `VECTOR` hiện hỗ trợ tối đa 1998 dimensions. Cách xử lý?

A. Tạo `VECTOR(3072)`  
B. Ép xuống `FLOAT`  
C. Yêu cầu model/deployment trả dimensions phù hợp hoặc chọn model/output khác  
D. Lưu hai vector ghép lại rồi search như một

**Đáp án: C.**

---

## Câu 26
Bạn đổi embedding model nhưng giữ nguyên corpus embeddings cũ, rồi query bằng model mới. Vì sao relevance xuống mạnh?

A. Query Store bị tắt  
B. Vectors từ model/version khác không cùng vector space đáng tin cậy  
C. RCSI chưa bật  
D. DAB cache stale

**Đáp án: B.** Re-embed corpus theo model/version mới.

---

## Câu 27
Cần keyword relevance + semantic recall. Chọn?

A. Pure `LIKE`  
B. Pure vector  
C. Hybrid Full-Text + Vector, sau đó fusion/reranking như RRF  
D. Clustered index scan

**Đáp án: C.**

---

## Câu 28
RAG retrieval lấy được row mà user không có quyền xem rồi mới “dặn model đừng tiết lộ”. Có an toàn không?

A. Có, system prompt đủ  
B. Không; phải enforce RLS/ACL/tenant filter **trước retrieval/context building**  
C. Có nếu temperature = 0  
D. Có nếu dùng vector search

**Đáp án: B.**

---

## Câu 29
`sp_invoke_external_rest_endpoint` có phải luôn cần `sp_configure 'external rest endpoint enabled', 1` trên mọi platform không?

A. Có  
B. Không; platform matters. Azure SQL Database/SQL database in Fabric enabled mặc định, SQL Server 2025/MI cần enable theo current docs  
C. Chỉ phụ thuộc model  
D. Chỉ phụ thuộc firewall

**Đáp án: B.**

---

## Câu 30
RAG có loại bỏ hoàn toàn hallucination không?

A. Có  
B. Không; RAG grounding giúp giảm nhưng vẫn cần retrieval quality, instructions, validation/guardrails  
C. Chỉ khi dùng cosine  
D. Chỉ khi dùng SQL Server 2025

**Đáp án: B.**

---

# CÁCH CHẤM

- **27–30 đúng:** bridge knowledge tốt; chuyển sang mixed scenario và Practice Assessment.
- **23–26 đúng:** khá; ôn lại đúng nhóm câu sai trước khi tiếp tục.
- **18–22 đúng:** còn gap đáng kể, đặc biệt nên học lại Documents 03/07/09.
- **<18 đúng:** chưa nên làm full mock; quay lại Hybrid Study Guide và học theo từng decision table.

## Error log tối thiểu cho mỗi câu sai

```text
Câu:
Topic:
Requirement chính:
Đáp án đúng:
Tôi chọn:
Vì sao tôi nhầm:
Công nghệ dễ nhầm:
Decision rule mới:
```
