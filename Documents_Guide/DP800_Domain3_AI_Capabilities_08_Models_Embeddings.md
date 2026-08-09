# DP-800 Domain 3: Design and Implement Models and Embeddings

> **Miền 3:** Implement AI Capabilities in Database Solutions (25–30%)  
> **Chủ đề:** Design and Implement Models and Embeddings  
> **Trọng tâm thi:** External Models (`CREATE EXTERNAL MODEL`), Chunking Strategies (`AI_GENERATE_CHUNKS`), Embedding Maintenance Methods, `AI_GENERATE_EMBEDDINGS`.

---

## 📘 PHẦN 1: LÝ THUYẾT & KIẾN THỨC CỐT LÕI (CORE THEORY)

### 1. Khái Niệm Vector Embedding & Đánh Giá Mô Hình Ngoại Vi (External Models)
- **Vector Embedding là gì?**  
  Là quá trình chuyển đổi văn bản (hoặc hình ảnh/âm thanh) thành một chuỗi mảng số thực (Vector) biểu diễn ý nghĩa ngữ nghĩa (Semantic Meaning).
  *Ví dụ:* `"Quy trình đổi trả hàng"` ➔ `[0.012, -0.045, 0.812, ..., 0.104]` (Mảng 1536 chiều).
- **Đánh giá & Chọn Mô Hình Embedding (External Model Selection):**
  - *Số chiều Vector (Dimensions):* Mô hình `text-embedding-3-small` (1536 chiều), `text-embedding-3-large` (3072 chiều). Số chiều càng lớn thì biểu diễn ý nghĩa càng tinh tế nhưng tốn bộ nhớ lưu trữ và tính toán hơn.
  - *Hỗ trợ Đa ngôn ngữ (Multilingual):* Đảm bảo mô hình hiểu tốt tiếng Việt và tiếng Anh.
  - *Kích thước context window & Structured Output:* Khả năng xử lý đầu vào dài và trả về JSON chuẩn.

### 2. Quản Lý Mô Hình Ngoại Vi (`CREATE EXTERNAL MODEL`)
- Tính năng native trong SQL Server 2025 / Azure SQL cho phép khai báo mô hình AI ngoại vi trực tiếp trong T-SQL:
  ```sql
  CREATE EXTERNAL MODEL dbo.AzureOpenAIEmbeddingModel
  WITH (
      LOCATION = 'https://my-openai.openai.azure.com/openai/deployments/text-embedding-3-small/embeddings?api-version=2024-08-01-preview',
      PROVIDER = AZURE_OPENAI,
      CREDENTIAL = [https://my-openai.openai.azure.com]
  );
  ```

### 3. Chiến Lược Chia Đoạn (Chunking Strategies)
- Văn bản quá dài (như sách, tài liệu PDF, hợp đồng) không thể đưa nguyên khối vào mô hình embedding ➔ Cần **Chia nhỏ (Chunking)**.
- **Chiến lược Chunking:**
  - *Fixed-size Chunking:* Chia theo số lượng từ/ký tự cố định (ví dụ: 500 tokens/chunk, overlap 50 tokens).
  - *Semantic / Paragraph Chunking:* Chia theo câu hoặc đoạn văn để giữ nguyên ngữ cảnh hoàn chỉnh.
- **Hàm Native `AI_GENERATE_CHUNKS` (SQL Server 2025+):**
  Tự động chia văn bản dài thành các chunk nhỏ ngay trong T-SQL.

### 4. Phương Pháp Duy Trì Dữ Liệu Embedding (Embedding Maintenance Methods)
Khi văn bản gốc trong CSDL bị thay đổi (`UPDATE/DELETE`), dữ liệu Vector Embedding tương ứng phải được cập nhật đồng bộ để tránh tìm kiếm ra thông tin cũ/sai lệch.
- **Các phương pháp đồng bộ:**
  - *Database Triggers:* Cập nhật embedding ngay lập tức (Synchronous). Thích hợp cho tần suất thay đổi ít.
  - *Change Tracking / CDC:* Đưa các dòng thay đổi vào hàng đợi (Queue) để worker background xử lý bất đồng bộ (Asynchronous).
  - *Azure Functions (SQL Trigger):* Tự động gọi API embedding bất đồng bộ khi có dòng mới.

---

## 💻 PHẦN 2: THỰC HÀNH T-SQL (HANDS-ON LABS)

