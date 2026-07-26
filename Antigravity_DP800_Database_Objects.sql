-- ====================================================================================
-- BÀI TẬP VÀ VÍ DỤ THỰC HÀNH KỲ THI DP-800 (MICROSOFT CERTIFIED: AI-ENABLED DATABASE SOLUTIONS)
-- CHUYÊN ĐỀ 1: THIẾT KẾ & PHÁT TRIỂN ĐỐI TƯỢNG CƠ SỞ DỮ LIỆU (DATABASE OBJECTS & PARTITIONING)
-- Tác giả: Microsoft Principal Database Solutions Architect
-- Tên file: Antigravity_DP800_Database_Objects.sql
-- ====================================================================================

USE master;
GO

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'DP800_Review_DB')
BEGIN
    CREATE DATABASE DP800_Review_DB;
END
GO

USE DP800_Review_DB;
GO

-- ====================================================================================
-- PHẦN 1: BẢNG, KIỂU DỮ LIỆU, CHỈ MỤC & COLUMNSTORE INDEXES
-- ====================================================================================

/*
   MẸO THI DP-800:
   1. Clustered Columnstore Index (CCI): Phù hợp cho Data Warehouse, bảng Analytics lớn (> 1 triệu dòng).
      - Nén dữ liệu theo cột, giảm I/O đáng kể.
      - Hỗ trợ batch mode execution.
   2. Nonclustered Columnstore Index (NCCI): Dùng cho Operational Analytics (HTAP - Hybrid Transactional/Analytical Processing).
      - Tạo trên bảng OLTP (Rowstore) hiện tại để chạy báo cáo realtime mà không cần ETL.
   3. Kiểu dữ liệu tối ưu: Tránh NVARCHAR(MAX) nếu không cần thiết; dùng INT/BIGINT cho khóa chính; dùng DATETIME2 thay cho DATETIME.
*/

-- 1.1 Bảng OLTP Chuẩn với B-Tree Indexes
IF OBJECT_ID('dbo.SalesOrderHeader', 'U') IS NOT NULL DROP TABLE dbo.SalesOrderHeader;
CREATE TABLE dbo.SalesOrderHeader (
    OrderID INT IDENTITY(1,1) NOT NULL,
    CustomerID INT NOT NULL,
    OrderDate DATETIME2(0) NOT NULL CONSTRAINT DF_SalesOrderHeader_OrderDate DEFAULT (SYSDATETIME()),
    TotalAmount DECIMAL(18, 2) NOT NULL,
    OrderStatus TINYINT NOT NULL CONSTRAINT CK_SalesOrderHeader_Status CHECK (OrderStatus IN (1, 2, 3, 4)), -- 1: New, 2: Processing, 3: Completed, 4: Cancelled
    CONSTRAINT PK_SalesOrderHeader PRIMARY KEY CLUSTERED (OrderID)
);

-- Nonclustered B-Tree Index tối ưu truy vấn tìm kiếm theo CustomerID & OrderDate
CREATE NONCLUSTERED INDEX IX_SalesOrderHeader_CustomerID_OrderDate 
ON dbo.SalesOrderHeader (CustomerID, OrderDate)
INCLUDE (TotalAmount, OrderStatus);
GO

-- 1.2 Bảng Analytics lớn tích hợp Clustered Columnstore Index (CCI)
IF OBJECT_ID('dbo.FactSalesAnalytics', 'U') IS NOT NULL DROP TABLE dbo.FactSalesAnalytics;
CREATE TABLE dbo.FactSalesAnalytics (
    FactID BIGINT IDENTITY(1,1) NOT NULL,
    DateKey INT NOT NULL,
    CustomerID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(18,2) NOT NULL,
    TotalDiscount DECIMAL(18,2) NOT NULL,
    NetAmount DECIMAL(18,2) NOT NULL
);

-- Tạo Clustered Columnstore Index cho bảng OLAP / Analytics
CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactSalesAnalytics
ON dbo.FactSalesAnalytics;
GO

-- 1.3 Operational Analytics: Tạo Nonclustered Columnstore Index (NCCI) trên bảng OLTP
-- Giúp chạy truy vấn OLAP tổng hợp trên dữ liệu OLTP mà không ảnh hưởng hiệu năng OLTP
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_SalesOrderHeader_Analytics
ON dbo.SalesOrderHeader (CustomerID, OrderDate, TotalAmount, OrderStatus);
GO


-- ====================================================================================
-- PHẦN 2: BẢNG CHUYÊN BIỆT (SPECIALIZED TABLES)
-- ====================================================================================

