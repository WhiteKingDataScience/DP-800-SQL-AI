# DP-800 — Phát triển giải pháp cơ sở dữ liệu có hỗ trợ AI

> **Chứng chỉ:** Microsoft Certified: SQL AI Developer Associate  
> **Tên kỳ thi:** DP-800 — Developing AI-Enabled Database Solutions  
> **Phạm vi đang áp dụng:** Skills measured as of **March 12, 2026**  
> **Ngày cập nhật cách trình bày:** **12/08/2026**  
> **Điểm đạt:** **700/1000 theo thang điểm quy đổi**, không đồng nghĩa với 70% câu đúng

> [!IMPORTANT]
> **Kết luận ngắn:** Bộ tài liệu gồm một file định hướng, một file kiến thức đầu vào và 10 file chuyên đề. Nội dung đã có nơi học cho **đủ 11 nhóm kỹ năng và 73/73 yêu cầu** trong Study Guide DP-800 hiện hành. Tuy nhiên, “đã có nội dung” không có nghĩa là “đã thành thạo”. Muốn sẵn sàng thi, bạn cần hiểu bài toán, tự viết lại mã, chạy bài thực hành, làm Practice Assessment và ghi lại những lỗi mình thường mắc.

> [!NOTE]
> Đây là bộ tài liệu cho **DP-800**, không phải DP-700. DP-700 có mục tiêu và blueprint khác.

---

## 1. DP-800 dùng để làm gì?

Hãy hình dung một công ty có dữ liệu khách hàng, đơn hàng và tài liệu nội bộ nằm trong cơ sở dữ liệu SQL. Công ty muốn xây một hệ thống có thể:

- lưu dữ liệu đúng cấu trúc và không để dữ liệu sai lọt vào;
- trả lời truy vấn nhanh khi số lượng bản ghi tăng rất lớn;
- chỉ cho mỗi người xem đúng dữ liệu họ được phép xem;
- triển khai thay đổi cơ sở dữ liệu qua Git và quy trình CI/CD an toàn;
- mở dữ liệu SQL qua REST hoặc GraphQL mà không phải viết toàn bộ máy chủ API từ đầu;
- tìm tài liệu theo **ý nghĩa**, không chỉ theo từ khóa;
- cho mô hình ngôn ngữ lớn (LLM) trả lời dựa trên dữ liệu riêng, mới nhất của doanh nghiệp bằng RAG.

Người thiết kế và triển khai các phần đó chính là vai trò mà DP-800 hướng tới: **SQL AI Developer**. Đây không phải kỳ thi dạy bạn huấn luyện một mô hình AI từ đầu. Kỳ thi đánh giá khả năng kết hợp cơ sở dữ liệu SQL, bảo mật, triển khai phần mềm và các khả năng AI thành một giải pháp chạy được trong thực tế.

### Một ví dụ xuyên suốt

Giả sử bạn xây trợ lý hỏi đáp cho bộ phận chăm sóc khách hàng:

```text
Khách hàng đặt câu hỏi
        ↓
Ứng dụng xác định người dùng và quyền truy cập
        ↓
SQL lọc các tài liệu người đó được phép xem
        ↓
Full-Text Search / Vector Search tìm các đoạn liên quan
        ↓
Hệ thống ghép câu hỏi với các đoạn đã tìm được
        ↓
Mô hình ngôn ngữ tạo câu trả lời và trích dẫn nguồn
```

Để hệ thống này hoạt động tốt, bạn phải dùng kiến thức của cả ba miền:

| Miền | Câu hỏi thực tế phải giải quyết |
|---|---|
| **Miền 1 — Thiết kế và phát triển** | Lưu dữ liệu bằng bảng nào? Chọn kiểu dữ liệu và chỉ mục nào? Viết view, procedure, function và truy vấn nâng cao ra sao? |
| **Miền 2 — Bảo mật, tối ưu và triển khai** | Ai được xem dữ liệu? Làm sao tìm nguyên nhân truy vấn chậm? Làm sao đưa thay đổi lên môi trường thật mà không làm hỏng database? |
| **Miền 3 — Khả năng AI** | Làm sao biến văn bản thành vector, tìm theo ngữ nghĩa và xây quy trình RAG để LLM trả lời dựa trên dữ liệu SQL? |

