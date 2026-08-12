# DP-800 — Phát triển giải pháp cơ sở dữ liệu hỗ trợ AI

> Bộ tài liệu học và thực hành cho chứng chỉ **Microsoft Certified: SQL AI Developer Associate — DP-800: Developing AI-Enabled Database Solutions**.

DP-800 dành cho người xây dựng giải pháp kết hợp **cơ sở dữ liệu SQL và AI**. Sau khi học, bạn cần biết cách thiết kế dữ liệu, viết T-SQL, bảo vệ và tối ưu cơ sở dữ liệu, triển khai thay đổi bằng CI/CD, tạo API từ dữ liệu SQL, tìm kiếm theo ngữ nghĩa và xây quy trình RAG để mô hình AI trả lời dựa trên dữ liệu riêng của doanh nghiệp.

Nội dung chính được viết bằng tiếng Việt. Tên lệnh T-SQL, tên sản phẩm và thuật ngữ bắt buộc phải nhận diện trong đề được giữ bằng tiếng Anh, nhưng được giải thích bằng tiếng Việt ở lần xuất hiện đầu tiên.

> **Trạng thái rà soát kỹ thuật:** 09/08/2026  
> **Cập nhật cách trình bày cho người mới:** 12/08/2026  
> **Blueprint đối chiếu:** Skills measured as of **March 12, 2026**  
> **Phạm vi:** 73 yêu cầu thuộc 11 nhóm kỹ năng, trên SQL Server, Azure SQL và SQL database in Microsoft Fabric.

> [!IMPORTANT]
> Bộ tài liệu đã phủ đủ phạm vi thi hiện hành, nhưng không tài liệu tĩnh nào có thể bảo đảm bạn trả lời được mọi câu hỏi. Hãy kết hợp đọc hiểu, tự viết lệnh, chạy bài thực hành, làm Practice Assessment và ghi lại các lỗi mình thường mắc.

## DP-800 dùng để làm gì trong thực tế?

Hãy hình dung một công ty muốn tạo trợ lý chăm sóc khách hàng dựa trên dữ liệu SQL. Hệ thống cần:

1. lưu đơn hàng và tài liệu đúng cấu trúc;
2. chỉ cho người dùng xem dữ liệu họ được phép xem;
3. tìm các đoạn tài liệu liên quan bằng từ khóa và ý nghĩa;
4. gửi đúng phần dữ liệu đã lọc cho mô hình ngôn ngữ;
5. trả về câu trả lời có căn cứ;
6. theo dõi hiệu năng và triển khai thay đổi an toàn.

Ba miền của DP-800 tương ứng với ba lớp công việc đó:

| Miền | Câu hỏi thực tế bạn phải trả lời |
|---|---|
| **1. Thiết kế và phát triển** | Dữ liệu lưu ở bảng nào? Chọn kiểu dữ liệu, chỉ mục và đối tượng T-SQL nào? |
| **2. Bảo mật, tối ưu và triển khai** | Ai được xem dữ liệu? Vì sao truy vấn chậm? Đưa thay đổi lên môi trường thật thế nào? |
| **3. Khả năng AI** | Biến văn bản thành vector, tìm theo ngữ nghĩa và xây RAG ra sao? |

## Bắt đầu nhanh

1. Đọc [Roadmap và ma trận 73 mục](<Documents_Guide/DP800_00_Exam_Roadmap_Overview.md>) để hiểu toàn bộ phạm vi và thứ tự học.
2. Nếu chưa vững SQL, học [00A — Nền tảng T-SQL](<Documents_Guide/DP800_00A_TSQL_Foundations_Prerequisites.md>) trước.
3. Học lần lượt ba miền trong [Documents_Guide](<Documents_Guide>): Miền 1 → Miền 2 → Miền 3.
4. Với mỗi nhóm kỹ năng, làm đủ bốn tầng: giải thích khái niệm → chọn giải pháp → viết lệnh/cấu hình → chẩn đoán lỗi.
5. Chỉ chạy lệnh trong cơ sở dữ liệu thực hành hoặc môi trường tạm; không dùng thông tin xác thực, endpoint hay dữ liệu của môi trường thật.
6. Trước ngày thi, mở lại [Study Guide DP-800](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800) và các liên kết Microsoft trong từng file để kiểm tra thay đổi.

