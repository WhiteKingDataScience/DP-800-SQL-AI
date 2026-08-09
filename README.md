# DP-800 — Phát triển giải pháp cơ sở dữ liệu hỗ trợ AI

> Bộ tài liệu học và thực hành cho chứng chỉ **Microsoft Certified: SQL AI Developer Associate — DP-800: Developing AI-Enabled Database Solutions**.

Nội dung chính được viết bằng tiếng Việt, giữ nguyên các thuật ngữ Microsoft và T-SQL quan trọng bằng tiếng Anh để dễ đối chiếu với đề thi và Microsoft Learn.

> **Trạng thái rà soát:** 09/08/2026
> **Blueprint đối chiếu:** Skills measured as of **March 12, 2026**
> **Phạm vi:** 73 bullet thuộc 11 skill group, trên SQL Server, Azure SQL và SQL database in Microsoft Fabric.

> [!IMPORTANT]
> Bộ tài liệu đã phủ đủ phạm vi blueprint hiện hành, nhưng không tài liệu tĩnh nào có thể bảo đảm bạn trả lời được mọi câu hỏi thi. Hãy kết hợp đọc hiểu, tự viết code, chạy lab, làm Practice Assessment và duy trì error log.

## Bắt đầu nhanh

1. Đọc [Roadmap và ma trận 73 mục](<Documents_Guide/DP800_00_Exam_Roadmap_Overview.md>) để hiểu toàn bộ phạm vi và thứ tự học.
2. Nếu chưa vững SQL, học [00A — Nền tảng T-SQL](<Documents_Guide/DP800_00A_TSQL_Foundations_Prerequisites.md>) trước.
3. Học lần lượt ba domain trong [Documents_Guide](<Documents_Guide>): Domain 1 → Domain 2 → Domain 3.
4. Với mỗi skill group, làm đủ bốn tầng: giải thích khái niệm → chọn giải pháp → viết code/config → chẩn đoán lỗi.
5. Chạy script chỉ trong database lab hoặc môi trường tạm; không dùng credential, endpoint hay dữ liệu production.
6. Trước ngày thi, mở lại [Study Guide DP-800](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800) và các liên kết Microsoft trong từng file để kiểm tra thay đổi.

## Blueprint và trọng số

| Domain | Trọng số | Skill group | Số bullet |
|---|---:|---:|---:|
| 1. Design and develop database solutions | 35–40% | 4 | 24 |
| 2. Secure, optimize, and deploy database solutions | 35–40% | 4 | 28 |
| 3. Implement AI capabilities in database solutions | 25–30% | 3 | 21 |
| **Tổng** | — | **11** | **73** |

Đây là các khoảng phần trăm, không phải số câu cố định. Khi làm câu hỏi scenario, luôn xác định platform, version, trạng thái GA/Preview, yêu cầu security/performance và constraint trước khi chọn đáp án.

## Cấu trúc tài liệu chuẩn

```text
DP-800 Microsoft SQL Server AI Developer/
├── Documents_Guide/                         # Giáo trình chuẩn, đã đối chiếu blueprint
│   ├── DP800_00_Exam_Roadmap_Overview.md
│   ├── DP800_00A_TSQL_Foundations_Prerequisites.md
│   ├── DP800_Domain1_Database_Design_01_Database_Objects.md
│   ├── DP800_Domain1_Database_Design_02_Programmability_Advanced_TSQL.md
│   ├── DP800_Domain1_Database_Design_03_AIAssisted_Tools.md
│   ├── DP800_Domain2_Security_Optimization_04_Data_Security_Compliance.md
│   ├── DP800_Domain2_Security_Optimization_05_Performance_Optimization.md
│   ├── DP800_Domain2_Security_Optimization_06_CICD_SQL_Projects.md
│   ├── DP800_Domain2_Security_Optimization_07_Azure_Services_Integration.md
│   ├── DP800_Domain3_AI_Capabilities_08_Models_Embeddings.md
│   ├── DP800_Domain3_AI_Capabilities_09_Intelligent_Search.md
│   └── DP800_Domain3_AI_Capabilities_10_RAG_Pipeline.md
├── Claude_Guide/                            # Giáo trình/lab bổ trợ; kiểm tra lại version
├── StartOfSection7.sql ... StartOfSection16.sql
├── Reviews.sql                              # Script ôn tập cũ/bổ trợ
├── PupilData.csv                            # Dữ liệu mẫu
├── DP-800ExamRequirements260515.pdf         # Snapshot yêu cầu thi
├── DP-800Notes260612.pdf                    # Ghi chú bổ trợ
├── DP-800CodeUsed260610.pdf                 # Code mẫu bổ trợ
└── README.md
```

