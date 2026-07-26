/*═══════════════════════════════════════════════════════════════════════════════
  DP-800 | MIỀN 1 | LAB 03 — BẢNG CHUYÊN BIỆT & JSON
  Đi kèm: Claude_DP800_D1_Design_Guide.md  (mục 5 và 6)

  PHẦN A — Temporal, Ledger, Memory-Optimized, Graph, External, Vector (S1..S6)
  PHẦN B — JSON (S7..S11)

  ⚠ Một số section yêu cầu phiên bản cụ thể — đã ghi rõ ở đầu mỗi section.
    Nếu instance không hỗ trợ, VẪN ĐỌC phần chú thích: đề thi hỏi khái niệm.
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
SELECT @@VERSION AS ServerVersion,
       SERVERPROPERTY('ProductMajorVersion') AS MajorVer,   -- 16 = 2022, 17 = 2025
       SERVERPROPERTY('EngineEdition')       AS EngineEdition; -- 5 = Azure SQL DB
GO

/*═══════════════════ PHẦN A — BẢNG CHUYÊN BIỆT ═══════════════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 1 — TEMPORAL TABLE (System-Versioned) | SQL 2016+
  Bài toán: "Dữ liệu trông như thế nào tại thời điểm X?" / khôi phục dòng bị sửa nhầm.
───────────────────────────────────────────────────────────────────────────────*/
IF OBJECTPROPERTY(OBJECT_ID('dbo.EmployeeT'),'TableTemporalType') = 2
    ALTER TABLE dbo.EmployeeT SET (SYSTEM_VERSIONING = OFF);
DROP TABLE IF EXISTS dbo.EmployeeT;
DROP TABLE IF EXISTS dbo.EmployeeT_History;
GO

CREATE TABLE dbo.EmployeeT
(
    EmpId      INT           NOT NULL PRIMARY KEY CLUSTERED,
    FullName   NVARCHAR(100) NOT NULL,
    Salary     DECIMAL(19,4) NOT NULL,
    DeptId     INT           NOT NULL,
    -- 2 cột period BẮT BUỘC, kiểu DATETIME2, GENERATED ALWAYS
    ValidFrom  DATETIME2(7) GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
    ValidTo    DATETIME2(7) GENERATED ALWAYS AS ROW END   HIDDEN NOT NULL,
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.EmployeeT_History,
                              DATA_CONSISTENCY_CHECK = ON));
GO
/*  HIDDEN ⇒ SELECT * không hiện 2 cột period (đỡ vỡ ứng dụng cũ).
    Nếu không chỉ định HISTORY_TABLE, SQL tự tạo tên
    dbo.MSSQL_TemporalHistoryFor_<object_id>.                                   */

INSERT dbo.EmployeeT (EmpId, FullName, Salary, DeptId) VALUES
 (1, N'Nguyễn Văn A', 1000, 10),
 (2, N'Trần Thị B',   2000, 20);

WAITFOR DELAY '00:00:02';
DECLARE @T1 DATETIME2 = SYSUTCDATETIME();   -- mốc thời gian "trước khi tăng lương"
WAITFOR DELAY '00:00:02';

UPDATE dbo.EmployeeT SET Salary = 1500 WHERE EmpId = 1;
DELETE dbo.EmployeeT WHERE EmpId = 2;

-- ⚠ FOR SYSTEM_TIME chỉ chấp nhận HẰNG hoặc BIẾN, KHÔNG nhận lời gọi hàm
--   (viết ... TO SYSUTCDATETIME() sẽ báo Msg 102) ⇒ phải gán ra biến trước.
DECLARE @T2 DATETIME2 = SYSUTCDATETIME();

-- Trạng thái hiện tại
SELECT 'CURRENT' AS Src, EmpId, FullName, Salary FROM dbo.EmployeeT;

-- Lịch sử (dòng cũ tự động chuyển sang bảng history)
SELECT 'HISTORY' AS Src, EmpId, FullName, Salary, ValidFrom, ValidTo
FROM   dbo.EmployeeT_History;

-- 5 MỆNH ĐỀ FOR SYSTEM_TIME (thi rất hay hỏi phân biệt)
SELECT * FROM dbo.EmployeeT FOR SYSTEM_TIME AS OF @T1;                    -- ảnh chụp 1 thời điểm
SELECT * FROM dbo.EmployeeT FOR SYSTEM_TIME FROM @T1 TO @T2; -- (from, to)  — loại biên
SELECT * FROM dbo.EmployeeT FOR SYSTEM_TIME BETWEEN @T1 AND @T2; -- [from, to] — gồm biên trên
SELECT * FROM dbo.EmployeeT FOR SYSTEM_TIME CONTAINED IN (@T1, @T2); -- dòng NẰM TRỌN trong khoảng
SELECT * FROM dbo.EmployeeT FOR SYSTEM_TIME ALL;                          -- current + history

