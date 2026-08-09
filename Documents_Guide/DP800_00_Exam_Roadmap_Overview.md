# DP-800: Developing AI-Enabled Database Solutions — Lộ trình ôn thi & Tổng quan

> **Chứng chỉ:** Microsoft Certified: SQL AI Developer Associate  
> **Kỳ thi:** DP-800 — Developing AI-Enabled Database Solutions  
> **Blueprint đang áp dụng:** Skills measured as of **March 12, 2026**  
> **Tài liệu được rà soát/cập nhật:** **09/08/2026**  
> **Điểm đạt:** 700/1000 (scaled score, không đồng nghĩa với 70% câu đúng)

> [!IMPORTANT]
> Các file trong bộ này được xây dựng theo **DP-800**, không phải DP-700. DP-700 là kỳ thi *Implementing Data Engineering Solutions Using Microsoft Fabric* và có blueprint khác. Vì các file bạn cung cấp, score report và các skill yếu đều thuộc DP-800, bộ tài liệu này lấy DP-800 làm chuẩn duy nhất.

---

## 1. Nguồn chuẩn phải dùng trước tiên

1. [Microsoft Learn — DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
2. [Microsoft Certified: SQL AI Developer Associate](https://learn.microsoft.com/en-us/credentials/certifications/developing-ai-enabled-database-solutions/)
3. [Microsoft Learn — DP-800T00-A course](https://learn.microsoft.com/en-us/training/courses/dp-800t00)
4. [SQL Server documentation](https://learn.microsoft.com/en-us/sql/)
5. [Microsoft Fabric documentation](https://learn.microsoft.com/en-us/fabric/)

Microsoft lưu ý rằng các bullet trong Study Guide chỉ minh họa cách kỹ năng được đánh giá; **các chủ đề liên quan vẫn có thể xuất hiện**. Phần lớn câu hỏi dùng tính năng GA, nhưng Preview feature có thể xuất hiện nếu được sử dụng phổ biến. Vì vậy mục tiêu hợp lý là **phủ kín blueprint + hiểu các liên hệ trực tiếp**, chứ không thể cam kết một file tĩnh sẽ chứa “mọi câu hỏi” có thể xuất hiện.

---

## 2. Cấu trúc bài thi DP-800

| Domain | Trọng số |
|---|---:|
| **1. Design and develop database solutions** | **35–40%** |
| **2. Secure, optimize, and deploy database solutions** | **35–40%** |
| **3. Implement AI capabilities in database solutions** | **25–30%** |

### Domain 1 — Design and develop database solutions

Domain 1 có bốn skill group chính:

1. **Design and implement database objects**
2. **Implement programmability objects**
3. **Write advanced T-SQL code**
4. **Design and implement SQL solutions by using AI-assisted tools**

Bộ file bạn cung cấp ở lượt này bao phủ đúng Domain 1:

- `DP800_Domain1_Database_Design_01_Database_Objects.md`
- `DP800_Domain1_Database_Design_02_Programmability_Advanced_TSQL.md`
- `DP800_Domain1_Database_Design_03_AIAssisted_Tools.md`

---

## 3. Phân tích score report và ưu tiên ôn tập

Bạn đạt **673/1000**, thấp hơn ngưỡng 700. Ba skill Microsoft đánh dấu cần ưu tiên là:

1. **Design and implement SQL solutions by using AI-assisted tools**
2. **Integrate SQL solutions with Azure services**
3. **Design and implement database objects**

Trong ba mục trên, **#1 và #3 nằm ở Domain 1**. Vì vậy Domain 1 phải được học theo hướng “chắc điểm”, không chỉ đọc lý thuyết.

### Thứ tự ưu tiên trong Domain 1

| Mức | Skill | Cách học |
|---|---|---|
| 🔴 P0 | AI-assisted tools | Học đúng sản phẩm hiện hành: GitHub Copilot in SSMS 22, Copilot in Fabric, model picker, Agent/Ask, MCP, SQL MCP Server, Fabric MCP Server, custom instructions |
| 🔴 P0 | Database objects | Viết được T-SQL cho CCI/NCCI, temporal, ledger, memory-optimized, graph, external, JSON index, constraints, sequence, partition |
| 🟠 P1 | Programmability | Viết được view/UDF/TVF/procedure/trigger và biết khi nào chọn object nào |
| 🟠 P1 | Advanced T-SQL | CTE, window, JSON, regex, fuzzy matching, graph MATCH, correlated queries, TRY/CATCH + transaction |

---

## 4. Đánh giá bộ tài liệu trước khi chỉnh sửa

### 4.1 Database Objects — trước đây: **chưa exam-ready**

Các vấn đề lớn đã được sửa trong phiên bản mới:

- Nội dung cũ nói SQL Server **không có JSON index trực tiếp**. Điều này đã lỗi thời: SQL Server 2025 có `CREATE JSON INDEX` (Preview).
- Thiếu lab hoàn chỉnh cho Memory-Optimized, Ledger, Graph, External, Ordered CCI, Native JSON index và Partitioning.
- Mô tả Clustered Index cũ dùng cụm “thứ tự vật lý trên đĩa”, dễ gây hiểu sai.
- Các con số compression/savings tuyệt đối đã được loại bỏ vì phụ thuộc workload.

### 4.2 Programmability & Advanced T-SQL — trước đây: **thiếu nhiều bullet của blueprint**

Đã bổ sung:

- Stored procedures và parameterization.
- DML triggers theo set-based, `inserted`/`deleted`, `AFTER` vs `INSTEAD OF`.
- CTE thường + recursive CTE.
- Window frame, ranking, offset.
- `JSON_OBJECT`, `JSON_ARRAY`, `JSON_ARRAYAGG`, `JSON_CONTAINS`, `OPENJSON`, `JSON_VALUE`.
- Toàn bộ regex function được blueprint nêu tên.
- Fuzzy matching và sự khác nhau giữa **distance** / **similarity**.
- Correlated subquery và `EXISTS`.
- Error handling chuẩn với `XACT_STATE()`.
- Sửa lỗi regex trong file cũ: `^\d{10}$Count` ➜ `^\d{10}$`.

### 4.3 AI-Assisted Tools — trước đây: **lỗi thời và có cấu hình MCP không còn phù hợp**

Đã thay thế các phần sau:

- Dùng **Microsoft SQL MCP Server** hiện hành, được xây trên **Data API builder (DAB)**.
- Bổ sung cấu hình chính thức cho `.vscode/mcp.json` với `dab start --mcp-stdio`.
- Bổ sung **Fabric MCP Server** chính thức.
- Cập nhật Copilot in Fabric: paid Fabric capacity **F2+** hoặc Power BI Premium **P1+**.
- Cập nhật **GitHub Copilot in SSMS 22**.
- Bổ sung model picker, tool approval, least privilege, RBAC.
- Cập nhật repository-wide và path-specific Copilot instructions.

---

## 5. Definition of Done — khi nào Domain 1 thực sự “nắm chắc”?

### Database objects

- [ ] Chọn đúng rowstore vs CCI vs NCCI cho OLTP/analytics/HTAP.
- [ ] Giải thích rowgroup, segment, delta store, tuple mover, segment elimination.
- [ ] Viết `CREATE CLUSTERED COLUMNSTORE INDEX ... ORDER (...)`.
- [ ] Thiết kế memory-optimized table và phân biệt `SCHEMA_AND_DATA` / `SCHEMA_ONLY`.
- [ ] Tạo temporal table và truy vấn `AS OF`, `FROM...TO`, `BETWEEN`, `CONTAINED IN`, `ALL`.
- [ ] Phân biệt temporal vs ledger.
- [ ] Tạo updatable ledger table.
- [ ] Tạo graph node/edge, insert `$from_id`/`$to_id`, query `MATCH`.
- [ ] Giải thích external table là data virtualization.
- [ ] Biết cả computed-column JSON index và `CREATE JSON INDEX`.
- [ ] Tạo PK/FK/UNIQUE/CHECK/DEFAULT; biết trusted vs untrusted FK.
- [ ] Tạo và dùng `SEQUENCE`.
- [ ] Tạo partition function/scheme/table/index; giải thích `RANGE LEFT/RIGHT`.
- [ ] Dùng `$PARTITION` và hiểu `ALTER TABLE ... SWITCH`.

### Programmability & Advanced T-SQL

- [ ] Tạo view, indexed view cơ bản.
- [ ] Tạo scalar UDF, inline TVF, multi-statement TVF; biết trade-off.
- [ ] Tạo stored procedure với input/output parameter.
- [ ] Viết trigger set-based với `inserted`/`deleted`.
- [ ] Viết regular CTE và recursive CTE.
- [ ] Viết ranking/offset/running total.
- [ ] Parse, construct, aggregate và search JSON.
- [ ] Viết được từng regex function trong blueprint.
- [ ] Phân biệt fuzzy distance và similarity.
- [ ] Viết graph `MATCH`.
- [ ] Nhận diện correlated subquery và `EXISTS`.
- [ ] Viết transaction với `TRY/CATCH`, `XACT_STATE`, `THROW`.

### AI-assisted tools

- [ ] Giải thích data leakage, secret exposure, over-permission, hallucinated SQL, unsafe DDL/DML, prompt injection/tool abuse.
- [ ] Biết cách bật GitHub Copilot in SSMS 22.
- [ ] Biết điều kiện để dùng Copilot in Fabric.
- [ ] Biết chọn model và hiểu availability phụ thuộc license/policy.
- [ ] Phân biệt Ask mode và Agent mode.
- [ ] Tạo `.github/copilot-instructions.md`.
- [ ] Biết path-specific instructions `.github/instructions/*.instructions.md`.
- [ ] Giải thích MCP client/server/tool/transport.
- [ ] Kết nối SQL MCP Server qua DAB.
- [ ] Kết nối Fabric MCP Server.
- [ ] Áp dụng least privilege và approval cho MCP tools.

---

## 6. Cách học mỗi chương để giữ kiến thức lâu

Dùng chu trình:

**Concept ➜ Syntax ➜ Lab ➜ Break it ➜ Diagnose ➜ Scenario question ➜ Explain why alternatives are wrong**

Ví dụ với Temporal:

1. Nói được use case.
2. Viết được `CREATE TABLE ... SYSTEM_VERSIONING = ON`.
3. `INSERT`/`UPDATE` để sinh history.
4. Query `FOR SYSTEM_TIME`.
5. Cố tình thiếu PK để xem vì sao fail.
6. So sánh với Ledger.
7. Làm scenario: “point-in-time reconstruction” ➜ Temporal; “tamper-evident audit” ➜ Ledger.

---

## 7. Chiến thuật làm bài với câu hỏi scenario

| Requirement | Hướng suy nghĩ |
|---|---|
| Aggregate hàng trăm triệu dòng | Columnstore |
| OLTP độ trễ thấp, contention cao | In-Memory OLTP nếu workload/platform phù hợp |
| Point-in-time history | Temporal |
| Tamper-evident / cryptographic verification | Ledger |
| Quan hệ nhiều-hop | Graph |
| Query file/object storage như table | External table |
| Search thuộc tính JSON thường xuyên | Computed column index hoặc native JSON index tùy version/platform |
| Tách bảng lớn theo date/key | Partitioning |
| Dùng cùng bộ số tăng trên nhiều table | Sequence |
| AI agent cần thao tác SQL qua tool contract | SQL MCP Server / DAB |
| Copilot cần thao tác Fabric/OneLake | Fabric MCP Server |
| AI chỉ cần gợi ý/read-only | Ask/read-only style |
| AI cần multi-step tool workflow | Agent mode + approval + least privilege |

---

## 8. Lộ trình 18 ngày

| Ngày | Nội dung |
|---|---|
| 1 | Rowstore, indexes, constraints, sequence |
| 2 | Columnstore: CCI/NCCI, ordered columnstore, rowgroup |
| 3 | Temporal + Ledger |
| 4 | Memory-Optimized + Graph + External |
| 5 | JSON + JSON index |
| 6 | Partitioning + tổng ôn Database Objects |
| 7 | Views + UDF/TVF |
| 8 | Stored procedures + triggers |
| 9 | CTE + window functions + correlated queries |
| 10 | JSON functions |
| 11 | Regex + fuzzy matching |
| 12 | Error handling + mixed T-SQL scenarios |
| 13 | GitHub Copilot in SSMS + Copilot in Fabric |
| 14 | Copilot instructions + security |
| 15 | MCP fundamentals + SQL MCP Server |
| 16 | Fabric MCP Server + tool/model options |
| 17 | Domain 1 mock + error log |
| 18 | Chỉ ôn câu sai + làm lại không nhìn đáp án |

---

## 9. Quy tắc dùng Preview features

- Không học Preview feature như một “cam kết tương thích vĩnh viễn”.
- Luôn nhớ **platform/version**.
- Khi scenario nêu SQL Server 2025, đừng tự động chọn workaround cũ nếu native feature đã tồn tại.
- Computed-column JSON indexing vẫn quan trọng và hỗ trợ rộng.
- `CREATE JSON INDEX` là native feature của SQL Server 2025 và hiện là Preview.
- Cả hai đều cần biết.

---

## 10. Link cập nhật quan trọng

- [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
- [SQL AI Developer Associate](https://learn.microsoft.com/en-us/credentials/certifications/developing-ai-enabled-database-solutions/)
- [CREATE JSON INDEX](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-json-index-transact-sql?view=sql-server-ver17)
- [Regular expression functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/regular-expressions-functions-transact-sql?view=sql-server-ver17)
- [EDIT_DISTANCE](https://learn.microsoft.com/en-us/sql/t-sql/functions/edit-distance-transact-sql?view=sql-server-ver17)
- [SQL MCP Server](https://learn.microsoft.com/en-us/sql/mcp/)
- [SQL MCP Server with VS Code](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/quickstart-visual-studio-code)
- [Fabric MCP Server](https://learn.microsoft.com/en-us/rest/api/fabric/articles/mcp-servers/what-is-fabric-mcp-server)
- [GitHub Copilot in SSMS](https://learn.microsoft.com/en-us/ssms/github-copilot/overview)
- [Enable Copilot in Fabric](https://learn.microsoft.com/en-us/fabric/fundamentals/copilot-enable-fabric)
- [GitHub Copilot custom instructions](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions)

---

## 11. Danh sách file trong bộ học

1. `DP800_00_Exam_Roadmap_Overview.md`
2. `DP800_Domain1_Database_Design_01_Database_Objects.md`
3. `DP800_Domain1_Database_Design_02_Programmability_Advanced_TSQL.md`
4. `DP800_Domain1_Database_Design_03_AIAssisted_Tools.md`
5. `DP800_Domain2_Security_Optimization_04_Data_Security_Compliance.md` — không được cung cấp trong lượt này.
6. `DP800_Domain2_Security_Optimization_05_Performance_Optimization.md` — không được cung cấp trong lượt này.
7. `DP800_Domain2_Security_Optimization_06_CICD_SQL_Projects.md` — không được cung cấp trong lượt này.
8. `DP800_Domain2_Security_Optimization_07_Azure_Services_Integration.md` — trọng điểm yếu #2, chưa được rà soát trong lượt này.
9. `DP800_Domain3_AI_Capabilities_08_Models_Embeddings.md` — không được cung cấp trong lượt này.
10. `DP800_Domain3_AI_Capabilities_09_Intelligent_Search.md` — không được cung cấp trong lượt này.
11. `DP800_Domain3_AI_Capabilities_10_RAG_Pipeline.md` — không được cung cấp trong lượt này.

> Vì score report đánh dấu **Integrate SQL solutions with Azure services** là skill yếu #2, bộ tài liệu tổng thể chỉ nên coi là hoàn thiện sau khi file Domain 2 Azure Services Integration cũng được rà soát theo cùng chuẩn.
