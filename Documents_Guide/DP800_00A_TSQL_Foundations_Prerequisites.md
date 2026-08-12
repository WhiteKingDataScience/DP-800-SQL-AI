# Kiến thức đầu vào DP-800 — Nền tảng T-SQL cho người mới bắt đầu

> **Vai trò của file này:** kiến thức đầu vào, **không phải miền thứ tư của kỳ thi**.  
> **Học file này trước Miền 1–3** nếu bạn chưa tự viết được `SELECT`, `JOIN`, `GROUP BY`, `INSERT`, `UPDATE`, `DELETE` và transaction.  
> **Blueprint đối chiếu:** DP-800, skills measured as of **March 12, 2026**.  
> **Rà soát:** 09/08/2026.

DP-800 không phải khóa “SQL từ con số 0”. Microsoft Learn xếp kỳ thi ở mức trung cấp và giả định người học đã biết truy vấn SQL cơ bản. Vì vậy, chương này lấp phần kiến thức đầu vào mà người mới thường thiếu.

Bạn có thể hình dung mối quan hệ như sau:

```text
T-SQL cơ bản
   ↓ giúp bạn đọc và thay đổi dữ liệu
Thiết kế database + bảo mật + tối ưu
   ↓ giúp hệ thống đúng, nhanh và an toàn
Vector Search + RAG
   ↓ giúp ứng dụng AI tìm và sử dụng dữ liệu doanh nghiệp
DP-800
```

Nếu chưa hiểu một câu `SELECT` đang đọc bảng nào, lọc dòng nào hoặc nối hai bảng theo điều kiện nào, bạn sẽ rất khó hiểu các ví dụ vector, RAG và bảo mật ở những chương sau.

## Mục tiêu sau khi học

Bạn cần tự làm được các việc sau mà không nhìn đáp án:

1. Giải thích bảng (table), dòng (row), cột (column), khóa chính và khóa ngoại.
2. Viết `SELECT` có lọc, sắp xếp, tính tổng hợp và `JOIN`.
3. Xử lý `NULL` đúng bằng `IS NULL`, `IS NOT NULL` và `COALESCE`.
4. Phân biệt `WHERE` với `HAVING`, `INNER JOIN` với `LEFT JOIN`.
5. Viết `INSERT`, `UPDATE`, `DELETE` có điều kiện an toàn.
6. Gom nhiều thay đổi vào một giao dịch (transaction) và biết khi nào `COMMIT` hoặc `ROLLBACK`.
7. Đọc được lỗi thường gặp trước khi chuyển sang CTE, hàm cửa sổ, lập trình database, bảo mật và AI.

---

# PHẦN 1 — CÁCH HÌNH DUNG CƠ SỞ DỮ LIỆU QUAN HỆ

## 1. Bảng, dòng và cột

Hãy hình dung một bảng trong database giống bảng tính nhưng có quy tắc chặt chẽ hơn:

- **Cột (column)** mô tả một thuộc tính và kiểu dữ liệu của thuộc tính đó.
- **Dòng (row)** là một bản ghi cụ thể.
- **Khóa chính (primary key — PK)** nhận diện duy nhất một dòng.
- **Khóa ngoại (foreign key — FK)** bảo đảm giá trị tham chiếu tới dòng có thật ở bảng khác.
- **Ràng buộc (constraint)** ngăn dữ liệu sai được ghi vào database.

Ví dụ quan hệ:

```text
Customer (1) ─────< (n) SalesOrder (1) ─────< (n) SalesOrderLine >───── (1) Product
```

Một khách hàng có thể có nhiều đơn hàng; một đơn hàng có nhiều dòng sản phẩm.

## 2. DDL, DML, DQL và TCL

| Nhóm | Mục đích | Câu lệnh thường gặp |
|---|---|---|
| DDL | Định nghĩa cấu trúc | `CREATE`, `ALTER`, `DROP` |
| DML | Thay đổi dữ liệu | `INSERT`, `UPDATE`, `DELETE` |
| DQL | Truy vấn dữ liệu | `SELECT` |
| TCL | Điều khiển transaction | `BEGIN TRAN`, `COMMIT`, `ROLLBACK` |
| DCL | Cấp/thu hồi quyền | `GRANT`, `DENY`, `REVOKE` |