`Documents_Guide` là nguồn học chuẩn của repository. `Claude_Guide`, các file `.sql` ở thư mục gốc và các PDF là nguồn thực hành/bổ trợ; nếu syntax hoặc trạng thái tính năng khác Microsoft Learn thì ưu tiên tài liệu Microsoft đúng platform/version.

## Lộ trình học đề xuất

### Giai đoạn 0 — Nền tảng T-SQL

Học table/row/column, khóa và constraint, `SELECT`, `WHERE`, `JOIN`, `GROUP BY`, `HAVING`, `EXISTS`, DML, transaction, `TRY...CATCH`, `XACT_STATE()` và kiểu dữ liệu. Hoàn thành toàn bộ lab trong [00A](<Documents_Guide/DP800_00A_TSQL_Foundations_Prerequisites.md>) trước khi chuyển tiếp nếu bạn là người mới.

### Domain 1 — Design and develop database solutions

- [01 — Database Objects](<Documents_Guide/DP800_Domain1_Database_Design_01_Database_Objects.md>): tables, indexes, columnstore, temporal, graph, JSON, partitioning và specialized tables.
- [02 — Programmability & Advanced T-SQL](<Documents_Guide/DP800_Domain1_Database_Design_02_Programmability_Advanced_TSQL.md>): views, functions, procedures, triggers, CTE, window functions, JSON, regex, fuzzy, graph query và error handling.
- [03 — AI-Assisted Tools](<Documents_Guide/DP800_Domain1_Database_Design_03_AIAssisted_Tools.md>): Copilot, Fabric Copilot, SSMS Agent mode, MCP, SQL MCP Server và security boundary.

### Domain 2 — Secure, optimize, and deploy database solutions

- [04 — Data Security & Compliance](<Documents_Guide/DP800_Domain2_Security_Optimization_04_Data_Security_Compliance.md>): encryption, Always Encrypted, DDM, RLS, permissions, auditing, Managed Identity và endpoint security.
- [05 — Performance Optimization](<Documents_Guide/DP800_Domain2_Security_Optimization_05_Performance_Optimization.md>): configuration, isolation/concurrency, execution plans, DMVs, Query Store, blocking và deadlocks.
- [06 — CI/CD & SQL Database Projects](<Documents_Guide/DP800_Domain2_Security_Optimization_06_CICD_SQL_Projects.md>): SQL projects, SDK-style model, tests, Git, secrets, drift, DACPAC và pipeline controls.
- [07 — Azure Services Integration](<Documents_Guide/DP800_Domain2_Security_Optimization_07_Azure_Services_Integration.md>): Data API Builder 2.0, REST/GraphQL, caching, pagination, monitoring, CT/CDC/Functions và CES.

### Domain 3 — Implement AI capabilities in database solutions

- [08 — Models & Embeddings](<Documents_Guide/DP800_Domain3_AI_Capabilities_08_Models_Embeddings.md>): external models, chunks, embeddings, maintenance strategies, ONNX Preview và CES.
- [09 — Intelligent Search](<Documents_Guide/DP800_Domain3_AI_Capabilities_09_Intelligent_Search.md>): Full-Text, vector type, DiskANN, exact/approximate search, hybrid search, RRF và troubleshooting.
- [10 — RAG Pipeline](<Documents_Guide/DP800_Domain3_AI_Capabilities_10_RAG_Pipeline.md>): prompt, structured JSON, external REST endpoint, permissions, retries và trích xuất response an toàn.

## Môi trường và điều kiện cần có

