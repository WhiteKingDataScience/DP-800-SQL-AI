# DP-800 Domain 3: Design and Implement Intelligent Search

> **Miền 3:** Implement AI Capabilities in Database Solutions (25–30%)  
> **Chủ đề:** Design and Implement Intelligent Search  
> **Trọng tâm thi:** Vector Search (`VECTOR_DISTANCE`, `VECTOR_SEARCH`), Full-text vs Vector vs Hybrid Search, ANN vs ENN, Reciprocal Rank Fusion (RRF).

---

## 📘 PHẦN 1: LÝ THUYẾT & KIẾN THỨC CỐT LÕI (CORE THEORY)

### 1. Phân Biệt Các Loại Tìm Kiếm (Full-Text vs Vector vs Hybrid Search)

| Loại tìm kiếm | Cách thức hoạt động | Ưu điểm & Trường hợp sử dụng tối ưu |
|---|---|---|
| **Full-Text Search** | Tìm kiếm dựa trên Từ khóa chính xác (Lexical Keyword Matching), Stemming, Synonyms. | Tối ưu khi tìm kiếm **Mã sản phẩm, Tên thương hiệu, Thuật ngữ chuyên ngành, Số hóa đơn**. |
| **Vector Search (Semantic Search)** | Tìm kiếm dựa trên Ý nghĩa Ngữ nghĩa (Semantic Similarity) giữa các Vector. | Tối ưu khi người dùng hỏi bằng **câu hỏi tự nhiên, cách diễn đạt khác, hoặc tìm ý tưởng tương đồng**. |
| **Hybrid Search** | Kết hợp cả Full-Text Search + Vector Search trong một truy vấn duy nhất. | **Tối ưu nhất cho mọi ứng dụng thực tế** (Vừa không bỏ sót từ khóa chính xác, vừa hiểu ngữ nghĩa). |

### 2. Các Hàm & Kiểu Dữ Liệu Vector Native
- **Kiểu dữ liệu `VECTOR(n)`:** Lưu trữ mảng số thực float32 với kích thước $n$ chiều.
- **Hàm `VECTOR_DISTANCE(metric, vector1, vector2)`:**  
  Đo khoảng cách giữa 2 Vector. Các metric phổ biến:
  - `'cosine'`: Đo góc giữa 2 vector. Metric tiêu chuẩn cho so sánh ngữ nghĩa văn bản (Giá trị càng gần 0 ➔ Càng giống nhau).
  - `'euclidean'`: Đo khoảng cách hình học tuyệt đối.
  - `'dot'`: Tích vô hướng (Dot Product).
- **Hàm `VECTOR_NORMALIZE(vector)`:** Chuẩn hóa vector về độ dài bằng 1.
- **Hàm `VECTORPROPERTY(vector, property)`:** Lấy thuộc tính của vector (như số chiều).

### 3. ENN vs ANN (Exact vs Approximate Nearest Neighbor)
- **ENN (Exact Nearest Neighbor):** Duyệt qua toàn bộ vector trong bảng để tính khoảng cách (Brute-force scan). Độ chính xác 100% nhưng chậm đối với bảng lớn.
- **ANN (Approximate Nearest Neighbor):** Sử dụng **Vector Index** (như HNSW - Hierarchical Navigable Small World) để tìm kiếm lân cận gần đúng. Cho tốc độ phản hồi cực nhanh (vài ms) với tập dữ liệu hàng triệu vector.

### 4. Hybrid Search & Thuật Toán Reciprocal Rank Fusion (RRF)
Khi thực hiện Hybrid Search, ta thu được 2 danh sách kết quả xếp hạng độc lập: Danh sách A (từ Full-Text Search) và Danh sách B (từ Vector Search). Để gộp 2 danh sách này thành một điểm số duy nhất, ta dùng thuật toán **Reciprocal Rank Fusion (RRF)**.

- **Công thức RRF:**
  $$RRF\_Score(d) = \sum_{m \in M} \frac{1}{k + r_m(d)}$$
  *(Trong đó $k$ thường chọn là 60, $r_m(d)$ là thứ hạng của tài liệu $d$ trong danh sách $m$).*

---

## 💻 PHẦN 2: THỰC HÀNH T-SQL (HANDS-ON LABS)