Trong thực tế, các nhóm này thường được gọi chung là T-SQL statements.

---

# PHẦN 2 — BÀI THỰC HÀNH NỀN TẢNG CHẠY ĐỘC LẬP

## 3. Chọn môi trường

Bạn có thể dùng SQL Server 2022/2025, Azure SQL Database hoặc SQL database in Fabric khi tính năng được hỗ trợ. Với người mới, dễ nhất là SQL Server Developer Edition kết hợp SQL Server Management Studio (SSMS), hoặc một Azure SQL Database dùng riêng để thực hành.

> **Lưu ý Azure SQL Database:** tạo database từ Azure portal/CLI rồi kết nối trực tiếp vào database đó. Không chạy `USE another_database` để chuyển database trong cùng connection.

## 4. Tạo schema thực hành và dữ liệu mẫu

Script sau tạo một cửa hàng rất nhỏ gồm khách hàng, sản phẩm, đơn hàng và dòng sản phẩm. Toàn bộ ví dụ trong chương đều dùng bốn bảng này để bạn không phải đổi ngữ cảnh liên tục. Chỉ chạy trong database thực hành, không chạy trong môi trường thật.

Trước khi chạy, hãy đọc sơ đồ quan hệ ở Phần 1. Khi đọc lệnh, tập trả lời bốn câu hỏi: bảng nào được tạo, cột nào nhận diện một dòng, cột nào liên kết sang bảng khác và quy tắc nào ngăn dữ liệu sai.

```sql
-- Xóa theo thứ tự từ table con đến table cha để không vi phạm FOREIGN KEY.
DROP TABLE IF EXISTS dbo.SalesOrderLine;
DROP TABLE IF EXISTS dbo.SalesOrder;
DROP TABLE IF EXISTS dbo.Product;
DROP TABLE IF EXISTS dbo.Customer;
GO

CREATE TABLE dbo.Customer
(
    CustomerID int IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Customer PRIMARY KEY,
    FullName nvarchar(100) NOT NULL,
    Email nvarchar(320) NULL,
    City nvarchar(100) NULL,
    CreatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_Customer_CreatedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE dbo.Product
(
    ProductID int IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Product PRIMARY KEY,
    SKU varchar(20) NOT NULL
        CONSTRAINT UQ_Product_SKU UNIQUE,
    ProductName nvarchar(150) NOT NULL,
    UnitPrice decimal(12,2) NOT NULL,
    IsActive bit NOT NULL
        CONSTRAINT DF_Product_IsActive DEFAULT (1),
    CONSTRAINT CK_Product_UnitPrice CHECK (UnitPrice >= 0)
);
GO

CREATE TABLE dbo.SalesOrder
(
    OrderID bigint IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_SalesOrder PRIMARY KEY,
    CustomerID int NOT NULL,
    OrderDate date NOT NULL,
    OrderStatus varchar(20) NOT NULL,
    RowVer rowversion NOT NULL,
    CONSTRAINT FK_SalesOrder_Customer
        FOREIGN KEY (CustomerID) REFERENCES dbo.Customer(CustomerID),
    CONSTRAINT CK_SalesOrder_Status
        CHECK (OrderStatus IN ('New', 'Paid', 'Shipped', 'Cancelled'))
);
GO

CREATE TABLE dbo.SalesOrderLine
(
    OrderID bigint NOT NULL,
    OrderLineNo smallint NOT NULL,
    ProductID int NOT NULL,
    Quantity int NOT NULL,
    UnitPrice decimal(12,2) NOT NULL,
    CONSTRAINT PK_SalesOrderLine PRIMARY KEY (OrderID, OrderLineNo),
    CONSTRAINT FK_SalesOrderLine_Order
        FOREIGN KEY (OrderID) REFERENCES dbo.SalesOrder(OrderID),
    CONSTRAINT FK_SalesOrderLine_Product
        FOREIGN KEY (ProductID) REFERENCES dbo.Product(ProductID),
    CONSTRAINT CK_SalesOrderLine_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_SalesOrderLine_UnitPrice CHECK (UnitPrice >= 0)
);
GO

INSERT dbo.Customer (FullName, Email, City)
VALUES
    (N'An Nguyễn', N'an@example.com', N'Hà Nội'),
    (N'Bình Trần', NULL, N'Đà Nẵng'),
    (N'Chi Lê', N'chi@example.com', NULL);

INSERT dbo.Product (SKU, ProductName, UnitPrice)
VALUES
    ('SQL-BOOK', N'Sách T-SQL căn bản', 350000.00),
    ('AI-BOOK',  N'Sách AI cho dữ liệu', 420000.00),
    ('LAB-01',   N'Gói thực hành DP-800', 600000.00);

INSERT dbo.SalesOrder (CustomerID, OrderDate, OrderStatus)
VALUES
    (1, '2026-08-01', 'Paid'),
    (1, '2026-08-03', 'Shipped'),
    (2, '2026-08-05', 'New');

INSERT dbo.SalesOrderLine (OrderID, OrderLineNo, ProductID, Quantity, UnitPrice)
VALUES
    (1, 1, 1, 1, 350000.00),
    (1, 2, 2, 1, 420000.00),
    (2, 1, 3, 1, 600000.00),
    (3, 1, 1, 2, 350000.00);
GO
```

