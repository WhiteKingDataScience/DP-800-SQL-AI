/*═══════════════════════════════════════════════════════════════════════════════
  DP-800 | MIỀN 3 | LAB 02 — GỌI DỊCH VỤ AI TỪ SQL
  Đi kèm: Claude_DP800_D3_AI_Guide.md  (mục 4)

  SECTION 1..4 — sp_invoke_external_rest_endpoint (thủ tục QUAN TRỌNG NHẤT miền 3)
  SECTION 5..7 — CREATE EXTERNAL MODEL, AI_GENERATE_EMBEDDINGS, AI_GENERATE_CHUNKS
  SECTION 8..9 — Bảo mật, chi phí, xử lý lỗi, mẫu triển khai theo lô

  ⚠ sp_invoke_external_rest_endpoint CÓ TRÊN: Azure SQL Database, Azure SQL Managed
    Instance, SQL Server 2025. KHÔNG có trên SQL Server ≤ 2022.
    Lab tự phát hiện phiên bản: chỗ nào không chạy được thì MÔ PHỎNG lại cấu trúc
    JSON trả về để bạn luyện đúng phần xử lý kết quả — phần đề thi hay hỏi nhất.
═══════════════════════════════════════════════════════════════════════════════*/

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
IF DB_ID('DP800_AI') IS NULL CREATE DATABASE DP800_AI;
GO
USE DP800_AI;
GO
SELECT  CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) AS MajorVer,
        SERVERPROPERTY('EngineEdition')                    AS EngineEdition,
        CASE WHEN OBJECT_ID('sys.sp_invoke_external_rest_endpoint') IS NOT NULL
             THEN 'CÓ sp_invoke_external_rest_endpoint'
             ELSE 'KHÔNG có — dùng phần MÔ PHỎNG' END      AS RestEndpointSupport;
GO
/*  EngineEdition: 3 = Enterprise/Developer (on-prem) | 5 = Azure SQL Database
                   8 = Azure SQL Managed Instance                                */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 1 — CHUẨN BỊ: BẬT TÍNH NĂNG & TẠO CREDENTIAL
