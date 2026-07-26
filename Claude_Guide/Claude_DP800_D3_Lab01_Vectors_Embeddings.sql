/*═══════════════════════════════════════════════════════════════════════════════
  DP-800 | MIỀN 3 | LAB 01 — EMBEDDINGS & VECTOR SEARCH
  Đi kèm: Claude_DP800_D3_AI_Guide.md  (mục 1, 2, 3)

  ⚠ KIỂU DỮ LIỆU `VECTOR` CẦN SQL SERVER 2025 / AZURE SQL.
    Lab này có HAI LỚP:
      • Khối [CÚ PHÁP 2025] — cú pháp gốc, có kiểm tra phiên bản; đọc & thuộc.
      • Khối [MÔ PHỎNG]     — cài đặt lại cosine/euclidean/dot bằng T-SQL thuần
                              trên JSON, CHẠY ĐƯỢC TỪ SQL SERVER 2016 TRỞ LÊN.
    Phần mô phỏng cho bạn cảm nhận ĐÚNG cách vector search hoạt động — thứ mà
    đề thi kiểm tra — mà không cần chờ có instance 2025.

  PHẦN A — Vector cơ bản & 3 metric        (S1..S5)
  PHẦN B — Vector index, ANN, hybrid search (S6..S9)
═══════════════════════════════════════════════════════════════════════════════*/

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
DECLARE @ver INT = CAST(SERVERPROPERTY('ProductMajorVersion') AS INT);
SELECT  @@VERSION AS ServerVersion, @ver AS MajorVer,
        CASE WHEN @ver >= 17 THEN 'CÓ hỗ trợ kiểu VECTOR (2025+)'
             ELSE 'KHÔNG hỗ trợ kiểu VECTOR — dùng phần MÔ PHỎNG bên dưới' END AS VectorSupport;
GO

IF DB_ID('DP800_AI') IS NOT NULL
BEGIN
    ALTER DATABASE DP800_AI SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DP800_AI;
END;
GO
CREATE DATABASE DP800_AI;
GO
USE DP800_AI;
GO


/*═══════════════════ PHẦN A — VECTOR CƠ BẢN ══════════════════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 1 — [CÚ PHÁP 2025] KIỂU VECTOR
───────────────────────────────────────────────────────────────────────────────*/
/*
    CREATE TABLE dbo.DocChunk
    (
        ChunkId   INT IDENTITY PRIMARY KEY,
        DocId     INT           NOT NULL,
        Content   NVARCHAR(MAX) NOT NULL,
        Embedding VECTOR(1536)  NOT NULL      -- n = SỐ CHIỀU, cố định theo model
    );

    -- Gán bằng chuỗi JSON mảng
    DECLARE @v VECTOR(3) = CAST('[0.5, -0.2, 0.8]' AS VECTOR(3));

    -- Chuyển ngược về JSON để xem
    SELECT CAST(@v AS NVARCHAR(MAX));

    ĐIỂM PHẢI NHỚ VỀ KIỂU VECTOR:
      • n phải KHỚP CHÍNH XÁC số chiều của model. Sai chiều ⇒ lỗi khi INSERT.
      • Tối đa 1998 chiều (giới hạn của vector index DiskANN).
      • Lưu dạng nhị phân float32 — gọn hơn nhiều so với NVARCHAR(MAX) chứa JSON.
      • KHÔNG so sánh bằng '='; KHÔNG GROUP BY / ORDER BY trực tiếp trên cột vector;
        KHÔNG làm khoá index B-Tree thường.
      • Trước 2025: lưu tạm bằng VARBINARY(8000) hoặc NVARCHAR(MAX) — cách cũ,
        hay xuất hiện làm đáp án nhiễu.

    SỐ CHIỀU THEO MODEL (nhớ vài mốc):
      text-embedding-ada-002    → 1536
      text-embedding-3-small    → 1536
      text-embedding-3-large    → 3072
      all-MiniLM-L6-v2 (ONNX)   →  384
    ⚠ ĐỔI MODEL = PHẢI SINH LẠI TOÀN BỘ EMBEDDING. Vector của model A không so
      sánh được với vector của model B — đây là câu hỏi tình huống hay gặp.       */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 2 — [MÔ PHỎNG] BẢNG CHUNK + EMBEDDING DẠNG JSON
