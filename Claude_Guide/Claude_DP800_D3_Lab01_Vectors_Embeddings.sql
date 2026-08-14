/*===============================================================================
  DP-800 | DOMAIN 3 | LAB 01 — VECTOR, EXACT SEARCH, ANN, HYBRID

  Cập nhật: 14/08/2026
  Mục tiêu:
    1) VECTOR data type
    2) VECTOR_DISTANCE exact search
    3) VECTORPROPERTY / VECTOR_NORM / VECTOR_NORMALIZE
    4) DiskANN vector index
    5) Latest VECTOR_SEARCH syntax: SELECT TOP(N) WITH APPROXIMATE
    6) Earlier TOP_N path theo platform/index version
    7) Full-Text + Vector + RRF concept

  Nguồn:
  https://learn.microsoft.com/en-us/sql/sql-server/ai/vectors?view=sql-server-ver17
  https://learn.microsoft.com/en-us/sql/t-sql/functions/vector-search-transact-sql?view=sql-server-ver17
  https://learn.microsoft.com/en-us/sql/t-sql/statements/create-vector-index-transact-sql?view=sql-server-ver17
===============================================================================*/

SET NOCOUNT ON;
GO

DROP TABLE IF EXISTS dbo.DP800_VectorDemo;
GO

CREATE TABLE dbo.DP800_VectorDemo
(
    Id        int NOT NULL
        CONSTRAINT PK_DP800_VectorDemo PRIMARY KEY CLUSTERED,
    Title     nvarchar(200) NOT NULL,
    Embedding vector(3) NOT NULL
);
GO

INSERT dbo.DP800_VectorDemo(Id, Title, Embedding)
VALUES
(1, N'Azure SQL security',      '[1.0, 0.0, 0.0]'),
(2, N'Data API builder',        '[0.9, 0.1, 0.0]'),
(3, N'Vector search',           '[0.0, 1.0, 0.0]'),
(4, N'RAG pipeline',            '[0.0, 0.8, 0.2]'),
(5, N'Unrelated topic',         '[0.0, 0.0, 1.0]');
GO

DECLARE @q vector(3) = '[1.0, 0.05, 0.0]';

SELECT
    Id,
    Title,
    VECTORPROPERTY(Embedding, 'Dimensions') AS Dimensions,
    VECTORPROPERTY(Embedding, 'BaseType') AS BaseType
FROM dbo.DP800_VectorDemo;
GO

/* Exact KNN: distance nhỏ hơn = gần hơn */
DECLARE @q vector(3) = '[1.0, 0.05, 0.0]';

SELECT TOP (3)
    Id,
    Title,
    VECTOR_DISTANCE('cosine', Embedding, @q) AS CosineDistance
FROM dbo.DP800_VectorDemo
ORDER BY CosineDistance ASC;
GO

DECLARE @v vector(3) = '[3.0, 4.0, 0.0]';

SELECT
    VECTOR_NORM(@v, 'norm2') AS L2Norm,
    VECTOR_NORMALIZE(@v, 'norm2') AS Normalized;
GO

/*
  PLATFORM NOTE — 14/08/2026
  - Vector index = Preview.
  - Latest vector index v3 hiện ở Azure SQL Database / SQL database in Fabric theo rollout.
  - SQL Server 2025 có Preview vector index nhưng current docs chưa nói v3 đã có ở đó.
*/

-- SQL Server 2025 khi cần Preview:
-- ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
-- GO

DROP TABLE IF EXISTS dbo.DP800_VectorAnnDemo;
GO

CREATE TABLE dbo.DP800_VectorAnnDemo
(
    Id int NOT NULL
        CONSTRAINT PK_DP800_VectorAnnDemo PRIMARY KEY CLUSTERED,
    Title nvarchar(100) NOT NULL,
    Embedding vector(3) NOT NULL
);
GO

-- Latest v3 index examples use enough rows to build the index.
INSERT dbo.DP800_VectorAnnDemo(Id, Title, Embedding)
SELECT
    value,
    CONCAT(N'Article ', value),
    CAST(
        JSON_ARRAY(
            CAST(value * 0.01 AS float),
            CAST(value * 0.02 AS float),
            CAST(value * 0.03 AS float)
        )
        AS vector(3)
    )
FROM GENERATE_SERIES(1, 100);
GO

CREATE VECTOR INDEX IX_DP800_VectorAnnDemo_Embedding
ON dbo.DP800_VectorAnnDemo(Embedding)
WITH
(
    TYPE = 'diskann',
    METRIC = 'cosine'
);
GO

/* Latest vector index v3 query */
DECLARE @q vector(3) = '[0.30, 0.60, 0.90]';

SELECT TOP (3) WITH APPROXIMATE
    t.Id,
    t.Title,
    r.distance
