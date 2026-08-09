# DP-800 Domain 1: Design and Implement Database Objects

> **Domain:** Design and develop database solutions (35–40%)  
> **Skill:** Design and implement database objects  
> **Ưu tiên cá nhân:** Đây là **Top 3 skill cần cải thiện** theo score report của bạn.  
> **Cập nhật:** 09/08/2026 — đối chiếu blueprint DP-800 và Microsoft Learn hiện hành.

## Mục tiêu sau khi học xong

Bạn phải làm được cả ba việc:

1. **Nhận diện requirement** và chọn đúng object/index/table type.
2. **Viết được cú pháp T-SQL cốt lõi** mà không cần nhìn tài liệu.
3. **Giải thích vì sao các lựa chọn còn lại sai** trong câu hỏi scenario.

Blueprint chính thức yêu cầu:

- Design and implement tables, including data types, size, columns, indexes, and columnstore indexes.
- Design and implement specialized tables: in-memory, temporal, external, ledger, graph.
- Design and implement JSON columns and indexes.
- Design and implement PRIMARY KEY, FOREIGN KEY, UNIQUE, CHECK, DEFAULT.
- Design and implement SEQUENCES.
- Design and implement partitioning for tables and indexes.

Nguồn: [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)

---

# PHẦN 1 — TABLE DESIGN, DATA TYPES VÀ ROWSTORE INDEXES

## 1.1 Chọn data type đúng

Nguyên tắc: chọn **kiểu nhỏ nhất nhưng vẫn đúng semantics và đủ range**.

### Integer

| Type | Range / Ghi nhớ |
|---|---|
| `TINYINT` | 0–255 |
| `SMALLINT` | khoảng ±32 nghìn |
| `INT` | khoảng ±2.1 tỷ |
| `BIGINT` | rất lớn, dùng khi `INT` không đủ |

Không dùng `BIGINT` chỉ “cho chắc” nếu bảng rất lớn và column đó xuất hiện trong nhiều index: key lớn làm index rộng hơn.

### Decimal / money

Ưu tiên `DECIMAL(p,s)` khi cần độ chính xác xác định, ví dụ tiền:

```sql
Amount DECIMAL(19,4)
```

Không dùng `FLOAT` cho giá trị tài chính cần so sánh/chính xác tuyệt đối vì `FLOAT` là approximate numeric.

### Character

- `VARCHAR(n)`: dữ liệu non-Unicode.
- `NVARCHAR(n)`: Unicode.
- `VARCHAR(MAX)`/`NVARCHAR(MAX)`: chỉ dùng khi thực sự cần LOB; tránh mặc định dùng `MAX`.

### Date/time

- `DATE`: chỉ ngày.
- `TIME`: chỉ thời gian.
- `DATETIME2`: lựa chọn hiện đại cho timestamp.
- `DATETIMEOFFSET`: cần lưu offset.

### NULL

`NULL` nghĩa là **unknown / missing**, không phải chuỗi rỗng và không phải 0.

```sql
-- Sai
WHERE MiddleName = NULL;

-- Đúng
WHERE MiddleName IS NULL;
```

---

## 1.2 Computed column

```sql
CREATE TABLE dbo.OrderLine
(
    OrderLineId BIGINT IDENTITY(1,1) PRIMARY KEY,
    UnitPrice   DECIMAL(19,4) NOT NULL,
    Quantity    INT NOT NULL,
    TotalAmount AS (UnitPrice * Quantity) PERSISTED
);
```

`PERSISTED` lưu giá trị tính toán vật lý và hữu ích khi muốn index computed expression, miễn expression đáp ứng yêu cầu cần thiết.

```sql
CREATE INDEX IX_OrderLine_TotalAmount
ON dbo.OrderLine(TotalAmount);
```

---

## 1.3 Sparse column

Sparse column tối ưu storage cho cột có tỷ lệ `NULL` cao, nhưng có overhead đối với non-null values. Không dùng chỉ vì “có NULL”.

```sql
CREATE TABLE dbo.CustomerOptional
(
    CustomerId INT PRIMARY KEY,
    FaxNumber  VARCHAR(30) SPARSE NULL,
    AltPhone   VARCHAR(30) SPARSE NULL
);
```

---

## 1.4 Clustered vs nonclustered rowstore index

### Clustered index

