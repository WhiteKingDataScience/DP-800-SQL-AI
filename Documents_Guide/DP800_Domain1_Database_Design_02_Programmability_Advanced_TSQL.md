# DP-800 Domain 1: Implement Programmability & Write Advanced T-SQL Code

> **Miền 1:** Design and Develop Database Solutions (35–40%)  
> **Chủ đề:** Implement programmability objects + Write advanced T-SQL code  
> **Blueprint:** DP-800 skills measured as of **March 12, 2026**  
> **Rà soát/cập nhật:** **09/08/2026**

> [!IMPORTANT]
> File này bám đúng blueprint DP-800. Các tính năng SQL Server 2025 đang ở **Preview** được đánh dấu rõ để bạn không nhầm “Preview” với “không thi”. Microsoft nêu rằng phần lớn câu hỏi dựa trên tính năng GA, nhưng tính năng Preview có thể xuất hiện nếu được sử dụng phổ biến.

---

# 1. CHECKLIST BLUEPRINT — PHẢI NẮM ĐƯỢC GÌ?

Theo DP-800 Study Guide, phần này yêu cầu bạn có thể:

## Implement programmability objects

- Design and implement **views**.
- Design and implement **scalar functions**.
- Design and implement **table-valued functions (TVFs)**.
- Design and implement **stored procedures**.
- Design and implement **triggers**.

## Write advanced T-SQL code

- Implement **Common Table Expressions (CTEs)**.
- Implement **window functions**.
- Implement JSON functions, gồm:
  - `JSON_OBJECT`
  - `JSON_ARRAY`
  - `JSON_ARRAYAGG`
  - `JSON_CONTAINS`
  - `OPENJSON`
  - `JSON_VALUE`
- Implement regular expression functions:
  - `REGEXP_LIKE`
  - `REGEXP_REPLACE`
  - `REGEXP_SUBSTR`
  - `REGEXP_INSTR`
  - `REGEXP_COUNT`
  - `REGEXP_MATCHES`
  - `REGEXP_SPLIT_TO_TABLE`
- Implement fuzzy string matching:
  - `EDIT_DISTANCE`
  - `EDIT_DISTANCE_SIMILARITY`
  - `JARO_WINKLER_DISTANCE`
- Implement graph queries with `MATCH`.
- Implement **correlated queries**.
- Implement **error handling**.

Nguồn chuẩn: [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)

---

# 2. PROGRAMMABILITY OBJECTS — HIỂU ĐÚNG VÀ CHỌN ĐÚNG

## 2.1 View

### View là gì?

`VIEW` là một câu `SELECT` được đặt tên. View không mặc định lưu riêng dữ liệu; khi truy vấn view, SQL Server thường truy vấn các base tables bên dưới.

Dùng View khi cần:

- đơn giản hóa query phức tạp;
- tạo interface ổn định cho application;
- giới hạn tập columns/rows người dùng nhìn thấy;
- tái sử dụng logic `SELECT`.

### Ví dụ cơ bản

```sql
CREATE OR ALTER VIEW dbo.vw_ActiveCustomers
AS
SELECT
    CustomerId,
    FullName,
    Email
FROM dbo.Customers
WHERE IsActive = 1;
GO

SELECT CustomerId, FullName
FROM dbo.vw_ActiveCustomers;
GO
```

### `WITH SCHEMABINDING`

`SCHEMABINDING` ràng buộc View với schema các object mà nó tham chiếu. Khi dùng nó:

- phải dùng tên 2 phần, ví dụ `dbo.Sales`;
- SQL Server ngăn những thay đổi schema bên dưới làm view không còn hợp lệ;
- là điều kiện quan trọng khi tạo **Indexed View**.

```sql
CREATE OR ALTER VIEW dbo.vw_ProductBase
WITH SCHEMABINDING
AS
SELECT ProductId, ProductName, UnitPrice
FROM dbo.Products;
GO
```

---

## 2.2 Indexed View — điểm thi dễ ra

Indexed View là View được vật lý hóa bằng index. **Index đầu tiên bắt buộc là `UNIQUE CLUSTERED INDEX`.**

### Các bước tư duy

1. Bật đúng required `SET` options.
2. View phải deterministic và đáp ứng các hạn chế của Indexed View.
3. Base objects và view phải phù hợp ownership requirements.
4. Tạo view bằng `WITH SCHEMABINDING`.
5. Tạo `UNIQUE CLUSTERED INDEX` đầu tiên.
6. Sau đó mới có thể tạo thêm nonclustered indexes.

### Lab hoàn chỉnh

```sql
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO

DROP VIEW IF EXISTS dbo.vw_ProductSalesSummary;
DROP TABLE IF EXISTS dbo.SalesDetail;
GO

CREATE TABLE dbo.SalesDetail
(
    DetailId  INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_SalesDetail PRIMARY KEY,
    ProductId INT NOT NULL,
    Quantity  INT NOT NULL,
    LineTotal DECIMAL(19,4) NOT NULL
);
GO

CREATE VIEW dbo.vw_ProductSalesSummary
WITH SCHEMABINDING
AS
SELECT
    ProductId,
    COUNT_BIG(*) AS RowCount,
    SUM(CONVERT(BIGINT, Quantity)) AS TotalQty,
    SUM(LineTotal) AS TotalRevenue
FROM dbo.SalesDetail
GROUP BY ProductId;
GO

CREATE UNIQUE CLUSTERED INDEX CIX_vw_ProductSalesSummary
ON dbo.vw_ProductSalesSummary(ProductId);
GO

SELECT ProductId, TotalQty, TotalRevenue
FROM dbo.vw_ProductSalesSummary WITH (NOEXPAND)
WHERE ProductId = 101;
GO
```