───────────────────────────────────────────────────────────────────────────────*/
CREATE TABLE dbo.DocChunk
(
    ChunkId    INT IDENTITY PRIMARY KEY,
    DocId      INT           NOT NULL,
    Title      NVARCHAR(200) NOT NULL,
    Content    NVARCHAR(MAX) NOT NULL,
    -- Trên SQL 2025 dòng dưới sẽ là:  Embedding VECTOR(8) NOT NULL
    Embedding  NVARCHAR(MAX) NOT NULL
        CONSTRAINT CK_DocChunk_IsJson CHECK (ISJSON(Embedding) = 1),
    Dimensions AS (CAST(JSON_VALUE(Embedding, '$.dim') AS INT))   -- kiểm tra chiều
);
GO
/*  Dùng 8 chiều thay vì 1536 để BẠN NHÌN THẤY được con số và tự kiểm chứng phép
    tính. Nguyên lý hoàn toàn giống nhau — chỉ khác số chiều.

    Ý nghĩa 8 chiều (giả lập một model đã học các "khái niệm"):
      [0]=hoàn tiền/trả hàng  [1]=vận chuyển  [2]=bảo hành  [3]=thanh toán
      [4]=tài khoản           [5]=khuyến mãi  [6]=kỹ thuật  [7]=nhân sự          */

INSERT dbo.DocChunk (DocId, Title, Content, Embedding) VALUES
(1, N'Chính sách hoàn tiền',
    N'Khách hàng được hoàn tiền trong vòng 30 ngày kể từ ngày mua nếu sản phẩm còn nguyên vẹn.',
    N'[0.95, 0.10, 0.15, 0.30, 0.05, 0.00, 0.00, 0.00]'),
(1, N'Quy định trả hàng',
    N'Sản phẩm trả lại phải còn tem niêm phong. Phí trả hàng do người bán chịu.',
    N'[0.90, 0.25, 0.10, 0.15, 0.00, 0.00, 0.00, 0.00]'),
(2, N'Thời gian giao hàng',
    N'Đơn hàng nội thành giao trong 24 giờ, liên tỉnh từ 2 đến 5 ngày làm việc.',
    N'[0.05, 0.95, 0.00, 0.10, 0.00, 0.10, 0.00, 0.00]'),
(2, N'Phí vận chuyển',
    N'Miễn phí vận chuyển cho đơn hàng từ 500.000đ. Dưới mức này tính phí 30.000đ.',
    N'[0.10, 0.85, 0.00, 0.35, 0.00, 0.20, 0.00, 0.00]'),
(3, N'Bảo hành sản phẩm',
    N'Sản phẩm điện tử được bảo hành 12 tháng theo tiêu chuẩn nhà sản xuất.',
    N'[0.15, 0.05, 0.95, 0.00, 0.00, 0.00, 0.25, 0.00]'),
(4, N'Phương thức thanh toán',
    N'Chấp nhận thẻ tín dụng, chuyển khoản, ví điện tử và thanh toán khi nhận hàng (COD).',
    N'[0.10, 0.15, 0.00, 0.95, 0.20, 0.05, 0.00, 0.00]'),
(5, N'Khôi phục mật khẩu',
    N'Nhấn "Quên mật khẩu" tại trang đăng nhập, hệ thống gửi liên kết đặt lại qua email.',
    N'[0.00, 0.00, 0.05, 0.05, 0.95, 0.00, 0.40, 0.00]'),
(6, N'Chương trình khuyến mãi',
    N'Giảm 20% cho khách hàng thân thiết vào ngày đôi hằng tháng.',
    N'[0.05, 0.15, 0.00, 0.25, 0.10, 0.95, 0.00, 0.00]'),
(7, N'Chế độ nghỉ phép',
    N'Nhân viên chính thức được 12 ngày phép có lương mỗi năm.',
    N'[0.00, 0.00, 0.00, 0.00, 0.05, 0.00, 0.00, 0.95]'),
(8, N'Sự cố kỹ thuật thường gặp',
    N'Nếu ứng dụng không tải được, hãy xoá bộ nhớ đệm và cài đặt lại phiên bản mới nhất.',
    N'[0.00, 0.00, 0.30, 0.00, 0.20, 0.00, 0.95, 0.00]');