Các nền tảng xuất hiện trong kỳ thi gồm **Microsoft SQL Server**, **Azure SQL** và **SQL database in Microsoft Fabric**. Một tính năng có thể chạy trên nền tảng này nhưng chưa có trên nền tảng khác, vì vậy mỗi tình huống phải được đọc theo đúng sản phẩm và phiên bản.

Nếu bạn chưa vững `SELECT`, `JOIN`, `GROUP BY`, truy vấn con, transaction và cách chạy script T-SQL, hãy học [00A — Nền tảng T-SQL](./DP800_00A_TSQL_Foundations_Prerequisites.md) trước File 01. Đây là **kiến thức đầu vào**, không phải miền thứ tư của kỳ thi.

### Từ điển cực ngắn cho người mới

| Thuật ngữ | Hiểu đơn giản |
|---|---|
| **Database** | Nơi lưu dữ liệu có cấu trúc và các quy tắc bảo vệ dữ liệu đó. |
| **Query** | Câu lệnh yêu cầu database đọc hoặc thay đổi dữ liệu. |
| **Schema** | Nhóm đối tượng và cũng là ranh giới tổ chức/phân quyền trong database. |
| **Index** | Cấu trúc giúp tìm dữ liệu nhanh hơn, tương tự mục lục của một cuốn sách. |
| **Endpoint** | Địa chỉ mà ứng dụng hoặc dịch vụ dùng để gọi vào một hệ thống. |
| **Model** | Mô hình AI nhận đầu vào và tạo đầu ra như embedding hoặc câu trả lời. |
| **Embedding** | Dãy số biểu diễn ý nghĩa của văn bản để máy có thể so sánh độ gần nghĩa. |
| **Vector Search** | Tìm nội dung gần nghĩa bằng cách so sánh embedding. |
| **RAG** | Tìm dữ liệu liên quan trước, rồi đưa dữ liệu đó cho LLM tạo câu trả lời. |
| **CI/CD** | Quy trình tự động kiểm tra, đóng gói và triển khai thay đổi một cách có kiểm soát. |
| **MCP** | Giao thức cho phép trợ lý AI khám phá và gọi các công cụ bên ngoài theo cấu hình. |

### Quy ước trình bày trong bộ tài liệu

Các chương được biên tập cho người mới theo cùng một nhịp học:

1. **Bài toán:** tính năng này giải quyết việc gì trong hệ thống thật?
2. **Khái niệm:** giải thích bằng tiếng Việt trước; tên sản phẩm, từ khóa T-SQL và thuật ngữ cần nhận diện trong đề được giữ bằng tiếng Anh.
3. **Ví dụ:** đưa một tình huống cụ thể thay vì chỉ liệt kê cú pháp.
4. **Cách đọc lệnh:** giải thích từng phần quan trọng và lý do nó xuất hiện.
5. **Kết quả mong đợi:** cho biết chạy xong sẽ thấy gì hoặc dữ liệu thay đổi ra sao.
6. **Khi nào chọn:** nêu dấu hiệu nhận biết trong đề, trường hợp không nên dùng và bẫy dễ nhầm.

Khi gặp một khối mã, đừng chỉ sao chép rồi chạy. Hãy tự trả lời bốn câu: **đầu vào là gì, mỗi bước làm gì, đầu ra phải là gì, và lỗi nào có thể xảy ra**. Đây cũng là cách đọc mã nhanh nhất trong kỳ thi.

Nguồn chuẩn:

1. [DP-800 Study Guide — nguồn quyết định phạm vi thi](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
2. [Microsoft Certified: SQL AI Developer Associate](https://learn.microsoft.com/en-us/credentials/certifications/developing-ai-enabled-database-solutions/)
3. [Course DP-800T00-A: Develop AI-enabled database solutions](https://learn.microsoft.com/en-us/training/courses/dp-800t00)

### Thứ tự ưu tiên khi hai nguồn có vẻ khác nhau

1. Study Guide DP-800 hiện hành và dòng **Skills measured as of ...**.
2. Microsoft Learn/Docs đúng với platform và version được nêu trong câu hỏi.
3. Tài liệu trong folder này.
4. Blog, video và nội dung cộng đồng chỉ dùng để bổ trợ, không dùng để ghi đè tài liệu chính thức.

Nếu Microsoft cập nhật blueprint sau ngày **12/03/2026**, hãy coi bản mới là nguồn chuẩn và rà soát lại ma trận ở phần 3.

---

## 2. Phạm vi kiến thức và trọng số hiện hành

| Miền kiến thức | Trọng số | Số nhóm kỹ năng | Số yêu cầu trong Study Guide |
|---|---:|---:|---:|
| **1. Thiết kế và phát triển giải pháp cơ sở dữ liệu** | **35–40%** | 4 | 24 |
| **2. Bảo mật, tối ưu và triển khai giải pháp cơ sở dữ liệu** | **35–40%** | 4 | 28 |
| **3. Triển khai khả năng AI trong giải pháp cơ sở dữ liệu** | **25–30%** | 3 | 21 |
| **Tổng** | — | **11** | **73** |

Ý nghĩa thực tế:

- Miền 1 và Miền 2 có trọng số cao ngang nhau; không nên chỉ học phần AI.
- Miền 3 ít trọng số hơn nhưng vẫn chiếm khoảng một phần tư bài thi và chứa nhiều khái niệm mới.
- Trọng số là khoảng phần trăm, không phải cam kết số câu cố định cho từng domain.
- Microsoft có thể hỏi chủ đề liên quan trực tiếp đến một yêu cầu, nên học theo **hệ thống ra quyết định kết hợp thực hành**, không học thuộc từng dòng rời rạc.

---

## 3. Bản đồ 73 yêu cầu của kỳ thi → file cần học

Số **01–73** dưới đây là mã theo dõi nội bộ của bộ tài liệu, được đánh tuần tự theo đúng thứ tự trong Study Guide; Microsoft không đánh số các mục này. “Đã phủ” nghĩa là yêu cầu đã được dẫn đến file có phần giải thích, ví dụ hoặc danh sách tự kiểm tra. Nó **không tự động có nghĩa người học đã thành thạo**.

### Miền 1 — Thiết kế và phát triển giải pháp cơ sở dữ liệu (35–40%)

| Mã | Nhóm kỹ năng và từng yêu cầu trong Study Guide | File học | Xác minh |
|---|---|---|---|
| **01–06** | **Thiết kế và triển khai các đối tượng cơ sở dữ liệu**<br>**01.** Bảng: kiểu dữ liệu, kích thước, cột, chỉ mục rowstore và columnstore.<br>**02.** Bảng chuyên biệt: in-memory, temporal, external, ledger và graph.<br>**03.** Cột JSON và chỉ mục JSON.<br>**04.** Các ràng buộc `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `CHECK`, `DEFAULT`.<br>**05.** Đối tượng `SEQUENCE`.<br>**06.** Phân vùng bảng và chỉ mục. | [01 — Đối tượng cơ sở dữ liệu](./DP800_Domain1_Database_Design_01_Database_Objects.md) | ✅ **6/6**<br>09/08/2026 |
| **07–11** | **Triển khai các đối tượng lập trình trong database**<br>**07.** View.<br>**08.** Hàm vô hướng.<br>**09.** Hàm trả về bảng.<br>**10.** Stored procedure.<br>**11.** Trigger. | [02 — Lập trình database và T-SQL nâng cao](./DP800_Domain1_Database_Design_02_Programmability_Advanced_TSQL.md) | ✅ **5/5**<br>09/08/2026 |
| **12–19** | **Viết T-SQL nâng cao**<br>**12.** Common Table Expression (CTE).<br>**13.** Hàm cửa sổ.<br>**14.** Các hàm JSON: `JSON_OBJECT`, `JSON_ARRAY`, `JSON_ARRAYAGG`, `JSON_CONTAINS`, `OPENJSON`, `JSON_VALUE`.<br>**15.** Biểu thức chính quy: `REGEXP_*`.<br>**16.** So khớp chuỗi gần đúng: `EDIT_DISTANCE`, `EDIT_DISTANCE_SIMILARITY`, `JARO_WINKLER_DISTANCE`.<br>**17.** Truy vấn graph với `MATCH`.<br>**18.** Truy vấn tương quan.<br>**19.** Xử lý lỗi. | [02 — Lập trình database và T-SQL nâng cao](./DP800_Domain1_Database_Design_02_Programmability_Advanced_TSQL.md) | ✅ **8/8**<br>09/08/2026 |
| **20–24** | **Thiết kế giải pháp SQL với công cụ hỗ trợ AI**<br>**20.** Ảnh hưởng bảo mật của công cụ AI.<br>**21.** Bật GitHub Copilot và Microsoft Copilot trong Fabric.<br>**22.** Cấu hình model và MCP tool trong Copilot chat.<br>**23.** Tạo file hướng dẫn cho GitHub Copilot.<br>**24.** Kết nối MCP endpoint cho Microsoft SQL Server và Fabric lakehouse. | [03 — Công cụ hỗ trợ AI](./DP800_Domain1_Database_Design_03_AIAssisted_Tools.md) | ✅ **5/5**<br>09/08/2026 |

### Miền 2 — Bảo mật, tối ưu và triển khai giải pháp cơ sở dữ liệu (35–40%)

| Mã | Nhóm kỹ năng và từng yêu cầu trong Study Guide | File học | Xác minh |
|---|---|---|---|
| **25–32** | **Bảo mật dữ liệu và đáp ứng yêu cầu tuân thủ**<br>**25.** Mã hóa dữ liệu, gồm Always Encrypted và mã hóa cấp cột.<br>**26.** Dynamic Data Masking.<br>**27.** Row-Level Security (RLS).<br>**28.** Quyền trên đối tượng.<br>**29.** Truy cập database an toàn, gồm kết nối không dùng mật khẩu.<br>**30.** Kiểm toán.<br>**31.** Bảo vệ model endpoint bằng Managed Identity.<br>**32.** Bảo vệ GraphQL, REST và MCP endpoint. | [04 — Bảo mật và tuân thủ](./DP800_Domain2_Security_Optimization_04_Data_Security_Compliance.md) | ✅ **8/8**<br>09/08/2026 |
| **33–36** | **Tối ưu hiệu năng cơ sở dữ liệu**<br>**33.** Đề xuất cấu hình database.<br>**34.** Giữ tính toàn vẹn và nhất quán bằng isolation level và cơ chế kiểm soát đồng thời.<br>**35.** Phân tích hiệu năng bằng execution plan, DMV, Query Store và Query Performance Insight.<br>**36.** Xác định và xử lý blocking, deadlock. | [05 — Tối ưu hiệu năng](./DP800_Domain2_Security_Optimization_05_Performance_Optimization.md) | ✅ **4/4**<br>09/08/2026 |
| **37–45** | **Triển khai CI/CD bằng SQL Database Projects**<br>**37.** Unit test và integration test.<br>**38.** Quản lý dữ liệu tham chiếu/tĩnh trong Git.<br>**39.** Tạo, build và kiểm tra database model, gồm SDK-style project.<br>**40.** Quản lý mã nguồn cho SQL project.<br>**41.** Branch, pull request và xử lý xung đột.<br>**42.** Quản lý bí mật.<br>**43.** Phát hiện schema drift.<br>**44.** Cập nhật project và triển khai thay đổi.<br>**45.** Kiểm soát pipeline bằng policy, approval, xác thực và code owner. | [06 — CI/CD và SQL Database Projects](./DP800_Domain2_Security_Optimization_06_CICD_SQL_Projects.md) | ✅ **9/9**<br>09/08/2026 |
| **46–52** | **Tích hợp giải pháp SQL với dịch vụ Azure**<br>**46.** Tạo file cấu hình DAB.<br>**47.** Cấu hình entity REST/GraphQL: cache, phân trang, tìm kiếm và lọc.<br>**48.** Cấu hình REST hoặc GraphQL endpoint.<br>**49.** Mở table, view, stored procedure và relationship qua API.<br>**50.** Triển khai DAB.<br>**51.** Azure Monitor, Application Insights và Log Analytics.<br>**52.** Xử lý thay đổi dữ liệu bằng CES, CDC, Change Tracking, Azure Functions SQL trigger hoặc Logic Apps. | [07 — Tích hợp dịch vụ Azure](./DP800_Domain2_Security_Optimization_07_Azure_Services_Integration.md) | ✅ **7/7**<br>09/08/2026 |

### Miền 3 — Triển khai khả năng AI trong giải pháp cơ sở dữ liệu (25–30%)

| Mã | Nhóm kỹ năng và từng yêu cầu trong Study Guide | File học | Xác minh |
|---|---|---|---|
| **53–58** | **Thiết kế và triển khai model, embedding**<br>**53.** Đánh giá model bên ngoài theo khả năng đa phương thức, đa ngôn ngữ, kích thước và structured output.<br>**54.** Tạo và quản lý external model.<br>**55.** Chọn cách cập nhật embedding bằng trigger, Change Tracking, Azure Functions, Logic Apps, CDC, CES hoặc Microsoft Foundry.<br>**56.** Chọn dữ liệu đưa vào embedding.<br>**57.** Thiết kế và tạo các đoạn văn bản nhỏ (chunk).<br>**58.** Sinh embedding. | [08 — Model và embedding](./DP800_Domain3_AI_Capabilities_08_Models_Embeddings.md) | ✅ **6/6**<br>09/08/2026 |
| **59–68** | **Thiết kế và triển khai tìm kiếm thông minh**<br>**59.** Chọn Full-Text, Vector hoặc Hybrid Search.<br>**60.** Triển khai Full-Text Search.<br>**61.** Kiểu dữ liệu vector, kích thước và vector index.<br>**62.** Các hàm `VECTOR_*`.<br>**63.** So sánh tìm kiếm chính xác và xấp xỉ.<br>**64.** Chọn loại vector index và thước đo khoảng cách.<br>**65.** Triển khai Vector Search.<br>**66.** Triển khai Hybrid Search.<br>**67.** Hợp nhất thứ hạng bằng RRF.<br>**68.** Đánh giá chất lượng và hiệu năng tìm kiếm. | [09 — Tìm kiếm thông minh](./DP800_Domain3_AI_Capabilities_09_Intelligent_Search.md) | ✅ **10/10**<br>09/08/2026 |
| **69–73** | **Thiết kế và triển khai RAG**<br>**69.** Nhận diện trường hợp nên dùng RAG.<br>**70.** Tạo prompt và gọi endpoint bằng `sp_invoke_external_rest_endpoint`.<br>**71.** Chuyển dữ liệu SQL có cấu trúc thành JSON.<br>**72.** Gửi kết quả truy xuất tới mô hình ngôn ngữ.<br>**73.** Trích xuất câu trả lời của mô hình. | [10 — Quy trình RAG](./DP800_Domain3_AI_Capabilities_10_RAG_Pipeline.md) | ✅ **5/5**<br>09/08/2026 |

### Kết quả rà soát phạm vi

- **11/11 nhóm kỹ năng** có file chuyên đề.
- **73/73 yêu cầu** của phạm vi hiện hành có nơi học.
- File [00A — Nền tảng T-SQL cho người mới](./DP800_00A_TSQL_Foundations_Prerequisites.md) bổ sung kiến thức đầu vào; file này không phải miền thứ tư hoặc yêu cầu thứ 74 của kỳ thi.
- Không còn tình trạng Domain 2 hoặc Domain 3 “chưa được cung cấp” như bản roadmap cũ.
- Các phần dễ thay đổi theo phiên bản như Copilot/MCP, DAB, SQL Database Projects, tìm kiếm vector, model bên ngoài và hàm AI phải luôn được đối chiếu với liên kết Microsoft ở cuối file chuyên đề trước ngày thi.

---

## 4. Khi nào mới được coi là “nắm chắc”?

Đọc hết tài liệu mới chỉ là bước đầu. Với mỗi nhóm kỹ năng, bạn phải vượt qua bốn tầng sau:

| Tầng | Bạn phải làm được gì? | Cách tự kiểm tra |
|---|---|---|
| **1. Nhận biết** | Giải thích khái niệm bằng lời dễ hiểu | Nói trong 60–90 giây mà không nhìn tài liệu |
| **2. Chọn giải pháp** | Đọc yêu cầu và chọn đúng tính năng/nền tảng | Giải thích vì sao ba phương án còn lại sai |
| **3. Triển khai** | Viết T-SQL/cấu hình/project cốt lõi | Làm bài thực hành từ file trống, không sao chép nguyên mẫu |
| **4. Chẩn đoán** | Nhận ra lỗi bảo mật, hiệu năng, cú pháp và phiên bản | Cố tình làm hỏng bài thực hành rồi tự sửa |

### Điều kiện đề xuất trước khi đặt lịch thi

Chỉ nên đặt lịch thi khi bạn đạt đồng thời:

- [ ] Hoàn thành danh sách tự kiểm tra cuối **cả 10 file chuyên đề**.
- [ ] Tự làm lại các bài thực hành quan trọng mà không nhìn lời giải.
- [ ] Có sổ lỗi ghi: câu sai, lý do sai, quy tắc đúng, liên kết Microsoft và ngày ôn lại.
- [ ] Hoàn thành bài đánh giá của các module trong cả ba lộ trình Microsoft Learn.
- [ ] Làm Practice Assessment trong điều kiện bấm giờ; đạt mức ổn định qua nhiều lần, không phải do nhớ đáp án.
- [ ] Có thể xác định **nền tảng + phiên bản + trạng thái phát hành chính thức/xem trước** trước khi chọn cú pháp.
- [ ] Có thể giải thích đặc quyền tối thiểu (least privilege), Managed Identity/xác thực không mật khẩu và ranh giới dữ liệu trong mọi tình huống có AI/API/MCP.

> [!CAUTION]
> “Thuộc cú pháp” nhưng không biết chọn đúng giải pháp cho tình huống vẫn chưa đủ. Ngược lại, chỉ hiểu khái niệm nhưng không viết được T-SQL/cấu hình cốt lõi cũng chưa đủ cho kỳ thi dành cho nhà phát triển này.

---

## 5. Những bài thực hành tối thiểu phải tự làm

| File | Bài thực hành tối thiểu |
|---|---|
| **01 — Đối tượng cơ sở dữ liệu** | Tạo lược đồ có rowstore/columnstore, ràng buộc, sequence và phân vùng; tạo và truy vấn temporal, ledger, graph, JSON cùng ít nhất một loại bảng chuyên biệt khác |
| **02 — Lập trình và T-SQL** | Tạo view/UDF/TVF/procedure/trigger; viết CTE, hàm cửa sổ, JSON, biểu thức chính quy, so khớp gần đúng, `MATCH`, truy vấn tương quan và giao dịch `TRY...CATCH` |
| **03 — Công cụ hỗ trợ AI** | Tạo file hướng dẫn Copilot; cấu hình MCP trong môi trường thực hành; kiểm tra phê duyệt công cụ, quyền chỉ đọc/đặc quyền tối thiểu và prompt có rủi ro |
| **04 — Bảo mật** | So sánh và triển khai cách mã hóa phù hợp, DDM, RLS, phân quyền, mẫu Entra không mật khẩu, kiểm toán và bảo mật endpoint |
| **05 — Hiệu năng** | Đọc kế hoạch thực thi thực tế; dùng DMV/Query Store; tái hiện chặn/bế tắc; thử mức cô lập và biện pháp sửa |
| **06 — CI/CD** | Tạo SQL project kiểu SDK, biên dịch `.dacpac`, kiểm thử, quản lý dữ liệu tĩnh, phát hiện sai lệch và triển khai bằng quy trình mẫu không ghi cứng bí mật |
| **07 — Tích hợp Azure** | Tạo cấu hình DAB; mở entity/view/procedure/mối quan hệ qua REST/GraphQL; thêm xác thực, lọc, phân trang/bộ nhớ đệm; triển khai, đọc nhật ký và so sánh các cơ chế xử lý thay đổi |
| **08 — Model và embedding** | Tạo model bên ngoài/thông tin xác thực trong môi trường hỗ trợ; thiết kế đoạn nhỏ; sinh/lưu embedding và triển khai một cơ chế cập nhật |
| **09 — Tìm kiếm thông minh** | Tạo tìm kiếm toàn văn; tìm kiếm vector chính xác; ANN khi nền tảng hỗ trợ; tìm kiếm kết hợp + RRF; đo độ trễ/chất lượng |
| **10 — RAG** | Viết quy trình truy xuất → JSON → prompt có ngữ cảnh → `sp_invoke_external_rest_endpoint` → đọc phản hồi, có Managed Identity, bảo vệ bí mật và xử lý lỗi |

Nếu không có Azure subscription hoặc tính năng chưa khả dụng trong môi trường thực hành, vẫn phải:

1. viết đúng đoạn lệnh/cấu hình;
2. đánh dấu rõ nền tảng/phiên bản;
3. đọc đầu ra mẫu và chẩn đoán được lỗi;
4. không giả vờ rằng đoạn mã đã được chạy thành công.

---

## 6. Cách học từng chương

Dùng chu trình sau:

**Hiểu khái niệm → đọc yêu cầu → học cú pháp → chạy bài thực hành → cố tình tạo lỗi → chẩn đoán → làm câu hỏi tình huống → giải thích vì sao các đáp án khác sai**

Ví dụ với temporal table:

1. Nói được trường hợp sử dụng: xem trạng thái dữ liệu tại một thời điểm trong quá khứ.
2. Phân biệt temporal với ledger: history theo thời gian khác với tamper-evident verification.
3. Viết `CREATE TABLE ... SYSTEM_VERSIONING = ON`.
4. `INSERT`/`UPDATE` để sinh history.
5. Query `FOR SYSTEM_TIME AS OF` và các biến thể cần thiết.
6. Cố tình bỏ `PRIMARY KEY` hoặc cấu hình period sai để hiểu điều kiện bắt buộc.
7. Làm câu hỏi tình huống và loại trừ đáp án không thỏa yêu cầu.

Quy tắc ôn lặp lại gợi ý:

- Lần 1: ngay sau khi học.
- Lần 2: sau 1 ngày.
- Lần 3: sau 3 ngày.
- Lần 4: sau 7 ngày.
- Lần 5: trước kỳ thi.

---

## 7. Bảng chọn giải pháp — nhận diện dấu hiệu trong tình huống

| Yêu cầu nổi bật | Hướng chọn đầu tiên | Cần loại trừ hoặc kiểm tra thêm |
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
| 10–11 | Mã hóa, DDM, RLS, quyền, kết nối không dùng mật khẩu, kiểm toán | Bài thực hành bảo mật + bảng chọn giải pháp tự viết |
| 12–14 | Configuration, isolation/concurrency, plans, DMVs, Query Store, blocking/deadlocks | Performance investigation report |
| 15–17 | SQL Database Projects, tests, Git, branch/PR, secrets, drift, deploy/pipeline controls | Project build ra `.dacpac` + pipeline mẫu |
| 18–20 | DAB REST/GraphQL, deployment, Azure Monitor, change patterns | DAB config + change-pattern matrix |
| 21–22 | Models, external models, embeddings, chunks, maintenance | Embedding design + lab File 08 |
| 23–24 | Full-text, vector, ANN/ENN, hybrid, RRF, performance | Search lab + benchmark ngắn |
| 25 | RAG end-to-end | Stored procedure/pipeline RAG |
| 26 | Tình huống kết hợp xuyên ba miền | 30–50 câu tự tạo hoặc bài luyện tập, giải thích vì sao đáp án sai |
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

Đọc tình huống theo thứ tự:

1. **Platform nào?** SQL Server, Azure SQL hay SQL database in Fabric?
2. **Version/feature state nào?** GA hay Preview? Cú pháp có được platform đó hỗ trợ không?
3. **Yêu cầu bắt buộc là gì?** Bảo mật, độ trễ, khả năng mở rộng, tính nhất quán, chi phí, khôi phục hay khả năng bảo trì?
4. **Constraint là gì?** Không đổi application, không dùng secret, ít downtime, read-only, near-real-time...?
5. **Phương án nào thỏa đủ yêu cầu với độ phức tạp và rủi ro thấp nhất?**

### Quản lý thời gian

- Lượt 1: trả lời câu chắc chắn; đánh dấu câu cần kiểm tra.
- Lượt 2: xử lý câu tình huống dài và câu cần đối chiếu tài liệu.
- Lượt cuối: kiểm tra câu bỏ trống, multi-select và các từ khóa như **NOT**, **MOST**, **LEAST**, **BEST**.
- Đừng dành quá nhiều thời gian tra cứu một cú pháp hiếm rồi bỏ lỡ nhiều câu khác.

### Dùng Microsoft Learn trong kỳ thi

Microsoft cho phép truy cập nội dung trong domain `learn.microsoft.com` ở các role-based exam, nhưng:

- đồng hồ thi vẫn chạy;
- không được cộng thêm thời gian;
- một số khu vực như Q&A, Practice Assessment và profile không truy cập được;
- Learn phù hợp để kiểm tra chi tiết hiếm, không phải để tìm đáp án cho mọi câu.

Hãy luyện trước việc tìm nhanh bằng tên function/object và `Ctrl+F` trên trang docs.

### Tính điểm và xử lý câu chưa chắc chắn

- Technical exam dùng scaled score 1–1000; **700** là điểm đạt nhưng không phải 70% câu đúng.
- Câu nhiều phần thường có thể nhận điểm theo từng phần đúng nếu đề ghi nhận multi-point.
- Không bị trừ điểm vì chọn sai, vì vậy hãy trả lời mọi câu.
- Có thể có câu không được tính điểm; bạn không biết câu nào, nên xử lý mọi câu như câu có điểm.

### Nghỉ giữa giờ

Nếu dùng unscheduled break, đồng hồ vẫn chạy và bạn không thể quay lại các câu đã xem trước break. Chỉ bấm break sau khi đã trả lời/review xong phần hiện tại.

---

## 10. Ưu tiên cá nhân từ báo cáo điểm đang ghi trong bộ tài liệu

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

## 12. Nguồn Microsoft chính thức nên lưu lại

### Blueprint, chứng chỉ và trải nghiệm thi

- [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
- [Microsoft Certified: SQL AI Developer Associate](https://learn.microsoft.com/en-us/credentials/certifications/developing-ai-enabled-database-solutions/)
- [Course DP-800T00-A](https://learn.microsoft.com/en-us/training/courses/dp-800t00)
- [Exam scoring and score reports](https://learn.microsoft.com/en-us/credentials/certifications/exam-scoring-reports)
- [Exam duration and exam experience](https://learn.microsoft.com/en-us/credentials/support/exam-duration-exam-experience)
- [Microsoft Certification Exam Sandbox](https://aka.ms/examdemo)

### Ba lộ trình Microsoft Learn bám sát phạm vi thi

- [Domain 1 — Design and develop database solutions](https://learn.microsoft.com/en-us/training/paths/design-develop-database-solutions/)
- [Domain 2 — Secure, optimize, and deploy database solutions](https://learn.microsoft.com/en-us/training/paths/secure-optimize-deploy-database-solutions/)
- [Domain 3 — Implement AI capabilities in database solutions](https://learn.microsoft.com/en-us/training/paths/implement-ai-capabilities-database-solutions/)

### Ba PDF có sẵn trong workspace — nguồn bổ trợ

- [DP-800ExamRequirements260515.pdf](../DP-800ExamRequirements260515.pdf): snapshot 3 trang của 73 bullet; tiện kiểm tra nhanh phạm vi nhưng Study Guide online vẫn là nguồn quyết định khi có thay đổi.
- [DP-800Notes260612.pdf](../DP-800Notes260612.pdf): 164 trang ghi chú theo các mục tiêu 1–73; dùng để ôn lại và đối chiếu ví dụ.
- [DP-800CodeUsed260610.pdf](../DP-800CodeUsed260610.pdf): 80 trang code mẫu; dùng làm bài thực hành bổ sung, không copy thẳng vào production.

Hai PDF Notes/Code là tài liệu bên thứ ba trong workspace, không phải Microsoft Learn. Nếu nội dung hoặc syntax trong PDF khác tài liệu Microsoft đúng platform/version, ưu tiên Microsoft và ghi lại sai lệch vào error log.

### Tài liệu nền tảng

- [Microsoft SQL documentation](https://learn.microsoft.com/en-us/sql/)
- [Azure SQL documentation](https://learn.microsoft.com/en-us/azure/azure-sql/)
- [SQL database in Microsoft Fabric](https://learn.microsoft.com/en-us/fabric/database/sql/overview)
- [Data API builder documentation](https://learn.microsoft.com/en-us/azure/data-api-builder/)
- [SQL Database Projects documentation](https://learn.microsoft.com/en-us/sql/tools/sql-database-projects/sql-database-projects?view=sql-server-ver17)
- [GitHub Copilot in SQL Server Management Studio](https://learn.microsoft.com/en-us/ssms/github-copilot/overview)
- [Microsoft SQL MCP Server](https://learn.microsoft.com/en-us/sql/mcp/)

---

## 13. Danh sách cần kiểm tra lại trước ngày thi

- [ ] Study Guide vẫn ghi **Skills measured as of March 12, 2026**; nếu không, lập diff với 73 bullet trong roadmap này.
- [ ] Trang chứng chỉ vẫn ghi cùng ba domain và thời lượng thi hiện hành.
- [ ] Link trong từng file chuyên đề còn hoạt động và đúng `view`/platform.
- [ ] Các feature có nhãn Preview/GA trong file vẫn đúng.
- [ ] Các package/API/config format mới không làm ví dụ cũ mất hiệu lực.
- [ ] Practice Assessment và Exam Sandbox đã được thực hành ít nhất một lần.
- [ ] Error log không còn lỗi lặp lại ở cùng một concept.

**Definition of Done cuối cùng:** bạn không chỉ “đã đọc hết”, mà có thể **nhận diện → chọn → triển khai → chẩn đoán → giải thích vì sao phương án khác sai** trên toàn bộ 11 skill group.
