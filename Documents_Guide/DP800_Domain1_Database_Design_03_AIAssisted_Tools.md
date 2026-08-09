# DP-800 Domain 1: Design & Implement SQL Solutions by Using AI-Assisted Tools

> **Miền 1:** Design and Develop Database Solutions (35–40%)  
> **Chủ đề:** Design and Implement SQL Solutions by Using AI-Assisted Tools  
> **🚨 ĐÂY LÀ ĐIỂM YẾU SỐ 1 TRONG SCORE REPORT (TOP PRIORITIZED SKILL):** Bạn cần nắm thật vững các khái niệm, file cấu hình và cơ chế bảo mật của GitHub Copilot, Copilot in Fabric và MCP (Model Context Protocol).

---

## 📘 PHẦN 1: LÝ THUYẾT & KIẾN THỨC CỐT LÕI (CORE THEORY)

### 1. Đánh Giá Tác Động Bảo Mật (Security Impact of AI-Assisted Tools)
Khi sử dụng các công cụ trợ lý AI (GitHub Copilot, Microsoft Copilot in Fabric, SSMS/VS Code Copilot Extensions) trong phát triển CSDL SQL Server & Azure SQL, lập trình viên và doanh nghiệp phải đối mặt với các rủi ro bảo mật nghiêm trọng:
- **Rủi ro rò rỉ dữ liệu nhạy cảm (Data Leakage & PII Exposure):** Đưa dữ liệu thật, thông tin cá nhân (PII), thông tin thẻ hoặc Connection String chứa mật khẩu vào Prompt có thể bị gửi lên cloud AI service.
- **Tuân thủ quy định pháp lý (Compliance & Data Residency):** Dữ liệu truyền sang các mô hình LLM ngoại vi có thể vi phạm các chứng chỉ tuân thủ như GDPR, HIPAA, SOC2 nếu dịch vụ AI không nằm trong vùng dữ liệu được cấp phép.
- **Mã nguồn bị lợi dụng để huấn luyện mô hình (Model Training Data):** Cần đảm bảo tài khoản GitHub Copilot Enterprise / Fabric Copilot đã tắt tùy chọn *"Allow GitHub to use your code snippets for product improvements"*.
- **Rủi ro An ninh mã T-SQL sinh ra (AI Code Vulnerabilities):** AI có thể gợi ý mã T-SQL chứa lỗ hổng **SQL Injection** (ví dụ: dùng nối chuỗi trong `EXEC()`), thiếu xử lý phân quyền, hoặc truy vấn thiếu Index làm sập CSDL.

### 2. Kích Hoạt & Cấu Hình GitHub Copilot & Microsoft Copilot in Fabric
- **GitHub Copilot in Azure Data Studio / VS Code / SSMS:**
  - Bật extension GitHub Copilot, đăng nhập tài khoản GitHub Organization được cấp bản quyền.
  - Thiết lập quyền riêng tư ở cấp Organization: Block gợi ý khớp với mã nguồn công khai (Public Code Filter).
- **Microsoft Copilot in Fabric:**
  - Bật tùy chọn Copilot trong **Fabric Admin Portal** ở cấp Tenant (`Tenant Settings -> Copilot and Azure OpenAI Service`).
  - Gán dung lượng Fabric Capacity (F64 trở lên hoặc P Capacity) để hỗ trợ tính năng AI cho Fabric Lakehouse & SQL Database.

### 3. Model Context Protocol (MCP) & MCP Servers cho SQL
- **Model Context Protocol (MCP) là gì?**  
  MCP là một chuẩn mở (open standard) cho phép mô hình AI (LLM) kết nối an toàn với các công cụ (tools), kho dữ liệu (data sources) và môi trường ngoài (như SQL Server CSDL hoặc Fabric Lakehouse).
- **Kết nối MCP Server Endpoints trong SQL Development:**
  - **Microsoft SQL Server MCP Server:** Cho phép Copilot đọc trực tiếp Metadata (Schema, Bảng, Cột, Foreign Keys, Index) của CSDL SQL local/Azure SQL để sinh ra mã T-SQL chính xác 100% theo ngữ cảnh CSDL thực tế.
  - **Fabric Lakehouse MCP Server:** Cho phép Copilot truy vấn Schema Delta Tables/Parquet trong Fabric Lakehouse.
- **Cấu hình MCP Tool Options trong Chat Session:** Lập trình viên có thể bật/tắt các công cụ MCP (Read-only schema inspection, Query execution, Execution plan analysis) trong phiên chat của Copilot.

### 4. Tệp Cấu Hình Hướng Dẫn GitHub Copilot (`.github/copilot-instructions.md`)
- Tạo tệp `.github/copilot-instructions.md` tại thư mục gốc của Git Repository để quy định "Luật sinh mã" (Custom System Instructions) cho Copilot.
- **Nội dung tệp instruction chuẩn cho SQL Developer:**
  - Bắt buộc dùng cú pháp T-SQL chuẩn SQL Server 2022/2025 (ví dụ: ưu tiên `STRING_AGG`, `REGEXP_LIKE`, `VECTOR`).
  - Không bao giờ sinh mã nối chuỗi động (chống SQL Injection).
  - Tự động thêm nhận xét giải thích execution plan và chỉ mục khuyến nghị.

---

## 💻 PHẦN 2: MÃ CẤU HÌNH & CHUẨN PROMPT (HANDS-ON CONFIGS & PROMPTS)

### 1. Mã Cấu Hình Tệp `.github/copilot-instructions.md` cho SQL Project

