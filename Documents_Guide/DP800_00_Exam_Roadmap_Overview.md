# DP-800: Developing AI-Enabled Database Solutions — Tổng quan và lộ trình ôn thi

> **Chứng chỉ:** Microsoft Certified: SQL AI Developer Associate  
> **Kỳ thi:** DP-800 — Developing AI-Enabled Database Solutions  
> **Blueprint đang áp dụng:** Skills measured as of **March 12, 2026**  
> **Ngày đối chiếu nguồn Microsoft:** **09/08/2026**
> **Điểm đạt:** **700/1000 theo scaled score**, không đồng nghĩa với 70% câu đúng

> [!IMPORTANT]
> **Kết luận ngắn:** Sau đợt rà soát này, bộ tài liệu gồm roadmap, một file prerequisite và 10 file chuyên đề đã có nơi học cho **đủ 11 skill group và 73/73 bullet** trong Study Guide DP-800 hiện hành. Vì vậy, bộ tài liệu **đủ về phạm vi blueprint** để làm giáo trình chính. Tuy nhiên, không tài liệu tĩnh nào có thể cam kết bạn trả lời được “mọi câu hỏi”. Microsoft nói rõ các bullet chỉ minh họa cách kỹ năng được đánh giá, chủ đề liên quan vẫn có thể xuất hiện, và một số Preview feature phổ biến cũng có thể được hỏi. Muốn thật sự exam-ready, bạn phải hoàn thành lab, tự viết lại code, làm Practice Assessment và sửa được các lỗi trong error log.

> [!NOTE]
> Đây là bộ tài liệu cho **DP-800**, không phải DP-700. DP-700 có mục tiêu và blueprint khác.

---

## 1. DP-800 đánh giá điều gì?

Ứng viên DP-800 cần thiết kế và phát triển giải pháp database có AI trên các nền tảng Microsoft SQL, gồm:

- **Microsoft SQL Server**;
- **Azure SQL**;
- **SQL database in Microsoft Fabric**.

Ngoài T-SQL và thiết kế database, bạn còn phải hiểu GitHub/CI/CD, AI-assisted development, models, embeddings, vectors, intelligent search và RAG. Đây không phải kỳ thi chỉ hỏi cú pháp SQL; nhiều câu hỏi là scenario yêu cầu chọn giải pháp phù hợp, an toàn, dễ vận hành và đúng platform/version.

Nếu bạn chưa vững `SELECT`, `JOIN`, `GROUP BY`, subquery, transaction và cách chạy script T-SQL, hãy học [00A — T-SQL Foundations & Prerequisites](./DP800_00A_TSQL_Foundations_Prerequisites.md) trước File 01. Đây là **kiến thức đầu vào**, không phải domain thứ tư và không làm thay đổi trọng số kỳ thi.

Nguồn chuẩn:

