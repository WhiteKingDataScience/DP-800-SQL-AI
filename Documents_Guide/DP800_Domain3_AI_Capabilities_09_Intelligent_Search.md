# DP-800 Domain 3: Design and Implement Intelligent Search

> **Miền 3:** Implement AI Capabilities in Database Solutions (25–30%)  
> **Chủ đề:** Design and Implement Intelligent Search  
> **Blueprint dùng để cập nhật:** DP-800 Skills measured as of **March 12, 2026**  
> **Ngày rà soát:** 09/08/2026  
> **Trọng tâm:** Full-Text Search, Vector Search, Hybrid Search, `VECTOR_*`, ANN vs ENN, DiskANN, RRF và performance.

---

# 0. Checklist blueprint — kỳ thi có thể hỏi gì?

Bạn cần làm được toàn bộ các việc sau:

1. Chọn giữa **full-text**, **semantic vector**, **hybrid search**.
2. Implement **Full-Text Search** thực sự.
3. Thiết kế vector data: `VECTOR`, dimensions, storage/index strategy.
4. Biết khi nào dùng `VECTOR_NORMALIZE`, `VECTOR_DISTANCE`, `VECTORPROPERTY`, `VECTOR_SEARCH`.
5. Chọn **ANN vs ENN**.
6. Đánh giá **vector index type + distance metric**.
7. Viết vector search.
8. Viết hybrid search.
9. Implement **Reciprocal Rank Fusion (RRF)**.
10. Đánh giá performance của vector/hybrid search.

> **Điểm sửa lớn so với tài liệu cũ:** SQL Database Engine hiện dùng **DiskANN** cho `CREATE VECTOR INDEX`; không nên học HNSW như vector-index type của T-SQL này. `VECTOR_SEARCH` cũng đã có syntax mới với `SELECT TOP (N) WITH APPROXIMATE`; `TOP_N` trong function là syntax cũ/deprecated cho index thế hệ trước.

---

# 📘 PHẦN 1 — FULL-TEXT vs VECTOR vs HYBRID

## 1. Ba kiểu search và cách chọn

| Kiểu | Search theo | Thế mạnh | Ví dụ |
|---|---|---|---|
| **B-tree / exact filter** | equality/range có cấu trúc | cực tốt cho ID, SKU, status, date | `WHERE SKU='ABC-123'` |
| **Full-Text Search (FTS)** | lexical words/phrases, morphology, prefix, proximity, weighted terms | keyword/search text chính xác và relevance rank | medical code, tên sản phẩm, thuật ngữ |
| **Vector Search** | semantic similarity | hiểu ý nghĩa/cách diễn đạt khác nhau | “máy không lên nguồn” ~ “thiết bị không khởi động” |
| **Hybrid Search** | kết hợp lexical + semantic | cân bằng exact keyword và semantic recall | enterprise knowledge search |

### Không có một loại “luôn tốt nhất”

Hybrid thường rất mạnh, nhưng không phải lúc nào cũng cần:

- Tìm `InvoiceNo = 'INV-2026-001'` → B-tree/exact search đơn giản hơn.
- Tìm một cụm từ/pháp lý chính xác → Full-Text có thể đủ.
- Tìm ý nghĩa tương đồng dù wording khác → Vector.
- Vừa có mã/keyword quan trọng vừa có câu hỏi tự nhiên → Hybrid.

> **Exam rule:** Chọn giải pháp **đơn giản nhất đáp ứng đủ requirement**. Đừng mặc định “AI/vector” là đáp án cho mọi bài search.

---

# 📘 PHẦN 2 — FULL-TEXT SEARCH THỰC SỰ

## 2. Tại sao `LIKE '%keyword%'` không phải Full-Text Search?

`LIKE` chỉ pattern-match chuỗi; nó không phải Full-Text Engine và không cung cấp relevance `RANK`, stemming/thesaurus/proximity theo cách của SQL Full-Text Search.

DP-800 ghi rõ **Implement full-text search**, vì vậy bạn nên biết:

- Full-text catalog.
- Full-text index.
- `CONTAINS` / `FREETEXT`.
- `CONTAINSTABLE` / `FREETEXTTABLE`.
- `KEY` và `RANK`.

---

## 3. Lab FTS từ đầu

