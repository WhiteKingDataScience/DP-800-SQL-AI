/*═══════════════════════════════════════════════════════════════════════════════
  DP-800 | MIỀN 1 | LAB 01 — THIẾT KẾ BẢNG & RÀNG BUỘC
  Đi kèm: Claude_DP800_D1_Design_Guide.md  (mục 1 và 2)
  Nền tảng: SQL Server 2022+ (Developer/Enterprise). Chạy trên instance TEST.

  CÁCH HỌC: chạy từng section. Các đoạn đánh dấu [LỖI CỐ Ý] được thiết kế để
  BÁO LỖI — hãy chạy, đọc kỹ số hiệu lỗi (Msg xxxx) rồi mới đọc phần giải thích.
  Đề thi DP-800 hỏi đúng những tình huống này.
═══════════════════════════════════════════════════════════════════════════════*/

SET NOCOUNT ON;
-- Bắt buộc khi có filtered index / index trên computed column.
-- SSMS mặc định đã ON, nhưng sqlcmd/osql mặc định OFF ⇒ luôn khai báo tường minh.
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET ANSI_WARNINGS ON;
SET ANSI_PADDING ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF DB_ID('DP800_Lab') IS NULL
    CREATE DATABASE DP800_Lab;
GO
USE DP800_Lab;
GO
IF SCHEMA_ID('Sales') IS NULL EXEC('CREATE SCHEMA Sales');
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 1 — KIỂU DỮ LIỆU: FLOAT vs DECIMAL (bẫy "tiền tệ")
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS dbo.MoneyDemo;
CREATE TABLE dbo.MoneyDemo
(
    AmtFloat    FLOAT,          -- xấp xỉ (approximate numeric)
    AmtDecimal  DECIMAL(19,4)   -- chính xác (exact numeric)
);
GO
-- ⚠ Bắt buộc có GO: SQL Server biên dịch cả batch trước khi chạy, nên câu lệnh
--   tham chiếu CỘT của bảng vừa CREATE trong CÙNG batch sẽ báo Msg 207.
--   (Tên BẢNG được phân giải trễ - deferred name resolution - nhưng tên CỘT thì không.)

-- Cộng 0.1 mười lần
DECLARE @i INT = 0;
WHILE @i < 10
BEGIN
    INSERT dbo.MoneyDemo VALUES (0.1, 0.1);
    SET @i += 1;
END;

SELECT  SUM(AmtFloat)                       AS Float_Sum,
        SUM(AmtDecimal)                     AS Decimal_Sum,
        CASE WHEN SUM(AmtFloat) = 1.0 THEN 'BẰNG 1' ELSE 'KHÁC 1 (!)' END AS Float_EqualsOne
FROM    dbo.MoneyDemo;
/*  KẾT QUẢ: Float_Sum hiển thị 1 nhưng so sánh = 1.0 lại FALSE.
    → Bài học thi: dữ liệu tài chính LUÔN dùng DECIMAL/NUMERIC, không bao giờ FLOAT.
    → FLOAT cũng KHÔNG được dùng trong computed column không-PERSISTED có index
      (imprecise ⇒ bắt buộc PERSISTED).                                        */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 2 — GUID NGẪU NHIÊN LÀM CLUSTERED KEY ⇒ PHÂN MẢNH
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS dbo.GuidRandom, dbo.GuidSequential;

CREATE TABLE dbo.GuidRandom
(
    Id      UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_GR DEFAULT NEWID(),
    Filler  CHAR(200)        NOT NULL DEFAULT 'x',
    CONSTRAINT PK_GR PRIMARY KEY CLUSTERED (Id)
);

CREATE TABLE dbo.GuidSequential
(
    Id      UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_GS DEFAULT NEWSEQUENTIALID(),
    Filler  CHAR(200)        NOT NULL DEFAULT 'x',
    CONSTRAINT PK_GS PRIMARY KEY CLUSTERED (Id)
);