GO
SELECT ChunkId, Title, Embedding FROM dbo.DocChunk;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 3 — [MÔ PHỎNG] CÀI ĐẶT LẠI VECTOR_DISTANCE BẰNG T-SQL
───────────────────────────────────────────────────────────────────────────────*/
/*  CÔNG THỨC (thuộc lòng, đề có thể hỏi khái niệm):
      dot(a,b)       = Σ aᵢ·bᵢ
      norm(a)        = √(Σ aᵢ²)
      cosine_sim     = dot(a,b) / (norm(a)·norm(b))          ∈ [-1, 1]
      COSINE DISTANCE= 1 − cosine_sim                         ∈ [0, 2]
      EUCLIDEAN      = √(Σ (aᵢ−bᵢ)²)
      DOT (negative inner product) = −dot(a,b)                                    */

CREATE OR ALTER FUNCTION dbo.fnVectorDistance
(
    @metric VARCHAR(10),          -- 'cosine' | 'euclidean' | 'dot'
    @a      NVARCHAR(MAX),
    @b      NVARCHAR(MAX)
)
RETURNS FLOAT
AS
BEGIN
    DECLARE @dot FLOAT = 0, @na FLOAT = 0, @nb FLOAT = 0, @sq FLOAT = 0;

    SELECT  @dot = SUM(x.v * y.v),
            @na  = SUM(x.v * x.v),
            @nb  = SUM(y.v * y.v),
            @sq  = SUM((x.v - y.v) * (x.v - y.v))
    FROM   (SELECT [key] AS i, CAST([value] AS FLOAT) AS v FROM OPENJSON(@a)) x
    JOIN   (SELECT [key] AS i, CAST([value] AS FLOAT) AS v FROM OPENJSON(@b)) y
           ON y.i = x.i;

    RETURN CASE @metric
             WHEN 'cosine'    THEN 1.0 - (@dot / NULLIF(SQRT(@na) * SQRT(@nb), 0))
             WHEN 'euclidean' THEN SQRT(@sq)
             WHEN 'dot'       THEN -@dot
           END;
END;
GO

-- Kiểm chứng bằng ví dụ tính tay được
DECLARE @v1 NVARCHAR(100) = N'[1, 0, 0]';
DECLARE @v2 NVARCHAR(100) = N'[1, 0, 0]';    -- giống hệt
DECLARE @v3 NVARCHAR(100) = N'[0, 1, 0]';    -- trực giao (vuông góc)
DECLARE @v4 NVARCHAR(100) = N'[-1, 0, 0]';   -- ngược hẳn
DECLARE @v5 NVARCHAR(100) = N'[2, 0, 0]';    -- cùng hướng, dài gấp đôi

SELECT * FROM (VALUES
 (N'Giống hệt',              dbo.fnVectorDistance('cosine', @v1, @v2), dbo.fnVectorDistance('euclidean', @v1, @v2)),
 (N'Trực giao (không liên quan)', dbo.fnVectorDistance('cosine', @v1, @v3), dbo.fnVectorDistance('euclidean', @v1, @v3)),
 (N'Ngược hẳn',              dbo.fnVectorDistance('cosine', @v1, @v4), dbo.fnVectorDistance('euclidean', @v1, @v4)),
 (N'Cùng hướng, khác độ dài',dbo.fnVectorDistance('cosine', @v1, @v5), dbo.fnVectorDistance('euclidean', @v1, @v5))
) v(TruongHop, CosineDistance, EuclideanDistance);
GO
/*  🎯 ĐỌC KẾT QUẢ — ĐÂY LÀ TRỌNG TÂM CỦA MIỀN 3:

    COSINE DISTANCE:  0 = giống hệt | 1 = trực giao | 2 = ngược hẳn
      → "Cùng hướng, khác độ dài" cho cosine = 0 (GIỐNG NHAU HOÀN TOÀN)
        nhưng euclidean = 1 (KHÁC NHAU).
      → Đó chính là lý do văn bản dùng COSINE: độ dài vector phản ánh độ dài
        văn bản, không phản ánh ý nghĩa. Cosine bỏ qua độ lớn, chỉ xét HƯỚNG.

    BA ĐIỀU CỰC DỄ NHẦM TRONG ĐỀ:
      1. VECTOR_DISTANCE trả KHOẢNG CÁCH, không phải độ tương đồng
         ⇒ ORDER BY ... ASC + TOP, KHÔNG phải DESC.
      2. cosine distance = 1 − cosine similarity.
      3. Metric lúc TRUY VẤN phải KHỚP metric đã khai khi TẠO vector index.       */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 4 — TÌM KIẾM NGỮ NGHĨA (exact KNN)