```sql
-- ============================================================
-- LAB 9.1 - REAL FULL-TEXT SEARCH
-- ============================================================

CREATE TABLE dbo.SearchDocuments
(
    DocumentId  int IDENTITY(1,1)
        CONSTRAINT PK_SearchDocuments PRIMARY KEY,
    Title       nvarchar(200) NOT NULL,
    ContentText nvarchar(max) NOT NULL,
    Category    nvarchar(100) NULL,
    Embedding   vector(1536) NULL
);
GO

INSERT dbo.SearchDocuments (Title, ContentText, Category)
VALUES
(N'Chính sách bảo hành', N'Sản phẩm điện tử được bảo hành mười hai tháng kể từ ngày mua.', N'Policy'),
(N'Khắc phục lỗi nguồn', N'Nếu thiết bị không khởi động, hãy kiểm tra nguồn điện và bộ sạc.', N'Troubleshooting'),
(N'Đổi trả sản phẩm', N'Khách hàng có thể đổi trả sản phẩm khi đáp ứng điều kiện của chính sách.', N'Policy');
GO

-- Full-Text Catalog
CREATE FULLTEXT CATALOG DP800_FTC AS DEFAULT;
GO

-- Primary key tạo unique index PK_SearchDocuments; dùng nó làm KEY INDEX.
CREATE FULLTEXT INDEX ON dbo.SearchDocuments
(
    Title LANGUAGE 1066,
    ContentText LANGUAGE 1066
)
KEY INDEX PK_SearchDocuments
WITH CHANGE_TRACKING AUTO;
GO
```

> `LANGUAGE 1066` là LCID tiếng Việt. Khi dữ liệu của bạn là tiếng khác, chọn language resources phù hợp với môi trường và dữ liệu thực tế.

---

## 4. `CONTAINS` vs `FREETEXT`

### `CONTAINS`
Dùng khi bạn muốn kiểm soát search expression: phrase, prefix, inflectional, proximity, weighted terms.

```sql
SELECT DocumentId, Title
FROM dbo.SearchDocuments
WHERE CONTAINS(ContentText, N'"bảo hành"');
GO
```

### `FREETEXT`
Phù hợp với free-form natural language hơn; engine có thể xét linguistic meaning/inflection theo Full-Text Engine.

```sql
SELECT DocumentId, Title
FROM dbo.SearchDocuments
WHERE FREETEXT(ContentText, N'chính sách bảo hành sản phẩm');
GO
```

---

## 5. `CONTAINSTABLE` — đặc biệt quan trọng cho Hybrid/RRF

`CONTAINSTABLE` trả về:

- `[KEY]`: full-text key của row.
- `[RANK]`: relevance rank (0–1000).

```sql
SELECT TOP (20)
    d.DocumentId,
    d.Title,
    ft.[RANK] AS FullTextRank
FROM CONTAINSTABLE
(
    dbo.SearchDocuments,
    (Title, ContentText),
    N'FORMSOF(INFLECTIONAL, "bảo hành")',
    20
) AS ft
INNER JOIN dbo.SearchDocuments AS d
    ON d.DocumentId = ft.[KEY]
ORDER BY ft.[RANK] DESC;
GO
```

### Một số search expression hay gặp

```sql
-- Prefix
WHERE CONTAINS(ContentText, N'"bảo*"');

-- Inflectional forms
WHERE CONTAINS(ContentText, N'FORMSOF(INFLECTIONAL, "run")');

-- Proximity
WHERE CONTAINS(ContentText, N'NEAR(("SQL", "vector"), 10)');
```

> **Exam trap:** Nếu bài yêu cầu **relevance ranking** từ Full-Text Search, `CONTAINSTABLE`/`FREETEXTTABLE` thường phù hợp hơn predicate đơn thuần vì chúng trả `RANK`.

### `FREETEXTTABLE`

`FREETEXTTABLE` cũng trả `KEY` và `RANK`, nhưng nhận free-text meaning thay vì cú pháp điều kiện chi tiết như `CONTAINSTABLE`:

```sql
SELECT TOP (20)
    d.DocumentId,
    d.Title,
    ft.[RANK] AS FullTextRank
FROM FREETEXTTABLE
(
    dbo.SearchDocuments,
    (Title, ContentText),
    N'cách xử lý thiết bị không khởi động',
    20
) AS ft
JOIN dbo.SearchDocuments AS d
    ON d.DocumentId = ft.[KEY]
ORDER BY ft.[RANK] DESC;
GO
```

---

# 📘 PHẦN 3 — VECTOR DATA & FUNCTIONS

## 6. `VECTOR(n)`

- Native binary-optimized representation; được expose giống JSON array cho convenience.
- Mặc định element là `float32`.
- Maximum dimensions hiện tại: **1,998**.
- B-tree/columnstore index không được tạo trực tiếp trên vector column; dùng **vector index** cho ANN.

```sql
DECLARE @v vector(3) = '[0.1, 0.2, 0.3]';
SELECT @v;
GO
```

