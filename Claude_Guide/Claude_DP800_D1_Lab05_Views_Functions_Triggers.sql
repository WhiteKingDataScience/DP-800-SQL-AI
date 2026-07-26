/*═══════════════════════════════════════════════════════════════════════════════
  DP-800 | MIỀN 1 | LAB 05 — VIEW, FUNCTION, TRIGGER
  Đi kèm: Claude_DP800_D1_Design_Guide.md  (mục 8, 9, 10)

  PHẦN A — Views          (S1..S5)
  PHẦN B — Functions      (S6..S9)
  PHẦN C — Triggers       (S10..S15)
═══════════════════════════════════════════════════════════════════════════════*/

SET NOCOUNT ON;
-- Bắt buộc cho filtered index / index trên computed column / indexed view.
-- SSMS mặc định đã ON; sqlcmd, osql, một số driver thì OFF ⇒ luôn khai báo tường minh.
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET ANSI_WARNINGS ON;
SET ANSI_PADDING ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO
IF DB_ID('DP800_Lab') IS NULL CREATE DATABASE DP800_Lab;
GO
USE DP800_Lab;
GO
IF SCHEMA_ID('Sales') IS NULL EXEC('CREATE SCHEMA Sales');
GO

-- Dọn dẹp để script CHẠY LẠI ĐƯỢC nhiều lần.
-- ⚠ Thứ tự bắt buộc: view SCHEMABINDING và hàm SCHEMABINDING khoá bảng nền,
--   bảng con có FK phải xoá trước bảng cha.
-- DDL trigger tồn tại qua các lần chạy và sẽ bắn khi script tạo lại bảng dbo.DdlAudit
-- (trigger ghi vào chính bảng chưa kịp tồn tại ⇒ Msg 208) ⇒ gỡ trước.
DROP TRIGGER IF EXISTS trg_DdlAudit ON DATABASE;
DROP TRIGGER IF EXISTS trg_PreventDropTable ON DATABASE;
GO
DROP VIEW IF EXISTS Sales.vOrderAgg, Sales.vBadIndexed, Sales.vBadIndexed2,
                    Sales.vOrderSummary, Sales.vNorthCustomer, Sales.vCustomerOrder;
DROP TABLE IF EXISTS dbo.Ratio;
DROP FUNCTION IF EXISTS dbo.fnSafeDivide, dbo.fnNotInlineable;
DROP FUNCTION IF EXISTS Sales.fnOrderTotal_Scalar,
                        Sales.fnOrdersByCustomer_MSTVF, Sales.fnOrdersByCustomer_ITVF;
GO

-- Dữ liệu nền cho lab
DROP TABLE IF EXISTS Sales.SalesDetail;
DROP TABLE IF EXISTS Sales.SalesOrder;
DROP TABLE IF EXISTS Sales.Customer;
GO
CREATE TABLE Sales.Customer
(
    CustomerId INT IDENTITY PRIMARY KEY,
    Name       NVARCHAR(100) NOT NULL,
    Region     NVARCHAR(50)  NOT NULL,
    IsActive   BIT           NOT NULL DEFAULT 1
);
CREATE TABLE Sales.SalesOrder
(
    OrderId    INT IDENTITY PRIMARY KEY,
    CustomerId INT  NOT NULL REFERENCES Sales.Customer(CustomerId),
    OrderDate  DATE NOT NULL,
    Total      DECIMAL(19,4) NOT NULL DEFAULT 0
);
CREATE TABLE Sales.SalesDetail
(
    DetailId  INT IDENTITY PRIMARY KEY,
    OrderId   INT NOT NULL REFERENCES Sales.SalesOrder(OrderId),
    Sku       VARCHAR(20)   NOT NULL,
    Qty       INT           NOT NULL,
    UnitPrice DECIMAL(19,4) NOT NULL
);
CREATE INDEX IX_SalesOrder_CustomerId ON Sales.SalesOrder(CustomerId);
CREATE INDEX IX_SalesDetail_OrderId   ON Sales.SalesDetail(OrderId);

INSERT Sales.Customer (Name, Region) VALUES
 (N'Công ty A', N'North'), (N'Công ty B', N'South'), (N'Công ty C', N'North');

INSERT Sales.SalesOrder (CustomerId, OrderDate)
SELECT (ABS(CHECKSUM(NEWID())) % 3) + 1,
       DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 700), CAST('2026-07-01' AS DATE))
FROM (SELECT TOP (30000) 1 x FROM sys.all_objects a, sys.all_objects b) t;

INSERT Sales.SalesDetail (OrderId, Sku, Qty, UnitPrice)
SELECT o.OrderId, 'SKU-' + RIGHT('000' + CAST(ABS(CHECKSUM(NEWID())) % 50 AS VARCHAR(3)), 3),
       ABS(CHECKSUM(NEWID())) % 5 + 1,
       ABS(CHECKSUM(NEWID())) % 10000 / 100.0
FROM Sales.SalesOrder o CROSS JOIN (VALUES (1),(2),(3)) v(n);
GO