```sql
-- ============================================================================
-- LAB 9.1: VECTOR DISTANCE (EXACT KNN SEARCH)
-- ============================================================================
USE tempdb;
GO

-- 1. Tìm Top 3 Chunk có ý nghĩa gần nhất với Query Vector
DECLARE @QueryVector VECTOR(1536) = (SELECT Embedding FROM dbo.DocumentChunks WHERE ChunkId = 1);

SELECT TOP (3)
    ChunkId,
    ChunkText,
    -- Tính khoảng cách Cosine Distance
    VECTOR_DISTANCE('cosine', Embedding, @QueryVector) AS CosineDist
FROM dbo.DocumentChunks
WHERE Embedding IS NOT NULL
ORDER BY CosineDist ASC;
GO

-- ============================================================================
-- LAB 9.2: HYBRID SEARCH + RECIPROCAL RANK FUSION (RRF) RE-RANKING
-- ============================================================================
CREATE PROCEDURE dbo.sp_HybridSearchRRF
    @SearchKeyword NVARCHAR(100),
    @QueryVector VECTOR(1536),
    @TopK INT = 5
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Full-Text Search Ranking (Rank List 1)
    WITH FullTextResults AS (
        SELECT ChunkId, ROW_NUMBER() OVER (ORDER BY ChunkId DESC) AS FTRank
        FROM dbo.DocumentChunks
        WHERE ChunkText LIKE '%' + @SearchKeyword + '%'
    ),
    -- 2. Vector Search Ranking (Rank List 2)
    VectorResults AS (
        SELECT TOP 20 ChunkId, ROW_NUMBER() OVER (ORDER BY VECTOR_DISTANCE('cosine', Embedding, @QueryVector) ASC) AS VectorRank
        FROM dbo.DocumentChunks
        WHERE Embedding IS NOT NULL
    )
    -- 3. Gộp & Xếp hạng lại bằng thuật toán RRF (k = 60)
    SELECT TOP (@TopK)
        c.ChunkId,
        c.ChunkText,
        ISNULL(ft.FTRank, 999) AS FTRank,
        ISNULL(v.VectorRank, 999) AS VectorRank,
        -- Tính RRF Score
        (ISNULL(1.0 / (60 + ft.FTRank), 0.0) + ISNULL(1.0 / (60 + v.VectorRank), 0.0)) AS RRFScore
    FROM dbo.DocumentChunks c
    LEFT JOIN FullTextResults ft ON c.ChunkId = ft.ChunkId
    LEFT JOIN VectorResults v ON c.ChunkId = v.ChunkId
    WHERE ft.ChunkId IS NOT NULL OR v.ChunkId IS NOT NULL
    ORDER BY RRFScore DESC;
END;
GO
```

---

## 📝 PHẦN 3: CÂU HỎI THI THỬ & TÌNH HUỐNG (MOCK TEST QUESTIONS)

#### Question 1 (Search Strategy Selection Scenario):
**Scenario:** You are building a search feature for a medical database. Doctors need to search for patients using exact medical codes (e.g., 'ICD-10-CM E11.9') as well as natural language symptoms (e.g., 'patient feels thirsty and frequent urination'). Which search architecture provides the highest accuracy for both query types?
- A. Pure Full-Text Search only.
- B. Pure Vector Semantic Search only.
- C. Hybrid Search combining Full-Text Search and Vector Search with Reciprocal Rank Fusion (RRF).
- D. B-tree Clustered Index Scan.

**👉 Correct Answer: C**  
*Explanation (Giải thích):* Khi ứng dụng vừa có nhu cầu tìm kiếm **từ khóa chính xác/mã chuyên ngành** (Medical Codes) vừa có nhu cầu tìm theo **câu hỏi tự nhiên/ngữ nghĩa** (Symptoms), kiến trúc tối ưu nhất là **Hybrid Search** kết hợp Full-Text Search và Vector Search sử dụng thuật toán xếp hạng **RRF**.

---

#### Question 2 (ANN vs ENN Vector Search Scenario):
**Scenario:** Your database contains 50 million vector embeddings of product images. Users perform real-time visual similarity searches from a mobile app. The search response time SLA must be under 50 milliseconds. Which vector search method should you implement?
- A. Exact Nearest Neighbor (ENN) without a vector index.
- B. Approximate Nearest Neighbor (ANN) using a Vector Index (such as HNSW).
- C. Full table scan with `LIKE '%[0-9]%'`.
- D. Cursor-based loop calculating Cosine Distance.

**👉 Correct Answer: B**  
*Explanation (Giải thích):* Với tập dữ liệu 50 triệu vector và SLA phản hồi dưới 50ms, phương pháp duy nhất đáp ứng hiệu năng là **Approximate Nearest Neighbor (ANN)** dựa trên **Vector Index** (như HNSW). ENN sẽ thực hiện brute-force scan toàn bộ 50 triệu dòng và thất bại về mặt thời gian.

---

#### Question 3 (Vector Distance Metric Scenario):
**Scenario:** You are writing a T-SQL query to calculate the semantic similarity between a user's question vector `@UserVector` and document chunk vectors stored in column `Embedding`. You want a distance metric that evaluates the angle between vectors regardless of magnitude. Which T-SQL function call is correct?
- A. `VECTOR_DISTANCE('euclidean', Embedding, @UserVector)`
- B. `VECTOR_DISTANCE('cosine', Embedding, @UserVector)`
- C. `VECTOR_DISTANCE('dot', Embedding, @UserVector)`
- D. `EDIT_DISTANCE(Embedding, @UserVector)`

**👉 Correct Answer: B**  
*Explanation (Giải thích):* Hàm `VECTOR_DISTANCE('cosine', ...)` đo độ tương đồng Cosine (góc giữa 2 vector), là metric tiêu chuẩn được sử dụng rộng rãi nhất trong tìm kiếm ngữ nghĩa văn bản (semantic text search).
