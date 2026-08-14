/*===============================================================================
  DP-800 | DOMAIN 3 | LAB 02 — EXTERNAL MODELS, EMBEDDINGS, REST ENDPOINTS, ONNX

  Cập nhật: 14/08/2026
  Mục tiêu:
    1) CREATE DATABASE SCOPED CREDENTIAL
    2) CREATE EXTERNAL MODEL — current MODEL_TYPE = EMBEDDINGS
    3) AI_GENERATE_CHUNKS
    4) AI_GENERATE_EMBEDDINGS
    5) sys.sp_invoke_external_rest_endpoint
    6) Permissions
    7) ONNX Runtime local model — current developer-preview syntax

  Nguồn:
  https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-model-transact-sql?view=sql-server-ver17
  https://learn.microsoft.com/en-us/sql/t-sql/functions/ai-generate-embeddings-transact-sql?view=sql-server-ver17
  https://learn.microsoft.com/en-us/sql/t-sql/functions/ai-generate-chunks-transact-sql?view=sql-server-ver17
  https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-invoke-external-rest-endpoint-transact-sql?view=sql-server-ver17
===============================================================================*/

SET NOCOUNT ON;
GO

/* Current platform enablement for external REST:
   - Azure SQL Database + SQL database in Fabric: enabled by default.
   - SQL Server 2025 + Azure SQL Managed Instance: disabled by default. */

-- SQL Server 2025 / Azure SQL MI khi cần:
-- EXECUTE sp_configure 'external rest endpoint enabled', 1;
-- RECONFIGURE WITH OVERRIDE;
-- GO

