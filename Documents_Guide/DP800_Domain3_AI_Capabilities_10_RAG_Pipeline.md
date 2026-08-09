# DP-800 Domain 3: Design & Implement Retrieval-Augmented Generation (RAG)

> **Miền 3:** Implement AI Capabilities in Database Solutions (25–30%)  
> **Chủ đề:** Design and Implement Retrieval-Augmented Generation (RAG)  
> **Trọng tâm thi:** RAG Architecture, `sp_invoke_external_rest_endpoint`, Managed Identity Credentials, JSON Prompt Formatting, Response Extraction.

---

## 📘 PHẦN 1: LÝ THUYẾT & KIẾN THỨC CỐT LÕI (CORE THEORY)

### 1. Kiến Trúc RAG Là Gì & Tại Sao Lại Cần RAG trong SQL CSDL?
- **Retrieval-Augmented Generation (RAG) là gì?**  
  Là kỹ thuật kết hợp giữa **Tìm kiếm dữ liệu doanh nghiệp (Retrieval)** và **Sinh câu trả lời bằng LLM (Generation)**.
- **Lợi ích của RAG:**
  - Cung cấp dữ liệu doanh nghiệp mới nhất cho LLM mà không cần Fine-tune mô hình tốn kém.
  - Loại bỏ hiện tượng "Ảo giác" (Hallucination) của AI bằng cách bắt buộc LLM chỉ được trả lời dựa trên thông tin (Context) được trích xuất từ SQL CSDL.
  - Kiểm soát phân quyền truy cập dữ liệu (RLS / ACL) ngay tại bước Retrieval.

