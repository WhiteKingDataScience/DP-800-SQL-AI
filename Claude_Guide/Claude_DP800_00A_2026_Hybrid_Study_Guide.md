# DP-800 — HƯỚNG DẪN HỌC KẾT HỢP 2026

> **Mục tiêu của file này:** giúp bạn dùng đúng vai trò của hai bộ `Documents_Guide` và `Claude_Guide`, tránh học trùng, tránh học syntax cũ và chuyển kiến thức thành điểm thi.
>
> **Kết luận ngắn:**
> - `Documents_Guide` = **source of truth / giáo trình chính**.
> - `Claude_Guide` = **workbook thực hành / lab / quiz**.
> - Không nên chọn một bộ và bỏ hẳn bộ còn lại.
>
> **Blueprint chuẩn:** DP-800 — Skills measured as of **March 12, 2026**.
>
> **Nguồn Microsoft quyết định phạm vi:** [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)

---

# 1. VÌ SAO KHÔNG NÊN CHỈ HỌC `Claude_Guide`?

`Claude_Guide` có ưu điểm rất lớn về **cách học**:

```text
Guide → Lab .sql → Quiz → đọc lại lỗi
```

Cấu trúc này rất tốt cho trí nhớ vì bạn phải:

1. hiểu khái niệm;
2. tự chạy lệnh;
3. gặp lỗi;
4. tự chẩn đoán;
5. làm câu hỏi scenario.

Tuy nhiên, bộ Claude được xây theo một phạm vi cũ hơn và ưu tiên lab chạy được trên SQL Server 2019/2022. Vì vậy nó **không phủ đầy đủ blueprint DP-800 hiện hành** và một số ví dụ AI/vector đã thay đổi trong năm 2026.

Các gap quan trọng:

- thiếu nhóm **AI-assisted tools**: GitHub Copilot in SSMS, Copilot in Fabric, MCP, SQL MCP Server, instruction files;
- thiếu nhiều hàm **Advanced T-SQL 2025**: regex, fuzzy matching và các bullet mới;
- thiếu nguyên nhóm **Integrate SQL solutions with Azure services**: DAB, REST/GraphQL, Azure Monitor, CT/CDC/Functions/CES/Logic Apps;
- một số ví dụ vector còn dùng syntax `TOP_N` cũ;
- một số mô tả `sp_invoke_external_rest_endpoint` chưa phân biệt đúng platform enablement hiện hành;
- các tính năng mới như vector index v3/full DML/iterative filtering chưa có trong workflow cũ.

---

# 2. VÌ SAO KHÔNG NÊN CHỈ ĐỌC `Documents_Guide`?

`Documents_Guide` hiện là bộ **đầy đủ và cập nhật hơn**, được map theo 73 bullet của blueprint hiện hành.

Nhược điểm khi học:

- file dài;
- lượng thông tin nhiều;
- dễ rơi vào trạng thái “đọc hiểu nhưng chưa tự viết được”;
- code nằm xen trong lý thuyết nên ít tạo áp lực tự nhớ hơn một lab `.sql` độc lập;
- nếu chỉ đọc liên tục, bạn có thể có cảm giác biết nhưng lại khó trả lời scenario.

Vì vậy cách tốt nhất là:

```text
Documents_Guide = học đúng và đủ
Claude_Guide    = biến kiến thức thành phản xạ
```

---

# 3. MA TRẬN: NÊN DÙNG FILE NÀO CHO VIỆC GÌ?

| Nhu cầu | Ưu tiên |
|---|---|
| Kiểm tra một topic có nằm trong blueprint không | `Documents_Guide/DP800_00_Exam_Roadmap_Overview.md` |
| Học kiến thức lần đầu | `Documents_Guide` |
| Tự chạy T-SQL nhiều bước | `Claude_Guide/*Lab*.sql` |
| Học các feature 2026 mới | `Documents_Guide` + Microsoft Learn |
| Ôn nhanh trước thi | decision tables/checklists trong `Documents_Guide` |
| Kiểm tra trí nhớ | `Claude_Guide/*Quiz.md` + Bridge Quiz |
| Azure Integration | **Documents file 07 là bắt buộc** |
| Copilot/MCP | **Documents file 03 là bắt buộc** |
| Vector/RAG syntax hiện hành | **Documents files 08–10 là nguồn chính** |

---

# 4. DOMAIN 1 — CÁCH HỌC TỐI ƯU

## 4.1 Database Objects

Học chính:

- [`Documents_Guide/DP800_Domain1_Database_Design_01_Database_Objects.md`](../Documents_Guide/DP800_Domain1_Database_Design_01_Database_Objects.md)

Sau đó chạy:

- `Claude_DP800_D1_Lab01_Tables_Constraints.sql`
- `Claude_DP800_D1_Lab02_Indexes_Columnstore.sql`
- `Claude_DP800_D1_Lab03_SpecializedTables_JSON.sql`
- `Claude_DP800_D1_Lab04_Partitioning.sql`

Mục tiêu không phải nhớ mọi option. Bạn phải nhìn requirement và phân biệt được:

```text
Temporal  → lịch sử theo thời gian
Ledger    → tamper-evident / integrity
Graph     → quan hệ nhiều hop
In-memory → OLTP contention/latency
Columnstore → analytics scan/aggregation
Partitioning → quản lý dữ liệu lớn theo boundary
```

## 4.2 Programmability + Advanced T-SQL

Học chính:

- [`Documents_Guide/DP800_Domain1_Database_Design_02_Programmability_Advanced_TSQL.md`](../Documents_Guide/DP800_Domain1_Database_Design_02_Programmability_Advanced_TSQL.md)

Claude Lab 05 rất hữu ích cho:

- view;
- scalar UDF;
- iTVF/mTVF;
- stored procedure;
- trigger.

Nhưng **không được dừng ở đó**. Blueprint hiện còn yêu cầu:

- CTE;
- window functions;
- JSON functions;
- regex functions;
- fuzzy string matching;
- graph `MATCH`;
- correlated queries;
- error handling.

Đặc biệt phải biết nhận diện các tên hàm như:

```text
REGEXP_LIKE
REGEXP_REPLACE
REGEXP_SUBSTR
REGEXP_INSTR
REGEXP_COUNT
REGEXP_MATCHES
REGEXP_SPLIT_TO_TABLE
EDIT_DISTANCE
EDIT_DISTANCE_SIMILARITY
JARO_WINKLER_DISTANCE
```

## 4.3 AI-Assisted Tools — gap lớn của Claude

Học bắt buộc:

- [`Documents_Guide/DP800_Domain1_Database_Design_03_AIAssisted_Tools.md`](../Documents_Guide/DP800_Domain1_Database_Design_03_AIAssisted_Tools.md)

Mental model:

```text
User prompt
   ↓
Copilot client
   ↓
Model + instructions
   ↓
Agent mode (nếu cần tools)
   ↓
MCP server
   ↓
RBAC / database permissions
   ↓
SQL / Fabric
```

Phải phân biệt:

- Ask mode vs Agent mode;
- instruction file vs security boundary;
- SQL MCP vs Fabric MCP;
- model selection vs permission;
- tool enablement vs database permission;
- AI-generated SQL vẫn cần review/test.

Nguồn:

- [GitHub Copilot in SSMS](https://learn.microsoft.com/en-us/ssms/github-copilot/overview)
- [SQL MCP Server](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/overview)

---

# 5. DOMAIN 2 — DOMAIN CẦN ƯU TIÊN NHIỀU NHẤT

## 5.1 Security

Học chính:

- [`Documents_Guide/DP800_Domain2_Security_Optimization_04_Data_Security_Compliance.md`](../Documents_Guide/DP800_Domain2_Security_Optimization_04_Data_Security_Compliance.md)

Sau đó làm Claude labs:

- `Claude_DP800_D2_Lab01_Encryption.sql`
- `Claude_DP800_D2_Lab02_DDM_RLS_Permissions.sql`
- `Claude_DP800_D2_Lab03_Auditing.sql`

Phải phản xạ theo mục tiêu:

```text
At rest                → TDE
DBA không thấy plaintext → Always Encrypted
Che kết quả             → DDM
Lọc row                 → RLS
Ai làm gì               → Audit
Không password          → Entra / Managed Identity
```

## 5.2 Performance

Học chính:

- [`Documents_Guide/DP800_Domain2_Security_Optimization_05_Performance_Optimization.md`](../Documents_Guide/DP800_Domain2_Security_Optimization_05_Performance_Optimization.md)

Sau đó chạy:

- `Claude_DP800_D2_Lab04_Performance.sql`

Phải phân biệt:

```text
RCSI         → statement-level row-versioned READ COMMITTED
SNAPSHOT     → transaction-level snapshot
Blocking     → session chờ lock
Deadlock     → vòng chờ, có victim
Query Store  → history + plan regression
DMV          → trạng thái hiện tại / cache / waits
Execution Plan → optimizer/runtime behavior
```

## 5.3 CI/CD

Học chính:

- [`Documents_Guide/DP800_Domain2_Security_Optimization_06_CICD_SQL_Projects.md`](../Documents_Guide/DP800_Domain2_Security_Optimization_06_CICD_SQL_Projects.md)

Claude Lab 05 D2 dùng để thực hành workflow, nhưng syntax/tooling hiện hành phải ưu tiên Documents.

Nhớ decision boundary:

```text
dotnet build         → validate model + produce dacpac
DeployReport/Script  → xem trước deployment
Publish              → thực thi deployment
DriftReport          → registered DAC drift
Schema Compare       → generic source/live comparison
OIDC                 → passwordless GitHub→Azure
CODEOWNERS            → required ownership/review
```

## 5.4 Azure Integration — gap quan trọng nhất của Claude

Học bắt buộc:

- [`Documents_Guide/DP800_Domain2_Security_Optimization_07_Azure_Services_Integration.md`](../Documents_Guide/DP800_Domain2_Security_Optimization_07_Azure_Services_Integration.md)

Không cố học “Azure nói chung”. Chỉ học 4 hộp:

```text
1. API
   → Data API builder (DAB)

2. Monitoring
   → Azure Monitor
   → Application Insights
   → Log Analytics

3. Data change / event
   → Change Tracking
   → CDC
   → Azure Functions SQL trigger
   → CES
   → Logic Apps

4. Identity/security
   → Entra ID
   → Managed Identity
```

### Bảng phản xạ bắt buộc thuộc

| Requirement | Nghĩ đầu tiên |
|---|---|
| SQL → REST/GraphQL, ít custom backend | **DAB** |
| Expose table/view/stored procedure | **DAB entity** |
| GraphQL related objects | **DAB relationship** |
| REST pagination | **`$first` + `$after`** |
| Application request/dependency/exception telemetry | **Application Insights** |
| Central logs + KQL | **Log Analytics** |
| Chỉ cần biết row nào thay đổi | **Change Tracking** |
| Cần change history / before-after cho ETL | **CDC** |
| Chạy C#/serverless khi SQL row thay đổi | **Azure Functions SQL trigger** |
| Stream change event gần realtime | **CES** |
| Low-code workflow | **Logic Apps** |
| Không lưu password | **Managed Identity / Entra** |

Nguồn:

- [Data API builder](https://learn.microsoft.com/en-us/azure/data-api-builder/)
- [DAB REST](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/rest/overview)
- [Azure SQL trigger for Azure Functions](https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-azure-sql-trigger)

---

# 6. DOMAIN 3 — DÙNG DOCUMENTS LÀM NGUỒN CHÍNH

Học chính:

- [`08 — Models & Embeddings`](../Documents_Guide/DP800_Domain3_AI_Capabilities_08_Models_Embeddings.md)
- [`09 — Intelligent Search`](../Documents_Guide/DP800_Domain3_AI_Capabilities_09_Intelligent_Search.md)
- [`10 — RAG`](../Documents_Guide/DP800_Domain3_AI_Capabilities_10_RAG_Pipeline.md)

Claude D3 labs vẫn rất tốt để hiểu pipeline, nhưng phải đọc các delta 2026 trước.

## 6.1 Vector search syntax hiện hành

Không học `TOP_N` như syntax mặc định mới.

Với latest vector index:

```sql
SELECT TOP (10) WITH APPROXIMATE
    t.Id,
    r.distance
FROM VECTOR_SEARCH
(
    TABLE = dbo.Documents AS t,
    COLUMN = Embedding,
    SIMILAR_TO = @QueryVector,
    METRIC = 'cosine'
) AS r
ORDER BY r.distance;
```

`TOP_N` hiện chỉ để backward compatibility với earlier vector indexes.

Nguồn: [VECTOR_SEARCH](https://learn.microsoft.com/en-us/sql/t-sql/functions/vector-search-transact-sql?view=sql-server-ver17)

## 6.2 Latest DiskANN index

Latest vector index hỗ trợ:

- full DML;
- iterative filtering;
- optimizer-driven ANN/kNN choice;
- transparent quantization improvements.

Không học quy tắc cũ “tạo vector index xong table read-only” như chân lý hiện hành.

Nguồn: [CREATE VECTOR INDEX](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-vector-index-transact-sql?view=sql-server-ver17)

## 6.3 `sp_invoke_external_rest_endpoint`

Platform matters:

- **Azure SQL Database / SQL database in Fabric:** enabled by default.
- **SQL Server 2025 / Azure SQL Managed Instance:** disabled by default, cần enable.

Nguồn: [sp_invoke_external_rest_endpoint](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-invoke-external-rest-endpoint-transact-sql?view=sql-server-ver17)

---

# 7. LỘ TRÌNH 14 BUỔI THEO ĐIỂM YẾU

> Mỗi buổi khoảng 90–150 phút. Nếu chỉ có 45–60 phút, chia một buổi thành hai ngày.

| Buổi | Học | Thực hành |
|---:|---|---|
| 1 | Documents 01: table/index | Claude D1 Lab01 + Lab02 |
| 2 | Documents 01: specialized/JSON/partition | Claude D1 Lab03 + Lab04 |
| 3 | Documents 02: programmability + advanced T-SQL | Claude D1 Lab05 + tự viết regex/JSON/window |
| 4 | **Documents 03: Copilot/MCP** | tự tạo instruction + MCP decision table |
| 5 | Documents 04: security | Claude D2 Lab01 + Lab02 |
| 6 | Documents 05: performance | Claude D2 Lab04 |
| 7 | Documents 06: CI/CD | Claude D2 Lab05 |
| 8 | **Documents 07: DAB REST** | dựng table/view/SP → DAB REST |
| 9 | **Documents 07: GraphQL/cache/security** | relationship + pagination + auth reasoning |
| 10 | **Documents 07: CT vs CDC** | tự chạy CT/CDC + decision matrix |
| 11 | **Documents 07: Functions/CES/Monitor** | scenario-only |
| 12 | Documents 08–09: embeddings/vector | Claude D3 Lab01 + Lab02, nhưng dùng syntax mới |
| 13 | Documents 10: RAG | Claude D3 Lab03 |
| 14 | Bridge Quiz + mixed Practice Assessment | error log + làm lại câu sai |

---

# 8. QUY TẮC HỌC MỖI TOPIC: 5 CÂU PHẢI TRẢ LỜI ĐƯỢC

Chưa được coi là “học xong” nếu chưa trả lời được:

1. Nó giải quyết vấn đề gì?
2. Khi nào chọn?
3. Khi nào **không** chọn?
4. Công nghệ nào dễ nhầm với nó?
5. Tôi có tự viết được code/config tối thiểu không nhìn tài liệu không?

Ví dụ CDC:

```text
What?   → capture detailed changes
When?   → ETL/change history
Not?    → chỉ cần key/version changed → CT
Confuse → CT, Functions trigger, CES
Code?   → enable db/table + query LSN functions
```

---

# 9. ERROR LOG — THỨ GIÚP TĂNG ĐIỂM NHANH NHẤT

Mỗi câu sai ghi đúng mẫu:

```text
Topic:
Requirement trong đề:
Đáp án đúng:
Vì sao đúng:
Tôi đã chọn gì:
Vì sao tôi chọn sai:
Công nghệ tôi nhầm với:
Keyword/decision boundary cần nhớ:
Ngày làm lại:
Kết quả lần làm lại:
```

Không ghi đơn giản “đáp án B”. Mục tiêu là sửa **decision rule**, không sửa một câu hỏi.

---

# 10. NGƯỠNG EXAM-READY

Chỉ nên coi là sẵn sàng khi:

- giải thích được 11 skill group mà không nhìn roadmap;
- Azure Integration scenario đạt khoảng **85–90%**;
- hai lần Practice Assessment liên tiếp khoảng **85%+** mà không nhớ máy móc đáp án;
- tự viết được các lab cốt lõi không nhìn tài liệu;
- với mỗi câu sai, giải thích được vì sao ít nhất hai distractor sai;
- trước ngày thi 7–10 ngày, kiểm tra lại DP-800 Study Guide và các trang `Applies to`/Preview của DAB, Copilot/MCP, vector search và AI functions.

---

# 11. THỨ TỰ NGUỒN KHI CÓ MÂU THUẪN

```text
1. DP-800 Study Guide hiện hành
2. Microsoft Learn/Docs đúng platform + version
3. Documents_Guide
4. Claude_Guide
5. PDF/blog/video/community
```

Nếu Claude lab chạy được trên SQL Server 2019 nhưng Documents/Microsoft nói feature hiện hành khác trên SQL Server 2025/Azure SQL/Fabric, hãy hiểu rằng lab đang dùng **mô phỏng/compatibility path**, không phải syntax mặc định để chọn trong đề thi hiện tại.
