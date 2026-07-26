# CẨM NANG CHUYÊN SÂU ÔN THI DP-800: SECURE, OPTIMIZE & DEPLOY DATABASE SOLUTIONS (35–40%)
> **Tác giả:** Expert Database Solutions Architect (10+ năm kinh nghiệm Microsoft SQL Server & Azure Data Platform)  
> **Phân loại:** MODULE 2 — LÝ THUYẾT & MẸO THI  
> **Kỳ thi:** DP-800: Developing AI-Enabled Database Solutions (Cập nhật mới nhất tháng 03/2026)  
> **File thực hành SQL đính kèm:**  
> - 📄 [Antigravity_DP800_Mod2_Lab01_Security_Optimization_Deploy.sql](file:///d:/SQL/DP-800%20Microsoft%20SQL%20Server%20AI%20Developer/Antigravity_DP800_Mod2_Lab01_Security_Optimization_Deploy.sql)

---

## 📌 TỔNG QUAN VỀ MIỀN KỸ NĂNG NÀY (35–40%)

Miền kiến thức **"Secure, optimize, and deploy database solutions"** chiếm 35–40% tổng số điểm của kỳ thi DP-800. Miền này bao gồm 4 mảng chiến lược:
1. **Bảo mật & Tuân thủ (Data Security & Compliance):** Mã hóa (Always Encrypted), Dynamic Data Masking (DDM), Row-Level Security (RLS), Passwordless Access, Auditing, và Bảo mật MCP / Model Endpoints.
2. **Tối ưu hóa hiệu năng (Database Performance Optimization):** Isolation Levels, Concurrency Controls, Query Store, DMVs, và Xử lý Deadlocks/Blocking.
3. **Quy trình CI/CD với SQL Database Projects:** SDK-style models, Unit testing, Branching policy, Static data management, Schema drift, và Deployment pipelines.
4. **Tích hợp dịch vụ Azure (Azure Integration & DAB):** Data API Builder (DAB - REST/GraphQL), Azure Monitor, và Event Streaming (CDC, Change Tracking, Azure Functions SQL Trigger Binding).

---

## 🔒 CHUYÊN ĐỀ 1: IMPLEMENT DATA SECURITY AND COMPLIANCE

### 1. Giải pháp mã hóa & Bảo vệ dữ liệu
* **Always Encrypted (Mã hóa phía Client):**
  * Mã hóa dữ liệu nhạy cảm ở phía Client trước khi gửi tới SQL Server. Key mã hóa (Column Master Key - CMK) nằm ở **Azure Key Vault**, SQL Server hoàn toàn không giữ key.
  * Phân biệt **Randomized Encryption** (Bảo mật cao nhất nhưng không thể JOIN/GROUP BY) và **Deterministic Encryption** (Cho phép equality lookup `=`).
* **Dynamic Data Masking (DDM):**
  * Che mờ dữ liệu ở tầng hiển thị cho User không có quyền `UNMASK`.
  * Dữ liệu vật lý lưu dưới đĩa **không bị thay đổi**.
  * Các hàm Masking: `default()`, `email()`, `partial(prefix, padding, suffix)`, `random(start, end)`.

---

### 2. Row-Level Security (RLS) & Granular Permissions
* **Kiến trúc RLS trong DP-800:**
  * Bao gồm một **Inline Table-Valued Function (Filter/Block Predicate)** và một **SECURITY POLICY**.
  * **FILTER PREDICATE:** Quyết định dòng dữ liệu nào user được phép đọc (`SELECT`) hoặc sửa (`UPDATE/DELETE`).
  * **BLOCK PREDICATE:** Ngăn chặn người dùng cố tình `INSERT` hoặc `UPDATE` dữ liệu vi phạm điều kiện chi nhánh/quyền hạn.
* **Bảo mật Endpoint & Access Control:**
  * Khuyến khích dùng **Passwordless Authentication** (Azure Active Directory / Entra ID Managed Identity) thay cho SQL Authentication truyền thống.
  * **Bảo mật MCP (Model Context Protocol) & GraphQL Endpoints:** Áp dụng RBAC (Role-Based Access Control) và OAuth2 Token Validation trên DAB/REST gateways.

---

## ⚡ CHUYÊN ĐỀ 2: OPTIMIZE DATABASE PERFORMANCE

### 1. Concurrency Controls & Transaction Isolation Levels

| Isolation Level | Phenom Prevented (Tránh được hiện tượng) | Lock Mechanism / Behavior | Trường hợp sử dụng tối ưu |
| :--- | :--- | :--- | :--- |
| **Read Committed (Default)** | Dirty Reads | Dùng Shared Lock ngắn hạn khi đọc. Có thể gây Blocking giữa Reader & Writer. | Giao dịch OLTP mặc định. |
| **Read Committed Snapshot (RCSI)** | Dirty Reads + Reader/Writer Blocking | Dùng **Row Versioning trong TempDB**. Reader KHÔNG khóa Writer, Writer KHÔNG khóa Reader. | **Lựa chọn hàng đầu trên Azure SQL** cho hệ thống tải cao. |
| **Snapshot Isolation (SI)** | Dirty Reads, Non-repeatable Reads, Phantom Reads | Lưu Version snapshot tại thời điểm bắt đầu Transaction. | Báo cáo giao dịch phức tạp cần tính nhất quán tuyệt đối. |
| **Serializable** | Tất cả (Dirty, Non-repeatable, Phantom) | Dùng Key-Range Lock. Đảm bảo tính tuần tự tuyệt đối nhưng nguy cơ Blocking/Deadlock rất cao. | Hệ thống tài chính cực kỳ nghiêm ngặt. |

---

### 2. Chẩn đoán hiệu năng với DMVs & Query Store
* **DMVs quan trọng khi đi thi:**
  * `sys.dm_exec_requests`: Xem các request đang thực thi, `wait_type`, `wait_time`, `blocking_session_id`.
  * `sys.dm_tran_locks`: Kiểm tra chi tiết các tài nguyên đang bị khóa (Exclusive / Shared / Intent locks).
  * `sys.dm_db_index_usage_stats`: Phát hiện index thừa (không được read nhưng phải write) hoặc thiếu index.
* **Query Store (Bộ nhớ lưu trữ truy vấn):**
  * Tự động lưu lịch sử Execution Plans và Runtime Statistics.
  * **Parameter Sniffing:** Hiện tượng SQL biên dịch plan dựa trên giá trị tham số lần đầu, gây chậm khi tham số sau có phân bố dữ liệu khác. Khắc phục bằng Query Store (Force Plan) hoặc dùng `OPTION (RECOMPILE)` / `OPTION (OPTIMIZE FOR...)`.

---

## 🛠️ CHUYÊN ĐỀ 3: IMPLEMENT CI/CD WITH SQL DATABASE PROJECTS

* **SDK-Style SQL Database Projects (`.sqlproj`):**
  * Định nghĩa cấu trúc database dưới dạng mã nguồn (Infrastructure as Code).
  * Biên dịch thành tệp **`.dacpac`** để triển khai tự động qua CI/CD Pipeline (Azure DevOps / GitHub Actions).
* **Quản lý dữ liệu tĩnh & Schema Drift:**
  * Sử dụng **Post-Deployment Scripts** kết hợp câu lệnh `MERGE` để đồng bộ dữ liệu danh mục tĩnh (Reference/Static Data).
  * **Schema Drift Detection:** So sánh `.dacpac` phát sinh từ codebase với Live Database để phát hiện thay đổi trái phép ngoài pipeline.

---

## 🌐 CHUYÊN ĐỀ 4: INTEGRATE SQL SOLUTIONS WITH AZURE SERVICES & DAB

### 1. Data API Builder (DAB - REST & GraphQL)
* **Khái niệm:** Dịch vụ mã nguồn mở của Microsoft giúp tạo REST và GraphQL APIs trực tiếp từ SQL Server / Azure SQL mà **không cần viết code backend**.
* **Cấu hình DAB (`dab-config.json`):**
  * Định nghĩa entities từ Tables, Views, Stored Procedures.
  * Hỗ trợ **GraphQL Relationships** (kết nối giữa các entity), Data Caching, Pagination (First/After cursor), Searching, và Filtering.

### 2. Theo Dõi Thay Đổi Dữ Liệu (Data Change Tracking)

```
                       ┌──► Change Tracking (CT)  ──► Chỉ lưu PK + Version (Nhẹ)
Data Change Events ────┼──► Change Data Capture (CDC) ──► Lưu đầy đủ dữ liệu Cũ/Mới (Audit)
                       └──► Change Event Streaming (CES) ──► Event Grid / Azure Functions Binding
```

* **Azure Functions SQL Trigger Binding:** Tự động kích hoạt Serverless Function mỗi khi có sự kiện DML trên bảng SQL thông qua Change Tracking.

---
*Tiếp tục học phần AI & Vector tại Cẩm nang Module 3!*
