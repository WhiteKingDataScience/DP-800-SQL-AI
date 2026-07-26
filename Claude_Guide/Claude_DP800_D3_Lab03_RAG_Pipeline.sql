/*═══════════════════════════════════════════════════════════════════════════════
  DP-800 | MIỀN 3 | LAB 03 — RAG END-TO-END TRONG SQL
  Đi kèm: Claude_DP800_D3_AI_Guide.md  (mục 5)

  Lab này dựng TRỌN VẸN một pipeline RAG chạy được thật, dùng embedding mô phỏng
  (từ vựng có kiểm soát) để bạn KIỂM CHỨNG ĐƯỢC từng bước bằng mắt. Mọi chỗ khác
  biệt so với SQL Server 2025 đều được ghi rõ trong khối [CÚ PHÁP 2025].

  PHA 1 — NẠP:    S1 thu thập → S2 chunking → S3 embedding → S4 lưu trữ → S5 index
  PHA 2 — TRUY VẤN: S6 embed câu hỏi → S7 retrieve → S8 hybrid+rerank
                    → S9 lắp prompt → S10 gọi LLM → S11 trả lời + trích dẫn
  S12 — Đánh giá chất lượng & vận hành
═══════════════════════════════════════════════════════════════════════════════*/

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
IF DB_ID('DP800_RAG') IS NOT NULL
BEGIN
    ALTER DATABASE DP800_RAG SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DP800_RAG;
END;
GO
CREATE DATABASE DP800_RAG;
GO
USE DP800_RAG;
GO

/*  SƠ ĐỒ TỔNG THỂ — VẼ LẠI ĐƯỢC LÀ TRẢ LỜI ĐƯỢC ĐA SỐ CÂU HỎI MIỀN 3

    PHA 1 — NẠP (offline, một lần / định kỳ)
      Tài liệu → [2] CHUNKING → [3] EMBEDDING → [4] LƯU VECTOR + metadata → [5] VECTOR INDEX

    PHA 2 — TRUY VẤN (online, mỗi câu hỏi)
      Câu hỏi → [6] EMBED (CÙNG MODEL!) → [7] RETRIEVE top-K → [8] HYBRID/RERANK
              → [9] LẮP PROMPT → [10] LLM → [11] TRẢ LỜI + TRÍCH DẪN

    ⚠ HAI LỖI HAY BỊ HỎI:
       • Embedding TRƯỚC chunking  → SAI. Phải chunk trước.
       • Embed câu hỏi bằng model KHÁC model đã embed tài liệu → kết quả vô nghĩa.  */