INSERT dbo.GuidRandom     (Filler) SELECT TOP (20000) 'x' FROM sys.all_objects a, sys.all_objects b;
INSERT dbo.GuidSequential (Filler) SELECT TOP (20000) 'x' FROM sys.all_objects a, sys.all_objects b;

SELECT  OBJECT_NAME(ips.object_id)              AS TableName,
        ips.avg_fragmentation_in_percent        AS FragPct,
        ips.page_count                          AS Pages,
        ips.avg_page_space_used_in_percent      AS PageFullPct
FROM    sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'DETAILED') ips
WHERE   ips.object_id IN (OBJECT_ID('dbo.GuidRandom'), OBJECT_ID('dbo.GuidSequential'))
  AND   ips.index_level = 0;
/*  NEWID()           → phân mảnh ~99%, nhiều page split, số trang lớn hơn.
    NEWSEQUENTIALID() → phân mảnh gần 0%.
    Đáp án thi: cần GUID nhưng không muốn phân mảnh ⇒ NEWSEQUENTIALID(),
    hoặc giữ GUID làm UNIQUE nonclustered và dùng INT IDENTITY làm clustered key. */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 3 — COMPUTED COLUMN: PERSISTED hay không?
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS Sales.OrderLine;
GO
CREATE TABLE Sales.OrderLine
(
    OrderLineId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    OrderId     INT           NOT NULL,
    Quantity    INT           NOT NULL,
    UnitPrice   DECIMAL(19,4) NOT NULL,
    Discount    DECIMAL(5,4)  NOT NULL DEFAULT 0,
    -- Deterministic + precise ⇒ index được kể cả khi KHÔNG persisted
    LineTotal   AS (Quantity * UnitPrice * (1 - Discount))
);
GO
CREATE INDEX IX_OrderLine_LineTotal ON Sales.OrderLine(LineTotal);   -- THÀNH CÔNG
GO

-- [LỖI CỐ Ý 3a] biểu thức dùng FLOAT (imprecise) ⇒ không index được nếu chưa PERSISTED
ALTER TABLE Sales.OrderLine ADD WeightKg FLOAT NULL;
GO
ALTER TABLE Sales.OrderLine ADD ShipCost AS (WeightKg * 1.35);
GO
CREATE INDEX IX_ShipCost ON Sales.OrderLine(ShipCost);
GO
/*  Msg 2799 — "Cannot create index ... column 'ShipCost' is imprecise..."
    KHẮC PHỤC: */
ALTER TABLE Sales.OrderLine DROP COLUMN ShipCost;
GO
ALTER TABLE Sales.OrderLine ADD ShipCost AS (WeightKg * 1.35) PERSISTED;
GO
CREATE INDEX IX_ShipCost ON Sales.OrderLine(ShipCost);              -- THÀNH CÔNG
GO

-- [LỖI CỐ Ý 3b] computed column không được tham chiếu bảng khác / subquery
BEGIN TRY
    EXEC('ALTER TABLE Sales.OrderLine ADD BadCol AS (SELECT COUNT(*) FROM sys.objects)');
END TRY
BEGIN CATCH
    SELECT 'LỖI 3b' AS Demo, ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS ErrMsg;
END CATCH;
GO

-- is_persisted nằm ở sys.computed_columns (KHÔNG có trong sys.columns)
SELECT  cc.name, cc.is_persisted, cc.is_nullable, cc.definition
FROM    sys.computed_columns cc
WHERE   cc.object_id = OBJECT_ID('Sales.OrderLine');
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 4 — IDENTITY vs SEQUENCE
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS dbo.InvoiceHeader, dbo.CreditNote;
DROP SEQUENCE IF EXISTS dbo.DocNumber;

-- Một dãy số CHUNG cho nhiều bảng (IDENTITY không làm được điều này)
CREATE SEQUENCE dbo.DocNumber AS INT START WITH 1000 INCREMENT BY 1 CACHE 50;

