# DP-800 Domain 2: Optimize Database Performance

> **Miền 2:** Secure, Optimize, and Deploy Database Solutions (35–40%)  
> **Chủ đề:** Optimize Database Performance  
> **Trọng tâm thi:** Query Store (kể cả Secondary Replicas), Execution Plans, Parameter Sniffing, Isolation Levels (RCSI/Snapshot), Resolving Blocking & Deadlocks.

---

## 📘 PHẦN 1: LÝ THUYẾT & KIẾN THỨC CỐT LÕI (CORE THEORY)

### 1. Cấu Hình Cơ Sở Dữ Liệu (Database Configurations)
- **MAXDOP (Max Degree of Parallelism):** Giới hạn số CPU core sử dụng cho 1 câu truy vấn song song. Tránh đặt MAXDOP quá cao gây CPU contention (CXPACKET wait).
- **Cost Threshold for Parallelism:** Giá trị ngưỡng chi phí để Query Optimizer chuyển truy vấn sang chạy song song (khuyên dùng 25-50 thay cho mặc định 5).
- **Read Committed Snapshot Isolation (RCSI):**  
  Bật RCSI trên CSDL (`READ_COMMITTED_SNAPSHOT ON`) để các thao tác đọc (`SELECT`) sử dụng **Row Versioning** trong TempDB. **Reader không chặn Writer, Writer không chặn Reader** ➔ Giải quyết triệt để vấn đề Blocking trong OLTP.

### 2. Isolation Levels & Concurrency Controls
- **Read Uncommitted (Dirty Read):** Đọc dữ liệu chưa commit (nhiễm bẩn).
- **Read Committed (Mặc định):** Đọc dữ liệu đã commit, có thể bị Non-repeatable read.
- **Repeatable Read:** Giữ Shared Lock đến cuối transaction ➔ Ngăn sửa đổi dòng đã đọc.
- **Serializable:** Giữ Range Lock ➔ Ngăn dòng mới chèn vào (Ngăn Phantom Read).
- **Snapshot Isolation:** Sử dụng phiên bản dòng trong TempDB ➔ Bảo đảm tính nhất quán giao dịch mà không bị lock.

### 3. Đánh Giá Hiệu Năng Truy Vấn (Query Performance Evaluation)
- **Execution Plan Analysis:**
  - *Clustered Index Seek vs Scan:* Seek là truy cập trực tiếp cực nhanh; Scan là đọc toàn bộ index.
  - *Key Lookup / Bookmark Lookup:* Xảy ra khi Nonclustered Index thiếu cột ➔ Cần bổ sung cột vào mệnh đề `INCLUDE`.
  - *Join Operators:* **Nested Loops** (Tốt cho tập dữ liệu nhỏ), **Hash Match** (Tốt cho dữ liệu lớn chưa sắp xếp), **Merge Join** (Tốt cho dữ liệu lớn đã sắp xếp sẵn).
- **Query Store & Query Store trên Secondary Replicas (Azure SQL / SQL Server 2022+):**
  - Query Store ghi lại lịch sử truy vấn, execution plan và chỉ số thời gian chạy.
  - *Plan Forcing:* Bắt buộc SQL Server luôn dùng một Execution Plan tốt nhất (`sp_query_store_force_plan`).
  - *Query Store Secondary Replicas (GA):* Telemetry của các truy vấn chạy trên **Read-Scale Out Secondary Replicas** được tự động hợp nhất về Query Store ở Primary Database!
- **Dynamic Management Views (DMVs):**
  - `sys.dm_exec_requests` & `sys.dm_exec_sql_text`: Xem các truy vấn đang chạy thực tế.
  - `sys.dm_db_index_usage_stats`: Phát hiện index thừa/không sử dụng.
  - `sys.dm_tran_locks`: Chẩn đoán Lock và Blocking.

### 4. Xử Lý Hiện Tượng Parameter Sniffing, Blocking & Deadlocks
- **Parameter Sniffing:** Xảy ra khi SQL Server biên dịch Execution Plan dựa trên giá trị tham số của lần chạy đầu tiên. Khi tham số lần sau thay đổi bản chất dữ liệu, plan cũ trở nên cực kỳ chậm.
  - *5 Cách xử lý:*
    1. Dùng hint `OPTION (RECOMPILE)` trong SQL.
    2. Dùng hint `OPTION (OPTIMIZE FOR (@Param = 'Val'))`.
    3. Thêm biến cục bộ (Local Variable) trong Stored Procedure.
    4. Dùng **Query Store Hints** ép hint mà không cần sửa mã nguồn ứng dụng.
    5. Tính năng **Parameter Sensitive Plan (PSP) Optimization** trong SQL Server 2022 (tự động tạo nhiều plan cho 1 SP).
- **Blocking & Deadlocks:**
  - *Blocking:* Truy vấn A giữ Lock khiến truy vấn B phải chờ. Giải pháp: Rút ngắn transaction, bật RCSI.
  - *Deadlock:* Truy vấn A chờ B, B lại chờ A ➔ SQL Server tự động kill một giao dịch (Deadlock Victim). Giải pháp: Truy cập các bảng theo thứ tự nhất quán trong mọi Stored Procedure.

---

## 💻 PHẦN 2: THỰC HÀNH T-SQL (HANDS-ON LABS)