### `NOEXPAND` — nhớ đúng

- `NOEXPAND` buộc optimizer truy vấn Indexed View như một indexed object thay vì expand ra base tables.
- SQL Server Standard/Express không tự động dùng Indexed View cho indexed-view matching như Enterprise; khi muốn truy vấn Indexed View trực tiếp, `NOEXPAND` là từ khóa quan trọng.
- Azure SQL Database và Azure SQL Managed Instance hỗ trợ automatic use mà không bắt buộc `NOEXPAND`.

Nguồn: [Create Indexed Views](https://learn.microsoft.com/en-us/sql/relational-databases/views/create-indexed-views?view=sql-server-ver17)

### Bẫy thi

`WITH SCHEMABINDING` **không tự biến View thành Indexed View**. Bạn còn phải tạo `UNIQUE CLUSTERED INDEX` đầu tiên.

---

# 3. FUNCTIONS — SCALAR, iTVF, mTVF

## 3.1 Scalar UDF

Trả về **một giá trị**.

```sql
CREATE OR ALTER FUNCTION dbo.fn_CalcLineTotal
(
    @UnitPrice DECIMAL(18,2),
    @Quantity  INT
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    RETURN @UnitPrice * @Quantity;
END;
GO

SELECT dbo.fn_CalcLineTotal(19.50, 3) AS LineTotal;
GO
```

### Khi nào chọn?

Khi logic thực sự là một phép tính scalar tái sử dụng. Không nên mặc định dùng scalar UDF cho mọi xử lý từng dòng chỉ vì code “đẹp”. Các phiên bản hiện đại có Scalar UDF Inlining cho nhiều trường hợp, nhưng không phải mọi UDF đều được inline.

---

## 3.2 Inline Table-Valued Function (iTVF)

Trả về một table từ **một câu `SELECT`**. Đây là dạng thường rất thân thiện với optimizer.

```sql
CREATE OR ALTER FUNCTION dbo.fn_OrdersByCustomer
(
    @CustomerId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        OrderId,
        CustomerId,
        OrderDate,
        TotalAmount
    FROM dbo.Orders
    WHERE CustomerId = @CustomerId
);
GO

SELECT *
FROM dbo.fn_OrdersByCustomer(1001)
WHERE OrderDate >= '2026-01-01';
GO
```

**Mental model:** iTVF gần với “parameterized view”.

---

## 3.3 Multi-Statement TVF (mTVF)

Có table variable nội bộ và nhiều statements.

```sql
CREATE OR ALTER FUNCTION dbo.fn_CustomerOrderStats
(
    @CustomerId INT
)
RETURNS @Result TABLE
(
    OrderCount  INT,
    TotalAmount DECIMAL(19,2)
)
AS
BEGIN
    INSERT @Result(OrderCount, TotalAmount)
    SELECT
        COUNT(*),
        COALESCE(SUM(TotalAmount), 0)
    FROM dbo.Orders
    WHERE CustomerId = @CustomerId;

    RETURN;
END;
GO
```

### Thi cử: chọn object nào?

| Nhu cầu | Object thường phù hợp |
|---|---|
| Một scalar value | Scalar UDF |
| Một result set có parameter và chỉ cần một SELECT | iTVF |
| Result table cần nhiều bước xử lý | mTVF |
| Cần DML / transaction / output params / side effects | Stored Procedure |

Không học theo câu “mTVF luôn xấu”. Hãy hiểu trade-off và chọn object đơn giản nhất đáp ứng yêu cầu.

---

# 4. STORED PROCEDURES

Stored Procedure phù hợp khi cần:

- thực hiện nhiều statements;
- DML (`INSERT`, `UPDATE`, `DELETE`);
- transaction;
- parameter input/output;
- encapsulate nghiệp vụ;
- gọi từ application/service.

## 4.1 Procedure với input + output parameter

```sql
CREATE OR ALTER PROCEDURE dbo.usp_CreateOrder
    @CustomerId INT,
    @OrderDate DATETIME2(0),
    @NewOrderId BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT dbo.Orders(CustomerId, OrderDate, TotalAmount)
    VALUES (@CustomerId, @OrderDate, 0);

    SET @NewOrderId = CONVERT(BIGINT, SCOPE_IDENTITY());
END;
GO

DECLARE @OrderId BIGINT;

EXEC dbo.usp_CreateOrder
    @CustomerId = 1001,
    @OrderDate = SYSDATETIME(),
    @NewOrderId = @OrderId OUTPUT;

SELECT @OrderId AS NewOrderId;
GO
```

## 4.2 Dynamic SQL an toàn — `sp_executesql`

**Không nối trực tiếp input của người dùng vào câu SQL.**

Sai:

```sql
-- KHÔNG dùng với input không tin cậy
EXEC('SELECT * FROM dbo.Customers WHERE Email = ''' + @Email + '''');
```

Đúng:

```sql
DECLARE @Email NVARCHAR(320) = N'user@example.com';
DECLARE @Sql NVARCHAR(MAX) =
    N'SELECT CustomerId, FullName, Email
      FROM dbo.Customers
      WHERE Email = @pEmail;';

EXEC sys.sp_executesql
    @Sql,
    N'@pEmail NVARCHAR(320)',
    @pEmail = @Email;
GO
```

**Exam keyword:** dynamic SQL + untrusted input + security ⇒ nghĩ đến **parameterization / `sp_executesql`**.

---

# 5. TRIGGERS — AFTER, INSTEAD OF, INSERTED/DELETED

## 5.1 AFTER trigger

Chạy sau DML đã vượt qua constraint checking và statement thực hiện thành công tới giai đoạn trigger.

### Điều quan trọng nhất trong thi

Trigger chạy **theo statement**, không phải “mỗi row”. `inserted` và `deleted` có thể chứa **nhiều dòng**.

```sql
DROP TABLE IF EXISTS dbo.OrderAudit;
GO

CREATE TABLE dbo.OrderAudit
(
    AuditId    BIGINT IDENTITY PRIMARY KEY,
    OrderId    BIGINT NOT NULL,
    OldAmount  DECIMAL(18,2) NULL,
    NewAmount  DECIMAL(18,2) NULL,
    ChangedAt  DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE OR ALTER TRIGGER dbo.trg_Orders_AuditAmount
ON dbo.Orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT dbo.OrderAudit(OrderId, OldAmount, NewAmount)
    SELECT
        i.OrderId,
        d.TotalAmount,
        i.TotalAmount
    FROM inserted AS i
    INNER JOIN deleted AS d
        ON d.OrderId = i.OrderId
    WHERE i.TotalAmount <> d.TotalAmount;
END;
GO
```

### `inserted` / `deleted`

| DML | `inserted` | `deleted` |
|---|---|---|
| INSERT | new rows | trống |
| DELETE | trống | old rows |
| UPDATE | new versions | old versions |

---

## 5.2 INSTEAD OF trigger

Thay thế DML gốc. Một use case điển hình là điều khiển cập nhật qua complex View.

```sql
CREATE OR ALTER TRIGGER dbo.trg_vwCustomerContact_Update
ON dbo.vwCustomerContact
INSTEAD OF UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE c
    SET
        c.FullName = i.FullName,
        c.Email = i.Email
    FROM dbo.Customers AS c
    INNER JOIN inserted AS i
        ON i.CustomerId = c.CustomerId;
END;
GO
```

> `TRUNCATE TABLE` không kích hoạt DML `DELETE` trigger. Đây là exam trap phổ biến.

Nguồn: [DML Triggers](https://learn.microsoft.com/en-us/sql/relational-databases/triggers/dml-triggers?view=sql-server-ver17)

---

# 6. COMMON TABLE EXPRESSIONS (CTEs)

## 6.1 Non-recursive CTE

CTE chỉ tồn tại cho **statement ngay sau nó**.

```sql
WITH CustomerTotals AS
(
    SELECT
        CustomerId,
        SUM(TotalAmount) AS LifetimeValue
    FROM dbo.Orders
    GROUP BY CustomerId
)
SELECT CustomerId, LifetimeValue
FROM CustomerTotals
WHERE LifetimeValue >= 10000;
GO
```

## 6.2 Recursive CTE

Gồm:

1. **Anchor member** — điểm bắt đầu.
2. `UNION ALL`.
3. **Recursive member** — tham chiếu lại CTE.
4. Điều kiện tự dừng.

```sql
WITH Org AS
(
    -- Anchor: CEO
    SELECT EmployeeId, ManagerId, EmployeeName, 0 AS LevelNo
    FROM dbo.Employees
    WHERE ManagerId IS NULL

    UNION ALL

    -- Recursive member
    SELECT e.EmployeeId, e.ManagerId, e.EmployeeName, o.LevelNo + 1
    FROM dbo.Employees AS e
    INNER JOIN Org AS o
        ON e.ManagerId = o.EmployeeId
)
SELECT *
FROM Org
ORDER BY LevelNo, EmployeeId
OPTION (MAXRECURSION 100);
GO
```

**Exam clue:** hierarchical parent-child traversal ⇒ recursive CTE là ứng viên tự nhiên.

---

# 7. WINDOW FUNCTIONS — PHẢI PHÂN BIỆT ĐƯỢC

Window function tính toán trên một “cửa sổ” rows nhưng **không collapse rows** như `GROUP BY`.

## 7.1 Ranking

```sql
SELECT
    CustomerId,
    OrderId,
    OrderDate,
    ROW_NUMBER() OVER
    (
        PARTITION BY CustomerId
        ORDER BY OrderDate DESC, OrderId DESC
    ) AS RowNo,
    RANK() OVER
    (
        PARTITION BY CustomerId
        ORDER BY TotalAmount DESC
    ) AS AmountRank,
    DENSE_RANK() OVER
    (
        PARTITION BY CustomerId
        ORDER BY TotalAmount DESC
    ) AS DenseAmountRank,
    NTILE(4) OVER
    (
        ORDER BY TotalAmount DESC
    ) AS Quartile
FROM dbo.Orders;
GO
```

### `ROW_NUMBER` vs `RANK` vs `DENSE_RANK`

Giả sử values: `100, 100, 90`.

```text
ROW_NUMBER: 1,2,3
RANK:       1,1,3
DENSE_RANK: 1,1,2
```

- Cần **đúng một row** theo thứ tự ⇒ thường `ROW_NUMBER()`.
- Cần đồng hạng và có khoảng trống ⇒ `RANK()`.
- Cần đồng hạng không có khoảng trống ⇒ `DENSE_RANK()`.

## 7.2 `LAG` / `LEAD`

```sql
SELECT
    CustomerId,
    OrderDate,
    TotalAmount,
    LAG(TotalAmount) OVER
        (PARTITION BY CustomerId ORDER BY OrderDate) AS PrevAmount,
    LEAD(TotalAmount) OVER
        (PARTITION BY CustomerId ORDER BY OrderDate) AS NextAmount
FROM dbo.Orders;
GO
```

**Clue:** so sánh row hiện tại với row trước/sau ⇒ `LAG` / `LEAD`, không cần self-join.

## 7.3 Running total và window frame

```sql
SELECT
    CustomerId,
    OrderDate,
    TotalAmount,
    SUM(TotalAmount) OVER
    (
        PARTITION BY CustomerId
        ORDER BY OrderDate, OrderId
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS RunningTotal
FROM dbo.Orders;
GO
```

Nhớ `ROWS BETWEEN ...` khi câu hỏi hỏi rõ frame vật lý của rows.

Nguồn: [SELECT - OVER Clause](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql?view=sql-server-ver17)

---

# 8. JSON FUNCTIONS — PHẦN BẮT BUỘC TRONG BLUEPRINT

## 8.1 `JSON_VALUE` — lấy scalar

```sql
DECLARE @j NVARCHAR(MAX) =
N'{"customer":{"id":42,"name":"Lan"},"vip":true}';

SELECT
    JSON_VALUE(@j, '$.customer.id')   AS CustomerId,
    JSON_VALUE(@j, '$.customer.name') AS CustomerName;
GO
```

`JSON_VALUE` phù hợp khi property là scalar. Với object/array, thường nghĩ đến `JSON_QUERY`.

---

## 8.2 `OPENJSON` — JSON → rows/columns

```sql
DECLARE @orders NVARCHAR(MAX) = N'
[
  {"orderId":1,"amount":120.50},
  {"orderId":2,"amount":310.00}
]';

SELECT OrderId, Amount
FROM OPENJSON(@orders)
WITH
(
    OrderId INT           '$.orderId',
    Amount  DECIMAL(18,2) '$.amount'
);
GO
```

**Mental model:** `OPENJSON` shredding JSON thành relational rows.

---

## 8.3 `JSON_OBJECT` và `JSON_ARRAY`

```sql
SELECT JSON_OBJECT
(
    'customerId': 42,
    'name': 'Lan',
    'status': 'Active'
) AS CustomerJson;
GO

SELECT JSON_ARRAY('SQL Server', 'Azure SQL', 'Fabric SQL') AS Products;
GO
```

---

## 8.4 `JSON_ARRAYAGG` — nhiều rows → JSON array

```sql
SELECT
    CustomerId,
    JSON_ARRAYAGG(OrderId ORDER BY OrderDate) AS OrderIds
FROM dbo.Orders
GROUP BY CustomerId;
GO
```

**Clue:** gom nhiều values từ nhiều rows thành array JSON ⇒ `JSON_ARRAYAGG`.

> **Availability ngày 09/08/2026:** `JSON_ARRAYAGG`/`JSON_OBJECTAGG` đã GA trên Azure SQL Database, Azure SQL Managed Instance dùng update policy SQL Server 2025/Always-up-to-date, và Fabric Data Warehouse; vẫn là Preview trên SQL Server 2025. Đừng suy diễn cùng một trạng thái cho mọi platform. Xem [JSON data in SQL Server](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-data-sql-server?view=sql-server-ver17#json-data-from-aggregates).

---

## 8.5 `JSON_CONTAINS` — kiểm tra containment

`JSON_CONTAINS` là tính năng SQL Server 2025 hiện còn **Preview**. Dùng để kiểm tra một JSON value có chứa candidate tại path được chỉ định hay không.

Ví dụ dạng ôn thi:

```sql
-- Ví dụ ý tưởng: kiểm tra mảng tags chứa một phần tử cụ thể.
SELECT ProductId
FROM dbo.Products
WHERE JSON_CONTAINS(Attributes, 'premium', '$.tags[*]') = 1;
GO
```

> Vì đây là Preview và syntax/capability có thể tiến hóa, luôn kiểm tra trang Microsoft Learn trước khi áp dụng production.

Các giới hạn hiện hành dễ thành đáp án nhiễu:

- dù signature ghi path là optional, bản Preview hiện tại **yêu cầu path**;
- path trỏ tới array phải có wildcard, ví dụ `$.tags[*]`;
- chưa dùng native `json` value hoặc kết quả object/array từ `JSON_QUERY` làm search value;
- hàm trả `1`, `0` hoặc `NULL`; path không tồn tại có thể trả `NULL`, không phải luôn là `0`.

Nguồn: [JSON_CONTAINS](https://learn.microsoft.com/en-us/sql/t-sql/functions/json-contains-transact-sql?view=sql-server-ver17)

---

# 9. REGULAR EXPRESSIONS — SQL SERVER 2025

Các `REGEXP_*` là nhóm rất dễ được hỏi vì blueprint gọi tên từng hàm.

> [!NOTE]
> `REGEXP_MATCHES` và `REGEXP_SPLIT_TO_TABLE` là **table-valued functions** và yêu cầu database compatibility level 170, trừ khi bật chính xác database-scoped configuration `ALLOW_BUILTIN_TVF_IN_ALL_COMPAT_LEVELS`. Regex trên Azure SQL Managed Instance yêu cầu update policy SQL Server 2025 hoặc Always-up-to-date.

```sql
-- Lựa chọn A: đặt compatibility level 170 cho database.
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 170;
GO

-- Lựa chọn B: khi chưa thể nâng compatibility level,
-- cho phép hai built-in regex TVFs chạy ở compatibility level khác.
ALTER DATABASE SCOPED CONFIGURATION
SET ALLOW_BUILTIN_TVF_IN_ALL_COMPAT_LEVELS = ON;
GO
```

Giới hạn dùng chung cần nhớ: `string_expression` dạng `varchar(max)`/`nvarchar(max)` được xử lý tối đa **2 MB**; regex pattern tối đa **8.000 bytes**. Các flags hợp lệ là `c` (case-sensitive, mặc định), `i`, `s`, `m`; nếu flags mâu thuẫn thì flag xuất hiện sau cùng thắng.

## 9.1 Bảng nhớ nhanh

| Hàm | Trả về / mục đích |
|---|---|
| `REGEXP_LIKE` | match hay không |
| `REGEXP_REPLACE` | thay thế text match |
| `REGEXP_SUBSTR` | lấy substring match |
| `REGEXP_INSTR` | vị trí bắt đầu/kết thúc match |
| `REGEXP_COUNT` | số lần match |
| `REGEXP_MATCHES` | table chứa các match/capture |
| `REGEXP_SPLIT_TO_TABLE` | split string thành nhiều rows |

Nguồn tổng hợp: [Regular Expressions Functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/regular-expressions-functions-transact-sql?view=sql-server-ver17)

## 9.2 `REGEXP_LIKE`

```sql
SELECT Email
FROM dbo.Customers
WHERE REGEXP_LIKE
(
    Email,
    '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
) = 1;
GO
```

### CHECK constraint chuẩn

```sql
DROP TABLE IF EXISTS dbo.Suppliers;
GO

CREATE TABLE dbo.Suppliers
(
    SupplierId   INT IDENTITY PRIMARY KEY,
    SupplierName NVARCHAR(100) NOT NULL,
    TaxCode      VARCHAR(20) NOT NULL,
    Email        VARCHAR(320) NOT NULL,

    CONSTRAINT CK_Suppliers_TaxCode
        CHECK (REGEXP_LIKE(TaxCode, '^\d{10}$') = 1),

    CONSTRAINT CK_Suppliers_Email
        CHECK
        (
            REGEXP_LIKE
            (
                Email,
                '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
            ) = 1
        )
);
GO
```

> Bản cũ có lỗi `'^\d{10}$Count'`; phiên bản này đã sửa thành `'^\d{10}$'`.

---

## 9.3 `REGEXP_REPLACE`

```sql
SELECT REGEXP_REPLACE
(
    '090-123-4567',
    '\d{4}$',
    '****'
) AS MaskedPhone;
GO
```

---

## 9.4 `REGEXP_SUBSTR`

```sql
SELECT REGEXP_SUBSTR
(
    'Order AB-2026-00981 is ready',
    '[A-Z]{2}-\d{4}-\d{5}'
) AS OrderCode;
GO
```

---

## 9.5 `REGEXP_INSTR`

```sql
SELECT REGEXP_INSTR
(
    'abc INV-2026-12345 xyz',
    'INV-\d{4}-\d{5}'
) AS StartPosition;
GO
```

---

## 9.6 `REGEXP_COUNT`

```sql
SELECT REGEXP_COUNT
(
    'A12 B34 C56',
    '\d{2}'
) AS NumberOfNumericPairs;
GO
```

---

## 9.7 `REGEXP_MATCHES`

```sql
-- TVF: trả về một hoặc nhiều rows chứa các match/capture.
SELECT *
FROM REGEXP_MATCHES
(
    'Ticket T-101, T-205 and T-999',
    'T-\d{3}'
);
GO
```

Không cần học thuộc mọi tên output column để làm scenario; cần nhớ **hàm này trả về table** (`match_id`, vị trí, `match_value`, captures dạng JSON), khác `REGEXP_SUBSTR` chỉ trả về một occurrence scalar.

Nguồn: [REGEXP_MATCHES](https://learn.microsoft.com/en-us/sql/t-sql/functions/regexp-matches-transact-sql?view=sql-server-ver17)

---

## 9.8 `REGEXP_SPLIT_TO_TABLE`

```sql
SELECT *
FROM REGEXP_SPLIT_TO_TABLE
(
    'SQL, Azure SQL; Fabric SQL | PostgreSQL',
    '[,;|]\s*'
);
GO
```

**Clue:** split text bằng delimiter phức tạp và muốn nhiều rows ⇒ `REGEXP_SPLIT_TO_TABLE`.

Nguồn: [REGEXP_SPLIT_TO_TABLE](https://learn.microsoft.com/en-us/sql/t-sql/functions/regexp-split-to-table-transact-sql?view=sql-server-ver17)

---

# 10. FUZZY STRING MATCHING — ĐỪNG NHẦM DISTANCE VÀ SIMILARITY

Nhóm này hỗ trợ matching tên/địa chỉ/text gần giống nhau.

> [!IMPORTANT]
> Các trang Microsoft Learn của `EDIT_DISTANCE`, `EDIT_DISTANCE_SIMILARITY` và `JARO_WINKLER_DISTANCE` vẫn được đánh dấu **Preview** ngày 09/08/2026. Chúng không nhận `varchar(max)`/`nvarchar(max)`. Hãy đọc đúng platform trong câu hỏi; trên Azure SQL Managed Instance cần update policy SQL Server 2025/Always-up-to-date.

## 10.1 `EDIT_DISTANCE`

Số phép biến đổi để chuyển chuỗi A thành B. **Thấp hơn = giống hơn.**

```sql
SELECT EDIT_DISTANCE('Colour', 'Color') AS Distance;

-- Có thể đặt ngưỡng để tránh tính toàn bộ distance không cần thiết.
-- Nếu distance thực vượt 2, kết quả chỉ được bảo đảm là >= 2,
-- không nhất thiết là distance chính xác.
SELECT EDIT_DISTANCE('Microsoft SQL', 'Microsft SQL', 2) AS BoundedDistance;
GO
```

**Bẫy implementation hiện hành:** tài liệu mô tả thuật toán Damerau-Levenshtein, nhưng bản Preview hiện **chưa hỗ trợ transposition**. Không dựa vào việc đổi chỗ hai ký tự để khẳng định kết quả bằng 1.

## 10.2 `EDIT_DISTANCE_SIMILARITY`

Trả về **integer từ 0 đến 100**:

- `0` = không tương đồng;
- `100` = trùng hoàn toàn.

```sql
SELECT EDIT_DISTANCE_SIMILARITY('Colour', 'Color') AS Similarity;
GO
```

> Đây là một lỗi quan trọng đã sửa so với bản cũ: **không phải 0.0–1.0**.

## 10.3 `JARO_WINKLER_DISTANCE`

Trả về `float` distance. **Giá trị càng thấp, chuỗi càng gần nhau.** Jaro-Winkler đặc biệt hữu ích khi prefix giống nhau, ví dụ tên người.

```sql
SELECT JARO_WINKLER_DISTANCE('Kien Bach', 'Kien Bch') AS Distance;
GO
```

## 10.4 Hàm liên quan cần nhận diện

SQL Server 2025 cũng có `JARO_WINKLER_SIMILARITY`, trả về 0–100. Dù blueprint DP-800 gọi tên `JARO_WINKLER_DISTANCE`, việc biết hàm similarity giúp tránh bẫy “distance vs similarity”.

Nguồn:

- [EDIT_DISTANCE](https://learn.microsoft.com/en-us/sql/t-sql/functions/edit-distance-transact-sql?view=sql-server-ver17)
- [EDIT_DISTANCE_SIMILARITY](https://learn.microsoft.com/en-us/sql/t-sql/functions/edit-distance-similarity-transact-sql?view=sql-server-ver17)
- [JARO_WINKLER_DISTANCE](https://learn.microsoft.com/en-us/sql/t-sql/functions/jaro-winkler-distance-transact-sql?view=sql-server-ver17)

---

# 11. GRAPH QUERY VỚI `MATCH`

Giả sử có:

- `Person AS NODE`
- `Restaurant AS NODE`
- `Likes AS EDGE`

```sql
SELECT
    p.Name AS PersonName,
    r.Name AS RestaurantName
FROM dbo.Person AS p,
     dbo.Likes AS l,
     dbo.Restaurant AS r
WHERE MATCH(p-(l)->r);
GO
```

**Exam clue:** tìm relationship/path giữa graph nodes ⇒ `MATCH`, không phải JSON join hay recursive CTE theo mặc định.

Nguồn: [MATCH (SQL Graph)](https://learn.microsoft.com/en-us/sql/t-sql/queries/match-sql-graph?view=sql-server-ver17)

---

# 12. CORRELATED QUERIES — BLUEPRINT CÓ GỌI TÊN

Correlated subquery tham chiếu column từ outer query và được đánh giá logic theo từng outer row (optimizer có thể transform cách thực thi).

## 12.1 `EXISTS` — kiểm tra có row hay không

```sql
SELECT
    c.CustomerId,
    c.FullName
FROM dbo.Customers AS c
WHERE EXISTS
(
    SELECT 1
    FROM dbo.Orders AS o
    WHERE o.CustomerId = c.CustomerId
      AND o.OrderDate >= '2026-01-01'
);
GO
```

**Clue:** “customers who have at least one…” ⇒ `EXISTS` rất tự nhiên.

## 12.2 `NOT EXISTS` — anti-semi logic

```sql
SELECT
    c.CustomerId,
    c.FullName
FROM dbo.Customers AS c
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.Orders AS o
    WHERE o.CustomerId = c.CustomerId
);
GO
```

**Clue:** “customers with no orders” ⇒ `NOT EXISTS`.

## 12.3 Correlated scalar aggregate

```sql
SELECT
    c.CustomerId,
    c.FullName,
    (
        SELECT MAX(o.OrderDate)
        FROM dbo.Orders AS o
        WHERE o.CustomerId = c.CustomerId
    ) AS LastOrderDate
FROM dbo.Customers AS c;
GO
```

### Bẫy `NOT IN` + NULL

Trong scenario chống tồn tại, `NOT EXISTS` thường an toàn và rõ hơn `NOT IN` khi subquery có khả năng trả `NULL`.

Nguồn: [Subqueries](https://learn.microsoft.com/en-us/sql/relational-databases/performance/subqueries?view=sql-server-ver17)

---

# 13. ERROR HANDLING + TRANSACTIONS

Đây là phần cần **viết được template chuẩn**.

## 13.1 Ba giá trị của `XACT_STATE()`

| Giá trị | Ý nghĩa |
|---:|---|
| `1` | đang có transaction và có thể commit |
| `0` | không có active user transaction |
| `-1` | transaction uncommittable; chỉ có thể rollback |

## 13.2 Template production-friendly

```sql
CREATE OR ALTER PROCEDURE dbo.usp_TransferFunds
    @FromAccount INT,
    @ToAccount   INT,
    @Amount      DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Accounts
        SET Balance = Balance - @Amount
        WHERE AccountId = @FromAccount;

        IF @@ROWCOUNT <> 1
            THROW 50001, 'Source account was not found.', 1;

        UPDATE dbo.Accounts
        SET Balance = Balance + @Amount
        WHERE AccountId = @ToAccount;

        IF @@ROWCOUNT <> 1
            THROW 50002, 'Destination account was not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
```

### Vì sao dùng `THROW`?

`THROW;` trong `CATCH` rethrow lỗi hiện tại và giữ thông tin lỗi phù hợp. Với code mới, đây là lựa chọn quan trọng cần nhận diện.

### Vì sao `XACT_STATE() <> 0`?

- `-1`: bắt buộc rollback.
- `1`: nếu business rule chọn hủy toàn bộ operation thì cũng rollback.
- `0`: không có transaction để rollback.

Bản cũ chỉ rollback khi `-1`, dễ bỏ sót transaction vẫn committable (`1`) nhưng application muốn atomic failure.

Nguồn:

- [TRY...CATCH](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql?view=sql-server-ver17)
- [XACT_STATE](https://learn.microsoft.com/en-us/sql/t-sql/functions/xact-state-transact-sql?view=sql-server-ver17)
- [THROW](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/throw-transact-sql?view=sql-server-ver17)

---

# 14. LAB TỔNG HỢP — TOP-N PER GROUP + JSON + PROCEDURE + TRANSACTION

Mục tiêu: nối nhiều kỹ năng vào cùng một scenario.

```sql
-- 1. Latest order per customer bằng ROW_NUMBER.
WITH RankedOrders AS
(
    SELECT
        o.OrderId,
        o.CustomerId,
        o.OrderDate,
        o.TotalAmount,
        ROW_NUMBER() OVER
        (
            PARTITION BY o.CustomerId
            ORDER BY o.OrderDate DESC, o.OrderId DESC
        ) AS rn
    FROM dbo.Orders AS o
)
SELECT
    CustomerId,
    OrderId,
    OrderDate,
    TotalAmount
FROM RankedOrders
WHERE rn = 1;
GO

-- 2. Xuất một object JSON.
SELECT JSON_OBJECT
(
    'customerId': c.CustomerId,
    'name': c.FullName,
    'email': c.Email
) AS CustomerJson
FROM dbo.Customers AS c
WHERE c.CustomerId = 1001;
GO

-- 3. Parse JSON input để insert nhiều rows.
DECLARE @Input NVARCHAR(MAX) = N'
[
  {"customerId":1001,"amount":125.50},
  {"customerId":1002,"amount":300.00}
]';

SELECT CustomerId, Amount
FROM OPENJSON(@Input)
WITH
(
    CustomerId INT           '$.customerId',
    Amount     DECIMAL(18,2) '$.amount'
);
GO
```

---

# 15. EXAM DECISION TABLE — NHÌN KEYWORD, CHỌN KỸ THUẬT

| Scenario | Nghĩ tới |
|---|---|
| Reusable SELECT abstraction | View |
| Materialized relational summary | Indexed View |
| Scalar reusable calculation | Scalar UDF |
| Parameterized relational result, one SELECT | iTVF |
| DML + transaction + parameters | Stored Procedure |
| React to table DML | Trigger |
| Multi-row trigger | `inserted` / `deleted`, set-based |
| Hierarchy recursion | Recursive CTE |
| Top N per group | `ROW_NUMBER` / ranking window |
| Previous/next row | `LAG` / `LEAD` |
| Running total | aggregate window + frame |
| JSON scalar | `JSON_VALUE` |
| JSON → rows | `OPENJSON` |
| Rows → JSON array | `JSON_ARRAYAGG` |
| JSON containment | `JSON_CONTAINS` |
| Regex Boolean test | `REGEXP_LIKE` |
| Regex extract one | `REGEXP_SUBSTR` |
| Regex position | `REGEXP_INSTR` |
| Regex count | `REGEXP_COUNT` |
| All regex matches as rows | `REGEXP_MATCHES` |
| Regex split as rows | `REGEXP_SPLIT_TO_TABLE` |
| Approximate string distance | `EDIT_DISTANCE` / `JARO_WINKLER_DISTANCE` |
| Similarity 0–100 | `EDIT_DISTANCE_SIMILARITY` |
| Graph relationship | `MATCH` |
| At least one related row | correlated `EXISTS` |
| No related row | `NOT EXISTS` |
| Transaction failure | TRY/CATCH + `XACT_STATE()` + rollback + `THROW` |

---

# 16. MOCK QUESTIONS — TỰ KIỂM TRA

## Q1 — Latest row per group

Bạn cần trả đúng **một order mới nhất** cho mỗi customer, kể cả khi hai orders có cùng `OrderDate`.

**Đáp án nên chọn:** `ROW_NUMBER()` với tie-breaker như `OrderId DESC`.

---

## Q2 — Ranking with ties

Values: 100, 100, 90. Muốn ranks: 1, 1, 2.

**Đáp án:** `DENSE_RANK()`.

---

## Q3 — JSON to rows

API gửi một JSON array gồm 1,000 order objects. Cần chuyển thành rowset để validate/insert.

**Đáp án:** `OPENJSON ... WITH (...)`.

---

## Q4 — JSON array aggregation

Cần trả danh sách `OrderId` của mỗi customer thành JSON array.

**Đáp án:** `JSON_ARRAYAGG`.

---

## Q5 — Regex check

`TaxCode` phải đúng 10 digits.

**Đáp án:** `CHECK (REGEXP_LIKE(TaxCode, '^\d{10}$') = 1)`.

---

## Q6 — Multiple regex results

Một chuỗi có nhiều ticket codes và bạn cần mỗi code thành một row.

**Đáp án:** `REGEXP_MATCHES`.

---

## Q7 — Fuzzy trap

Cần thang điểm **0–100**, giá trị cao hơn nghĩa là giống hơn.

**Đáp án:** `EDIT_DISTANCE_SIMILARITY` (hoặc Jaro-Winkler similarity nếu scenario chỉ hỏi ngoài blueprint); không chọn distance.

---

## Q8 — Trigger

Một `UPDATE` sửa 500 rows. Trigger audit chỉ dùng scalar variables từ `inserted`.

**Vấn đề:** sai tư duy; trigger phải xử lý `inserted`/`deleted` dưới dạng set.

---

## Q9 — Indexed View

View đã có `SCHEMABINDING`, nhưng chưa materialized.

**Bước tiếp:** tạo `UNIQUE CLUSTERED INDEX`.

---

## Q10 — SQL Server Standard Indexed View

Muốn query trực tiếp sử dụng indexed representation.

**Đáp án:** `WITH (NOEXPAND)`.

---

## Q11 — Correlated anti-query

Tìm customers chưa từng có order và subquery có khả năng chứa NULL.

**Đáp án:** `NOT EXISTS` là pattern rõ và an toàn.

---

## Q12 — Error handling

Trong `CATCH`, cần biết transaction có ở trạng thái uncommittable hay không.

**Đáp án:** `XACT_STATE()`; `-1` nghĩa là uncommittable.

---

# 17. CHECKLIST “EXAM READY”

Bạn chỉ nên đánh dấu hoàn tất file này khi tự làm được mà không nhìn đáp án:

- [ ] Tạo View và giải thích `SCHEMABINDING`.
- [ ] Tạo Indexed View theo đúng thứ tự.
- [ ] Phân biệt scalar UDF / iTVF / mTVF / Stored Procedure.
- [ ] Viết Stored Procedure có input/output params.
- [ ] Viết dynamic SQL dùng `sp_executesql` parameterized.
- [ ] Viết AFTER trigger xử lý multi-row bằng `inserted`/`deleted`.
- [ ] Giải recursive CTE.
- [ ] Phân biệt `ROW_NUMBER`, `RANK`, `DENSE_RANK`.
- [ ] Viết `LAG`, `LEAD`, running total.
- [ ] Dùng `JSON_VALUE`, `OPENJSON`, `JSON_OBJECT`, `JSON_ARRAY`, `JSON_ARRAYAGG`, nhận diện `JSON_CONTAINS`.
- [ ] Nhớ mục đích cả 7 hàm `REGEXP_*` trong blueprint.
- [ ] Nhớ `EDIT_DISTANCE_SIMILARITY` là **0–100**, không phải 0–1.
- [ ] Dùng `MATCH` trong graph query.
- [ ] Viết `EXISTS` / `NOT EXISTS` correlated query.
- [ ] Viết template TRY/CATCH + transaction + `XACT_STATE()` + `THROW`.

---

# 18. LINK THAM KHẢO CHÍNH THỨC

## Blueprint

- [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)

## Programmability

- [CREATE VIEW](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-view-transact-sql?view=sql-server-ver17)
- [Create Indexed Views](https://learn.microsoft.com/en-us/sql/relational-databases/views/create-indexed-views?view=sql-server-ver17)
- [CREATE FUNCTION](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-function-transact-sql?view=sql-server-ver17)
- [CREATE PROCEDURE](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-procedure-transact-sql?view=sql-server-ver17)
- [DML Triggers](https://learn.microsoft.com/en-us/sql/relational-databases/triggers/dml-triggers?view=sql-server-ver17)

## Advanced T-SQL

- [WITH common_table_expression](https://learn.microsoft.com/en-us/sql/t-sql/queries/with-common-table-expression-transact-sql?view=sql-server-ver17)
- [OVER clause](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql?view=sql-server-ver17)
- [JSON functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/json-functions-transact-sql?view=sql-server-ver17)
- [JSON_CONTAINS](https://learn.microsoft.com/en-us/sql/t-sql/functions/json-contains-transact-sql?view=sql-server-ver17)
- [Regular Expressions Functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/regular-expressions-functions-transact-sql?view=sql-server-ver17)
- [REGEXP_MATCHES](https://learn.microsoft.com/en-us/sql/t-sql/functions/regexp-matches-transact-sql?view=sql-server-ver17)
- [REGEXP_SPLIT_TO_TABLE](https://learn.microsoft.com/en-us/sql/t-sql/functions/regexp-split-to-table-transact-sql?view=sql-server-ver17)
- [EDIT_DISTANCE](https://learn.microsoft.com/en-us/sql/t-sql/functions/edit-distance-transact-sql?view=sql-server-ver17)
- [EDIT_DISTANCE_SIMILARITY](https://learn.microsoft.com/en-us/sql/t-sql/functions/edit-distance-similarity-transact-sql?view=sql-server-ver17)
- [JARO_WINKLER_DISTANCE](https://learn.microsoft.com/en-us/sql/t-sql/functions/jaro-winkler-distance-transact-sql?view=sql-server-ver17)
- [MATCH (SQL Graph)](https://learn.microsoft.com/en-us/sql/t-sql/queries/match-sql-graph?view=sql-server-ver17)
- [TRY...CATCH](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql?view=sql-server-ver17)
- [XACT_STATE](https://learn.microsoft.com/en-us/sql/t-sql/functions/xact-state-transact-sql?view=sql-server-ver17)
- [THROW](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/throw-transact-sql?view=sql-server-ver17)

---

## Tóm tắt cuối file

Nếu thời gian rất ít, hãy thuộc chắc chuỗi sau:

```text
View -> reusable SELECT
Indexed View -> SCHEMABINDING + UNIQUE CLUSTERED INDEX
Scalar UDF -> one value
Inline TVF -> parameterized rowset, one SELECT
Stored Procedure -> DML / transaction / params
Trigger -> statement-level; inserted/deleted are sets
CTE -> query organization / recursion
Window -> rank, previous/next, running calculations without GROUP BY collapse
OPENJSON -> JSON to rows
JSON_ARRAYAGG -> rows to JSON array
REGEXP_LIKE -> Boolean regex
REGEXP_MATCHES -> regex matches as rows
EDIT_DISTANCE_SIMILARITY -> 0..100, higher is closer
JARO_WINKLER_DISTANCE -> lower is closer
MATCH -> graph relationships
EXISTS/NOT EXISTS -> correlated existence
XACT_STATE -1 -> uncommittable; rollback
THROW -> propagate/raise modern T-SQL error
```