```sql
-- ============================================================================
-- LAB 8.1: BẢNG LƯU TRỮ CHUNK & EMBEDDINGS VỚI KIỂU VECTOR
-- ============================================================================
USE tempdb;
GO

-- 1. Tạo Bảng lưu trữ Tài liệu gốc
CREATE TABLE dbo.Documents (
    DocumentId INT IDENTITY PRIMARY KEY,
    Title NVARCHAR(200) NOT NULL,
    ContentText NVARCHAR(MAX) NOT NULL,
    CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME()
);
GO

-- 2. Tạo Bảng lưu trữ Chunks & Vector Embedding (1536 chiều)
CREATE TABLE dbo.DocumentChunks (
    ChunkId BIGINT IDENTITY PRIMARY KEY,
    DocumentId INT NOT NULL REFERENCES dbo.Documents(DocumentId) ON DELETE CASCADE,
    ChunkIndex INT NOT NULL,
    ChunkText NVARCHAR(MAX) NOT NULL,
    -- Cột kiểu dữ liệu VECTOR(1536) Native
    Embedding VECTOR(1536) NULL,
    EmbeddingVersion INT DEFAULT 1,
    UpdatedAt DATETIME2 DEFAULT SYSUTCDATETIME()
);
GO

-- ============================================================================
-- LAB 8.2: MÔ PHỎNG QUY TRÌNH EMBEDDING TỰ ĐỘNG
-- ============================================================================
-- Insert Tài liệu mẫu
INSERT INTO dbo.Documents (Title, ContentText)
VALUES (N'Chính sách bảo hành', N'Tất cả sản phẩm điện tử được bảo hành 12 tháng kể từ ngày mua. Khách hàng cần giữ lại hóa đơn thanh toán.');

-- Chia Chunk và tạo bản ghi
INSERT INTO dbo.DocumentChunks (DocumentId, ChunkIndex, ChunkText)
VALUES 
(1, 1, N'Tất cả sản phẩm điện tử được bảo hành 12 tháng kể từ ngày mua.'),
(1, 2, N'Khách hàng cần giữ lại hóa đơn thanh toán.');
GO
```

---

## 📝 PHẦN 3: CÂU HỎI THI THỬ & TÌNH HUỐNG (MOCK TEST QUESTIONS)

#### Question 1 (Embedding Maintenance Selection Scenario):
**Scenario:** Your company manages an e-commerce catalog in Azure SQL Database with 2 million products. Product descriptions are updated thousands of times per hour by background warehouse sync jobs. You need to implement an embedding maintenance strategy to update vector embeddings in Azure OpenAI without degrading the transactional performance of product update queries. Which maintenance method should you select?
- A. A synchronous AFTER UPDATE DML Trigger that calls Azure OpenAI directly.
- B. Change Tracking or CDC combined with an asynchronous Azure Function worker queue.
- C. Rebuild the Clustered Columnstore Index on every update.
- D. Execute `sp_invoke_external_rest_endpoint` inside a blocking transaction.

**👉 Correct Answer: B**  
*Explanation (Giải thích):* Đối với các hệ thống có tần suất cập nhật cao (thousands of updates/hour), việc gọi API embedding đồng bộ trong Trigger sẽ gây trễ (latency) và nghẽn giao dịch OLTP. Phương pháp tối ưu nhất là dùng **Change Tracking hoặc CDC** kết hợp với **Azure Function worker queue** để xử lý tính toán embedding bất đồng bộ (Asynchronous background processing).

---

#### Question 2 (Vector Dimensions Matching Scenario):
**Scenario:** You configured an external embedding model using `text-embedding-3-small` which outputs 1,536-dimensional vectors. You create a table `dbo.KnowledgeBase` to store embeddings. How should you define the `Embedding` column in T-SQL?
- A. `Embedding NVARCHAR(MAX)`
- B. `Embedding VARBINARY(8000)`
- C. `Embedding VECTOR(1536)`
- D. `Embedding FLOAT(53)`

**👉 Correct Answer: C**  
*Explanation (Giải thích):* SQL Server 2025 và Azure SQL giới thiệu kiểu dữ liệu chuẩn **`VECTOR(dimensions)`**. Vì mô hình `text-embedding-3-small` sinh ra vector 1,536 chiều, cột lưu trữ phải được khai báo chính xác là **`VECTOR(1536)`**.

---

#### Question 3 (Column Selection for Embeddings Scenario):
**Scenario:** You are designing an AI search feature for a Human Resources database table `dbo.Employees` containing columns: `EmployeeId`, `SSN`, `FirstName`, `LastName`, `JobTitle`, `Department`, and `ResumeText`. Which columns should be concatenated and processed to generate meaningful semantic vector embeddings?
- A. `EmployeeId` and `SSN`
- B. `JobTitle`, `Department`, and `ResumeText`
- C. All columns including system timestamps and primary keys
- D. Only `EmployeeId`

**👉 Correct Answer: B**  
*Explanation (Giải thích):* Dữ liệu đưa vào mô hình Embedding phải chứa thông tin có ý nghĩa ngữ nghĩa (Semantic Content). Các cột như `JobTitle`, `Department`, `ResumeText` chứa nội dung mô tả kỹ năng/nghề nghiệp. Không nên đưa các cột ID hệ thống (`EmployeeId`) hoặc dữ liệu bảo mật cá nhân (`SSN`) vào embedding.