```sql
-- ============================================================================
-- LAB 5.1: BẬT RCSI ĐỂ GIẢM BLOCKING & QUERY STORE
-- ============================================================================
USE master;
GO

-- 1. Bật Read Committed Snapshot Isolation (RCSI)
ALTER DATABASE tempdb SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO

-- 2. Bật Query Store trên Database
ALTER DATABASE tempdb SET QUERY_STORE = ON (
    OPERATION_MODE = READ_WRITE,
    DATA_FLUSH_INTERVAL_SECONDS = 60,
    INTERVAL_LENGTH_MINUTES = 5
);
GO

-- ============================================================================
-- LAB 5.2: XỬ LÝ PARAMETER SNIFFING BẰNG QUERY STORE HINTS (KHÔNG SỬA CODE)
-- ============================================================================
-- Trường hợp SP bị Parameter Sniffing
CREATE PROCEDURE dbo.sp_GetCustomerOrders @CustomerId INT
AS
BEGIN
    SELECT OrderId, OrderDate, TotalAmount
    FROM dbo.Orders
    WHERE CustomerId = @CustomerId;
END;
GO

-- Áp dụng Query Store Hint ép Recompile mà không cần sửa SP
EXEC sys.sp_query_store_set_hints 
    @query_id = 42, 
    @query_hint = N'OPTION (RECOMPILE)';
GO

-- ============================================================================
-- LAB 5.3: TRUY VẤN DMVS CHẨN ĐOÁN QUERY CHẬM & BLOCKING
-- ============================================================================
-- Xem Top 10 Truy vấn tốn CPU nhất trong Cache
SELECT TOP (10)
    qs.total_worker_time / qs.execution_count AS AvgCPU_Time,
    qs.execution_count,
    qs.total_logical_reads / qs.execution_count AS AvgLogicalReads,
    SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset
         END - qs.statement_start_offset)/2) + 1) AS QueryText
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
ORDER BY AvgCPU_Time DESC;
GO
```

---

## 📝 PHẦN 3: CÂU HỎI THI THỬ & TÌNH HUỐNG (MOCK TEST QUESTIONS)

#### Question 1 (Query Store Read-Scale Out Scenario):
**Scenario:** Your Azure SQL Database uses Read-Scale Out to offload read-only reporting queries to a Secondary Replica. Report users complain that certain queries running on the Secondary Replica are experiencing sudden performance degradation. You want to use Query Store to analyze execution plan regressions for queries executed on the Secondary Replica. Where should you look for this Query Store telemetry?
- A. Connect to the Primary Database and open Query Store.
- B. Connect to the TempDB of the Secondary Replica and query DMVs.
- C. Query Store is unavailable on Secondary Replicas and cannot capture secondary workload data.
- D. Enable Extended Events on the Client Application Machine.

**👉 Correct Answer: A**  
*Explanation (Giải thích):* Trong Azure SQL Database và SQL Server 2022+, tính năng **Query Store for Secondary Replicas** đã GA. Toàn bộ thông tin telemetry và execution plan của các câu truy vấn chạy trên Secondary Replica sẽ tự động được hợp nhất (consolidate) về **Query Store nằm tại Primary Database**.

---

#### Question 2 (Parameter Sniffing Resolution Scenario):
**Scenario:** A critical stored procedure `dbo.GetOrdersByDate` exhibits severe performance fluctuations. When executed with a date range returning 5 rows, it runs in 10 milliseconds. However, when executed with a date range returning 500,000 rows, it locks up the database due to an inefficient plan cached from the small parameter run. You cannot modify the application source code calling the stored procedure. How can you resolve this Parameter Sniffing issue?
- A. Enable Dynamic Data Masking on the date column.
- B. Use `sp_query_store_set_hints` to apply `OPTION (RECOMPILE)` directly to the query ID in Query Store.
- C. Drop and recreate the Primary Key.
- D. Set the database isolation level to READ UNCOMMITTED.

**👉 Correct Answer: B**  
*Explanation (Giải thích):* Khi không thể sửa mã nguồn ứng dụng (application code), công cụ **Query Store Hints** (`sp_query_store_set_hints`) cho phép DBA can thiệp và gán trực tiếp query hint (như `OPTION (RECOMPILE)` hoặc `OPTIMIZE FOR`) vào Query ID đã ghi nhận trong Query Store.

---

#### Question 3 (Concurrency & Blocking Mitigation Scenario):
**Scenario:** An OLTP database suffers from severe blocking between long-running `SELECT` reporting queries and frequent `UPDATE` transactions. Modifying the queries to include `WITH (NOLOCK)` is rejected by the compliance team because dirty reads are unacceptable. What database configuration change eliminates reader-writer blocking while maintaining read consistency?
- A. Set `MAXDOP = 1` on the database level.
- B. Enable `READ_COMMITTED_SNAPSHOT` (RCSI) on the database.
- C. Rebuild all indexes with `DATA_COMPRESSION = PAGE`.
- D. Change the database compatibility level to SQL Server 2014.

**👉 Correct Answer: B**  
*Explanation (Giải thích):* Bật **Read Committed Snapshot Isolation (RCSI)** giúp SQL Server sử dụng công nghệ Row Versioning trong TempDB cho truy vấn `SELECT`. Người đọc (Reader) đọc phiên bản dữ liệu đã commit gần nhất mà không cần xin Lock, loại bỏ hoàn toàn hiện tượng Reader bị Writer chặn (và ngược lại) mà không bị Dirty Read như `NOLOCK`.