```markdown
# GITHUB COPILOT INSTRUCTIONS FOR SQL SERVER & AZURE SQL DEVELOPMENT

## General Rules:
1. Always generate ANSI-standard T-SQL compatible with SQL Server 2022/2025 and Azure SQL Database.
2. Maintain strict security: NEVER generate dynamic SQL using string concatenation (`EXEC('SELECT ... ' + @val)`). Always use `sys.sp_executesql` with parameterized inputs to prevent SQL Injection.
3. Performance First:
   - Prefer Inline Table-Valued Functions (iTVFs) over Multi-Statement TVFs (mTVFs) or Scalar UDFs.
   - Avoid `SELECT *`; explicit column listing is required.
   - Ensure SARGable queries (avoid applying functions directly on indexed columns in `WHERE` clauses).
4. AI & Modern Features:
   - Use `REGEXP_LIKE` for complex pattern matching in CHECK constraints.
   - Use `VECTOR` data type and `VECTOR_DISTANCE('cosine', ...)` for vector semantic search.
   - Use `sp_invoke_external_rest_endpoint` with Managed Identity for Azure OpenAI calls.
```

### 2. Mã Cấu Hình MCP Server (`mcp-config.json` trong VS Code / Copilot Settings)

```json
{
  "mcpServers": {
    "sql-server-local": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-sql",
        "--connection-string",
        "Server=localhost;Database=DP800_Lab;Integrated Security=true;TrustServerCertificate=true;"
      ],
      "tools": [
        "get_schema_metadata",
        "execute_read_only_query",
        "explain_execution_plan"
      ]
    },
    "fabric-lakehouse": {
      "command": "dotnet",
      "args": [
        "run",
        "--project",
        "./FabricLHMcpServer/FabricLHMcpServer.csproj"
      ]
    }
  }
}
```

### 3. Prompt Mẫu Chuẩn Cho AI-Assisted T-SQL Generation
- **Prompt tối ưu Index:**  
  `"Hãy phân tích câu truy vấn T-SQL sau và gợi ý Filtered Index hoặc Covering Index với INCLUDE để khắc phục Key Lookup: [Insert Query]"`
- **Prompt viết RAG Stored Procedure an toàn:**  
  `"Hãy tạo một Stored Procedure trong Azure SQL gọi Azure OpenAI Embeddings dùng sp_invoke_external_rest_endpoint với Database Scoped Credential Managed Identity. Không hardcode API key."`

---

## 📝 PHẦN 3: CÂU HỎI THI THỬ & TÌNH HUỐNG (MOCK TEST QUESTIONS)

#### Question 1 (AI Tool Security Impact Scenario):
**Scenario:** Your company is adopting GitHub Copilot for all database developers working on an Azure SQL database containing Sensitive Personal Data (PII). Compliance policy strictly prohibits company data from being stored or used by third parties to train machine learning models. Which two actions must you configure? (Select 2)
- A. Enable public code suggestions in GitHub Copilot settings.
- B. Disable the "Allow GitHub to use your code snippets for product improvements" setting in the Organization policy.
- C. Store database passwords directly inside `.github/copilot-instructions.md`.
- D. Ensure developers never paste live PII data rows into Copilot chat prompts.
- E. Use dynamic SQL string concatenation for all AI queries.

**👉 Correct Answers: B and D**  
*Explanation (Giải thích):* Để bảo vệ dữ liệu PII và tuân thủ quy định không cho phép GitHub dùng mã/dữ liệu công ty để huấn luyện AI, cần: (1) Tắt tùy chọn *"Allow GitHub to use code snippets for product improvements"* ở cấp Organization policy; và (2) Đảm bảo lập trình viên không dán dữ liệu thật/PII vào khung Chat của Copilot.

---

#### Question 2 (MCP Endpoint Configuration Scenario):
**Scenario:** You are configuring VS Code with GitHub Copilot to assist in writing T-SQL queries for a Microsoft Fabric Lakehouse. You want Copilot to automatically discover table schemas, relationships, and metadata without manually typing schema definitions into chat. What technology should you configure to expose the lakehouse metadata to Copilot?
- A. ODBC DSN Connection
- B. Model Context Protocol (MCP) Server for Fabric Lakehouse
- C. SQL Server Audit File
- D. Data API Builder Gateway

**👉 Correct Answer: B**  
*Explanation (Giải thích):* **Model Context Protocol (MCP) Server** là giao thức chuẩn mở được thiết kế để kết nối trực tiếp kho dữ liệu (như Fabric Lakehouse hoặc SQL Server) với các mô hình AI/Copilot, cho phép Copilot tự động đọc Schema, Metadata và cấu trúc bảng thực tế.

---

#### Question 3 (GitHub Copilot Instruction File Scenario):
**Scenario:** You want all database code generated by GitHub Copilot across your team's repository to enforce the use of ANSI-standard T-SQL, avoid non-SARGable `WHERE` clauses, and automatically include parameterized `sp_executesql` for dynamic queries. Where should you place these rules so GitHub Copilot automatically applies them?
- A. Inside a SQL Server System Table `sys.copilot_rules`.
- B. In a file named `.github/copilot-instructions.md` at the repository root.
- C. In the connection string parameter `CopilotRules=True`.
- D. Inside the `master` database system registry.

**👉 Correct Answer: B**  
*Explanation (Giải thích):* GitHub Copilot tự động đọc và tuân thủ các quy tắc được định nghĩa trong tệp **`.github/copilot-instructions.md`** đặt tại thư mục gốc của Git Repository.
