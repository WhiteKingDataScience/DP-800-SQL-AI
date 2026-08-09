# DP-800: Developing AI-Enabled Database Solutions — Lộ Trình Ôn Thi & Tổng Quan Toàn Diện

> **Kỳ thi:** Microsoft Certified: Azure Database Developer Associate / SQL AI Developer (DP-800)  
> **Cập nhật nội dung:** Chuẩn Microsoft Learn (tháng 03/2026)  
> **Tỷ lệ điểm đạt:** 700 / 1000  

---

## 📊 1. Cấu Trúc Đề Thi & Tỷ Trọng Trọng Số các Miền (Domains)

Đề thi DP-800 đánh giá năng lực thiết kế, xây dựng, tối ưu hóa và tích hợp các tính năng AI hiện đại vào cơ sở dữ liệu Microsoft SQL (SQL Server 2025, Azure SQL Database, Azure SQL Managed Instance, Fabric SQL Database).

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          KỲ THI DP-800: SKILLS MEASURED                         │
├─────────────────────────────────────────┬───────────────────────────────────────┤
│ Miền 1: Design & Develop Database       │ 35 – 40% Trọng số                     │
│         Solutions                       │                                       │
├─────────────────────────────────────────┼───────────────────────────────────────┤
│ Miền 2: Secure, Optimize & Deploy       │ 35 – 40% Trọng số                     │
│         Database Solutions              │                                       │
├─────────────────────────────────────────┼───────────────────────────────────────┤
│ Miền 3: Implement AI Capabilities in    │ 25 – 30% Trọng số                     │
│         Database Solutions              │                                       │
└─────────────────────────────────────────┴───────────────────────────────────────┘
```

---

## 🚨 2. Phân Tích Báo Cáo Điểm Thi (`DP-800 score.pdf`) & Yếu Điểm Cần Khắc Phục

Dựa trên kết quả thi thực tế của bạn (**Score: 673/700 — FAIL**):

### 🎯 Các vùng kiến thức yếu nhất cần tập trung ưu tiên (Top Priorities):

1. 🥇 **Design and implement SQL solutions by using AI-assisted tools** *(Cần cải thiện nhất)*:
   - Cách bật và cấu hình GitHub Copilot, Microsoft Copilot in Fabric.
   - Hiểu về Model Context Protocol (MCP) tool options & MCP server endpoints (SQL Server & Fabric Lakehouse).
   - Thiết lập GitHub Copilot instruction files (`.github/copilot-instructions.md`).
   - Đánh giá tác động bảo mật (security impact) khi sử dụng các công cụ AI-assisted.

2. 🥈 **Integrate SQL solutions with Azure services** *(Ưu tiên số 2)*:
   - Data API builder (DAB): Cấu hình file `dab-config.json`, REST & GraphQL entities, caching, pagination, search, filtering, relationships và deployment.
   - Azure Monitor / Log Analytics Workspace / Application Insights.
   - Xử lý thay đổi dữ liệu (Handling Data Changes): Change Event Streaming (CES), Change Data Capture (CDC), Change Tracking, Azure Functions SQL trigger bindings, Azure Logic Apps.

3. 🥉 **Design and implement database objects** *(Ưu tiên số 3)*:
   - Columnstore Indexes (Clustered CCI & Nonclustered NCCI, Ordered CCI, Delta Store, Rowgroup).
   - Specialized Tables: In-Memory OLTP, Temporal Tables, Ledger Tables, External Tables, Graph Tables.
   - JSON Columns & JSON Indexes.
   - Database Constraints, SEQUENCES, Table & Index Partitioning.

---

## 🗺️ 3. Lộ Trình Ôn Thi Chi Tiết 18 Ngày (18-Day Action Plan)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          LỘ TRÌNH ÔN THI 18 NGÀY                            │
├───────────┬─────────────────────────────────────────────────────────────────┤
│ Giai đoạn │ Công việc chi tiết từng ngày                                    │
├───────────┼─────────────────────────────────────────────────────────────────┤
│ Ngày 1–6  │ MIỀN 1: Thiết kế & Phát triển CSDL                              │
│           │ • Ngày 1-2: Tables, Columnstore, Specialized Tables, JSON       │
│           │ • Ngày 3-4: Programmability, CTEs, Window Functions, Regex 2025 │
│           │ • Ngày 5-6: AI-Assisted Tools (Copilot, MCP, Instruction Files)│
├───────────┼─────────────────────────────────────────────────────────────────┤
│ Ngày 7–13 │ MIỀN 2: Bảo mật, Tối ưu hóa & Triển khai                        │
│           │ • Ngày 7-8: Encryption (TDE/AKV, Always Encrypted), DDM, RLS    │
│           │ • Ngày 9-10: Performance Optimization, Query Store, Deadlocks   │
│           │ • Ngày 11-12: CI/CD với SQL Projects (SDK-Style, Schema Drift)  │
│           │ • Ngày 13: Integrate with Azure Services (DAB, Azure Monitor)   │
├───────────┼─────────────────────────────────────────────────────────────────┤
│ Ngày 14-17│ MIỀN 3: Triển khai Khả năng AI                                  │
│           │ • Ngày 14: Models & Embeddings (CREATE EXTERNAL MODEL, Chunks)  │
│           │ • Ngày 15-16: Intelligent Search (Vector, Hybrid Search, RRF)   │
│           │ • Ngày 17: RAG Pipeline & sp_invoke_external_rest_endpoint     │
├───────────┼─────────────────────────────────────────────────────────────────┤
│ Ngày 18   │ TỔNG ÔN & LÀM MOCK EXAM                                         │
│           │ • Ôn lại 3 danh sách yếu điểm                                   │
│           │ • Giải toàn bộ câu hỏi thi thử trong các file                   │
└───────────┴─────────────────────────────────────────────────────────────────┘
```