CREATE TABLE dbo.InvoiceHeader
(
    DocNo   INT NOT NULL DEFAULT (NEXT VALUE FOR dbo.DocNumber) PRIMARY KEY,
    Note    NVARCHAR(50)
);
CREATE TABLE dbo.CreditNote
(
    DocNo   INT NOT NULL DEFAULT (NEXT VALUE FOR dbo.DocNumber) PRIMARY KEY,
    Note    NVARCHAR(50)
);
GO
INSERT dbo.InvoiceHeader (Note) VALUES (N'HĐ 1'), (N'HĐ 2');
INSERT dbo.CreditNote    (Note) VALUES (N'GBC 1');
INSERT dbo.InvoiceHeader (Note) VALUES (N'HĐ 3');

SELECT 'Invoice' AS Src, DocNo, Note FROM dbo.InvoiceHeader
UNION ALL
SELECT 'Credit',        DocNo, Note FROM dbo.CreditNote
ORDER BY DocNo;
/*  Dãy 1000,1001,1002,1003 chạy XUYÊN 2 bảng — đây là đáp án cho câu hỏi
    "nhiều bảng phải dùng chung một dãy số duy nhất".                        */

-- LẤY GIÁ TRỊ TRƯỚC KHI INSERT (IDENTITY không làm được)
DECLARE @NextDoc INT = NEXT VALUE FOR dbo.DocNumber;
SELECT @NextDoc AS Biet_ID_Truoc_Khi_Ghi;
INSERT dbo.InvoiceHeader (DocNo, Note) VALUES (@NextDoc, N'Ghi cha rồi ghi con dùng cùng ID');

-- Cấp phát hàng loạt cho ETL
DECLARE @first SQL_VARIANT;
EXEC sys.sp_sequence_get_range @sequence_name = N'dbo.DocNumber',
     @range_size = 1000, @range_first_value = @first OUTPUT;
SELECT @first AS Dai_1000_So_Bat_Dau_Tu;

-- So sánh cách reset
-- IDENTITY : DBCC CHECKIDENT ('dbo.T', RESEED, 0);
ALTER SEQUENCE dbo.DocNumber RESTART WITH 5000;

/*  ⚠ Bẫy thi: IDENTITY và SEQUENCE đều KHÔNG đảm bảo liên tục (gap) khi rollback
    hoặc khi service restart (do cache). Muốn số chứng từ liên tục tuyệt đối theo
    luật kế toán ⇒ phải dùng bảng đếm + transaction, hoặc SEQUENCE ... NO CACHE.  */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 5 — CHECK CONSTRAINT VÀ NULL (bẫy số 1 của miền này)
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS dbo.Person;
CREATE TABLE dbo.Person
(
    PersonId INT IDENTITY PRIMARY KEY,
    FullName NVARCHAR(100) NOT NULL,
    Age      INT NULL,
    CONSTRAINT CK_Person_Age CHECK (Age > 18)
);
GO
INSERT dbo.Person (FullName, Age) VALUES (N'Hợp lệ', 25);      -- OK
INSERT dbo.Person (FullName, Age) VALUES (N'NULL lọt lưới!', NULL);  -- ✅ VẪN CHÈN ĐƯỢC
-- INSERT dbo.Person (FullName, Age) VALUES (N'Bị chặn', 10);   -- Msg 547

SELECT * FROM dbo.Person;
/*  NULL > 18 ⇒ UNKNOWN, mà CHECK chỉ từ chối khi biểu thức = FALSE.
    ⇒ UNKNOWN được CHẤP NHẬN. Muốn chặn: */
