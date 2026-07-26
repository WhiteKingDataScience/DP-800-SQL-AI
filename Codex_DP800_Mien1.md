# DP-800 — Thiết kế và phát triển giải pháp cơ sở dữ liệu

> Miền kỹ năng chiếm khoảng **35–40%**. Nội dung hiện hành còn bao gồm **SEQUENCE** và **stored procedure** ngoài các chủ đề thường gặp.

## 1. Bảng, kiểu dữ liệu và ràng buộc

- Chọn kiểu dữ liệu nhỏ nhất nhưng đủ dùng.
- Dùng `date` nếu không cần giờ; `datetime2` thay cho `datetime`.
- Dùng `decimal(p,s)` cho tiền và số chính xác.
- `PRIMARY KEY`: định danh bản ghi, không cho `NULL`.
- `FOREIGN KEY`: bảo đảm toàn vẹn tham chiếu.
- `UNIQUE`: chống trùng.
- `CHECK`: giới hạn miền giá trị.
- `DEFAULT`: giá trị mặc định.

```sql
CREATE TABLE dbo.Customer
(
    CustomerId int IDENTITY PRIMARY KEY,
    CustomerCode varchar(20) NOT NULL,
    FullName nvarchar(100) NOT NULL,
    CreditLimit decimal(18,2) NOT NULL,
    IsActive bit NOT NULL DEFAULT 1,
    CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT UQ_Customer_Code UNIQUE (CustomerCode),
    CONSTRAINT CK_Customer_CreditLimit CHECK (CreditLimit >= 0)
);
```

## 2. Chỉ mục

- **Clustered index**: tối đa một trên bảng; xác định cách dữ liệu được tổ chức.
- **Nonclustered index**: cấu trúc tra cứu riêng, tăng tốc đọc nhưng làm tăng chi phí ghi.
- Cột đứng đầu index phải phù hợp với điều kiện lọc phổ biến.
- `INCLUDE` tạo covering index mà không thêm cột vào khóa.
- Filtered index phù hợp với một tập con dữ liệu thường xuyên truy vấn.

```sql
CREATE INDEX IX_SalesOrder_Customer_Date
ON dbo.SalesOrder(CustomerId, OrderDate DESC)
INCLUDE (Status);

CREATE INDEX IX_Customer_Active
ON dbo.Customer(CustomerCode)
WHERE IsActive = 1;
```

## 3. Columnstore

Phù hợp với kho dữ liệu, bảng fact lớn và truy vấn tổng hợp nhiều dòng. Không mặc định phù hợp với OLTP cập nhật từng dòng.

```sql
CREATE TABLE dbo.SalesFact
(
    SalesId bigint,
    CustomerId int,
    ProductId int,
    SaleDate date,
    Quantity int,
    Amount decimal(18,2)
);

CREATE CLUSTERED COLUMNSTORE INDEX CCI_SalesFact
ON dbo.SalesFact;
```

## 4. JSON

Dùng cho dữ liệu bán cấu trúc. Có thể kiểm tra JSON bằng `ISJSON`, đọc thuộc tính bằng `JSON_VALUE` và đọc mảng bằng `OPENJSON`.

```sql
CREATE TABLE dbo.CustomerProfile
(
    CustomerId int PRIMARY KEY,
    Preferences nvarchar(max) NOT NULL,
    CONSTRAINT CK_Profile_Json CHECK (ISJSON(Preferences) = 1)
);

SELECT
    JSON_VALUE(Preferences, '$.language') AS Language
FROM dbo.CustomerProfile;

SELECT value AS Interest
FROM dbo.CustomerProfile
CROSS APPLY OPENJSON(Preferences, '$.interests');
```

Tạo index JSON theo cách tương thích rộng bằng computed column:

```sql
ALTER TABLE dbo.CustomerProfile
ADD PreferredLanguage AS JSON_VALUE(Preferences, '$.language');

CREATE INDEX IX_Profile_Language
ON dbo.CustomerProfile(PreferredLanguage);
```

## 5. SEQUENCE

Dùng khi cần sinh số độc lập với một bảng hoặc dùng chung cho nhiều bảng.

```sql
CREATE SEQUENCE dbo.InvoiceSequence
    AS bigint START WITH 100000 INCREMENT BY 1 CACHE 100;

SELECT NEXT VALUE FOR dbo.InvoiceSequence;
```

Sequence có thể có khoảng trống nếu transaction rollback hoặc server khởi động lại.

## 6. Phân vùng

Phân vùng chia bảng lớn theo chiều ngang, thường theo ngày/tháng/quý. Nó hỗ trợ quản trị và loại bỏ partition khi truy vấn có điều kiện trên partition key.

```sql
CREATE PARTITION FUNCTION pf_SalesDate(date)
AS RANGE RIGHT FOR VALUES
('2026-01-01', '2026-04-01', '2026-07-01', '2026-10-01');
GO

CREATE PARTITION SCHEME ps_SalesDate
AS PARTITION pf_SalesDate ALL TO ([PRIMARY]);
GO

CREATE TABLE dbo.PartitionedSales
(
    SalesId bigint NOT NULL,
    SaleDate date NOT NULL,
    Amount decimal(18,2) NOT NULL,
    CONSTRAINT PK_PartitionedSales PRIMARY KEY CLUSTERED (SaleDate, SalesId)
)
ON ps_SalesDate(SaleDate);
```

