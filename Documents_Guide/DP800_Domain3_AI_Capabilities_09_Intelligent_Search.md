# DP-800 Miền 3 — Thiết kế và triển khai tìm kiếm thông minh

> **Miền 3:** Triển khai khả năng AI trong giải pháp cơ sở dữ liệu (25–30%)  
> **Chủ đề:** Full-Text Search, Vector Search, Hybrid Search và RRF  
> **Blueprint dùng để cập nhật:** DP-800 Skills measured as of **March 12, 2026**  
> **Cập nhật cách trình bày:** 12/08/2026  
> **Trọng tâm:** Chọn đúng kiểu tìm kiếm, hiểu kết quả xếp hạng và cân bằng chất lượng với tốc độ.

## Tại sao một hệ thống cần nhiều kiểu tìm kiếm?

Người dùng có thể tìm bằng mã chính xác, bằng từ khóa hoặc bằng một câu diễn đạt ý nghĩa. Không một công cụ tìm kiếm nào giỏi nhất cho mọi trường hợp.

Ví dụ:

- tìm `SKU-A17` cần so khớp chính xác bằng B-tree hoặc điều kiện `=`;
- tìm tài liệu có cụm “hoàn tiền” cần Full-Text Search;
- tìm “quy định trả lại sản phẩm” dù tài liệu viết “chính sách hoàn tiền” cần Vector Search;
- muốn vừa giữ mã sản phẩm chính xác vừa hiểu câu hỏi tự nhiên cần Hybrid Search.

Chương này dạy bạn chọn đúng kỹ thuật, không mặc định “có AI thì phải dùng vector”. Sau khi tìm được kết quả, bạn còn phải hiểu khoảng cách, thứ hạng, độ chính xác và độ trễ để biết hệ thống có thực sự tốt hay không.

---

# 0. Phạm vi kiến thức — kỳ thi có thể hỏi gì?

Bạn cần làm được toàn bộ các việc sau:

1. Chọn giữa **full-text**, **semantic vector**, **hybrid search**.
2. Triển khai **Full-Text Search** thực sự.
3. Thiết kế dữ liệu vector: `VECTOR`, số chiều, cách lưu và chiến lược index.
4. Biết khi nào dùng `VECTOR_NORMALIZE`, `VECTOR_DISTANCE`, `VECTORPROPERTY`, `VECTOR_SEARCH`.
5. Chọn **ANN vs ENN**.
6. Đánh giá loại vector index và thước đo khoảng cách.
7. Viết vector search.
8. Viết hybrid search.
9. Hợp nhất thứ hạng bằng **Reciprocal Rank Fusion (RRF)**.
10. Đánh giá chất lượng và hiệu năng của Vector/Hybrid Search.

> **Điểm cập nhật quan trọng:** SQL Database Engine hiện dùng **DiskANN** cho `CREATE VECTOR INDEX`; HNSW không phải loại index của câu lệnh T-SQL này. Với **vector index v3**, `VECTOR_SEARCH` dùng `SELECT TOP (N) WITH APPROXIMATE`; `TOP_N` là cú pháp cũ nhưng vẫn cần cho index thế hệ trước. Luôn đọc đúng nền tảng và phiên bản: tại ngày rà soát, v3 mới chỉ có trên Azure SQL Database và SQL database in Fabric.

### Ma trận nền tảng và phiên bản bắt buộc phải nhớ (09/08/2026)

| Khả năng | SQL Server 2025 | Azure SQL Database | Azure SQL Managed Instance | SQL database in Fabric |
|---|---|---|---|---|
| `VECTOR`, `VECTOR_DISTANCE`, `VECTOR_NORM`, `VECTOR_NORMALIZE`, `VECTORPROPERTY` | Có | Có | Có theo servicing policy | Có |
| `CREATE VECTOR INDEX` / `VECTOR_SEARCH` | **Preview**; cần `PREVIEW_FEATURES` | **Preview**, rollout theo region | **Không được liệt kê** trong `Applies to` hiện hành | **Preview**, rollout theo region |
| Vector index **v3 mới nhất**: hỗ trợ đầy đủ DML, lọc lặp, ANN/kNN do bộ tối ưu lựa chọn và lượng tử hóa | Chưa có theo ghi chú hiện hành | Có khi đã được triển khai tới khu vực | Không áp dụng | Có khi đã được triển khai tới khu vực |
| Vector index thế hệ trước: dùng `TOP_N` cũ, lọc sau và bị giới hạn DML | Có trong trạng thái Preview hiện hành | Có thể còn tồn tại nếu chỉ mục cũ chưa được chuyển đổi | Không áp dụng | Có thể còn tồn tại nếu chỉ mục cũ chưa được chuyển đổi |