ALTER TABLE dbo.Person DROP CONSTRAINT CK_Person_Age;
DELETE dbo.Person WHERE Age IS NULL;   -- phải dọn dữ liệu cũ, nếu không WITH CHECK báo Msg 547
ALTER TABLE dbo.Person WITH CHECK
    ADD CONSTRAINT CK_Person_Age CHECK (Age IS NOT NULL AND Age > 18);
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 6 — UNIQUE CHỈ CHO 1 NULL ⇒ DÙNG UNIQUE FILTERED INDEX
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS dbo.Employee;
CREATE TABLE dbo.Employee
(
    EmpId       INT IDENTITY PRIMARY KEY,
    NationalId  VARCHAR(20) NULL,
    Email       VARCHAR(100) NULL,
    CONSTRAINT UQ_Emp_NationalId UNIQUE (NationalId)
);
GO
INSERT dbo.Employee (NationalId) VALUES ('001'), (NULL);
GO
-- [LỖI CỐ Ý 6] NULL thứ hai bị chặn
INSERT dbo.Employee (NationalId) VALUES (NULL);
GO
/*  Msg 2627 — Violation of UNIQUE KEY constraint.
    SQL Server coi hai NULL là "trùng nhau" đối với UNIQUE constraint.
    GIẢI PHÁP CHUẨN (câu hỏi tủ): unique filtered index                       */
CREATE UNIQUE NONCLUSTERED INDEX UX_Emp_Email
    ON dbo.Employee(Email)
    WHERE Email IS NOT NULL;

-- ⚠ Phải cấp NationalId khác nhau: cột đó vẫn còn UNIQUE constraint và đã có 1 dòng NULL.
INSERT dbo.Employee (NationalId, Email)
VALUES ('002','a@x.com'), ('003', NULL), ('004', NULL), ('005', NULL);   -- ✅ nhiều NULL ở Email đều OK
GO
-- INSERT dbo.Employee (NationalId, Email) VALUES ('006','a@x.com');  -- bị chặn: trùng giá trị Email thật
SELECT * FROM dbo.Employee;


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 7 — FOREIGN KEY KHÔNG TỰ TẠO INDEX
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS dbo.OrderDetail, dbo.OrderHead;
CREATE TABLE dbo.OrderHead
(
    OrderId  INT IDENTITY PRIMARY KEY,
    OrderDate DATE NOT NULL DEFAULT SYSUTCDATETIME()
);
CREATE TABLE dbo.OrderDetail
(
    DetailId INT IDENTITY PRIMARY KEY,
    OrderId  INT NOT NULL
        CONSTRAINT FK_Detail_Head REFERENCES dbo.OrderHead(OrderId),
    Amount   DECIMAL(19,4) NOT NULL
);
GO
-- Chứng minh: index nào tồn tại trên bảng con?
SELECT i.name, i.type_desc, i.is_primary_key
FROM   sys.indexes i WHERE i.object_id = OBJECT_ID('dbo.OrderDetail');
/*  Chỉ có PK — KHÔNG có index nào trên cột FK OrderId.
    Hậu quả: mỗi lần DELETE ở bảng cha, SQL phải SCAN toàn bộ bảng con để
    kiểm tra tham chiếu ⇒ chậm + lock. Luôn tạo thủ công:                     */
CREATE INDEX IX_OrderDetail_OrderId ON dbo.OrderDetail(OrderId);

-- Truy vấn tìm MỌI FK chưa có index hỗ trợ (dùng được ngoài đời thật):
SELECT  QUOTENAME(SCHEMA_NAME(t.schema_id)) + '.' + QUOTENAME(t.name) AS ChildTable,
        fk.name AS ForeignKey, c.name AS FKColumn
FROM    sys.foreign_keys fk
JOIN    sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
JOIN    sys.tables  t ON t.object_id = fk.parent_object_id
JOIN    sys.columns c ON c.object_id = fkc.parent_object_id AND c.column_id = fkc.parent_column_id
WHERE   NOT EXISTS (
            SELECT 1 FROM sys.index_columns ic
            WHERE ic.object_id = fkc.parent_object_id
              AND ic.column_id = fkc.parent_column_id
              AND ic.key_ordinal = 1);


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 8 — TRUSTED vs UNTRUSTED CONSTRAINT
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS dbo.Product;
CREATE TABLE dbo.Product
(
    ProductId INT IDENTITY PRIMARY KEY,
    Price     DECIMAL(19,4) NOT NULL
);
GO
INSERT dbo.Product (Price) VALUES (100), (-50);   -- có dữ liệu "bẩn"