───────────────────────────────────────────────────────────────────────────────*/
/*
 -- BƯỚC 1: bật tính năng (Azure SQL Database)
 EXEC sp_configure 'external rest endpoint enabled', 1;
 RECONFIGURE WITH OVERRIDE;

 -- BƯỚC 2: master key của database (nếu chưa có)
 CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Str0ng!Pass#2026';

 -- BƯỚC 3: credential — ⚠ TÊN CREDENTIAL PHẢI TRÙNG URL GỐC CỦA ENDPOINT
 --   (đây là chi tiết SAI NHIỀU NHẤT khi triển khai và cũng hay ra đề)

 -- Cách A: khoá API trong header (đơn giản, kém an toàn nhất)
 CREATE DATABASE SCOPED CREDENTIAL [https://myres.openai.azure.com]
 WITH IDENTITY = 'HTTPEndpointHeaders',
      SECRET   = '{"api-key":"<YOUR_KEY>"}';

 -- Cách B: MANAGED IDENTITY — 🎯 KHUYẾN NGHỊ, không lưu khoá ở đâu cả
 CREATE DATABASE SCOPED CREDENTIAL [https://myres.openai.azure.com]
 WITH IDENTITY = 'Managed Identity',
      SECRET   = '{"resourceid":"https://cognitiveservices.azure.com"}';
 --   Cần: bật system-assigned managed identity cho SQL server, rồi cấp vai trò
 --        "Cognitive Services OpenAI User" cho identity đó trên tài nguyên OpenAI.

 -- BƯỚC 4: quyền cho người dùng
 GRANT EXECUTE ANY EXTERNAL ENDPOINT TO AppUser;

 -- BƯỚC 5: firewall của endpoint phải cho phép truy cập từ dịch vụ Azure SQL.
*/


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 2 — CÚ PHÁP ĐẦY ĐỦ CỦA sp_invoke_external_rest_endpoint
───────────────────────────────────────────────────────────────────────────────*/
/*
 DECLARE @response NVARCHAR(MAX), @ret INT;

 EXEC @ret = sys.sp_invoke_external_rest_endpoint
      @url        = N'https://myres.openai.azure.com/openai/deployments/emb/embeddings?api-version=2024-02-01',
      @method     = N'POST',                    -- GET | POST | PUT | PATCH | DELETE | HEAD
      @headers    = N'{"Content-Type":"application/json"}',
      @payload    = N'{"input":"nội dung cần nhúng"}',
      @timeout    = 30,                         -- giây, hợp lệ 1..230 (mặc định 30)
      @credential = [https://myres.openai.azure.com],
      @response   = @response OUTPUT;

 SELECT @ret AS ReturnCode, @response AS RawJson;

 ┌──────────────┬────────────────────────────────────────────────────────────────┐
 │ Tham số      │ Ghi nhớ                                                        │
 ├──────────────┼────────────────────────────────────────────────────────────────┤
 │ @url         │ CHỈ HTTPS. HTTP bị từ chối thẳng.                              │
 │ @method      │ Mặc định POST.                                                 │
 │ @headers     │ JSON. KHÔNG đặt khoá ở đây nếu đã dùng credential.             │
 │ @payload     │ JSON body. Với GET thì bỏ trống.                               │
 │ @timeout     │ 1..230 giây. Quá 230 ⇒ lỗi.                                    │
 │ @credential  │ Database scoped credential, TÊN = URL gốc.                     │
 │ @response    │ OUTPUT, NVARCHAR(MAX), chứa JSON kết quả.                      │
 │ Giá trị trả  │ @ret = 0 là thành công; khác 0 ⇒ đọc nhánh $.error.            │
 └──────────────┴────────────────────────────────────────────────────────────────┘
*/


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 3 — [MÔ PHỎNG] CẤU TRÚC JSON TRẢ VỀ & CÁCH BÓC TÁCH
───────────────────────────────────────────────────────────────────────────────*/
/*  Đây là phần đề thi hỏi nhiều nhất: @response LUÔN có 3 nhánh gốc
      $.response  — mã trạng thái HTTP + headers
      $.result    — BODY thật của API (thứ bạn cần)
      $.error     — chỉ xuất hiện khi lỗi                                        */

DECLARE @response NVARCHAR(MAX) = N'
{
  "response": {
    "status": { "http": { "code": 200, "description": "OK" } },
    "headers": { "Content-Type": "application/json", "x-ratelimit-remaining-requests": "119" }
  },
  "result": {
    "object": "list",
    "data": [
      { "object": "embedding", "index": 0,
        "embedding": [0.0021, -0.0144, 0.0087, 0.0312, -0.0056, 0.0198, -0.0231, 0.0075] }
    ],
    "model": "text-embedding-3-small",
    "usage": { "prompt_tokens": 8, "total_tokens": 8 }
  }
}';

-- (a) Kiểm tra trạng thái HTTP TRƯỚC khi dùng kết quả
SELECT  JSON_VALUE(@response, '$.response.status.http.code')        AS HttpCode,
        JSON_VALUE(@response, '$.response.status.http.description') AS HttpDesc,
        JSON_VALUE(@response, '$.result.model')                     AS ModelUsed,
        JSON_VALUE(@response, '$.result.usage.total_tokens')        AS TokensUsed;

-- (b) Lấy vector embedding (JSON_QUERY vì đây là MẢNG, không phải scalar)
DECLARE @embedding NVARCHAR(MAX) = JSON_QUERY(@response, '$.result.data[0].embedding');
SELECT @embedding AS EmbeddingJson;

-- (c) Bung mảng ra để kiểm tra số chiều — bước xác thực rất nên làm
SELECT  COUNT(*)                       AS Dimensions,
        MIN(CAST([value] AS FLOAT))    AS MinVal,
        MAX(CAST([value] AS FLOAT))    AS MaxVal
FROM    OPENJSON(@embedding);
GO
/*  ⚠ JSON_VALUE cho SCALAR, JSON_QUERY cho MẢNG/OBJECT.
    Dùng JSON_VALUE lên mảng embedding ⇒ trả NULL (lax mode) — lỗi kinh điển.

    TRÊN SQL 2025 thì lưu thẳng:
      INSERT dbo.DocChunk (Content, Embedding)
      VALUES (@text, CAST(@embedding AS VECTOR(1536)));                          */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 4 — XỬ LÝ LỖI: MẪU TRIỂN KHAI THẬT