---

## 7. `VECTORPROPERTY`

Dùng để lấy property của vector, ví dụ dimensions/base type.

```sql
DECLARE @v vector(3) = '[0.1, 0.2, 0.3]';

SELECT
    VECTORPROPERTY(@v, 'Dimensions') AS Dimensions,
    VECTORPROPERTY(@v, 'BaseType') AS BaseType;
GO
```

> **Bẫy:** `VECTORPROPERTY` viết liền, không phải `VECTOR_PROPERTY`.

---

## 8. `VECTOR_NORM` và `VECTOR_NORMALIZE`

### Norm
Đo magnitude/length của vector theo norm type.

```sql
DECLARE @v vector(3) = '[3, 4, 0]';
SELECT VECTOR_NORM(@v, 'norm2') AS L2Norm;
GO
```

### Normalize
Chuẩn hóa vector về độ dài 1 theo norm type.

```sql
DECLARE @v vector(3) = '[3, 4, 0]';
SELECT VECTOR_NORMALIZE(@v, 'norm2') AS NormalizedVector;
GO
```

> **Sửa lỗi tài liệu cũ:** syntax không phải chỉ `VECTOR_NORMALIZE(vector)`; current function cần chỉ rõ norm type.

---

## 9. `VECTOR_DISTANCE`

Cú pháp:

```sql
VECTOR_DISTANCE('cosine' | 'euclidean' | 'dot', vector1, vector2)
```

### Các metric

| Metric | Ý nghĩa | Dùng khi |
|---|---|---|
| `cosine` | so hướng/góc | rất phổ biến cho text embeddings |
| `euclidean` | khoảng cách hình học L2 | khi magnitude/spatial distance có ý nghĩa |
| `dot` | negative dot product theo SQL vector distance semantics | khi model/retrieval design phù hợp dot-product |

> **Metric phải đồng nhất:** Query `VECTOR_SEARCH` chỉ tận dụng ANN index tương thích khi metric của search phù hợp với metric của vector index.

### Exact search bằng `VECTOR_DISTANCE`

```sql
DECLARE @QueryVector vector(1536) =
    AI_GENERATE_EMBEDDINGS
    (
        N'thiết bị không khởi động'
        USE MODEL DP800_EmbeddingModel
    );

SELECT TOP (10)
    DocumentId,
    Title,
    VECTOR_DISTANCE('cosine', Embedding, @QueryVector) AS Distance
FROM dbo.SearchDocuments
WHERE Embedding IS NOT NULL
ORDER BY Distance ASC;
GO
```

**Rất quan trọng:** `VECTOR_DISTANCE` tính distance **exact** và không dùng vector index để biến phép tính này thành ANN.

---

# 📘 PHẦN 4 — ENN/kNN vs ANN

## 10. Exact nearest neighbors (ENN/kNN)

Exact search tính khoảng cách trên toàn bộ candidate set cần xét và cho exact nearest neighbors.

Phù hợp khi:

- dataset/candidate set nhỏ,
- cần deterministic/exact recall,
- filter trước làm candidate set rất nhỏ,
- batch/offline workload chấp nhận latency cao hơn.

Microsoft guidance hiện gợi ý exact search thường phù hợp khi candidate set dưới khoảng **50,000 vectors**; đây là rule-of-thumb, không phải hard exam threshold.

---

## 11. ANN — Approximate Nearest Neighbor

ANN đánh đổi một phần recall để tăng tốc rất mạnh khi vector corpus lớn.

Phù hợp:

- hàng trăm nghìn/hàng triệu vectors,
- interactive search SLA,
- có thể chấp nhận approximate result.

### Vector index type hiện hành: `DiskANN`

Cú pháp cần nhớ:

```sql
CREATE VECTOR INDEX IX_SearchDocuments_Embedding
ON dbo.SearchDocuments(Embedding)
WITH
(
    METRIC = 'cosine',
    TYPE = 'DiskANN'
);
GO
```

> **Quan trọng khi chạy lab:** Current/latest vector index yêu cầu tối thiểu **100 rows có non-NULL vectors**. Bảng `SearchDocuments` phía trên chỉ có vài row để học Full-Text nên đừng chạy lệnh index này trên bảng đó cho đến khi đã populate đủ dữ liệu. Lab chạy độc lập ngay dưới đây minh họa đầy đủ điều kiện này.

### Lab chạy độc lập: 100 rows → DiskANN → approximate search