### 2. Quy Trình RAG End-to-End Trong SQL Server & Azure SQL (6 Bước)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          QUY TRÌNH RAG TRONG SQL                            │
├───────┬─────────────────────────────────────────────────────────────────────┤
│ Bước  │ Thao tác T-SQL                                                      │
├───────┼─────────────────────────────────────────────────────────────────────┤
│ 1     │ Nhận câu hỏi từ người dùng (@UserQuery)                             │
│ 2     │ Gọi Vector Search / Hybrid Search lấy Top-K Chunks liên quan nhất   │
│ 3     │ Chuyển đổi dữ liệu Top-K Chunks thành định dạng JSON System Context │
│ 4     │ Đóng gói Prompt (System Prompt + Context + User Question)           │
│ 5     │ Thực thi `sp_invoke_external_rest_endpoint` gọi Azure OpenAI        │
│ 6     │ Dùng `JSON_VALUE` trích xuất câu trả lời AI hoàn chỉnh              │
└───────┴─────────────────────────────────────────────────────────────────────┘
```

### 3. Stored Procedure `sp_invoke_external_rest_endpoint`
Stored Procedure hệ thống cho phép SQL Server / Azure SQL gửi HTTP POST/GET trực tiếp sang REST API bên ngoài:

```sql
EXEC sys.sp_invoke_external_rest_endpoint
    @url = N'https://<my-openai>.openai.azure.com/openai/deployments/gpt-4o/chat/completions?api-version=2024-08-01-preview',
    @method = N'POST',
    @credential = [https://<my-openai>.openai.azure.com], -- Bắt buộc dùng Database Scoped Credential
    @payload = @JsonPayload,
    @timeout = 30,
    @response = @response OUTPUT;
```

> 💡 **Bẫy thi DP-800 Bảo Mật:**
> - Luôn chọn **Managed Identity** làm Identity cho Database Scoped Credential khi gọi Azure OpenAI. Không dùng API Key cứng!
> - Phải bật `sp_configure 'external rest endpoint enabled', 1; RECONFIGURE;` trên SQL Server.

---

## 💻 PHẦN 2: THỰC HÀNH T-SQL (HANDS-ON LAB: PIPELINE RAG COMPLETE)

```sql
-- ============================================================================
-- LAB 10.1: END-TO-END RAG PIPELINE STORED PROCEDURE
-- ============================================================================
USE tempdb;
GO

CREATE PROCEDURE dbo.sp_AnswerUserQuestionRAG
    @UserQuestion NVARCHAR(MAX),
    @QueryVector VECTOR(1536),
    @AIResponse NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Bước 1: Retrieval - Lấy Top 3 Context Chunks có độ tương đồng cao nhất
    DECLARE @ContextText NVARCHAR(MAX);

    SELECT @ContextText = STRING_AGG(CAST(ChunkText AS NVARCHAR(MAX)), CHAR(10) + '---' + CHAR(10))
    FROM (
        SELECT TOP (3) ChunkText
        FROM dbo.DocumentChunks
        WHERE Embedding IS NOT NULL
        ORDER BY VECTOR_DISTANCE('cosine', Embedding, @QueryVector) ASC
    ) AS TopChunks;

    -- 2. Bước 2: Đóng gói JSON Payload cho Azure OpenAI Chat Completions
    DECLARE @JsonPayload NVARCHAR(MAX);
    
    SET @JsonPayload = JSON_OBJECT(
        'messages': JSON_ARRAY(
            JSON_OBJECT(
                'role': 'system',
                'content': N'Bạn là trợ lý AI nội bộ. Hãy chỉ trả lời câu hỏi dựa trên ngữ cảnh được cung cấp sau đây. Nếu không tìm thấy thông tin trong ngữ cảnh, hãy trả lời: "Tôi không tìm thấy thông tin trong CSDL nội bộ". Ngữ cảnh: ' + ISNULL(@ContextText, N'')
            ),
            JSON_OBJECT(
                'role': 'user',
                'content': @UserQuestion
            )
        ),
        'temperature': 0.2,
        'max_tokens': 500
    );

    -- 3. Bước 3: Gọi Azure OpenAI Endpoint qua sp_invoke_external_rest_endpoint
    DECLARE @RestResponse NVARCHAR(MAX);

    BEGIN TRY
        EXEC sys.sp_invoke_external_rest_endpoint
            @url = N'https://my-openai-instance.openai.azure.com/openai/deployments/gpt-4o/chat/completions?api-version=2024-08-01-preview',
            @method = N'POST',
            @credential = [https://my-openai-instance.openai.azure.com],
            @payload = @JsonPayload,
            @timeout = 30,
            @response = @RestResponse OUTPUT;

        -- 4. Bước 4: Trích xuất câu trả lời từ JSON Response
        SET @AIResponse = JSON_VALUE(@RestResponse, '$.result.choices[0].message.content');
    END TRY
    BEGIN CATCH
        SET @AIResponse = N'Lỗi kết nối AI Endpoint: ' + ERROR_MESSAGE();
    END CATCH
END;
GO
```

---

## 📝 PHẦN 3: CÂU HỎI THI THỬ & TÌNH HUỐNG (MOCK TEST QUESTIONS)

#### Question 1 (RAG Security & Managed Identity Scenario):
**Scenario:** You are implementing an enterprise RAG application inside Azure SQL Database that sends query prompts to Azure OpenAI via `sp_invoke_external_rest_endpoint`. Company security guidelines mandate that credentials must not use API Keys or static secrets. How should you set up authentication for `sp_invoke_external_rest_endpoint`?
- A. Pass the Azure OpenAI API Key in the `@headers` parameter as plaintext.
- B. Enable System-Assigned Managed Identity on Azure SQL Server, grant it the "Cognitive Services OpenAI User" role on Azure OpenAI, and create a Database Scoped Credential using `IDENTITY = 'Managed Identity'`.
- C. Store the API Key in a public SQL Server table.
- D. Disable TLS/SSL encryption on the endpoint.

**👉 Correct Answer: B**  
*Explanation (Giải thích):* Phương án bảo mật chuẩn Microsoft là sử dụng **Managed Identity** (Passwordless).Ta bật Managed Identity cho Azure SQL Server, cấp quyền RBAC trên Azure OpenAI, và khởi tạo **Database Scoped Credential** với `IDENTITY = 'Managed Identity'` để truyền vào tham số `@credential` của `sp_invoke_external_rest_endpoint`.

---

#### Question 2 (Grounding Prompts to Prevent Hallucination Scenario):
**Scenario:** When testing your RAG stored procedure, you notice that the LLM occasionally invents false facts (hallucinations) when a user asks a question not covered by the retrieved database context. How should you modify the system prompt to enforce grounding?
- A. Increase the `temperature` parameter to 1.0.
- B. Add explicit instructions in the system message telling the LLM to answer ONLY using the provided database context, and to state "Information not found" if the context is insufficient.
- C. Convert the database context into an XML format instead of JSON.
- D. Remove the context chunks from the prompt.

**👉 Correct Answer: B**  
*Explanation (Giải thích):* Để chống ảo giác (Hallucination) trong RAG, kỹ thuật chuẩn là thiết lập **System Prompt** với quy tắc ràng buộc nghiêm ngặt: Ép LLM chỉ được trả lời dựa trên tập ngữ cảnh (Context Chunks) được trích xuất từ SQL CSDL truyền vào, và nếu không có thông tin thì bắt buộc phải thông báo không tìm thấy.

---

#### Question 3 (Response JSON Extraction Scenario):
**Scenario:** You called `sp_invoke_external_rest_endpoint` and received a JSON response string stored in `@RestResponse`. The JSON structure contains: `{"result":{"choices":[{"message":{"content":"The warranty period is 12 months."}}]}}`. Which T-SQL expression correctly extracts the AI message content string?
- A. `JSON_VALUE(@RestResponse, '$.result.choices[0].message.content')`
- B. `OPENJSON(@RestResponse, '$.choices')`
- C. `JSON_QUERY(@RestResponse, '$.result.choices')`
- D. `REGEXP_SUBSTR(@RestResponse, 'warranty')`

**👉 Correct Answer: A**  
*Explanation (Giải thích):* Hàm **`JSON_VALUE`** được sử dụng để trích xuất một giá trị đơn (Scalar String) từ chuỗi JSON theo đường dẫn JSON Path (`$.result.choices[0].message.content`).