### Vì sao đoạn lệnh ghi rõ danh sách cột khi `INSERT`?

`INSERT dbo.Customer VALUES (...)` phụ thuộc vào thứ tự vật lý của mọi column và dễ hỏng khi schema thay đổi. Ghi rõ `(FullName, Email, City)` làm intent rõ ràng và tránh vô tình chèn sai cột.

### Vì sao dùng tiền tố `N` trước chuỗi tiếng Việt?

`N'Đà Nẵng'` tạo một chuỗi Unicode. Điều này quan trọng khi cột đích là `nvarchar`; thiếu `N` có thể làm mất ký tự ở môi trường dùng bảng mã không phù hợp.

---

# PHẦN 3 — ĐỌC, LỌC VÀ SẮP XẾP DỮ LIỆU

## 5. `SELECT` tối thiểu

**Bài toán:** đọc danh sách sản phẩm nhưng chỉ lấy bốn cột ứng dụng thực sự cần. `SELECT` chỉ ra cột cần trả về; `FROM` chỉ ra bảng nguồn; `AS p` đặt bí danh ngắn để tham chiếu bảng rõ ràng hơn.

```sql
SELECT
    p.ProductID,
    p.SKU,
    p.ProductName,
    p.UnitPrice
FROM dbo.Product AS p;
```

Với dữ liệu mẫu, kết quả có ba dòng sản phẩm. Truy vấn này **chỉ đọc**, không sửa dữ liệu. Vì chưa có `ORDER BY`, SQL Server không cam kết thứ tự các dòng.

Quy tắc nên tập ngay từ đầu:

- Ghi schema, ví dụ `dbo.Product`, thay vì chỉ `Product`.
- Dùng alias ngắn nhưng có nghĩa, ví dụ `p` cho Product.
- Không dùng `SELECT *` trong mã chạy ở môi trường thật nếu chỉ cần vài cột.
- Không giả định thứ tự dòng nếu không có `ORDER BY`.

## 6. `WHERE`, toán tử và tham số

**Bài toán:** chỉ lấy sản phẩm đang hoạt động và có giá từ 400.000 trở lên, sau đó sắp xếp giá giảm dần. Biến `@MinPrice` giúp tách giá trị đầu vào khỏi câu truy vấn, thay vì viết cứng con số ở nhiều chỗ.

```sql
DECLARE @MinPrice decimal(12,2) = 400000.00;

SELECT p.ProductName, p.UnitPrice
FROM dbo.Product AS p
WHERE p.IsActive = 1
  AND p.UnitPrice >= @MinPrice
ORDER BY p.UnitPrice DESC, p.ProductName ASC;
```

Với dữ liệu mẫu, kết quả gồm “Gói thực hành DP-800” và “Sách AI cho dữ liệu”. `WHERE` loại dòng không đạt điều kiện; `ORDER BY` chỉ sắp xếp các dòng còn lại.

Các toán tử cần biết:

| Nhu cầu | Cú pháp |
|---|---|
| So sánh | `=`, `<>`, `>`, `>=`, `<`, `<=` |
| Nhiều điều kiện | `AND`, `OR`, `NOT` |
| Một trong nhiều giá trị | `IN (...)` |
| Một khoảng đóng | `BETWEEN ... AND ...` |
| Mẫu ký tự | `LIKE` với `%` và `_` |
| Giá trị chưa biết | `IS NULL`, `IS NOT NULL` |

Khi trộn `AND` và `OR`, dùng ngoặc để intent không mơ hồ:

```sql
SELECT c.CustomerID, c.FullName, c.City
FROM dbo.Customer AS c
WHERE (c.City = N'Hà Nội' OR c.City = N'Đà Nẵng')
  AND c.Email IS NOT NULL;
```

## 7. `NULL` không phải rỗng, zero hay chuỗi `'NULL'`

`NULL` nghĩa là chưa biết/không áp dụng. So sánh bằng `= NULL` trả về `UNKNOWN`, không phải `TRUE`.

```sql
-- Sai về logic: không tìm được row có Email là NULL.
SELECT *
FROM dbo.Customer
WHERE Email = NULL;

-- Đúng.
SELECT CustomerID, FullName
FROM dbo.Customer
WHERE Email IS NULL;

-- Thay NULL chỉ ở kết quả hiển thị; không sửa dữ liệu gốc.
SELECT
    FullName,
    COALESCE(Email, N'(chưa có email)') AS DisplayEmail
FROM dbo.Customer;
```

Ba điểm thi rất hay nhầm:

- `COUNT(*)` đếm row; `COUNT(Email)` chỉ đếm row có `Email IS NOT NULL`.
- `NOT IN (subquery)` có thể cho kết quả bất ngờ nếu subquery chứa `NULL`; `NOT EXISTS` thường an toàn hơn cho anti-match.
- `NULL` được gom thành một group khi dùng `GROUP BY`.

## 8. Thứ tự viết và thứ tự logic

Ta viết query theo thứ tự quen thuộc:

```sql
SELECT ...
FROM ...
JOIN ... ON ...
WHERE ...
GROUP BY ...
HAVING ...
ORDER BY ...;
```

Nhưng cách hình dung theo thứ tự xử lý logic sẽ hữu ích hơn:

```text
FROM/JOIN/ON → WHERE → GROUP BY → HAVING → SELECT → DISTINCT → ORDER BY → TOP/OFFSET
```

Vì vậy alias tạo trong `SELECT` thường chưa dùng được ở `WHERE`, nhưng dùng được ở `ORDER BY`.

---

# PHẦN 4 — JOIN

## 9. `INNER JOIN`: chỉ giữ dòng khớp ở hai phía

```sql
SELECT
    o.OrderID,
    o.OrderDate,
    c.FullName,
    p.ProductName,
    l.Quantity,
    l.UnitPrice,
    CAST(l.Quantity * l.UnitPrice AS decimal(14,2)) AS LineTotal
FROM dbo.SalesOrder AS o
INNER JOIN dbo.Customer AS c
    ON c.CustomerID = o.CustomerID
INNER JOIN dbo.SalesOrderLine AS l
    ON l.OrderID = o.OrderID
INNER JOIN dbo.Product AS p
    ON p.ProductID = l.ProductID
ORDER BY o.OrderID, l.OrderLineNo;
```

`ON` mô tả quan hệ giữa hai nguồn. Nếu bỏ điều kiện join hoặc viết sai key, số row có thể nhân lên thành Cartesian product.

## 10. `LEFT JOIN`: giữ mọi dòng bên trái

Yêu cầu: hiển thị mọi khách hàng, kể cả người chưa có đơn.

```sql
SELECT
    c.CustomerID,
    c.FullName,
    COUNT(o.OrderID) AS OrderCount
FROM dbo.Customer AS c
LEFT JOIN dbo.SalesOrder AS o
    ON o.CustomerID = c.CustomerID
GROUP BY c.CustomerID, c.FullName
ORDER BY c.CustomerID;
```

