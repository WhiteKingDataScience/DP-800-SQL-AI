# DP-800 — MỤC LỤC BỘ TÀI LIỆU ÔN THI

> Toàn bộ tài liệu do Claude tạo, đặt tên theo quy tắc:
> **`Claude_DP800_<Miền>_<Loại><Số>_<Chủ đề>`**
>
> | Ký hiệu | Nghĩa |
> |---|---|
> | `00` | File mục lục này |
> | `D1` | **Miền 1** — Thiết kế & phát triển giải pháp CSDL (35–40%) |
> | `D2` | **Miền 2** — Bảo mật, tối ưu hoá & triển khai (35–40%) |
> | `D3` | **Miền 3** — Triển khai khả năng AI (25–30%) |
> | `D4` | **Bổ sung** — Hàm Regex (SQL Server 2025 / Fabric) |
> | `D5` | **Bổ sung** — Tích hợp Azure, AI-Assisted Tools & các chủ đề thiếu |
> | `Guide` | Cẩm nang lý thuyết (đọc trước) |
> | `LabNN` | Bài thực hành SQL chạy được (làm sau khi đọc guide) |
> | `Quiz` | Bộ câu hỏi tự kiểm tra kèm giải thích (làm cuối cùng) |

---

## 📊 PHÂN TÍCH ĐIỂM MẠNH & ĐIỂM YẾU KIẾN THỨC

### 1. Các vùng kiến thức trọng tâm cần củng cố:

| # | Vùng kiến thức cần ưu tiên | Thuộc miền | Tài liệu học bổ sung |
|---|---|---|---|
| 1 | **Design and implement SQL solutions by using AI-assisted tools** | D3 + D5 | [D5 — Phần B: AI-Assisted Tools](./Claude_DP800_D5_Azure_AITools_Guide.md) |
| 2 | **Integrate SQL solutions with Azure services** | D2 + D5 | [D5 — Phần A: Azure Integration](./Claude_DP800_D5_Azure_AITools_Guide.md) |
| 3 | **Design and implement database objects** | D1 | Ôn lại D1 Guide + Lab |

### 2. Chi tiết phân tích điểm yếu & giải pháp:

| Điểm yếu kiến thức | Mô tả chi tiết | Tài liệu học tập |
|---|---|---|
| **Tích hợp Azure Services** | Chưa nắm chắc cơ chế Data API Builder (DAB), Azure Functions SQL Trigger, Change Tracking, Managed Identity và Private Endpoint | [D5 — DAB, Azure Functions, Managed Identity, Fabric](./Claude_DP800_D5_Azure_AITools_Guide.md) |
| **Xử lý chuỗi bằng Regular Expression (Regex)** | Chưa hiểu và chưa sử dụng chính xác các hàm regex trong SQL Server 2025 (`REGEXP_LIKE`, `REGEXP_REPLACE`, `REGEXP_SUBSTR`, `REGEXP_COUNT`, `REGEXP_INSTR`) | [D4 — Cẩm nang Hàm Regex đầy đủ + 20 câu quiz](./Claude_DP800_D4_Regex_Guide.md) |
| **Công cụ hỗ trợ AI (AI-Assisted Tools)** | Cấu hình MCP Server, GitHub Copilot Chat settings, bảo mật prompt schema-only | [D5 — Phần B: MCP Server & Copilot Chat](./Claude_DP800_D5_Azure_AITools_Guide.md) |

> 💡 **Lộ trình học tập đề xuất:** Học tài liệu bổ sung D4 (Regex) và D5 (Azure Integration & AI Tools) TRƯỚC để lấp đầy các lỗ hổng kiến thức cốt lõi, sau đó ôn luyện hệ thống các miền D1, D2, D3.

---

## 📘 MIỀN 1 — THIẾT KẾ & PHÁT TRIỂN GIẢI PHÁP CSDL (35–40%)

*Bảng, chỉ mục, columnstore, bảng chuyên biệt, JSON, ràng buộc, phân vùng, view, function, trigger*