```sql
-- SQL Server 2025: bật Preview feature khi platform yêu cầu
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
GO

DROP TABLE IF EXISTS dbo.VectorIndexDemo;
GO

CREATE TABLE dbo.VectorIndexDemo
(
    Id        int NOT NULL CONSTRAINT PK_VectorIndexDemo PRIMARY KEY CLUSTERED,
    Title     nvarchar(100) NOT NULL,
    Category  varchar(20) NOT NULL,
    Embedding vector(5) NOT NULL
);
GO

-- Tạo đủ 100 vectors mẫu để đáp ứng minimum current index requirement.
INSERT dbo.VectorIndexDemo (Id, Title, Category, Embedding)
SELECT
    value,
    CONCAT(N'Article ', value),
    CASE WHEN value % 2 = 0 THEN 'Tech' ELSE 'Other' END,
    CAST
    (
        JSON_ARRAY
        (
            CAST(value * 0.01 AS float),
            CAST(value * 0.02 AS float),
            CAST(value * 0.03 AS float),
            CAST(value * 0.04 AS float),
            CAST(value * 0.05 AS float)
        ) AS vector(5)
    )
FROM GENERATE_SERIES(1, 100);
GO

CREATE VECTOR INDEX IX_VectorIndexDemo_Embedding
ON dbo.VectorIndexDemo(Embedding)
WITH
(
    METRIC = 'cosine',
    TYPE = 'DiskANN'
);
GO

DECLARE @qv vector(5) = '[0.3,0.3,0.3,0.3,0.3]';

SELECT TOP (5) WITH APPROXIMATE
    d.Id,
    d.Title,
    r.distance
FROM VECTOR_SEARCH
(
    TABLE = dbo.VectorIndexDemo AS d,
    COLUMN = Embedding,
    SIMILAR_TO = @qv,
    METRIC = 'cosine'
) AS r
ORDER BY r.distance;
GO
```

> **Bẫy thi:** Với SQL Database Engine hiện hành, `CREATE VECTOR INDEX` chỉ hỗ trợ `TYPE = 'DiskANN'`. HNSW tồn tại trong nhiều vector systems khác nhưng không phải đáp án T-SQL `CREATE VECTOR INDEX` này.

---

# 📘 PHẦN 5 — VECTOR INDEX: CURRENT 2026 BEHAVIOR

## 12. Preview/availability cần hiểu

`CREATE VECTOR INDEX` và approximate `VECTOR_SEARCH` vẫn có các phần Preview/rollout theo platform.

- SQL Server 2025: cần `PREVIEW_FEATURES` để dùng Preview functionality này.
- Azure SQL Database / SQL database in Fabric: availability có thể rollout theo region/index version.
- Latest vector index generation hiện có behavior mới so với earlier versions.

```sql
-- SQL Server 2025 khi cần Preview feature
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
GO
```

---

## 13. Điều kiện/limitations quan trọng của current vector index

Các điểm dễ bị hỏi theo scenario hoặc dễ làm lab lỗi:

- Base table cần **clustered primary key** cho current vector index requirements.
- Cần ít nhất **100 rows có non-NULL vector** trước khi tạo current vector index.
- Vector index hiện không partition được.
- Bảng đang có vector index không `TRUNCATE TABLE` trực tiếp; cần drop index → truncate → reload → recreate.
- Vector indexes không deploy trực tiếp thuận lợi qua DACPAC/BACPAC theo current limitation; thường recreate sau data load/import.
- Latest generation hỗ trợ DML và background maintenance; older index generations có limitations khác.

### Monitor index version/health

```sql
SELECT
    i.name AS IndexName,
    t.name AS TableName,
    JSON_VALUE(v.build_parameters, '$.Version') AS IndexVersion
FROM sys.vector_indexes AS v
JOIN sys.indexes AS i
    ON i.object_id = v.object_id
   AND i.index_id = v.index_id
JOIN sys.tables AS t
    ON t.object_id = v.object_id;
GO
```

Current latest index generation còn có DMV để monitor vector-index maintenance/health, ví dụ `sys.dm_db_vector_indexes` khi platform/version hỗ trợ.

---

# 📘 PHẦN 6 — `VECTOR_SEARCH`: SYNTAX HIỆN HÀNH

## 14. Approximate search — latest syntax

Với current/latest vector index:

```sql
DECLARE @qv vector(1536) =
    AI_GENERATE_EMBEDDINGS
    (
        N'cách xử lý máy không lên nguồn'
        USE MODEL DP800_EmbeddingModel
    );

SELECT TOP (10) WITH APPROXIMATE
    d.DocumentId,
    d.Title,
    r.distance
FROM VECTOR_SEARCH
(
    TABLE = dbo.SearchDocuments AS d,
    COLUMN = Embedding,
    SIMILAR_TO = @qv,
    METRIC = 'cosine'
) AS r
ORDER BY r.distance;
GO
```