───────────────────────────────────────────────────────────────────────────────*/
-- Mô phỏng phản hồi LỖI
DECLARE @errResponse NVARCHAR(MAX) = N'
{
  "response": { "status": { "http": { "code": 429, "description": "Too Many Requests" } },
                "headers": { "retry-after": "12" } },
  "error": { "message": "Rate limit exceeded. Retry after 12 seconds.", "code": "429" }
}';

SELECT  JSON_VALUE(@errResponse, '$.response.status.http.code')  AS HttpCode,
        JSON_VALUE(@errResponse, '$.error.code')                AS ErrorCode,
        JSON_VALUE(@errResponse, '$.error.message')             AS ErrorMessage,
        JSON_VALUE(@errResponse, '$.response.headers."retry-after"') AS RetryAfterSec;
GO

-- Thủ tục bao bọc chuẩn: có retry, có ghi log, có kiểm tra mã HTTP
CREATE TABLE dbo.AiCallLog
(
    LogId      INT IDENTITY PRIMARY KEY,
    CalledAt   DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    Url        NVARCHAR(400) NOT NULL,
    HttpCode   INT           NULL,
    Attempt    INT           NOT NULL,
    DurationMs INT           NULL,
    TokensUsed INT           NULL,
    ErrorMsg   NVARCHAR(MAX) NULL
);
GO
CREATE OR ALTER PROCEDURE dbo.usp_CallAiEndpoint
    @Url        NVARCHAR(400),
    @Payload    NVARCHAR(MAX),
    @MaxRetries INT = 3,
    @Response   NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @attempt INT = 1, @ret INT = -1, @httpCode INT = NULL,
            @t0 DATETIME2(3), @backoff CHAR(12);

    WHILE @attempt <= @MaxRetries
    BEGIN
        SET @t0 = SYSUTCDATETIME();
        BEGIN TRY
            IF OBJECT_ID('sys.sp_invoke_external_rest_endpoint') IS NOT NULL
            BEGIN
                -- Gọi thật (Azure SQL / SQL Server 2025)
                DECLARE @sql NVARCHAR(MAX) = N'
                    EXEC @r = sys.sp_invoke_external_rest_endpoint
                         @url = @u, @method = N''POST'',
                         @payload = @p, @timeout = 30,
                         @response = @resp OUTPUT;';
                EXEC sys.sp_executesql @sql,
                     N'@u NVARCHAR(400), @p NVARCHAR(MAX), @r INT OUTPUT, @resp NVARCHAR(MAX) OUTPUT',
                     @u = @Url, @p = @Payload, @r = @ret OUTPUT, @resp = @Response OUTPUT;
            END
            ELSE
            BEGIN
                -- Mô phỏng: lần 1 gặp 429, lần 2 thành công (để thấy retry hoạt động)
                SET @Response = CASE WHEN @attempt = 1
                    THEN N'{"response":{"status":{"http":{"code":429}}},"error":{"message":"Rate limit"}}'
                    ELSE N'{"response":{"status":{"http":{"code":200}}},"result":{"data":[{"embedding":[0.1,0.2,0.3]}],"usage":{"total_tokens":8}}}'
                END;
                SET @ret = CASE WHEN @attempt = 1 THEN 1 ELSE 0 END;
            END;

            SET @httpCode = TRY_CAST(JSON_VALUE(@Response, '$.response.status.http.code') AS INT);

            INSERT dbo.AiCallLog (Url, HttpCode, Attempt, DurationMs, TokensUsed, ErrorMsg)
            VALUES (@Url, @httpCode, @attempt,
                    DATEDIFF(MILLISECOND, @t0, SYSUTCDATETIME()),
                    TRY_CAST(JSON_VALUE(@Response, '$.result.usage.total_tokens') AS INT),
                    JSON_VALUE(@Response, '$.error.message'));

            -- Thành công
            IF @ret = 0 AND @httpCode BETWEEN 200 AND 299 RETURN 0;

            -- 4xx (trừ 429) là lỗi của phía mình ⇒ retry vô ích
            IF @httpCode BETWEEN 400 AND 499 AND @httpCode <> 429
            BEGIN
                RAISERROR(N'Lỗi client %d — không retry.', 16, 1, @httpCode);
                RETURN 1;
            END;

            -- 429 / 5xx ⇒ exponential backoff rồi thử lại
            SET @backoff = CONVERT(CHAR(12), DATEADD(SECOND, POWER(2, @attempt), CAST('00:00:00' AS TIME)), 114);
            WAITFOR DELAY @backoff;
        END TRY
        BEGIN CATCH
            INSERT dbo.AiCallLog (Url, HttpCode, Attempt, ErrorMsg)
            VALUES (@Url, NULL, @attempt, ERROR_MESSAGE());
        END CATCH;

        SET @attempt += 1;
    END;

    RAISERROR(N'Gọi endpoint thất bại sau %d lần thử.', 16, 1, @MaxRetries);
    RETURN 1;