-- WITH NOCHECK: thêm được nhưng constraint bị coi là KHÔNG đáng tin
ALTER TABLE dbo.Product WITH NOCHECK
    ADD CONSTRAINT CK_Product_Price CHECK (Price > 0);

SELECT name, is_not_trusted FROM sys.check_constraints
WHERE parent_object_id = OBJECT_ID('dbo.Product');   -- is_not_trusted = 1

/*  Hệ quả: Query Optimizer KHÔNG dùng constraint này để loại bớt dữ liệu
    (mất tối ưu, mất partition/constraint elimination).                        */

DELETE dbo.Product WHERE Price <= 0;                 -- dọn dữ liệu bẩn
ALTER TABLE dbo.Product WITH CHECK CHECK CONSTRAINT CK_Product_Price;  -- kiểm tra lại

SELECT name, is_not_trusted FROM sys.check_constraints
WHERE parent_object_id = OBJECT_ID('dbo.Product');   -- is_not_trusted = 0 ✅

-- Rà soát toàn DB (câu hỏi "làm sao biết constraint nào không trusted?")
SELECT 'CHECK' AS Kind, name, OBJECT_NAME(parent_object_id) AS TableName
FROM sys.check_constraints WHERE is_not_trusted = 1
UNION ALL
SELECT 'FOREIGN KEY', name, OBJECT_NAME(parent_object_id)
FROM sys.foreign_keys   WHERE is_not_trusted = 1;


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 9 — CASCADE VÀ LỖI "MULTIPLE CASCADE PATHS"
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS dbo.Trip, dbo.City;
CREATE TABLE dbo.City (CityId INT PRIMARY KEY, CityName NVARCHAR(50));
GO
-- [LỖI CỐ Ý 9] hai FK cùng CASCADE trỏ về một bảng cha
CREATE TABLE dbo.Trip
(
    TripId INT PRIMARY KEY,
    FromCityId INT NOT NULL REFERENCES dbo.City(CityId) ON DELETE CASCADE,
    ToCityId   INT NOT NULL REFERENCES dbo.City(CityId) ON DELETE CASCADE
);
GO
/*  Msg 1785 — "Introducing FOREIGN KEY constraint ... may cause cycles or
    multiple cascade paths. Specify ON DELETE NO ACTION..."
    GIẢI PHÁP: giữ NO ACTION rồi xử lý bằng trigger INSTEAD OF / stored procedure. */
DROP TABLE IF EXISTS dbo.Trip;
GO
CREATE TABLE dbo.Trip
(
    TripId INT PRIMARY KEY,
    FromCityId INT NOT NULL REFERENCES dbo.City(CityId),   -- NO ACTION
    ToCityId   INT NOT NULL REFERENCES dbo.City(CityId)    -- NO ACTION
);
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 10 — NÉN DỮ LIỆU (ROW / PAGE) VÀ SPARSE COLUMN
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS dbo.CompressDemo;
CREATE TABLE dbo.CompressDemo
(
    Id     INT IDENTITY PRIMARY KEY,
    Code   CHAR(50)     NOT NULL,   -- nhiều khoảng trắng thừa ⇒ ROW nén tốt
    City   NVARCHAR(50) NOT NULL    -- giá trị lặp lại ⇒ PAGE (dictionary) nén tốt
);
GO
INSERT dbo.CompressDemo (Code, City)
SELECT TOP (50000) 'ABC', N'Hà Nội' FROM sys.all_objects a, sys.all_objects b;

-- Ước lượng TRƯỚC khi nén (nên làm trong thực tế)
EXEC sys.sp_estimate_data_compression_savings 'dbo','CompressDemo',NULL,NULL,'ROW';
EXEC sys.sp_estimate_data_compression_savings 'dbo','CompressDemo',NULL,NULL,'PAGE';

SELECT 'Trước nén' AS Stage, SUM(used_page_count)*8 AS KB
FROM sys.dm_db_partition_stats WHERE object_id = OBJECT_ID('dbo.CompressDemo');