### Phải nhớ

- `WITH APPROXIMATE` nằm ở `SELECT TOP (N)`, không phải một parameter mới trong function.
- `ORDER BY r.distance` là bắt buộc cho approximate syntax.
- Distance phải order **ASC**.
- Với approximate query, `distance` là ordering key hợp lệ theo current restrictions.
- `TOP_N` parameter trong `VECTOR_SEARCH` là syntax cũ/deprecated cho older vector index versions.

---

## 15. `VECTOR_SEARCH` cũng có thể chạy exact kNN

Current behavior:

```sql
-- Không WITH APPROXIMATE => exact kNN theo current semantics
SELECT TOP (10)
    d.DocumentId,
    d.Title,
    r.distance
FROM VECTOR_SEARCH
(
    TABLE = dbo.SearchDocuments AS d,
    COLUMN = Embedding,
    SIMILAR_TO = @qv,
    METRIC = 'cosine'
) AS r
ORDER BY r.distance;
GO
```

Không có compatible ANN index thì engine có thể thực hiện full scan/kNN; approximate query có thể warn/fallback theo current behavior nếu không có compatible index.

> **Exam trap:** `VECTOR_SEARCH` không đồng nghĩa tuyệt đối “ANN”. Với current syntax/engine behavior, `TOP ... WITH APPROXIMATE` thể hiện explicit approximate request; không có `WITH APPROXIMATE` có thể là exact kNN.

---

## 16. Iterative filtering — cập nhật 2026 rất đáng nhớ

Latest vector indexes hỗ trợ **iterative filtering**: relational predicates có thể được áp dụng trong quá trình vector search thay vì chỉ post-filter.

```sql
SELECT TOP (5) WITH APPROXIMATE
    d.DocumentId,
    d.Title,
    d.Category,
    r.distance
FROM VECTOR_SEARCH
(
    TABLE = dbo.SearchDocuments AS d,
    COLUMN = Embedding,
    SIMILAR_TO = @qv,
    METRIC = 'cosine'
) AS r
WHERE d.Category = N'Troubleshooting'
ORDER BY r.distance;
GO
```

### Performance pattern

Có thể dùng đồng thời:

- Vector index trên `Embedding`.
- B-tree index trên filter columns như `Category`, `TenantId`, `IsPublished`.

```sql
CREATE INDEX IX_SearchDocuments_Category
ON dbo.SearchDocuments(Category);
GO
```

> Đây là mental model rất quan trọng: **vector index giải semantic candidate search; relational index giải structured filtering**.

---

# 📘 PHẦN 7 — GENERATE SAMPLE EMBEDDINGS

## 17. Populate embeddings

Giả sử file 08 đã tạo `DP800_EmbeddingModel`:

```sql
UPDATE dbo.SearchDocuments
SET Embedding = AI_GENERATE_EMBEDDINGS
(
    CONCAT_WS(N' | ', Title, Category, ContentText)
    USE MODEL DP800_EmbeddingModel
)
WHERE Embedding IS NULL;
GO
```

> Trên môi trường thật, batch/throttling/cost cần được cân nhắc; không nên UPDATE hàng triệu rows một phát mà không có kế hoạch batching/retry.

---

# 📘 PHẦN 8 — HYBRID SEARCH

## 18. Hybrid Search đúng nghĩa

Hybrid search kết hợp:

1. **Lexical rank** từ Full-Text Search (`CONTAINSTABLE`/`FREETEXTTABLE`).
2. **Semantic rank** từ vector search.
3. Fusion/re-ranking, ví dụ **RRF**.

Không nên gọi `LIKE '%keyword%'` + vector là “full hybrid implementation” cho mục tiêu DP-800, vì bạn không khai thác Full-Text ranking.

---

# 📘 PHẦN 9 — RECIPROCAL RANK FUSION (RRF)

## 19. RRF là gì?

Khi hai search systems trả score khác scale:

- Full-Text `RANK`: 0–1000.
- Vector distance: nhỏ hơn = tốt hơn.

Không nên cộng trực tiếp hai score raw.

RRF dùng **vị trí xếp hạng**:

```text
RRF(d) = Σ 1 / (k + rank_i(d))
```

`k = 60` là một constant phổ biến trong ví dụ/thực tế, nhưng RRF không phải built-in T-SQL function và 60 không phải “luật SQL”.

### Ý tưởng

- Rank 1 từ FTS → contribution cao.
- Rank 2 từ Vector → contribution cao.
- Document xuất hiện tốt ở cả hai danh sách → tổng RRF cao.