END;
GO

DECLARE @resp NVARCHAR(MAX), @rc INT;
EXEC @rc = dbo.usp_CallAiEndpoint
     @Url = N'https://myres.openai.azure.com/openai/deployments/emb/embeddings',
     @Payload = N'{"input":"thử nghiệm"}',
     @Response = @resp OUTPUT;
SELECT @rc AS ReturnCode, @resp AS Response;
SELECT LogId, HttpCode, Attempt, DurationMs, TokensUsed, ErrorMsg FROM dbo.AiCallLog ORDER BY LogId;
GO
/*  🎯 MẪU XỬ LÝ LỖI CẦN NHỚ:
      200–299 → thành công
      401/403 → sai khoá / thiếu quyền / firewall chặn   ⇒ KHÔNG retry
      404     → sai URL hoặc sai tên deployment          ⇒ KHÔNG retry
      408     → timeout                                   ⇒ retry
      429     → vượt hạn mức (rate limit)                 ⇒ retry có backoff,
                                                            đọc header retry-after
      5xx     → lỗi phía dịch vụ                          ⇒ retry có backoff

    ⚠⚠ CẢNH BÁO QUAN TRỌNG NHẤT:
      sp_invoke_external_rest_endpoint là lời gọi ĐỒNG BỘ. Transaction sẽ GIỮ KHOÁ
      suốt thời gian chờ mạng (tới 230 giây!).
      ⇒ TUYỆT ĐỐI KHÔNG gọi trong TRIGGER hoặc trong transaction dài.
      ⇒ Với khối lượng lớn: xử lý theo LÔ ngoài giờ cao điểm, hoặc đẩy sang tầng
        ứng dụng / Azure Function / Data Factory.                                */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 5 — CREATE EXTERNAL MODEL (SQL 2025 / Azure SQL) — cách hiện đại