/*═══════════════════ PHẦN A — VIEWS ══════════════════════════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 1 — VIEW CƠ BẢN & WITH CHECK OPTION
───────────────────────────────────────────────────────────────────────────────*/
CREATE OR ALTER VIEW Sales.vNorthCustomer
AS
SELECT CustomerId, Name, Region, IsActive
FROM   Sales.Customer
WHERE  Region = N'North'
WITH CHECK OPTION;
GO

-- ✅ Chèn dòng vẫn "nhìn thấy" qua view
INSERT Sales.vNorthCustomer (Name, Region) VALUES (N'Công ty D', N'North');
GO
-- [LỖI CỐ Ý] chèn dòng sẽ BIẾN MẤT khỏi view ⇒ bị chặn bởi WITH CHECK OPTION
INSERT Sales.vNorthCustomer (Name, Region) VALUES (N'Công ty E', N'South');
GO
/*  Msg 550 — "The attempted insert or update failed because the target view
    ... specifies WITH CHECK OPTION..."
    Không có WITH CHECK OPTION thì dòng đó vẫn được ghi nhưng lập tức
    "biến mất" khỏi view — nguồn gốc của bug rất khó lần ra.                    */
SELECT * FROM Sales.vNorthCustomer;


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 2 — VIEW UPDATABLE / KHÔNG UPDATABLE
───────────────────────────────────────────────────────────────────────────────*/
GO
CREATE OR ALTER VIEW Sales.vOrderSummary
AS
SELECT c.CustomerId, c.Name, COUNT_BIG(*) AS OrderCount, SUM(o.Total) AS TotalSpent
FROM   Sales.Customer c
JOIN   Sales.SalesOrder o ON o.CustomerId = c.CustomerId
GROUP  BY c.CustomerId, c.Name;
GO
BEGIN TRY
    -- ⚠ Phải bọc trong EXEC(): lỗi 4403 phát sinh lúc BIÊN DỊCH batch, nên TRY...CATCH
    --   ở cùng batch KHÔNG bắt được. Bọc vào batch con (EXEC) mới bắt được.
    EXEC(N'UPDATE Sales.vOrderSummary SET Name = N''X'' WHERE CustomerId = 1;');
END TRY
BEGIN CATCH
    SELECT 'View có GROUP BY không update được' AS Demo, ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS Msg;
END CATCH;
GO
/*  ĐIỀU KIỆN VIEW UPDATABLE:
      - Chỉ đụng tới MỘT bảng nền trong 1 câu lệnh DML.
      - Không DISTINCT, GROUP BY, HAVING, aggregate, UNION, TOP với ORDER BY.
      - Cột đích không phải computed/derived.
      - Mọi cột NOT NULL không có DEFAULT của bảng nền phải xuất hiện trong view
        (nếu muốn INSERT).
    Vi phạm ⇒ dùng INSTEAD OF trigger (Section 12).                            */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 3 — INDEXED VIEW: DANH SÁCH "VÀNG" CÁC ĐIỀU KIỆN
───────────────────────────────────────────────────────────────────────────────*/
-- 7 tuỳ chọn SET phải đúng KHI TẠO và KHI GHI vào bảng nền
SET ANSI_NULLS ON;  SET ANSI_PADDING ON;  SET ANSI_WARNINGS ON;
SET ARITHABORT ON;  SET CONCAT_NULL_YIELDS_NULL ON;  SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO

-- [LỖI CỐ Ý 3a] thiếu SCHEMABINDING
CREATE OR ALTER VIEW Sales.vBadIndexed
AS
SELECT CustomerId, COUNT_BIG(*) AS Cnt FROM Sales.SalesOrder GROUP BY CustomerId;
GO
CREATE UNIQUE CLUSTERED INDEX IX_Bad ON Sales.vBadIndexed(CustomerId);
GO
/*  Msg 1939 — "Cannot create index on view ... It is not schema bound."        */

-- [LỖI CỐ Ý 3b] có SCHEMABINDING nhưng THIẾU COUNT_BIG(*)
CREATE OR ALTER VIEW Sales.vBadIndexed2
WITH SCHEMABINDING
AS
SELECT CustomerId, SUM(Total) AS TotalSum FROM Sales.SalesOrder GROUP BY CustomerId;
GO
CREATE UNIQUE CLUSTERED INDEX IX_Bad2 ON Sales.vBadIndexed2(CustomerId);
GO
/*  Msg 10138 — "...does not contain a count aggregate..." hoặc lỗi tương tự.
    LÝ DO: engine cần COUNT_BIG(*) để bảo trì TĂNG DẦN (biết khi nào nhóm về 0). */

-- ✅ ĐÚNG CHUẨN
CREATE OR ALTER VIEW Sales.vOrderAgg
WITH SCHEMABINDING
AS
SELECT  o.CustomerId,
        COUNT_BIG(*)   AS OrderCount,     -- BẮT BUỘC khi có GROUP BY
        SUM(o.Total)   AS TotalSum        -- SUM ok; AVG/MIN/MAX/COUNT(*) KHÔNG ok