| File | Nội dung |
|---|---|
| [Claude_DP800_D1_Design_Guide.md](./Claude_DP800_D1_Design_Guide.md) | **Cẩm nang lý thuyết** — 12 mục, bảng quyết định nhanh, lộ trình 7 ngày |
| [Claude_DP800_D1_Lab01_Tables_Constraints.sql](./Claude_DP800_D1_Lab01_Tables_Constraints.sql) | Kiểu dữ liệu, computed column, IDENTITY vs SEQUENCE, CHECK & NULL, unique filtered index, FK thiếu index, trusted/untrusted, cascade path, nén, SPARSE |
| [Claude_DP800_D1_Lab02_Indexes_Columnstore.sql](./Claude_DP800_D1_Lab02_Indexes_Columnstore.sql) | Key vs INCLUDE, thứ tự cột khoá, sargable, filtered index, ngưỡng bảo trì, RESUMABLE, CCI vs NCCI, rowgroup & delta store, ordered CCI |
| [Claude_DP800_D1_Lab03_SpecializedTables_JSON.sql](./Claude_DP800_D1_Lab03_SpecializedTables_JSON.sql) | Temporal, Ledger, memory-optimized, Graph, External table, Vector; JSON: `JSON_VALUE`/`JSON_QUERY`/`OPENJSON`/`FOR JSON`, đánh chỉ mục JSON |
| [Claude_DP800_D1_Lab04_Partitioning.sql](./Claude_DP800_D1_Lab04_Partitioning.sql) | Filegroup → function → scheme → table, RANGE LEFT/RIGHT, aligned index, SWITCH IN/OUT, SPLIT/MERGE, partitioned columnstore |
| [Claude_DP800_D1_Lab05_Views_Functions_Triggers.sql](./Claude_DP800_D1_Lab05_Views_Functions_Triggers.sql) | Indexed view, NOEXPAND, iTVF/mTVF/scalar UDF, UDF inlining, trigger set-based, INSTEAD OF, DDL trigger, bẫy TRUNCATE |
| [Claude_DP800_D1_Quiz.md](./Claude_DP800_D1_Quiz.md) | **60 câu** + đáp án giải thích + bản đồ câu hỏi → mục ôn |

---

## 🔐 MIỀN 2 — BẢO MẬT, TỐI ƯU HOÁ & TRIỂN KHAI (35–40%)

*Mã hoá, DDM, RLS, quyền, kiểm toán, tối ưu hiệu suất, CI/CD, kiểm thử, tích hợp Azure*

| File | Nội dung |
|---|---|
| [Claude_DP800_D2_SecurityPerfDeploy_Guide.md](./Claude_DP800_D2_SecurityPerfDeploy_Guide.md) | **Cẩm nang lý thuyết** — 10 mục, bảng quyết định nhanh, lộ trình 7 ngày |
| [Claude_DP800_D2_Lab01_Encryption.sql](./Claude_DP800_D2_Lab01_Encryption.sql) | Cây khoá SMK→DMK→Cert→DEK, 5 bước bật TDE, backup encryption, cell encryption, Always Encrypted (deterministic vs randomized, secure enclaves) |
| [Claude_DP800_D2_Lab02_DDM_RLS_Permissions.sql](./Claude_DP800_D2_Lab02_DDM_RLS_Permissions.sql) | 5 hàm mask + 2 cách vượt DDM, RLS filter vs block predicate, `SESSION_CONTEXT`, DENY > GRANT, ownership chaining, module signing |
| [Claude_DP800_D2_Lab03_Auditing.sql](./Claude_DP800_D2_Lab03_Auditing.sql) | SQL Server Audit 3 phần, `ON_FAILURE`, `fn_get_audit_file`, Change Tracking vs CDC, Extended Events |
| [Claude_DP800_D2_Lab04_Performance.sql](./Claude_DP800_D2_Lab04_Performance.sql) | Query Store, plan forcing, Query Store hints, parameter sniffing (5 cách xử lý), statistics, wait stats, RCSI, tempdb, IQP |
| [Claude_DP800_D2_Lab05_Deployment_CICD.sql](./Claude_DP800_D2_Lab05_Deployment_CICD.sql) | DACPAC vs BACPAC, 6 action SqlPackage, expand→migrate→contract, pipeline YAML, khung unit test, tSQLt, backup/restore, chọn đích Azure |
| [Claude_DP800_D2_Quiz.md](./Claude_DP800_D2_Quiz.md) | **60 câu** + đáp án giải thích + bản đồ câu hỏi → mục ôn |

---