───────────────────────────────────────────────────────────────────────────────*/
/*
 -- MODEL EMBEDDINGS
 CREATE EXTERNAL MODEL MyEmbedder
 WITH (
     LOCATION   = 'https://myres.openai.azure.com/openai/deployments/emb/embeddings?api-version=2024-02-01',
     API_FORMAT = 'Azure OpenAI',          -- 'Azure OpenAI' | 'OpenAI' | 'Ollama'
     MODEL_TYPE = EMBEDDINGS,              -- EMBEDDINGS | CHAT_COMPLETIONS
     MODEL      = 'text-embedding-3-small',
     CREDENTIAL = [https://myres.openai.azure.com]
 );

 -- MODEL CHAT
 CREATE EXTERNAL MODEL MyChatModel
 WITH (
     LOCATION   = 'https://myres.openai.azure.com/openai/deployments/gpt4o/chat/completions?api-version=2024-02-01',
     API_FORMAT = 'Azure OpenAI',
     MODEL_TYPE = CHAT_COMPLETIONS,
     MODEL      = 'gpt-4o',
     CREDENTIAL = [https://myres.openai.azure.com]
 );

 -- MODEL CỤC BỘ qua Ollama (không gửi dữ liệu ra ngoài — hợp yêu cầu bảo mật cao)
 CREATE EXTERNAL MODEL LocalEmbedder
 WITH (
     LOCATION   = 'http://localhost:11434/api/embeddings',
     API_FORMAT = 'Ollama',
     MODEL_TYPE = EMBEDDINGS,
     MODEL      = 'nomic-embed-text'
 );

 -- SỬ DỤNG
 SELECT AI_GENERATE_EMBEDDINGS(N'chính sách hoàn tiền' USE MODEL MyEmbedder);

 INSERT dbo.DocChunk (DocId, Content, Embedding)
 SELECT DocId, Content, AI_GENERATE_EMBEDDINGS(Content USE MODEL MyEmbedder)
 FROM   dbo.StagingDoc;

 SELECT AI_GENERATE_CHAT(N'Tóm tắt đoạn sau: ' + @text USE MODEL MyChatModel);

 -- QUẢN LÝ
 SELECT * FROM sys.external_models;
 GRANT EXECUTE ANY EXTERNAL MODEL TO AppUser;
 ALTER EXTERNAL MODEL MyEmbedder SET (MODEL = 'text-embedding-3-large');
 DROP  EXTERNAL MODEL MyEmbedder;

 🎯 SO SÁNH HAI CÁCH GỌI (đề hay hỏi "nên dùng cái nào"):
    CREATE EXTERNAL MODEL + AI_GENERATE_EMBEDDINGS
      ✅ Khai báo một lần, dùng lại; cú pháp gọn; tích hợp trực tiếp vào SELECT/INSERT
      ✅ Engine tự dựng payload và bóc kết quả — ít lỗi thủ công
      ❌ Chỉ hỗ trợ các API_FORMAT đã biết; cần SQL 2025 / Azure SQL
    sp_invoke_external_rest_endpoint
      ✅ Gọi được BẤT KỲ REST API nào (không riêng AI): dịch thuật, kiểm tra địa chỉ,
         Azure AI Search, Logic Apps, webhook...
      ❌ Phải tự dựng JSON payload và tự bóc kết quả
    ⇒ Có sẵn external model thì dùng external model; cần linh hoạt thì dùng REST.  */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 6 — AI_GENERATE_CHUNKS (SQL 2025) & CÁCH TỰ CẮT TRÊN BẢN CŨ
───────────────────────────────────────────────────────────────────────────────*/
/*  [CÚ PHÁP 2025]
      SELECT c.chunk_ordinal, c.chunk
      FROM   dbo.Document d
      CROSS APPLY AI_GENERATE_CHUNKS(
              source     = d.Content,
              chunk_type = N'FIXED',      -- FIXED | (các kiểu khác tuỳ bản)
              chunk_size = 400,           -- ký tự
              overlap    = 50) AS c;                                             */

-- [MÔ PHỎNG] tự cắt bằng T-SQL — chạy được trên mọi phiên bản
CREATE OR ALTER FUNCTION dbo.fnChunkText
(
    @Text      NVARCHAR(MAX),
    @ChunkSize INT,
    @Overlap   INT
)
RETURNS @r TABLE (ChunkOrdinal INT, Chunk NVARCHAR(MAX))
AS
BEGIN
    DECLARE @pos INT = 1, @ord INT = 1, @len INT = LEN(@Text);
    DECLARE @step INT = CASE WHEN @ChunkSize - @Overlap < 1 THEN 1 ELSE @ChunkSize - @Overlap END;

    WHILE @pos <= @len
    BEGIN
        INSERT @r (ChunkOrdinal, Chunk) VALUES (@ord, SUBSTRING(@Text, @pos, @ChunkSize));
        SET @ord += 1;
        SET @pos += @step;
    END;
    RETURN;
END;
GO

DECLARE @doc NVARCHAR(MAX) = N'Chính sách hoàn tiền của công ty áp dụng cho mọi đơn hàng '
 + N'mua trực tuyến. Khách hàng có thể yêu cầu hoàn tiền trong vòng 30 ngày kể từ ngày nhận hàng. '
 + N'Sản phẩm phải còn nguyên tem niêm phong và đầy đủ phụ kiện đi kèm. '
 + N'Chi phí vận chuyển trả hàng do người bán chịu nếu lỗi thuộc về nhà sản xuất. '
 + N'Tiền được hoàn về tài khoản gốc trong 5 đến 7 ngày làm việc.';