FROM VECTOR_SEARCH
(
    TABLE = dbo.DP800_VectorAnnDemo AS t,
    COLUMN = Embedding,
    SIMILAR_TO = @q,
    METRIC = 'cosine'
) AS r
ORDER BY r.distance;
GO

/*
  EARLIER VECTOR INDEX PATH — PHẢI NHẬN DIỆN

  Earlier indexes use TOP_N inside VECTOR_SEARCH, e.g.:

  SELECT t.Id, t.Title, r.distance
  FROM VECTOR_SEARCH
  (
      TABLE = dbo.DP800_VectorAnnDemo AS t,
      COLUMN = Embedding,
      SIMILAR_TO = @q,
      METRIC = 'cosine',
      TOP_N = 3
  ) AS r
  ORDER BY r.distance;

  Đừng học TOP_N như syntax mặc định mới, nhưng cũng đừng coi nó luôn sai.
*/

/* Exact search + prefilter */
ALTER TABLE dbo.DP800_VectorDemo
ADD Category nvarchar(30) NULL;
GO

UPDATE dbo.DP800_VectorDemo
SET Category =
    CASE
        WHEN Id IN (1, 2) THEN N'Azure'
        WHEN Id IN (3, 4) THEN N'AI'
        ELSE N'Other'
    END;
GO

DECLARE @q vector(3) = '[1.0, 0.05, 0.0]';

SELECT TOP (3)
    Id,
    Title,
    VECTOR_DISTANCE('cosine', Embedding, @q) AS Distance
FROM dbo.DP800_VectorDemo
WHERE Category = N'Azure'
ORDER BY Distance;
GO

/* Full-Text Search != LIKE */
DROP TABLE IF EXISTS dbo.DP800_SearchDocuments;
GO

CREATE TABLE dbo.DP800_SearchDocuments
(
    DocumentId  int IDENTITY(1,1)
        CONSTRAINT PK_DP800_SearchDocuments PRIMARY KEY,
    Title       nvarchar(200) NOT NULL,
    ContentText nvarchar(max) NOT NULL,
    Embedding   vector(3) NULL
);
GO

INSERT dbo.DP800_SearchDocuments(Title, ContentText, Embedding)
VALUES
(N'Azure SQL',  N'Azure SQL security and managed identity', '[1,0,0]'),
(N'DAB',        N'Data API builder exposes REST and GraphQL', '[0.9,0.1,0]'),
(N'RAG',        N'Retrieval augmented generation with vector search', '[0,0.8,0.2]');
GO

-- Nếu Full-Text được cài/hỗ trợ:
-- CREATE FULLTEXT CATALOG DP800_FTC AS DEFAULT;
-- GO
-- CREATE FULLTEXT INDEX ON dbo.DP800_SearchDocuments
-- (
--     Title,
--     ContentText
-- )
-- KEY INDEX PK_DP800_SearchDocuments
-- WITH CHANGE_TRACKING AUTO;
-- GO

/* RRF: fuse rank, không cộng raw scores khác scale */
DECLARE @k float = 60.0;

WITH Lexical AS
(
    SELECT *
    FROM (VALUES
        (1, 1),
        (2, 2),
        (3, 3)
    ) v(DocumentId, LexicalRank)
),
VectorRanked AS
(
    SELECT *
    FROM (VALUES
        (2, 1),
        (1, 2),
        (3, 3)
    ) v(DocumentId, VectorRank)
),
AllIds AS
(
    SELECT DocumentId FROM Lexical
    UNION
    SELECT DocumentId FROM VectorRanked
)
SELECT
    a.DocumentId,
    COALESCE(1.0 / (@k + l.LexicalRank), 0.0)
  + COALESCE(1.0 / (@k + v.VectorRank), 0.0) AS RRFScore
FROM AllIds AS a
LEFT JOIN Lexical AS l
  ON l.DocumentId = a.DocumentId
LEFT JOIN VectorRanked AS v
  ON v.DocumentId = a.DocumentId
ORDER BY RRFScore DESC;
GO

PRINT N'
[CHECKLIST]
1. VECTOR_DISTANCE = exact; distance nhỏ hơn = gần hơn.
2. DiskANN = vector index type hiện hành.
3. Latest v3 ANN = SELECT TOP(N) WITH APPROXIMATE + VECTOR_SEARCH.
4. Latest v3 hiện ở Azure SQL DB / SQL database in Fabric theo rollout.
5. TOP_N = earlier vector-index path; vẫn cần nhận diện theo platform/version.
6. Metric query phải tương thích metric index.
7. Full-Text != LIKE.
8. Hybrid = lexical + semantic; RRF fuse ranks, không cộng raw score.
';
GO