/*
   MẸO THI DP-800:
   1. Temporal Tables (System-Versioned): Tự động lưu vết lịch sử thay đổi (Audit, Point-in-time analysis). Yêu cầu PRIMARY KEY và 2 cột DATETIME2 GENERATED ALWAYS AS ROW START/END.
   2. In-Memory OLTP (Memory-Optimized Tables): Lưu dữ liệu trong RAM, loại bỏ Lock/Latch contention. Cần BUCKET_COUNT phù hợp cho HASH INDEX (khoảng 1-2 lần số lượng khóa duy nhất).
   3. Ledger Tables: Bảo vệ dữ liệu chống sửa đổi (Tamper-evident) bằng Cryptographic Hashing (SHA-256) tích hợp Merkle Tree.
      - Updatable Ledger Table: Cho phép UPDATE/DELETE nhưng ghi vết không thể xóa.
      - Append-Only Ledger Table: Chỉ cho phép INSERT.
   4. Graph Tables: Bao gồm NODE table (đối tượng) và EDGE table (mối quan hệ). Truy vấn bằng toán tử MATCH.
*/

-- 2.1 Temporal Table (Bảng theo dõi lịch sử giá sản phẩm)
IF OBJECT_ID('dbo.ProductPriceHistory', 'U') IS NOT NULL 
BEGIN
    ALTER TABLE dbo.ProductPriceHistory SET (SYSTEM_VERSIONING = OFF);
    DROP TABLE dbo.ProductPriceHistory;
    IF OBJECT_ID('dbo.ProductPriceHistory_Archive', 'U') IS NOT NULL DROP TABLE dbo.ProductPriceHistory_Archive;
END

CREATE TABLE dbo.ProductPriceHistory (
    ProductID INT NOT NULL PRIMARY KEY CLUSTERED,
    ProductName NVARCHAR(100) NOT NULL,
    UnitPrice DECIMAL(18,2) NOT NULL,
    ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL,
    ValidTo DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (
    SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.ProductPriceHistory_Archive)
);
GO

-- Demo cập nhật Temporal Table
INSERT INTO dbo.ProductPriceHistory (ProductID, ProductName, UnitPrice) 
VALUES (101, N'Laptop AI Pro', 1500.00);

WAITFOR DELAY '00:00:02';

UPDATE dbo.ProductPriceHistory 
SET UnitPrice = 1399.99 
WHERE ProductID = 101;

-- Truy vấn Temporal Table tại thời điểm trong quá khứ
SELECT * FROM dbo.ProductPriceHistory FOR SYSTEM_TIME ALL WHERE ProductID = 101;
GO

-- 2.2 Ledger Table (Bảng sổ cái chống gian lận tài chính)
IF OBJECT_ID('dbo.AccountBalanceLedger', 'U') IS NOT NULL 
BEGIN
    ALTER TABLE dbo.AccountBalanceLedger SET (SYSTEM_VERSIONING = OFF);
    DROP TABLE dbo.AccountBalanceLedger;
    IF OBJECT_ID('dbo.AccountBalanceLedger_Ledger', 'U') IS NOT NULL DROP TABLE dbo.AccountBalanceLedger_Ledger;
END

CREATE TABLE dbo.AccountBalanceLedger (
    AccountID INT NOT NULL PRIMARY KEY CLUSTERED,
    CustomerName NVARCHAR(100) NOT NULL,
    Balance DECIMAL(18,2) NOT NULL
)
WITH (
    SYSTEM_VERSIONING = ON,
    LEDGER = ON (LEDGER_TABLE_TYPE = UPDATABLE)
);
GO

INSERT INTO dbo.AccountBalanceLedger VALUES (1, N'Nguyen Van A', 5000.00);
UPDATE dbo.AccountBalanceLedger SET Balance = 7500.00 WHERE AccountID = 1;

-- Kiểm tra sổ cái thay đổi trong sys.AccountBalanceLedger_Ledger
SELECT * FROM dbo.AccountBalanceLedger_Ledger;
GO

-- 2.3 Graph Tables (Cơ sở dữ liệu đồ thị)
IF OBJECT_ID('dbo.LikesEdge', 'U') IS NOT NULL DROP TABLE dbo.LikesEdge;
IF OBJECT_ID('dbo.PersonNode', 'U') IS NOT NULL DROP TABLE dbo.PersonNode;
IF OBJECT_ID('dbo.ProductNode', 'U') IS NOT NULL DROP TABLE dbo.ProductNode;

-- Node Tables
CREATE TABLE dbo.PersonNode (
    PersonID INT NOT NULL PRIMARY KEY,
    PersonName NVARCHAR(100) NOT NULL
) AS NODE;