SELECT ChunkOrdinal, LEN(Chunk) AS ChunkLen, Chunk
FROM   dbo.fnChunkText(@doc, 150, 30);
GO
/*  🎯 THAM SỐ CHUNKING — CHẤT LƯỢNG RAG PHỤ THUỘC VÀO ĐÂY:
    ┌──────────────┬───────────────────────┬──────────────────────────────────────┐
    │ Tham số      │ Khuyến nghị           │ Vì sao                               │
    ├──────────────┼───────────────────────┼──────────────────────────────────────┤
    │ Kích thước   │ 200–800 token         │ Nhỏ quá ⇒ mất ngữ cảnh;              │
    │              │ (~400–1500 ký tự)     │ lớn quá ⇒ pha loãng ngữ nghĩa, tốn token│
    │ Chồng lấn    │ 10–20% kích thước     │ Tránh cắt đứt câu/ý ở ranh giới      │
    │ Ranh giới    │ Theo câu/đoạn/tiêu đề │ Giữ ngữ nghĩa trọn vẹn               │
    │ Metadata     │ Luôn lưu DocId, nguồn │ Cần cho trích dẫn và pre-filter      │
    └──────────────┴───────────────────────┴──────────────────────────────────────┘
    BA CHIẾN LƯỢC:
      Fixed-size        — đơn giản nhất, dễ triển khai
      Semantic/recursive— cắt theo cấu trúc (chương → đoạn → câu), chất lượng cao hơn
      Document-based    — mỗi bản ghi là 1 chunk, hợp dữ liệu đã có cấu trúc        */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 7 — SINH EMBEDDING THEO LÔ (mẫu triển khai thực tế)
───────────────────────────────────────────────────────────────────────────────*/
DROP TABLE IF EXISTS dbo.EmbeddingQueue;
CREATE TABLE dbo.EmbeddingQueue
(
    QueueId      INT IDENTITY PRIMARY KEY,
    SourceTable  SYSNAME       NOT NULL,
    SourceId     INT           NOT NULL,
    TextToEmbed  NVARCHAR(MAX) NOT NULL,
    TextHash     VARBINARY(32) NOT NULL,        -- ⚠ để KHÔNG embed lại nội dung không đổi
    Status       VARCHAR(20)   NOT NULL DEFAULT 'PENDING',  -- PENDING/DONE/FAILED
    Embedding    NVARCHAR(MAX) NULL,
    ErrorMsg     NVARCHAR(MAX) NULL,
    ProcessedAt  DATETIME2(3)  NULL
);
CREATE INDEX IX_EmbeddingQueue_Status ON dbo.EmbeddingQueue(Status) INCLUDE (SourceId);
CREATE UNIQUE INDEX UX_EmbeddingQueue_Hash ON dbo.EmbeddingQueue(SourceTable, SourceId, TextHash);
GO

-- Chỉ nạp vào hàng đợi những chunk MỚI hoặc ĐÃ ĐỔI NỘI DUNG
INSERT dbo.EmbeddingQueue (SourceTable, SourceId, TextToEmbed, TextHash)
SELECT 'dbo.DocChunk', c.ChunkId, c.Content, HASHBYTES('SHA2_256', c.Content)
FROM   dbo.DocChunk c
WHERE  NOT EXISTS (
         SELECT 1 FROM dbo.EmbeddingQueue q
         WHERE  q.SourceTable = 'dbo.DocChunk'
           AND  q.SourceId    = c.ChunkId
           AND  q.TextHash    = HASHBYTES('SHA2_256', c.Content));

SELECT Status, COUNT(*) AS Cnt FROM dbo.EmbeddingQueue GROUP BY Status;
GO