1. [DP-800 Study Guide — nguồn quyết định phạm vi thi](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
2. [Microsoft Certified: SQL AI Developer Associate](https://learn.microsoft.com/en-us/credentials/certifications/developing-ai-enabled-database-solutions/)
3. [Course DP-800T00-A: Develop AI-enabled database solutions](https://learn.microsoft.com/en-us/training/courses/dp-800t00)

### Thứ tự ưu tiên khi hai nguồn có vẻ khác nhau

1. Study Guide DP-800 hiện hành và dòng **Skills measured as of ...**.
2. Microsoft Learn/Docs đúng với platform và version được nêu trong câu hỏi.
3. Tài liệu trong folder này.
4. Blog/video/community chỉ dùng để bổ trợ, không dùng để ghi đè tài liệu chính thức.

Nếu Microsoft cập nhật blueprint sau ngày **12/03/2026**, hãy coi bản mới là nguồn chuẩn và rà soát lại ma trận ở phần 3.

---

## 2. Blueprint và trọng số hiện hành

| Domain | Trọng số | Số skill group | Số bullet trong Study Guide |
|---|---:|---:|---:|
| **1. Design and develop database solutions** | **35–40%** | 4 | 24 |
| **2. Secure, optimize, and deploy database solutions** | **35–40%** | 4 | 28 |
| **3. Implement AI capabilities in database solutions** | **25–30%** | 3 | 21 |
| **Tổng** | — | **11** | **73** |

Ý nghĩa thực tế:

- Domain 1 và Domain 2 có trọng số cao ngang nhau; không nên chỉ học phần AI.
- Domain 3 ít trọng số hơn nhưng vẫn chiếm khoảng một phần tư bài thi và chứa nhiều khái niệm mới.
- Trọng số là khoảng phần trăm, không phải cam kết số câu cố định cho từng domain.
- Microsoft có thể hỏi chủ đề liên quan trực tiếp đến một bullet, nên học theo **hệ thống quyết định + hands-on**, không học thuộc từng dòng rời rạc.

---

## 3. Ma trận 73 bullet blueprint → file học

Số **01–73** dưới đây là mã theo dõi nội bộ của bộ tài liệu, được đánh tuần tự theo đúng thứ tự bullet trên Study Guide; Microsoft không đánh số các bullet này. “Đã phủ” nghĩa là bullet đã được đối chiếu và định tuyến đến file chuyên đề có giải thích, ví dụ hoặc checklist. Nó **không tự động có nghĩa người học đã thành thạo**.

### Domain 1 — Design and develop database solutions (35–40%)

| Mã | Skill group và từng bullet Study Guide | File học | Xác minh |
|---|---|---|---|
| **01–06** | **Design and implement database objects**<br>**01.** Tables: data types, size, columns, indexes, columnstore indexes.<br>**02.** Specialized tables: in-memory, temporal, external, ledger, graph.<br>**03.** JSON columns và indexes.<br>**04.** `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `CHECK`, `DEFAULT`.<br>**05.** `SEQUENCE`.<br>**06.** Partitioning cho tables và indexes. | [01 — Database Objects](./DP800_Domain1_Database_Design_01_Database_Objects.md) | ✅ **6/6**<br>09/08/2026 |
| **07–11** | **Implement programmability objects**<br>**07.** Views.<br>**08.** Scalar functions.<br>**09.** Table-valued functions.<br>**10.** Stored procedures.<br>**11.** Triggers. | [02 — Programmability & Advanced T-SQL](./DP800_Domain1_Database_Design_02_Programmability_Advanced_TSQL.md) | ✅ **5/5**<br>09/08/2026 |
| **12–19** | **Write advanced T-SQL code**<br>**12.** Common Table Expressions (CTEs).<br>**13.** Window functions.<br>**14.** JSON: `JSON_OBJECT`, `JSON_ARRAY`, `JSON_ARRAYAGG`, `JSON_CONTAINS`, `OPENJSON`, `JSON_VALUE`.<br>**15.** Regex: `REGEXP_LIKE`, `REGEXP_REPLACE`, `REGEXP_SUBSTR`, `REGEXP_INSTR`, `REGEXP_COUNT`, `REGEXP_MATCHES`, `REGEXP_SPLIT_TO_TABLE`.<br>**16.** Fuzzy: `EDIT_DISTANCE`, `EDIT_DISTANCE_SIMILARITY`, `JARO_WINKLER_DISTANCE`.<br>**17.** Graph queries với `MATCH`.<br>**18.** Correlated queries.<br>**19.** Error handling. | [02 — Programmability & Advanced T-SQL](./DP800_Domain1_Database_Design_02_Programmability_Advanced_TSQL.md) | ✅ **8/8**<br>09/08/2026 |
| **20–24** | **Design and implement SQL solutions by using AI-assisted tools**<br>**20.** Security impact của AI-assisted tools.<br>**21.** Enable GitHub Copilot và Microsoft Copilot in Fabric.<br>**22.** Model và MCP tool options trong Copilot chat.<br>**23.** GitHub Copilot instruction files.<br>**24.** Kết nối MCP server endpoints, gồm Microsoft SQL Server và Fabric lakehouse. | [03 — AI-Assisted Tools](./DP800_Domain1_Database_Design_03_AIAssisted_Tools.md) | ✅ **5/5**<br>09/08/2026 |

### Domain 2 — Secure, optimize, and deploy database solutions (35–40%)

| Mã | Skill group và từng bullet Study Guide | File học | Xác minh |
|---|---|---|---|
| **25–32** | **Implement data security and compliance**<br>**25.** Data encryption, gồm Always Encrypted và column-level encryption.<br>**26.** Dynamic Data Masking.<br>**27.** Row-Level Security (RLS).<br>**28.** Object-level permissions.<br>**29.** Secure database access, gồm passwordless.<br>**30.** Auditing.<br>**31.** Secure model endpoints, gồm Managed Identity.<br>**32.** Secure GraphQL, REST và MCP endpoints. | [04 — Data Security & Compliance](./DP800_Domain2_Security_Optimization_04_Data_Security_Compliance.md) | ✅ **8/8**<br>09/08/2026 |
| **33–36** | **Optimize database performance**<br>**33.** Recommend database configurations.<br>**34.** Data integrity/consistency bằng transaction isolation levels và concurrency controls.<br>**35.** Query performance bằng execution plans, DMVs, Query Store và Query Performance Insight.<br>**36.** Xác định, xử lý blocking và deadlocks. | [05 — Performance Optimization](./DP800_Domain2_Security_Optimization_05_Performance_Optimization.md) | ✅ **4/4**<br>09/08/2026 |
| **37–45** | **Implement CI/CD by using SQL Database Projects**<br>**37.** Unit tests và integration tests.<br>**38.** Reference/static data trong source control.<br>**39.** Create/build/validate database models, gồm SDK-style models.<br>**40.** Source control cho SQL Database Projects.<br>**41.** Branching, pull requests, conflict resolution.<br>**42.** Secrets management.<br>**43.** Schema drift detection.<br>**44.** Update SQL database project và deploy changes.<br>**45.** Deployment pipeline controls, gồm branching policies, triggers in approvals, authentication tables và code owners. | [06 — CI/CD & SQL Database Projects](./DP800_Domain2_Security_Optimization_06_CICD_SQL_Projects.md) | ✅ **9/9**<br>09/08/2026 |
| **46–52** | **Integrate SQL solutions with Azure services**<br>**46.** DAB configuration files.<br>**47.** REST/GraphQL entities: data caching, pagination, searching, filtering.<br>**48.** REST hoặc GraphQL endpoints.<br>**49.** Expose database objects, stored procedures, views và GraphQL relationships.<br>**50.** DAB deployment.<br>**51.** Azure Monitor, gồm Application Insights và Log Analytics.<br>**52.** Handle changes bằng CES, CDC, Change Tracking, Azure Functions SQL trigger binding hoặc Azure Logic Apps. | [07 — Azure Services Integration](./DP800_Domain2_Security_Optimization_07_Azure_Services_Integration.md) | ✅ **7/7**<br>09/08/2026 |

### Domain 3 — Implement AI capabilities in database solutions (25–30%)

| Mã | Skill group và từng bullet Study Guide | File học | Xác minh |
|---|---|---|---|
| **53–58** | **Design and implement models and embeddings**<br>**53.** Evaluate external models: multimodal, multilanguage, sizes, structured output.<br>**54.** Create và manage external models.<br>**55.** Chọn embedding maintenance: table triggers, Change Tracking, Azure Functions SQL trigger binding, Azure Logic Apps, CDC, CES, Microsoft Foundry.<br>**56.** Chọn columns đưa vào embeddings.<br>**57.** Design và implement chunks.<br>**58.** Generate embeddings. | [08 — Models & Embeddings](./DP800_Domain3_AI_Capabilities_08_Models_Embeddings.md) | ✅ **6/6**<br>09/08/2026 |
| **59–68** | **Design and implement intelligent search**<br>**59.** Chọn full-text, semantic vector hoặc hybrid search.<br>**60.** Implement Full-Text Search.<br>**61.** Vector data type, vector indexes và size.<br>**62.** `VECTOR_NORMALIZE`, `VECTOR_DISTANCE`, `VECTORPROPERTY`, `VECTOR_SEARCH`.<br>**63.** ANN vs ENN.<br>**64.** Vector index types và metrics.<br>**65.** Implement vector search.<br>**66.** Implement hybrid search.<br>**67.** Reciprocal Rank Fusion (RRF).<br>**68.** Evaluate vector/hybrid search performance. | [09 — Intelligent Search](./DP800_Domain3_AI_Capabilities_09_Intelligent_Search.md) | ✅ **10/10**<br>09/08/2026 |
| **69–73** | **Design and implement retrieval-augmented generation (RAG)**<br>**69.** Identify RAG use cases.<br>**70.** Create prompt bằng `sp_invoke_external_rest_endpoint` stored procedure.<br>**71.** Structured data → JSON cho language model.<br>**72.** Send results tới language model.<br>**73.** Extract language model responses. | [10 — RAG Pipeline](./DP800_Domain3_AI_Capabilities_10_RAG_Pipeline.md) | ✅ **5/5**<br>09/08/2026 |

### Kết quả audit phạm vi

- **11/11 skill group** có file chuyên đề.
- **73/73 bullet** của blueprint hiện hành có nơi học.
- File [00A — T-SQL Foundations & Prerequisites](./DP800_00A_TSQL_Foundations_Prerequisites.md) bổ sung nền tảng cho người mới; file này không được tính là exam domain hay bullet thứ 74.
- Không còn tình trạng Domain 2 hoặc Domain 3 “chưa được cung cấp” như bản roadmap cũ.
- Các phần dễ thay đổi theo version như Copilot/MCP, DAB, SQL Database Projects, vector search, external models và AI functions phải luôn được đối chiếu với link Microsoft ở cuối file chuyên đề trước ngày thi.

---

## 4. Khi nào mới được coi là “nắm chắc”?

Đọc hết tài liệu mới chỉ là bước đầu. Với mỗi skill group, bạn phải vượt qua bốn tầng sau:

| Tầng | Bạn phải làm được gì? | Cách tự kiểm tra |
|---|---|---|
| **1. Nhận biết** | Giải thích khái niệm bằng lời dễ hiểu | Nói trong 60–90 giây mà không nhìn tài liệu |
| **2. Chọn giải pháp** | Đọc requirement và chọn đúng feature/platform | Giải thích vì sao ba phương án còn lại sai |
| **3. Triển khai** | Viết T-SQL/config/project cốt lõi | Làm lab từ file trống, không copy-paste |
| **4. Chẩn đoán** | Nhận ra lỗi security, performance, syntax và version | Cố tình làm hỏng lab rồi tự sửa |

### Gate “exam-ready” đề xuất

Chỉ nên đặt lịch thi khi bạn đạt đồng thời:

- [ ] Hoàn thành checklist cuối **cả 10 file chuyên đề**.
- [ ] Tự làm lại các lab quan trọng mà không nhìn lời giải.
- [ ] Có error log ghi: câu sai, lý do sai, rule đúng, link Microsoft, ngày ôn lại.
- [ ] Hoàn thành module assessment của cả ba Microsoft Learn learning path.
- [ ] Làm Practice Assessment trong điều kiện bấm giờ; đạt mức ổn định qua nhiều lần, không phải do nhớ đáp án.
- [ ] Có thể xác định **platform + version + trạng thái GA/Preview** trước khi chọn cú pháp.
- [ ] Có thể giải thích least privilege, Managed Identity/passwordless và data boundary trong mọi scenario có AI/API/MCP.

> [!CAUTION]
> “Thuộc cú pháp” nhưng không biết chọn đúng scenario vẫn chưa đủ. Ngược lại, chỉ hiểu khái niệm nhưng không viết được T-SQL/config cốt lõi cũng chưa đủ cho kỳ thi developer-level này.

---

## 5. Bộ lab tối thiểu phải tự làm

| File | Bài thực hành tối thiểu |
|---|---|
| **01 — Database Objects** | Tạo schema có rowstore/columnstore, constraints, sequence, partitioning; tạo và query temporal, ledger, graph, JSON và ít nhất một specialized table khác |
| **02 — Programmability & T-SQL** | Tạo view/UDF/TVF/procedure/trigger; viết CTE, window, JSON, regex, fuzzy, `MATCH`, correlated query và transaction `TRY...CATCH` |
| **03 — AI-Assisted Tools** | Tạo Copilot instruction file; cấu hình MCP trong môi trường lab; kiểm tra tool approval, quyền read-only/least privilege và prompt có rủi ro |
| **04 — Security** | So sánh và triển khai encryption phù hợp, DDM, RLS, permissions, Entra/passwordless pattern, audit và endpoint security |
| **05 — Performance** | Đọc actual execution plan; dùng DMV/Query Store; tái hiện blocking/deadlock; thử isolation level và biện pháp sửa |
| **06 — CI/CD** | Tạo SDK-style SQL project, build `.dacpac`, test, quản lý static data, phát hiện drift và deploy bằng pipeline mẫu không hard-code secret |
| **07 — Azure Integration** | Tạo DAB config; expose REST/GraphQL entity/view/procedure/relationship; thêm auth, filter, pagination/cache; deploy và quan sát log; so sánh các change pattern |
| **08 — Models & Embeddings** | Tạo external model/credential trong môi trường hỗ trợ; thiết kế chunk; generate/store embeddings và triển khai một maintenance pattern |
| **09 — Intelligent Search** | Tạo Full-Text Search; exact vector search; ANN khi platform hỗ trợ; hybrid search + RRF; đo latency/quality |
| **10 — RAG** | Viết pipeline retrieval → JSON → augmented prompt → `sp_invoke_external_rest_endpoint` → parse response, có Managed Identity/secret hygiene và error handling |

Nếu không có Azure subscription hoặc feature chưa khả dụng trong môi trường lab, vẫn phải:

1. viết đúng script/config;
2. đánh dấu rõ platform/version;
3. đọc output mẫu và chẩn đoán được lỗi;
4. không giả vờ rằng code đã được chạy thành công.

---

## 6. Chu trình học cho từng chương

Dùng chu trình sau:

**Concept → Requirement → Syntax → Lab → Break it → Diagnose → Scenario question → Explain why alternatives are wrong**

Ví dụ với temporal table:

1. Nói được use case: xem trạng thái dữ liệu tại một thời điểm trong quá khứ.
2. Phân biệt temporal với ledger: history theo thời gian khác với tamper-evident verification.
3. Viết `CREATE TABLE ... SYSTEM_VERSIONING = ON`.
4. `INSERT`/`UPDATE` để sinh history.
5. Query `FOR SYSTEM_TIME AS OF` và các biến thể cần thiết.
6. Cố tình bỏ `PRIMARY KEY` hoặc cấu hình period sai để hiểu điều kiện bắt buộc.
7. Làm câu scenario và loại trừ đáp án không đúng requirement.

Quy tắc ôn lặp lại gợi ý:

- Lần 1: ngay sau khi học.
- Lần 2: sau 1 ngày.
- Lần 3: sau 3 ngày.
- Lần 4: sau 7 ngày.
- Lần 5: trước kỳ thi.

---

## 7. Decision table — nhận diện keyword trong scenario

| Requirement nổi bật | Hướng chọn đầu tiên | Cần loại trừ/kiểm tra thêm |
|---|---|---|
| Aggregate dữ liệu rất lớn, scan nhiều cột | Columnstore | OLTP point lookup có thể hợp rowstore hơn |
| OLTP contention cao, yêu cầu latency thấp | In-Memory OLTP nếu platform/workload phù hợp | Chi phí memory, durability, limitations |
| Xem dữ liệu tại một thời điểm quá khứ | Temporal | Không đồng nghĩa tamper-evident |
| Chứng minh dữ liệu không bị sửa trái phép | Ledger | Không thay thế backup hoặc RLS |
| Quan hệ nhiều-hop | Graph + `MATCH` | Quan hệ đơn giản có thể chỉ cần join |
| Query dữ liệu bên ngoài như table | External table | Kiểm tra data source, credential, pushdown |
| Cột nhạy cảm không để database engine/DBA thấy plaintext | Always Encrypted | TDE chỉ bảo vệ at rest |
| User được thấy row nhưng một số giá trị phải bị che | Dynamic Data Masking | DDM không phải encryption |
| Mỗi tenant/user chỉ được thấy một số row | Row-Level Security | DDM không lọc row |
| Kết nối không dùng password/secret cố định | Microsoft Entra + Managed Identity/passwordless | Quyền database vẫn phải least privilege |
| Query chậm sau plan regression | Query Store | Vẫn phải kiểm tra wait/resource/index/statistics |
| Session chờ lock của session khác | Blocking | Deadlock là vòng chờ và có victim |
| Database schema phải build/deploy lặp lại | SQL Database Project + `.dacpac` + CI/CD | Không sửa production ad-hoc |
| Expose SQL bằng REST/GraphQL ít boilerplate | Data API builder | Phải cấu hình auth, entity permission và endpoint security |
| Cần biết row nào đã đổi để đồng bộ | Change Tracking | Nếu cần toàn bộ before/after/history, cân nhắc CDC/CES |
| Search đúng từ/cụm từ, morphology hoặc relevance | Full-Text Search | `LIKE '%...%'` không phải Full-Text Search |
| Search theo ý nghĩa | Vector Search | Exact ID/SKU vẫn dùng B-tree/filter |
| Cần cả keyword chính xác và semantic recall | Hybrid Search + ranking/RRF | Không cộng trực tiếp raw score khác thang đo |
| Cần câu trả lời LLM dựa trên dữ liệu private/current | RAG | Filter quyền trước khi gửi context cho model |
| AI agent gọi database/Fabric tools | MCP + approval + least privilege | Không cấp quyền rộng hoặc tin output chưa review |

---

## 8. Lộ trình 28 buổi cho người mới bắt đầu

Mỗi “buổi” nên có 90–150 phút. Nếu chỉ học 45–60 phút/ngày, hãy tách một buổi thành hai ngày; không cần ép hoàn thành trong đúng 28 ngày.

| Buổi | Nội dung chính | Sản phẩm phải tạo |
|---:|---|---|
| 0 *(nếu chưa vững T-SQL)* | Học [00A — T-SQL Foundations & Prerequisites](./DP800_00A_TSQL_Foundations_Prerequisites.md): `SELECT`, `JOIN`, `GROUP BY`, subquery, DML, transaction và cách chạy script | Bộ query nền tảng tự viết; chỉ chuyển sang File 01 khi đọc/viết được các mẫu cơ bản |
| 1 | Đọc roadmap, Study Guide, làm baseline assessment | Danh sách điểm yếu + error log |
| 2–3 | Tables, data types, rowstore/columnstore indexes | Script tạo bảng/index + giải thích lựa chọn |
| 4–5 | Specialized tables, JSON, constraints, sequence, partition | Lab tổng hợp File 01 |
| 6 | Views, functions, procedures, triggers | Lab programmability |
| 7–8 | CTE, window, JSON, regex, fuzzy, graph, correlated query, error handling | Bộ query File 02 chạy được |
| 9 | Copilot, instructions, MCP, security impact | Config/instruction mẫu + threat checklist |
| 10–11 | Encryption, DDM, RLS, permissions, passwordless, audit | Security lab + decision table tự viết |
| 12–14 | Configuration, isolation/concurrency, plans, DMVs, Query Store, blocking/deadlocks | Performance investigation report |
| 15–17 | SQL Database Projects, tests, Git, branch/PR, secrets, drift, deploy/pipeline controls | Project build ra `.dacpac` + pipeline mẫu |
| 18–20 | DAB REST/GraphQL, deployment, Azure Monitor, change patterns | DAB config + change-pattern matrix |
| 21–22 | Models, external models, embeddings, chunks, maintenance | Embedding design + lab File 08 |
| 23–24 | Full-text, vector, ANN/ENN, hybrid, RRF, performance | Search lab + benchmark ngắn |
| 25 | RAG end-to-end | Stored procedure/pipeline RAG |
| 26 | Mixed scenarios xuyên ba domain | 30–50 câu tự tạo hoặc practice, giải thích đáp án sai |
| 27 | Practice Assessment + Exam Sandbox có bấm giờ | Score + error log + danh sách lookup chậm |
| 28 | Chỉ ôn lỗi; làm lại lab/câu sai không nhìn đáp án | Go/no-go checklist |

### Phân bổ thời gian nếu cần ôn gấp

- Domain 1: **35–40%** thời gian.
- Domain 2: **35–40%** thời gian.
- Domain 3: **25–30%** thời gian.
- Sau mỗi hai buổi, dành 15–20 phút ôn lại câu sai cũ.

Không nên dồn toàn bộ thời gian cho Domain 3 chỉ vì AI là phần mới và hấp dẫn.

---

## 9. Chiến thuật làm bài thi

Theo trang chứng chỉ hiện hành, DP-800 có **120 phút** để hoàn thành assessment. Hãy kiểm tra lại thời lượng hiển thị khi đăng ký và ở màn hình hướng dẫn trước khi bắt đầu, vì Microsoft có thể thay đổi trải nghiệm thi.

### Trước khi chọn đáp án

Đọc scenario theo thứ tự:

1. **Platform nào?** SQL Server, Azure SQL hay SQL database in Fabric?
2. **Version/feature state nào?** GA hay Preview? Cú pháp có được platform đó hỗ trợ không?
3. **Requirement bắt buộc là gì?** Security, latency, scale, consistency, cost, recovery hay maintainability?
4. **Constraint là gì?** Không đổi application, không dùng secret, ít downtime, read-only, near-real-time...?
5. **Phương án nào thỏa đủ requirement với ít phức tạp/rủi ro nhất?**

### Quản lý thời gian

- Lượt 1: trả lời câu chắc chắn; đánh dấu câu cần kiểm tra.
- Lượt 2: xử lý câu scenario dài và câu cần đối chiếu tài liệu.
- Lượt cuối: kiểm tra câu bỏ trống, multi-select và các từ khóa như **NOT**, **MOST**, **LEAST**, **BEST**.
- Đừng dành quá nhiều thời gian tra cứu một cú pháp hiếm rồi bỏ lỡ nhiều câu khác.

### Dùng Microsoft Learn trong kỳ thi

Microsoft cho phép truy cập nội dung trong domain `learn.microsoft.com` ở các role-based exam, nhưng:

- đồng hồ thi vẫn chạy;
- không được cộng thêm thời gian;
- một số khu vực như Q&A, Practice Assessment và profile không truy cập được;
- Learn phù hợp để kiểm tra chi tiết hiếm, không phải để tìm đáp án cho mọi câu.

Hãy luyện trước việc tìm nhanh bằng tên function/object và `Ctrl+F` trên trang docs.

### Scoring và guessing

- Technical exam dùng scaled score 1–1000; **700** là điểm đạt nhưng không phải 70% câu đúng.
- Câu nhiều phần thường có thể nhận điểm theo từng phần đúng nếu đề ghi nhận multi-point.
- Không bị trừ điểm vì chọn sai, vì vậy hãy trả lời mọi câu.
- Có thể có câu không được tính điểm; bạn không biết câu nào, nên xử lý mọi câu như câu có điểm.

### Break

Nếu dùng unscheduled break, đồng hồ vẫn chạy và bạn không thể quay lại các câu đã xem trước break. Chỉ bấm break sau khi đã trả lời/review xong phần hiện tại.

---

## 10. Ưu tiên cá nhân từ score report đang ghi trong bộ tài liệu

Bản roadmap trước ghi nhận score gần nhất là **673/1000** và ba khu vực cần ưu tiên:

1. **Design and implement SQL solutions by using AI-assisted tools**.
2. **Integrate SQL solutions with Azure services**.
3. **Design and implement database objects**.

Nếu đây vẫn là score report mới nhất, hãy dành thêm 30–40% thời gian thực hành cho File 03, File 07 và File 01, nhưng không bỏ các skill group khác. Biểu đồ skill area trong score report chỉ cho biết tương đối điểm mạnh/yếu; Microsoft nói không thể dùng độ dài các thanh để suy ra số câu đúng.

Nếu đã có score report mới hơn, hãy cập nhật danh sách ưu tiên cá nhân này; **không thay đổi blueprint/trọng số** theo score cá nhân.

---

## 11. Quy tắc với tính năng mới và Preview

- Microsoft cho biết phần lớn câu hỏi dùng tính năng GA, nhưng Preview feature phổ biến vẫn có thể xuất hiện.
- Luôn ghi nhớ **product + version + availability** cạnh cú pháp mới.
- Không suy diễn rằng cùng một tính năng hoạt động giống hệt trên SQL Server, Azure SQL và Fabric.
- Không học thuộc version package/model/API nếu blueprint chỉ đánh giá concept; version có thể đổi nhanh.
- Nếu file local mâu thuẫn với Microsoft Learn đúng platform/version tại thời điểm thi, ưu tiên Microsoft Learn và ghi lại điểm cần sửa.
- Trước ngày thi 7–10 ngày, mở lại Study Guide và các link “availability/limitations” trong từng file để kiểm tra thay đổi.

---

## 12. Nguồn Microsoft chính thức nên bookmark

### Blueprint, chứng chỉ và trải nghiệm thi

- [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
- [Microsoft Certified: SQL AI Developer Associate](https://learn.microsoft.com/en-us/credentials/certifications/developing-ai-enabled-database-solutions/)
- [Course DP-800T00-A](https://learn.microsoft.com/en-us/training/courses/dp-800t00)
- [Exam scoring and score reports](https://learn.microsoft.com/en-us/credentials/certifications/exam-scoring-reports)
- [Exam duration and exam experience](https://learn.microsoft.com/en-us/credentials/support/exam-duration-exam-experience)
- [Microsoft Certification Exam Sandbox](https://aka.ms/examdemo)

### Ba learning path bám blueprint

- [Domain 1 — Design and develop database solutions](https://learn.microsoft.com/en-us/training/paths/design-develop-database-solutions/)
- [Domain 2 — Secure, optimize, and deploy database solutions](https://learn.microsoft.com/en-us/training/paths/secure-optimize-deploy-database-solutions/)
- [Domain 3 — Implement AI capabilities in database solutions](https://learn.microsoft.com/en-us/training/paths/implement-ai-capabilities-database-solutions/)

### Ba PDF có sẵn trong workspace — nguồn bổ trợ

- [DP-800ExamRequirements260515.pdf](../DP-800ExamRequirements260515.pdf): snapshot 3 trang của 73 bullet; tiện kiểm tra nhanh phạm vi nhưng Study Guide online vẫn là nguồn quyết định khi có thay đổi.
- [DP-800Notes260612.pdf](../DP-800Notes260612.pdf): 164 trang ghi chú theo các mục tiêu 1–73; dùng để ôn lại và đối chiếu ví dụ.
- [DP-800CodeUsed260610.pdf](../DP-800CodeUsed260610.pdf): 80 trang code mẫu; dùng làm bài thực hành bổ sung, không copy thẳng vào production.

Hai PDF Notes/Code là tài liệu bên thứ ba trong workspace, không phải Microsoft Learn. Nếu nội dung hoặc syntax trong PDF khác tài liệu Microsoft đúng platform/version, ưu tiên Microsoft và ghi lại sai lệch vào error log.

### Documentation nền tảng

- [Microsoft SQL documentation](https://learn.microsoft.com/en-us/sql/)
- [Azure SQL documentation](https://learn.microsoft.com/en-us/azure/azure-sql/)
- [SQL database in Microsoft Fabric](https://learn.microsoft.com/en-us/fabric/database/sql/overview)
- [Data API builder documentation](https://learn.microsoft.com/en-us/azure/data-api-builder/)
- [SQL Database Projects documentation](https://learn.microsoft.com/en-us/sql/tools/sql-database-projects/sql-database-projects?view=sql-server-ver17)
- [GitHub Copilot in SQL Server Management Studio](https://learn.microsoft.com/en-us/ssms/github-copilot/overview)
- [Microsoft SQL MCP Server](https://learn.microsoft.com/en-us/sql/mcp/)

---

## 13. Checklist cập nhật bộ tài liệu trước ngày thi

- [ ] Study Guide vẫn ghi **Skills measured as of March 12, 2026**; nếu không, lập diff với 73 bullet trong roadmap này.
- [ ] Trang chứng chỉ vẫn ghi cùng ba domain và thời lượng thi hiện hành.
- [ ] Link trong từng file chuyên đề còn hoạt động và đúng `view`/platform.
- [ ] Các feature có nhãn Preview/GA trong file vẫn đúng.
- [ ] Các package/API/config format mới không làm ví dụ cũ mất hiệu lực.
- [ ] Practice Assessment và Exam Sandbox đã được thực hành ít nhất một lần.
- [ ] Error log không còn lỗi lặp lại ở cùng một concept.

**Definition of Done cuối cùng:** bạn không chỉ “đã đọc hết”, mà có thể **nhận diện → chọn → triển khai → chẩn đoán → giải thích vì sao phương án khác sai** trên toàn bộ 11 skill group.