---

## 20. Lab Hybrid + RRF với Full-Text thật và Vector thật

> Lab này dùng **exact vector ranking** để code dễ hiểu và chạy được ngay cả khi chưa tạo ANN index. Khi corpus lớn, có thể thay phần vector candidates bằng `VECTOR_SEARCH ... WITH APPROXIMATE`.

```sql
CREATE OR ALTER PROCEDURE dbo.SearchHybridRRF
    @FullTextCondition nvarchar(4000),
    @QueryVector vector(1536),
    @TopK int = 10
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH FullTextCandidates AS
    (
        SELECT TOP (50)
            d.DocumentId,
            ft.[RANK] AS FtsScore,
            ROW_NUMBER() OVER
            (
                ORDER BY ft.[RANK] DESC, d.DocumentId
            ) AS FtsRank
        FROM CONTAINSTABLE
        (
            dbo.SearchDocuments,
            (Title, ContentText),
            @FullTextCondition,
            50
        ) AS ft
        JOIN dbo.SearchDocuments AS d
            ON d.DocumentId = ft.[KEY]
        ORDER BY ft.[RANK] DESC
    ),
    VectorCandidatesRaw AS
    (
        SELECT TOP (50)
            d.DocumentId,
            VECTOR_DISTANCE('cosine', d.Embedding, @QueryVector) AS VectorDistance
        FROM dbo.SearchDocuments AS d
        WHERE d.Embedding IS NOT NULL
        ORDER BY VECTOR_DISTANCE('cosine', d.Embedding, @QueryVector), d.DocumentId
    ),
    VectorCandidates AS
    (
        SELECT
            DocumentId,
            VectorDistance,
            ROW_NUMBER() OVER
            (
                ORDER BY VectorDistance ASC, DocumentId
            ) AS VectorRank
        FROM VectorCandidatesRaw
    ),
    Combined AS
    (
        SELECT
            COALESCE(f.DocumentId, v.DocumentId) AS DocumentId,
            f.FtsScore,
            f.FtsRank,
            v.VectorDistance,
            v.VectorRank
        FROM FullTextCandidates AS f
        FULL OUTER JOIN VectorCandidates AS v
            ON v.DocumentId = f.DocumentId
    )
    SELECT TOP (@TopK)
        d.DocumentId,
        d.Title,
        d.Category,
        c.FtsScore,
        c.FtsRank,
        c.VectorDistance,
        c.VectorRank,
        CAST
        (
            COALESCE(1.0 / (60.0 + c.FtsRank), 0.0)
          + COALESCE(1.0 / (60.0 + c.VectorRank), 0.0)
          AS decimal(18,10)
        ) AS RRFScore
    FROM Combined AS c
    JOIN dbo.SearchDocuments AS d
        ON d.DocumentId = c.DocumentId
    ORDER BY RRFScore DESC, d.DocumentId;
END;
GO
```

Gọi:

```sql
DECLARE @qv vector(1536) =
    AI_GENERATE_EMBEDDINGS
    (
        N'thiết bị không khởi động'
        USE MODEL DP800_EmbeddingModel
    );

EXEC dbo.SearchHybridRRF
    @FullTextCondition = N'"khởi động" OR "nguồn"',
    @QueryVector = @qv,
    @TopK = 5;
GO
```

---

## 21. ANN version cho vector candidates

Khi đã có current vector index và đủ dữ liệu:

```sql
DECLARE @qv vector(1536) =
    AI_GENERATE_EMBEDDINGS
    (
        N'thiết bị không khởi động'
        USE MODEL DP800_EmbeddingModel
    );

SELECT TOP (50) WITH APPROXIMATE
    d.DocumentId,
    r.distance
FROM VECTOR_SEARCH
(
    TABLE = dbo.SearchDocuments AS d,
    COLUMN = Embedding,
    SIMILAR_TO = @qv,
    METRIC = 'cosine'
) AS r
ORDER BY r.distance;
GO
```

Sau đó bọc result này trong subquery/CTE để tạo `ROW_NUMBER()` và fusion với FTS list.

---

# 📘 PHẦN 10 — PERFORMANCE

## 22. Những yếu tố ảnh hưởng vector search performance

### A. Number of candidate vectors
- Ít → exact có thể đủ.
- Rất nhiều → ANN/index hữu ích.

### B. Dimensions
Vector nhiều chiều hơn:
- storage lớn hơn,
- CPU/memory cost cao hơn,
- index/search có thể tốn tài nguyên hơn.

### C. Distance metric
Metric của query cần phù hợp metric của vector index.