/*  Thủ tục xử lý hàng đợi theo lô — chạy trong SQL Agent job / Elastic Job:

    CREATE OR ALTER PROCEDURE dbo.usp_ProcessEmbeddingQueue @BatchSize INT = 100
    AS
    BEGIN
        SET NOCOUNT ON;
        DECLARE @id INT, @text NVARCHAR(MAX), @emb NVARCHAR(MAX), @n INT = 0;

        WHILE @n < @BatchSize
        BEGIN
            SELECT TOP (1) @id = QueueId, @text = TextToEmbed
            FROM   dbo.EmbeddingQueue WHERE Status = 'PENDING' ORDER BY QueueId;
            IF @@ROWCOUNT = 0 BREAK;

            BEGIN TRY
                -- ⚠ KHÔNG bọc lời gọi mạng trong transaction!
                SET @emb = CAST(AI_GENERATE_EMBEDDINGS(@text USE MODEL MyEmbedder) AS NVARCHAR(MAX));

                UPDATE dbo.EmbeddingQueue
                SET    Embedding = @emb, Status = 'DONE', ProcessedAt = SYSUTCDATETIME()
                WHERE  QueueId = @id;
            END TRY
            BEGIN CATCH
                UPDATE dbo.EmbeddingQueue
                SET    Status = 'FAILED', ErrorMsg = ERROR_MESSAGE(), ProcessedAt = SYSUTCDATETIME()
                WHERE  QueueId = @id;
            END CATCH;

            SET @n += 1;
        END;
    END;

 🎯 NĂM NGUYÊN TẮC SINH EMBEDDING QUY MÔ LỚN (đề hay hỏi về chi phí/độ trễ):
    1. Dùng HASH nội dung để CHỈ sinh lại chunk đã thay đổi.
    2. Xử lý theo LÔ, chạy nền, ngoài giờ cao điểm.
    3. KHÔNG gọi API trong transaction hay trigger.
    4. Có trạng thái + retry + ghi log lỗi cho từng bản ghi.
    5. Tôn trọng rate limit: giới hạn tốc độ, backoff khi gặp 429.                */


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 8 — BẢO MẬT KHI TÍCH HỢP AI
───────────────────────────────────────────────────────────────────────────────*/
/*
 THỨ TỰ ƯU TIÊN VỀ XÁC THỰC (đề hay hỏi "cách an toàn nhất"):
   1. 🥇 MANAGED IDENTITY        — không có khoá nào để lộ, xoay vòng tự động
   2. 🥈 Database scoped credential — khoá nằm trong DB, đã được mã hoá
   3. 🥉 Khoá API trong @headers   — lộ trong plan cache, XEvents, log ⇒ tránh

 QUYỀN TỐI THIỂU:
   GRANT EXECUTE ANY EXTERNAL ENDPOINT TO AppUser;   -- gọi REST
   GRANT EXECUTE ANY EXTERNAL MODEL    TO AppUser;   -- dùng external model
   -- KHÔNG cấp CONTROL hay db_owner chỉ để gọi được API.

 RỦI RO DỮ LIỆU RỜI KHỎI DATABASE:
   Nội dung gửi lên LLM là dữ liệu RA KHỎI ranh giới bảo mật của bạn.
   ⇒ Lọc/che PII trước khi gửi; cân nhắc model chạy cục bộ (Ollama/ONNX) cho dữ liệu
     nhạy cảm; kiểm tra điều khoản lưu trữ dữ liệu của nhà cung cấp.

 MẠNG:
   • Chỉ HTTPS. • Ưu tiên private endpoint. • Cấu hình firewall hai chiều.

 LIÊN MIỀN 2 — câu hỏi liên miền rất hay ra:
   "Làm sao đảm bảo RAG chỉ trả về tài liệu người dùng được phép xem?"
   ⇒ ROW-LEVEL SECURITY trên bảng chunk. Lọc ở tầng ứng dụng là ĐÁP ÁN SAI,
     vì người dùng có quyền truy vấn trực tiếp vẫn đọc được toàn bộ.             */

-- Minh hoạ: RLS trên bảng chunk (kết hợp Miền 2)
CREATE SCHEMA SecAi;
GO
CREATE FUNCTION SecAi.fn_DeptPredicate(@Department NVARCHAR(50))
RETURNS TABLE
WITH SCHEMABINDING
AS RETURN
    SELECT 1 AS ok
    WHERE  @Department = CAST(SESSION_CONTEXT(N'Department') AS NVARCHAR(50))
       OR  IS_MEMBER('db_owner') = 1;
