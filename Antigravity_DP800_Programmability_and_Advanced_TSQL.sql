-- ====================================================================================
-- BÀI TẬP VÀ VÍ DỤ THỰC HÀNH KỲ THI DP-800 (MICROSOFT CERTIFIED: AI-ENABLED DATABASE SOLUTIONS)
-- CHUYÊN ĐỀ 2: PROGRAMMABILITY OBJECTS & ADVANCED T-SQL
-- Tác giả: Microsoft Principal Database Solutions Architect
-- Tên file: Antigravity_DP800_Programmability_and_Advanced_TSQL.sql
-- ====================================================================================

USE DP800_Review_DB;
GO

-- ====================================================================================
-- PHẦN 1: PROGRAMMABILITY OBJECTS (VIEWS, FUNCTIONS, PROCEDURES, TRIGGERS)
-- ====================================================================================

/*
   MẸO THI DP-800:
   1. Indexed View (Materialized View): 
      - Bắt buộc phải có `WITH SCHEMABINDING`.
      - Mọi bảng được tham chiếu phải dùng kiểu 2 phần (dbo.TableName).
      - Chỉ mục đầu tiên phải là UNIQUE CLUSTERED INDEX.
      - Tránh dùng COUNT(*), MIN, MAX, OUTER JOIN; phải dùng COUNT_BIG(*).
   2. Scalar UDF vs Inline TVF:
      - Tránh xa Multi-Statement TVF (MSTVF) và Scalar UDF trong câu lệnh SELECT lớn vì chúng gây suy giảm hiệu năng (RBAR).
      - Ưu tiên dùng **Inline Table-Valued Function (iTVF)** vì SQL Query Optimizer có thể inline hóa code vào Execution Plan chính.
*/

-- 1.1 Indexed View (Materialized View)
IF OBJECT_ID('dbo.vw_CustomerOrderSummary', 'V') IS NOT NULL DROP VIEW dbo.vw_CustomerOrderSummary;
GO

CREATE VIEW dbo.vw_CustomerOrderSummary
WITH SCHEMABINDING
AS
SELECT 
    h.CustomerID,
    COUNT_BIG(*) AS TotalOrders,
    SUM(ISNULL(h.TotalAmount, 0)) AS GrandTotalAmount
FROM dbo.SalesOrderHeader h
GROUP BY h.CustomerID;
GO

-- Tạo Unique Clustered Index biến View thành Indexed View (Lưu vật lý trên đĩa)
CREATE UNIQUE CLUSTERED INDEX CIX_vw_CustomerOrderSummary 
ON dbo.vw_CustomerOrderSummary (CustomerID);
GO

-- 1.2 Inline Table-Valued Function (iTVF) vs Multi-Statement TVF
-- Inline TVF (Khuyên dùng trong kỳ thi DP-800)
IF OBJECT_ID('dbo.fn_GetCustomerOrders', 'IF') IS NOT NULL DROP FUNCTION dbo.fn_GetCustomerOrders;
GO

CREATE FUNCTION dbo.fn_GetCustomerOrders (@CustID INT)
RETURNS TABLE
AS
RETURN (
    SELECT OrderID, OrderDate, TotalAmount, OrderStatus
    FROM dbo.SalesOrderHeader
    WHERE CustomerID = @CustID
);
GO