Dùng `COUNT(o.OrderID)`, không dùng `COUNT(*)`, vì row khách chưa có đơn vẫn tồn tại sau `LEFT JOIN` nhưng `o.OrderID` là `NULL`.

### Bẫy biến `LEFT JOIN` thành `INNER JOIN`

Mục tiêu của ví dụ sau là cho thấy vị trí đặt điều kiện lọc có thể làm mất những dòng “không khớp” mà `LEFT JOIN` đáng lẽ phải giữ lại.

```sql
-- WHERE loại row NULL-extended, nên khách chưa có đơn biến mất.
SELECT c.FullName, o.OrderID
FROM dbo.Customer AS c
LEFT JOIN dbo.SalesOrder AS o
    ON o.CustomerID = c.CustomerID
WHERE o.OrderStatus = 'Paid';

-- Nếu muốn giữ mọi khách, đưa filter phía phải vào ON.
SELECT c.FullName, o.OrderID
FROM dbo.Customer AS c
LEFT JOIN dbo.SalesOrder AS o
    ON o.CustomerID = c.CustomerID
   AND o.OrderStatus = 'Paid';
```

## 11. Chọn loại phép nối

| Yêu cầu của bài toán | Chọn |
|---|---|
| Chỉ lấy row có match | `INNER JOIN` |
| Giữ mọi row phía trái, match nếu có | `LEFT JOIN` |
| Giữ mọi row phía phải | `RIGHT JOIN` hoặc đổi vị trí và dùng `LEFT JOIN` |
| Giữ mọi row từ cả hai phía | `FULL OUTER JOIN` |
| Mọi tổ hợp có thể | `CROSS JOIN` |
| Một table tự nối với chính nó | self join bằng alias khác nhau |

---

# PHẦN 5 — TÍNH TỔNG HỢP, `GROUP BY` VÀ `HAVING`

## 12. Tính tổng theo đơn hàng

**Bài toán:** từ các dòng sản phẩm, tính tổng tiền, số dòng và tổng số lượng cho từng đơn hàng. `GROUP BY l.OrderID` tạo một nhóm cho mỗi đơn; các hàm `SUM` và `COUNT` tính trên từng nhóm đó.

```sql
SELECT
    l.OrderID,
    SUM(l.Quantity * l.UnitPrice) AS OrderTotal,
    COUNT(*) AS LineCount,
    SUM(l.Quantity) AS TotalQuantity
FROM dbo.SalesOrderLine AS l
GROUP BY l.OrderID
ORDER BY l.OrderID;
```

Đầu ra có một dòng cho mỗi `OrderID`, không còn một dòng cho mỗi sản phẩm. Đây là khác biệt quan trọng giữa truy vấn tổng hợp và truy vấn chi tiết.

Mọi cột trong `SELECT` phải:

- nằm trong hàm tổng hợp như `SUM`, `COUNT`, `AVG`, `MIN`, `MAX`; hoặc
- xuất hiện trong `GROUP BY`.

## 13. `WHERE` lọc từng dòng, `HAVING` lọc từng nhóm

Ví dụ sau lọc đơn hàng theo hai thời điểm khác nhau: `WHERE` loại từng dòng trước khi tính tổng, còn `HAVING` loại cả nhóm sau khi `SUM` đã được tính.

```sql
DECLARE @FromDate date = '2026-08-01';
DECLARE @MinTotal decimal(14,2) = 500000.00;

SELECT
    o.CustomerID,
    SUM(l.Quantity * l.UnitPrice) AS CustomerTotal
FROM dbo.SalesOrder AS o
INNER JOIN dbo.SalesOrderLine AS l
    ON l.OrderID = o.OrderID
WHERE o.OrderDate >= @FromDate       -- lọc row trước khi group
GROUP BY o.CustomerID
HAVING SUM(l.Quantity * l.UnitPrice) >= @MinTotal -- lọc group
ORDER BY CustomerTotal DESC;
```

---

# PHẦN 6 — TRUY VẤN CON VÀ `EXISTS`

## 14. Khách có ít nhất một đơn hàng

**Bài toán:** kiểm tra sự tồn tại, không cần lấy chi tiết đơn hàng. Với từng khách hàng ở truy vấn ngoài, `EXISTS` dừng ngay khi truy vấn con tìm thấy một đơn hàng khớp.