GO
CREATE SECURITY POLICY SecAi.ChunkFilter
ADD FILTER PREDICATE SecAi.fn_DeptPredicate(Department) ON dbo.DocChunk
WITH (STATE = ON);
GO
CREATE USER KyThuatUser WITHOUT LOGIN;
GRANT SELECT ON dbo.DocChunk TO KyThuatUser;
GO
EXECUTE AS USER = 'KyThuatUser';
    EXEC sys.sp_set_session_context @key = N'Department', @value = N'KyThuat', @read_only = 1;
    SELECT ChunkId, Title, Department FROM dbo.DocChunk;   -- chỉ thấy phòng KyThuat
REVERT;
GO
SELECT 'dbo thấy tất cả' AS Note, COUNT(*) AS TotalChunks FROM dbo.DocChunk;
GO


/*───────────────────────────────────────────────────────────────────────────────
  SECTION 9 — CÁC KHẢ NĂNG AI KHÁC & BẢNG PHÂN LOẠI
───────────────────────────────────────────────────────────────────────────────*/
/*
 ┌─────────────────────────────┬──────────────────────────┬──────────────────────┐
 │ Khả năng                    │ Công nghệ                │ Chạy ở đâu           │
 ├─────────────────────────────┼──────────────────────────┼──────────────────────┤
 │ Sinh embedding / gọi LLM    │ External model, REST     │ RA NGOÀI (mạng)      │
 │ Suy luận model ML           │ PREDICT + ONNX           │ TRONG engine         │
 │ Chạy Python/R               │ ML Services              │ TRONG engine (on-prem)│
 │ Tìm kiếm từ khoá            │ Full-Text Search         │ TRONG engine         │
 │ Tìm kiếm ngữ nghĩa          │ VECTOR + vector index    │ TRONG engine         │
 │ Trợ lý NL→SQL               │ Copilot in Azure SQL/SSMS│ Dịch vụ ngoài        │
 │ Điều phối pipeline AI phức tạp│ Azure AI Foundry,       │ Ngoài DB             │
 │                             │ AI Search, Semantic Kernel│                     │
 └─────────────────────────────┴──────────────────────────┴──────────────────────┘

 🎯 HAI CÂU HỎI PHÂN LOẠI TOÀN BỘ MIỀN 3:
      1. "Chạy TRONG engine hay gọi RA ngoài?"
      2. "Chính xác (exact) hay xấp xỉ (approximate)?"
    Trả lời được hai câu này là loại được đa số đáp án nhiễu.                     */


/*───────────────────────────────────────────────────────────────────────────────
  DỌN DẸP
───────────────────────────────────────────────────────────────────────────────*/
DROP SECURITY POLICY IF EXISTS SecAi.ChunkFilter;
GO

/*═══════════════════════════════════════════════════════════════════════════════
  CHECKLIST SAU LAB 02
  □ Kể đủ tham số của sp_invoke_external_rest_endpoint và giới hạn của @timeout.
  □ Nhớ: chỉ HTTPS, tên credential PHẢI trùng URL gốc.
  □ Vẽ được 3 nhánh $.response / $.result / $.error của JSON trả về.
  □ Biết dùng JSON_VALUE cho scalar, JSON_QUERY cho mảng embedding.
  □ Nêu mã HTTP nào nên retry, mã nào retry vô ích.
  □ Giải thích vì sao KHÔNG gọi endpoint trong trigger/transaction.
  □ Viết được CREATE EXTERNAL MODEL với đủ 5 tuỳ chọn.
  □ So sánh external model và REST endpoint: khi nào dùng cái nào.
  □ Nhớ khuyến nghị chunk 200–800 token, overlap 10–20%.
  □ Nêu 5 nguyên tắc sinh embedding quy mô lớn.
  □ Nhớ thứ tự ưu tiên xác thực: Managed Identity > credential > khoá trong header.
  □ Biết RLS là câu trả lời cho phân quyền tài liệu trong RAG.
═══════════════════════════════════════════════════════════════════════════════*/