───────────────────────────────────────────────────────────────────────────────*/
/*  [CÚ PHÁP 2025] — bản thật sẽ là:

      DECLARE @q VECTOR(1536) =
              AI_GENERATE_EMBEDDINGS(N'chính sách hoàn tiền' USE MODEL MyEmbedder);

      SELECT TOP (3) ChunkId, Title, Content,
             VECTOR_DISTANCE('cosine', Embedding, @q) AS Distance
      FROM   dbo.DocChunk
      ORDER  BY Distance;                    -- ⚠ ASC: nhỏ = giống                */

-- [MÔ PHỎNG] câu hỏi "tôi muốn trả lại hàng và lấy lại tiền"
-- (giả lập embedding của câu hỏi: đậm chiều [0]=hoàn tiền/trả hàng)
DECLARE @q NVARCHAR(MAX) = N'[0.92, 0.18, 0.08, 0.20, 0.00, 0.00, 0.00, 0.00]';

SELECT TOP (3)
       ChunkId, Title,
       LEFT(Content, 60) AS ContentPreview,
       CAST(dbo.fnVectorDistance('cosine', Embedding, @q) AS DECIMAL(8,5)) AS CosineDistance
FROM   dbo.DocChunk
ORDER  BY CosineDistance ASC;         -- exact KNN: quét toàn bảng, chính xác 100%
GO
/*  ⚠ QUAN SÁT: câu hỏi dùng chữ "trả lại hàng / lấy lại tiền" — KHÔNG chứa cụm
    "hoàn tiền" của tài liệu, nhưng vẫn tìm ra đúng vì hai vector gần nhau.
    ⇒ Đây chính là thứ FULL-TEXT SEARCH KHÔNG LÀM ĐƯỢC.                          */

-- Thử câu hỏi khác: "khi nào hàng tới nơi?"
DECLARE @q2 NVARCHAR(MAX) = N'[0.05, 0.93, 0.00, 0.08, 0.00, 0.05, 0.00, 0.00]';
SELECT TOP (3) ChunkId, Title,
       CAST(dbo.fnVectorDistance('cosine', Embedding, @q2) AS DECIMAL(8,5)) AS CosineDistance
FROM   dbo.DocChunk ORDER BY CosineDistance ASC;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 5 — SO SÁNH BA METRIC TRÊN CÙNG MỘT TRUY VẤN
───────────────────────────────────────────────────────────────────────────────*/
DECLARE @q NVARCHAR(MAX) = N'[0.92, 0.18, 0.08, 0.20, 0.00, 0.00, 0.00, 0.00]';

SELECT  ChunkId, Title,
        CAST(dbo.fnVectorDistance('cosine',    Embedding, @q) AS DECIMAL(8,5)) AS Cosine,
        CAST(dbo.fnVectorDistance('euclidean', Embedding, @q) AS DECIMAL(8,5)) AS Euclidean,
        CAST(dbo.fnVectorDistance('dot',       Embedding, @q) AS DECIMAL(8,5)) AS NegDot,
        RANK() OVER (ORDER BY dbo.fnVectorDistance('cosine',    Embedding, @q)) AS RankCosine,
        RANK() OVER (ORDER BY dbo.fnVectorDistance('euclidean', Embedding, @q)) AS RankEuclidean
FROM    dbo.DocChunk
ORDER BY Cosine;
GO
/*  BẢNG CHỌN METRIC (thuộc lòng):
    ┌─────────────┬────────────────────────────────┬────────────────────────────┐
    │ Metric      │ Ý nghĩa                        │ Dùng khi                   │
    ├─────────────┼────────────────────────────────┼────────────────────────────┤
    │ 'cosine'    │ Góc giữa 2 vector, bỏ độ dài   │ MẶC ĐỊNH cho VĂN BẢN       │
    │ 'euclidean' │ Khoảng cách L2 (đường thẳng)   │ Khi độ lớn có ý nghĩa      │
    │ 'dot'       │ Tích vô hướng (âm)             │ Model đã chuẩn hoá; nhanh  │
    └─────────────┴────────────────────────────────┴────────────────────────────┘
    Với vector đã CHUẨN HOÁ (norm = 1), cosine và euclidean cho cùng THỨ HẠNG
    ⇒ khi đó chọn 'dot' vì rẻ nhất (không cần khai căn).                         */


