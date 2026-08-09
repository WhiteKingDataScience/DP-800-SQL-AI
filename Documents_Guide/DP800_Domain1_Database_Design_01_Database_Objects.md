# DP-800 Domain 1: Design and Implement Database Objects

> **Miền 1:** Design and Develop Database Solutions (35–40%)  
> **Chủ đề:** Design and Implement Database Objects  
> **Trọng tâm thi (Score Weak Point #3):** Columnstore Indexes, Specialized Tables (Ledger/Temporal/Memory-Optimized/Graph/External), JSON Columns/Indexes, Partitioning.

---

## 📘 PHẦN 1: LÝ THUYẾT & KIẾN THỨC CỐT LÕI (CORE THEORY)

### 1. Thiết Kế Bảng & Kiểu Dữ Liệu (Tables & Data Types)
- **Thiết kế tối ưu dung lượng (Storage Efficiency):** Chọn kiểu dữ liệu nhỏ nhất đáp ứng đủ yêu cầu (`TINYINT` 1 byte, `SMALLINT` 2 bytes, `INT` 4 bytes, `BIGINT` 8 bytes; `VARCHAR` vs `NVARCHAR`).
- **Computed Columns & Sparse Columns:**
  - *Persisted Computed Column:* Cột tính toán có từ khóa `PERSISTED` giúp lưu trực tiếp kết quả vào đĩa, cho phép đánh chỉ mục (index).
  - *Sparse Columns:* Tối ưu dung lượng cho bảng có nhiều cột nhưng đa số chứa giá trị `NULL` (tiết kiệm đến 20-40% dung lượng đĩa).

### 2. Chỉ Mục Tối Ưu Hiệu Năng (B-Tree & Columnstore Indexes)
- **B-Tree Indexes (Clustered & Nonclustered):**
  - *Clustered Index:* Quyết định thứ tự vật lý của dữ liệu trên đĩa (Mỗi bảng chỉ có duy nhất 1 Clustered Index).
  - *Nonclustered Index with INCLUDE:* Thêm các cột không thuộc khóa vào mệnh đề `INCLUDE` để tạo **Covering Index**, tránh tra cứu lại bảng chính (Bookmark Lookup / Key Lookup).
  - *Filtered Index:* Chỉ đánh chỉ mục trên các dòng thỏa điều kiện `WHERE` (ví dụ: `WHERE IsActive = 1` hoặc `WHERE DeletedDate IS NULL`). Giảm kích thước index và chi phí bảo trì.
- **Columnstore Indexes (CCI & NCCI):**
  - *Clustered Columnstore Index (CCI):* Lưu trữ dữ liệu dạng cột (Columnar Storage), nén dữ liệu cực cao (10x), phù hợp cho Data Warehouse, OLAP và truy vấn tổng hợp (`SUM`, `AVG`, `GROUP BY`).
  - *Nonclustered Columnstore Index (NCCI):* Đánh trên bảng OLTP (B-Tree) để hỗ trợ phân tích thời gian thực (HTAP - Hybrid Transactional/Analytical Processing).
  - *Rowgroup & Delta Store:* Dữ liệu lưu thành từng Rowgroup (~1 triệu dòng/rowgroup). Dữ liệu chèn mới chưa nén được lưu tạm trong **Delta Store** (dạng B-Tree) trước khi được **Tuple Mover** nén đưa vào Columnstore.
  - *Ordered CCI (SQL Server 2022+ / Fabric):* Sắp xếp dữ liệu theo thứ tự cột khoá giúp loại bỏ Segment (Segment Elimination) cực kỳ hiệu quả.

### 3. Các Loại Bảng Chuyên Biệt (Specialized Tables)
- **In-Memory OLTP (Memory-Optimized Tables):**
  - Dữ liệu lưu hoàn toàn trên RAM, không bị tranh chấp khóa (Lock/Latch-free).
  - Phù hợp cho hệ thống giao dịch tần suất cực cao (High throughput, Low latency OLTP).
- **Temporal Tables (System-Versioned Tables):**
  - Tự động ghi lại lịch sử thay đổi của dữ liệu theo thời gian (chứa 2 cột `SYSSTART` và `SYSEND`).
  - Truy vấn dữ liệu tại một thời điểm trong quá khứ bằng cú pháp `FOR SYSTEM_TIME AS OF <datetime>`.
- **Ledger Tables (SQL Server 2022+ / Azure SQL):**
  - Bảng chống sửa đổi (Tamper-evident) sử dụng công nghệ mã hóa Hash-chain (tương tự Blockchain).
  - Phù hợp cho yêu cầu kiểm toán ngân hàng, tài chính, tuân thủ pháp lý strict.
- **Graph Tables (Node & Edge Tables):**
  - Biểu diễn quan hệ nhiều-nhiều phức tạp bằng `NODE` (thực thể) và `EDGE` (mối quan hệ).
  - Truy vấn đường đi phức tạp bằng hàm `MATCH()`.
- **External Tables (PolyBase / Azure Storage):**
  - Truy vấn dữ liệu trực tiếp từ các nguồn bên ngoài (Azure Blob Storage, Data Lake Gen2, AWS S3) mà không cần nạp dữ liệu vào SQL Server.

### 4. Cột Dữ Liệu JSON & JSON Indexes
- SQL Server hỗ trợ lưu trữ JSON dưới dạng `NVARCHAR(MAX)` hoặc kiểu dữ liệu native `JSON` (SQL Server 2025+).
- **Đánh chỉ mục JSON (JSON Indexing):** Không có chỉ mục JSON trực tiếp; thay vào đó, ta tạo một **Computed Column** trích xuất thuộc tính JSON (dùng `JSON_VALUE`) và đánh B-Tree Index trên cột đó.

### 5. Constraints & SEQUENCES
- **Ràng buộc (Constraints):** `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `CHECK`, `DEFAULT`.
  - *Trusted vs Untrusted Constraint:* Khi bật lại FK với `WITH NOCHECK`, constraint trở thành Untrusted (Query Optimizer sẽ không dùng nó để tối ưu truy vấn). Cần dùng `WITH CHECK CHECK CONSTRAINT` để khôi phục trạng thái Trusted.
- **SEQUENCE vs IDENTITY:**
  - `IDENTITY` gắn liền với 1 bảng cụ thể.
  - `SEQUENCE` là đối tượng độc lập cấp Database, có thể dùng chung cho nhiều bảng và sinh trước giá trị mà không cần chèn dòng (`NEXT VALUE FOR OrderSeq`).

### 6. Phân Vùng Bảng & Chỉ Mục (Partitioning)
- Chia bảng lớn thành các phần nhỏ dựa trên cột phân vùng (Partition Key - thường là Ngày tháng).
- **Quy trình tạo Partition:** `Filegroup` ➔ `CREATE PARTITION FUNCTION` (khai báo ngưỡng `RANGE LEFT/RIGHT`) ➔ `CREATE PARTITION SCHEME` (ánh xạ sang Filegroup) ➔ `CREATE TABLE ... ON PartitionScheme(Key)`.
- **Partition Switching (`ALTER TABLE ... SWITCH TO ...`):** Di chuyển dữ liệu giữa các phân vùng мгновенно (Metadata-only operation, 0 giây downtime).

---

## 💻 PHẦN 2: THỰC HÀNH T-SQL (HANDS-ON LABS)

```sql
-- ============================================================================
-- LAB 1.1: TẠO BẢNG TỐI ƯU, COMPUTED COLUMNS & SEQUENCES
-- ============================================================================
USE tempdb;
GO

-- 1. Tạo Sequence độc lập
CREATE SEQUENCE dbo.OrderNumberSeq
    AS BIGINT
    START WITH 10001
    INCREMENT BY 1;
GO

-- 2. Tạo Bảng với Persisted Computed Column & CHECK Constraint
CREATE TABLE dbo.Orders (
    OrderId BIGINT NOT NULL DEFAULT (NEXT VALUE FOR dbo.OrderNumberSeq),
    CustomerId INT NOT NULL,
    OrderDate DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UnitPrice DECIMAL(18,2) NOT NULL,
    Quantity INT NOT NULL,
    -- Persisted Computed Column
    TotalAmount AS (UnitPrice * Quantity) PERSISTED,
    Status VARCHAR(20) NOT NULL,
    CONSTRAINT PK_Orders PRIMARY KEY (OrderId),
    CONSTRAINT CHK_Quantity CHECK (Quantity > 0)
);
GO

-- ============================================================================
-- LAB 1.2: CLUSTERED COLUMNSTORE INDEX & FILTERED INDEX
-- ============================================================================
-- 1. Filtered Index trên các đơn hàng Active
CREATE NONCLUSTERED INDEX IX_Orders_Active
ON dbo.Orders(CustomerId, OrderDate)
INCLUDE (TotalAmount)
WHERE Status = 'Completed';
GO

-- 2. Tạo Bảng Phân Tích với Clustered Columnstore Index (CCI)
CREATE TABLE dbo.FactSales (
    SalesId BIGINT NOT NULL,
    ProductKey INT NOT NULL,
    OrderDateKey INT NOT NULL,
    SalesAmount DECIMAL(18,2) NOT NULL
);

-- Bật Clustered Columnstore Index nén dữ liệu
CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactSales ON dbo.FactSales;
GO

-- ============================================================================
-- LAB 1.3: TEMPORAL TABLE & JSON COMPUTED INDEX
-- ============================================================================
-- 1. Tạo Temporal Table tự động lưu lịch sử
CREATE TABLE dbo.EmployeeSalary (
    EmployeeId INT NOT NULL PRIMARY KEY,
    EmpName NVARCHAR(100) NOT NULL,
    Salary DECIMAL(18,2) NOT NULL,
    SysStartTime DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL,
    SysEndTime DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (SysStartTime, SysEndTime)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.EmployeeSalaryHistory));