/* Managed Identity credential example */
-- CREATE DATABASE SCOPED CREDENTIAL
--     [https://my-resource.openai.azure.com/]
-- WITH
-- (
--     IDENTITY = 'Managed Identity',
--     SECRET = '{"resourceid":"https://cognitiveservices.azure.com"}'
-- );
-- GO

/*
  IMPORTANT FIX:
  Current CREATE EXTERNAL MODEL accepts MODEL_TYPE = EMBEDDINGS.
  Do NOT learn MODEL_TYPE = CHAT_COMPLETIONS as a current accepted value.
*/

-- CREATE EXTERNAL MODEL DP800_EmbeddingModel
-- WITH
-- (
--     LOCATION =
--       'https://my-resource.openai.azure.com/openai/deployments/my-embedding/embeddings?api-version=2024-02-01',
--     API_FORMAT = 'Azure OpenAI',
--     MODEL_TYPE = EMBEDDINGS,
--     MODEL = 'text-embedding-3-small',
--     CREDENTIAL =
--       [https://my-resource.openai.azure.com/],
--     PARAMETERS = '{"dimensions":1536}'
-- );
-- GO

-- SELECT * FROM sys.external_models;
-- GO

-- GRANT EXECUTE
-- ON EXTERNAL MODEL::DP800_EmbeddingModel
-- TO [DP800_AI_User];
-- GO

/* AI_GENERATE_CHUNKS
   CHUNK_TYPE = FIXED is current syntax.
   OVERLAP is percent, range 0..50. */

-- SELECT *
-- FROM AI_GENERATE_CHUNKS
-- (
--     SOURCE = N'
--       DP-800 yêu cầu hiểu SQL, Azure integration, vector search và RAG.
--       Một document dài nên được chia thành các đoạn vừa đủ để retrieval chính xác.
--     ',
--     CHUNK_TYPE = FIXED,
--     CHUNK_SIZE = 120,
--     OVERLAP = 20
-- );
-- GO

/* AI_GENERATE_EMBEDDINGS */
-- DECLARE @embedding vector(1536);
-- SET @embedding =
--     AI_GENERATE_EMBEDDINGS
--     (
--         N'chính sách bảo hành'
--         USE MODEL DP800_EmbeddingModel
--     );
-- SELECT @embedding;
-- GO

/* End-to-end table pattern */
-- DROP TABLE IF EXISTS dbo.DP800_Chunks;
-- GO
-- CREATE TABLE dbo.DP800_Chunks
-- (
--     ChunkId    bigint IDENTITY PRIMARY KEY,
--     DocumentId bigint NOT NULL,
--     ChunkText  nvarchar(max) NOT NULL,
--     Embedding  vector(1536) NULL,
--     ModelVersion varchar(100) NULL,
--     EmbeddedAt datetime2 NULL
-- );
-- GO

/* Generic REST payload */
DECLARE @Payload nvarchar(max) =
N'{
  "messages": [
    {
      "role": "system",
      "content": "You are a SQL study assistant."
    },
    {
      "role": "user",
      "content": "Explain RAG briefly."
    }
  ]
}';

SELECT ISJSON(@Payload) AS PayloadIsJson;
GO

/* Actual call after configuring endpoint and credential */
-- DECLARE @Response nvarchar(max),
--         @ReturnCode int;
--
-- EXEC @ReturnCode =
--     sys.sp_invoke_external_rest_endpoint
--         @url = N'https://<resource>/<chat-endpoint>',
--         @method = N'POST',
--         @payload = @Payload,
--         @credential = [https://<credential-prefix>],
--         @timeout = 60,
--         @retry_count = 2,
--         @response = @Response OUTPUT;
--
-- SELECT @ReturnCode AS ReturnCode,
--        @Response AS Response;
-- GO

/* Response wrapper parsing */
DECLARE @MockResponse nvarchar(max) =
N'{
  "response": {
    "status": {
      "http": {
        "code": 200,
        "description": "OK"
      }
    },
    "headers": {}
  },
  "result": {
    "choices": [
      {
        "message": {
          "content": "RAG retrieves relevant context before generation."
        }
      }
    ]
  }
}';

SELECT
    JSON_VALUE(@MockResponse, '$.response.status.http.code') AS HttpCode,
    JSON_VALUE(@MockResponse, '$.result.choices[0].message.content') AS ShortAnswer;
GO

SELECT j.content
FROM OPENJSON(@MockResponse, '$.result.choices')
WITH
(
    content nvarchar(max) '$.message.content'
) AS j;
GO

/* Permissions */
-- GRANT EXECUTE ANY EXTERNAL ENDPOINT
-- TO [DP800_RagExecutor];
-- GO
-- GRANT REFERENCES
-- ON DATABASE SCOPED CREDENTIAL::[https://<credential-prefix>]
-- TO [DP800_RagExecutor];
-- GO

/*
  ONNX Runtime local model — Developer Preview.

  OLD/INCORRECT STYLE TO AVOID:
    CREATE EXTERNAL MODEL X WITH (ONNX, LOCATION='...');

  CURRENT PATTERN:
*/

-- ALTER DATABASE SCOPED CONFIGURATION
-- SET PREVIEW_FEATURES = ON;
-- GO
--
-- EXECUTE sys.sp_configure
--     'external AI runtimes enabled',
--     1;
-- RECONFIGURE WITH OVERRIDE;
-- GO
--
-- CREATE EXTERNAL MODEL DP800_LocalOnnxModel
-- WITH
-- (
--     LOCATION =
--       'C:\onnx_runtime\model\all-MiniLM-L6-v2-onnx',
--     API_FORMAT = 'ONNX Runtime',
--     MODEL_TYPE = EMBEDDINGS,
--     MODEL = 'allMiniLM',
--     PARAMETERS = '{"valid":"JSON"}',
--     LOCAL_RUNTIME_PATH = 'C:\onnx_runtime\'
-- );
-- GO
--
-- SELECT AI_GENERATE_EMBEDDINGS
-- (
--     N'local embedding test'
--     USE MODEL DP800_LocalOnnxModel
-- );
-- GO

PRINT N'
[EXAM TRAPS]
1. CREATE EXTERNAL MODEL current MODEL_TYPE = EMBEDDINGS.
2. Chat/generation API có thể gọi qua sp_invoke_external_rest_endpoint;
   điều đó không biến CHAT_COMPLETIONS thành current MODEL_TYPE value.
3. Azure SQL DB/Fabric SQL DB: external REST enabled by default.
4. SQL Server 2025/Azure SQL MI: external REST disabled by default.
5. ReturnCode 0 = HTTP 2xx; non-2xx returns status code; call failure throws.
6. @response là wrapper response/result.
7. Managed Identity vẫn cần target RBAC/database permissions.
8. ONNX current pattern = API_FORMAT ONNX Runtime + MODEL_TYPE EMBEDDINGS.
';
GO