/*═══════════════════ PHẦN B — VECTOR INDEX & HYBRID ══════════════════════════*/

/*───────────────────────────────────────────────────────────────────────────────
  SECTION 6 — [CÚ PHÁP 2025] VECTOR INDEX & VECTOR_SEARCH
───────────────────────────────────────────────────────────────────────────────*/
/*
    CREATE VECTOR INDEX VI_DocChunk ON dbo.DocChunk(Embedding)
    WITH (METRIC = 'cosine', TYPE = 'diskann');

    SELECT t.ChunkId, t.Title, s.distance
    FROM   VECTOR_SEARCH(
               TABLE      = dbo.DocChunk AS t,
               COLUMN     = Embedding,
               SIMILAR_TO = @q,
               METRIC     = 'cosine',
               TOP_N      = 10
           ) AS s
    ORDER BY s.distance;

 ┌────────────────┬───────────────────────────┬──────────────────────────────────┐
 │                │ VECTOR_DISTANCE           │ VECTOR_SEARCH + vector index     │
 ├────────────────┼───────────────────────────┼──────────────────────────────────┤
 │ Thuật toán     │ Exact KNN (quét toàn bảng)│ ANN xấp xỉ (DiskANN)             │
 │ Độ chính xác   │ 100%                      │ ~95–99% (recall)                 │
 │ Tốc độ         │ Chậm tuyến tính theo dòng │ Nhanh, gần như không đổi         │
 │ Dùng khi       │ Bảng nhỏ, cần tuyệt đối   │ Bảng lớn, chấp nhận sai số nhỏ   │
 └────────────────┴───────────────────────────┴──────────────────────────────────┘

 ĐIỀU KIỆN & LƯU Ý CỦA VECTOR INDEX (hay ra đề):
   • Bảng phải có clustered index / primary key.
   • METRIC lúc tạo index PHẢI TRÙNG metric lúc truy vấn, nếu không index bị bỏ qua.
   • Index xây offline trên ảnh chụp dữ liệu ⇒ dòng thêm sau CHƯA nằm trong index
     ⇒ phải REBUILD định kỳ để giữ recall.
   • Không hỗ trợ trên bảng memory-optimized, external table.
   • Số chiều tối đa 1998.
   • Xem: sys.vector_indexes

 🎯 CÂU HỎI TỦ: "Bảng 50 triệu chunk, cần top-5 trong vài chục ms"
    ⇒ VECTOR INDEX + VECTOR_SEARCH (KHÔNG phải VECTOR_DISTANCE).                 */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 7 — PRE-FILTER BẰNG METADATA (kỹ thuật quan trọng)
───────────────────────────────────────────────────────────────────────────────*/
ALTER TABLE dbo.DocChunk ADD Department NVARCHAR(50) NULL, PublishedOn DATE NULL;
GO
UPDATE dbo.DocChunk SET Department = N'CSKH',   PublishedOn = '2026-01-15' WHERE DocId IN (1,2,4,6);
UPDATE dbo.DocChunk SET Department = N'KyThuat',PublishedOn = '2026-03-20' WHERE DocId IN (3,8);
UPDATE dbo.DocChunk SET Department = N'NhanSu', PublishedOn = '2025-11-01' WHERE DocId = 7;
UPDATE dbo.DocChunk SET Department = N'CSKH',   PublishedOn = '2026-05-05' WHERE Department IS NULL;
GO
CREATE INDEX IX_DocChunk_Dept ON dbo.DocChunk(Department, PublishedOn);
GO

DECLARE @q NVARCHAR(MAX) = N'[0.92, 0.18, 0.08, 0.20, 0.00, 0.00, 0.00, 0.00]';

-- Lọc metadata TRƯỚC rồi mới tính khoảng cách trên tập nhỏ
SELECT TOP (3) ChunkId, Title, Department,
       CAST(dbo.fnVectorDistance('cosine', Embedding, @q) AS DECIMAL(8,5)) AS Distance
FROM   dbo.DocChunk
WHERE  Department = N'CSKH'                      -- pre-filter
  AND  PublishedOn >= '2026-01-01'