FROM    Sales.SalesOrder AS o             -- ⚠ tên HAI PHẦN: Sales.SalesOrder
GROUP BY o.CustomerId;
GO
CREATE UNIQUE CLUSTERED INDEX IX_vOrderAgg ON Sales.vOrderAgg(CustomerId);   -- ✅
CREATE NONCLUSTERED INDEX IX_vOrderAgg_Total ON Sales.vOrderAgg(TotalSum);   -- được, SAU khi có UCI
GO

SELECT * FROM Sales.vOrderAgg ORDER BY CustomerId;

/*  ĐIỀU KIỆN ĐẦY ĐỦ CHO INDEXED VIEW (danh sách hay ra đề nhất của mục View):
      1. WITH SCHEMABINDING + tên hai phần (schema.table).
      2. Index đầu tiên PHẢI là UNIQUE CLUSTERED.
      3. Có GROUP BY ⇒ BẮT BUỘC COUNT_BIG(*).
      4. CẤM: OUTER JOIN, UNION/UNION ALL, DISTINCT, TOP, ORDER BY, subquery, CTE,
              hàm cửa sổ (OVER), MIN/MAX/AVG/STDEV/VAR khi GROUP BY, COUNT(*),
              self-join, bảng phái sinh, TEXT/NTEXT/IMAGE, hàm không xác định.
      5. Chỉ dùng hàm DETERMINISTIC (không GETDATE, NEWID, RAND).
      6. Đúng 7 tuỳ chọn SET ở trên.
      7. Bảng nền cùng database, cùng chủ sở hữu.                                */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 4 — AUTOMATIC MATCHING & NOEXPAND
───────────────────────────────────────────────────────────────────────────────*/
SET STATISTICS IO ON;

-- Truy vấn KHÔNG nhắc tên view. Enterprise/Developer/Azure SQL: optimizer tự dùng view.
SELECT CustomerId, COUNT_BIG(*) AS OrderCount
FROM   Sales.SalesOrder GROUP BY CustomerId;

-- Ép dùng indexed view (BẮT BUỘC trên bản Standard/Web/Express)
SELECT CustomerId, OrderCount FROM Sales.vOrderAgg WITH (NOEXPAND);

SET STATISTICS IO OFF;
SELECT SERVERPROPERTY('Edition') AS Edition;
/*  Không có NOEXPAND trên bản Standard ⇒ optimizer "expand" view thành truy vấn
    gốc và quét bảng nền ⇒ mất hoàn toàn lợi ích của indexed view.
    🎯 Câu hỏi tủ: "Đã tạo indexed view nhưng plan vẫn quét bảng nền, làm gì?"
       ⇒ Thêm hint WITH (NOEXPAND).                                             */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 5 — SCHEMABINDING BẢO VỆ SCHEMA
───────────────────────────────────────────────────────────────────────────────*/
BEGIN TRY
    ALTER TABLE Sales.SalesOrder DROP COLUMN Total;
END TRY
BEGIN CATCH
    SELECT 'SCHEMABINDING chặn DROP COLUMN' AS Demo, ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS Msg;
END CATCH;
GO
/*  Msg 5074 — "The object 'vOrderAgg' is dependent on column 'Total'."
    ⇒ Chi phí của SCHEMABINDING: muốn đổi schema phải DROP view trước.
    Tra cứu phụ thuộc: */
-- sys.dm_sql_referencing_entities trả về đối tượng ĐANG THAM CHIẾU tới bảng
SELECT referencing_schema_name, referencing_entity_name, referencing_class_desc
FROM   sys.dm_sql_referencing_entities('Sales.SalesOrder', 'OBJECT');

-- Chiều ngược lại: view/proc này đang phụ thuộc vào những gì
SELECT referenced_schema_name, referenced_entity_name, referenced_minor_name
FROM   sys.dm_sql_referenced_entities('Sales.vOrderAgg', 'OBJECT');
GO


/*═══════════════════ PHẦN B — FUNCTIONS ══════════════════════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 6 — BA LOẠI HÀM & SO SÁNH HIỆU NĂNG
───────────────────────────────────────────────────────────────────────────────*/
-- (1) SCALAR UDF — chậm nhất
CREATE OR ALTER FUNCTION Sales.fnOrderTotal_Scalar (@OrderId INT)
RETURNS DECIMAL(19,4)
AS
BEGIN
    DECLARE @t DECIMAL(19,4);
    SELECT @t = SUM(Qty * UnitPrice) FROM Sales.SalesDetail WHERE OrderId = @OrderId;
    RETURN ISNULL(@t, 0);
END;
GO