- Leaf level chứa chính rows của table.
- Một table chỉ có một clustered index.
- Rows được tổ chức theo clustered key ở leaf level.
- **Không nên diễn giải thành “SQL cố định thứ tự vật lý trên đĩa”.**

```sql
CREATE CLUSTERED INDEX CX_Orders_OrderDate_OrderId
ON dbo.Orders(OrderDate, OrderId);
```

### Nonclustered index

```sql
CREATE NONCLUSTERED INDEX IX_Orders_Customer_OrderDate
ON dbo.Orders(CustomerId, OrderDate);
```

### Covering index với INCLUDE

```sql
CREATE NONCLUSTERED INDEX IX_Orders_Customer_OrderDate
ON dbo.Orders(CustomerId, OrderDate)
INCLUDE (Status, TotalAmount);
```

### Filtered index

```sql
CREATE NONCLUSTERED INDEX IX_Orders_Open
ON dbo.Orders(CustomerId, OrderDate)
INCLUDE (TotalAmount)
WHERE Status = 'Open';
```

---

# PHẦN 2 — COLUMNSTORE INDEXES

Nguồn:
- [CREATE COLUMNSTORE INDEX](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-columnstore-index-transact-sql?view=sql-server-ver17)
- [Ordered columnstore indexes](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/ordered-columnstore-indexes?view=sql-server-ver17)

## 2.1 Khi nào dùng?

Dấu hiệu mạnh:

- Data warehouse / fact table lớn.
- Scan nhiều rows nhưng chỉ vài columns.
- `SUM`, `AVG`, `COUNT`, `GROUP BY`.
- Batch analytics.
- Compression quan trọng.

### Clustered Columnstore Index — CCI

```sql
CREATE TABLE dbo.FactSales
(
    SalesId      BIGINT NOT NULL,
    OrderDateKey INT NOT NULL,
    ProductKey   INT NOT NULL,
    CustomerKey  INT NOT NULL,
    Quantity     INT NOT NULL,
    SalesAmount  DECIMAL(19,4) NOT NULL
);

CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactSales
ON dbo.FactSales;
```

### Nonclustered Columnstore Index — NCCI

```sql
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_Orders_Analytics
ON dbo.Orders(OrderDate, CustomerId, Status, TotalAmount);
```

Cách nhớ:
- **CCI**: analytics-first.
- **NCCI**: OLTP table + analytics sidecar.

---

## 2.2 Rowgroup, segment, delta store, tuple mover

- **Compressed rowgroup**: dữ liệu đã columnar/compressed.
- **Segment**: dữ liệu một column bên trong rowgroup.
- **Delta store**: rowstore tạm cho các insert nhỏ/chưa đủ điều kiện nén.
- **Tuple mover**: background process giúp chuyển closed delta rowgroups sang compressed columnstore.
- **Deleted bitmap**: đánh dấu rows bị xóa.
- **Segment elimination**: bỏ qua segment dựa vào metadata min/max.

Rowgroup tối đa khoảng **1,048,576 rows**.

---

## 2.3 Ordered CCI / NCCI

```sql
CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactSales
ON dbo.FactSales
ORDER (OrderDateKey, ProductKey);
```

SQL Server 2025 hỗ trợ ordered NCCI trong các scenario tương ứng:

```sql
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_Orders_Analytics
ON dbo.Orders(OrderDate, CustomerId, Status, TotalAmount)
ORDER (OrderDate, CustomerId);
```

Bẫy:
- `ORDER` của columnstore không giống clustered B-tree order từng row.
- Mục tiêu là cải thiện segment organization/elimination.
- `MAXDOP = 1` có thể tăng chất lượng ordering nhưng build lâu hơn.

---

# PHẦN 3 — SPECIALIZED TABLES

## 3.1 In-Memory OLTP / Memory-Optimized Table

Nguồn:
- [Introduction to Memory-Optimized Tables](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/introduction-to-memory-optimized-tables?view=sql-server-ver17)
- [Requirements for In-Memory OLTP](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/requirements-for-using-memory-optimized-tables?view=sql-server-ver17)

### Khi nào chọn?

- OLTP concurrency cao.
- Latency thấp.
- Hot tables.
- Contention trở thành bottleneck.
- Có đủ memory và platform hỗ trợ.

### Durability

- `SCHEMA_AND_DATA`: durable.
- `SCHEMA_ONLY`: data không survive restart.

### SQL Server on-prem: memory-optimized filegroup

