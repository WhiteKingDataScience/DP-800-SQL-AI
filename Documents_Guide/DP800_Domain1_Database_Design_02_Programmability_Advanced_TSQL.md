# DP-800 Domain 1: Implement Programmability & Write Advanced T-SQL Code

> **Miền 1:** Design and Develop Database Solutions (35–40%)  
> **Chủ đề:** Implement Programmability Objects & Write Advanced T-SQL Code  
> **Cập nhật mới 2025/2026:** Native Regular Expressions (`REGEXP_*`), Fuzzy String Matching, Graph Queries (`MATCH`), Advanced JSON functions (`JSON_OBJECT`, `JSON_ARRAYAGG`).

---

## 📘 PHẦN 1: LÝ THUYẾT & KIẾN THỨC CỐT LÕI (CORE THEORY)

### 1. Đối Tượng Lập Trình (Programmability Objects)
- **Views & Indexed Views (Materialized Views):**
  - *Indexed View:* View được vật lý hóa kết quả lên đĩa bằng cách tạo một `UNIQUE CLUSTERED INDEX` đầu tiên. Yêu cầu định nghĩa View phải có `WITH SCHEMABINDING` và dùng tên hai phần (`dbo.TableName`).
  - *Gợi ý `NOEXPAND`:* Khi truy vấn Indexed View ở bản SQL Server Enterprise / Azure SQL, Query Optimizer tự động dùng index của View. Ở bản Standard Edition, bắt buộc phải dùng hint `WITH (NOEXPAND)` để Query Optimizer không rã View ra bảng gốc.
- **User-Defined Functions (UDFs):**
  - *Scalar UDF:* Trả về 1 giá trị đơn. Trước SQL Server 2019, Scalar UDF gây ảnh hưởng nặng tới hiệu năng (RBAR - Row-By-Agonizing-Row). Từ SQL Server 2019+ có tính năng **Scalar UDF Inlining** tự động chuyển UDF thành biểu thức inline.
  - *Inline Table-Valued Function (iTVF):* Trả về bảng bằng 1 câu lệnh `RETURN SELECT ...`. Query Optimizer đối xử iTVF như View, hiệu năng cực cao.
  - *Multi-Statement Table-Valued Function (mTVF):* Trả về biến bảng (`TABLE`), tốn tài nguyên `tempdb` và gây sai lệch thống kê (cardinality estimation). Luôn ưu tiên dùng **iTVF** thay cho **mTVF**.
- **Triggers (DML & DDL Triggers):**
  - *AFTER Trigger:* Chạy sau khi thao tác DML thành công.
  - *INSTEAD OF Trigger:* Chạy thay thế cho thao tác DML (thường dùng để cho phép `INSERT/UPDATE/DELETE` trên View phức tạp).
  - *Lưu ý quan trọng:* Lệnh `TRUNCATE TABLE` **KHÔNG** kích hoạt DML Trigger (`AFTER DELETE`).

### 2. T-SQL Nâng Cao & Các Hàm Chuỗi Mới (Advanced T-SQL & Regex 2025)
- **Window Functions (Hàm Cửa Sổ):**
  - `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()`, `NTILE()`.
  - `LAG()`, `LEAD()`, `FIRST_VALUE()`, `LAST_VALUE()`.
  - Khai báo khung cửa sổ: `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.
- **Hàm Chuỗi Chính Quy (Native Regular Expressions - REGEXP_*):**
  - `REGEXP_LIKE(String, Pattern)`: Trả về `1` (True) hoặc `0` (False). Rất tối ưu khi dùng trong `CHECK Constraint` hoặc `WHERE`.
  - `REGEXP_REPLACE(String, Pattern, Replacement)`: Thay thế chuỗi khớp regex.
  - `REGEXP_SUBSTR(String, Pattern)`: Trích xuất chuỗi con khớp regex.
  - `REGEXP_MATCHES(String, Pattern)`: Tìm các kết quả khớp.
  - `REGEXP_SPLIT_TO_TABLE(String, Pattern)`: Tách văn bản thành bảng các dòng dựa theo dấu phân cách Regex.
- **Hàm So Sánh Chuỗi Mờ (Fuzzy String Matching):**
  - `EDIT_DISTANCE(str1, str2)`: Đo số bước sửa đổi Levenshtein giữa 2 chuỗi.
  - `EDIT_DISTANCE_SIMILARITY(str1, str2)`: Trả về độ tương đồng dạng % (từ 0.0 đến 1.0).
  - `JARO_WINKLER_DISTANCE(str1, str2)`: Đo độ tương đồng phù hợp cho so sánh Tên người / Địa chỉ.
- **T-SQL JSON Functions:**
  - `JSON_OBJECT()`, `JSON_ARRAY()`, `JSON_ARRAYAGG()` (gộp các dòng thành mảng JSON).
  - `OPENJSON()`: Chuyển chuỗi JSON thành bảng quan hệ (Relational Rows).
- **Graph Queries (`MATCH` Operator):**
  - Truy vấn kết nối Node & Edge trong CSDL Đồ thị: `WHERE MATCH(Person-(Likes)->Restaurant)`.
- **Xử Lý Lỗi An Toàn (Error Handling & Transactions):**
  - Sử dụng `BEGIN TRY ... END TRY BEGIN CATCH ... END CATCH`.
  - Kiểm tra `XACT_STATE()`: Trả về `1` (Transaction commit được), `-1` (Transaction bị hỏng, phải `ROLLBACK`), `0` (Không có Transaction).
  - Dùng `THROW` để bắn lại lỗi chuẩn thay cho `RAISERROR`.

---

## 💻 PHẦN 2: THỰC HÀNH T-SQL (HANDS-ON LABS)

```sql
-- ============================================================================
-- LAB 2.1: REGEX NATIVE 2025 & FUZZY MATCHING (CẬP NHẬT MỚI DP-800)
-- ============================================================================
USE tempdb;
GO