-- (2) MULTI-STATEMENT TVF (mTVF) — ước lượng số dòng sai, phải vật chất hoá
CREATE OR ALTER FUNCTION Sales.fnOrdersByCustomer_MSTVF (@CustomerId INT)
RETURNS @r TABLE (OrderId INT, OrderDate DATE, Total DECIMAL(19,4))
AS
BEGIN
    INSERT @r
    SELECT o.OrderId, o.OrderDate, SUM(d.Qty * d.UnitPrice)
    FROM   Sales.SalesOrder o
    JOIN   Sales.SalesDetail d ON d.OrderId = o.OrderId
    WHERE  o.CustomerId = @CustomerId
    GROUP  BY o.OrderId, o.OrderDate;
    RETURN;
END;
GO

-- (3) INLINE TVF (iTVF) — TỐT NHẤT, được "nở" vào query như view có tham số
CREATE OR ALTER FUNCTION Sales.fnOrdersByCustomer_ITVF (@CustomerId INT)
RETURNS TABLE
AS
RETURN
(
    SELECT o.OrderId, o.OrderDate, SUM(d.Qty * d.UnitPrice) AS Total
    FROM   Sales.SalesOrder o
    JOIN   Sales.SalesDetail d ON d.OrderId = o.OrderId
    WHERE  o.CustomerId = @CustomerId
    GROUP  BY o.OrderId, o.OrderDate
);
GO
/*  ⚠ iTVF: KHÔNG có BEGIN...END, KHÔNG khai báo cấu trúc bảng trả về,
      thân hàm là MỘT câu SELECT duy nhất sau RETURN.                           */

SET STATISTICS TIME ON;
SELECT COUNT(*) FROM Sales.fnOrdersByCustomer_MSTVF(1);
SELECT COUNT(*) FROM Sales.fnOrdersByCustomer_ITVF(1);
SET STATISTICS TIME OFF;
/*  So sánh trên execution plan:
      mTVF → toán tử "Table Valued Function" + ước lượng 100 dòng cố định
             (từ SQL 2014; các bản cũ ước lượng 1 dòng), không parallel.
      iTVF → không có toán tử riêng; nội dung hàm được ghép thẳng vào plan,
             optimizer thấy được thống kê thật ⇒ ước lượng chuẩn.
    🎯 Câu hỏi tủ: "TVF chạy chậm, ước lượng số dòng sai" ⇒ VIẾT LẠI THÀNH iTVF. */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 7 — SCALAR UDF TRONG SELECT: "HIDDEN RBAR"
───────────────────────────────────────────────────────────────────────────────*/
SET STATISTICS TIME ON;
-- ❌ Gọi scalar UDF cho TỪNG dòng
SELECT TOP (5000) OrderId, Sales.fnOrderTotal_Scalar(OrderId) AS Total
FROM   Sales.SalesOrder ORDER BY OrderId;

-- ✅ Viết lại bằng APPLY + iTVF (set-based)
SELECT TOP (5000) o.OrderId, x.Total
FROM   Sales.SalesOrder o
CROSS APPLY (SELECT SUM(d.Qty * d.UnitPrice) AS Total
             FROM Sales.SalesDetail d WHERE d.OrderId = o.OrderId) x
ORDER BY o.OrderId;
SET STATISTICS TIME OFF;
/*  Scalar UDF (khi KHÔNG inline được):
      - Gọi 1 lần/dòng (RBAR), không hiện chi phí trên execution plan ⇒ khó chẩn đoán.
      - CHẶN PARALLELISM cho toàn bộ truy vấn (kể cả phần khác).
      - Bị coi là non-sargable khi đặt trong WHERE.                             */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 8 — SCALAR UDF INLINING (Froid) | SQL 2019+
───────────────────────────────────────────────────────────────────────────────*/
-- ≥150 mới có scalar UDF inlining. Đặt mức cao nhất mà instance hỗ trợ.
-- ⚠ EXEC(...) chỉ nhận chuỗi/biến nối đơn giản, KHÔNG nhận biểu thức có CAST ⇒ Msg 102.
--   Dựng câu lệnh vào biến trước rồi mới thực thi.
DECLARE @lvl NVARCHAR(3) = CAST(CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) * 10 AS NVARCHAR(3));
DECLARE @cmd NVARCHAR(200) = N'ALTER DATABASE DP800_Lab SET COMPATIBILITY_LEVEL = ' + @lvl;
EXEC sys.sp_executesql @cmd;
GO
SELECT  o.name, m.is_inlineable, m.inline_type,
        OBJECTPROPERTY(o.object_id,'IsScalarFunction') AS IsScalar
FROM    sys.sql_modules m
JOIN    sys.objects o ON o.object_id = m.object_id
WHERE   o.type = 'FN';
GO

-- Hàm KHÔNG inline được (có WHILE loop)
CREATE OR ALTER FUNCTION dbo.fnNotInlineable (@n INT)
RETURNS INT
AS
BEGIN
    DECLARE @s INT = 0;
    WHILE @n > 0 BEGIN SET @s += @n; SET @n -= 1; END;   -- vòng lặp ⇒ không inline
    RETURN @s;
