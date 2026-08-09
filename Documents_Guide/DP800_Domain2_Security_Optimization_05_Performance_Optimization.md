# DP-800 Domain 2: Optimize Database Performance

> **Miền 2:** Secure, Optimize, and Deploy Database Solutions (35–40%)  
> **Chủ đề:** Optimize Database Performance  
> **Cập nhật:** 09/08/2026  
> **Blueprint áp dụng:** DP-800 — Skills measured as of March 12, 2026  
> **Mục tiêu:** Hiểu nguyên nhân → đo bằng đúng công cụ → chọn biện pháp ít rủi ro nhất.

---

## 0. PHẠM VI THI CHÍNH THỨC

DP-800 yêu cầu:

1. **Recommend database configurations**.
2. Bảo toàn data integrity/consistency bằng **transaction isolation levels** và concurrency controls.
3. Đánh giá hiệu năng bằng **execution plans, DMVs, Query Store, Query Performance Insight**.
4. Xác định và xử lý **blocking và deadlocks**.

**Nguồn chuẩn:**
- [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
- [Microsoft Learn — Optimize database performance](https://learn.microsoft.com/en-us/training/modules/optimize-database-performance/)

---

# PHẦN 1 — DATABASE CONFIGURATION

## 1. Azure SQL purchasing/service tiers — phải biết để “recommend configuration”

### 1.1 DTU vs vCore

- **DTU model:** gộp CPU/memory/I/O vào DTU; đơn giản nhưng ít tách bạch.
- **vCore model:** chọn compute rõ hơn, phù hợp phần lớn thiết kế hiện đại và dễ map nhu cầu tài nguyên/licensing hơn.

### 1.2 Service tiers theo vCore

| Tier | Storage/HA hiện hành | Chọn khi |
|---|---|---|
| General Purpose | remote premium storage, thường 5–10 ms; 1–4 TB; không có built-in read scale-out replica | cần cost/performance cân bằng, workload phổ thông |
| Business Critical | local SSD, thường 1–2 ms; 1–4 TB; ba secondary replicas và một read-only replica không tính thêm compute | OLTP cần I/O latency thấp, failover nhanh hoặc offload một read workload |
| Hyperscale | compute/storage tách rời + local SSD cache; tự tăng storage đến 128 TB; có thể cấu hình nhiều HA/read replicas | workload mới/modernized cần scale storage/read/HA linh hoạt, không chỉ database “đã rất lớn” |

> **Cập nhật quan trọng:** Microsoft hiện mô tả Hyperscale là tier được khuyến nghị và mặc định cho các OLTP/HTAP workload mới hoặc đang hiện đại hóa. Tuy vậy, không chọn máy móc: General Purpose vẫn phù hợp khi ưu tiên chi phí; Business Critical phù hợp khi cần local-SSD latency/In-Memory OLTP. Các giới hạn còn phụ thuộc hardware/region/resource limit cụ thể.

### 1.3 Provisioned vs Serverless

- **Provisioned:** compute luôn sẵn sàng; workload ổn định.
- **Serverless:** auto-scale và tính compute theo mức sử dụng từng giây; phù hợp **single database** có workload gián đoạn, khó đoán và chịu được warm-up.

Serverless hiện có trên **General Purpose và Hyperscale**, không có trên Business Critical; chỉ **General Purpose serverless** hỗ trợ auto-pause/auto-resume. Vì vậy, “serverless” không đồng nghĩa “database chắc chắn auto-pause”. Khi paused, compute cost bằng 0 nhưng storage vẫn tính phí; ứng dụng phải có retry logic cho quá trình resume.

> Exam không chỉ hỏi “query chậm sửa index gì”; có thể hỏi **resource/service tier** không phù hợp.

Tham khảo:

- [Azure SQL Database purchasing models](https://learn.microsoft.com/en-us/azure/azure-sql/database/purchasing-models?view=azuresql)
- [vCore service tiers](https://learn.microsoft.com/en-us/azure/azure-sql/database/service-tiers-sql-database-vcore?view=azuresql)
- [Serverless compute tier](https://learn.microsoft.com/en-us/azure/azure-sql/database/serverless-tier-overview?view=azuresql)

---

## 2. MAXDOP, compatibility level, automatic tuning và ADR

### 2.1 MAXDOP

`MAXDOP` giới hạn số scheduler dùng cho một parallel plan. Không có một con số “25–50” hay “MAXDOP = X” đúng cho mọi hệ thống.

Database-scoped:

```sql
ALTER DATABASE SCOPED CONFIGURATION
SET MAXDOP = 8;
GO
```

**Exam principle:** chọn theo workload/topology; tránh “tăng MAXDOP = query luôn nhanh hơn”.

Trên **Azure SQL Database** và **SQL database in Fabric**, database mới mặc định `MAXDOP = 8`; đây là default, không phải magic number bắt buộc cho mọi workload. Kiểm tra trước khi thay đổi và load-test với concurrency thực tế:

```sql
SELECT name, value, value_for_secondary
FROM sys.database_scoped_configurations
WHERE name = N'MAXDOP';
GO
```

Nguồn: [Configure MAXDOP in Azure SQL Database and Fabric SQL database](https://learn.microsoft.com/en-us/azure/azure-sql/database/configure-max-degree-of-parallelism?view=azuresql)

### 2.2 Compatibility level

Compatibility level mở/đóng nhiều optimizer behavior mới.

```sql
SELECT name, compatibility_level
FROM sys.databases
WHERE name = DB_NAME();
GO

ALTER DATABASE CURRENT
SET COMPATIBILITY_LEVEL = 170;
GO
```

Với SQL Server/Azure SQL mới, compatibility level 170 gắn với các optimizer improvements mới. **Không nâng production chỉ để “lấy tính năng” mà không test regression.**

### 2.3 Automatic tuning — Azure SQL

Các lựa chọn đáng nhớ:
- `FORCE_LAST_GOOD_PLAN`
- `CREATE_INDEX`
- `DROP_INDEX`

Ví dụ:

```sql
ALTER DATABASE CURRENT
SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = ON);
GO
```

Điểm thi: automatic tuning có thể tự khắc phục plan regression, nhưng vẫn phải hiểu Query Store/telemetry.

**Defaults/availability dễ nhầm:** Azure defaults cho server mới là `FORCE_LAST_GOOD_PLAN = ON`, còn `CREATE_INDEX` và `DROP_INDEX` là `OFF`. Azure SQL Managed Instance hiện chỉ hỗ trợ automatic tuning option **FORCE LAST GOOD PLAN**; đừng chọn auto-create/drop index cho MI. SQL database in Fabric lại tự bật `CREATE INDEX`.

### 2.4 Optimize for ad hoc workloads

Khi có quá nhiều one-off ad hoc plans:

```sql
ALTER DATABASE SCOPED CONFIGURATION
SET OPTIMIZE_FOR_AD_HOC_WORKLOADS = ON;
GO
```

### 2.5 Accelerated Database Recovery (ADR)

ADR giúp recovery/rollback nhanh hơn bằng cơ chế versioning. Trên Azure SQL Database, ADR là phần nền tảng của dịch vụ. **Persistent Version Store (PVS)** nằm trong user database, khác row version store truyền thống trong `tempdb`.

Tham khảo: [Accelerated Database Recovery](https://learn.microsoft.com/en-us/sql/relational-databases/accelerated-database-recovery-concepts?view=sql-server-ver17)

---

# PHẦN 2 — TRANSACTION ISOLATION & CONCURRENCY

## 3. Bảng anomaly cần thuộc

| Isolation | Dirty read | Non-repeatable read | Phantom | Cơ chế dễ nhớ |
|---|---:|---:|---:|---|
| READ UNCOMMITTED | Có | Có | Có | đọc không chờ committed |
| READ COMMITTED | Không | Có | Có | mặc định truyền thống |
| REPEATABLE READ | Không | Không | Có | giữ shared locks lâu hơn |
| SERIALIZABLE | Không | Không | Không | range locks, chặt nhất |
| SNAPSHOT | Không | Không | Không theo transaction snapshot | row versions |
| RCSI | Không | Có thể thấy thay đổi giữa statement | Có thể | READ COMMITTED nhưng mỗi statement đọc snapshot |

### 3.1 RCSI ≠ SNAPSHOT

**RCSI**
- bật ở database.
- transaction vẫn dùng `READ COMMITTED`.
- mỗi statement đọc committed row version phù hợp.
- giảm mạnh **reader–writer blocking**.
- được bật mặc định cho database mới trong Azure SQL Database.

```sql
SELECT name,
       is_read_committed_snapshot_on,
       snapshot_isolation_state_desc
FROM sys.databases
WHERE name = DB_NAME();
GO

ALTER DATABASE YourDatabase
SET READ_COMMITTED_SNAPSHOT ON
WITH ROLLBACK IMMEDIATE;
GO
```

**SNAPSHOT**
- bật quyền sử dụng ở database.
- session/transaction phải chọn `SET TRANSACTION ISOLATION LEVEL SNAPSHOT`.
- snapshot nhất quán ở phạm vi transaction.

```sql
ALTER DATABASE YourDatabase
SET ALLOW_SNAPSHOT_ISOLATION ON;
GO

SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRAN;

SELECT ...;
-- các statement trong transaction dùng transaction snapshot

COMMIT;
GO
```

### Bẫy rất quan trọng

**RCSI không “xóa sạch mọi blocking”.** Nó chủ yếu giảm reader–writer blocking. Hai writer cùng sửa một row vẫn có thể block nhau; schema locks và các contention khác vẫn tồn tại.

Với `SNAPSHOT`, transaction đọc snapshot nhất quán nhưng có thể gặp **update conflict** khi cố cập nhật row đã bị transaction khác thay đổi sau thời điểm snapshot bắt đầu. Đây không phải cơ chế “last writer wins”; ứng dụng phải rollback/retry transaction phù hợp.

Nguồn: [Understand and resolve blocking in Azure SQL Database](https://learn.microsoft.com/en-us/azure/azure-sql/database/understand-resolve-blocking?view=azuresql)

### 3.2 Optimized locking — Azure SQL

Optimized locking giảm lock memory/lock footprint bằng Transaction ID locking và Lock After Qualification, phối hợp tốt với RCSI. Đừng nhầm nó với “không còn lock”.

Tham khảo: [Optimized locking in Azure SQL Database](https://learn.microsoft.com/en-us/azure/azure-sql/database/optimized-locking-overview?view=azuresql)

---

# PHẦN 3 — EXECUTION PLANS

## 4. Estimated vs Actual

- **Estimated plan:** optimizer estimate; query không cần thực thi để lấy runtime metrics.
- **Actual plan:** có runtime metrics sau khi chạy; dùng để so estimate vs actual.

### Operator mindset

- **Index Seek** thường tốt khi chọn ít row, nhưng seek không tự động tốt nếu phải lookup hàng triệu lần.
- **Scan** không tự động xấu; scan có thể là lựa chọn đúng khi cần phần lớn bảng hoặc columnstore scan.
- **Key Lookup** đáng chú ý khi lặp rất nhiều; có thể thêm `INCLUDE` hoặc thiết kế index khác.
- **Sort/Hash spill** và warning → xem memory grant/cardinality.
- Estimate lệch xa actual → nghĩ đến statistics/cardinality/parameter sensitivity.

### Covering index example

```sql
CREATE INDEX IX_Orders_Customer_OrderDate
ON dbo.Orders(CustomerId, OrderDate)
INCLUDE (Status, TotalAmount);
GO
```

Không tạo index chỉ vì “Missing Index hint nói vậy”. Phải xét write overhead, index overlap và workload.

Tham khảo: [Display and save execution plans](https://learn.microsoft.com/en-us/sql/relational-databases/performance/display-and-save-execution-plans?view=sql-server-ver17)

---

# PHẦN 4 — DMVs

## 5. Truy vấn đang chạy và blocking chain

```sql
SELECT
    r.session_id,
    r.status,
    r.command,
    r.wait_type,
    r.wait_time,
    r.blocking_session_id,
    DB_NAME(r.database_id) AS database_name,
    t.text AS sql_text
FROM sys.dm_exec_requests AS r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.session_id <> @@SPID
ORDER BY r.blocking_session_id DESC, r.session_id;
GO
```

### Top cached queries theo CPU trung bình

```sql
SELECT TOP (20)
    qs.execution_count,
    qs.total_worker_time,
    qs.total_worker_time / NULLIF(qs.execution_count, 0) AS avg_cpu,
    qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS avg_reads,
    SUBSTRING
    (
        st.text,
        (qs.statement_start_offset / 2) + 1,
        (
            (
                CASE qs.statement_end_offset
                    WHEN -1 THEN DATALENGTH(st.text)
                    ELSE qs.statement_end_offset
                END
                - qs.statement_start_offset
            ) / 2
        ) + 1
    ) AS statement_text
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
ORDER BY avg_cpu DESC;
GO
```

### Locks

```sql
SELECT *
FROM sys.dm_tran_locks;
GO
```

**Bẫy:** DMVs thường là “current/cache state”; Query Store cung cấp lịch sử bền vững hơn cho regression analysis.

---

# PHẦN 5 — QUERY STORE & QUERY PERFORMANCE INSIGHT

## 6. Query Store

Query Store lưu:
- query text/identity,
- execution plans,
- runtime statistics,
- wait statistics (nếu capture),
- lịch sử theo thời gian.

### Enable/configure trên USER DATABASE

> Không dùng `tempdb` làm lab Query Store.

```sql
ALTER DATABASE YourDatabase
SET QUERY_STORE = ON
(
    OPERATION_MODE = READ_WRITE,
    DATA_FLUSH_INTERVAL_SECONDS = 60,
    INTERVAL_LENGTH_MINUTES = 15
);
GO

ALTER DATABASE YourDatabase
SET QUERY_STORE
(
    WAIT_STATS_CAPTURE_MODE = ON
);
GO
```

### Force/unforce plan

```sql
EXEC sys.sp_query_store_force_plan
    @query_id = 123,
    @plan_id = 456;
GO

EXEC sys.sp_query_store_unforce_plan
    @query_id = 123,
    @plan_id = 456;
GO
```

### Query Store hints — sửa behavior mà không đổi source code

```sql
EXEC sys.sp_query_store_set_hints
    @query_id = 123,
    @query_hints = N'OPTION(RECOMPILE)';
GO

EXEC sys.sp_query_store_clear_hints
    @query_id = 123;
GO
```

> **Cú pháp cần nhớ:** tham số hiện hành là `@query_hints` (số nhiều).

### Query Store on readable secondaries

SQL Server/Azure SQL hỗ trợ thu thập workload trên readable secondary trong các cấu hình/version được hỗ trợ; runtime information được đưa về Query Store của primary để lưu trữ. Các khả năng hint/replica-specific phụ thuộc phiên bản — đặc biệt SQL Server 2025 bổ sung khả năng phong phú hơn.

Tham khảo:
- [Monitor performance with Query Store](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)
- [Query Store hints](https://learn.microsoft.com/en-us/sql/relational-databases/performance/query-store-hints?view=sql-server-ver17)
- [Query Store for readable secondaries](https://learn.microsoft.com/en-us/sql/relational-databases/performance/query-store-for-secondary-replicas?view=sql-server-ver17)

---

## 7. Query Performance Insight (QPI)

QPI là trải nghiệm trong Azure portal dùng Query Store data để:
- thấy top resource-consuming queries,
- theo dõi CPU/duration/executions theo thời gian,
- tìm query cần tune.

**Nếu câu hỏi nói “Azure portal, identify top queries visually without writing DMV query” → nghĩ đến Query Performance Insight.**

Tham khảo: [Query Performance Insight](https://learn.microsoft.com/en-us/azure/azure-sql/database/query-performance-insight-use?view=azuresql)

---

# PHẦN 6 — PARAMETER SENSITIVITY

## 8. Parameter sniffing / Parameter Sensitive Plan (PSP)

Classic parameter sniffing:
1. SP compile với parameter A.
2. Optimizer cache plan tốt cho A.
3. Parameter B có data distribution rất khác.
4. Reuse plan A → chậm.

### Các lựa chọn

```sql
-- Chỉ statement này compile lại mỗi lần
SELECT ...
FROM dbo.Orders
WHERE CustomerId = @CustomerId
OPTION (RECOMPILE);
GO
```

```sql
-- Dùng khi bạn có giá trị đại diện rõ ràng
OPTION (OPTIMIZE FOR (@CustomerId = 100));
```

Hoặc **Query Store Hint** nếu không sửa code.

**PSP Optimization** (compatibility level phù hợp, SQL Server 2022+) có thể tạo nhiều plan variants cho parameter-sensitive equality predicates thay vì ép một plan cho mọi distribution.

**SQL Server 2025 / compatibility 170:** thêm optimizer enhancements như Optional Parameter Plan Optimization (OPPO) cho một số optional predicate patterns. Đừng dùng kiến thức này thay cho việc hiểu Query Store/PSP cơ bản.

Tham khảo: [Parameter Sensitive Plan optimization](https://learn.microsoft.com/en-us/sql/relational-databases/performance/parameter-sensitive-plan-optimization?view=sql-server-ver17)

---

# PHẦN 7 — BLOCKING & DEADLOCKS

## 9. Blocking

Blocking không đồng nghĩa với bug; lock chờ là phần bình thường của concurrency. Vấn đề là **blocking kéo dài / chain lớn / head blocker không hợp lý**.

### Checklist xử lý

1. Tìm `blocking_session_id`.
2. Xác định head blocker.
3. Xem transaction có mở quá lâu không.
4. Kiểm tra index/query có giữ lock trên quá nhiều row không.
5. Rút ngắn transaction.
6. Cân nhắc RCSI nếu vấn đề là reader–writer.
7. Không mặc định dùng `NOLOCK` vì dirty/inconsistent reads.

`SET XACT_ABORT ON` thường giúp transaction tự rollback khi runtime error thích hợp, tránh connection bỏ lại transaction chưa kết thúc:

```sql
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRAN;

    -- DML

    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK;
    THROW;
END CATCH;
GO
```

---

## 10. Deadlocks

Deadlock = cycle:
- T1 giữ A, chờ B.
- T2 giữ B, chờ A.
- SQL chọn một **victim**, trả lỗi 1205.

### Cách giảm

- Các code path truy cập object theo **cùng thứ tự**.
- Transaction ngắn.
- Index tốt để giảm rows/locks.
- Retry ở application cho lỗi 1205.
- Capture deadlock graph, không đoán.

### Database-scoped Extended Events cho Azure SQL

```sql
CREATE EVENT SESSION DP800_Deadlocks
ON DATABASE
ADD EVENT sqlserver.database_xml_deadlock_report
ADD TARGET package0.ring_buffer;
GO

ALTER EVENT SESSION DP800_Deadlocks
ON DATABASE
STATE = START;
GO
```

Kiểm tra session/target:

```sql
SELECT *
FROM sys.dm_xe_database_sessions;
GO

SELECT *
FROM sys.dm_xe_database_session_targets;
GO
```

Tham khảo: [Deadlocks guide](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-deadlocks-guide?view=sql-server-ver17)

---

# PHẦN 8 — DECISION TABLE ĐI THI

| Scenario | Công cụ/giải pháp đầu tiên nên nghĩ |
|---|---|
| Query regression sau deployment | Query Store, compare plans, last good plan |
| Không sửa app code nhưng cần hint | Query Store Hints |
| Reader block writer, dirty read bị cấm | RCSI |
| Writer block writer | RCSI không đủ; tối ưu transaction/index/concurrency |
| Top queries trong Azure Portal | Query Performance Insight |
| “Query đang chạy ngay bây giờ” | DMVs |
| Cần historical plans/runtime | Query Store |
| Estimate lệch actual | Statistics/cardinality/parameter sensitivity |
| Same SP nhanh/chậm tùy parameter | PSP/Query Store/recompile strategy |
| Deadlock | deadlock graph/XE + consistent access order |
| Azure workload quá lớn so với service tier | scale/tier/resource configuration, không chỉ index |
| Ad hoc one-time plans làm plan cache phình | `OPTIMIZE_FOR_AD_HOC_WORKLOADS` |

---

# PHẦN 9 — MOCK QUESTIONS

### Câu 1
Reporting `SELECT` block OLTP `UPDATE`, nhưng compliance cấm dirty reads. Chọn?

**Đáp án:** RCSI.

### Câu 2
Sau khi bật RCSI, hai transaction cùng update một Order vẫn block. Có phải RCSI lỗi?

**Đáp án:** Không. Writer–writer blocking vẫn có thể xảy ra.

### Câu 3
Bạn không sửa được application code nhưng muốn `OPTION(RECOMPILE)` cho query đã có trong Query Store.

**Đáp án:** `sys.sp_query_store_set_hints` với `@query_hints`.

### Câu 4
Cần xem query nào tiêu thụ nhiều CPU nhất theo lịch sử trong Azure portal.

**Đáp án:** Query Performance Insight / Query Store tùy wording; nếu “portal visualization” → QPI.

### Câu 5
Execution plan có Scan. Có chắc phải thêm index?

**Đáp án:** Không. Scan có thể tối ưu khi cần nhiều rows; phải xét cardinality/cost/workload.

### Câu 6
Deadlock xảy ra giữa hai SP do chúng update bảng theo thứ tự ngược nhau.

**Đáp án:** Chuẩn hóa thứ tự truy cập object, rút ngắn transaction và capture deadlock graph để xác nhận.

### Câu 7
Query Store database chuyển READ_ONLY vì chạm quota.

**Đáp án:** Kiểm tra `sys.database_query_store_options`, retention/max size/cleanup và cấu hình lại phù hợp.

### Câu 8
Workload intermittent, có thời gian dài idle và muốn giảm compute cost trên tier hỗ trợ.

**Đáp án:** Cân nhắc serverless.

---

# PHẦN 10 — CHECKLIST “EXAM READY”

- [ ] Phân biệt DTU/vCore, General Purpose/Business Critical/Hyperscale.
- [ ] Phân biệt provisioned/serverless.
- [ ] Giải thích MAXDOP mà không đưa “magic number”.
- [ ] Phân biệt RCSI và SNAPSHOT.
- [ ] Biết RCSI không loại writer–writer blocking.
- [ ] Đọc estimated vs actual plan; Seek/Scan/Lookup.
- [ ] Dùng DMVs để tìm current requests/blocker.
- [ ] Enable Query Store trên user database.
- [ ] Force/unforce plan và dùng Query Store Hint.
- [ ] Nhớ tham số `@query_hints`.
- [ ] Biết Query Performance Insight dùng khi nào.
- [ ] Giải thích parameter sniffing/PSP.
- [ ] Capture và xử lý deadlock.
- [ ] Biết automatic tuning/ADR/optimized locking ở mức chọn scenario.

---

# TÀI LIỆU THAM KHẢO

1. [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
2. [Optimize database performance — Microsoft Learn](https://learn.microsoft.com/en-us/training/modules/optimize-database-performance/)
3. [Query Store](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)
4. [Query Store hints](https://learn.microsoft.com/en-us/sql/relational-databases/performance/query-store-hints?view=sql-server-ver17)
5. [Query Performance Insight](https://learn.microsoft.com/en-us/azure/azure-sql/database/query-performance-insight-use?view=azuresql)
6. [Automatic tuning](https://learn.microsoft.com/en-us/azure/azure-sql/database/automatic-tuning-overview?view=azuresql)
7. [Optimized locking](https://learn.microsoft.com/en-us/azure/azure-sql/database/optimized-locking-overview?view=azuresql)
8. [Deadlocks guide](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-deadlocks-guide?view=sql-server-ver17)
9. [vCore service tiers](https://learn.microsoft.com/en-us/azure/azure-sql/database/service-tiers-sql-database-vcore?view=azuresql)
10. [Serverless compute tier](https://learn.microsoft.com/en-us/azure/azure-sql/database/serverless-tier-overview?view=azuresql)
11. [Configure MAXDOP in Azure SQL Database/Fabric SQL](https://learn.microsoft.com/en-us/azure/azure-sql/database/configure-max-degree-of-parallelism?view=azuresql)
