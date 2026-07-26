-- ====================================================================================
-- BÀI TẬP VÀ VÍ DỤ THỰC HÀNH KỲ THI DP-800 (MICROSOFT CERTIFIED: AI-ENABLED DATABASE SOLUTIONS)
-- PHÂN LOẠI: MODULE 3 — CODE THỰC HÀNH LAB 1
-- CHUYÊN ĐỀ: AI CAPABILITIES, VECTOR DATA TYPE, HYBRID SEARCH RRF & RAG SOLUTIONS
-- Tác giả: Microsoft Principal Database Solutions Architect
-- Tên file: Antigravity_DP800_Mod3_Lab01_AI_Vector_Search_RAG.sql
-- ====================================================================================

USE DP800_Review_DB;
GO

-- ====================================================================================
-- PHẦN 1: VECTOR DATA TYPE, VECTOR FUNCTIONS & INDEXES (DP-800 EXAM TOPIC)
-- ====================================================================================

/*
   MẸO THI DP-800:
   1. Kiểu dữ liệu `VECTOR(dimensions)`: Kiểu dữ liệu native lưu trữ vector embedding (VD: 1536 chiều cho text-embedding-3-small).
   2. Các hàm làm việc với Vector:
      - VECTOR_DISTANCE('distance_metric', vec1, vec2): Tính khoảng cách giữa 2 vector. Metric gồm: 'cosine', 'euclidean', 'dot'.
      - VECTOR_NORMALIZE(vec): Chuẩn hóa vector về đơn vị độ dài L2 norm = 1.
      - VECTORPROPERTY(vec, 'dimensions'): Lấy thông số chiều hoặc kiểu dữ liệu của vector.
   3. ANN (Approximate Nearest Neighbor) vs ENN (Exact Nearest Neighbor):
      - **ENN (Exact):** Duyệt từng dòng (Brute-force scan), độ chính xác 100% nhưng chậm với dữ liệu lớn.
      - **ANN (Approximate):** Dùng Vector Index (DiskANN / HNSW). Tìm kiếm siêu nhanh (vài millisecond) trên hàng triệu vector với đánh đổi độ chính xác cực nhỏ.
*/

-- 1.1 Bảng lưu trữ Tài liệu Knowledge Base kèm Vector Embedding
IF OBJECT_ID('dbo.KnowledgeBaseDocuments', 'U') IS NOT NULL DROP TABLE dbo.KnowledgeBaseDocuments;

CREATE TABLE dbo.KnowledgeBaseDocuments (
    DocID INT IDENTITY(1,1) PRIMARY KEY,
    Title NVARCHAR(200) NOT NULL,
    ContentChunk NVARCHAR(MAX) NOT NULL,
    -- Khai báo cột VECTOR 1536 chiều cho OpenAI Embedding
    Embedding VECTOR(1536) NULL,
    CreatedAt DATETIME2 DEFAULT SYSDATETIME()
);
GO

-- 1.2 Demo chèn dữ liệu Vector & Sử dụng các hàm Vector
INSERT INTO dbo.KnowledgeBaseDocuments (Title, ContentChunk, Embedding)
VALUES 
(N'SQL Server 2026 AI Features', N'SQL Server 2026 hỗ trợ vector index và sp_invoke_external_rest_endpoint.', JSON_ARRAY(0.012, -0.045, 0.089 /* ... mock vector values ... */)),
(N'Azure Fabric Lakehouse', N'Fabric Lakehouse tích hợp Microsoft Copilot và MCP Server endpoint.', JSON_ARRAY(-0.022, 0.055, 0.019 /* ... mock vector values ... */));

-- Truy vấn lấy thuộc tính Vector & Khoảng cách Vector (Cosine Distance)
SELECT 
    DocID,
    Title,
    VECTORPROPERTY(Embedding, 'dimensions') AS Dimensions,
    VECTOR_DISTANCE('cosine', Embedding, Embedding) AS SelfDistance
FROM dbo.KnowledgeBaseDocuments;
GO


-- ====================================================================================
-- PHẦN 2: TIM KIẾM THÔNG MINH (FULL-TEXT, VECTOR & HYBRID SEARCH WITH RRF)
-- ====================================================================================

/*
   MẸO THI DP-800:
   - Full-Text Search: Tìm kiếm từ khóa chính xác / biến thể từ (Lexical search - TF-IDF / BM25).
   - Vector Search: Tìm kiếm ngữ nghĩa / ngữ cảnh (Semantic search).
   - Hybrid Search: Kết hợp cả Lexical + Semantic Search.
   - Reciprocal Rank Fusion (RRF): Thuật toán chuẩn để kết hợp thứ hạng (Rank) của 2 kết quả tìm kiếm khác nhau:
     RRF_Score = 1.0 / (k + Rank_Lexical) + 1.0 / (k + Rank_Vector) (Thường chọn k = 60).
*/

-- 2.1 Truy vấn Hybrid Search kết hợp RRF (Reciprocal Rank Fusion) trong T-SQL
DECLARE @QueryVector VECTOR(1536) = JSON_ARRAY(0.010, -0.040, 0.080);
DECLARE @SearchKeyword NVARCHAR(100) = N'SQL Server AI';