END;
GO
SELECT o.name, m.is_inlineable FROM sys.sql_modules m
JOIN sys.objects o ON o.object_id = m.object_id WHERE o.name = 'fnNotInlineable';
GO
/*  KHÔNG INLINE ĐƯỢC nếu hàm có: WHILE/GOTO, EXEC / sp_executesql, biến bảng hoặc
    bảng tạm, đệ quy, gọi hàm không xác định (GETDATE ở một số ngữ cảnh),
    aggregate truyền tham số, EXECUTE AS, hàm sửa dữ liệu, TIME ZONE conversion.
    Tắt inlining ở 3 cấp:
      - Hàm : CREATE FUNCTION ... WITH INLINE = OFF
      - Query: OPTION (USE HINT('DISABLE_TSQL_SCALAR_UDF_INLINING'))
      - DB  : ALTER DATABASE SCOPED CONFIGURATION SET TSQL_SCALAR_UDF_INLINING = OFF; */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 9 — TUỲ CHỌN HÀM & GIỚI HẠN
───────────────────────────────────────────────────────────────────────────────*/
CREATE OR ALTER FUNCTION dbo.fnSafeDivide (@a DECIMAL(19,4), @b DECIMAL(19,4))
RETURNS DECIMAL(19,4)
WITH SCHEMABINDING, RETURNS NULL ON NULL INPUT
AS
BEGIN
    RETURN CASE WHEN @b = 0 THEN NULL ELSE @a / @b END;
END;
GO
SELECT dbo.fnSafeDivide(10, 4) AS Ok, dbo.fnSafeDivide(10, NULL) AS NullShortCircuit;
GO
/*  WITH SCHEMABINDING trên hàm ⇒ giúp hàm được coi là deterministic hơn,
      ĐIỀU KIỆN để index computed column có dùng hàm đó.
    RETURNS NULL ON NULL INPUT ⇒ bỏ qua thân hàm khi tham số NULL (nhanh hơn).

    TRONG HÀM KHÔNG ĐƯỢC:
      - Sửa dữ liệu bảng thật (chỉ sửa biến bảng cục bộ).
      - Gọi stored procedure (trừ extended SP).
      - Dùng TRY...CATCH, RAISERROR, THROW.
      - Dùng hàm không xác định như NEWID(), RAND() không seed (GETDATE() được
        phép từ SQL 2005 nhưng làm hàm thành nondeterministic).
      - CREATE/ALTER bảng, dùng bảng tạm (#tmp) — chỉ dùng được biến bảng.
      - Câu lệnh động (EXEC).                                                   */

-- Hàm dùng trong computed column có index (cần SCHEMABINDING + deterministic)
DROP TABLE IF EXISTS dbo.Ratio;
CREATE TABLE dbo.Ratio
(
    Id INT IDENTITY PRIMARY KEY,
    A DECIMAL(19,4) NOT NULL, B DECIMAL(19,4) NOT NULL,
    R AS dbo.fnSafeDivide(A, B) PERSISTED
);
CREATE INDEX IX_Ratio_R ON dbo.Ratio(R);       -- ✅ chỉ được nhờ SCHEMABINDING
GO


/*═══════════════════ PHẦN C — TRIGGERS ═══════════════════════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 10 — LỖI KINH ĐIỂN NHẤT: TRIGGER VIẾT KIỂU "MỘT DÒNG"
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS dbo.AuditLog;
CREATE TABLE dbo.AuditLog
(
    LogId    INT IDENTITY PRIMARY KEY,
    TableNm  SYSNAME NOT NULL,
    KeyValue INT NOT NULL,
    Action   VARCHAR(10) NOT NULL,
    LoggedAt DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    LoggedBy SYSNAME NOT NULL DEFAULT SUSER_SNAME()
);
GO

-- ❌ SAI: giả định inserted chỉ có 1 dòng
CREATE OR ALTER TRIGGER Sales.trg_Customer_Audit_WRONG
ON Sales.Customer AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id INT;
    SELECT @id = CustomerId FROM inserted;      -- chỉ lấy được 1 giá trị tuỳ ý!
    INSERT dbo.AuditLog (TableNm, KeyValue, Action) VALUES ('Customer', @id, 'INSERT');
END;
GO
INSERT Sales.Customer (Name, Region) VALUES (N'X1',N'North'),(N'X2',N'South'),(N'X3',N'North');
SELECT 'TRIGGER SAI' AS Demo, COUNT(*) AS SoDongDuocGhi FROM dbo.AuditLog;   -- = 1 (mất 2 dòng!)
GO

-- ✅ ĐÚNG: set-based
DROP TRIGGER Sales.trg_Customer_Audit_WRONG;
DELETE dbo.AuditLog;
GO
CREATE OR ALTER TRIGGER Sales.trg_Customer_Audit
ON Sales.Customer AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted)
        RETURN;                                  -- thoát sớm khi DML 0 dòng

    -- Xác định loại thao tác bằng sự có mặt của inserted/deleted
    INSERT dbo.AuditLog (TableNm, KeyValue, Action)
    SELECT 'Customer', COALESCE(i.CustomerId, d.CustomerId),
           CASE WHEN i.CustomerId IS NOT NULL AND d.CustomerId IS NOT NULL THEN 'UPDATE'
                WHEN i.CustomerId IS NOT NULL                              THEN 'INSERT'
                ELSE 'DELETE' END
    FROM        inserted i
    FULL JOIN   deleted  d ON d.CustomerId = i.CustomerId;
END;
GO
INSERT Sales.Customer (Name, Region) VALUES (N'Y1',N'North'),(N'Y2',N'South'),(N'Y3',N'North');
UPDATE Sales.Customer SET Region = N'South' WHERE Name IN (N'Y1', N'Y3');
SELECT 'TRIGGER ĐÚNG' AS Demo, Action, COUNT(*) AS Cnt FROM dbo.AuditLog GROUP BY Action;
GO
/*  🎯 GHI NHỚ: inserted/deleted là BẢNG, có thể 0, 1 hoặc N dòng.
    Mọi trigger phải viết bằng JOIN/set-based. Đề thi hay đưa đoạn code
    "SELECT @var = ... FROM inserted" và hỏi lỗi ở đâu.
    Bảng inserted/deleted nằm trong tempdb (thực tế đọc từ version store),
    KHÔNG được đánh index, và không tồn tại ngoài phạm vi trigger.               */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 11 — UPDATE() và COLUMNS_UPDATED()