-- 1. Sử dụng REGEXP_LIKE trong CHECK Constraint kiểm tra định dạng Email & Mã Thuế
CREATE TABLE dbo.Suppliers (
    SupplierId INT IDENTITY PRIMARY KEY,
    SupplierName NVARCHAR(100) NOT NULL,
    TaxCode VARCHAR(20) NOT NULL,
    Email VARCHAR(100) NOT NULL,
    -- Constraint Regex kiểm tra Mã thuế 10 chữ số
    CONSTRAINT CHK_TaxCode CHECK (REGEXP_LIKE(TaxCode, '^\d{10}$Count') = 1),
    -- Constraint Regex kiểm tra Email chuẩn
    CONSTRAINT CHK_Email CHECK (REGEXP_LIKE(Email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') = 1)
);
GO

-- 2. Thử nghiệm Fuzzy Matching so sánh tên gần đúng (Duplicate Detection)
SELECT 
    'Kien Bach' AS OriginalName,
    'Kien Bch' AS VariantName,
    EDIT_DISTANCE('Kien Bach', 'Kien Bch') AS EditDist,
    JARO_WINKLER_DISTANCE('Kien Bach', 'Kien Bch') AS JaroSimilarity;
GO

-- ============================================================================
-- LAB 2.2: WINDOW FUNCTIONS & RECURSIVE CTE
-- ============================================================================
-- 1. Lấy Top 1 Đơn hàng mới nhất của từng Khách hàng dùng DENSE_RANK()
WITH RankedSales AS (
    SELECT 
        OrderId, CustomerId, OrderDate, TotalAmount,
        DENSE_RANK() OVER (PARTITION BY CustomerId ORDER BY OrderDate DESC) AS RN
    FROM dbo.Orders
)
SELECT OrderId, CustomerId, OrderDate, TotalAmount
FROM RankedSales
WHERE RN = 1;
GO

-- ============================================================================
-- LAB 2.3: INDEXED VIEW VỚI SCHEMABINDING & NOEXPAND
-- ============================================================================
CREATE TABLE dbo.SalesDetail (
    DetailId INT IDENTITY PRIMARY KEY,
    ProductId INT NOT NULL,
    Quantity INT NOT NULL,
    LineTotal DECIMAL(18,2) NOT NULL
);
GO

-- Tạo Indexed View tính tổng doanh thu theo Sản phẩm
CREATE VIEW dbo.vw_ProductSalesSummary
WITH SCHEMABINDING
AS
SELECT 
    ProductId,
    SUM(Quantity) AS TotalQty,
    SUM(LineTotal) AS TotalRevenue,
    COUNT_BIG(*) AS TotalRows -- Bắt buộc có COUNT_BIG(*) nếu dùng GROUP BY trong Indexed View
FROM dbo.SalesDetail
GROUP BY ProductId;
GO

-- Vật lý hóa View lên đĩa bằng Clustered Index
CREATE UNIQUE CLUSTERED INDEX CIX_vw_ProductSalesSummary 
ON dbo.vw_ProductSalesSummary(ProductId);
GO

-- Truy vấn sử dụng Hint NOEXPAND để tối ưu hiệu năng tuyệt đối
SELECT ProductId, TotalRevenue 
FROM dbo.vw_ProductSalesSummary WITH (NOEXPAND)
WHERE ProductId = 101;
GO

-- ============================================================================
-- LAB 2.4: XỬ LÝ LỖI CHUẨN VỚI XACT_STATE() & THROW
-- ============================================================================
CREATE PROCEDURE dbo.sp_TransferFunds
    @FromAccount INT,
    @ToAccount INT,
    @Amount DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        UPDATE dbo.Accounts SET Balance = Balance - @Amount WHERE AccountId = @FromAccount;
        UPDATE dbo.Accounts SET Balance = Balance + @Amount WHERE AccountId = @ToAccount;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Kiểm tra nếu Giao dịch bị Uncommittable (-1)
        IF (XACT_STATE()) = -1
        BEGIN
            ROLLBACK TRANSACTION;
        END;
        
        -- Bắn lại lỗi ra ngoài cho Application
        THROW;
    END CATCH
END;
GO
```

---

## 📝 PHẦN 3: CÂU HỎI THI THỬ & TÌNH HUỐNG (MOCK TEST QUESTIONS)

#### Question 1 (Regex Check Constraint Scenario):
**Scenario:** You need to enforce data integrity on a table named `dbo.Customers`. The column `IdentityNumber` must only accept string values that consist of exactly 12 numeric digits (e.g., '123456789012'). Any insert or update operation with non-digit characters or wrong lengths must fail immediately at the database layer. What is the most efficient solution?
- A. Create an AFTER INSERT, UPDATE Trigger using `LIKE '%[0-9]%'`.
- B. Add a CHECK Constraint on the table using `REGEXP_LIKE(IdentityNumber, '^\d{12}$') = 1`.
- C. Create a Scalar User-Defined Function that iterates through each character with `CHARINDEX`.
- D. Apply Dynamic Data Masking using `partial(0, "XXXXXXXXXXXX", 0)`.

**👉 Correct Answer: B**  
*Explanation (Giải thích):* Hàm **`REGEXP_LIKE`** trong `CHECK Constraint` là phương pháp tối ưu nhất, chạy native trực tiếp tại SQL Engine để kiểm tra định dạng chính xác 12 chữ số (`^\d{12}$`), chặn ngay lập tức dữ liệu không hợp lệ mà không tốn chi phí gọi Trigger hay UDF RBAR.

---

#### Question 2 (Indexed View Query Hint Scenario):
**Scenario:** You created an Indexed View named `dbo.vw_MonthlyReport` on a SQL Server Standard Edition database. You write a query against the view `SELECT * FROM dbo.vw_MonthlyReport WHERE Year = 2026`. However, execution plans show that the query processor is expanding the view definition and reading from the base tables instead of using the materialized clustered index on the view. How can you force the query to use the view's index?
- A. Recompile the view using `WITH RECOMPILE`.
- B. Add the query hint `OPTION (RECOMPILE)`.
- C. Use the view hint `WITH (NOEXPAND)` in the `FROM` clause.
- D. Add `WITH SCHEMABINDING` to the outer query.

**👉 Correct Answer: C**  
*Explanation (Giải thích):* Trên bản SQL Server Standard Edition (hoặc khi muốn bảo đảm Query Optimizer luôn đọc trực tiếp từ Clustered Index của Indexed View mà không rã View thành các bảng gốc), bắt buộc phải sử dụng View hint **`WITH (NOEXPAND)`** trong mệnh đề `FROM`.

---

#### Question 3 (Transaction Error Handling Scenario):
**Scenario:** You are implementing a stored procedure that executes multiple DML statements inside a transaction. In the `CATCH` block, you need to check if the transaction is uncommittable and safe to roll back. Which function should you evaluate?
- A. `@@ERROR`
- B. `XACT_STATE()`
- C. `@@TRANCOUNT`
- D. `ERROR_NUMBER()`

**👉 Correct Answer: B**  
*Explanation (Giải thích):* Hàm **`XACT_STATE()`** trả về `-1` khi một giao dịch gặp lỗi nghiêm trọng và rơi vào trạng thái "Doomed / Uncommittable Transaction" (không thể commit), giúp code trong khối `CATCH` thực hiện `ROLLBACK TRANSACTION` an toàn và chính xác.