-- Khôi phục dòng đã xóa nhầm — sức mạnh thực sự của temporal table
INSERT dbo.EmployeeT (EmpId, FullName, Salary, DeptId)
SELECT EmpId, FullName, Salary, DeptId
FROM   dbo.EmployeeT FOR SYSTEM_TIME AS OF @T1
WHERE  EmpId = 2;
SELECT * FROM dbo.EmployeeT;

-- Chính sách tự dọn lịch sử (retention)
ALTER TABLE dbo.EmployeeT SET (SYSTEM_VERSIONING = ON
    (HISTORY_TABLE = dbo.EmployeeT_History, HISTORY_RETENTION_PERIOD = 6 MONTHS));
ALTER DATABASE CURRENT SET TEMPORAL_HISTORY_RETENTION ON;

SELECT name, temporal_type_desc, history_retention_period, history_retention_period_unit_desc
FROM   sys.tables WHERE name IN ('EmployeeT','EmployeeT_History');
/*  ⚠ QUY TẮC SỐNG CÒN CỦA TEMPORAL:
      - Bảng hiện tại BẮT BUỘC có PRIMARY KEY; bảng history thì KHÔNG được có PK/FK/
        identity/constraint và không được sửa trực tiếp.
      - Cấu trúc cột 2 bảng phải khớp hệt.
      - Không thể TRUNCATE, không thể DROP khi SYSTEM_VERSIONING = ON.
        Muốn ALTER schema: SQL tự lan xuống history, nhưng để DROP phải SET OFF trước.
      - Thời gian là UTC, do ENGINE gán — ứng dụng không ghi đè được.
      - ON DELETE CASCADE trỏ TỚI bảng temporal ⇒ KHÔNG cho phép.
    → Đề thi: "audit thay đổi dữ liệu, truy vấn dữ liệu quá khứ" = TEMPORAL.
             "chống giả mạo, chứng minh với kiểm toán bằng mật mã" = LEDGER.     */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 2 — LEDGER TABLE | SQL 2022+ / Azure SQL
  Bài toán: tamper-evident, chứng minh dữ liệu chưa từng bị sửa lén.
───────────────────────────────────────────────────────────────────────────────*/
-- (a) UPDATABLE LEDGER: cho phép UPDATE/DELETE nhưng lưu vết bất biến
IF OBJECT_ID('dbo.Payment') IS NOT NULL
    PRINT 'Bỏ qua: bảng ledger không DROP được nếu DB bật LEDGER = ON';