───────────────────────────────────────────────────────────────────────────────*/
CREATE OR ALTER TRIGGER Sales.trg_Customer_ProtectRegion
ON Sales.Customer AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(Region)          -- chỉ chạy khi cột Region NẰM TRONG câu SET
    BEGIN
        INSERT dbo.AuditLog (TableNm, KeyValue, Action)
        SELECT 'Customer.Region', i.CustomerId, 'REGION_CHG'
        FROM   inserted i JOIN deleted d ON d.CustomerId = i.CustomerId
        WHERE  ISNULL(i.Region,'') <> ISNULL(d.Region,'');   -- và giá trị THỰC SỰ đổi
    END;
END;
GO
UPDATE Sales.Customer SET Name = N'Đổi tên' WHERE CustomerId = 1;   -- không ghi log
UPDATE Sales.Customer SET Region = N'Central' WHERE CustomerId = 1; -- có ghi log
SELECT * FROM dbo.AuditLog WHERE TableNm = 'Customer.Region';
GO
/*  ⚠ UPDATE(col) trả TRUE khi cột XUẤT HIỆN trong câu lệnh, kể cả khi
    gán lại đúng giá trị cũ. Muốn biết giá trị THẬT SỰ đổi phải so sánh
    inserted vs deleted như trên. Đây là bẫy hay gặp.
    UPDATE(col) cũng trả TRUE cho mọi cột trong lệnh INSERT.                    */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 12 — INSTEAD OF TRIGGER: LÀM CHO VIEW GHI ĐƯỢC
───────────────────────────────────────────────────────────────────────────────*/
CREATE OR ALTER VIEW Sales.vCustomerOrder
AS
SELECT o.OrderId, o.OrderDate, o.Total, c.CustomerId, c.Name, c.Region
FROM   Sales.SalesOrder o JOIN Sales.Customer c ON c.CustomerId = o.CustomerId;
GO
-- View đa bảng ⇒ INSERT thẳng sẽ lỗi. Dùng INSTEAD OF để tự viết logic:
CREATE OR ALTER TRIGGER Sales.trg_vCustomerOrder_Insert
ON Sales.vCustomerOrder
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    -- 1. Tạo khách hàng chưa tồn tại
    INSERT Sales.Customer (Name, Region)
    SELECT DISTINCT i.Name, i.Region
    FROM   inserted i
    WHERE  NOT EXISTS (SELECT 1 FROM Sales.Customer c WHERE c.Name = i.Name);

    -- 2. Tạo đơn hàng, ánh xạ về CustomerId thật
    INSERT Sales.SalesOrder (CustomerId, OrderDate, Total)
    SELECT c.CustomerId, i.OrderDate, i.Total
    FROM   inserted i JOIN Sales.Customer c ON c.Name = i.Name;
END;
GO
INSERT Sales.vCustomerOrder (OrderDate, Total, Name, Region)
VALUES ('2026-07-20', 500, N'Khách hoàn toàn mới', N'West');

SELECT TOP (2) * FROM Sales.Customer ORDER BY CustomerId DESC;
SELECT TOP (2) * FROM Sales.SalesOrder ORDER BY OrderId DESC;
GO
/*  ⚠ INSTEAD OF:
      - Là loại trigger DUY NHẤT dùng được trên VIEW.
      - Chạy TRƯỚC khi kiểm tra constraint; AFTER chạy SAU.
      - Không dùng được INSTEAD OF DELETE/UPDATE trên bảng có FK
        với ON DELETE/UPDATE CASCADE.
      - Chỉ được MỘT INSTEAD OF trigger cho mỗi thao tác trên mỗi đối tượng.    */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 13 — TRUNCATE KHÔNG BẮN TRIGGER (bẫy audit)
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS dbo.TruncDemo;
CREATE TABLE dbo.TruncDemo (Id INT IDENTITY PRIMARY KEY, Val INT);
GO
CREATE OR ALTER TRIGGER dbo.trg_TruncDemo_Delete
ON dbo.TruncDemo AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.AuditLog (TableNm, KeyValue, Action)
    SELECT 'TruncDemo', d.Id, 'DELETE' FROM deleted d;