```sql
SELECT c.CustomerID, c.FullName
FROM dbo.Customer AS c
WHERE EXISTS
(
    SELECT 1
    FROM dbo.SalesOrder AS o
    WHERE o.CustomerID = c.CustomerID
);
```

Đây là **truy vấn con tương quan** vì nó tham chiếu `c.CustomerID` từ truy vấn ngoài. `EXISTS` chỉ cần biết có dòng hay không; giá trị `SELECT 1` không được trả ra ngoài. Với dữ liệu mẫu, An và Bình được trả về, còn Chi thì không.

## 15. Khách chưa có đơn hàng

```sql
SELECT c.CustomerID, c.FullName
FROM dbo.Customer AS c
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.SalesOrder AS o
    WHERE o.CustomerID = c.CustomerID
);
```

Đây là anti-semi pattern quan trọng. Nó tránh bẫy `NOT IN` khi tập bên trong có `NULL`.

---

# PHẦN 7 — INSERT, UPDATE, DELETE AN TOÀN

## 16. Xem trước trước khi sửa

Trước `UPDATE` hoặc `DELETE`, chạy một `SELECT` có cùng `WHERE`:

```sql
SELECT o.OrderID, o.OrderStatus
FROM dbo.SalesOrder AS o
WHERE o.OrderID = 3;

UPDATE dbo.SalesOrder
SET OrderStatus = 'Paid'
WHERE OrderID = 3;

SELECT @@ROWCOUNT AS RowsUpdated;
```

`UPDATE` hoặc `DELETE` thiếu `WHERE` tác động mọi row. Đây không phải lỗi syntax; engine sẽ làm đúng điều bạn viết.

## 17. Thực hành DML nhưng luôn hoàn tác

Khối lệnh sau cho phép bạn thử `INSERT`, `UPDATE` và `DELETE`, xem kết quả ngay trong giao dịch, rồi dùng `ROLLBACK` để đưa dữ liệu về trạng thái ban đầu.

```sql
BEGIN TRANSACTION;

INSERT dbo.Customer (FullName, Email, City)
VALUES (N'Dũng Phạm', N'dung@example.com', N'Huế');

UPDATE dbo.Product
SET UnitPrice = UnitPrice * 1.05
WHERE SKU IN ('SQL-BOOK', 'AI-BOOK');

DELETE dbo.SalesOrderLine
WHERE OrderID = 3
  AND OrderLineNo = 1;

-- Kiểm tra thay đổi trong transaction hiện tại.
SELECT * FROM dbo.Customer WHERE Email = N'dung@example.com';
SELECT * FROM dbo.Product ORDER BY ProductID;
SELECT * FROM dbo.SalesOrderLine ORDER BY OrderID, OrderLineNo;

-- Lab không giữ thay đổi.
ROLLBACK TRANSACTION;
```

---

# PHẦN 8 — GIAO DỊCH VÀ XỬ LÝ LỖI

## 18. Tính nguyên tử

Một đơn hàng và các dòng của nó phải cùng thành công hoặc cùng thất bại. Đó là **atomicity**.

```sql
SET XACT_ABORT ON;
GO

DECLARE @NewOrderID bigint;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT dbo.SalesOrder (CustomerID, OrderDate, OrderStatus)
    VALUES (3, '2026-08-09', 'New');

    SET @NewOrderID = SCOPE_IDENTITY();

    INSERT dbo.SalesOrderLine
        (OrderID, OrderLineNo, ProductID, Quantity, UnitPrice)
    VALUES
        (@NewOrderID, 1, 2, 1, 420000.00);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
```

Ý nghĩa:

- `BEGIN TRANSACTION` bắt đầu logical unit of work.
- `COMMIT` xác nhận toàn bộ thay đổi.
- `ROLLBACK` hoàn tác transaction chưa commit.
- `XACT_STATE()` cho biết transaction còn hợp lệ để commit (`1`), không thể commit (`-1`), hay không có transaction (`0`).
- `THROW` ném lại lỗi gốc để caller biết thao tác thất bại.
- `SET XACT_ABORT ON` giúp nhiều runtime errors tự đánh dấu/rollback transaction; vẫn cần `TRY...CATCH` để kiểm soát cleanup và error flow.