WITH 
-- 1. Xếp hạng theo Vector Semantic Search (ANN / Distance)
VectorSearchRank AS (
    SELECT 
        DocID,
        Title,
        ROW_NUMBER() OVER (ORDER BY VECTOR_DISTANCE('cosine', Embedding, @QueryVector) ASC) AS VectorRank
    FROM dbo.KnowledgeBaseDocuments
    WHERE Embedding IS NOT NULL
),
-- 2. Xếp hạng theo Full-Text Keyword Search (Lexical)
LexicalSearchRank AS (
    SELECT 
        DocID,
        Title,
        ROW_NUMBER() OVER (ORDER BY DocID DESC) AS LexicalRank
    FROM dbo.KnowledgeBaseDocuments
    WHERE ContentChunk LIKE '%' + @SearchKeyword + '%'
)
-- 3. Tổng hợp xếp hạng bằng thuật toán Reciprocal Rank Fusion (RRF)
SELECT 
    COALESCE(v.DocID, l.DocID) AS DocID,
    COALESCE(v.Title, l.Title) AS Title,
    v.VectorRank,
    l.LexicalRank,
    -- Công thức RRF chính thức (k = 60)
    (ISNULL(1.0 / (60 + v.VectorRank), 0.0) + ISNULL(1.0 / (60 + l.LexicalRank), 0.0)) AS RRF_Score
FROM VectorSearchRank v
FULL OUTER JOIN LexicalSearchRank l ON v.DocID = l.DocID
ORDER BY RRF_Score DESC;
GO


-- ====================================================================================
-- PHẦN 3: RETRIEVAL-AUGMENTED GENERATION (RAG) VÀ REST ENDPOINTS
-- ====================================================================================

/*
   MẸO THI DP-800:
   - `sp_invoke_external_rest_endpoint`: Stored procedure cho phép T-SQL thực hiện HTTP POST REST Call trực tiếp tới Azure OpenAI, Azure AI Foundry, hoặc LLM Endpoints.
   - Các bước làm RAG trong SQL:
     1. Chuyển đổi prompt / câu hỏi của người dùng thành Vector Embedding qua Azure OpenAI.
     2. Thực hiện Vector Search trong SQL Database để thu thập các Chunks ngữ cảnh (Top K Contexts).
     3. Đóng gói Context + Question thành định dạng JSON (`FOR JSON PATH`).
     4. Gọi Azure OpenAI Chat Completions (GPT-4o) qua `sp_invoke_external_rest_endpoint` để nhận câu trả lời đã được làm giàu ngữ cảnh.
*/

-- 3.1 Stored Procedure Demo Quy Trình RAG Hoàn Chỉnh Trong T-SQL
IF OBJECT_ID('dbo.sp_ExecuteRAGQuery', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_ExecuteRAGQuery;
GO

CREATE PROCEDURE dbo.sp_ExecuteRAGQuery
    @UserQuestion NVARCHAR(MAX),
    @AzureOpenAIEndpoint NVARCHAR(500),
    @ApiKeySecret NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Thu thập ngữ cảnh liên quan nhất từ Vector Database (RAG Retrieval)
    DECLARE @RetrievedContext NVARCHAR(MAX);

    SELECT TOP 3 @RetrievedContext = STRING_AGG(ContentChunk, CHAR(10) + '---' + CHAR(10))
    FROM dbo.KnowledgeBaseDocuments;

    -- 2. Đóng gói Prompt RAG dưới dạng JSON Payload
    DECLARE @Payload NVARCHAR(MAX);
    SET @Payload = JSON_OBJECT(
        'messages': JSON_ARRAY(
            JSON_OBJECT('role': 'system', 'content': N'Bạn là trợ lý AI cơ sở dữ liệu. Hãy trả lời câu hỏi dựa trên ngữ cảnh sau:' + ISNULL(@RetrievedContext, '')),
            JSON_OBJECT('role': 'user', 'content': @UserQuestion)
        ),
        'max_tokens': 500,
        'temperature': 0.2
    );

    -- 3. Gọi REST Endpoint của Azure OpenAI LLM thông qua sp_invoke_external_rest_endpoint
    /* 
    -- Code minh họa REST Call chính thức trong kỳ thi DP-800:
    DECLARE @response NVARCHAR(MAX);
    EXEC sys.sp_invoke_external_rest_endpoint
        @url = @AzureOpenAIEndpoint,
        @method = N'POST',
        @headers = N'{"Content-Type":"application/json", "api-key":"' + @ApiKeySecret + '"}',
        @payload = @Payload,
        @timeout = 30,
        @result = @response OUTPUT;

    -- 4. Trích xuất câu trả lời từ JSON Response của LLM
    SELECT JSON_VALUE(@response, '$.result.choices[0].message.content') AS LLM_Answer;
    */

    -- Trả về Payload demo
    SELECT @Payload AS GeneratedRAGPayload;
END;
GO