## Blueprint và trọng số

| Miền kiến thức | Trọng số | Nhóm kỹ năng | Số yêu cầu |
|---|---:|---:|---:|
| 1. Thiết kế và phát triển giải pháp cơ sở dữ liệu | 35–40% | 4 | 24 |
| 2. Bảo mật, tối ưu và triển khai giải pháp cơ sở dữ liệu | 35–40% | 4 | 28 |
| 3. Triển khai khả năng AI trong giải pháp cơ sở dữ liệu | 25–30% | 3 | 21 |
| **Tổng** | — | **11** | **73** |

Đây là các khoảng phần trăm, không phải số câu cố định. Khi làm câu hỏi tình huống, luôn xác định nền tảng, phiên bản, trạng thái phát hành chính thức/xem trước, yêu cầu bảo mật/hiệu năng và các ràng buộc trước khi chọn đáp án.

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

`Documents_Guide` là giáo trình chính của kho tài liệu. `Claude_Guide`, các file `.sql` ở thư mục gốc và các PDF là nguồn thực hành/bổ trợ; nếu cú pháp hoặc trạng thái tính năng khác Microsoft Learn thì ưu tiên tài liệu Microsoft đúng nền tảng và phiên bản.

## Lộ trình học đề xuất

### Giai đoạn 0 — Nền tảng T-SQL

Học bảng/dòng/cột, khóa và ràng buộc, `SELECT`, `WHERE`, `JOIN`, `GROUP BY`, `HAVING`, `EXISTS`, các lệnh sửa dữ liệu, giao dịch, `TRY...CATCH`, `XACT_STATE()` và kiểu dữ liệu. Nếu là người mới, hãy hoàn thành toàn bộ bài thực hành trong [00A](<Documents_Guide/DP800_00A_TSQL_Foundations_Prerequisites.md>) trước khi chuyển tiếp.

### Miền 1 — Thiết kế và phát triển giải pháp cơ sở dữ liệu

- [01 — Thiết kế đối tượng cơ sở dữ liệu](<Documents_Guide/DP800_Domain1_Database_Design_01_Database_Objects.md>): bảng, chỉ mục, columnstore, temporal, graph, JSON, phân vùng và các loại bảng chuyên biệt.
- [02 — Lập trình và T-SQL nâng cao](<Documents_Guide/DP800_Domain1_Database_Design_02_Programmability_Advanced_TSQL.md>): view, hàm, stored procedure, trigger, CTE, hàm cửa sổ, JSON, biểu thức chính quy, so khớp gần đúng, truy vấn đồ thị và xử lý lỗi.
- [03 — Công cụ hỗ trợ AI](<Documents_Guide/DP800_Domain1_Database_Design_03_AIAssisted_Tools.md>): Copilot, Fabric Copilot, chế độ Agent trong SSMS, MCP, SQL MCP Server và ranh giới bảo mật.

### Miền 2 — Bảo mật, tối ưu và triển khai giải pháp cơ sở dữ liệu

- [04 — Bảo mật dữ liệu và tuân thủ](<Documents_Guide/DP800_Domain2_Security_Optimization_04_Data_Security_Compliance.md>): mã hóa, Always Encrypted, DDM, RLS, phân quyền, kiểm toán, Managed Identity và bảo mật endpoint.
- [05 — Tối ưu hiệu năng](<Documents_Guide/DP800_Domain2_Security_Optimization_05_Performance_Optimization.md>): cấu hình, cô lập/truy cập đồng thời, kế hoạch thực thi, DMV, Query Store, chặn lẫn nhau và bế tắc.
- [06 — CI/CD và SQL Database Projects](<Documents_Guide/DP800_Domain2_Security_Optimization_06_CICD_SQL_Projects.md>): SQL project, mô hình kiểu SDK, kiểm thử, Git, quản lý bí mật, phát hiện sai lệch, DACPAC và các điểm kiểm soát triển khai.
- [07 — Tích hợp dịch vụ Azure](<Documents_Guide/DP800_Domain2_Security_Optimization_07_Azure_Services_Integration.md>): Data API Builder 2.0, REST/GraphQL, bộ nhớ đệm, phân trang, giám sát, CT/CDC/Azure Functions và CES.