### D. Structured filters
Ví dụ `TenantId`, `Category`, `Published` nên có relational indexes phù hợp.

### E. Duplicate/low-quality embeddings
Nhiều duplicate vectors có thể làm search quality/index usefulness kém.

### F. Stale embeddings
Index nhanh nhưng semantic data cũ vẫn trả kết quả sai về nghĩa.

### G. Exact recall vs latency
ANN là trade-off: latency tốt hơn nhưng approximate.

---

## 23. Measure thay vì đoán

Bạn nên đo:

- Query latency p50/p95/p99.
- Logical reads/CPU.
- Recall@K nếu so ANN với exact baseline.
- Result quality/relevance.
- Index build/maintenance cost.
- Storage.
- Filter selectivity.

### Test ANN quality bằng exact baseline

1. Chọn tập query mẫu.
2. Chạy exact top K.
3. Chạy approximate top K.
4. So overlap/recall.
5. Đo latency.

Đây là cách đánh giá đúng bản chất ANN: **speed vs recall/quality**.

---

# 🧠 PHẦN 11 — EXAM TRAPS

## 24. Bẫy cần nhớ

### Bẫy 1 — `LIKE` = Full-Text Search
Sai. DP-800 yêu cầu Full-Text Search; hãy biết catalog/index và `CONTAINSTABLE`/`FREETEXTTABLE`.

### Bẫy 2 — Vector search thay exact SKU lookup
Sai. `SKU = ...` thường B-tree/exact filter tốt hơn.

### Bẫy 3 — SQL vector index = HNSW
Sai với current SQL Database Engine syntax. `CREATE VECTOR INDEX` hiện dùng **DiskANN**.

### Bẫy 4 — `VECTOR_DISTANCE` dùng ANN index
Sai. `VECTOR_DISTANCE` là exact distance calculation.

### Bẫy 5 — Current `VECTOR_SEARCH` luôn cần `TOP_N`
Sai. `TOP_N` là deprecated syntax cho earlier vector indexes. Latest syntax dùng `SELECT TOP(N) WITH APPROXIMATE`.

### Bẫy 6 — `WITH APPROXIMATE` nhưng không `ORDER BY distance`
Sai theo current syntax requirements.

### Bẫy 7 — Metric index/search khác nhau
ANN index chỉ hữu ích khi compatible metric/column.

### Bẫy 8 — Full-text raw score + vector raw distance cộng trực tiếp
Không tốt vì scale/meaning khác nhau. RRF dùng ranks để fusion.

### Bẫy 9 — Hybrid luôn tốt nhất
Sai. Tăng complexity; chỉ dùng khi lexical + semantic đều tạo giá trị.

### Bẫy 10 — Vector index tạo được khi table có 3 rows
Current latest vector index yêu cầu ít nhất 100 non-NULL vectors.

---

# 📝 PHẦN 12 — MOCK QUESTIONS

## Question 1 — DiskANN
Bạn cần tạo ANN index trên Azure SQL vector column. Current SQL Database Engine hỗ trợ loại nào trong `CREATE VECTOR INDEX`?

- A. HNSW
- B. IVF-PQ
- C. DiskANN
- D. B-tree ANN

**Đáp án: C.**

---

## Question 2 — Exact vs approximate
Corpus có 500 rows và exact correctness quan trọng hơn latency. Chọn giải pháp đơn giản:

- A. Exact kNN bằng `VECTOR_DISTANCE`/exact `VECTOR_SEARCH`.
- B. Bắt buộc DiskANN.
- C. Full-text only.
- D. Graph table.

**Đáp án: A.**

---

## Question 3 — Current approximate syntax
Cú pháp current/latest phù hợp là:

- A. `VECTOR_SEARCH(... TOP_N=10)` bắt buộc.
- B. `SELECT TOP (10) WITH APPROXIMATE ... FROM VECTOR_SEARCH(...) ORDER BY distance`.
- C. `SELECT APPROXIMATE 10 FROM VECTOR_DISTANCE(...)`.
- D. `CREATE HNSW SEARCH`.

**Đáp án: B.**

---

## Question 4 — FTS rank
Bạn cần lexical result có relevance ranking để fuse với vector rank. Nên dùng:

- A. `LIKE`
- B. `CONTAINSTABLE`
- C. `CHARINDEX`
- D. `LEN`

**Đáp án: B.** `CONTAINSTABLE` trả `KEY` và `RANK`.

---

## Question 5 — RRF
Tại sao RRF phù hợp cho hybrid search?

- A. Vì nó encrypt vector.
- B. Vì nó gộp các ranked lists dựa trên vị trí xếp hạng, tránh phụ thuộc raw-score scale khác nhau.
- C. Vì nó tạo full-text index.
- D. Vì nó re-embeds dữ liệu.