---

## 📚 4. Danh Sách Các File Tài Liệu Học Trong Thư Mục `Documents_Guide`

Toàn bộ tài liệu được chuẩn hóa tên theo cú pháp tiếng Anh kèm số thứ tự: `DP800_<Domain>_<DomainName>_<NN>_<SubTopicName>.md`

1. [`DP800_00_Exam_Roadmap_Overview.md`](file:///d:/SQL/DP-800%20Microsoft%20SQL%20Server%20AI%20Developer/Documents_Guide/DP800_00_Exam_Roadmap_Overview.md) *(File này)*
2. [`DP800_Domain1_Database_Design_01_Database_Objects.md`](file:///d:/SQL/DP-800%20Microsoft%20SQL%20Server%20AI%20Developer/Documents_Guide/DP800_Domain1_Database_Design_01_Database_Objects.md)
3. [`DP800_Domain1_Database_Design_02_Programmability_Advanced_TSQL.md`](file:///d:/SQL/DP-800%20Microsoft%20SQL%20Server%20AI%20Developer/Documents_Guide/DP800_Domain1_Database_Design_02_Programmability_Advanced_TSQL.md)
4. [`DP800_Domain1_Database_Design_03_AIAssisted_Tools.md`](file:///d:/SQL/DP-800%20Microsoft%20SQL%20Server%20AI%20Developer/Documents_Guide/DP800_Domain1_Database_Design_03_AIAssisted_Tools.md) *(Trọng điểm yếu #1)*
5. [`DP800_Domain2_Security_Optimization_04_Data_Security_Compliance.md`](file:///d:/SQL/DP-800%20Microsoft%20SQL%20Server%20AI%20Developer/Documents_Guide/DP800_Domain2_Security_Optimization_04_Data_Security_Compliance.md)
6. [`DP800_Domain2_Security_Optimization_05_Performance_Optimization.md`](file:///d:/SQL/DP-800%20Microsoft%20SQL%20Server%20AI%20Developer/Documents_Guide/DP800_Domain2_Security_Optimization_05_Performance_Optimization.md)
7. [`DP800_Domain2_Security_Optimization_06_CICD_SQL_Projects.md`](file:///d:/SQL/DP-800%20Microsoft%20SQL%20Server%20AI%20Developer/Documents_Guide/DP800_Domain2_Security_Optimization_06_CICD_SQL_Projects.md)
8. [`DP800_Domain2_Security_Optimization_07_Azure_Services_Integration.md`](file:///d:/SQL/DP-800%20Microsoft%20SQL%20Server%20AI%20Developer/Documents_Guide/DP800_Domain2_Security_Optimization_07_Azure_Services_Integration.md) *(Trọng điểm yếu #2)*
9. [`DP800_Domain3_AI_Capabilities_08_Models_Embeddings.md`](file:///d:/SQL/DP-800%20Microsoft%20SQL%20Server%20AI%20Developer/Documents_Guide/DP800_Domain3_AI_Capabilities_08_Models_Embeddings.md)
10. [`DP800_Domain3_AI_Capabilities_09_Intelligent_Search.md`](file:///d:/SQL/DP-800%20Microsoft%20SQL%20Server%20AI%20Developer/Documents_Guide/DP800_Domain3_AI_Capabilities_09_Intelligent_Search.md)
11. [`DP800_Domain3_AI_Capabilities_10_RAG_Pipeline.md`](file:///d:/SQL/DP-800%20Microsoft%20SQL%20Server%20AI%20Developer/Documents_Guide/DP800_Domain3_AI_Capabilities_10_RAG_Pipeline.md)

---

## 💡 5. Mẹo Chiến Thuật Làm Bài Thi DP-800

1. **Phân biệt câu hỏi Single Choice vs Multiple Choice vs Drag-and-Drop vs Hotspot:**
   - Dạng bài ghép lệnh SQL hoặc sắp xếp các bước (ví dụ: Các bước cấu hình RAG hay Always Encrypted): Hãy thuộc lòng thứ tự các bước trong phần Lab của tài liệu này!
2. **Kỹ thuật chọn đáp án bảo mật (Security Best Practices):**
   - Không chọn giải pháp hardcode Password/API Key.
   - Luôn chọn **Managed Identity** (Passwordless) và **Database Scoped Credential** khi tích hợp dịch vụ Azure (Azure OpenAI, Azure Key Vault, DAB).
3. **Từ khóa bẫy trong câu hỏi (Exam Trap Words):**
   - *Minimal logging / Analytic queries / DW workload* ➔ chọn **Columnstore Index**.
   - *Low latency / High concurrency OLTP* ➔ chọn **In-Memory OLTP (Memory-Optimized Table)**.
   - *Tamper-evident / Audit trail compliance* ➔ chọn **Ledger Table**.
   - *Exact match string vs Regex* ➔ chọn **CHECK constraint** chứa `REGEXP_LIKE`.
   - *Detect schema drift without modifying database* ➔ chọn `SqlPackage.exe /Action:DriftReport`.