## 🤖 MIỀN 3 — TRIỂN KHAI KHẢ NĂNG AI (25–30%)

*Embeddings, vector, tìm kiếm thông minh, RAG, `sp_invoke_external_rest_endpoint`*

| File | Nội dung |
|---|---|
| [Claude_DP800_D3_AI_Guide.md](./Claude_DP800_D3_AI_Guide.md) | **Cẩm nang lý thuyết** — 9 mục, bảng quyết định nhanh, lộ trình 4 ngày |
| [Claude_DP800_D3_Lab01_Vectors_Embeddings.sql](./Claude_DP800_D3_Lab01_Vectors_Embeddings.sql) | Kiểu `VECTOR`, 3 metric (tự cài đặt lại bằng T-SQL để kiểm chứng), exact KNN vs ANN, vector index, pre/post-filter, hybrid + RRF, `PREDICT` |
| [Claude_DP800_D3_Lab02_ExternalEndpoints_Models.sql](./Claude_DP800_D3_Lab02_ExternalEndpoints_Models.sql) | `sp_invoke_external_rest_endpoint` đầy đủ, cấu trúc JSON trả về, mẫu retry/backoff, `CREATE EXTERNAL MODEL`, `AI_GENERATE_CHUNKS`, hàng đợi embedding, bảo mật |
| [Claude_DP800_D3_Lab03_RAG_Pipeline.sql](./Claude_DP800_D3_Lab03_RAG_Pipeline.sql) | **RAG end-to-end 11 bước chạy được thật**: chunking theo câu → embedding → truy xuất → hybrid → lắp prompt → gọi LLM → trích dẫn → đo Recall@K/MRR |
| [Claude_DP800_D3_Quiz.md](./Claude_DP800_D3_Quiz.md) | **45 câu** + đáp án giải thích + bản đồ câu hỏi → mục ôn |

---

## 🔧 BỔ SUNG D4 — HÀM REGEX (SQL SERVER 2025 / FABRIC)

*REGEXP_LIKE, REGEXP_REPLACE, REGEXP_SUBSTR, REGEXP_INSTR, REGEXP_COUNT, REGEXP_MATCHES, EDIT_DISTANCE*

| File | Nội dung |
|---|---|
| [Claude_DP800_D4_Regex_Guide.md](./Claude_DP800_D4_Regex_Guide.md) | **Cẩm nang Regex** — 6 hàm regex cốt lõi, bảng ký hiệu regex, pattern phổ biến đề thi, kết hợp JSON + regex, fuzzy matching, **20 câu quiz** |

---

## 🔧 BỔ SUNG D5 — TÍCH HỢP AZURE, AI-ASSISTED TOOLS & CHỦ ĐỀ THIẾU

*DAB, Azure Functions SQL Trigger, Managed Identity, MCP Server, SQL Graph, CI/CD, Blocking Chain, Transaction Isolation, Embedding Maintenance, Fabric*

| File | Nội dung |
|---|---|
| [Claude_DP800_D5_Azure_AITools_Guide.md](./Claude_DP800_D5_Azure_AITools_Guide.md) | **Cẩm nang bổ sung** — 10 phần: DAB config, Azure Functions trigger, Managed Identity, Private Endpoint, GitHub Copilot, MCP Server, SQL Graph MATCH, CI/CD pipeline, Blocking chain analysis, Transaction isolation levels, ONNX local model, Fabric GraphQL, **15 câu quiz** |

---

## 🗺️ LỘ TRÌNH ÔN THI LẦN 2 (ƯU TIÊN ĐIỂM YẾU)

| Giai đoạn | Ngày | Việc cần làm |
|---|---|---|
| **⭐ Điểm yếu trước** | 1–2 | **D4 Regex Guide** (đọc + làm 20 câu quiz) |
| **⭐ Điểm yếu trước** | 3–5 | **D5 Azure & AI Tools Guide** (đọc + làm 15 câu quiz) |
| **Miền 1** | 6–9 | Guide D1 → Lab 01…05 → Quiz D1 (ôn lại nhanh) |
| **Miền 2** | 10–13 | Guide D2 → Lab 01…05 → Quiz D2 (ôn lại nhanh) |
| **Miền 3** | 14–16 | Guide D3 → Lab 01…03 → Quiz D3 (ôn lại nhanh) |
| **Tổng ôn** | 17 | Làm lại tất cả quiz (D1–D5), đọc lại các bảng "quyết định nhanh" + cheat sheet |