**Đáp án: B.**

---

## Question 6 — Metric mismatch
Vector index được tạo với cosine, query `VECTOR_SEARCH` yêu cầu euclidean. Điều gì quan trọng nhất?

- A. Index luôn được dùng vì cùng vector column.
- B. ANN index phải compatible với metric; metric mismatch có thể khiến index không được tận dụng như mong muốn.
- C. SQL tự đổi euclidean thành cosine.
- D. Cần đổi vector thành XML.

**Đáp án: B.**

---

## Question 7 — Structured filter + vector
Bạn search semantic trong 10 triệu products nhưng chỉ category `Electronics`. Thiết kế tốt:

- A. Chỉ vector index, không relational index nào khác.
- B. Vector index trên embedding + B-tree index thích hợp trên filter column, dùng iterative filtering khi current index hỗ trợ.
- C. Full scan toàn bảng rồi filter cuối cùng.
- D. Chuyển category thành vector duy nhất.

**Đáp án: B.**

---

# ✅ PHẦN 13 — EXAM-READY CHECKLIST

Bạn đã nắm chắc file 09 nếu có thể:

- [ ] Giải thích B-tree vs Full-Text vs Vector vs Hybrid.
- [ ] Tạo Full-Text Catalog và Full-Text Index.
- [ ] Dùng `CONTAINS`, `FREETEXT`, `CONTAINSTABLE`.
- [ ] Giải thích `[KEY]` và `[RANK]` của `CONTAINSTABLE`.
- [ ] Nhớ `VECTOR` max dimensions hiện hành.
- [ ] Viết đúng `VECTORPROPERTY`.
- [ ] Viết đúng `VECTOR_NORM` và `VECTOR_NORMALIZE(vector, norm_type)`.
- [ ] Dùng `VECTOR_DISTANCE` với cosine/euclidean/dot.
- [ ] Giải thích exact kNN/ENN vs ANN.
- [ ] Nhớ current `CREATE VECTOR INDEX ... TYPE='DiskANN'`.
- [ ] Nhớ minimum current vector-index rows và key limitations.
- [ ] Viết current `VECTOR_SEARCH` với `TOP (N) WITH APPROXIMATE`.
- [ ] Biết `TOP_N` là legacy/deprecated cho earlier index versions.
- [ ] Giải thích iterative filtering.
- [ ] Thiết kế Full-Text + Vector hybrid.
- [ ] Tự viết RRF bằng ranks.
- [ ] Đánh giá vector performance bằng latency + recall/quality.

---

# 🔗 PHẦN 14 — TÀI LIỆU THAM KHẢO CHÍNH THỨC

1. [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
2. [Vector search and vector indexes in the SQL Database Engine](https://learn.microsoft.com/en-us/sql/sql-server/ai/vectors?view=sql-server-ver17)
3. [Vector data type](https://learn.microsoft.com/en-us/sql/t-sql/data-types/vector-data-type?view=sql-server-ver17)
4. [Vector functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/vector-functions-transact-sql?view=sql-server-ver17)
5. [VECTOR_DISTANCE](https://learn.microsoft.com/en-us/sql/t-sql/functions/vector-distance-transact-sql?view=sql-server-ver17)
6. [VECTOR_SEARCH](https://learn.microsoft.com/en-us/sql/t-sql/functions/vector-search-transact-sql?view=sql-server-ver17)
7. [CREATE VECTOR INDEX](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-vector-index-transact-sql?view=sql-server-ver17)
8. [CONTAINSTABLE](https://learn.microsoft.com/en-us/sql/relational-databases/system-functions/containstable-transact-sql?view=sql-server-ver17)
9. [Full-Text Search functions](https://learn.microsoft.com/en-us/sql/relational-databases/system-functions/full-text-search-and-semantic-search-functions-transact-sql?view=sql-server-ver17)
10. [sys.fulltext_languages — kiểm tra language/LCID có sẵn](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-fulltext-languages-transact-sql?view=sql-server-ver17)
11. [Microsoft Learn — Implement AI capabilities in database solutions](https://learn.microsoft.com/en-us/training/paths/implement-ai-capabilities-database-solutions/)

---

## Ghi chú versioning

Vector index/search đang thay đổi nhanh và một số khả năng vẫn Preview. Tài liệu này ưu tiên syntax current/latest tại ngày rà soát và ghi riêng legacy behavior để bạn nhận diện câu hỏi hoặc môi trường cũ, thay vì học lẫn hai thế hệ syntax.