ORDER BY Distance;
GO
/*  🎯 HAI CHIẾN LƯỢC LỌC — đề hay hỏi phân biệt:
      PRE-FILTER  : lọc metadata trước, tìm vector sau.
                    ✅ Đảm bảo đủ K kết quả thoả điều kiện.
                    ⚠ Với vector index, pre-filter có thể làm giảm hiệu quả ANN.
      POST-FILTER : tìm top-K vector trước rồi lọc.
                    ✅ Tận dụng tối đa vector index.
                    ⚠ Có thể còn ÍT HƠN K kết quả sau khi lọc (thậm chí 0).
    Thực hành tốt: lấy top-N lớn hơn nhu cầu (vd 50) rồi lọc và cắt còn 5.

    LIÊN MIỀN 2: "người dùng chỉ được tìm trong tài liệu họ có quyền xem"
      ⇒ ROW-LEVEL SECURITY trên bảng chunk (không lọc ở tầng ứng dụng!).         */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 8 — VECTOR vs FULL-TEXT vs HYBRID
───────────────────────────────────────────────────────────────────────────────*/
-- Thêm dữ liệu có MÃ CHÍNH XÁC — điểm yếu của vector search
INSERT dbo.DocChunk (DocId, Title, Content, Embedding, Department, PublishedOn) VALUES
(9, N'Thông số kỹ thuật SKU-A17X',
    N'Model SKU-A17X: pin 5000mAh, màn hình 6.7 inch, chip A17 Pro.',
    N'[0.00, 0.00, 0.20, 0.00, 0.00, 0.00, 0.90, 0.00]', N'KyThuat', '2026-04-01');
GO

DECLARE @q NVARCHAR(MAX) = N'[0.00, 0.00, 0.25, 0.00, 0.00, 0.00, 0.92, 0.00]';
DECLARE @keyword NVARCHAR(100) = N'SKU-A17X';

-- (a) Chỉ vector: tìm theo ý nghĩa
WITH VectorHits AS (
    SELECT TOP (5) ChunkId, Title,
           dbo.fnVectorDistance('cosine', Embedding, @q) AS Distance,
           ROW_NUMBER() OVER (ORDER BY dbo.fnVectorDistance('cosine', Embedding, @q)) AS VecRank
    FROM   dbo.DocChunk ORDER BY Distance
),
-- (b) Chỉ từ khoá: LIKE thay cho CONTAINS (full-text có thể chưa cài trên instance)
KeywordHits AS (
    SELECT TOP (5) ChunkId, Title,
           ROW_NUMBER() OVER (ORDER BY ChunkId) AS KwRank
    FROM   dbo.DocChunk
    WHERE  Content LIKE '%' + @keyword + '%' OR Title LIKE '%' + @keyword + '%'
)
-- (c) HYBRID: hợp nhất thứ hạng bằng Reciprocal Rank Fusion (RRF)
SELECT  COALESCE(v.ChunkId, k.ChunkId)      AS ChunkId,
        COALESCE(v.Title,   k.Title)        AS Title,
        v.VecRank, k.KwRank,
        CAST(ISNULL(1.0/(60 + v.VecRank), 0) + ISNULL(1.0/(60 + k.KwRank), 0)
             AS DECIMAL(10,6))              AS RrfScore
FROM        VectorHits  v
FULL JOIN   KeywordHits k ON k.ChunkId = v.ChunkId
ORDER BY RrfScore DESC;
GO
/*  RECIPROCAL RANK FUSION:  score = Σ 1/(k + rank)   với k thường = 60.
    Ưu điểm: chỉ cần THỨ HẠNG, không cần chuẩn hoá điểm số giữa hai hệ thống
    có thang đo khác nhau ⇒ đây là cách hợp nhất chuẩn trong hybrid search.

 ┌──────────────────────────────┬─────────────┬──────────────┬──────────┐
 │ Nhu cầu                      │ Full-text   │ Vector       │ Hybrid   │
 ├──────────────────────────────┼─────────────┼──────────────┼──────────┤
 │ "trả hàng" tìm ra "hoàn tiền"│ ❌          │ ✅           │ ✅       │
 │ Tìm mã chính xác "SKU-A17X"  │ ✅          │ ⚠ kém        │ ✅       │
 │ Chi phí                      │ Thấp        │ Cao (gọi API)│ Cao nhất │
 │ Cần sinh embedding           │ Không       │ Có           │ Có       │
 └──────────────────────────────┴─────────────┴──────────────┴──────────┘

 🎯 Đề mô tả "người dùng vừa hỏi bằng ngôn ngữ tự nhiên, vừa tra mã sản phẩm
    chính xác" ⇒ HYBRID SEARCH. Đây là đáp án hay bị bỏ sót.

 CÚ PHÁP FULL-TEXT THẬT (nếu instance đã cài Full-Text Search):
   CREATE FULLTEXT CATALOG ftCat AS DEFAULT;
   CREATE FULLTEXT INDEX ON dbo.DocChunk(Content) KEY INDEX PK__DocChunk__...;
   SELECT * FROM dbo.DocChunk WHERE CONTAINS(Content, '"SKU-A17X"');
   SELECT * FROM FREETEXTTABLE(dbo.DocChunk, Content, N'hoàn tiền') ft;  -- có cột RANK  */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 9 — PREDICT: CHẠY MODEL ONNX NGAY TRONG ENGINE