**Thứ tự trong mỗi miền:** Guide (hiểu) → Lab (làm) → Quiz (kiểm tra) → đọc lại phần sai.

**Mẹo hiệu quả nhất:** trong lab, các đoạn đánh dấu `[LỖI CỐ Ý]` được thiết kế để **báo lỗi**.
Hãy chạy, đọc số hiệu lỗi (`Msg xxxx`), rồi mới đọc giải thích. Đề thi hỏi đúng những
tình huống đó.

---

## ⚙️ MÔI TRƯỜNG & TÍNH TƯƠNG THÍCH

Toàn bộ lab đã được **chạy thực tế và kiểm chứng trên SQL Server 2019 Developer Edition**
(instance `localhost` của máy này). Sau khi sửa, script chỉ còn để lại đúng các **lỗi cố ý**
đã được đánh dấu.

Tính năng cần bản mới hơn được **bọc kiểm tra phiên bản** hoặc để dạng chú thích đọc-hiểu,
nên mọi script vẫn chạy trọn vẹn trên SQL Server 2019:

| Tính năng | Bản tối thiểu | Xử lý trong lab |
|---|---|---|
| `ORDER (...)` cho Clustered Columnstore, `JSON_PATH_EXISTS` | 2022 | Kiểm tra phiên bản, tự bỏ qua |
| Ledger table | 2022 | Bọc `TRY…CATCH` |
| Parameter Sensitive Plan optimization, Query Store hints | 2022 | Kiểm tra phiên bản, in thông báo |
| PolyBase 2022 (external table trên S3/Parquet) | 2022 | Chú thích đọc-hiểu |
| `VECTOR`, `VECTOR_DISTANCE`, `VECTOR_SEARCH`, vector index | 2025 | Khối `[CÚ PHÁP 2025]` + **phần mô phỏng chạy được** |
| `CREATE EXTERNAL MODEL`, `AI_GENERATE_EMBEDDINGS`, `AI_GENERATE_CHUNKS` | 2025 | Khối `[CÚ PHÁP 2025]` + phần mô phỏng |
| `sp_invoke_external_rest_endpoint` | Azure SQL / 2025 | Tự phát hiện, mô phỏng JSON trả về |
| Always Encrypted (tạo CMK/CEK) | mọi bản, cần kho khoá client | Chú thích đọc-hiểu |

**Database do lab tạo (đều trên instance TEST, script tự dọn hoặc tự tạo lại):**

| Database | Do lab nào tạo |
|---|---|
| `DP800_Lab` | D1 Lab 01, 02, 03, 05 |
| `DP800_Part` | D1 Lab 04 |
| `DP800_TDE` | D2 Lab 01 *(tự dọn hoàn toàn ở Section 10)* |
| `DP800_Sec` | D2 Lab 02 |
| `DP800_Audit` | D2 Lab 03 *(tự dọn hoàn toàn ở Section 8)* |
| `DP800_Perf` | D2 Lab 04 |
| `DP800_Deploy` | D2 Lab 05 |
| `DP800_AI` | D3 Lab 01, 02 |
| `DP800_RAG` | D3 Lab 03 |

> ⚠️ **Chỉ chạy trên instance TEST.** D2 Lab 01 bật TDE (ảnh hưởng `tempdb` toàn instance)
> và D2 Lab 03 tạo Server Audit ở cấp server — cả hai đều có phần dọn dẹp đầy đủ.

---

## 📄 CÁC FILE KHÁC TRONG THƯ MỤC

| File | Ghi chú |
|---|---|
| `DP-800 score.pdf` | Báo cáo phân tích đánh giá kỹ năng cá nhân |
| `DP-800 question test.pdf` | Bộ 147 câu hỏi luyện thi (tham khảo) |
| `DP-800ExamRequirements260515.pdf` | Yêu cầu kỳ thi chính thức |
| `DP-800Notes260612.pdf`, `DP-800CodeUsed260610.pdf` | Tài liệu khoá học |
| `Antigravity_*`, `Codex_*` | Tài liệu do công cụ khác tạo |
| `StartOfSection*.sql`, `Reviews.sql`, `PupilData.csv` | Tài nguyên khoá học gốc |
