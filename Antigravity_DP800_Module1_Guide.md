# CẨM NANG CHUYÊN SÂU ÔN THI DP-800: DESIGN & DEVELOP DATABASE SOLUTIONS (35–40%)
> **Tác giả:** Expert Database Solutions Architect (10+ năm kinh nghiệm Microsoft SQL Server & Azure Data Platform)  
> **Kỳ thi:** DP-800: Developing AI-Enabled Database Solutions (Cập nhật mới nhất từ tháng 03/2026)  
> **File đính kèm:**  
> - 📄 [Antigravity_DP800_Database_Objects.sql](file:///d:/SQL/DP-800%20Microsoft%20SQL%20Server%20AI%20Developer/Antigravity_DP800_Database_Objects.sql)  
> - 📄 [Antigravity_DP800_Programmability_and_Advanced_TSQL.sql](file:///d:/SQL/DP-800%20Microsoft%20SQL%20Server%20AI%20Developer/Antigravity_DP800_Programmability_and_Advanced_TSQL.sql)

---

## 📌 TỔNG QUAN VỀ MIỀN KỸ NĂNG NÀY (35–40%)

Miền kiến thức **"Design and develop database solutions"** chiếm tỷ trọng lớn nhất trong đề thi **DP-800** (35–40%). Đây là phần quyết định trực tiếp tới điểm số của bạn. Kỳ thi DP-800 không chỉ kiểm tra lý thuyết T-SQL cơ bản mà tập trung sâu vào:
1. **Kiến trúc lưu trữ nâng cao:** Columnstore Indexing, Partitioning, In-Memory OLTP, Temporal Tables, Ledger Tables, và Đồ thị (Graph Database).
2. **Lập trình T-SQL hiện đại & Tối ưu hóa:** Native JSON, Regular Expressions (`REGEXP_*`), Fuzzy Matching (`EDIT_DISTANCE`), Window Functions, và xử lý lỗi chuẩn Enterprise.
3. **Phát triển cơ sở dữ liệu hỗ trợ AI (AI-Enabled & MCP):** Tích hợp AI Tooling, Model Context Protocol (MCP) server endpoints, Copilot Instruction files, và Bảo mật AI.

---

## 📖 CHUYÊN ĐỀ 1: DESIGN AND IMPLEMENT DATABASE OBJECTS

### 1. Bảng, Chỉ Mục & Columnstore Indexing
* **Rowstore B-Tree Index:**
  * **Clustered Index (CI):** Sắp xếp dữ liệu vật lý trên đĩa theo khóa chỉ mục. Mỗi bảng chỉ có duy nhất 1 Clustered Index.
  * **Nonclustered Index (NCI):** Cấu trúc cây B-Tree riêng biệt chứa các cột chỉ mục và bookmark (RID hoặc Clustered Key) trỏ về dòng dữ liệu gốc.
  * **Covering Index (`INCLUDE`):** Đưa thêm các cột chỉ phụ vào mức lá (leaf level) của NCI để phục vụ câu truy vấn mà không cần Lookup lại Clustered Index (Bookmark Lookup Penalty).
* **Columnstore Index (Nén dữ liệu theo cột - Compressed Columnar Format):**
  * **Clustered Columnstore Index (CCI):** Nén toàn bộ bảng thành từng `Rowgroup` (~1 triệu dòng/rowgroup) và lưu theo từng cột (`Column segment`). Thích hợp cho **Data Warehouse / OLAP** chạy truy vấn tổng hợp (`SUM`, `AVG`, `COUNT`).
  * **Nonclustered Columnstore Index (NCCI):** Tạo một Columnstore index phụ trên một bảng Rowstore đang chạy OLTP. Đây là giải pháp **Operational Analytics (HTAP)** giúp chạy báo cáo thời gian thực trực tiếp trên OLTP mà không gây khóa bảng.

> 💡 **Bẫy thi DP-800:**
> - Nếu câu hỏi yêu cầu tối ưu cho báo cáo tổng hợp trên bảng OLTP đang chạy liên tục mà **không muốn chuyển dữ liệu sang Data Warehouse**, câu trả lời đúng luôn là: **Tạo Nonclustered Columnstore Index (NCCI)**.
> - Nếu bảng nhỏ dưới 100.000 dòng, không nên dùng Columnstore vì hiệu năng nén và Batch Mode không phát huy hiệu quả bằng B-Tree.

---

### 2. Các Bảng Chuyên Biệt (Specialized Tables)

| Loại bảng | Đặc điểm kiến trúc | Trường hợp sử dụng tiêu biểu | Lưu ý quan trọng khi thi |
| :--- | :--- | :--- | :--- |
| **Temporal Tables** *(System-Versioned)* | Tự động tạo thêm một bảng History để ghi lại toàn bộ lịch sử `UPDATE` / `DELETE`. | Truy vấn lịch sử thay đổi (Audit), Point-in-time analysis (`FOR SYSTEM_TIME AS OF`). | Yêu cầu phải có Primary Key và 2 cột `DATETIME2` định nghĩa `GENERATED ALWAYS AS ROW START/END`. |
| **In-Memory OLTP** *(Memory-Optimized)* | Lưu toàn bộ bảng trong RAM, dùng cấu trúc dữ liệu Lock-free/Latch-free. | Hệ thống giao dịch tần suất cực cao (High throughput / Low latency transactions). | Phải định nghĩa `DURABILITY = SCHEMA_AND_DATA` (hoặc `SCHEMA_ONLY`). Cần tính toán `BUCKET_COUNT` cho HASH index. |
| **Ledger Tables** | Dùng thuật toán mã hóa SHA-256 + Merkle Tree để đảm bảo dữ liệu chống sửa đổi/gian lận. | Sổ cái tài chính, Ngân hàng, Chuỗi cung ứng, Hệ thống tuân thủ pháp lý. | Phân biệt **Updatable Ledger Table** (cho phép Update/Delete nhưng lưu vết Ledger) và **Append-Only Ledger Table** (chỉ cho phép Insert). |
| **Graph Tables** | Gồm **NODE Table** (đối tượng) và **EDGE Table** (mối quan hệ giữa các Node). | Mạng xã hội, Hệ thống gợi ý sản phẩm, Phát hiện gian lận phức tạp. | Truy vấn mối quan hệ bằng toán tử `MATCH(Person-(Likes)->Product)`. |
| **External Tables** | Sử dụng PolyBase hoặc Azure Storage connectors để truy vấn file dữ liệu trực tiếp trên Data Lake/Blob. | Data Lakehouse, Query S3/ADLS Gen2 parquet/csv mà không cần Import vào SQL. | Không hỗ trợ chỉ mục B-Tree truyền thống trên External Table. |

---

### 3. Native JSON & JSON Indexing
SQL Server 2024 và Azure SQL Database đã hỗ trợ kiểu dữ liệu native `JSON`:
* **Lưu trữ & Ràng buộc:** Với kiểu dữ liệu `NVARCHAR(MAX)`, cần có ràng buộc `CHECK (ISJSON(col) = 1)`.
* **Đánh chỉ mục cho JSON:**
  * SQL không tạo trực tiếp B-Tree Index trên toàn bộ cột JSON MAX.
  * **Giải pháp chuẩn:** Tạo **Computed Column** dựa trên `JSON_VALUE(JSONCol, '$.path')` với từ khóa `PERSISTED`, sau đó tạo **Nonclustered B-Tree Index** trên Computed Column này.

---

### 4. Constraints & SEQUENCES
* **Constraints:** `PRIMARY KEY` (chỉ 1), `FOREIGN KEY` (toàn vẹn tham chiếu), `UNIQUE` (cho phép 1 giá trị NULL), `CHECK` (ràng buộc logic), `DEFAULT` (giá trị mặc định).
* **SEQUENCE vs IDENTITY:**
  * `IDENTITY`: Gắn liền với 1 bảng cụ thể. Khó lấy trước giá trị trước khi `INSERT` nếu chưa thực thi.
  * `SEQUENCE`: Một đối tượng độc lập trong Database schema. Có thể dùng `NEXT VALUE FOR SeqName` để cấp phát số thứ tự dùng chung cho **nhiều bảng khác nhau**, hoặc lấy số thứ tự trước khi ghi dữ liệu.

---

### 5. Table & Index Partitioning (Phân Vùng Bảng)
* **Quy trình 3 bước thiết lập Phân vùng:**
  1. **Partition Function:** Định nghĩa giá trị ranh giới (Boundary values) và kiểu dữ liệu phân vùng (`RANGE LEFT` hoặc `RANGE RIGHT`).
  2. **Partition Scheme:** Ánh xạ các partition được tạo bởi Function vào các Filegroup lưu trữ vật lý.
  3. **Partitioned Table/Index:** Tạo bảng hoặc index đặt trên Partition Scheme theo cột phân vùng (Partition Key).
* **Kỹ thuật Sliding Window Pattern (`SWITCH PARTITION`):**
  * Chuyển một partition dữ liệu cũ sang bảng Archive chỉ mất **0 giây** (Metadata operation), hoàn toàn tránh được việc dùng câu lệnh `DELETE` làm phình Transaction Log và gây lock bảng.

---

## 🛠️ CHUYÊN ĐỀ 2: IMPLEMENT PROGRAMMABILITY OBJECTS

### 1. Views & Indexed Views (Materialized Views)
* **Standard View:** Chỉ lưu câu lệnh `SELECT` dưới dạng metadata, không lưu dữ liệu vật lý.
* **Indexed View (Materialized View):**
  * Lưu kết quả tính toán vật lý lên đĩa. Khi dữ liệu ở bảng gốc thay đổi, Indexed View tự động cập nhật.
  * **Điều kiện bắt buộc trong đề thi DP-800:**
    1. Câu lệnh `CREATE VIEW` phải có từ khóa `WITH SCHEMABINDING`.
    2. Các bảng tham chiếu phải viết dưới dạng `schema.object` (VD: `dbo.SalesOrderHeader`).
    3. Chỉ mục đầu tiên phải là **`UNIQUE CLUSTERED INDEX`**.
    4. Nếu có hàm tổng hợp `GROUP BY`, phải sử dụng `COUNT_BIG(*)` thay cho `COUNT(*)`.

---

### 2. Scalar Functions vs Table-Valued Functions (TVFs)
* **Scalar UDF (Hàm trả về giá trị đơn):** Tránh dùng trong các câu `SELECT` có số lượng dòng lớn vì gây ra hiện tượng **RBAR (Row-By-Agonizing-Row)**, cản trở Query Optimizer song song hóa (Parallelism).
* **Inline Table-Valued Function (iTVF):** Trả về kiểu `TABLE` bằng một câu lệnh `RETURN (SELECT ...)`. Query Optimizer sẽ chèn trực tiếp logic của iTVF vào Execution Plan chính (Inlining), giúp đạt **hiệu năng tối đa**.
* **Multi-Statement TVF (MSTVF):** Khai báo bảng tạm `@ResultTable TABLE`, dùng nhiều câu lệnh để chèn dữ liệu. Thường gây ước lượng sai số dòng (Cardinality Misestimation) dẫn tới Execution Plan xấu. Tránh dùng nếu có thể chuyển thành iTVF.

---

### 3. Stored Procedures & Triggers
* **Stored Procedures:** Đã được biên dịch sẵn Execution Plan, hỗ trợ tham số `OUTPUT`, giao dịch `TRANSACTION`, và xử lý lỗi.
* **DML Triggers:**
  * `AFTER Trigger`: Chạy sau khi thao tác `INSERT/UPDATE/DELETE` và các ràng buộc đã thành công.
  * `INSTEAD OF Trigger`: Ghi đè lên thao tác `INSERT/UPDATE/DELETE`. Thường dùng để cập nhật dữ liệu thông qua các View phức tạp.
  * Sử dụng 2 bảng giả lập trong bộ nhớ: `inserted` (chứa dữ liệu mới/mới sửa) và `deleted` (chứa dữ liệu cũ/đã xóa).

---

## 💻 CHUYÊN ĐỀ 3: WRITE ADVANCED T-SQL CODE

### 1. Window Functions (Hàm Cửa Sổ)
* **Hàm xếp hạng:**
  * `ROW_NUMBER()`: Đánh số thứ tự liên tục (1, 2, 3, 4).
  * `RANK()`: Trùng giá trị thì đồng hạng, bỏ qua hạng kế tiếp (1, 2, 2, 4).
  * `DENSE_RANK()`: Trùng giá trị đồng hạng, KHÔNG bỏ qua hạng kế tiếp (1, 2, 2, 3).
* **Hàm di chuyển / So sánh:**
  * `LAG(col, offset)`: Lấy giá trị của dòng trước đó trong phân vùng.
  * `LEAD(col, offset)`: Lấy giá trị của dòng kế tiếp.
* **Khung cửa sổ (Window Frames):** `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` giúp tính tổng tích lũy (Running Total) cực kỳ tối ưu.

---

### 2. Các Hàm JSON Mới Trong T-SQL (DP-800 Core Feature)
Đề thi DP-800 xoáy sâu vào các hàm JSON thế hệ mới:
* `JSON_OBJECT('key': value, ...)`: Tạo đối tượng JSON từ các cặp Key-Value.
* `JSON_ARRAY(val1, val2, ...)`: Tạo mảng JSON.
* `JSON_ARRAYAGG(expression)`: Hàm tổng hợp (Aggregate) gom nhiều dòng dữ liệu quan hệ thành 1 mảng JSON.
* `OPENJSON(json_string) WITH (...)`: Bóc tách chuỗi JSON thành các dòng và cột trong cơ sở dữ liệu quan hệ.
* `JSON_CONTAINS(json_string, path_or_value)`: Kiểm tra sự tồn tại của phần tử trong chuỗi JSON.

---

### 3. Biểu Thức Chính Quy (Regular Expressions - `REGEXP_*`)
Từ phiên bản 2026/Azure SQL, SQL Server đã hỗ trợ các hàm Regex nguyên bản:
* `REGEXP_LIKE(source, pattern)`: Kiểm tra chuỗi có khớp pattern không (Trả về 1/0).
* `REGEXP_REPLACE(source, pattern, replacement)`: Thay thế chuỗi khớp regex.
* `REGEXP_SUBSTR(source, pattern)`: Trích xuất chuỗi con theo regex.
* `REGEXP_COUNT(source, pattern)`: Đếm số lần xuất hiện của regex.
* `REGEXP_SPLIT_TO_TABLE(source, pattern)`: Tách chuỗi thành bảng dữ liệu dựa theo dấu phân cách regex.

---

### 4. Tìm Kiếm Chuỗi Mờ (Fuzzy String Matching)
Nhóm hàm giải quyết bài toán khớp chuỗi không chính xác / trùng lặp mờ:
* `EDIT_DISTANCE(str1, str2)`: Khoảng cách Levenshtein (Số phép thêm/bớt/sửa ký tự).
* `EDIT_DISTANCE_SIMILARITY(str1, str2)`: Tỷ lệ tương đồng từ `0.00` (khác hoàn toàn) đến `1.00` (giống 100%).
* `JARO_WINKLER_DISTANCE(str1, str2)`: Thuật toán so sánh tên người/địa danh ưu tiên các ký tự tiền tố giống nhau.

---

### 5. Truy Vấn Đồ Thị Với Toán Tử `MATCH`
* Trong câu lệnh `SELECT`, kết nối Node và Edge thông qua mệnh đề `WHERE MATCH(...)`:
  ```sql
  SELECT Person.Name, Product.ProductName
  FROM PersonNode Person, LikesEdge Likes, ProductNode Product
  WHERE MATCH(Person-(Likes)->Product);
  ```
* Hỗ trợ tìm đường đi ngắn nhất bằng `SHORTEST_PATH`.

---

### 6. Xử Lý Lỗi & Quản Lý Giao Dịch Chuẩn Enterprise
* **Mô hình chuẩn xử lý lỗi:**
  ```sql
  SET NOCOUNT ON;
  SET XACT_ABORT ON; -- Đảm bảo Rollback ngay lập tức khi xảy ra lỗi Uncommittable
  
  BEGIN TRY
      BEGIN TRANSACTION;
      -- Các câu lệnh T-SQL
      COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH
      IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
      THROW; -- Re-throw lỗi nguyên bản giữ nguyên Stack Trace
  END CATCH
  ```

---

## 🤖 CHUYÊN ĐỀ 4: AI-ASSISTED SQL DEVELOPMENT & MCP ENDPOINTS

Kỳ thi DP-800 kiểm tra kiến thức thực tế về việc áp dụng AI Tools để phát triển SQL:

### 1. Model Context Protocol (MCP) Server Endpoints
* **Khái niệm MCP:** Giao thức chuẩn hóa giúp các mô hình AI (GitHub Copilot, Fabric Copilot) kết nối trực tiếp tới context của SQL Server, Fabric Lakehouse, và Metadata Schema mà không lộ dữ liệu thô.
* **Cấu hình MCP Endpoints:** Kết nối tới SQL Server endpoint để AI có thể tự động đọc DDL, Index statistics, và Execution Plans nhằm đưa ra gợi ý tối ưu chính xác.

### 2. GitHub Copilot Instruction Files
* **Tệp `.github/copilot-instructions.md`:** Tệp cấu hình đặt trong thư mục gốc của SQL Project nhằm định hướng phong cách viết code T-SQL cho AI (VD: "Mọi Stored Procedure phải có `SET XACT_ABORT ON` và dùng `DATETIME2`").

---

## 🎯 BẢNG TÓM TẮT THỦ THUẬT LÀM BÀI THI DP-800

1. **Khi nào chọn Columnstore Index?**
   - Cần chạy báo cáo OLAP trên bảng >1 triệu dòng ➡️ **Clustered Columnstore Index**.
   - Cần chạy báo cáo OLAP trên bảng OLTP realtime mà không làm chậm OLTP ➡️ **Nonclustered Columnstore Index**.
2. **Khi nào chọn Temporal vs Ledger?**
   - Cần xem dữ liệu cũ tại thời điểm quá khứ ➡️ **Temporal Table**.
   - Cần bảo đảm dữ liệu không bị ai sửa lén (Tamper-proof/Financial Audit) ➡️ **Ledger Table**.
3. **Khi nào chọn Inline TVF vs Scalar UDF?**
   - Luôn ưu tiên **Inline TVF (`RETURNS TABLE AS RETURN SELECT...`)** vì hiệu năng vượt trội nhờ khả năng Query Inlining.
4. **Xử lý Regex & Fuzzy Matching trong T-SQL:**
   - Dùng `REGEXP_LIKE` cho kiểm tra định dạng (Email, Phone, CCCD).
   - Dùng `EDIT_DISTANCE_SIMILARITY` cho bài toán loại bỏ dữ liệu trùng lặp mờ (Deduplication).

---
*Chúc bạn ôn tập tốt và đạt kết quả tối đa trong kỳ thi DP-800!*