/*═══════════════════ PHA 1 — NẠP DỮ LIỆU ═════════════════════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 1 — THU THẬP TÀI LIỆU NGUỒN
───────────────────────────────────────────────────────────────────────────────*/
CREATE TABLE dbo.Document
(
    DocId       INT IDENTITY PRIMARY KEY,
    Title       NVARCHAR(200) NOT NULL,
    Department  NVARCHAR(50)  NOT NULL,
    SourceUrl   NVARCHAR(400) NULL,
    Content     NVARCHAR(MAX) NOT NULL,
    ContentHash AS (HASHBYTES('SHA2_256', Content)) PERSISTED,   -- phát hiện thay đổi
    UpdatedAt   DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
INSERT dbo.Document (Title, Department, SourceUrl, Content) VALUES
(N'Chính sách hoàn tiền', N'CSKH', N'https://kb.congty.vn/hoan-tien',
 N'Khách hàng có quyền yêu cầu hoàn tiền trong vòng 30 ngày kể từ ngày nhận hàng. '
+N'Sản phẩm phải còn nguyên tem niêm phong và đầy đủ phụ kiện đi kèm. '
+N'Chi phí vận chuyển trả hàng do người bán chịu nếu lỗi thuộc về nhà sản xuất. '
+N'Tiền được hoàn về tài khoản gốc trong 5 đến 7 ngày làm việc kể từ khi nhận được hàng trả.'),

(N'Quy định giao hàng', N'CSKH', N'https://kb.congty.vn/giao-hang',
 N'Đơn hàng nội thành được giao trong vòng 24 giờ kể từ khi xác nhận. '
+N'Đơn hàng liên tỉnh mất từ 2 đến 5 ngày làm việc tuỳ khu vực. '
+N'Miễn phí vận chuyển cho đơn hàng có giá trị từ 500.000 đồng trở lên. '
+N'Đơn hàng dưới mức này chịu phí vận chuyển cố định 30.000 đồng.'),

(N'Chế độ bảo hành', N'KyThuat', N'https://kb.congty.vn/bao-hanh',
 N'Sản phẩm điện tử được bảo hành 12 tháng theo tiêu chuẩn nhà sản xuất. '
+N'Bảo hành không áp dụng cho hư hỏng do rơi vỡ, vào nước hoặc tự ý sửa chữa. '
+N'Khách hàng cần xuất trình hoá đơn mua hàng hoặc mã đơn hàng khi yêu cầu bảo hành. '
+N'Thời gian xử lý bảo hành trung bình từ 7 đến 14 ngày làm việc.'),

(N'Hướng dẫn tài khoản', N'KyThuat', N'https://kb.congty.vn/tai-khoan',
 N'Để khôi phục mật khẩu, nhấn vào liên kết Quên mật khẩu tại trang đăng nhập. '
+N'Hệ thống sẽ gửi một liên kết đặt lại mật khẩu tới địa chỉ email đã đăng ký. '
+N'Liên kết có hiệu lực trong 15 phút. Nếu không nhận được email, hãy kiểm tra hộp thư rác.'),

(N'Chính sách nhân sự', N'NhanSu', N'https://kb.congty.vn/nhan-su',
 N'Nhân viên chính thức được hưởng 12 ngày phép có lương mỗi năm. '
+N'Ngày phép chưa dùng được chuyển sang quý một của năm kế tiếp. '
+N'Đơn xin nghỉ phép phải được gửi trước ít nhất 3 ngày làm việc.');
GO
SELECT DocId, Title, Department, LEN(Content) AS ContentLen FROM dbo.Document;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 2 — CHUNKING
───────────────────────────────────────────────────────────────────────────────*/
/*  [CÚ PHÁP 2025]
      INSERT dbo.Chunk (DocId, ChunkOrdinal, Content)
      SELECT d.DocId, c.chunk_ordinal, c.chunk
      FROM   dbo.Document d
      CROSS APPLY AI_GENERATE_CHUNKS(source = d.Content,
                  chunk_type = N'FIXED', chunk_size = 400, overlap = 50) AS c;    */

-- [MÔ PHỎNG] cắt theo CÂU rồi gộp lại cho tới ngưỡng — chất lượng cao hơn fixed-size
-- vì không bao giờ cắt giữa câu (semantic-aware chunking).
CREATE OR ALTER FUNCTION dbo.fnChunkBySentence
(
    @Text        NVARCHAR(MAX),
    @MaxChars    INT,
    @OverlapSent INT           -- số CÂU chồng lấn giữa 2 chunk liên tiếp
)
RETURNS @r TABLE (ChunkOrdinal INT, Chunk NVARCHAR(MAX), SentenceCount INT)
AS
BEGIN
    -- Tách câu theo dấu chấm
    DECLARE @s TABLE (Seq INT IDENTITY PRIMARY KEY, Sentence NVARCHAR(MAX));
    DECLARE @rest NVARCHAR(MAX) = @Text, @p INT;

    WHILE LEN(@rest) > 0
    BEGIN
        SET @p = CHARINDEX('.', @rest);
        IF @p = 0
        BEGIN
            INSERT @s (Sentence) VALUES (LTRIM(RTRIM(@rest)));
            BREAK;
        END;
        INSERT @s (Sentence) VALUES (LTRIM(RTRIM(LEFT(@rest, @p))));
        SET @rest = LTRIM(SUBSTRING(@rest, @p + 1, LEN(@rest)));
    END;
    DELETE @s WHERE LEN(Sentence) = 0;

    -- Gộp câu thành chunk cho tới khi chạm @MaxChars
    DECLARE @ord INT = 1, @start INT = 1, @cur INT, @buf NVARCHAR(MAX), @cnt INT,
            @maxSeq INT = (SELECT ISNULL(MAX(Seq), 0) FROM @s);

    WHILE @start <= @maxSeq
    BEGIN
        SET @buf = N''; SET @cnt = 0; SET @cur = @start;

        WHILE @cur <= @maxSeq
        BEGIN
            DECLARE @sent NVARCHAR(MAX) = (SELECT Sentence FROM @s WHERE Seq = @cur);
            IF LEN(@buf) > 0 AND LEN(@buf) + LEN(@sent) + 1 > @MaxChars BREAK;
            SET @buf = CASE WHEN LEN(@buf) = 0 THEN @sent ELSE @buf + N' ' + @sent END;
            SET @cnt += 1;
            SET @cur += 1;
        END;

        INSERT @r (ChunkOrdinal, Chunk, SentenceCount) VALUES (@ord, @buf, @cnt);
        SET @ord += 1;

        -- Lùi lại @OverlapSent câu để tạo vùng chồng lấn
        DECLARE @next INT = @cur - @OverlapSent;
        SET @start = CASE WHEN @next <= @start THEN @start + 1 ELSE @next END;
    END;
    RETURN;
END;
GO

CREATE TABLE dbo.Chunk
(
    ChunkId      INT IDENTITY PRIMARY KEY,
    DocId        INT           NOT NULL REFERENCES dbo.Document(DocId),
    ChunkOrdinal INT           NOT NULL,
    Content      NVARCHAR(MAX) NOT NULL,
    -- Trên SQL 2025:  Embedding VECTOR(8) NULL
    Embedding    NVARCHAR(MAX) NULL,
    EmbeddedAt   DATETIME2(3)  NULL,
    CONSTRAINT UQ_Chunk UNIQUE (DocId, ChunkOrdinal)
);
CREATE INDEX IX_Chunk_DocId ON dbo.Chunk(DocId);
GO

INSERT dbo.Chunk (DocId, ChunkOrdinal, Content)
SELECT d.DocId, c.ChunkOrdinal, c.Chunk
FROM   dbo.Document d
CROSS APPLY dbo.fnChunkBySentence(d.Content, 200, 1) c;
GO

SELECT  c.ChunkId, d.Title, c.ChunkOrdinal, LEN(c.Content) AS Len, c.Content
FROM    dbo.Chunk c JOIN dbo.Document d ON d.DocId = c.DocId
ORDER BY c.DocId, c.ChunkOrdinal;
GO
/*  ⚠ QUAN SÁT VÙNG CHỒNG LẤN: câu cuối của chunk N xuất hiện lại ở đầu chunk N+1.
    Đó chính là tác dụng của overlap — nếu câu trả lời nằm vắt qua ranh giới,
    ít nhất một chunk vẫn chứa trọn ý.

    NHẮC LẠI KHUYẾN NGHỊ (hay ra đề):
      Kích thước 200–800 token (~400–1500 ký tự) | Chồng lấn 10–20%
      Cắt theo ranh giới câu/đoạn | Luôn lưu metadata để trích dẫn             */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 3 — SINH EMBEDDING
───────────────────────────────────────────────────────────────────────────────*/
/*  [CÚ PHÁP 2025]
      UPDATE c
      SET    c.Embedding  = AI_GENERATE_EMBEDDINGS(c.Content USE MODEL MyEmbedder),
             c.EmbeddedAt = SYSUTCDATETIME()
      FROM   dbo.Chunk c
      WHERE  c.Embedding IS NULL;          -- chỉ embed cái CHƯA có                */

-- [MÔ PHỎNG] "model" 8 chiều dựa trên từ vựng có kiểm soát.
-- KHÔNG phải embedding thật, nhưng cho ra vector CÓ Ý NGHĨA để kiểm chứng pipeline.
CREATE OR ALTER FUNCTION dbo.fnMockEmbedding (@Text NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @t NVARCHAR(MAX) = LOWER(@Text);
    DECLARE @d0 FLOAT = 0, @d1 FLOAT = 0, @d2 FLOAT = 0, @d3 FLOAT = 0,
            @d4 FLOAT = 0, @d5 FLOAT = 0, @d6 FLOAT = 0, @d7 FLOAT = 0;

    -- [0] hoàn tiền / trả hàng
    IF @t LIKE N'%hoàn tiền%' SET @d0 += 1;
    IF @t LIKE N'%trả hàng%'  SET @d0 += 1;
    IF @t LIKE N'%hoàn về%'   SET @d0 += 1;
    IF @t LIKE N'%niêm phong%' SET @d0 += 0.5;
    -- [1] vận chuyển / giao hàng
    IF @t LIKE N'%giao%'         SET @d1 += 1;
    IF @t LIKE N'%vận chuyển%'   SET @d1 += 1;
    IF @t LIKE N'%đơn hàng%'     SET @d1 += 0.4;
    IF @t LIKE N'%ngày làm việc%' SET @d1 += 0.3;
    -- [2] bảo hành
    IF @t LIKE N'%bảo hành%'     SET @d2 += 1.5;
    IF @t LIKE N'%hư hỏng%'      SET @d2 += 0.6;
    IF @t LIKE N'%sửa chữa%'     SET @d2 += 0.6;
    -- [3] thanh toán / chi phí
    IF @t LIKE N'%phí%'          SET @d3 += 0.8;
    IF @t LIKE N'%đồng%'         SET @d3 += 0.5;
    IF @t LIKE N'%tài khoản gốc%' SET @d3 += 0.5;
    IF @t LIKE N'%hoá đơn%'      SET @d3 += 0.5;
    -- [4] tài khoản / đăng nhập
    IF @t LIKE N'%mật khẩu%'     SET @d4 += 1.5;
    IF @t LIKE N'%đăng nhập%'    SET @d4 += 1;
    IF @t LIKE N'%email%'        SET @d4 += 0.6;
    -- [5] thời hạn
    IF @t LIKE N'%ngày%'         SET @d5 += 0.4;
    IF @t LIKE N'%giờ%'          SET @d5 += 0.4;
    IF @t LIKE N'%phút%'         SET @d5 += 0.4;
    IF @t LIKE N'%tháng%'        SET @d5 += 0.4;
    -- [6] kỹ thuật / sản phẩm
    IF @t LIKE N'%điện tử%'      SET @d6 += 0.8;
    IF @t LIKE N'%sản phẩm%'     SET @d6 += 0.5;
    IF @t LIKE N'%hệ thống%'     SET @d6 += 0.5;
    -- [7] nhân sự
    IF @t LIKE N'%nhân viên%'    SET @d7 += 1.2;
    IF @t LIKE N'%phép%'         SET @d7 += 1.2;
    IF @t LIKE N'%nghỉ%'         SET @d7 += 0.8;

    -- Chuẩn hoá về vector đơn vị (norm = 1) — đúng như model embedding thật làm
    DECLARE @n FLOAT = SQRT(@d0*@d0 + @d1*@d1 + @d2*@d2 + @d3*@d3
                          + @d4*@d4 + @d5*@d5 + @d6*@d6 + @d7*@d7);
    IF @n = 0 SET @n = 1;

    RETURN N'[' + CONCAT(
        FORMAT(@d0/@n,'0.0000'), ',', FORMAT(@d1/@n,'0.0000'), ',',
        FORMAT(@d2/@n,'0.0000'), ',', FORMAT(@d3/@n,'0.0000'), ',',
        FORMAT(@d4/@n,'0.0000'), ',', FORMAT(@d5/@n,'0.0000'), ',',
        FORMAT(@d6/@n,'0.0000'), ',', FORMAT(@d7/@n,'0.0000')) + N']';
END;
GO

UPDATE dbo.Chunk
SET    Embedding  = dbo.fnMockEmbedding(Content),
       EmbeddedAt = SYSUTCDATETIME()
WHERE  Embedding IS NULL;                     -- ⚠ chỉ embed cái CHƯA có
GO
SELECT ChunkId, LEFT(Content, 45) AS Preview, Embedding FROM dbo.Chunk ORDER BY ChunkId;
GO
/*  ⚠ Vì embedding đã CHUẨN HOÁ (norm = 1), cosine và euclidean cho cùng THỨ HẠNG.
    Model embedding thật cũng thường trả vector đã chuẩn hoá — đó là lý do
    metric 'dot' đôi khi được chọn: rẻ nhất mà xếp hạng vẫn đúng.                */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 4 — HÀM KHOẢNG CÁCH + SECTION 5 — "INDEX"
───────────────────────────────────────────────────────────────────────────────*/
CREATE OR ALTER FUNCTION dbo.fnCosineDistance (@a NVARCHAR(MAX), @b NVARCHAR(MAX))
RETURNS FLOAT
AS
BEGIN
    DECLARE @dot FLOAT, @na FLOAT, @nb FLOAT;
    SELECT @dot = SUM(x.v*y.v), @na = SUM(x.v*x.v), @nb = SUM(y.v*y.v)
    FROM   (SELECT [key] i, CAST([value] AS FLOAT) v FROM OPENJSON(@a)) x
    JOIN   (SELECT [key] i, CAST([value] AS FLOAT) v FROM OPENJSON(@b)) y ON y.i = x.i;
    RETURN 1.0 - (@dot / NULLIF(SQRT(@na)*SQRT(@nb), 0));
END;
GO
/*  [CÚ PHÁP 2025] — bước 5 của pha nạp:
      CREATE VECTOR INDEX VI_Chunk ON dbo.Chunk(Embedding)
      WITH (METRIC = 'cosine', TYPE = 'diskann');

    ⚠ Index xây offline trên ảnh chụp dữ liệu ⇒ chunk thêm sau CHƯA nằm trong index.
      Phải REBUILD định kỳ để giữ recall. Đây là điểm vận hành hay ra đề.        */


/*═══════════════════ PHA 2 — TRUY VẤN ════════════════════════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 6+7 — EMBED CÂU HỎI & TRUY XUẤT TOP-K
───────────────────────────────────────────────────────────────────────────────*/
DECLARE @question NVARCHAR(400) = N'Tôi muốn trả hàng và lấy lại tiền thì mất bao lâu?';
DECLARE @qEmbedding NVARCHAR(MAX) = dbo.fnMockEmbedding(@question);   -- ⚠ CÙNG MODEL!

SELECT @question AS Question, @qEmbedding AS QuestionEmbedding;

SELECT TOP (3)
       c.ChunkId, d.Title, d.SourceUrl,
       CAST(dbo.fnCosineDistance(c.Embedding, @qEmbedding) AS DECIMAL(8,5)) AS Distance,
       c.Content
FROM   dbo.Chunk c
JOIN   dbo.Document d ON d.DocId = c.DocId
ORDER BY Distance ASC;                    -- ⚠ ASC: nhỏ = giống
GO
/*  [CÚ PHÁP 2025] bước này là:
      DECLARE @q VECTOR(1536) = AI_GENERATE_EMBEDDINGS(@question USE MODEL MyEmbedder);
      SELECT t.ChunkId, s.distance
      FROM   VECTOR_SEARCH(TABLE = dbo.Chunk AS t, COLUMN = Embedding,
                           SIMILAR_TO = @q, METRIC = 'cosine', TOP_N = 3) AS s;

    🎯 ĐIỂM MẤU CHỐT: câu hỏi dùng chữ "trả hàng / lấy lại tiền", tài liệu dùng
      "hoàn tiền". Không trùng từ khoá nhưng vẫn tìm đúng — đó là sức mạnh của
      tìm kiếm ngữ nghĩa, và là lý do RAG dùng vector thay vì LIKE/full-text.    */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 8 — HYBRID SEARCH + PRE-FILTER
───────────────────────────────────────────────────────────────────────────────*/
DECLARE @question NVARCHAR(400) = N'Bảo hành sản phẩm điện tử bao lâu?';
DECLARE @qEmb NVARCHAR(MAX) = dbo.fnMockEmbedding(@question);
DECLARE @keyword NVARCHAR(100) = N'bảo hành';
DECLARE @dept NVARCHAR(50) = NULL;        -- đặt N'KyThuat' để thấy tác dụng pre-filter

WITH VectorHits AS (
    SELECT TOP (5) c.ChunkId, d.Title, c.Content, d.SourceUrl,
           dbo.fnCosineDistance(c.Embedding, @qEmb) AS Distance,
           ROW_NUMBER() OVER (ORDER BY dbo.fnCosineDistance(c.Embedding, @qEmb)) AS VecRank
    FROM   dbo.Chunk c JOIN dbo.Document d ON d.DocId = c.DocId
    WHERE  (@dept IS NULL OR d.Department = @dept)          -- PRE-FILTER metadata
    ORDER BY Distance
),
KeywordHits AS (
    SELECT TOP (5) c.ChunkId, d.Title, c.Content, d.SourceUrl,
           ROW_NUMBER() OVER (ORDER BY LEN(c.Content)) AS KwRank
    FROM   dbo.Chunk c JOIN dbo.Document d ON d.DocId = c.DocId
    WHERE  c.Content LIKE N'%' + @keyword + N'%'
      AND  (@dept IS NULL OR d.Department = @dept)
)
SELECT  COALESCE(v.ChunkId, k.ChunkId)  AS ChunkId,
        COALESCE(v.Title,   k.Title)    AS Title,
        v.VecRank, k.KwRank,
        CAST(ISNULL(1.0/(60 + v.VecRank), 0) + ISNULL(1.0/(60 + k.KwRank), 0)
             AS DECIMAL(10,6))          AS RrfScore,
        LEFT(COALESCE(v.Content, k.Content), 70) AS Preview
FROM        VectorHits  v
FULL JOIN   KeywordHits k ON k.ChunkId = v.ChunkId
ORDER BY RrfScore DESC;
GO
/*  RECIPROCAL RANK FUSION: score = Σ 1/(k + rank), k thường = 60.
    Chỉ cần THỨ HẠNG nên không phải chuẩn hoá điểm giữa hai hệ thống khác thang đo.

    KHI NÀO DÙNG GÌ:
      Vector    — hỏi bằng ngôn ngữ tự nhiên, cần hiểu ý
      Full-text — tra mã sản phẩm, tên riêng, thuật ngữ chính xác
      HYBRID    — 🎯 khi có CẢ HAI nhu cầu (đáp án hay bị bỏ sót)               */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 9 — LẮP PROMPT (grounding)
───────────────────────────────────────────────────────────────────────────────*/
CREATE OR ALTER FUNCTION dbo.fnBuildRagPrompt (@Question NVARCHAR(400), @TopK INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @qEmb NVARCHAR(MAX) = dbo.fnMockEmbedding(@Question);
    DECLARE @context NVARCHAR(MAX) = N'';

    SELECT @context = @context
         + N'[Nguồn ' + CAST(ROW_NUMBER() OVER (ORDER BY t.Distance) AS NVARCHAR(3)) + N'] '
         + t.Title + N' (' + ISNULL(t.SourceUrl, N'n/a') + N')' + CHAR(13) + CHAR(10)
         + t.Content + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
    FROM (
        SELECT TOP (@TopK) d.Title, d.SourceUrl, c.Content,
               dbo.fnCosineDistance(c.Embedding, @qEmb) AS Distance
        FROM   dbo.Chunk c JOIN dbo.Document d ON d.DocId = c.DocId
        ORDER BY Distance
    ) t;

    RETURN
      N'Bạn là trợ lý hỗ trợ khách hàng. Hãy trả lời CHỈ dựa trên NGỮ CẢNH bên dưới.' + CHAR(13)+CHAR(10)
    + N'Nếu ngữ cảnh không chứa thông tin cần thiết, hãy trả lời chính xác: '
    + N'"Tôi không tìm thấy thông tin này trong tài liệu."' + CHAR(13)+CHAR(10)
    + N'Luôn trích dẫn số nguồn theo dạng [Nguồn n]. Không được suy đoán.' + CHAR(13)+CHAR(10)
    + N'---------- NGỮ CẢNH ----------' + CHAR(13)+CHAR(10)
    + @context
    + N'---------- CÂU HỎI ----------' + CHAR(13)+CHAR(10)
    + @Question;
END;
GO

PRINT dbo.fnBuildRagPrompt(N'Tôi muốn trả hàng và lấy lại tiền thì mất bao lâu?', 3);
GO
/*  🎯 BỐN THÀNH PHẦN BẮT BUỘC CỦA PROMPT RAG (đề hay hỏi "làm sao giảm bịa đặt"):
      1. VAI TRÒ         — "Bạn là trợ lý hỗ trợ khách hàng"
      2. RÀNG BUỘC       — "CHỈ dựa trên ngữ cảnh", "không suy đoán"
      3. LỐI THOÁT       — câu trả lời chuẩn khi không có thông tin
                           ⇒ đây là thứ giảm hallucination hiệu quả nhất
      4. YÊU CẦU TRÍCH DẪN — buộc mô hình chỉ ra nguồn ⇒ người dùng kiểm chứng được */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 10 — GỌI LLM SINH CÂU TRẢ LỜI
───────────────────────────────────────────────────────────────────────────────*/
/*  [CÚ PHÁP 2025 — cách gọn nhất]
      DECLARE @prompt NVARCHAR(MAX) = dbo.fnBuildRagPrompt(@question, 3);
      SELECT AI_GENERATE_CHAT(@prompt USE MODEL MyChatModel) AS Answer;

    [CÁCH TỔNG QUÁT — chạy trên Azure SQL / SQL Server 2025]
      DECLARE @payload NVARCHAR(MAX) =
          (SELECT N'You are a helpful assistant.' AS [messages[0].content],
                  N'system'                        AS [messages[0].role],
                  @prompt                          AS [messages[1].content],
                  N'user'                          AS [messages[1].role],
                  0.0                              AS temperature,   -- ⚠ 0 = ổn định nhất
                  800                              AS max_tokens
           FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

      DECLARE @resp NVARCHAR(MAX), @ret INT;
      EXEC @ret = sys.sp_invoke_external_rest_endpoint
           @url        = N'https://myres.openai.azure.com/openai/deployments/gpt4o/chat/completions?api-version=2024-02-01',
           @method     = N'POST',
           @payload    = @payload,
           @timeout    = 60,
           @credential = [https://myres.openai.azure.com],
           @response   = @resp OUTPUT;

      SELECT JSON_VALUE(@resp, '$.result.choices[0].message.content') AS Answer,
             JSON_VALUE(@resp, '$.result.usage.total_tokens')         AS TokensUsed;

    ⚠ temperature = 0 cho câu trả lời ổn định, ít bịa — đúng nhu cầu của RAG.
    ⚠ Nhớ giới hạn max_tokens để kiểm soát chi phí.                              */

-- Minh hoạ cách bóc câu trả lời từ phản hồi (mô phỏng)
DECLARE @mockLlmResponse NVARCHAR(MAX) = N'
{
  "response": { "status": { "http": { "code": 200 } } },
  "result": {
    "choices": [ { "message": { "role": "assistant",
        "content": "Bạn có thể yêu cầu hoàn tiền trong vòng 30 ngày kể từ ngày nhận hàng. Sau khi công ty nhận được hàng trả, tiền sẽ được hoàn về tài khoản gốc trong 5 đến 7 ngày làm việc. [Nguồn 1]" } } ],
    "usage": { "prompt_tokens": 412, "completion_tokens": 58, "total_tokens": 470 }
  }
}';
SELECT  JSON_VALUE(@mockLlmResponse, '$.result.choices[0].message.content') AS Answer,
        JSON_VALUE(@mockLlmResponse, '$.result.usage.total_tokens')         AS TotalTokens;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 11 — GHI LOG HỘI THOẠI & TRÍCH DẪN
───────────────────────────────────────────────────────────────────────────────*/
CREATE TABLE dbo.RagConversation
(
    ConversationId INT IDENTITY PRIMARY KEY,
    AskedAt        DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    AskedBy        SYSNAME       NOT NULL DEFAULT SUSER_SNAME(),
    Question       NVARCHAR(400) NOT NULL,
    Answer         NVARCHAR(MAX) NULL,
    TokensUsed     INT           NULL,
    LatencyMs      INT           NULL,
    UserRating     TINYINT       NULL          -- phản hồi 1..5 để đánh giá chất lượng
);
CREATE TABLE dbo.RagCitation
(
    CitationId     INT IDENTITY PRIMARY KEY,
    ConversationId INT NOT NULL REFERENCES dbo.RagConversation(ConversationId),
    ChunkId        INT NOT NULL REFERENCES dbo.Chunk(ChunkId),
    Rank           INT NOT NULL,
    Distance       DECIMAL(8,5) NOT NULL
);
GO

DECLARE @question NVARCHAR(400) = N'Tôi muốn trả hàng và lấy lại tiền thì mất bao lâu?';
DECLARE @qEmb NVARCHAR(MAX) = dbo.fnMockEmbedding(@question);
DECLARE @convId INT;

INSERT dbo.RagConversation (Question, Answer, TokensUsed, LatencyMs)
VALUES (@question,
        N'Bạn có thể yêu cầu hoàn tiền trong vòng 30 ngày kể từ ngày nhận hàng. '
      + N'Tiền được hoàn về tài khoản gốc trong 5 đến 7 ngày làm việc. [Nguồn 1]',
        470, 1240);
SET @convId = SCOPE_IDENTITY();

INSERT dbo.RagCitation (ConversationId, ChunkId, Rank, Distance)
SELECT @convId, t.ChunkId, t.Rnk, t.Distance
FROM (
    SELECT TOP (3) c.ChunkId,
           ROW_NUMBER() OVER (ORDER BY dbo.fnCosineDistance(c.Embedding, @qEmb)) AS Rnk,
           CAST(dbo.fnCosineDistance(c.Embedding, @qEmb) AS DECIMAL(8,5)) AS Distance
    FROM   dbo.Chunk c ORDER BY Distance
) t;

-- Kết quả cuối cùng trả về cho người dùng: câu trả lời + nguồn kiểm chứng được
SELECT  cv.Question, cv.Answer, cv.TokensUsed, cv.LatencyMs,
        ct.Rank, d.Title AS SourceTitle, d.SourceUrl, ct.Distance
FROM    dbo.RagConversation cv
JOIN    dbo.RagCitation ct ON ct.ConversationId = cv.ConversationId
JOIN    dbo.Chunk c        ON c.ChunkId = ct.ChunkId
JOIN    dbo.Document d     ON d.DocId = c.DocId
WHERE   cv.ConversationId = @convId
ORDER BY ct.Rank;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 12 — ĐÁNH GIÁ CHẤT LƯỢNG & VẬN HÀNH
───────────────────────────────────────────────────────────────────────────────*/
-- Bộ câu hỏi vàng để đo chất lượng truy xuất (retrieval evaluation)
CREATE TABLE dbo.RagGoldenSet
(
    TestId          INT IDENTITY PRIMARY KEY,
    Question        NVARCHAR(400) NOT NULL,
    ExpectedDocId   INT           NOT NULL REFERENCES dbo.Document(DocId)
);
INSERT dbo.RagGoldenSet (Question, ExpectedDocId) VALUES
(N'Tôi muốn trả hàng và lấy lại tiền',        1),
(N'Bao lâu thì hàng tới nơi?',                2),
(N'Điện thoại của tôi được bảo hành mấy tháng?', 3),
(N'Tôi quên mật khẩu đăng nhập',              4),
(N'Một năm được nghỉ phép bao nhiêu ngày?',   5);
GO

-- Đo Recall@3: tài liệu đúng có nằm trong top-3 không?
/*  ⚠ KHÔNG gộp (aggregate) một biểu thức vừa chứa cột của bảng NGOÀI vừa chứa cột
    của APPLY — SQL Server báo Msg 8124. Cách đúng: lấy top-K ra trước (không gộp),
    rồi so khớp ở tầng ngoài.                                                    */
WITH TopK AS
(
    SELECT  g.TestId, g.Question, g.ExpectedDocId, t.DocId, t.Rnk
    FROM    dbo.RagGoldenSet g
    CROSS APPLY (
        SELECT TOP (3) c.DocId,
               ROW_NUMBER() OVER (
                   ORDER BY dbo.fnCosineDistance(c.Embedding, dbo.fnMockEmbedding(g.Question))) AS Rnk
        FROM   dbo.Chunk c
        ORDER BY dbo.fnCosineDistance(c.Embedding, dbo.fnMockEmbedding(g.Question))
    ) t
),
Scored AS
(
    SELECT  TestId, Question, ExpectedDocId,
            STRING_AGG(CAST(DocId AS NVARCHAR(5)), ',') WITHIN GROUP (ORDER BY Rnk) AS TopDocIds,
            MAX(CASE WHEN DocId = ExpectedDocId THEN 1 ELSE 0 END) AS Hit,
            MIN(CASE WHEN DocId = ExpectedDocId THEN Rnk END)      AS HitRank
    FROM    TopK
    GROUP BY TestId, Question, ExpectedDocId
)
SELECT  TestId, Question, ExpectedDocId, TopDocIds, HitRank,
        CASE WHEN Hit = 1 THEN N'TRUNG' ELSE N'TRUOT' END AS [Recall@3]
FROM    Scored ORDER BY TestId;
GO

-- Tổng hợp Recall@3 và MRR (Mean Reciprocal Rank) trên toàn bộ bộ câu hỏi vàng
WITH TopK AS
(
    SELECT  g.TestId, g.ExpectedDocId, t.DocId, t.Rnk
    FROM    dbo.RagGoldenSet g
    CROSS APPLY (
        SELECT TOP (3) c.DocId,
               ROW_NUMBER() OVER (
                   ORDER BY dbo.fnCosineDistance(c.Embedding, dbo.fnMockEmbedding(g.Question))) AS Rnk
        FROM   dbo.Chunk c
        ORDER BY dbo.fnCosineDistance(c.Embedding, dbo.fnMockEmbedding(g.Question))
    ) t
),
Scored AS
(
    SELECT  TestId,
            MAX(CASE WHEN DocId = ExpectedDocId THEN 1 ELSE 0 END) AS Hit,
            MIN(CASE WHEN DocId = ExpectedDocId THEN Rnk END)      AS HitRank
    FROM    TopK GROUP BY TestId
)
SELECT  COUNT(*)                                              AS TotalQuestions,
        SUM(Hit)                                              AS Hits,
        CAST(100.0 * SUM(Hit) / COUNT(*) AS DECIMAL(5,2))     AS [Recall@3_Percent],
        CAST(AVG(ISNULL(1.0 / HitRank, 0)) AS DECIMAL(6,4))   AS MRR
FROM    Scored;
GO
/*  📌 ĐỌC KẾT QUẢ THẬT CỦA LAB NÀY: Recall@3 = 80% (4/5 câu trúng).
      Câu TRƯỢT là TestId 2: "Bao lâu thì hàng tới nơi?" — nó trả về tài liệu
      "Chính sách hoàn tiền" thay vì "Quy định giao hàng".

      VÌ SAO? Câu hỏi dùng chữ "hàng tới nơi", trong khi "model" mô phỏng ở
      Section 3 chỉ nhận diện các từ "giao", "vận chuyển". Không khớp từ khoá nào
      ⇒ vector câu hỏi gần như rỗng ⇒ xếp hạng ngẫu nhiên.

      ĐÂY CHÍNH LÀ ĐIỂM KHÁC BIỆT giữa embedding MÔ PHỎNG và embedding THẬT:
      model thật học từ hàng tỷ câu nên biết "hàng tới nơi" ≈ "giao hàng",
      còn model từ-khoá của chúng ta thì không.

      🎯 NHƯNG BÀI HỌC CHẨN ĐOÁN THÌ HOÀN TOÀN THẬT và hay ra đề:
         Recall thấp ⇒ vấn đề nằm ở TRUY XUẤT, không phải ở LLM.
         Sửa theo thứ tự: (1) kiểm tra model embedding có phù hợp ngôn ngữ/miền
         không → (2) chỉnh chunking → (3) tăng top-K → (4) thêm hybrid search
         → (5) thêm reranking.
      Thử ngay: sửa câu hỏi TestId 2 thành "Đơn hàng được giao trong bao lâu?"
      rồi chạy lại — Recall@3 sẽ lên 100%.                                       */

/*  🎯 CÁC CHỈ SỐ ĐÁNH GIÁ RAG (biết tên là đủ cho đề thi):
      Recall@K      — tài liệu đúng có nằm trong top-K không? (đo TRUY XUẤT)
      Precision@K   — bao nhiêu trong top-K là liên quan?
      MRR           — Mean Reciprocal Rank: tài liệu đúng đứng thứ mấy
      Groundedness  — câu trả lời có thực sự dựa trên ngữ cảnh không? (đo SINH)
      Answer relevance — câu trả lời có đúng ý câu hỏi không?

    KHI CHẤT LƯỢNG KÉM, SỬA THEO THỨ TỰ:
      1. Recall thấp  ⇒ vấn đề ở TRUY XUẤT: chỉnh chunking, tăng top-K,
                        thêm hybrid search, thêm reranking
      2. Recall tốt nhưng câu trả lời sai ⇒ vấn đề ở SINH: siết prompt,
                        giảm temperature, buộc trích dẫn

    VẬN HÀNH:
      • Chỉ re-embed chunk có ContentHash thay đổi (tiết kiệm chi phí lớn nhất).
      • Rebuild vector index định kỳ để giữ recall.
      • Theo dõi TokensUsed và LatencyMs để kiểm soát chi phí và trải nghiệm.
      • Thu thập UserRating để phát hiện suy giảm chất lượng theo thời gian.
      • RLS trên bảng Chunk để phân quyền tài liệu (Miền 2).                     */


/*───────────────────────────────────────────────────────────────────────────────
  DỌN DẸP
───────────────────────────────────────────────────────────────────────────────*/
-- USE master;
-- ALTER DATABASE DP800_RAG SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
-- DROP DATABASE DP800_RAG;

/*═══════════════════════════════════════════════════════════════════════════════
  CHECKLIST SAU LAB 03
  □ Vẽ lại 11 bước của pipeline RAG theo đúng thứ tự, không nhìn tài liệu.
  □ Nhớ: CHUNKING trước EMBEDDING (không phải ngược lại).
  □ Nhớ: câu hỏi phải embed bằng ĐÚNG model đã embed tài liệu.
  □ Nêu khuyến nghị kích thước chunk và tỷ lệ overlap, giải thích vì sao cần overlap.
  □ Kể 4 thành phần bắt buộc của prompt RAG và cái nào giảm hallucination nhiều nhất.
  □ Biết temperature = 0 dùng cho tình huống nào.
  □ Giải thích RRF và khi nào cần hybrid search.
  □ Phân biệt pre-filter và post-filter.
  □ Kể 5 chỉ số đánh giá RAG và biết chỉ số nào đo truy xuất, chỉ số nào đo sinh.
  □ Recall thấp thì sửa ở đâu? Recall tốt mà trả lời sai thì sửa ở đâu?
  □ Nêu cách giảm chi phí embedding khi tài liệu ít thay đổi.
═══════════════════════════════════════════════════════════════════════════════*/