`RANGE RIGHT`: giá trị đúng bằng boundary thuộc partition bên phải. Có `n` boundary thì tạo `n + 1` partition.

## 7. Temporal table

Tự động lưu lịch sử thay đổi, phù hợp cho audit và truy vấn dữ liệu tại thời điểm quá khứ.

```sql
CREATE TABLE dbo.Employee
(
    EmployeeId int PRIMARY KEY,
    FullName nvarchar(100) NOT NULL,
    Salary decimal(18,2) NOT NULL,
    ValidFrom datetime2 GENERATED ALWAYS AS ROW START NOT NULL,
    ValidTo datetime2 GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON);

SELECT *
FROM dbo.Employee
FOR SYSTEM_TIME ALL;
```

## 8. Bảng chuyên biệt

| Loại | Khi sử dụng |
|---|---|
| Memory-optimized | OLTP độ trễ thấp, đồng thời cao; cần đánh giá bộ nhớ |
| Temporal | Lưu lịch sử tự động |
| Graph node/edge | Quan hệ dạng mạng, nhiều-nhiều |
| External | Truy cập dữ liệu bên ngoài |
| Ledger | Bằng chứng chống sửa đổi, tuân thủ |
| Columnstore | Phân tích dữ liệu lớn |

```sql
CREATE TABLE dbo.Person
(
    PersonId int,
    PersonName nvarchar(100)
) AS NODE;

CREATE TABLE dbo.Friend
(
    SinceDate date
) AS EDGE;
```

## 9. View, function và stored procedure

### View

```sql
CREATE VIEW dbo.vw_OrderSummary
AS
SELECT CustomerId, COUNT(*) AS OrderCount
FROM dbo.SalesOrder
GROUP BY CustomerId;
```

### Scalar function

```sql
CREATE FUNCTION dbo.fn_Vat
(
    @Amount decimal(18,2),
    @Rate decimal(5,2)
)
RETURNS decimal(18,2)
AS
BEGIN
    RETURN @Amount * @Rate / 100;
END;
```

### Inline table-valued function

```sql
CREATE FUNCTION dbo.fn_OrdersByCustomer(@CustomerId int)
RETURNS TABLE
AS
RETURN
(
    SELECT OrderId, OrderDate, Status
    FROM dbo.SalesOrder
    WHERE CustomerId = @CustomerId
);
```

### Stored procedure

```sql
CREATE PROCEDURE dbo.usp_GetOrders
    @CustomerId int,
    @FromDate date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT OrderId, OrderDate, Status
    FROM dbo.SalesOrder
    WHERE CustomerId = @CustomerId
      AND (@FromDate IS NULL OR OrderDate >= @FromDate);
END;
```

Function thường trả về giá trị/result set; stored procedure phù hợp hơn cho quy trình nghiệp vụ nhiều bước và phân quyền thực thi.

## 10. Trigger

`inserted` chứa dữ liệu mới; `deleted` chứa dữ liệu cũ. Trigger phải xử lý nhiều dòng.

```sql
CREATE TRIGGER dbo.trg_Order_Audit
ON dbo.SalesOrder
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.OrderAudit(OrderId, OldStatus, NewStatus)
    SELECT d.OrderId, d.Status, i.Status
    FROM deleted d
    JOIN inserted i ON i.OrderId = d.OrderId
    WHERE ISNULL(d.Status, '') <> ISNULL(i.Status, '');
END;
```

Tránh trigger quá phức tạp vì có thể làm chậm transaction hoặc gây deadlock.

## Bẫy thường gặp trong đề thi

1. Primary key mặc định thường là clustered nhưng không bắt buộc phải clustered.
2. Partitioning không tự động làm mọi truy vấn nhanh hơn.
3. Columnstore dành chủ yếu cho analytics; rowstore phù hợp hơn với OLTP thông thường.
4. `RANGE RIGHT` và `RANGE LEFT` phân loại boundary khác nhau.
5. Trigger phải xử lý theo tập hợp, không giả định chỉ có một dòng.
6. JSON hợp lệ không bảo đảm thuộc tính có đúng kiểu nghiệp vụ.
7. Temporal table tự ghi lịch sử, không cần trigger cho cùng mục đích.
8. Sequence có thể tạo khoảng trống.
9. `INCLUDE` không thay thế các cột khóa dùng để tìm kiếm.
10. Chọn object dựa trên workload: OLTP, analytics, lịch sử, graph hay bán cấu trúc.

## Bài lab tổng hợp

Xây dựng cơ sở dữ liệu bán hàng gồm:

- `Customer`, `Product`, `SalesOrder`, `SalesOrderDetail`.
- Primary key, foreign key, unique, check, default.
- Index tra cứu đơn hàng theo khách hàng.
- JSON lưu tùy chọn khách hàng.
- View tổng hợp doanh thu.
- Inline TVF tìm đơn hàng.
- Stored procedure tạo/truy vấn đơn hàng.
- Trigger audit trạng thái.
- Temporal table cho dữ liệu cần lịch sử.
- Partition theo ngày hoặc quý.
- Columnstore cho bảng fact.

### Tài liệu Microsoft

- [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
- [DP-800T00-A](https://learn.microsoft.com/en-us/training/courses/dp-800t00)
- [Partitioned tables and indexes](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/create-partitioned-tables-and-indexes)
- [Memory-optimized tables](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/introduction-to-memory-optimized-tables)
- [SQL Graph](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-table-sql-graph)