END;
GO
INSERT dbo.TruncDemo (Val) VALUES (1),(2),(3);
DELETE dbo.TruncDemo WHERE Val = 1;
SELECT 'Sau DELETE' AS Stage, COUNT(*) AS AuditRows FROM dbo.AuditLog WHERE TableNm='TruncDemo';

TRUNCATE TABLE dbo.TruncDemo;
SELECT 'Sau TRUNCATE' AS Stage, COUNT(*) AS AuditRows FROM dbo.AuditLog WHERE TableNm='TruncDemo';
-- ⇒ Số dòng audit KHÔNG tăng, dù dữ liệu đã bị xoá sạch!
GO
/*  🎯 ĐÁP ÁN THI: "Mọi thao tác xoá phải được ghi vết" ⇒ trigger là CHƯA ĐỦ,
      phải THU HỒI quyền ALTER trên bảng (TRUNCATE cần quyền ALTER).
    Tương tự: BULK INSERT / bcp mặc định KHÔNG bắn trigger,
      trừ khi chỉ định FIRE_TRIGGERS. WRITETEXT/UPDATETEXT cũng không.          */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 14 — DDL TRIGGER & LOGON TRIGGER
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS dbo.DdlAudit;
CREATE TABLE dbo.DdlAudit
(
    AuditId   INT IDENTITY PRIMARY KEY,
    EventType SYSNAME,
    ObjectNm  SYSNAME NULL,
    LoginNm   SYSNAME,
    TsqlText  NVARCHAR(MAX),
    EventXml  XML,
    OccurredAt DATETIME2(3) DEFAULT SYSUTCDATETIME()
);
GO
CREATE OR ALTER TRIGGER trg_DdlAudit
ON DATABASE
FOR CREATE_TABLE, ALTER_TABLE, DROP_TABLE, CREATE_INDEX, DROP_INDEX
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @x XML = EVENTDATA();
    INSERT dbo.DdlAudit (EventType, ObjectNm, LoginNm, TsqlText, EventXml)
    VALUES (@x.value('(/EVENT_INSTANCE/EventType)[1]',   'SYSNAME'),
            @x.value('(/EVENT_INSTANCE/ObjectName)[1]',  'SYSNAME'),
            @x.value('(/EVENT_INSTANCE/LoginName)[1]',   'SYSNAME'),
            @x.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)'),
            @x);
END;
GO
CREATE TABLE dbo.TestDdl (Id INT);
DROP TABLE dbo.TestDdl;
SELECT EventType, ObjectNm, LoginNm, TsqlText FROM dbo.DdlAudit;
GO

-- Chặn DROP TABLE hoàn toàn (kỹ thuật bảo vệ production)
CREATE OR ALTER TRIGGER trg_PreventDropTable
ON DATABASE FOR DROP_TABLE
AS
BEGIN
    PRINT 'Cấm DROP TABLE trên database này. Liên hệ DBA.';
    ROLLBACK;               -- huỷ lệnh DDL
END;
GO
BEGIN TRY
    CREATE TABLE dbo.WillNotDrop (Id INT);
    DROP TABLE dbo.WillNotDrop;
END TRY
BEGIN CATCH SELECT 'DDL trigger chặn DROP' AS Demo, ERROR_MESSAGE() AS Msg; END CATCH;
GO
DROP TRIGGER trg_PreventDropTable ON DATABASE;
DROP TABLE IF EXISTS dbo.WillNotDrop;
GO
/*  PHẠM VI DDL TRIGGER:
      ON DATABASE   — sự kiện trong 1 database (CREATE_TABLE, ALTER_INDEX...)
      ON ALL SERVER — sự kiện cấp server (CREATE_LOGIN, CREATE_DATABASE...)
    Nhóm sự kiện: DDL_TABLE_EVENTS, DDL_DATABASE_LEVEL_EVENTS, DDL_LOGIN_EVENTS...
    DDL trigger KHÔNG có inserted/deleted, dùng EVENTDATA() trả về XML.
    DDL trigger không bắt được các thao tác hệ thống ngầm và một số lệnh
      (vd: CREATE nhất thời trong tempdb).

  LOGON TRIGGER (cấp server) — giới hạn kết nối/chặn theo giờ:
      CREATE TRIGGER trg_LimitConn ON ALL SERVER FOR LOGON
      AS
      BEGIN
          IF ORIGINAL_LOGIN() = 'AppUser'
             AND (SELECT COUNT(*) FROM sys.dm_exec_sessions
                  WHERE is_user_process = 1 AND original_login_name = 'AppUser') > 5
              ROLLBACK;   -- từ chối phiên
      END;
  ⚠ Logon trigger lỗi ⇒ CHẶN MỌI NGƯỜI ĐĂNG NHẬP. Cứu bằng DAC (Dedicated
    Admin Connection: sqlcmd -A) hoặc khởi động ở chế độ single-user (-f).       */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 15 — THỨ TỰ, LỒNG NHAU, ĐỆ QUY & KHI NÀO KHÔNG DÙNG TRIGGER