ALTER TABLE dbo.CompressDemo REBUILD WITH (DATA_COMPRESSION = PAGE);

SELECT 'Sau nén PAGE' AS Stage, SUM(used_page_count)*8 AS KB
FROM sys.dm_db_partition_stats WHERE object_id = OBJECT_ID('dbo.CompressDemo');

-- SPARSE: dùng khi cột NULL rất nhiều (>40-60%)
DROP TABLE IF EXISTS dbo.SparseDemo;
CREATE TABLE dbo.SparseDemo
(
    Id        INT IDENTITY PRIMARY KEY,
    CommonCol INT NOT NULL,
    Attr01    INT SPARSE NULL,
    Attr02    INT SPARSE NULL,
    Attr03    NVARCHAR(50) SPARSE NULL,
    AllAttrs  XML COLUMN_SET FOR ALL_SPARSE_COLUMNS   -- đọc/ghi hàng loạt cột thưa
);
GO
INSERT dbo.SparseDemo (CommonCol, Attr01) VALUES (1, 99);
INSERT dbo.SparseDemo (CommonCol, AllAttrs) VALUES (2, '<Attr02>7</Attr02><Attr03>abc</Attr03>');
SELECT Id, CommonCol, AllAttrs FROM dbo.SparseDemo;   -- SELECT * chỉ trả COLUMN_SET
SELECT Id, Attr01, Attr02, Attr03 FROM dbo.SparseDemo;
/*  ⚠ SPARSE: tiết kiệm chỗ khi NULL, nhưng TỐN THÊM 4 byte cho mỗi giá trị
    KHÔNG NULL ⇒ dùng sai chỗ sẽ phình bảng. Không dùng SPARSE cho cột
    của clustered index key, và không kết hợp với DATA_COMPRESSION = PAGE.     */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 11 — BẢNG TẠM vs BIẾN BẢNG (hay bị hỏi kèm)
───────────────────────────────────────────────────────────────────────────────*/
/*  #temp        : có thống kê (statistics), index tạo sau được, tham gia transaction,
                   ước lượng số dòng ĐÚNG ⇒ chọn khi dữ liệu > ~1000 dòng.
    @tablevar    : không có statistics (ước lượng 1 dòng, trừ khi OPTION(RECOMPILE)),
                   không rollback theo transaction ⇒ chọn cho tập nhỏ / cần giữ dữ liệu
                   sau ROLLBACK (ví dụ log lỗi).
    Memory-optimized table variable: thay thế nhanh nhất cho tempdb contention.   */
DECLARE @tv TABLE (Id INT PRIMARY KEY, Val INT);
INSERT @tv SELECT TOP (5) object_id, 1 FROM sys.objects;
SELECT * FROM @tv;

DROP TABLE IF EXISTS #tmp;
SELECT TOP (5) object_id AS Id, name INTO #tmp FROM sys.objects;
CREATE INDEX IX_tmp ON #tmp(Id);      -- ✅ tạo index SAU được (biến bảng thì không)
SELECT * FROM #tmp;
DROP TABLE #tmp;
GO


/*───────────────────────────────────────────────────────────────────────────────
  DỌN DẸP (bỏ chú thích nếu muốn xóa)
───────────────────────────────────────────────────────────────────────────────*/
-- USE master; DROP DATABASE DP800_Lab;

/*═══════════════════════════════════════════════════════════════════════════════
  CHECKLIST TỰ KIỂM TRA SAU LAB 01
  □ Giải thích được vì sao CHECK không chặn NULL.
  □ Nêu 3 cách ép "duy nhất nhưng cho phép nhiều NULL".
  □ Nói được khi nào BẮT BUỘC PERSISTED cho computed column.
  □ Kể 4 điểm SEQUENCE làm được mà IDENTITY không làm được.
  □ Biết truy vấn tìm FK thiếu index và constraint untrusted.
  □ Biết lỗi Msg 1785 xảy ra khi nào và cách né.
═══════════════════════════════════════════════════════════════════════════════*/