### Miền 3 — Triển khai khả năng AI trong giải pháp cơ sở dữ liệu

- [08 — Model và embedding](<Documents_Guide/DP800_Domain3_AI_Capabilities_08_Models_Embeddings.md>): model bên ngoài, chia đoạn, embedding, chiến lược cập nhật, ONNX Preview và CES.
- [09 — Tìm kiếm thông minh](<Documents_Guide/DP800_Domain3_AI_Capabilities_09_Intelligent_Search.md>): tìm kiếm toàn văn, kiểu vector, DiskANN, tìm kiếm chính xác/xấp xỉ, tìm kiếm kết hợp, RRF và chẩn đoán lỗi.
- [10 — Quy trình RAG](<Documents_Guide/DP800_Domain3_AI_Capabilities_10_RAG_Pipeline.md>): prompt, JSON có cấu trúc, REST endpoint bên ngoài, phân quyền, thử lại và trích xuất phản hồi an toàn.

## Môi trường và điều kiện cần có

- **Cơ sở dữ liệu:** SQL Server Developer 2022/2025 cho bài thực hành T-SQL ổn định; Azure SQL Database hoặc SQL database in Fabric cho các tính năng đám mây/AI tương ứng.
- **Công cụ:** SSMS phiên bản hiện hành; VS Code và Git hữu ích cho SQL Database Projects, Copilot và MCP.
- **Azure/Fabric:** chỉ cần khi bài thực hành yêu cầu; một số tính năng cần năng lực Fabric trả phí, Managed Identity, Azure Event Hubs, Azure OpenAI/Foundry hoặc REST endpoint.
- **Kiến thức nền:** nếu chưa biết SQL, bắt đầu từ file 00A; nếu đã biết SQL nhưng chưa biết cơ sở dữ liệu tích hợp AI, có thể bắt đầu từ Miền 1.

Không suy luận rằng một câu lệnh chạy giống nhau trên SQL Server, Azure SQL và Fabric. Luôn đọc phần **Applies to** (áp dụng cho), điều kiện cần có, mức tương thích và nhãn **Preview/GA** (xem trước/phát hành chính thức) trong tài liệu Microsoft.

## Quy tắc chạy bài thực hành an toàn

- Dùng cơ sở dữ liệu riêng, dữ liệu giả và tài khoản có quyền tối thiểu.
- Đọc toàn bộ đoạn lệnh trước khi chạy; kiểm tra kỹ các câu `DROP`, `ALTER`, `UPDATE`, `DELETE` và SQL động.
- Không đưa API key, mật khẩu, SAS token, chuỗi kết nối hoặc bí mật vào Git.
- Thay các chỗ mẫu như `<your-resource>`, `<credential>` và `<endpoint>` bằng giá trị trong môi trường thực hành; không dán bí mật thật vào Markdown.
- Các ví dụ AI/vector/RAG có thể cần nền tảng hoặc phiên bản cụ thể, nên một số đoạn chỉ có thể kiểm tra cú pháp nếu không có dịch vụ Azure/Fabric tương ứng.

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

## Tình trạng kiểm tra chất lượng

Rà soát kỹ thuật ngày 09/08/2026 và biên tập cách trình bày ngày 12/08/2026:

- 12 file Markdown trong `Documents_Guide` đều được mã hóa UTF-8 hợp lệ.
- Roadmap có đủ 73 ID liên tục, không thiếu hoặc trùng.
- 19/19 khối T-SQL trong file kiến thức đầu vào đã chạy thành công trong cơ sở dữ liệu kiểm thử tạm.
- 16/16 khối JSON hợp lệ.
- Các khối mã, liên kết nội bộ và kiểm tra định dạng đều đạt.

Đây là kiểm tra chất lượng tài liệu và bài thực hành mẫu; nó không thay thế việc tự chạy trên đúng nền tảng/phiên bản mà câu hỏi thi nêu.

## Giấy phép

Kho tài liệu hiện chưa có file `LICENSE`. Không nên tự suy đoán giấy phép sử dụng hoặc tái phân phối; hãy bổ sung giấy phép rõ ràng trước khi công khai.