CREATE TABLE dbo.ProductNode (
    ProductID INT NOT NULL PRIMARY KEY,
    ProductName NVARCHAR(100) NOT NULL
) AS NODE;

-- Edge Table biểu diễn quan hệ (Person LIKES Product)
CREATE TABLE dbo.LikesEdge (
    Rating INT NOT NULL
) AS EDGE;
GO

-- Thêm dữ liệu Đồ thị
INSERT INTO dbo.PersonNode VALUES (1, N'Alice'), (2, N'Bob');
INSERT INTO dbo.ProductNode VALUES (10, N'SQL Server 2026'), (20, N'Azure AI Studio');

INSERT INTO dbo.LikesEdge ($from_id, $to_id, Rating)
VALUES (
    (SELECT $node_id FROM dbo.PersonNode WHERE PersonID = 1),
    (SELECT $node_id FROM dbo.ProductNode WHERE ProductID = 10),
    5
);
GO


-- ====================================================================================
-- PHẦN 3: JSON COLUMNS & INDEXES
-- ====================================================================================

/*
   MẸO THI DP-800:
   - Trong SQL Server 2024 / Azure SQL Database mới nhất, SQL hỗ trợ kiểu dữ liệu native `JSON` (hoặc NVARCHAR(MAX) với CHECK constraint ISJSON()).
   - Để tối ưu hóa truy vấn các đặc tính bên trong chuỗi JSON:
     + Tạo Computed Column dựa trên JSON_VALUE() và đánh chỉ mục B-Tree lên cột đó.
     + Hoặc tạo Full-Text Index / JSON Search Index.
*/

IF OBJECT_ID('dbo.CustomerProfiles', 'U') IS NOT NULL DROP TABLE dbo.CustomerProfiles;

CREATE TABLE dbo.CustomerProfiles (
    CustomerID INT PRIMARY KEY,
    ProfileAttributes NVARCHAR(MAX) CONSTRAINT CK_CustomerProfiles_JSON CHECK (ISJSON(ProfileAttributes) = 1),
    -- Computed Column trích xuất giá trị Email từ JSON để đánh Index
    ExtractedEmail AS JSON_VALUE(ProfileAttributes, '$.contact.email') PERSISTED
);

-- Đánh Index trên cột tính toán từ JSON
CREATE NONCLUSTERED INDEX IX_CustomerProfiles_Email ON dbo.CustomerProfiles(ExtractedEmail);
GO

INSERT INTO dbo.CustomerProfiles (CustomerID, ProfileAttributes)
VALUES 
(1, N'{"name": "Tran Van B", "contact": {"email": "tranb@example.com", "phone": "0901234567"}, "tier": "Gold"}'),
(2, N'{"name": "Le Thi C", "contact": {"email": "lec@example.com", "phone": "0987654321"}, "tier": "Platinum"}');

-- Truy vấn tận dụng Index trên JSON
SELECT CustomerID, ProfileAttributes
FROM dbo.CustomerProfiles
WHERE ExtractedEmail = 'tranb@example.com';
GO


-- ====================================================================================
-- PHẦN 4: RÀNG BUỘC (CONSTRAINTS) & SEQUENCES
-- ====================================================================================

/*
   MẸO THI DP-800:
   - SEQUENCE: Đối tượng độc lập với bảng, tạo giá trị số tăng tự động chia sẻ giữa nhiều bảng. Tối ưu hơn IDENTITY khi cần cấp phát số trước khi INSERT hoặc dùng chung trên nhiều bảng.
   - Constraints: PRIMARY KEY, FOREIGN KEY, UNIQUE, CHECK, DEFAULT.
*/

IF OBJECT_ID('dbo.InvoiceDetails', 'U') IS NOT NULL DROP TABLE dbo.InvoiceDetails;
IF OBJECT_ID('dbo.Invoices', 'U') IS NOT NULL DROP TABLE dbo.Invoices;
IF EXISTS (SELECT * FROM sys.sequences WHERE name = 'Seq_InvoiceNumber') DROP SEQUENCE dbo.Seq_InvoiceNumber;

-- Tạo SEQUENCE
CREATE SEQUENCE dbo.Seq_InvoiceNumber
    AS BIGINT
    START WITH 100001
    INCREMENT BY 1
    NO CACHE;
GO

CREATE TABLE dbo.Invoices (
    InvoiceID BIGINT NOT NULL CONSTRAINT PK_Invoices PRIMARY KEY,
    InvoiceNumber VARCHAR(20) NOT NULL CONSTRAINT UQ_InvoiceNumber UNIQUE,
    CustomerCode VARCHAR(10) NOT NULL,
    TotalAmount DECIMAL(18,2) NOT NULL CONSTRAINT DF_Invoices_Total DEFAULT (0.00),
    CONSTRAINT CK_Invoices_Amount CHECK (TotalAmount >= 0)
);