- **Database:** SQL Server Developer 2022/2025 cho lab T-SQL ổn định; Azure SQL Database hoặc SQL database in Fabric cho các tính năng cloud/AI tương ứng.
- **Công cụ:** SSMS phiên bản hiện hành; VS Code và Git hữu ích cho SQL Database Projects, Copilot và MCP.
- **Azure/Fabric:** chỉ cần khi lab yêu cầu; một số tính năng cần paid capacity, Managed Identity, Azure Event Hubs, Azure OpenAI/Foundry hoặc endpoint REST.
- **Kiến thức nền:** nếu chưa biết SQL, bắt đầu từ file 00A; nếu đã biết SQL nhưng chưa biết AI database, có thể bắt đầu từ Domain 1.

Không suy luận rằng một câu lệnh chạy giống nhau trên SQL Server, Azure SQL và Fabric. Luôn đọc phần **Applies to**, prerequisites, compatibility level và nhãn **Preview/GA** trong tài liệu Microsoft.

## Quy tắc chạy lab an toàn

- Dùng database riêng, dữ liệu giả và tài khoản có quyền tối thiểu.
- Đọc toàn bộ script trước khi chạy; kiểm tra các câu `DROP`, `ALTER`, `UPDATE`, `DELETE` và dynamic SQL.
- Không commit API key, password, SAS token, connection string hoặc secret vào Git.
- Thay placeholder như `<your-resource>`, `<credential>` và `<endpoint>` bằng giá trị lab của bạn; không dán secret thật vào Markdown.
- Các ví dụ AI/vector/RAG có thể cần platform hoặc version cụ thể, nên một số đoạn chỉ được kiểm tra tĩnh nếu không có dịch vụ Azure/Fabric tương ứng.

## Nguồn Microsoft chính thức

- [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
- [Microsoft Certified: SQL AI Developer Associate](https://learn.microsoft.com/en-us/credentials/certifications/developing-ai-enabled-database-solutions/)
- [Course DP-800T00-A](https://learn.microsoft.com/en-us/training/courses/dp-800t00)
- [Learning path: Domain 1](https://learn.microsoft.com/en-us/training/paths/design-develop-database-solutions/)
- [Learning path: Domain 2](https://learn.microsoft.com/en-us/training/paths/secure-optimize-deploy-database-solutions/)
- [Learning path: Domain 3](https://learn.microsoft.com/en-us/training/paths/implement-ai-capabilities-database-solutions/)
- [SQL Server documentation](https://learn.microsoft.com/en-us/sql/)
- [Azure SQL documentation](https://learn.microsoft.com/en-us/azure/azure-sql/)
- [SQL database in Microsoft Fabric](https://learn.microsoft.com/en-us/fabric/database/sql/overview)
- [Data API Builder](https://learn.microsoft.com/en-us/azure/data-api-builder/)
- [SQL Database Projects](https://learn.microsoft.com/en-us/sql/tools/sql-database-projects/sql-database-projects?view=sql-server-ver17)
- [GitHub Copilot in SSMS](https://learn.microsoft.com/en-us/ssms/github-copilot/overview)
- [Microsoft SQL MCP Server](https://learn.microsoft.com/en-us/sql/mcp/)

## Tình trạng kiểm tra

Tính đến 09/08/2026:

- 12 file Markdown trong `Documents_Guide` đều được mã hóa UTF-8 hợp lệ.
- Roadmap có đủ 73 ID liên tục, không thiếu hoặc trùng.
- 19/19 khối T-SQL trong file prerequisite đã chạy thành công trong database QA tạm.
- 16/16 khối JSON hợp lệ.
- Code fence, link nội bộ và `git diff --check` đều đạt.

Đây là kiểm tra chất lượng tài liệu và lab mẫu; nó không thay thế việc chạy hands-on trên đúng platform/version mà câu hỏi thi nêu.

## Giấy phép

Workspace hiện chưa có file `LICENSE`. Không nên tự suy đoán giấy phép sử dụng hoặc tái phân phối; hãy bổ sung một license rõ ràng trước khi công khai repository.