Do đó, trên Managed Instance hãy dùng exact search bằng `VECTOR_DISTANCE` trong phạm vi docs hiện hành; không suy luận rằng có kiểu `VECTOR` thì chắc chắn có DiskANN/`VECTOR_SEARCH`. Nguồn chốt: [CREATE VECTOR INDEX (Preview)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-vector-index-transact-sql?view=sql-server-ver17) và [VECTOR_SEARCH (Preview)](https://learn.microsoft.com/en-us/sql/t-sql/functions/vector-search-transact-sql?view=sql-server-ver17).

---

# PHẦN 1 — SO SÁNH TÌM KIẾM TOÀN VĂN, VECTOR VÀ KẾT HỢP

## 1. Các kiểu tìm kiếm và cách chọn

| Kiểu | Tìm theo | Thế mạnh | Ví dụ |
|---|---|---|---|
| **B-tree / exact filter** | equality/range có cấu trúc | cực tốt cho ID, SKU, status, date | `WHERE SKU='ABC-123'` |
| **Full-Text Search (FTS)** | từ/cụm từ, biến thể hình thái, tiền tố, khoảng cách và trọng số | từ khóa hoặc cụm từ chính xác, cần điểm liên quan | mã y tế, tên sản phẩm, thuật ngữ |
| **Vector Search** | semantic similarity | hiểu ý nghĩa/cách diễn đạt khác nhau | “máy không lên nguồn” ~ “thiết bị không khởi động” |
| **Hybrid Search** | kết hợp lexical + semantic | cân bằng exact keyword và semantic recall | enterprise knowledge search |

### Không có một loại “luôn tốt nhất”

Hybrid thường rất mạnh, nhưng không phải lúc nào cũng cần:

- Tìm `InvoiceNo = 'INV-2026-001'` → B-tree/exact search đơn giản hơn.
- Tìm một cụm từ/pháp lý chính xác → Full-Text có thể đủ.
- Tìm ý nghĩa tương đồng dù wording khác → Vector.
- Vừa có mã/keyword quan trọng vừa có câu hỏi tự nhiên → Hybrid.

> **Quy tắc khi làm bài:** Chọn giải pháp **đơn giản nhất nhưng đáp ứng đủ yêu cầu**. Đừng mặc định AI/vector là đáp án cho mọi bài toán tìm kiếm.

---

# PHẦN 2 — TÌM KIẾM TOÀN VĂN THỰC SỰ

## 2. Tại sao `LIKE '%từ_khóa%'` không phải tìm kiếm toàn văn?

`LIKE` chỉ pattern-match chuỗi; nó không phải Full-Text Engine và không cung cấp relevance `RANK`, stemming/thesaurus/proximity theo cách của SQL Full-Text Search.

DP-800 ghi rõ **Implement full-text search**, vì vậy bạn nên biết:

- Full-text catalog.
- Full-text index.
- `CONTAINS` / `FREETEXT`.
- `CONTAINSTABLE` / `FREETEXTTABLE`.
- `KEY` và `RANK`.

---

## 3. Bài thực hành tìm kiếm toàn văn từ đầu

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

### Kiểm tra Full-Text đã sẵn sàng chưa

```sql
-- 1 = Full-Text component đã được cài trên SQL Server instance.
SELECT FULLTEXTSERVICEPROPERTY('IsFullTextInstalled') AS IsFullTextInstalled;

-- Kiểm tra language resource tiếng Việt có trên instance hay không.
SELECT lcid, name
FROM sys.fulltext_languages
WHERE lcid = 1066;

-- 0 thường là idle; trạng thái khác cho biết catalog đang populate/thay đổi.
SELECT FULLTEXTCATALOGPROPERTY('DP800_FTC', 'PopulateStatus') AS PopulateStatus;
GO
```

Nếu query vừa tạo index nhưng chưa thấy kết quả, kiểm tra population status, full-text crawl log, unique key, language/word breaker, stoplist và transaction đã commit. `CHANGE_TRACKING AUTO` ở đây là cơ chế duy trì **full-text index**, không phải SQL Server Change Tracking dùng cho pipeline re-embedding.

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

### Một số biểu thức tìm kiếm hay gặp

```sql
-- Prefix
WHERE CONTAINS(ContentText, N'"bảo*"');

-- Inflectional forms
WHERE CONTAINS(ContentText, N'FORMSOF(INFLECTIONAL, "run")');

-- Proximity
WHERE CONTAINS(ContentText, N'NEAR(("SQL", "vector"), 10)');
```

> **Bẫy thường gặp trong đề:** Nếu cần **xếp hạng mức độ liên quan** từ Full-Text Search, `CONTAINSTABLE` hoặc `FREETEXTTABLE` thường phù hợp hơn predicate đơn thuần vì chúng trả cột `RANK`.

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

# PHẦN 3 — DỮ LIỆU VECTOR VÀ CÁC HÀM `VECTOR_*`

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

### Độ dài vector (norm)
Đo magnitude/length của vector theo norm type.

```sql
DECLARE @v vector(3) = '[3, 4, 0]';
SELECT VECTOR_NORM(@v, 'norm2') AS L2Norm;
GO
```

Các norm type hiện hỗ trợ là `norm1` (L1), `norm2` (L2) và `norminf` (giá trị tuyệt đối lớn nhất).

### Chuẩn hóa vector
Chuẩn hóa vector về độ dài 1 theo norm type.

```sql
DECLARE @v vector(3) = '[3, 4, 0]';
SELECT VECTOR_NORMALIZE(@v, 'norm2') AS NormalizedVector;
GO
```

> **Sửa lỗi tài liệu cũ:** syntax không phải chỉ `VECTOR_NORMALIZE(vector)`; current function cần chỉ rõ norm type.

Azure OpenAI embedding vectors đã được normalize theo tài liệu Microsoft; đừng normalize lặp lại chỉ vì “vector search luôn cần normalize”. Với model khác, hãy kiểm tra model contract và dùng cùng preprocessing cho cả corpus lẫn query.

---

## 9. `VECTOR_DISTANCE`

Cú pháp:

```sql
VECTOR_DISTANCE('cosine' | 'euclidean' | 'dot', vector1, vector2)
```

### Các thước đo khoảng cách

| Metric | Ý nghĩa | Dùng khi |
|---|---|---|
| `cosine` | so hướng/góc | rất phổ biến cho text embeddings |
| `euclidean` | khoảng cách hình học L2 | khi magnitude/spatial distance có ý nghĩa |
| `dot` | negative dot product theo SQL vector distance semantics | khi model/retrieval design phù hợp dot-product |

> **Metric phải đồng nhất:** Query `VECTOR_SEARCH` chỉ tận dụng ANN index tương thích khi metric của search phù hợp với metric của vector index.

Trong SQL, **distance càng nhỏ càng gần** cho cả ba metric:

| Metric | Khoảng giá trị hiện hành | Ghi chú threshold |
|---|---:|---|
| `cosine` | 0 đến 2 | Không mặc định coi 0.8 là “80% giống”; phải calibrate |
| `euclidean` | 0 đến +∞ | Phụ thuộc scale/magnitude |
| `dot` | -∞ đến +∞ | SQL trả **negative dot product**, nên nhỏ hơn vẫn gần hơn |

Không sao chép một threshold giữa model/version/metric khác nhau. Hãy dùng tập query đã gắn nhãn để đo precision/recall rồi chọn cutoff.

### Tìm kiếm chính xác bằng `VECTOR_DISTANCE`

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

# PHẦN 4 — SO SÁNH TÌM KIẾM CHÍNH XÁC VÀ XẤP XỈ

## 10. Tìm láng giềng gần nhất chính xác (ENN/kNN)

Exact search tính khoảng cách trên toàn bộ candidate set cần xét và cho exact nearest neighbors.

Phù hợp khi:

- dataset/candidate set nhỏ,
- cần deterministic/exact recall,
- filter trước làm candidate set rất nhỏ,
- batch/offline workload chấp nhận latency cao hơn.

Microsoft guidance hiện gợi ý exact search thường phù hợp khi candidate set dưới khoảng **50,000 vectors**; đây là rule-of-thumb, không phải hard exam threshold.

---

## 11. Tìm láng giềng gần nhất xấp xỉ (ANN)

ANN đánh đổi một phần recall để tăng tốc rất mạnh khi vector corpus lớn.

Phù hợp:

- hàng trăm nghìn/hàng triệu vectors,
- interactive search SLA,
- có thể chấp nhận approximate result.

### Loại vector index hiện hành: `DiskANN`

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

> **Quan trọng khi thực hành:** Vector index hiện hành yêu cầu tối thiểu **100 dòng có vector khác `NULL`**. Bảng `SearchDocuments` phía trên chỉ có vài dòng để học tìm kiếm toàn văn, vì vậy chưa thể tạo vector index trên bảng đó. Bài thực hành độc lập ngay dưới đây tạo đủ dữ liệu và minh họa đầy đủ điều kiện này.

### Bài thực hành độc lập: 100 dòng → DiskANN → chọn đúng cú pháp theo phiên bản chỉ mục

```sql
-- Chỉ SQL Server 2025 cần bước này; Azure SQL DB/Fabric không cần.
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

-- Tạo đủ 100 vector mẫu để đáp ứng số lượng tối thiểu mà chỉ mục hiện hành yêu cầu.
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
            CAST((value % 7) * 0.10 AS float),
            CAST((value % 11) * 0.08 AS float),
            CAST((value % 13) * 0.06 AS float),
            CAST(((value * value) % 17) * 0.05 AS float)
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

-- Xác định version trước khi chọn cú pháp query.
SELECT
    i.name,
    JSON_VALUE(v.build_parameters, '$.Version') AS IndexVersion
FROM sys.vector_indexes AS v
JOIN sys.indexes AS i
  ON i.object_id = v.object_id
 AND i.index_id = v.index_id
WHERE v.object_id = OBJECT_ID(N'dbo.VectorIndexDemo');
GO

DECLARE @qv vector(5) = '[0.3,0.3,0.3,0.3,0.3]';

-- PATH A: chỉ chạy khi IndexVersion >= 3
-- (hiện là Azure SQL Database/Fabric sau khi rollout tới region).
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

Nếu `IndexVersion < 3` (điển hình là SQL Server 2025 theo ghi chú current), dùng legacy syntax sau; đây là compatibility syntax, không phải mẫu cho thiết kế v3 mới:

```sql
DECLARE @qv vector(5) = '[0.3,0.3,0.3,0.3,0.3]';

SELECT TOP (5)
    d.Id,
    d.Title,
    r.distance
FROM VECTOR_SEARCH
(
    TABLE = dbo.VectorIndexDemo AS d,
    COLUMN = Embedding,
    SIMILAR_TO = @qv,
    METRIC = 'cosine',
    TOP_N = 5
) AS r
ORDER BY r.distance;
GO
```

> **Bẫy phiên bản:** Dùng `TOP_N` với chỉ mục v3 gây `Msg 42274`; dùng cú pháp v3 trên chỉ mục thế hệ cũ cũng không đúng. Hãy truy vấn `sys.vector_indexes` trước, rồi chọn đúng nhánh lệnh.

> **Bẫy thi:** Với SQL Database Engine hiện hành, `CREATE VECTOR INDEX` chỉ hỗ trợ `TYPE = 'DiskANN'`. HNSW tồn tại trong nhiều vector systems khác nhưng không phải đáp án T-SQL `CREATE VECTOR INDEX` này.

---

# PHẦN 5 — VECTOR INDEX: HÀNH VI HIỆN HÀNH NĂM 2026

## 12. Trạng thái xem trước và phạm vi nền tảng được hỗ trợ

`CREATE VECTOR INDEX` và `VECTOR_SEARCH` là **Preview** trên toàn bộ các platform đang được trang docs liệt kê.

- SQL Server 2025: cần `PREVIEW_FEATURES` để dùng Preview functionality này.
- Azure SQL Database / SQL database in Fabric: availability có thể rollout theo region/index version.
- Vector index v3 mới nhất hiện chỉ có trên Azure SQL Database/SQL database in Fabric và được triển khai dần theo từng khu vực.
- SQL Server 2025 được liệt kê cho Preview function/index nhưng **chưa có v3** theo ghi chú hiện hành.
- Azure SQL Managed Instance không được liệt kê cho `CREATE VECTOR INDEX`/`VECTOR_SEARCH` ở thời điểm rà soát.

```sql
-- SQL Server 2025 khi cần Preview feature
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
GO
```

### So sánh chỉ mục thế hệ cũ với v3

| Hành vi | Vector index thế hệ cũ | Vector index v3 |
|---|---|---|
| Approximate syntax | `TOP_N` bên trong `VECTOR_SEARCH` (deprecated) | `SELECT TOP (N) WITH APPROXIMATE`, không có `TOP_N` |
| Relational predicate | Post-filter; có thể trả ít hơn N | Iterative filtering |
| DML | Table read-only theo mặc định; có thể bật `ALLOW_STALE_VECTOR_INDEX` nếu chấp nhận stale results | Full `INSERT`/`UPDATE`/`DELETE`/`MERGE`, background maintenance |
| Strategy | ANN theo legacy behavior | Optimizer chọn ANN hay exact kNN; có `FORCE_ANN_ONLY` khi cần buộc |
| Migration | Không upgrade in-place | Drop/recreate index; version trong `build_parameters` phải ≥ 3 |

`ALLOW_STALE_VECTOR_INDEX` là tùy chọn tương thích cho index thế hệ cũ; nó **không** biến index thành v3 và không cung cấp lọc lặp. Khi nền tảng đã hỗ trợ v3, kế hoạch đúng là chọn thời gian bảo trì → xóa và tạo lại index → kiểm tra phiên bản và chất lượng.

```sql
-- Chỉ dành cho kiểu chỉ mục cũ khi hệ thống phải ghi dữ liệu và chấp nhận kết quả ANN chưa kịp cập nhật.
ALTER DATABASE SCOPED CONFIGURATION SET ALLOW_STALE_VECTOR_INDEX = ON;
GO
```

---

## 13. Điều kiện và giới hạn quan trọng của vector index hiện hành

Các điểm dễ bị hỏi trong tình huống thi hoặc dễ làm bài thực hành lỗi:

- Bảng gốc cần **clustered primary key** để đáp ứng yêu cầu của vector index hiện hành.
- Cần ít nhất **100 rows có non-NULL vector** trước khi tạo current vector index.
- Vector index hiện không partition được.
- Vector index hiện không được replicate tới subscriber.
- Bảng đang có vector index không `TRUNCATE TABLE` trực tiếp; cần drop index → truncate → reload → recreate.
- Vector indexes không deploy trực tiếp thuận lợi qua DACPAC/BACPAC theo current limitation; thường recreate sau data load/import.
- Thế hệ mới nhất hỗ trợ DML và bảo trì nền; các thế hệ chỉ mục cũ có những giới hạn khác.

### Theo dõi phiên bản và trạng thái chỉ mục

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

Với v3, dùng `sys.dm_db_vector_indexes` để xem background maintenance và staleness:

```sql
SELECT
    OBJECT_SCHEMA_NAME(d.object_id) AS SchemaName,
    OBJECT_NAME(d.object_id) AS TableName,
    i.name AS IndexName,
    d.approximate_staleness_percent,
    d.quantized_keys_used_percent,
    d.last_background_task_time,
    d.last_background_task_succeeded,
    d.last_background_task_duration_seconds,
    d.last_background_task_processed_inserts,
    d.last_background_task_processed_deletes,
    d.last_background_task_error_message
FROM sys.dm_db_vector_indexes AS d
JOIN sys.indexes AS i
  ON i.object_id = d.object_id
 AND i.index_id = d.index_id;
GO
```

Pending DML vẫn có thể xuất hiện trong kết quả search, nhưng ranking có thể chưa tối ưu cho đến khi graph background maintenance bắt kịp. `approximate_staleness_percent` cao hoặc task thất bại là tín hiệu cần điều tra, không phải tự động kết luận index “mất dữ liệu”.

---

# PHẦN 6 — CÚ PHÁP `VECTOR_SEARCH` HIỆN HÀNH

## 14. Tìm kiếm xấp xỉ — cú pháp v3

Với **vector index v3 mới nhất** (hiện có trên Azure SQL Database/Fabric sau khi được triển khai tới khu vực):

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
- `GROUP BY`, aggregate/window/set operations, `DISTINCT`, multiple `ORDER BY` columns và một số `APPLY` patterns cần đặt approximate query ở **subquery** rồi xử lý ở outer query.

### Khi cần chứng minh chỉ mục ANN phải được dùng

Optimizer v3 có thể tự chọn ANN index hoặc exact kNN. `FORCE_ANN_ONLY` chỉ dùng khi bạn chủ ý buộc ANN (ví dụ diagnostic/SLA), và sẽ lỗi nếu không có compatible vector index hoặc không dùng `TOP ... WITH APPROXIMATE`:

```sql
SELECT TOP (10) WITH APPROXIMATE
    d.DocumentId,
    r.distance
FROM VECTOR_SEARCH
(
    TABLE = dbo.SearchDocuments AS d,
    COLUMN = Embedding,
    SIMILAR_TO = @qv,
    METRIC = 'cosine'
) AS r WITH (FORCE_ANN_ONLY)
ORDER BY r.distance;
GO
```

---

## 15. `VECTOR_SEARCH` cũng có thể chạy kNN chính xác

Hành vi hiện hành:

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

Nếu không có ANN index tương thích, engine có thể quét toàn bộ và chạy kNN; truy vấn xấp xỉ có thể cảnh báo hoặc dùng phương án dự phòng tùy hành vi hiện hành.

> **Bẫy thường gặp trong đề:** `VECTOR_SEARCH` không luôn đồng nghĩa với ANN. Trong cú pháp hiện hành, `TOP ... WITH APPROXIMATE` yêu cầu tìm kiếm xấp xỉ; không có `WITH APPROXIMATE` có thể là kNN chính xác.

---

## 16. Lọc lặp trong quá trình tìm kiếm — chỉ có ở v3

Vector index v3 mới nhất hỗ trợ **lọc lặp (iterative filtering)**: điều kiện quan hệ có thể được áp dụng ngay trong quá trình vector search thay vì chỉ lọc sau. Kiểu chỉ mục cũ lấy `TOP_N` vector ứng viên trước rồi mới lọc, nên có thể trả ít hơn N dòng dù vẫn còn dữ liệu phù hợp; khi chưa chuyển đổi, thường phải lấy dư `TOP_N` có kiểm soát.

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

### Cách thiết kế để đạt hiệu năng tốt

Có thể dùng đồng thời:

- Vector index trên `Embedding`.
- B-tree index trên filter columns như `Category`, `TenantId`, `IsPublished`.

```sql
CREATE INDEX IX_SearchDocuments_Category
ON dbo.SearchDocuments(Category);
GO
```

> Cách hình dung quan trọng: **vector index tìm các ứng viên gần nghĩa; B-tree index hỗ trợ lọc dữ liệu có cấu trúc** như tenant, trạng thái hoặc ngày.

---

# PHẦN 7 — TẠO EMBEDDING MẪU

## 17. Điền embedding vào dữ liệu

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

# PHẦN 8 — TÌM KIẾM KẾT HỢP

## 18. Tìm kiếm kết hợp đúng nghĩa

Hybrid search kết hợp:

1. **Lexical rank** từ Full-Text Search (`CONTAINSTABLE`/`FREETEXTTABLE`).
2. **Semantic rank** từ vector search.
3. Fusion/re-ranking, ví dụ **RRF**.

Không nên gọi `LIKE '%keyword%'` + vector là “full hybrid implementation” cho mục tiêu DP-800, vì bạn không khai thác Full-Text ranking.

---

# PHẦN 9 — HỢP NHẤT THỨ HẠNG BẰNG RRF

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

## 20. Bài thực hành tìm kiếm kết hợp và RRF

> Bài thực hành này dùng **xếp hạng vector chính xác** để lệnh dễ hiểu và chạy được ngay cả khi chưa tạo ANN index. Khi tập tài liệu lớn, có thể thay phần lấy ứng viên vector bằng v3 `VECTOR_SEARCH ... WITH APPROXIMATE`, hoặc dùng cú pháp `TOP_N` cũ nếu chỉ mục/nền tảng vẫn ở thế hệ trước.

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

## 21. Dùng ANN v3 để lấy ứng viên vector

Khi đã có **v3 index** và đủ dữ liệu trên Azure SQL Database/Fabric:

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

# PHẦN 10 — ĐÁNH GIÁ CHẤT LƯỢNG VÀ HIỆU NĂNG

## 22. Những yếu tố ảnh hưởng hiệu năng tìm kiếm vector

### A. Số lượng vector cần xét
- Ít → exact có thể đủ.
- Rất nhiều → ANN/index hữu ích.

### B. Số chiều vector
Vector nhiều chiều hơn:
- storage lớn hơn,
- CPU/memory cost cao hơn,
- index/search có thể tốn tài nguyên hơn.

### C. Thước đo khoảng cách
Metric của query cần phù hợp metric của vector index.

### D. Điều kiện lọc có cấu trúc
Ví dụ `TenantId`, `Category`, `Published` nên có relational indexes phù hợp.

### E. Embedding trùng lặp hoặc chất lượng thấp
Nhiều duplicate vectors có thể làm search quality/index usefulness kém.

### F. Embedding chưa được cập nhật
Index nhanh nhưng semantic data cũ vẫn trả kết quả sai về nghĩa.

### G. Đánh đổi giữa tỷ lệ tìm thấy kết quả đúng (recall) và độ trễ
ANN là trade-off: latency tốt hơn nhưng approximate.

---

## 23. Đo lường thay vì phỏng đoán

Bạn nên đo:

- Query latency p50/p95/p99.
- Logical reads/CPU.
- Recall@K nếu so ANN với exact baseline.
- Result quality/relevance.
- Index build/maintenance cost.
- Storage.
- Filter selectivity.

### Kiểm tra chất lượng ANN bằng kết quả chính xác làm mốc

1. Chọn tập query mẫu.
2. Chạy exact top K.
3. Chạy approximate top K.
4. So overlap/recall.
5. Đo latency.

Đây là cách đánh giá đúng bản chất ANN: **speed vs recall/quality**.

### Chẩn đoán nhanh theo lỗi hoặc triệu chứng

| Triệu chứng | Nguyên nhân có khả năng cao | Cách xử lý |
|---|---|---|
| FTS vừa tạo nhưng chưa có result | Population chưa xong, language/word breaker/stoplist không phù hợp | Kiểm tra `FULLTEXTCATALOGPROPERTY`, crawl log, `sys.fulltext_languages` |
| `Msg 42266` khi tạo vector index | Ít hơn 100 non-NULL vectors | Populate đủ dữ liệu rồi tạo lại; dataset nhỏ dùng exact kNN |
| `Msg 42274` | Dùng `TOP_N` với vector index v3 | Bỏ `TOP_N`, dùng `SELECT TOP (N) WITH APPROXIMATE` |
| Tìm kiếm xấp xỉ + filter trả ít hơn N | Index cũ chỉ lọc sau khi lấy ứng viên | Tạo lại thành v3 khi nền tảng hỗ trợ hoặc lấy dư `TOP_N` có kiểm soát |
| ANN index không được chọn | Optimizer chọn exact, thiếu compatible index, metric/column mismatch | Kiểm tra plan, `sys.vector_indexes`; dùng `FORCE_ANN_ONLY` chỉ để buộc/diagnose khi đủ điều kiện |
| Ranking giảm sau nhiều DML | Background graph maintenance đang backlog | Xem `approximate_staleness_percent` và last task/error trong `sys.dm_db_vector_indexes` |
| Dimension/type error | Query vector khác dimension/base type hoặc model version | `VECTORPROPERTY`, model/dimension metadata; embed corpus/query cùng version |
| Hybrid rank bất thường | Cộng raw FTS score với raw vector distance | Rank từng list rồi dùng RRF; đánh giá relevance trên labeled queries |

---

# PHẦN 11 — BẪY THƯỜNG GẶP TRONG ĐỀ

## 24. Bẫy cần nhớ

### Bẫy 1 — `LIKE` = Full-Text Search
Sai. DP-800 yêu cầu Full-Text Search; hãy biết catalog/index và `CONTAINSTABLE`/`FREETEXTTABLE`.

### Bẫy 2 — dùng vector search thay cho việc tra SKU chính xác
Sai. `SKU = ...` thường B-tree/exact filter tốt hơn.

### Bẫy 3 — SQL vector index = HNSW
Sai với current SQL Database Engine syntax. `CREATE VECTOR INDEX` hiện dùng **DiskANN**.

### Bẫy 4 — `VECTOR_DISTANCE` dùng ANN index
Sai. `VECTOR_DISTANCE` là exact distance calculation.

### Bẫy 5 — `VECTOR_SEARCH` hiện hành luôn cần `TOP_N`
Sai. Index thế hệ cũ cần `TOP_N`; v3 dùng `SELECT TOP(N) WITH APPROXIMATE`. Phải kiểm tra phiên bản và nền tảng.

### Bẫy 6 — `WITH APPROXIMATE` nhưng không `ORDER BY distance`
Sai theo yêu cầu cú pháp hiện hành.

### Bẫy 7 — Metric index/search khác nhau
ANN index chỉ hữu ích khi compatible metric/column.

### Bẫy 8 — cộng trực tiếp điểm toàn văn thô với khoảng cách vector thô
Không tốt vì scale/meaning khác nhau. RRF dùng ranks để fusion.

### Bẫy 9 — tìm kiếm kết hợp luôn tốt nhất
Sai. Tăng complexity; chỉ dùng khi lexical + semantic đều tạo giá trị.

### Bẫy 10 — tạo được vector index khi bảng chỉ có 3 dòng
Vector index hiện hành yêu cầu ít nhất 100 vector khác `NULL`.

### Bẫy 11 — Azure SQL Managed Instance có `VECTOR` nên chắc chắn có DiskANN
Sai theo `Applies to` hiện hành. MI có vector type/functions theo policy nhưng không được liệt kê cho `CREATE VECTOR INDEX`/`VECTOR_SEARCH` ở ngày rà soát.

### Bẫy 12 — “semantic search”, “semantic ranker” và HNSW là cùng một tính năng
Sai. Native SQL semantic vector search dùng `VECTOR`/DiskANN. **Azure AI Search semantic ranker** là service khác, rerank top BM25/RRF results và có captions/answers; HNSW trong Azure AI Search cũng không phải `TYPE` của T-SQL `CREATE VECTOR INDEX`. SQL Server Full-Text Semantic Search truyền thống lại là một feature khác nữa.

---

# PHẦN 12 — CÂU HỎI TỰ KIỂM TRA

## Câu 1 — DiskANN
Bạn cần tạo ANN index trên Azure SQL vector column. Current SQL Database Engine hỗ trợ loại nào trong `CREATE VECTOR INDEX`?

- A. HNSW
- B. IVF-PQ
- C. DiskANN
- D. B-tree ANN

**Đáp án: C.**

---

## Câu 2 — Chính xác và xấp xỉ
Corpus có 500 rows và exact correctness quan trọng hơn latency. Chọn giải pháp đơn giản:

- A. Exact kNN bằng `VECTOR_DISTANCE`/exact `VECTOR_SEARCH`.
- B. Bắt buộc DiskANN.
- C. Full-text only.
- D. Graph table.

**Đáp án: A.**

---

## Câu 3 — Cú pháp tìm kiếm xấp xỉ hiện hành
Azure SQL Database đã có vector index v3. Cú pháp phù hợp là:

- A. `VECTOR_SEARCH(... TOP_N=10)` bắt buộc.
- B. `SELECT TOP (10) WITH APPROXIMATE ... FROM VECTOR_SEARCH(...) ORDER BY distance`.
- C. `SELECT APPROXIMATE 10 FROM VECTOR_DISTANCE(...)`.
- D. `CREATE HNSW SEARCH`.

**Đáp án: B.**

---

## Câu 4 — Điểm xếp hạng của tìm kiếm toàn văn
Bạn cần lexical result có relevance ranking để fuse với vector rank. Nên dùng:

- A. `LIKE`
- B. `CONTAINSTABLE`
- C. `CHARINDEX`
- D. `LEN`

**Đáp án: B.** `CONTAINSTABLE` trả `KEY` và `RANK`.

---

## Câu 5 — RRF
Tại sao RRF phù hợp cho hybrid search?

- A. Vì nó encrypt vector.
- B. Vì nó gộp các ranked lists dựa trên vị trí xếp hạng, tránh phụ thuộc raw-score scale khác nhau.
- C. Vì nó tạo full-text index.
- D. Vì nó re-embeds dữ liệu.

**Đáp án: B.**

---

## Câu 6 — Không thống nhất thước đo khoảng cách
Vector index được tạo với cosine, query `VECTOR_SEARCH` yêu cầu euclidean. Điều gì quan trọng nhất?

- A. Index luôn được dùng vì cùng vector column.
- B. ANN index phải compatible với metric; metric mismatch có thể khiến index không được tận dụng như mong muốn.
- C. SQL tự đổi euclidean thành cosine.
- D. Cần đổi vector thành XML.

**Đáp án: B.**

---

## Câu 7 — Điều kiện lọc có cấu trúc kết hợp vector
Bạn search semantic trong 10 triệu products nhưng chỉ category `Electronics`. Thiết kế tốt:

- A. Chỉ vector index, không relational index nào khác.
- B. Vector index trên embedding + B-tree index thích hợp trên filter column, dùng iterative filtering khi current index hỗ trợ.
- C. Full scan toàn bảng rồi filter cuối cùng.
- D. Chuyển category thành vector duy nhất.

**Đáp án: B.**

---

# PHẦN 13 — DANH SÁCH TỰ KIỂM TRA

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
- [ ] Phân biệt platform: MI hiện không có vector index/search trong `Applies to`; SQL Server 2025 cần `PREVIEW_FEATURES`; v3 hiện chỉ Azure SQL DB/Fabric.
- [ ] Nhớ minimum current vector-index rows và key limitations.
- [ ] Viết cú pháp v3 `VECTOR_SEARCH` với `TOP (N) WITH APPROXIMATE` và cú pháp chỉ mục thế hệ trước với `TOP_N`.
- [ ] Biết `TOP_N` là cú pháp cũ dành cho các phiên bản index thế hệ trước.
- [ ] Giải thích iterative filtering.
- [ ] Thiết kế Full-Text + Vector hybrid.
- [ ] Tự viết RRF bằng ranks.
- [ ] Đánh giá vector performance bằng latency + recall/quality.

---

# PHẦN 14 — TÀI LIỆU THAM KHẢO CHÍNH THỨC

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
12. [sys.vector_indexes](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-vector-indexes-transact-sql?view=sql-server-ver17)
13. [sys.dm_db_vector_indexes](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-vector-indexes-transact-sql?view=sql-server-ver17)
14. [Azure AI Search semantic ranker overview — service riêng](https://learn.microsoft.com/en-us/azure/search/semantic-search-overview)
15. [Azure AI Search hybrid search ranking/RRF — service riêng](https://learn.microsoft.com/en-us/azure/search/hybrid-search-ranking)
16. [Microsoft Learn module — Design and implement intelligent search with SQL](https://learn.microsoft.com/en-us/training/modules/design-implement-intelligent-search-with-sql/)

---

## Ghi chú về phiên bản

Vector index/search vẫn là Preview và thay đổi nhanh. Tài liệu này ghi song song v3 và legacy vì **cả hai đều có thể là câu trả lời đúng tùy platform/index version**; không học một cú pháp rồi áp dụng máy móc cho mọi môi trường.