───────────────────────────────────────────────────────────────────────────────*/
/*
    -- Lưu model ONNX đã huấn luyện vào bảng
    CREATE TABLE dbo.MlModel
    (
        ModelId   INT IDENTITY PRIMARY KEY,
        ModelName NVARCHAR(100) NOT NULL,
        ModelBlob VARBINARY(MAX) NOT NULL       -- nội dung file .onnx
    );

    INSERT dbo.MlModel (ModelName, ModelBlob)
    SELECT 'ChurnPredictor',
           BulkColumn FROM OPENROWSET(BULK 'C:\models\churn.onnx', SINGLE_BLOB) AS m;

    -- Suy luận HÀNG LOẠT, ngay trong engine, KHÔNG gọi ra mạng
    DECLARE @model VARBINARY(MAX) =
            (SELECT ModelBlob FROM dbo.MlModel WHERE ModelName = 'ChurnPredictor');

    SELECT c.CustomerId, p.Score AS ChurnProbability
    FROM   PREDICT(MODEL = @model, DATA = dbo.CustomerFeatures AS c) WITH (Score FLOAT) AS p;

 🎯 PHÂN BIỆT (câu hỏi rất hay ra):
    PREDICT / ONNX          → chạy TRONG engine, độ trễ thấp, không phụ thuộc mạng,
                              hợp cho SCORING HÀNG LOẠT (dự đoán rời bỏ, phân loại,
                              chấm điểm rủi ro).
    External model / REST   → gọi RA dịch vụ ngoài, dùng cho LLM & EMBEDDING.
    ML Services (sp_execute_external_script) → chạy Python/R trong SQL Server
                              on-prem; KHÔNG có trên Azure SQL Database.

    HAI CÂU HỎI PHÂN LOẠI TOÀN BỘ MIỀN 3:
      1. "Chạy TRONG engine hay gọi RA ngoài?"
      2. "Chính xác (exact) hay xấp xỉ (approximate)?"                            */


/*───────────────────────────────────────────────────────────────────────────────
  DỌN DẸP
───────────────────────────────────────────────────────────────────────────────*/
-- USE master;
-- ALTER DATABASE DP800_AI SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
-- DROP DATABASE DP800_AI;

/*═══════════════════════════════════════════════════════════════════════════════
  CHECKLIST SAU LAB 01
  □ Giải thích embedding bằng 1 câu và nêu điều full-text KHÔNG làm được.
  □ Viết đúng khai báo VECTOR(n) và biết n đến từ đâu.
  □ Nhớ: đổi model ⇒ phải sinh lại toàn bộ embedding.
  □ Viết công thức cosine distance và biết dải giá trị 0..2.
  □ Nói ngay vì sao văn bản dùng cosine chứ không dùng euclidean.
  □ Nhớ ORDER BY distance ASC (không phải DESC).
  □ Phân biệt VECTOR_DISTANCE (exact) và VECTOR_SEARCH + index (ANN).
  □ Kể 3 điều kiện/lưu ý của vector index, đặc biệt việc METRIC phải khớp.
  □ Phân biệt pre-filter và post-filter, nêu rủi ro của từng cách.
  □ Giải thích hybrid search và công thức RRF.
  □ Phân biệt PREDICT (ONNX) với external model.
═══════════════════════════════════════════════════════════════════════════════*/