CREATE TABLE dbo.InvoiceDetails (
    DetailID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_InvoiceDetails PRIMARY KEY,
    InvoiceID BIGINT NOT NULL,
    ItemDescription NVARCHAR(200) NOT NULL,
    Quantity INT NOT NULL CONSTRAINT CK_InvoiceDetails_Qty CHECK (Quantity > 0),
    UnitPrice DECIMAL(18,2) NOT NULL,
    CONSTRAINT FK_InvoiceDetails_Invoices FOREIGN KEY (InvoiceID) REFERENCES dbo.Invoices(InvoiceID) ON DELETE CASCADE
);
GO

-- Sử dụng NEXT VALUE FOR SEQUENCE
INSERT INTO dbo.Invoices (InvoiceID, InvoiceNumber, CustomerCode, TotalAmount)
VALUES (NEXT VALUE FOR dbo.Seq_InvoiceNumber, 'INV-2026-001', 'CUST001', 2500.00);

SELECT * FROM dbo.Invoices;
GO


-- ====================================================================================
-- PHẦN 5: PHÂN VÙNG BẢNG VÀ CHỈ MỤC (TABLE & INDEX PARTITIONING)
-- ====================================================================================

/*
   MẸO THI DP-800:
   - Các bước phân vùng (Partitioning):
     1. Partition Function: Định nghĩa ranh giới phân vùng (RANGE LEFT / RIGHT) và kiểu dữ liệu.
     2. Partition Scheme: Ánh xạ các phân vùng vào các Filegroup (hoặc PRIMARY).
     3. Tạo Bảng/Index đặt trên Partition Scheme.
   - Sliding Window Pattern: Kỹ thuật SWITCH PARTITION giúp Archive/Purge dữ liệu lớn tức thì (Metadata operation - 0 seconds) thay vì chạy câu lệnh DELETE gây treo DB.
*/

-- 5.1 Tạo Partition Function (Phân vùng theo Năm)
IF EXISTS (SELECT * FROM sys.partition_schemes WHERE name = 'PS_TransactionDate') DROP PARTITION SCHEME PS_TransactionDate;
IF EXISTS (SELECT * FROM sys.partition_functions WHERE name = 'PF_TransactionDate') DROP PARTITION FUNCTION PF_TransactionDate;

CREATE PARTITION FUNCTION PF_TransactionDate (DATETIME2(0))
AS RANGE RIGHT FOR VALUES (
    '2024-01-01 00:00:00',
    '2025-01-01 00:00:00',
    '2026-01-01 00:00:00',
    '2027-01-01 00:00:00'
);
GO

-- 5.2 Tạo Partition Scheme
CREATE PARTITION SCHEME PS_TransactionDate
AS PARTITION PF_TransactionDate
ALL TO ([PRIMARY]);
GO

-- 5.3 Tạo Bảng Phân Vùng
IF OBJECT_ID('dbo.PartitionedTransactions', 'U') IS NOT NULL DROP TABLE dbo.PartitionedTransactions;

CREATE TABLE dbo.PartitionedTransactions (
    TransactionID BIGINT IDENTITY(1,1) NOT NULL,
    TransactionDate DATETIME2(0) NOT NULL,
    CustomerID INT NOT NULL,
    Amount DECIMAL(18,2) NOT NULL,
    CONSTRAINT PK_PartitionedTransactions PRIMARY KEY CLUSTERED (TransactionID, TransactionDate)
) ON PS_TransactionDate (TransactionDate);
GO

-- Thêm dữ liệu thử nghiệm
INSERT INTO dbo.PartitionedTransactions (TransactionDate, CustomerID, Amount) VALUES
('2024-05-15 10:30:00', 101, 150.00),
('2025-08-20 14:45:00', 102, 300.50),
('2026-02-10 09:15:00', 103, 500.00);

-- Kiểm tra dữ liệu nằm ở phân vùng nào trong sys.partitions
SELECT 
    p.partition_number,
    p.rows,
    rv.value AS BoundaryValue
FROM sys.partitions p
JOIN sys.indexes i ON p.object_id = i.object_id AND p.index_id = i.index_id
LEFT JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
LEFT JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
LEFT JOIN sys.partition_range_values rv ON pf.function_id = rv.function_id AND p.partition_number = rv.boundary_id + 1
WHERE p.object_id = OBJECT_ID('dbo.PartitionedTransactions') AND i.index_id <= 1;
GO