GO

-- 2. JSON Indexing qua Persisted Computed Column
CREATE TABLE dbo.CustomerProfiles (
    ProfileId INT IDENTITY PRIMARY KEY,
    RawAttributes NVARCHAR(MAX) NOT NULL,
    -- Bóc tách thuộc tính JSON để đánh Index
    Email AS JSON_VALUE(RawAttributes, '$.email') PERSISTED
);

CREATE UNIQUE NONCLUSTERED INDEX IX_CustomerProfiles_Email
ON dbo.CustomerProfiles(Email) WHERE Email IS NOT NULL;
GO

-- ============================================================================
-- LAB 1.4: PARTITION SWITCHING (METADATA-ONLY FAST DATA PURGE)
-- ============================================================================
-- 1. Partition Function & Scheme
CREATE PARTITION FUNCTION PF_OrderYear (INT)
AS RANGE RIGHT FOR VALUES (20240101, 20250101, 20260101);

CREATE PARTITION SCHEME PS_OrderYear
AS PARTITION PF_OrderYear ALL TO ([PRIMARY]);
GO
```

---

## 📝 PHẦN 3: CÂU HỎI THI THỬ & TÌNH HUỐNG (MOCK TEST QUESTIONS)

#### Question 1 (Columnstore Index Scenario):
**Scenario:** You are designing a data warehouse table `dbo.FactTransactions` containing 500 million rows. The table is primarily accessed by analytical queries that aggregate sales by region and date. Write operations occur in large nightly batches. Which index strategy provides the best compression and query performance?
- A. Create a Nonclustered B-Tree Index on Region and Date.
- B. Create a Clustered Columnstore Index on the table.
- C. Create a Unique Clustered B-Tree Index and multiple Filtered Indexes.
- D. Convert the table into an In-Memory Memory-Optimized Table.

**👉 Correct Answer: B**  
*Explanation (Giải thích):* Clustered Columnstore Index (CCI) là chuẩn tối ưu nhất cho bảng kho dữ liệu lớn (Analytics/DW) nhờ khả năng nén 10x và quét dữ liệu theo cột cực nhanh đối với các câu truy vấn tổng hợp (`SUM`, `AVG`, `GROUP BY`).

---

#### Question 2 (Constraint Trust State Scenario):
**Scenario:** A database administrator disabled a Foreign Key constraint `FK_Orders_Customers` during a bulk load operation. Afterwards, the DBA re-enabled the constraint using `ALTER TABLE dbo.Orders WITH NOCHECK CHECK CONSTRAINT FK_Orders_Customers`. During performance tuning, you notice the Query Optimizer is not using the constraint to simplify query join plans. What should you do to resolve this?
- A. Rebuild the Clustered Index on `dbo.Orders`.
- B. Execute `ALTER TABLE dbo.Orders WITH CHECK CHECK CONSTRAINT FK_Orders_Customers`.
- C. Drop and recreate the Primary Key on `dbo.Customers`.
- D. Convert the Foreign Key constraint into a Trigger.

**👉 Correct Answer: B**  
*Explanation (Giải thích):* Khi bật lại constraint bằng `WITH NOCHECK`, SQL Server đánh dấu constraint đó là **Untrusted** (không tin tưởng hoàn toàn dữ liệu cũ), khiến Query Optimizer bỏ qua nó khi tối ưu execution plan. Phải dùng `WITH CHECK CHECK CONSTRAINT` để SQL Server xác minh lại dữ liệu và đưa constraint về trạng thái **Trusted**.

---

#### Question 3 (JSON Indexing Scenario):
**Scenario:** You store product metadata in an `NVARCHAR(MAX)` column named `CustomAttributes` containing JSON documents. Queries frequently search for products by `SKU` inside the JSON structure: `WHERE JSON_VALUE(CustomAttributes, '$.sku') = 'ABC-123'`. Query performance is unacceptable due to full table scans. How can you index this JSON attribute efficiently?
- A. Create a Full-Text Index on the `CustomAttributes` column.
- B. Add a PERSISTED computed column defined as `JSON_VALUE(CustomAttributes, '$.sku')` and create a Nonclustered B-tree Index on it.
- C. Convert the table to a Graph Table.
- D. Create a Clustered Columnstore Index on `CustomAttributes`.

**👉 Correct Answer: B**  
*Explanation (Giải thích):* Trong SQL Server, cách tiêu chuẩn và tối ưu nhất để đánh chỉ mục một thuộc tính JSON là tạo một **PERSISTED Computed Column** dùng hàm `JSON_VALUE`, sau đó tạo B-Tree Index thông thường trên cột tính toán đó.