Phần nâng cao và các bẫy chi tiết nằm trong file Programmability & Advanced T-SQL.

---

# PHẦN 9 — KIỂU DỮ LIỆU VÀ CHUYỂN ĐỔI KIỂU

## 19. Chọn kiểu dữ liệu theo ý nghĩa của dữ liệu

| Dữ liệu | Gợi ý | Tránh |
|---|---|---|
| Số nguyên | `tinyint`, `smallint`, `int`, `bigint` theo range | dùng `bigint` cho mọi thứ |
| Tiền/chính xác thập phân | `decimal(p,s)` | `float` khi cần số thập phân chính xác |
| Chuỗi Unicode | `nvarchar(n)` | `varchar` nếu phải lưu nhiều ngôn ngữ |
| Ngày | `date` | lưu ngày trong string |
| Ngày + giờ | `datetime2` | mặc định chọn `datetime` cũ |
| Cờ true/false | `bit` | string `'yes'/'no'` không constraint |

## 20. Chuyển đổi kiểu dữ liệu rõ ràng

**Bài toán:** dữ liệu nhập vào đang là chuỗi, nhưng phép tính cần số thập phân và ngày. Ví dụ so sánh `CAST` với `TRY_CONVERT`, đặc biệt ở trường hợp dữ liệu ngày không hợp lệ.

```sql
DECLARE @TextPrice varchar(20) = '420000.50';

SELECT
    CAST(@TextPrice AS decimal(12,2)) AS PriceWithCast,
    TRY_CONVERT(date, '2026-08-09', 23) AS SafeIsoDate,
    TRY_CONVERT(date, 'not-a-date', 23) AS InvalidBecomesNull;
```

Hai cột đầu trả về `420000.50` và ngày `2026-08-09`; cột cuối trả `NULL` thay vì làm cả truy vấn lỗi. `TRY_CONVERT` trả `NULL` khi chuyển đổi thất bại trong trường hợp được phép, còn `CONVERT`/`CAST` thường ném lỗi. Ở môi trường thật, không được xem `NULL` im lặng là đủ; hãy kiểm tra và ghi nhật ký dữ liệu lỗi.

### SARGability cơ bản

Tránh bọc indexed column trong function nếu có thể viết range tương đương:

```sql
-- Kém thuận lợi hơn cho index seek.
WHERE YEAR(OrderDate) = 2026;

-- Thường tốt hơn.
WHERE OrderDate >= '2026-01-01'
  AND OrderDate <  '2027-01-01';
```

---

# PHẦN 10 — 12 BẪY NỀN TẢNG

1. Không có `ORDER BY` nhưng tin rằng row luôn trả theo cùng thứ tự.
2. Dùng `= NULL` thay vì `IS NULL`.
3. Dùng `COUNT(*)` sau `LEFT JOIN` khi muốn đếm row khớp phía phải.
4. Đặt filter của table bên phải trong `WHERE`, vô tình làm mất row của `LEFT JOIN`.
5. Quên điều kiện `JOIN`, tạo Cartesian product.
6. Dùng `WHERE` để lọc aggregate thay vì `HAVING`.
7. Dùng `NOT IN` với subquery có thể chứa `NULL`.
8. Dùng `float` cho số tiền chính xác.
9. Dùng string cho date và phụ thuộc locale; ưu tiên ISO `yyyy-MM-dd` hoặc typed parameter.
10. `UPDATE`/`DELETE` thiếu `WHERE` nhưng tưởng engine sẽ cảnh báo.
11. Ghép input người dùng vào dynamic SQL; phải parameterize.
12. Bắt lỗi rồi không `ROLLBACK` hoặc không `THROW`, khiến caller tưởng thao tác thành công.

---

# PHẦN 11 — BÀI TỰ LUYỆN

## Bài 1

Liệt kê sản phẩm active có giá từ 400.000, giá giảm dần.

<details>
<summary>Đáp án</summary>