```sql
CREATE DATABASE DP800_InMemory;
GO

ALTER DATABASE DP800_InMemory
ADD FILEGROUP DP800_InMemory_mod
CONTAINS MEMORY_OPTIMIZED_DATA;
GO

ALTER DATABASE DP800_InMemory
ADD FILE
(
    NAME = DP800_InMemory_mod1,
    FILENAME = 'C:\SQLData\DP800_InMemory_mod1'
)
TO FILEGROUP DP800_InMemory_mod;
GO
```

### Memory-optimized table

```sql
USE DP800_InMemory;
GO

CREATE TABLE dbo.SessionState
(
    SessionId UNIQUEIDENTIFIER NOT NULL
        PRIMARY KEY NONCLUSTERED,
    UserId    INT NOT NULL,
    Payload   NVARCHAR(1000) NULL,
    UpdatedAt DATETIME2(3) NOT NULL,

    INDEX IX_SessionState_UserId
        NONCLUSTERED (UserId)
)
WITH
(
    MEMORY_OPTIMIZED = ON,
    DURABILITY = SCHEMA_AND_DATA
);
GO
```

Hash index:

```sql
CREATE TABLE dbo.HotLookup
(
    LookupId INT NOT NULL
        PRIMARY KEY NONCLUSTERED HASH
        WITH (BUCKET_COUNT = 100000),
    ValueText NVARCHAR(100) NOT NULL
)
WITH
(
    MEMORY_OPTIMIZED = ON,
    DURABILITY = SCHEMA_AND_DATA
);
```

---

## 3.2 Temporal Table — System-Versioned