───────────────────────────────────────────────────────────────────────────────*/
-- Chỉ điều khiển được trigger ĐẦU TIÊN và CUỐI CÙNG
EXEC sp_settriggerorder @triggername = 'Sales.trg_Customer_Audit',
                        @order = 'First', @stmttype = 'INSERT';

SELECT  OBJECT_NAME(parent_id) AS TableName, name AS TriggerName,
        is_disabled, is_instead_of_trigger
FROM    sys.triggers WHERE parent_class = 1;

-- Bật/tắt trigger (hữu ích khi nạp dữ liệu hàng loạt)
DISABLE TRIGGER Sales.trg_Customer_Audit ON Sales.Customer;
ENABLE  TRIGGER Sales.trg_Customer_Audit ON Sales.Customer;

-- Cấu hình nested / recursive
SELECT name, value_in_use FROM sys.configurations WHERE name = 'nested triggers';  -- mặc định 1
SELECT name, is_recursive_triggers_on FROM sys.databases WHERE database_id = DB_ID();
-- ALTER DATABASE DP800_Lab SET RECURSIVE_TRIGGERS ON;   -- mặc định OFF
GO
/*  - Nested triggers: trigger A gây DML kích hoạt trigger B. Mặc định BẬT, tối đa 32 cấp.
    - Recursive triggers (trực tiếp): trigger tự kích hoạt chính nó. Mặc định TẮT
      ở cấp DATABASE. Tắt nested triggers cũng tắt luôn recursive gián tiếp.
    - TRIGGER_NESTLEVEL() cho biết đang ở cấp mấy.
    - Trigger chạy TRONG CÙNG transaction với lệnh gốc ⇒ ROLLBACK trong trigger
      huỷ luôn lệnh gốc, và mọi lệnh sau ROLLBACK trong trigger vẫn chạy
      (ngoài transaction) ⇒ nên RETURN ngay sau ROLLBACK.
    - LUÔN SET NOCOUNT ON để tránh làm hỏng ứng dụng đọc rowcount.

  KHI NÀO KHÔNG DÙNG TRIGGER (bảng đối chiếu ra đề rất nhiều):
    ┌────────────────────────────────────┬──────────────────────────────────┐
    │ Nhu cầu                            │ Giải pháp TỐT HƠN trigger        │
    ├────────────────────────────────────┼──────────────────────────────────┤
    │ Ghi lịch sử thay đổi dữ liệu       │ Temporal table                   │
    │ Chống giả mạo / audit tuân thủ     │ Ledger table                     │
    │ Kiểm tra giá trị hợp lệ            │ CHECK constraint                 │
    │ Áp giá trị mặc định                │ DEFAULT constraint               │
    │ Toàn vẹn tham chiếu                │ FOREIGN KEY                      │
    │ Lấy dữ liệu vừa ghi                │ OUTPUT clause                    │
    │ Đồng bộ ra hệ thống khác           │ CDC / Change Tracking            │
    │ Tính toán dẫn xuất trong cùng bảng │ Computed column                  │
    └────────────────────────────────────┴──────────────────────────────────┘
    Trigger là công cụ mạnh nhưng ẨN, khó debug, chạy đồng bộ trong transaction
    ⇒ luôn ưu tiên phương án khai báo (declarative) trước.                       */

-- OUTPUT clause: thay thế trigger khi chỉ cần lấy dữ liệu vừa ghi
DECLARE @out TABLE (CustomerId INT, Name NVARCHAR(100));
INSERT Sales.Customer (Name, Region)
OUTPUT inserted.CustomerId, inserted.Name INTO @out
VALUES (N'Dùng OUTPUT', N'East');
SELECT * FROM @out;
GO


/*═══════════════════════════════════════════════════════════════════════════════
  CHECKLIST SAU LAB 05
  □ Đọc một CREATE VIEW và nói ngay có tạo được indexed view không, thiếu gì.
  □ Nhớ vì sao GROUP BY phải kèm COUNT_BIG(*).
  □ Biết khi nào phải dùng WITH (NOEXPAND).
  □ Phân biệt iTVF / mTVF / scalar UDF và cách viết lại cho nhanh.
  □ Kể 5 điều kiện làm scalar UDF không inline được.
  □ Viết trigger set-based đúng, dùng FULL JOIN inserted/deleted.
  □ Giải thích UPDATE(col) khác "giá trị thực sự thay đổi".
  □ Nhớ TRUNCATE / BULK INSERT không bắn trigger.
  □ Nêu 5 tình huống nên thay trigger bằng tính năng khai báo.
═══════════════════════════════════════════════════════════════════════════════*/