```sql
SELECT ProductID, SKU, ProductName, UnitPrice
FROM dbo.Product
WHERE IsActive = 1
  AND UnitPrice >= 400000.00
ORDER BY UnitPrice DESC;
```

</details>

## Bài 2

Hiển thị mọi khách hàng và tổng tiền đã đặt; khách chưa đặt hàng phải có tổng bằng 0.

<details>
<summary>Đáp án</summary>

```sql
SELECT
    c.CustomerID,
    c.FullName,
    COALESCE(SUM(l.Quantity * l.UnitPrice), 0) AS TotalOrdered
FROM dbo.Customer AS c
LEFT JOIN dbo.SalesOrder AS o
    ON o.CustomerID = c.CustomerID
LEFT JOIN dbo.SalesOrderLine AS l
    ON l.OrderID = o.OrderID
GROUP BY c.CustomerID, c.FullName
ORDER BY c.CustomerID;
```

</details>

## Bài 3

Tìm khách chưa có bất kỳ đơn hàng nào bằng `NOT EXISTS`.

<details>
<summary>Đáp án</summary>

```sql
SELECT c.CustomerID, c.FullName
FROM dbo.Customer AS c
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.SalesOrder AS o
    WHERE o.CustomerID = c.CustomerID
);
```

</details>

## Bài 4

Viết transaction tạo một order và một line; khi line vi phạm constraint thì không được giữ order rỗng.

Gợi ý: dùng template `TRY...CATCH`, `XACT_STATE()`, `ROLLBACK`, `THROW` ở phần 18 rồi cố tình đặt `Quantity = 0` để quan sát lỗi.

---

# PHẦN 12 — DANH SÁCH TỰ KIỂM TRA VÀ ĐƯỜNG HỌC TIẾP

Bạn có thể chuyển sang các chương DP-800 chính khi tự trả lời “Có” cho tất cả:

- [ ] Tạo và đặt lại được bốn bảng của bài thực hành.
- [ ] Viết được query có `WHERE`, `ORDER BY` và typed parameter.
- [ ] Giải thích được vì sao `= NULL` sai.
- [ ] Viết được `INNER JOIN` và `LEFT JOIN` đúng key.
- [ ] Phân biệt được `WHERE` và `HAVING`.
- [ ] Viết được aggregate theo group.
- [ ] Dùng được `EXISTS`/`NOT EXISTS`.
- [ ] Viết `UPDATE`/`DELETE` có kiểm tra phạm vi row.
- [ ] Viết được transaction có `TRY...CATCH`, `ROLLBACK` và `THROW`.

Thứ tự học tiếp:

1. Database Objects.
2. Programmability & Advanced T-SQL.
3. Security, Performance, CI/CD và Azure Integration.
4. Models/Embeddings, Intelligent Search và RAG.

---

# TÀI LIỆU MICROSOFT CHÍNH THỨC

1. [Query and modify data with Transact-SQL — learning path cho người mới](https://learn.microsoft.com/en-us/training/paths/get-started-querying-with-transact-sql/)
2. [Tutorial: Write Transact-SQL statements](https://learn.microsoft.com/en-us/sql/t-sql/tutorial-writing-transact-sql-statements?view=sql-server-ver17)
3. [SELECT examples](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-examples-transact-sql?view=sql-server-ver17)
4. [Combine multiple tables with JOINs in T-SQL](https://learn.microsoft.com/en-us/training/modules/query-multiple-tables-with-joins/)
5. [Use built-in functions and GROUP BY](https://learn.microsoft.com/en-us/training/modules/use-built-functions-transact-sql/)
6. [Write subqueries in T-SQL](https://learn.microsoft.com/en-us/training/modules/write-subqueries/)
7. [Implement transactions with Transact-SQL](https://learn.microsoft.com/en-us/training/modules/implement-transactions-transact-sql/)
8. [DP-800: Write advanced T-SQL code](https://learn.microsoft.com/en-us/training/modules/write-advanced-sql-code/)

> Microsoft Learn và SQL documentation là nguồn chuẩn khi syntax/availability thay đổi. Chương này cố ý chỉ dùng nền tảng T-SQL ổn định; các tính năng SQL Server 2025/Preview được giải thích và gắn nhãn trong từng file domain tương ứng.