GO
BEGIN TRY
    EXEC(N'
    CREATE TABLE dbo.Payment
    (
        PaymentId  INT           NOT NULL PRIMARY KEY CLUSTERED,
        Payer      NVARCHAR(100) NOT NULL,
        Amount     DECIMAL(19,4) NOT NULL
    )
    WITH (LEDGER = ON (LEDGER_VIEW = dbo.Payment_Ledger));
    ');
    PRINT 'Đã tạo updatable ledger table.';
END TRY
BEGIN CATCH
    SELECT 'Ledger không khả dụng' AS Info, ERROR_MESSAGE() AS Msg;
END CATCH;
GO

IF OBJECT_ID('dbo.Payment') IS NOT NULL
BEGIN
    INSERT dbo.Payment VALUES (1, N'Công ty X', 1000);
    UPDATE dbo.Payment SET Amount = 9999 WHERE PaymentId = 1;   -- cố tình "sửa lén"

    SELECT * FROM dbo.Payment;
    -- LEDGER VIEW phơi bày toàn bộ: bản ghi cũ vẫn còn, kèm loại thao tác
    SELECT * FROM dbo.Payment_Ledger ORDER BY ledger_transaction_id;
    -- Ai làm, lúc nào:
    SELECT * FROM sys.database_ledger_transactions ORDER BY commit_time DESC;
END;
GO

-- (b) APPEND-ONLY LEDGER: chỉ cho INSERT, UPDATE/DELETE bị chặn ở mức ENGINE
BEGIN TRY
    EXEC(N'
    CREATE TABLE dbo.AuditLog
    (
        LogId   INT IDENTITY PRIMARY KEY,
        Message NVARCHAR(400) NOT NULL
    )
    WITH (LEDGER = ON (APPEND_ONLY = ON));
    ');
    EXEC(N'INSERT dbo.AuditLog(Message) VALUES (N''sự kiện 1'')');
    EXEC(N'UPDATE dbo.AuditLog SET Message = N''sửa'' WHERE LogId = 1');  -- Msg 37359
END TRY
BEGIN CATCH
    SELECT 'APPEND_ONLY chặn UPDATE' AS Demo, ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS Msg;
END CATCH;
GO
/*  KIẾN THỨC THI VỀ LEDGER:
      - Mọi giao dịch được băm (SHA-256) thành Merkle tree ⇒ database digest.
      - Digest có thể lưu ở nơi BẤT BIẾN bên ngoài (Azure Blob immutable storage,
        Azure Confidential Ledger) ⇒ ngay cả DBA/sysadmin sửa lén cũng bị phát hiện.
      - Xác minh: sys.sp_verify_database_ledger / sp_verify_database_ledger_from_digest_storage.
      - Ledger table KHÔNG THỂ DROP (chỉ "dropped ledger table"), không thể tắt LEDGER.
      - Không hỗ trợ: IDENTITY trong updatable ledger có ràng buộc, ALTER cột hạn chế,
        không dùng được với temporal system-versioning do người dùng tự tạo.
      SO SÁNH NHANH:
        Temporal = "xem lại quá khứ" (ai cũng đọc/ghi được history nếu tắt versioning)
        Ledger   = "chứng minh không ai sửa được" (bằng mật mã, cả sysadmin)         */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 3 — MEMORY-OPTIMIZED TABLE (In-Memory OLTP)
───────────────────────────────────────────────────────────────────────────────*/
-- Bước bắt buộc: filegroup MEMORY_OPTIMIZED_DATA (Azure SQL DB Premium tự có)
BEGIN TRY
    IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE type = 'FX')
    BEGIN
        DECLARE @path NVARCHAR(400) =
            CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(400)) + N'DP800_IMOLTP';
        EXEC(N'ALTER DATABASE DP800_Lab ADD FILEGROUP IMOLTP_FG CONTAINS MEMORY_OPTIMIZED_DATA');
        EXEC(N'ALTER DATABASE DP800_Lab ADD FILE (name = ''IMOLTP_File'', filename = ''' + @path + N''') TO FILEGROUP IMOLTP_FG');
    END;
END TRY
BEGIN CATCH
    SELECT 'In-Memory OLTP không khả dụng' AS Info, ERROR_MESSAGE() AS Msg;
END CATCH;
GO

DROP TABLE IF EXISTS dbo.SessionState;
DROP TABLE IF EXISTS dbo.HotOrder;
GO
BEGIN TRY
    -- (a) DURABILITY = SCHEMA_AND_DATA : bền vững như bảng thường
    EXEC(N'
    CREATE TABLE dbo.HotOrder
    (
        OrderId  INT           NOT NULL,
        Amount   DECIMAL(19,4) NOT NULL,
        Status   TINYINT       NOT NULL,
        CONSTRAINT PK_HotOrder PRIMARY KEY NONCLUSTERED HASH (OrderId) WITH (BUCKET_COUNT = 131072),
        INDEX IX_Status NONCLUSTERED (Status)
    ) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);
    ');

    -- (b) DURABILITY = SCHEMA_ONLY : mất dữ liệu khi restart, nhanh nhất — staging/ETL/session
    EXEC(N'
    CREATE TABLE dbo.SessionState
    (
        SessionId  UNIQUEIDENTIFIER NOT NULL PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT = 8192),
        Payload    NVARCHAR(1000)   NULL
    ) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_ONLY);
    ');

    -- Natively compiled stored procedure
    EXEC(N'
    CREATE OR ALTER PROCEDURE dbo.usp_AddHotOrder
        @OrderId INT, @Amount DECIMAL(19,4)
    WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
    AS
    BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N''us_english'')
        INSERT dbo.HotOrder (OrderId, Amount, Status) VALUES (@OrderId, @Amount, 1);
    END;
    ');
    EXEC dbo.usp_AddHotOrder @OrderId = 1, @Amount = 500;
    SELECT * FROM dbo.HotOrder;
    PRINT 'In-Memory OLTP OK';
END TRY
BEGIN CATCH
    SELECT 'Lỗi In-Memory' AS Info, ERROR_MESSAGE() AS Msg;
END CATCH;
GO
/*  ĐIỂM THI VỀ MEMORY-OPTIMIZED TABLE:
    - Bảng nằm HOÀN TOÀN trong RAM; index KHÔNG được ghi xuống đĩa (dựng lại lúc recovery).
    - HASH index: chỉ tốt cho tìm ĐÚNG BẰNG (=). BUCKET_COUNT ≈ 1–2× số giá trị
      DISTINCT, làm tròn lên lũy thừa 2. Quá nhỏ ⇒ chuỗi va chạm dài; quá lớn ⇒ phí RAM.
      HASH index KHÔNG hỗ trợ quét theo dải hay ORDER BY.
    - NONCLUSTERED (Bw-tree) index: hỗ trợ range + ORDER BY một chiều (theo đúng
      thứ tự đã khai báo; ORDER BY ngược lại không dùng được index).
    - KHÔNG có clustered index. Không có khoá (lock-free, optimistic MVCC)
      ⇒ giải quyết nghẽn latch/lock, nhưng có thể gặp lỗi 41302 write-write conflict.
    - Cross-container transaction phải chỉ định hint isolation:
      SELECT ... FROM dbo.HotOrder WITH (SNAPSHOT).
    - Natively compiled SP: biên dịch thành DLL C, chỉ truy cập được bảng
      memory-optimized, BEGIN ATOMIC bắt buộc, hạn chế cú pháp T-SQL.
    → Đề thi: "nghẽn lock/latch, cần thông lượng giao dịch cực cao" = memory-optimized.
             "bảng staging ETL tốc độ tối đa, không cần bền vững"    = SCHEMA_ONLY.  */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 4 — GRAPH TABLE (NODE / EDGE) | SQL 2017+
  Bài toán: quan hệ nhiều tầng, độ sâu không xác định (mạng xã hội, BOM, chuỗi cung ứng).
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS dbo.Follows;
DROP TABLE IF EXISTS dbo.PersonNode;
GO
CREATE TABLE dbo.PersonNode
(
    PersonId INT           NOT NULL PRIMARY KEY,
    Name     NVARCHAR(100) NOT NULL
) AS NODE;

CREATE TABLE dbo.Follows
(
    Since DATE NOT NULL DEFAULT '2026-01-01'
) AS EDGE;

INSERT dbo.PersonNode VALUES (1,N'An'),(2,N'Bình'),(3,N'Cường'),(4,N'Dung'),(5,N'Em');

-- ⚠ T-SQL KHÔNG hỗ trợ "(a, b) IN ((1,2),...)" (row-value constructor) ⇒ dùng bảng dẫn xuất.
INSERT dbo.Follows ($from_id, $to_id, Since)
SELECT p1.$node_id, p2.$node_id, '2026-01-01'
FROM   (VALUES (1,2),(2,3),(3,4),(4,5),(1,3)) AS e(FromId, ToId)
JOIN   dbo.PersonNode p1 ON p1.PersonId = e.FromId
JOIN   dbo.PersonNode p2 ON p2.PersonId = e.ToId;

-- Truy vấn MATCH: An theo dõi ai?
SELECT p1.Name AS Follower, p2.Name AS Followee
FROM   dbo.PersonNode p1, dbo.Follows f, dbo.PersonNode p2
WHERE  MATCH(p1-(f)->p2) AND p1.Name = N'An';

-- SHORTEST_PATH (SQL 2019+): đường ngắn nhất từ An tới mọi người
SELECT  p1.Name AS StartNode,
        LAST_VALUE(p2.Name)   WITHIN GROUP (GRAPH PATH) AS EndNode,
        STRING_AGG(p2.Name,'->') WITHIN GROUP (GRAPH PATH) AS Path,
        COUNT(p2.Name)        WITHIN GROUP (GRAPH PATH) AS Hops
FROM    dbo.PersonNode  AS p1,
        dbo.Follows FOR PATH AS f,
        dbo.PersonNode FOR PATH AS p2
WHERE   MATCH(SHORTEST_PATH(p1(-(f)->p2)+))
  AND   p1.Name = N'An';
/*  ĐIỂM THI:
    - NODE table tự có cột ẩn $node_id (JSON chứa object_id + id nội bộ).
    - EDGE table tự có $edge_id, $from_id, $to_id. Edge có thể nối bất kỳ node nào
      trừ khi khai báo EDGE CONSTRAINT ... CONNECTION (A TO B).
    - MATCH chỉ dùng trong WHERE của SELECT, không dùng cho UPDATE/DELETE trực tiếp.
    - Không hỗ trợ: temporal graph tables kết hợp, MATCH với OUTER JOIN,
      SHORTEST_PATH trong subquery/view.
    - Khi nào chọn graph thay vì self-join/CTE đệ quy? Khi độ sâu KHÔNG XÁC ĐỊNH
      và quan hệ đa dạng. Với cây phân cấp cố định, HIERARCHYID hoặc recursive CTE
      vẫn đơn giản hơn.                                                          */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 5 — EXTERNAL TABLE (Data Virtualization / PolyBase) | SQL 2022+
  Chỉ ĐỌC tham khảo — cần cấu hình PolyBase + nguồn ngoài thật.
───────────────────────────────────────────────────────────────────────────────*/
/*
  Trình tự 5 bước BẮT BUỘC (đề hay hỏi dạng "sắp xếp thứ tự"):

  1) Bật PolyBase
     EXEC sp_configure 'polybase enabled', 1; RECONFIGURE;

  2) Master key + credential (xác thực tới nguồn ngoài)
     CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Str0ng!Pass';
     CREATE DATABASE SCOPED CREDENTIAL AzureCred
       WITH IDENTITY = 'SHARED ACCESS SIGNATURE', SECRET = 'sv=...';

  3) External DATA SOURCE (nơi chứa dữ liệu)
     CREATE EXTERNAL DATA SOURCE LakeDS
       WITH (LOCATION = 'abs://container@account.blob.core.windows.net',
             CREDENTIAL = AzureCred);

  4) External FILE FORMAT (chỉ cho CSV/DELIMITEDTEXT; Parquet/Delta không cần)
     CREATE EXTERNAL FILE FORMAT CsvFmt
       WITH (FORMAT_TYPE = DELIMITEDTEXT,
             FORMAT_OPTIONS (FIELD_TERMINATOR = ',', FIRST_ROW = 2));

  5) External TABLE
     CREATE EXTERNAL TABLE dbo.ExtSales (OrderId INT, Amount DECIMAL(19,4))
       WITH (LOCATION = '/sales/2026/', DATA_SOURCE = LakeDS, FILE_FORMAT = CsvFmt);

  Cách nhanh hơn nếu chỉ đọc một lần (không cần external table):
     SELECT * FROM OPENROWSET(BULK 'https://acct.blob.core.windows.net/c/f.parquet',
                              FORMAT = 'PARQUET') AS r;

  KIẾN THỨC THI:
    - SQL 2022 hỗ trợ nguồn: Azure Blob/ADLS Gen2, S3-compatible, Oracle, Teradata,
      MongoDB, ODBC generic; định dạng CSV, PARQUET, DELTA.
    - External table CHỈ ĐỌC (trừ CETAS — CREATE EXTERNAL TABLE AS SELECT — để GHI ra).
    - Không có thống kê tự động ⇒ nên CREATE STATISTICS thủ công.
    - Mục đích: truy vấn dữ liệu TẠI CHỖ, không phải nạp (ELT) vào SQL Server.
    → Đề thi: "truy vấn file Parquet trên data lake mà không sao chép dữ liệu"
      = EXTERNAL TABLE / OPENROWSET.                                            */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 6 — VECTOR & AI | SQL Server 2025 / Azure SQL (preview)
───────────────────────────────────────────────────────────────────────────────*/
/*
  -- Kiểu dữ liệu VECTOR(n): n = số chiều embedding (vd 1536 cho text-embedding-3-small)
  CREATE TABLE dbo.DocChunk
  (
      ChunkId   INT IDENTITY PRIMARY KEY,
      DocId     INT           NOT NULL,
      Content   NVARCHAR(MAX) NOT NULL,
      Embedding VECTOR(1536)  NOT NULL
  );

  -- Sinh embedding NGAY TRONG SQL (external model)
  CREATE EXTERNAL MODEL MyEmbedder
  WITH (LOCATION = 'https://<res>.openai.azure.com/openai/deployments/emb/embeddings',
        API_FORMAT = 'Azure OpenAI', MODEL_TYPE = EMBEDDINGS, MODEL = 'text-embedding-3-small',
        CREDENTIAL = [https://<res>.openai.azure.com]);

  INSERT dbo.DocChunk (DocId, Content, Embedding)
  SELECT 1, @txt, AI_GENERATE_EMBEDDINGS(@txt USE MODEL MyEmbedder);

  -- Tìm kiếm ngữ nghĩa (exact KNN)
  DECLARE @q VECTOR(1536) = AI_GENERATE_EMBEDDINGS(N'chính sách hoàn tiền' USE MODEL MyEmbedder);
  SELECT TOP (5) ChunkId, Content,
         VECTOR_DISTANCE('cosine', Embedding, @q) AS Distance
  FROM   dbo.DocChunk
  ORDER  BY Distance;      -- càng NHỎ càng giống (cosine distance = 1 - cosine similarity)

  -- Vector index (DiskANN) + ANN search cho bảng lớn
  CREATE VECTOR INDEX VI_DocChunk ON dbo.DocChunk(Embedding)
  WITH (METRIC = 'cosine', TYPE = 'diskann');

  SELECT t.ChunkId, s.distance
  FROM   VECTOR_SEARCH(TABLE = dbo.DocChunk AS t, COLUMN = Embedding,
                       SIMILAR_TO = @q, METRIC = 'cosine', TOP_N = 5) AS s;

  ĐIỂM THI:
    - Metric: 'cosine' (phổ biến cho text), 'euclidean' (L2), 'dot' (inner product).
    - Cột VECTOR không làm key của index B-Tree thông thường; phải dùng VECTOR INDEX.
    - Số chiều tối đa 1998 với vector index DiskANN.
    - VECTOR_DISTANCE = tìm chính xác (quét toàn bảng, đúng 100%);
      VECTOR_SEARCH   = xấp xỉ ANN (nhanh, đánh đổi recall) ⇒ chọn khi bảng lớn.
    - Kiến trúc RAG trong SQL: chunk văn bản → embedding → lưu VECTOR →
      truy vấn lân cận → nạp vào prompt.                                        */


GO

/*═══════════════════ PHẦN B — JSON ═══════════════════════════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 7 — LƯU TRỮ & KIỂM TRA JSON
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS dbo.ProductJson;
CREATE TABLE dbo.ProductJson
(
    ProductId  INT IDENTITY PRIMARY KEY,
    Name       NVARCHAR(100) NOT NULL,
    -- SQL 2016–2022: lưu bằng NVARCHAR(MAX) + CHECK ISJSON
    Attributes NVARCHAR(MAX) NULL
        CONSTRAINT CK_Product_Attributes_IsJson CHECK (ISJSON(Attributes) = 1)
);
GO
/*  SQL SERVER 2025 có KIỂU JSON gốc (lưu dạng binary đã parse):
      Attributes JSON NULL      -- nhanh hơn, không cần CHECK ISJSON, có JSON index
    ISJSON(expr, JSON_SCHEMA)   -- 2025: kiểm tra theo schema                    */

INSERT dbo.ProductJson (Name, Attributes) VALUES
(N'Laptop', N'{"brand":"Dell","specs":{"ram":16,"cpu":"i7"},"tags":["office","light"],"price":1200.50}'),
(N'Phone',  N'{"brand":"Apple","specs":{"ram":8,"cpu":"A17"},"tags":["5g","camera"],"price":999.00}'),
(N'Mouse',  N'{"brand":"Logitech","specs":{"dpi":8000},"tags":["wireless"],"price":45.99}');

-- [LỖI CỐ Ý] JSON sai cú pháp bị CHECK chặn
BEGIN TRY
    INSERT dbo.ProductJson (Name, Attributes) VALUES (N'Bad', N'{not json}');
END TRY
BEGIN CATCH
    SELECT 'CHECK ISJSON chặn' AS Demo, ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS Msg;
END CATCH;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 8 — BỘ HÀM JSON: VALUE / QUERY / MODIFY / PATH
───────────────────────────────────────────────────────────────────────────────*/
SELECT  Name,
        JSON_VALUE(Attributes, '$.brand')            AS Brand,      -- trả SCALAR
        JSON_VALUE(Attributes, '$.specs.ram')        AS RamGB,
        JSON_VALUE(Attributes, '$.tags[0]')          AS FirstTag,
        JSON_QUERY(Attributes, '$.specs')            AS SpecsObj,   -- trả OBJECT/ARRAY
        JSON_QUERY(Attributes, '$.tags')             AS TagsArr
FROM    dbo.ProductJson;

-- JSON_PATH_EXISTS chỉ có từ SQL Server 2022 (v16) ⇒ chạy có điều kiện
IF CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) >= 16
    EXEC(N'SELECT Name, JSON_PATH_EXISTS(Attributes, ''$.specs.dpi'') AS HasDpi
           FROM dbo.ProductJson;');
ELSE
    PRINT 'SQL Server < 2022: bỏ qua JSON_PATH_EXISTS (tương đương: JSON_VALUE(...) IS NOT NULL).';
GO
/*  ⚠ BẪY KINH ĐIỂN:
      JSON_VALUE trả về scalar — gọi trên object/array ⇒ trả NULL (lax mode)
                                 hoặc BÁO LỖI nếu dùng 'strict $.specs'.
      JSON_QUERY trả về object/array — gọi trên scalar ⇒ NULL.
      lax  (mặc định): đường dẫn sai ⇒ NULL.
      strict          : đường dẫn sai ⇒ Msg 13608/13609 (dùng khi cần phát hiện lỗi).
      JSON_VALUE mặc định trả NVARCHAR(4000) ⇒ luôn CAST khi so sánh/tính toán,
      nếu không sẽ so sánh chuỗi ('9' > '1200') và không dùng được index đúng cách.*/

-- lax vs strict
SELECT JSON_VALUE(Attributes, 'lax $.khong_ton_tai') AS Lax_TraNull FROM dbo.ProductJson WHERE ProductId = 1;
BEGIN TRY
    SELECT JSON_VALUE(Attributes, 'strict $.khong_ton_tai') FROM dbo.ProductJson WHERE ProductId = 1;
END TRY
BEGIN CATCH SELECT 'strict báo lỗi' AS Demo, ERROR_MESSAGE() AS Msg; END CATCH;

-- JSON_MODIFY: cập nhật, thêm, xóa thuộc tính
UPDATE dbo.ProductJson
SET    Attributes = JSON_MODIFY(Attributes, '$.specs.ram', 32)               -- sửa
WHERE  Name = N'Laptop';

UPDATE dbo.ProductJson
SET    Attributes = JSON_MODIFY(Attributes, '$.warranty', '24 months')       -- thêm mới
WHERE  Name = N'Laptop';

UPDATE dbo.ProductJson
SET    Attributes = JSON_MODIFY(Attributes, 'append $.tags', 'gaming')       -- nối vào mảng
WHERE  Name = N'Laptop';

UPDATE dbo.ProductJson
SET    Attributes = JSON_MODIFY(Attributes, '$.warranty', NULL)              -- XÓA thuộc tính
WHERE  Name = N'Laptop';
/*  ⚠ JSON_MODIFY(..., NULL) trong lax mode = XÓA key. Muốn GÁN giá trị null thật:
      JSON_MODIFY(@j, 'strict $.warranty', NULL)                               */

SELECT Name, Attributes FROM dbo.ProductJson WHERE Name = N'Laptop';


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 9 — OPENJSON: JSON → BẢNG (shredding)
───────────────────────────────────────────────────────────────────────────────*/
-- (a) Không WITH ⇒ trả key / value / type
SELECT * FROM OPENJSON((SELECT Attributes FROM dbo.ProductJson WHERE Name = N'Phone'));
/*  cột type: 0=null 1=string 2=int 3=true/false 4=array 5=object                */

-- (b) Có WITH ⇒ định nghĩa schema, đây là dạng dùng thực tế
SELECT  p.Name, j.Brand, j.Ram, j.Price, j.Tags
FROM    dbo.ProductJson p
CROSS APPLY OPENJSON(p.Attributes)
WITH (
        Brand NVARCHAR(50)  '$.brand',
        Ram   INT           '$.specs.ram',
        Price DECIMAL(19,2) '$.price',
        Tags  NVARCHAR(MAX) '$.tags' AS JSON      -- AS JSON để lấy nguyên mảng/object
     ) AS j;
/*  ⚠ 'AS JSON' BẮT BUỘC khi cột đích là object/array, và kiểu phải là NVARCHAR(MAX).
      Thiếu ⇒ Msg 13618.                                                        */

-- (c) Bung mảng thành nhiều dòng (normalize)
SELECT  p.Name, t.[value] AS Tag
FROM    dbo.ProductJson p
CROSS APPLY OPENJSON(p.Attributes, '$.tags') t;

-- (d) Nạp dữ liệu từ chuỗi JSON của ứng dụng vào bảng quan hệ (ETL rất hay dùng)
DECLARE @payload NVARCHAR(MAX) = N'
[
  {"id":101,"customer":"An","lines":[{"sku":"A1","qty":2},{"sku":"B2","qty":1}]},
  {"id":102,"customer":"Bình","lines":[{"sku":"C3","qty":5}]}
]';

SELECT  o.id, o.customer, l.sku, l.qty
FROM    OPENJSON(@payload)
        WITH (id INT '$.id', customer NVARCHAR(50) '$.customer',
              lines NVARCHAR(MAX) '$.lines' AS JSON) AS o
CROSS APPLY OPENJSON(o.lines)
        WITH (sku NVARCHAR(20) '$.sku', qty INT '$.qty') AS l;


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 10 — FOR JSON: BẢNG → JSON
───────────────────────────────────────────────────────────────────────────────*/
SELECT TOP (2) ProductId AS 'id', Name AS 'product.name'
FROM   dbo.ProductJson
FOR JSON PATH;                                   -- dấu chấm trong alias ⇒ lồng nhau

SELECT TOP (2) ProductId, Name FROM dbo.ProductJson
FOR JSON AUTO, ROOT('products'), INCLUDE_NULL_VALUES;

SELECT TOP (1) ProductId, Name FROM dbo.ProductJson
FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;            -- trả 1 object thay vì mảng

-- Lồng cấp bằng subquery + JSON_QUERY
SELECT  p.ProductId, p.Name,
        JSON_QUERY(p.Attributes) AS attributes   -- không có JSON_QUERY sẽ bị escape thành chuỗi!
FROM    dbo.ProductJson p
FOR JSON PATH, ROOT('data');
/*  ⚠ BẪY: nhúng một cột đã chứa JSON mà quên JSON_QUERY ⇒ dấu " bị escape (\")
      và kết quả thành chuỗi, không phải object.
    PATH = tự kiểm soát cấu trúc bằng alias | AUTO = tự lồng theo thứ tự JOIN.   */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 11 — ĐÁNH CHỈ MỤC CHO JSON
───────────────────────────────────────────────────────────────────────────────*/
-- Không có index: mọi truy vấn JSON đều SCAN
SET STATISTICS IO ON;
SELECT ProductId FROM dbo.ProductJson WHERE JSON_VALUE(Attributes,'$.brand') = 'Dell';
SET STATISTICS IO OFF;

-- GIẢI PHÁP CHUẨN (SQL 2016–2022): computed column + index
ALTER TABLE dbo.ProductJson
    ADD Brand AS CAST(JSON_VALUE(Attributes,'$.brand') AS NVARCHAR(50));  -- không cần PERSISTED
GO
CREATE INDEX IX_ProductJson_Brand ON dbo.ProductJson(Brand);
GO

SET STATISTICS IO ON;
SELECT ProductId FROM dbo.ProductJson WHERE Brand = N'Dell';                      -- seek
SELECT ProductId FROM dbo.ProductJson WHERE JSON_VALUE(Attributes,'$.brand') = N'Dell';
-- ↑ Optimizer TỰ KHỚP biểu thức với computed column ⇒ vẫn seek, không cần sửa app!
SET STATISTICS IO OFF;
/*  ⚠ Muốn optimizer khớp được: biểu thức trong computed column phải GIỐNG HỆT
      biểu thức trong truy vấn (kể cả CAST và đường dẫn).
    ⚠ Nếu cần lọc theo phần tử MẢNG ⇒ computed column không giải quyết được,
      phải normalize sang bảng phụ (OPENJSON) hoặc dùng full-text/JSON index.

    SQL SERVER 2025 — JSON INDEX (đánh index cho TOÀN BỘ tài liệu):
      CREATE JSON INDEX JI_Product ON dbo.ProductJson (Attributes)
          FOR ('$.brand', '$.specs.ram');
      ⇒ hỗ trợ cả JSON_VALUE, JSON_PATH_EXISTS và lọc trên mảng.

    KHI NÀO DÙNG JSON THAY VÌ CỘT QUAN HỆ?
      ✅ Thuộc tính THƯA/thay đổi liên tục theo từng loại sản phẩm (EAV thay thế).
      ✅ Payload nguyên vẹn từ API cần lưu nguyên trạng.
      ✅ Dữ liệu bán cấu trúc ít khi lọc/JOIN theo.
      ❌ Thuộc tính CỐT LÕI, lọc/JOIN/tổng hợp thường xuyên ⇒ dùng cột thật.
      ❌ Cần ràng buộc toàn vẹn (FK, UNIQUE) trên thuộc tính đó.                */


/*═══════════════════════════════════════════════════════════════════════════════
  CHECKLIST SAU LAB 03
  □ Phân biệt Temporal vs Ledger vs CDC/Change Tracking trong 1 câu.
  □ Nhớ 5 mệnh đề FOR SYSTEM_TIME và khác biệt FROM..TO / BETWEEN / CONTAINED IN.
  □ Biết SCHEMA_ONLY vs SCHEMA_AND_DATA dùng cho tình huống nào.
  □ Giải thích BUCKET_COUNT và vì sao HASH index không quét dải được.
  □ Nói được 5 bước tạo external table đúng thứ tự.
  □ Phân biệt JSON_VALUE vs JSON_QUERY, lax vs strict.
  □ Biết vì sao phải có 'AS JSON' trong OPENJSON ... WITH.
  □ Nêu cách tăng tốc WHERE JSON_VALUE(...) trên SQL 2022 và trên SQL 2025.
═══════════════════════════════════════════════════════════════════════════════*/