-- 1.3 Stored Procedure với Transaction & Error Handling chuẩn Microsoft
IF OBJECT_ID('dbo.sp_ProcessNewOrder', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_ProcessNewOrder;
GO

CREATE PROCEDURE dbo.sp_ProcessNewOrder
    @CustomerID INT,
    @TotalAmount DECIMAL(18,2),
    @NewOrderID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- Bắt buộc ROLLBACK tự động nếu gặp lỗi nghiêm trọng

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.SalesOrderHeader (CustomerID, OrderDate, TotalAmount, OrderStatus)
        VALUES (@CustomerID, SYSDATETIME(), @TotalAmount, 1);

        SET @NewOrderID = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 
            ROLLBACK TRANSACTION;

        -- Re-throw lỗi nguyên bản kèm thông tin chi tiết
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO

-- 1.4 DML Triggers (AFTER & INSTEAD OF)
IF OBJECT_ID('dbo.trg_SalesOrderHeader_Audit', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_SalesOrderHeader_Audit;
GO

CREATE TRIGGER dbo.trg_SalesOrderHeader_Audit
ON dbo.SalesOrderHeader
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    -- Kiểm tra nếu cột TotalAmount bị thay đổi
    IF UPDATE(TotalAmount)
    BEGIN
        INSERT INTO dbo.ProductPriceHistory (ProductID, ProductName, UnitPrice, ValidFrom, ValidTo)
        SELECT 
            i.OrderID, 
            N'Order Amount Updated from ' + CAST(d.TotalAmount AS NVARCHAR(20)), 
            i.TotalAmount,
            SYSDATETIME(),
            '9999-12-31 23:59:59'
        FROM inserted i
        JOIN deleted d ON i.OrderID = d.OrderID;
    END
END;
GO


-- ====================================================================================
-- PHẦN 2: ADVANCED T-SQL (CTEs, WINDOW FUNCTIONS, CORRELATED QUERIES)
-- ====================================================================================

/*
   MẸO THI DP-800:
   - Window Functions: PARTITION BY, ORDER BY, ROWS/RANGE BETWEEN.
     + ROW_NUMBER(): Số thứ tự duy nhất không trùng.
     + RANK(): Trùng xếp cùng hạng, bỏ cách hạng tiếp theo (1, 2, 2, 4).
     + DENSE_RANK(): Trùng xếp cùng hạng, KHÔNG bỏ cách hạng (1, 2, 2, 3).
     + LAG(col, offset) / LEAD(col, offset): So sánh dòng trước / dòng sau.
*/

-- 2.1 Recursive CTE (Truy vấn phân cấp cây / thư mục / quản lý)
WITH EmployeeHierarchy CTE AS (
    -- Anchor Member
    SELECT EmployeeID, ManagerID, EmployeeName, 1 AS Level
    FROM (VALUES (1, NULL, N'CEO Alice'), (2, 1, N'Manager Bob'), (3, 2, N'Dev Charlie')) AS Emp(EmployeeID, ManagerID, EmployeeName)
    WHERE ManagerID IS NULL
    
    UNION ALL
    
    -- Recursive Member
    SELECT e.EmployeeID, e.ManagerID, e.EmployeeName, r.Level + 1
    FROM (VALUES (1, NULL, N'CEO Alice'), (2, 1, N meManager Bob'), (3, 2, N'Dev Charlie')) AS e(EmployeeID, ManagerID, EmployeeName)
    JOIN CTE r ON e.ManagerID = r.EmployeeID
)
SELECT * FROM CTE;
GO

-- 2.2 Window Functions Phân Tích Doanh Thu
SELECT 
    OrderID,
    CustomerID,
    OrderDate,
    TotalAmount,
    -- Xếp hạng đơn hàng đắt nhất của từng khách hàng
    ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY TotalAmount DESC) AS OrderRankByCust,
    -- Doanh thu đơn hàng trước đó của cùng khách hàng
    LAG(TotalAmount, 1, 0) OVER (PARTITION BY CustomerID ORDER BY OrderDate) AS PrevOrderAmount,
    -- Tổng doanh thu tích lũy (Running Total)
    SUM(TotalAmount) OVER (PARTITION BY CustomerID ORDER BY OrderDate ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningTotal
FROM dbo.SalesOrderHeader;
GO


-- ====================================================================================
-- PHẦN 3: NÂNG CAO - JSON FUNCTIONS TRONG T-SQL (DP-800 SPECIFIC)
-- ====================================================================================

/*
   MẸO THI DP-800: Các hàm JSON thế hệ mới trong SQL Server / Azure SQL:
   - JSON_OBJECT('key': val, ...): Tạo JSON object.
   - JSON_ARRAY(val1, val2, ...): Tạo JSON array.
   - JSON_ARRAYAGG(col): Gom nhóm các dòng dữ liệu thành 1 mảng JSON.
   - OPENJSON(): Chuyển JSON thành bảng dữ liệu (Relational Rows).
   - JSON_VALUE(): Trích xuất giá trị vô hướng (scalar value).
   - JSON_QUERY(): Trích xuất một đối tượng JSON hoặc mảng JSON.
   - JSON_CONTAINS(): Kiểm tra sự tồn tại của key/path trong JSON.
*/

-- 3.1 Tạo và Tổng hợp JSON từ dữ liệu quan hệ
SELECT 
    CustomerID,
    JSON_OBJECT(
        'customer_id': CustomerID,
        'order_count': COUNT(*),
        'total_spent': SUM(TotalAmount)
    ) AS CustomerSummaryJSON,
    JSON_ARRAYAGG(
        JSON_OBJECT('order_id': OrderID, 'amount': TotalAmount, 'date': CONVERT(VARCHAR, OrderDate, 120))
    ) AS OrderDetailsJSONArray
FROM dbo.SalesOrderHeader
GROUP BY CustomerID;
GO

-- 3.2 Bóc tách JSON với OPENJSON (T-SQL Relational Parsing)
DECLARE @jsonInput NVARCHAR(MAX) = N'[
    {"id": 101, "item": "Keyboard", "price": 49.99},
    {"id": 102, "item": "Mouse", "price": 25.00}
]';

SELECT *
FROM OPENJSON(@jsonInput)
WITH (
    ProductID INT '$.id',
    ProductName NVARCHAR(50) '$.item',
    UnitPrice DECIMAL(18,2) '$.price'
);
GO


-- ====================================================================================
-- PHẦN 4: THẾ HỆ MỚI - REGULAR EXPRESSIONS & FUZZY STRING MATCHING (DP-800 EXAM TOPIC)
-- ====================================================================================

/*
   MẸO THI DP-800: Kỳ thi DP-800 bổ sung các hàm Regex và Fuzzy String Matching nguyên bản:
   - REGEXP_LIKE(str, pattern): Kiểm tra chuỗi thỏa mãn regex.
   - REGEXP_REPLACE(str, pattern, replacement): Thay thế chuỗi bằng regex.
   - REGEXP_SUBSTR(str, pattern): Trích xuất chuỗi con theo regex.
   - REGEXP_COUNT(str, pattern): Đếm số lần xuất hiện regex.
   - EDIT_DISTANCE(str1, str2): Tính khoảng cách Levenshtein giữa 2 chuỗi.
   - EDIT_DISTANCE_SIMILARITY(str1, str2): Tính độ tương đồng (0.00 đến 1.00).
   - JARO_WINKLER_DISTANCE(str1, str2): Độ tương đồng Jaro-Winkler cho tên người/địa danh.
*/

-- 4.1 Regular Expression Queries
DECLARE @TestEmail NVARCHAR(100) = 'user.name@domain.com';

-- Kiểm tra Email hợp lệ với REGEXP_LIKE
SELECT 
    CASE 
        WHEN REGEXP_LIKE(@TestEmail, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') = 1 
        THEN N'Valid Email' 
        ELSE N'Invalid Email' 
    END AS EmailValidationStatus;

-- Replace số điện thoại định dạng chuẩn
SELECT REGEXP_REPLACE('SĐT: 090-123-4567 hoặc 098-765-4321', '\d{3}-\d{3}-\d{4}', '[REDACTED]') AS MaskedPhones;
GO

-- 4.2 Fuzzy String Matching (Tìm kiếm chuỗi mờ / trùng lặp gần đúng)
SELECT 
    N'Microsoft' AS Str1, 
    N'Microsft' AS Str2,
    EDIT_DISTANCE(N'Microsoft', N'Microsft') AS LevenshteinDistance,
    EDIT_DISTANCE_SIMILARITY(N'Microsoft', N'Microsft') AS SimilarityScore,
    JARO_WINKLER_DISTANCE(N'Microsoft', N'Microsft') AS JaroWinklerScore;
GO


-- ====================================================================================
-- PHẦN 5: GRAPH QUERIES VỚI TOÁN TỬ MATCH
-- ====================================================================================

/*
   MẸO THI DP-800:
   - Toán tử MATCH: Dùng trong mệnh đề WHERE của truy vấn Đồ thị.
   - Cú pháp: MATCH(Node1-(Edge)->Node2)
*/

SELECT 
    p.PersonName,
    e.Rating,
    prod.ProductName
FROM 
    dbo.PersonNode p,
    dbo.LikesEdge e,
    dbo.ProductNode prod
WHERE 
    MATCH(p-(e)->prod)
    AND p.PersonName = N'Alice';
GO