Nguồn:
- [Create a system-versioned temporal table](https://learn.microsoft.com/en-us/sql/relational-databases/tables/creating-a-system-versioned-temporal-table?view=sql-server-ver17)
- [Query temporal data](https://learn.microsoft.com/en-us/sql/relational-databases/tables/querying-data-in-a-system-versioned-temporal-table?view=sql-server-ver17)

### Use case

- Point-in-time reconstruction.
- History tự động.
- “Row này có giá trị gì vào thời điểm X?”

### Yêu cầu

- Current table có `PRIMARY KEY`.
- `PERIOD FOR SYSTEM_TIME`.
- Hai `DATETIME2` columns `ROW START` và `ROW END`.

```sql
CREATE TABLE dbo.EmployeeSalary
(
    EmployeeId INT NOT NULL
        CONSTRAINT PK_EmployeeSalary PRIMARY KEY,
    EmployeeName NVARCHAR(100) NOT NULL,
    Salary DECIMAL(19,2) NOT NULL,

    ValidFrom DATETIME2(7)
        GENERATED ALWAYS AS ROW START
        NOT NULL
        CONSTRAINT DF_EmployeeSalary_ValidFrom
        DEFAULT SYSUTCDATETIME(),

    ValidTo DATETIME2(7)
        GENERATED ALWAYS AS ROW END
        NOT NULL
        CONSTRAINT DF_EmployeeSalary_ValidTo
        DEFAULT CONVERT(DATETIME2(7), '9999-12-31 23:59:59.9999999'),

    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH
(
    SYSTEM_VERSIONING = ON
    (
        HISTORY_TABLE = dbo.EmployeeSalaryHistory
    )
);
GO
```

DML:

```sql
INSERT dbo.EmployeeSalary(EmployeeId, EmployeeName, Salary)
VALUES (1, N'An', 3000);

UPDATE dbo.EmployeeSalary
SET Salary = 3500
WHERE EmployeeId = 1;
```

Queries:

```sql
SELECT *
FROM dbo.EmployeeSalary
FOR SYSTEM_TIME AS OF '2026-08-01T12:00:00'
WHERE EmployeeId = 1;

SELECT *
FROM dbo.EmployeeSalary
FOR SYSTEM_TIME FROM '2026-08-01' TO '2026-08-31';

SELECT *
FROM dbo.EmployeeSalary
FOR SYSTEM_TIME BETWEEN '2026-08-01' AND '2026-08-31';

SELECT *
FROM dbo.EmployeeSalary
FOR SYSTEM_TIME CONTAINED IN ('2026-08-01', '2026-08-31');

SELECT *
FROM dbo.EmployeeSalary
FOR SYSTEM_TIME ALL;
```

Tắt:

```sql
ALTER TABLE dbo.EmployeeSalary
SET (SYSTEM_VERSIONING = OFF);
```

---

## 3.3 Ledger Table

Nguồn:
- [Updatable ledger tables](https://learn.microsoft.com/en-us/sql/relational-databases/security/ledger/ledger-how-to-updatable-ledger-tables?view=sql-server-ver17)
- [Verify ledger](https://learn.microsoft.com/en-us/sql/relational-databases/security/ledger/ledger-verify-database?view=sql-server-ver17)

### Keyword

- tamper-evident
- cryptographic digest
- verify integrity
- compliance audit

```sql
CREATE SCHEMA Account;
GO

CREATE TABLE Account.Balance
(
    CustomerId INT NOT NULL
        PRIMARY KEY CLUSTERED,
    LastName   VARCHAR(50) NOT NULL,
    FirstName  VARCHAR(50) NOT NULL,
    Balance    DECIMAL(10,2) NOT NULL
)
WITH
(
    SYSTEM_VERSIONING = ON
    (
        HISTORY_TABLE = Account.BalanceHistory
    ),
    LEDGER = ON
);
GO
```

Query ledger view:

```sql
SELECT
    t.commit_time,
    t.principal_name,
    l.CustomerId,
    l.Balance,
    l.ledger_operation_type_desc
FROM Account.Balance_Ledger AS l
JOIN sys.database_ledger_transactions AS t
  ON t.transaction_id = l.ledger_transaction_id
ORDER BY t.commit_time DESC;
```

**Temporal vs Ledger**
- Temporal = time history.
- Ledger = tamper evidence + integrity verification.

---

## 3.4 Graph Tables

Nguồn: [SQL Graph sample](https://learn.microsoft.com/en-us/sql/relational-databases/graphs/sql-graph-sample?view=sql-server-ver17)

```sql
CREATE TABLE dbo.Person
(
    PersonId INT PRIMARY KEY,
    PersonName NVARCHAR(100) NOT NULL
) AS NODE;
GO

CREATE TABLE dbo.Restaurant
(
    RestaurantId INT PRIMARY KEY,
    RestaurantName NVARCHAR(100) NOT NULL
) AS NODE;
GO

CREATE TABLE dbo.Likes
(
    Rating TINYINT NULL
) AS EDGE;
GO
```

Insert:

```sql
INSERT dbo.Person(PersonId, PersonName)
VALUES (1, N'An'), (2, N'Bình');

INSERT dbo.Restaurant(RestaurantId, RestaurantName)
VALUES (10, N'Pho 24'), (20, N'Bún Bò Huế');

INSERT dbo.Likes($from_id, $to_id, Rating)
SELECT p.$node_id, r.$node_id, 5
FROM dbo.Person AS p
JOIN dbo.Restaurant AS r
  ON p.PersonId = 1
 AND r.RestaurantId = 10;
```

MATCH:

```sql
SELECT
    p.PersonName,
    r.RestaurantName,
    l.Rating
FROM dbo.Person AS p,
     dbo.Likes AS l,
     dbo.Restaurant AS r
WHERE MATCH(p-(l)->r);
```

Nhớ:
- Node: `$node_id`.
- Edge: `$edge_id`, `$from_id`, `$to_id`.

---

## 3.5 External Tables

Nguồn:
- [CREATE EXTERNAL TABLE](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-table-transact-sql?view=sql-server-ver17)
- [CREATE EXTERNAL DATA SOURCE](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-data-source-transact-sql?view=sql-server-ver17)

External table là **metadata + data virtualization**, không tự động copy data vào SQL.

```sql
CREATE DATABASE SCOPED CREDENTIAL AzureStorageCredential
WITH
(
    IDENTITY = 'SHARED ACCESS SIGNATURE',
    SECRET = '<SAS token without leading ?>'
);
GO

CREATE EXTERNAL DATA SOURCE SalesLake
WITH
(
    LOCATION = 'abs://sales@storageaccount.blob.core.windows.net/',
    CREDENTIAL = AzureStorageCredential
);
GO

CREATE EXTERNAL FILE FORMAT CsvFormat
WITH
(
    FORMAT_TYPE = DELIMITEDTEXT,
    FORMAT_OPTIONS
    (
        FIELD_TERMINATOR = ',',
        STRING_DELIMITER = '"',
        FIRST_ROW = 2
    )
);
GO

CREATE EXTERNAL TABLE dbo.ExternalSales
(
    SalesId     BIGINT,
    OrderDate   DATE,
    CustomerId  INT,
    Amount      DECIMAL(19,2)
)
WITH
(
    LOCATION = '/sales/',
    DATA_SOURCE = SalesLake,
    FILE_FORMAT = CsvFormat
);
GO
```

> Cú pháp/auth khác nhau theo SQL Server/Azure SQL/Fabric. Đọc platform trong scenario.

---

# PHẦN 4 — JSON COLUMNS VÀ INDEXES

Nguồn:
- [JSON data in SQL Server](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-data-sql-server?view=sql-server-ver17)
- [Index JSON data](https://learn.microsoft.com/en-us/sql/relational-databases/json/index-json-data?view=sql-server-ver17)
- [CREATE JSON INDEX](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-json-index-transact-sql?view=sql-server-ver17)

## 4.1 Lưu JSON

Truyền thống:

```sql
JsonText NVARCHAR(MAX)
```

Validate:

```sql
CHECK (ISJSON(JsonText) = 1)
```

Native type:

```sql
CREATE TABLE dbo.Products
(
    ProductId INT PRIMARY KEY CLUSTERED,
    Metadata json NOT NULL
);
```

### Availability phải đọc trước khi chọn đáp án

| Khả năng | Azure SQL Database | Azure SQL Managed Instance | SQL Server 2025 | SQL database in Fabric |
|---|---|---|---|---|
| Native `json` data type | GA | GA nếu dùng update policy SQL Server 2025/Always-up-to-date | Preview | Preview |
| Lưu JSON trong `nvarchar(max)` + `ISJSON` | Hỗ trợ | Hỗ trợ | Hỗ trợ | Hỗ trợ theo tài liệu nền tảng |
| `CREATE JSON INDEX` | Không suy diễn từ việc có native `json` | Không suy diễn từ việc có native `json` | **Preview, chỉ SQL Server 2025** | Không |

> **Bẫy thi:** native `json` đã GA trên một số Azure SQL products không có nghĩa `CREATE JSON INDEX` cũng GA ở đó. Theo tài liệu cú pháp hiện hành ngày 09/08/2026, `CREATE JSON INDEX` chỉ áp dụng cho SQL Server 2025 và vẫn ở Preview. Nếu platform không hỗ trợ, dùng computed column dựa trên `JSON_VALUE` rồi tạo B-tree index như mục 4.2.

---

## 4.2 Computed column + B-tree index

```sql
CREATE TABLE dbo.CustomerProfiles
(
    ProfileId INT IDENTITY(1,1)
        PRIMARY KEY,
    RawAttributes NVARCHAR(MAX) NOT NULL
        CONSTRAINT CK_CustomerProfiles_Json
        CHECK (ISJSON(RawAttributes) = 1),

    Email AS JSON_VALUE(RawAttributes, '$.email')
);
GO

CREATE INDEX IX_CustomerProfiles_Email
ON dbo.CustomerProfiles(Email);
GO
```

---

## 4.3 Native `CREATE JSON INDEX`

SQL Server 2025: Preview. Không dùng đoạn này cho Azure SQL chỉ vì Azure SQL đã có native `json` type.

```sql
CREATE TABLE dbo.SalesOrder
(
    SalesOrderId INT NOT NULL
        PRIMARY KEY CLUSTERED,
    Info json NOT NULL
);
GO

CREATE JSON INDEX IX_SalesOrder_Info
ON dbo.SalesOrder(Info)
FOR
(
    '$.Customer.ID',
    '$.Customer.Type',
    '$.Order.TotalDue'
);
GO
```

Query:

```sql
SELECT SalesOrderId
FROM dbo.SalesOrder
WHERE JSON_VALUE(Info, '$.Customer.ID' RETURNING INT) = 16167;
```

Nhớ:
- Table cần clustered PK cho native JSON index.
- Không dùng native JSON index trên indexed view.
- `ONLINE = ON` chưa được hỗ trợ cho JSON index; thao tác offline có thể giữ `Sch-M` lock.
- File cũ nói “không có JSON index trực tiếp” là lỗi thời.

---

# PHẦN 5 — CONSTRAINTS

## PRIMARY KEY

```sql
CONSTRAINT PK_Orders PRIMARY KEY (OrderId)
```

## FOREIGN KEY

```sql
CONSTRAINT FK_Orders_Customers
FOREIGN KEY (CustomerId)
REFERENCES dbo.Customers(CustomerId)
```

FK **không tự động tạo index trên FK column**.

## UNIQUE

```sql
CONSTRAINT UQ_Customers_Email UNIQUE (Email)
```

## CHECK

```sql
CONSTRAINT CK_OrderLine_Quantity
CHECK (Quantity > 0)
```

## DEFAULT

```sql
CreatedAt DATETIME2 NOT NULL
    CONSTRAINT DF_Orders_CreatedAt
    DEFAULT SYSUTCDATETIME()
```

---

## Trusted vs Untrusted FK

Sau:

```sql
ALTER TABLE dbo.Orders
WITH NOCHECK
CHECK CONSTRAINT FK_Orders_Customers;
```

FK có thể enabled nhưng untrusted.

Khôi phục:

```sql
ALTER TABLE dbo.Orders
WITH CHECK
CHECK CONSTRAINT FK_Orders_Customers;
```

Kiểm tra:

```sql
SELECT name, is_disabled, is_not_trusted
FROM sys.foreign_keys
WHERE name = 'FK_Orders_Customers';
```

---

# PHẦN 6 — SEQUENCE VS IDENTITY

## IDENTITY

```sql
OrderId BIGINT IDENTITY(1,1)
```

## SEQUENCE

```sql
CREATE SEQUENCE dbo.OrderNumberSequence
    AS BIGINT
    START WITH 100000
    INCREMENT BY 1
    CACHE 100;
GO

SELECT NEXT VALUE FOR dbo.OrderNumberSequence;
```

Dùng nhiều tables:

```sql
INSERT dbo.Orders(OrderId, CustomerId, OrderDate)
VALUES
(
    NEXT VALUE FOR dbo.OrderNumberSequence,
    42,
    SYSUTCDATETIME()
);
```

Bẫy: Sequence/Identity không bảo đảm gapless.

---

# PHẦN 7 — TABLE & INDEX PARTITIONING

Nguồn:
- [Create partitioned tables and indexes](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/create-partitioned-tables-and-indexes?view=sql-server-ver17)
- [$PARTITION](https://learn.microsoft.com/en-us/sql/t-sql/functions/partition-transact-sql?view=sql-server-ver17)

## 7.1 Quy trình

1. Partition function.
2. Partition scheme.
3. Table/index dùng scheme + partition column.

```sql
CREATE PARTITION FUNCTION PF_OrderDate (DATE)
AS RANGE RIGHT FOR VALUES
(
    '2026-01-01',
    '2026-04-01',
    '2026-07-01',
    '2026-10-01'
);
GO

CREATE PARTITION SCHEME PS_OrderDate
AS PARTITION PF_OrderDate
ALL TO ([PRIMARY]);
GO

CREATE TABLE dbo.PartitionedOrders
(
    OrderId BIGINT NOT NULL,
    OrderDate DATE NOT NULL,
    CustomerId INT NOT NULL,
    Amount DECIMAL(19,2) NOT NULL,
    CONSTRAINT PK_PartitionedOrders
        PRIMARY KEY CLUSTERED (OrderDate, OrderId)
)
ON PS_OrderDate(OrderDate);
GO
```

Partitioned index:

```sql
CREATE INDEX IX_PartitionedOrders_Customer
ON dbo.PartitionedOrders(CustomerId, OrderDate)
ON PS_OrderDate(OrderDate);
GO
```

---

## 7.2 `$PARTITION`

```sql
SELECT
    OrderDate,
    $PARTITION.PF_OrderDate(OrderDate) AS PartitionNumber
FROM dbo.PartitionedOrders;
```

---

## 7.3 SPLIT / MERGE

```sql
ALTER PARTITION FUNCTION PF_OrderDate()
SPLIT RANGE ('2027-01-01');

ALTER PARTITION FUNCTION PF_OrderDate()
MERGE RANGE ('2026-01-01');
```

Một partition function có thể được nhiều objects dùng.

---

## 7.4 SWITCH

Ví dụ hoàn chỉnh dưới đây đưa partition 2 (`2026-01-01` đến trước `2026-04-01` vì dùng `RANGE RIGHT`) sang một staging/archive table rỗng. Target nằm cùng filegroup và có schema, clustered/nonclustered indexes tương ứng:

```sql
CREATE TABLE dbo.OrderArchive
(
    OrderId BIGINT NOT NULL,
    OrderDate DATE NOT NULL,
    CustomerId INT NOT NULL,
    Amount DECIMAL(19,2) NOT NULL,
    CONSTRAINT PK_OrderArchive
        PRIMARY KEY CLUSTERED (OrderDate, OrderId),
    CONSTRAINT CK_OrderArchive_2026Q1
        CHECK
        (
            OrderDate >= CONVERT(date, '20260101', 112)
            AND OrderDate < CONVERT(date, '20260401', 112)
        )
) ON [PRIMARY];
GO

CREATE INDEX IX_OrderArchive_Customer
ON dbo.OrderArchive(CustomerId, OrderDate)
ON [PRIMARY];
GO

ALTER TABLE dbo.PartitionedOrders
SWITCH PARTITION 2
TO dbo.OrderArchive;
GO
```

Điều kiện:
- target phải rỗng,
- source/target có columns, data types, nullability và indexes tương thích,
- target/range có `CHECK` constraint phù hợp và nằm trên filegroup tương ứng,
- operation rất nhanh khi chỉ metadata nhưng vẫn có locking.

> **Bẫy:** `SWITCH` không tự copy từng row; đây chủ yếu là metadata operation. Nếu target có row, index không tương thích hoặc constraint không chứng minh được đúng boundary, lệnh thất bại.

---

# PHẦN 8 — LAB TỔNG HỢP

## 8.1 Constraints + Sequence + Filtered Index

```sql
CREATE SEQUENCE dbo.OrderSeq
AS BIGINT
START WITH 10001
INCREMENT BY 1;
GO

CREATE TABLE dbo.Orders
(
    OrderId BIGINT NOT NULL
        CONSTRAINT DF_Orders_OrderId
        DEFAULT (NEXT VALUE FOR dbo.OrderSeq),

    CustomerId INT NOT NULL,
    OrderDate DATETIME2(3) NOT NULL
        CONSTRAINT DF_Orders_OrderDate
        DEFAULT SYSUTCDATETIME(),

    UnitPrice DECIMAL(19,4) NOT NULL,
    Quantity INT NOT NULL,
    TotalAmount AS (UnitPrice * Quantity) PERSISTED,
    Status VARCHAR(20) NOT NULL,

    CONSTRAINT PK_Orders PRIMARY KEY (OrderId),
    CONSTRAINT CK_Orders_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_Orders_Status
        CHECK (Status IN ('Open','Completed','Cancelled'))
);
GO

CREATE INDEX IX_Orders_Open
ON dbo.Orders(CustomerId, OrderDate)
INCLUDE (TotalAmount)
WHERE Status = 'Open';
GO
```

## 8.2 Ordered CCI

```sql
CREATE TABLE dbo.FactTransactions
(
    TransactionId BIGINT NOT NULL,
    TransactionDate DATE NOT NULL,
    RegionId INT NOT NULL,
    ProductId INT NOT NULL,
    Amount DECIMAL(19,2) NOT NULL
);
GO

CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactTransactions
ON dbo.FactTransactions
ORDER (TransactionDate, RegionId);
GO
```

## 8.3 Temporal

```sql
CREATE TABLE dbo.ProductPrice
(
    ProductId INT NOT NULL PRIMARY KEY,
    Price DECIMAL(19,2) NOT NULL,

    ValidFrom DATETIME2(7)
        GENERATED ALWAYS AS ROW START
        NOT NULL
        DEFAULT SYSUTCDATETIME(),

    ValidTo DATETIME2(7)
        GENERATED ALWAYS AS ROW END
        NOT NULL
        DEFAULT CONVERT(DATETIME2(7),'9999-12-31 23:59:59.9999999'),

    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH
(
    SYSTEM_VERSIONING = ON
    (HISTORY_TABLE = dbo.ProductPriceHistory)
);
GO
```

## 8.4 Native JSON index

```sql
CREATE TABLE dbo.ProductCatalog
(
    ProductId INT NOT NULL PRIMARY KEY CLUSTERED,
    Attributes json NOT NULL
);
GO

CREATE JSON INDEX IX_ProductCatalog_Attributes
ON dbo.ProductCatalog(Attributes)
FOR ('$.sku', '$.brand', '$.price');
GO
```

> Nếu môi trường lab chưa bật feature tương ứng, dùng computed-column JSON index để thực hành.

---

# PHẦN 9 — EXAM TRAPS

1. “Clustered index = physical disk order” ➜ quá đơn giản.
2. “Columnstore = mọi table lớn” ➜ sai.
3. “Temporal = tamper-proof” ➜ sai.
4. “Ledger = chỉ history” ➜ thiếu.
5. “External table copy data vào SQL” ➜ sai.
6. “Sequence gapless” ➜ sai.
7. “Partitioning tự động làm mọi query nhanh” ➜ sai.
8. “Không có JSON index trực tiếp” ➜ lỗi thời với SQL Server 2025.
9. “NCCI = CCI nhưng ít columns hơn” ➜ sai mental model.
10. “In-Memory = data không durable” ➜ sai với `SCHEMA_AND_DATA`.

---

# PHẦN 10 — MOCK QUESTIONS

### Q1
Fact table 800M rows, nightly batch, chủ yếu aggregate theo Date/Region.

**Đáp án:** CCI.

### Q2
OLTP Orders liên tục nhưng cần dashboard real-time trên cùng table.

**Đáp án:** NCCI.

### Q3
Cần xem salary tại một thời điểm quá khứ.

**Đáp án:** Temporal.

### Q4
Auditor cần phát hiện tampering và verify integrity.

**Đáp án:** Ledger.

### Q5
Query nhiều-hop relationships.

**Đáp án:** Graph + `MATCH`.

### Q6
SQL Server 2025, native `json`, muốn native indexing.

**Đáp án:** `CREATE JSON INDEX`.

### Q7
Muốn kỹ thuật JSON indexing hỗ trợ rộng.

**Đáp án:** Computed column `JSON_VALUE` + B-tree.

### Q8
FK được bật bằng `WITH NOCHECK`, optimizer không trust.

**Đáp án:** `WITH CHECK CHECK CONSTRAINT`.

### Q9
Hai tables dùng chung numbering source.

**Đáp án:** `SEQUENCE`.

### Q10
Archive một monthly partition nhanh.

**Đáp án:** Partitioning + compatible `SWITCH`.

---

# PHẦN 11 — CHEAT SHEET

```text
OLAP/DW aggregation        -> CCI
OLTP + real-time analytics -> NCCI
Low-latency hot OLTP       -> Memory-Optimized
Point-in-time history      -> Temporal
Tamper-evident audit       -> Ledger
Many-hop relationships     -> Graph
External storage query     -> External Table
JSON scalar broad index    -> Computed column + B-tree
SQL 2025 native JSON       -> CREATE JSON INDEX
Cross-table number source  -> SEQUENCE
Large-table manageability  -> Partitioning
FK trusted again           -> WITH CHECK CHECK CONSTRAINT
```

---

# PHẦN 12 — LINK THAM KHẢO

- [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
- [CREATE TABLE](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql?view=sql-server-ver17)
- [CREATE COLUMNSTORE INDEX](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-columnstore-index-transact-sql?view=sql-server-ver17)
- [Ordered Columnstore](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/ordered-columnstore-indexes?view=sql-server-ver17)
- [Memory-Optimized Tables](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/introduction-to-memory-optimized-tables?view=sql-server-ver17)
- [Temporal Tables](https://learn.microsoft.com/en-us/sql/relational-databases/tables/creating-a-system-versioned-temporal-table?view=sql-server-ver17)
- [Query Temporal Data](https://learn.microsoft.com/en-us/sql/relational-databases/tables/querying-data-in-a-system-versioned-temporal-table?view=sql-server-ver17)
- [Ledger Tables](https://learn.microsoft.com/en-us/sql/relational-databases/security/ledger/ledger-how-to-updatable-ledger-tables?view=sql-server-ver17)
- [SQL Graph Sample](https://learn.microsoft.com/en-us/sql/relational-databases/graphs/sql-graph-sample?view=sql-server-ver17)
- [CREATE EXTERNAL TABLE](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-table-transact-sql?view=sql-server-ver17)
- [Index JSON Data](https://learn.microsoft.com/en-us/sql/relational-databases/json/index-json-data?view=sql-server-ver17)
- [CREATE JSON INDEX](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-json-index-transact-sql?view=sql-server-ver17)
- [Partitioned Tables and Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/create-partitioned-tables-and-indexes?view=sql-server-ver17)
