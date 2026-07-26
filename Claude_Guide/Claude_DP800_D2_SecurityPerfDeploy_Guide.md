# DP-800 — MIỀN 2: BẢO MẬT, TỐI ƯU HÓA & TRIỂN KHAI (35–40%)

> **Cẩm nang ôn thi chuyên sâu** — góc nhìn Database Solutions Architect.
> **Nền tảng mục tiêu:** SQL Server 2022 / 2025 / Azure SQL Database / Azure SQL Managed Instance.
> **Bộ lab đi kèm:**
> - [Claude_DP800_D2_Lab01_Encryption.sql](./Claude_DP800_D2_Lab01_Encryption.sql)
> - [Claude_DP800_D2_Lab02_DDM_RLS_Permissions.sql](./Claude_DP800_D2_Lab02_DDM_RLS_Permissions.sql)
> - [Claude_DP800_D2_Lab03_Auditing.sql](./Claude_DP800_D2_Lab03_Auditing.sql)
> - [Claude_DP800_D2_Lab04_Performance.sql](./Claude_DP800_D2_Lab04_Performance.sql)
> - [Claude_DP800_D2_Lab05_Deployment_CICD.sql](./Claude_DP800_D2_Lab05_Deployment_CICD.sql)
> - [Claude_DP800_D2_Quiz.md](./Claude_DP800_D2_Quiz.md) — 60 câu tự kiểm tra kèm giải thích

---

## 0. CÁCH ĐỀ THI HỎI MIỀN NÀY

Miền 2 chiếm 35–40% → khoảng **18–24 câu**. Đây là miền **rộng nhất** và cũng là miền
thí sinh mất điểm nhiều nhất, vì nó trộn 3 nhóm kỹ năng khác hẳn nhau.

| Nhóm | Tỷ trọng ước lượng | Khuôn mẫu câu hỏi |
|---|---|---|
| **Bảo mật** | ~15% | "Yêu cầu X + ràng buộc Y → chọn cơ chế bảo vệ nào?" |
| **Tối ưu hiệu năng** | ~15% | "Triệu chứng Z → nguyên nhân + công cụ chẩn đoán + cách sửa" |
| **Triển khai / CI-CD / kiểm thử** | ~8% | "Sắp xếp bước", "chọn công cụ", "chiến lược migration" |

**Nguyên tắc vàng của miền bảo mật:** đọc kỹ **ai là kẻ tấn công trong đề bài**.
- Kẻ tấn công là **người có quyền đọc file/backup** (mất đĩa, mất băng) → **TDE**.
- Kẻ tấn công là **DBA / sysadmin** → **Always Encrypted** (hoặc Ledger cho toàn vẹn).
- Kẻ tấn công là **người dùng ứng dụng hợp lệ nhưng không được xem dữ liệu người khác** → **RLS**.
- Chỉ cần **che khi hiển thị**, không cần chống tấn công thật sự → **Dynamic Data Masking**.
- Cần **chứng minh chuyện gì đã xảy ra** → **SQL Audit** (không phải trigger).

Ba từ đó quyết định đáp án gần như tuyệt đối. Nếu đề nói "kể cả quản trị viên cơ sở
dữ liệu cũng không được xem" mà bạn chọn TDE hay DDM là **sai chắc chắn**.

---

## 1. BỨC TRANH TỔNG THỂ VỀ BẢO MẬT SQL SERVER

Bốn tầng, mỗi tầng trả lời một câu hỏi khác nhau. Đề thi luôn hỏi "tầng nào".

| Tầng | Câu hỏi nó trả lời | Công nghệ |
|---|---|---|
| **Authentication** | *Bạn là ai?* | SQL login, Windows/AD, Microsoft Entra ID, managed identity |
| **Authorization** | *Bạn được làm gì?* | GRANT/DENY/REVOKE, role, schema, ownership chaining |
| **Protection** | *Dữ liệu được bảo vệ ra sao?* | TDE, Always Encrypted, Backup encryption, TLS, DDM, RLS |
| **Auditing** | *Ai đã làm gì, khi nào?* | SQL Audit, Ledger, Extended Events, Change Tracking/CDC |

> 🎯 Đề hay đánh lừa bằng cách trộn tầng: "dữ liệu đã mã hoá TDE, tại sao DBA vẫn đọc được?"
> — Vì TDE là bảo vệ **at rest**; khi engine đọc lên bộ nhớ thì dữ liệu đã giải mã,
> mọi truy vấn hợp lệ đều thấy plaintext.

---

## 2. MÃ HOÁ (ENCRYPTION)

### 2.1. Bảng so sánh sống còn

| | **TDE** | **Always Encrypted** | **Column-level (cell)** | **Backup Encryption** |
|---|---|---|---|---|
| Bảo vệ khi | Dữ liệu **nằm yên** (at rest) | **Suốt vòng đời**: rest + transit + in use | At rest, trong cột | File backup |
| Ai KHÔNG đọc được | Người lấy được file `.mdf`/`.bak` | **Kể cả sysadmin/DBA/cloud operator** | Người không có khoá | Người có file backup |
| Nơi mã/giải mã | Engine (I/O layer) | **Client driver** | T-SQL (`ENCRYPTBYKEY`) | Engine khi ghi backup |
| Thay đổi ứng dụng | ❌ Không | ✅ Có (connection string `Column Encryption Setting=Enabled`) | ✅ Nhiều | ❌ Không |
| Phạm vi | Toàn **database** | Từng **cột** | Từng **cột/giá trị** | Từng **backup** |
| Truy vấn được không | Bình thường | Hạn chế (xem 2.3) | Phải giải mã thủ công | — |

> ⚠️ **TDE tự động mã hoá `tempdb`** của cả instance khi có bất kỳ DB nào bật TDE.
> ⚠️ TDE + backup: backup của DB có TDE **luôn được mã hoá**; muốn restore ở nơi khác
> phải mang theo **certificate + private key**, nếu không mất dữ liệu vĩnh viễn.
> ⚠️ TDE **không nén tốt** — nén backup gần như vô tác dụng (dữ liệu ngẫu nhiên hoá).

### 2.2. Chuỗi khoá (key hierarchy) — hay ra đề dạng sắp xếp

```
Service Master Key (SMK)   ← tạo tự động khi cài, bảo vệ bởi DPAPI của Windows
      ↓ bảo vệ
Database Master Key (DMK)  ← CREATE MASTER KEY ENCRYPTION BY PASSWORD (trong master)
      ↓ bảo vệ
Certificate / Asymmetric Key
      ↓ bảo vệ
Database Encryption Key (DEK)  ← nằm trong DB người dùng, thuật toán AES_256
      ↓ mã hoá
Dữ liệu (toàn bộ data file + log file)
```

**Trình tự bật TDE (thuộc lòng 5 bước):**
1. `USE master; CREATE MASTER KEY ENCRYPTION BY PASSWORD = '...';`
2. `CREATE CERTIFICATE TDECert WITH SUBJECT = '...';`
3. **`BACKUP CERTIFICATE` + private key ra nơi an toàn** ← quên bước này = mất DB khi phải restore
4. `USE MyDb; CREATE DATABASE ENCRYPTION KEY WITH ALGORITHM = AES_256 ENCRYPTION BY SERVER CERTIFICATE TDECert;`
5. `ALTER DATABASE MyDb SET ENCRYPTION ON;`

Theo dõi tiến độ: `sys.dm_database_encryption_keys` (`encryption_state`: 1=chưa mã, **2=đang mã**, **3=đã mã** ... 5=đang giải mã).

> 💡 **Azure SQL Database**: TDE **bật mặc định**, dùng service-managed key.
> Muốn tự kiểm soát → **Customer-Managed Key (CMK / BYOK)** đặt trong **Azure Key Vault**.
> Đề hỏi "khách hàng yêu cầu tự quản lý khoá mã hoá trên Azure SQL" ⇒ **CMK + Key Vault**.

### 2.3. Always Encrypted — chi tiết dễ mất điểm

Hai loại khoá:
- **Column Encryption Key (CEK)**: mã hoá dữ liệu cột, **lưu trong database** (ở dạng đã mã).
- **Column Master Key (CMK)**: mã hoá CEK, **lưu NGOÀI database** — Windows Certificate Store, **Azure Key Vault**, HSM. Đây chính là lý do DBA không giải mã được.

Hai kiểu mã hoá:

| | `DETERMINISTIC` | `RANDOMIZED` |
|---|---|---|
| Cùng plaintext → cùng ciphertext | ✅ | ❌ |
| Hỗ trợ | `=`, `JOIN`, `GROUP BY`, `DISTINCT`, index | **Không truy vấn được gì** ngoài `INSERT`/`SELECT` toàn cột |
| Rủi ro | Bị suy đoán qua phân tích tần suất | An toàn hơn |
| Collation bắt buộc | `_BIN2` cho cột chuỗi | — |

**Không bao giờ hỗ trợ (kể cả deterministic):** `LIKE`, `>` `<` `BETWEEN`, hàm chuỗi/toán học,
`SUM`/`AVG`, computed column tham chiếu cột đã mã, cột IDENTITY, sparse column set.

> 🎯 **Always Encrypted with Secure Enclaves** (SQL 2019+/Azure SQL): thêm vùng nhớ
> tin cậy trong engine ⇒ **hỗ trợ `LIKE`, so sánh dải, và mã hoá tại chỗ (in-place)**
> mà không cần tải dữ liệu về client. Đề hỏi "cần Always Encrypted nhưng vẫn phải chạy
> `LIKE`/range query" ⇒ **secure enclaves** (VBS enclave hoặc Intel SGX).

### 2.4. Các cơ chế khác cần biết tên

- **Backup encryption**: `BACKUP DATABASE ... WITH ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = Cert)` — độc lập TDE, dùng khi chỉ cần bảo vệ file backup.
- **TLS / Encrypt=True**: bảo vệ dữ liệu **đang truyền**. `Encrypt=True;TrustServerCertificate=False` là cấu hình đúng chuẩn (Azure SQL bắt buộc TLS).
- **EKM (Extensible Key Management)**: đưa khoá ra HSM/Key Vault ở SQL Server on-prem.

---

## 3. DYNAMIC DATA MASKING (DDM)

```sql
ALTER TABLE dbo.Customer
ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');
```

| Hàm mask | Kết quả mẫu | Dùng cho |
|---|---|---|
| `default()` | `xxxx` / `0` / `1900-01-01` | mọi kiểu |
| `email()` | `aXXX@XXXX.com` | email |
| `partial(2,"XXX",1)` | giữ 2 ký tự đầu + `XXX` + 1 ký tự cuối | CMND, số ĐT |
| `random(1,100)` | số ngẫu nhiên trong khoảng | kiểu số |
| `datetime("Y")` *(2022+)* | chỉ lộ phần năm | ngày tháng |

**Quy tắc thi về DDM:**
- Người có quyền **`UNMASK`** (và mọi thành viên `db_owner`/sysadmin) **luôn thấy dữ liệu thật**.
  Từ SQL 2022, `GRANT UNMASK ON schema/table/column` cho phép cấp ở mức chi tiết.
- DDM **KHÔNG mã hoá gì cả** — dữ liệu trên đĩa vẫn là plaintext.
- ⚠️ **DDM có thể bị vượt qua bằng suy luận**: kẻ tấn công có quyền `SELECT` vẫn dùng được
  `WHERE Salary > 100000` để dò từng giá trị, hoặc `SELECT ... INTO #t` rồi đọc bảng tạm
  (bảng tạm **không kế thừa mask** ở các bản cũ). ⇒ **DDM không phải biện pháp bảo mật thật sự**,
  chỉ chống lộ dữ liệu vô ý trên màn hình.
- Đề hỏi "che số thẻ tín dụng khỏi nhân viên hỗ trợ, không đổi ứng dụng, chấp nhận
  không cần chống tấn công chủ đích" ⇒ **DDM**. Nếu đề nói "phải chống được kẻ tấn công
  có quyền truy vấn" ⇒ **KHÔNG chọn DDM**.

---

## 4. ROW-LEVEL SECURITY (RLS)

### 4.1. Ba thành phần

```sql
-- (1) Hàm vị từ: BẮT BUỘC là inline TVF, WITH SCHEMABINDING
CREATE FUNCTION Security.fn_TenantPredicate(@TenantId INT)
RETURNS TABLE
WITH SCHEMABINDING
AS RETURN
    SELECT 1 AS ok
    WHERE @TenantId = CAST(SESSION_CONTEXT(N'TenantId') AS INT)
       OR IS_MEMBER('db_owner') = 1;          -- lối thoát cho quản trị

-- (2) Security policy gắn vị từ vào bảng
CREATE SECURITY POLICY Security.TenantFilter
ADD FILTER    PREDICATE Security.fn_TenantPredicate(TenantId) ON dbo.Orders,
ADD BLOCK     PREDICATE Security.fn_TenantPredicate(TenantId) ON dbo.Orders AFTER INSERT
WITH (STATE = ON);
```

### 4.2. FILTER vs BLOCK — phân biệt bắt buộc nhớ

| | `FILTER PREDICATE` | `BLOCK PREDICATE` |
|---|---|---|
| Tác dụng | **Ẩn** dòng khỏi `SELECT`/`UPDATE`/`DELETE` | **Chặn** và báo lỗi khi ghi |
| Người dùng thấy gì | Dòng "biến mất" im lặng, không báo lỗi | Msg 33504 — lỗi tường minh |
| Các thao tác | Áp cho đọc + ghi ngầm | `AFTER INSERT`, `AFTER UPDATE`, `BEFORE UPDATE`, `BEFORE DELETE` |

> ⚠️ Chỉ có `FILTER` mà không có `BLOCK AFTER INSERT` ⇒ người dùng vẫn **chèn được** dòng
> thuộc tenant khác (rồi dòng đó biến mất khỏi mắt họ). Đây là câu hỏi tủ.

### 4.3. Điểm kỹ thuật hay hỏi

- Hàm vị từ **phải là inline TVF + `SCHEMABINDING`**; không được dùng `EXECUTE AS`, không truy cập bảng khác trừ khi cấp quyền đủ.
- Cách truyền danh tính: `SESSION_CONTEXT()` (khuyến nghị, dùng `sp_set_session_context ... @read_only = 1`), `USER_NAME()`, `SUSER_SNAME()`, `DATABASE_PRINCIPAL_ID()`, hoặc `APP_NAME()` (không an toàn).
- **Chi phí**: vị từ được nối vào mọi truy vấn ⇒ cần index trên cột lọc, tránh hàm nặng.
- Người có quyền `ALTER ANY SECURITY POLICY` có thể tắt policy ⇒ đừng cấp cho ứng dụng.
- RLS **không** áp dụng cho `DBCC`, và người có `SELECT` trực tiếp lên bảng nền vẫn bị lọc (đó là điểm mạnh so với view).
- Kiểm tra: `sys.security_policies`, `sys.security_predicates`.

---

## 5. QUYỀN & PRINCIPAL

### 5.1. Ba tầng principal

| Cấp | Principal | Chứa gì |
|---|---|---|
| Windows/AD | Login, group | — |
| **Server** | `LOGIN`, server role | `sysadmin`, `securityadmin`, `dbcreator`, ... |
| **Database** | `USER`, database role, application role | `db_owner`, `db_datareader`, `db_datawriter`, `db_securityadmin`, ... |

- **Contained database user** (`CREATE USER x WITH PASSWORD`): không cần login ở cấp server ⇒ **bắt buộc trên Azure SQL Database** và giúp failover/geo-replication không vỡ quyền.
- **Microsoft Entra ID (Azure AD)**: `CREATE USER [ten@domain.com] FROM EXTERNAL PROVIDER;` — đáp án chuẩn cho Azure SQL, hỗ trợ MFA và **managed identity** cho ứng dụng (không lưu mật khẩu).

### 5.2. Thứ tự ưu tiên quyền

```
DENY  >  GRANT  >  REVOKE(mặc định = không có quyền)
```
`DENY` ở bất kỳ cấp nào **luôn thắng**, trừ một ngoại lệ: thành viên `sysadmin` bỏ qua mọi kiểm tra.

> ⚠️ Bẫy kinh điển: user thuộc role được `GRANT SELECT`, nhưng cá nhân bị `DENY SELECT`
> ⇒ **không đọc được**. Muốn gỡ phải `REVOKE` cái `DENY` chứ không phải `GRANT` thêm.

### 5.3. Nguyên tắc thiết kế được chấm điểm

- **Least privilege**: cấp quyền cho **role**, không cấp cho user; cấp ở mức **schema** thay vì từng bảng: `GRANT SELECT ON SCHEMA::Sales TO SalesReader;`
- **Ownership chaining**: nếu view/proc và bảng nền **cùng owner**, người dùng chỉ cần quyền trên view/proc, **không cần** quyền trên bảng. Đây là cách chuẩn để "cho phép thao tác dữ liệu mà không cấp quyền trực tiếp lên bảng".
  - Chuỗi **đứt** khi khác owner, hoặc khi dùng **SQL động** (`EXEC(@sql)`) ⇒ khi đó dùng
    `EXECUTE AS OWNER` hoặc ký module bằng certificate (**module signing** — giải pháp
    "sạch" nhất, giữ nguyên danh tính người gọi cho mục đích audit).
- **`EXECUTE AS`**: `CALLER` (mặc định), `SELF`, `OWNER`, `'user'`. Dùng `REVERT` để quay lại.

---

## 6. KIỂM TOÁN (AUDITING)

### 6.1. SQL Server Audit — cấu trúc 3 phần

```sql
-- (1) Server Audit: ghi ra ĐÂU
USE master;
CREATE SERVER AUDIT Audit_Main
TO FILE (FILEPATH = 'C:\Audit\', MAXSIZE = 100 MB, MAX_ROLLOVER_FILES = 10)
WITH (ON_FAILURE = CONTINUE);        -- hoặc SHUTDOWN / FAIL_OPERATION
ALTER SERVER AUDIT Audit_Main WITH (STATE = ON);

-- (2) Audit Specification: ghi CÁI GÌ
--     cấp server:
CREATE SERVER AUDIT SPECIFICATION Spec_Server FOR SERVER AUDIT Audit_Main
    ADD (FAILED_LOGIN_GROUP), ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP)
    WITH (STATE = ON);
--     cấp database:
USE MyDb;
CREATE DATABASE AUDIT SPECIFICATION Spec_Db FOR SERVER AUDIT Audit_Main
    ADD (SELECT, UPDATE ON dbo.Salary BY public),
    ADD (SCHEMA_OBJECT_CHANGE_GROUP)
    WITH (STATE = ON);
```

- Đích ghi: **FILE**, **APPLICATION_LOG**, **SECURITY_LOG** (Windows). Azure SQL ghi ra **Azure Blob Storage / Log Analytics / Event Hub**.
- `ON_FAILURE = SHUTDOWN` ⇒ nếu không ghi được audit thì **tắt instance** — đáp án cho yêu cầu tuân thủ nghiêm ngặt ("không được phép có thao tác nào không được ghi vết").
- Đọc log: `SELECT * FROM sys.fn_get_audit_file('C:\Audit\*.sqlaudit', DEFAULT, DEFAULT);`
- Audit **cấp server bắt buộc phải ON** thì spec cấp database mới hoạt động.

### 6.2. Chọn công cụ theo dõi nào?

| Nhu cầu | Công cụ |
|---|---|
| "Ai đã `SELECT` bảng lương?" / tuân thủ, chống chối bỏ | **SQL Server Audit** |
| "Dữ liệu đã thay đổi thế nào theo thời gian?" | **Temporal table** |
| "Chứng minh bằng mật mã là chưa bị sửa" | **Ledger** |
| "Đồng bộ thay đổi sang kho dữ liệu (biết cả giá trị cũ/mới)" | **Change Data Capture (CDC)** |
| "Chỉ cần biết dòng nào đã đổi để đồng bộ" (nhẹ hơn CDC) | **Change Tracking** |
| "Chẩn đoán hiệu năng, bắt deadlock, truy vấn chậm" | **Extended Events** (thay thế Profiler/Trace đã deprecated) |
| "Phát hiện lỗ hổng cấu hình, dữ liệu nhạy cảm trên Azure" | **Microsoft Defender for SQL + Data Discovery & Classification** |

> 🎯 Đề mô tả "cần biết cả giá trị trước và sau của mỗi thay đổi để nạp vào data warehouse"
> ⇒ **CDC**. "Chỉ cần biết khoá nào đã đổi, càng ít chi phí càng tốt" ⇒ **Change Tracking**.

---

## 7. TỐI ƯU HIỆU NĂNG

### 7.1. Quy trình chẩn đoán chuẩn (đề hỏi "bước tiếp theo là gì")

```
1. Đo lường  → Query Store, sys.dm_exec_query_stats, wait statistics
2. Khoanh vùng → truy vấn nào tốn nhất? chờ cái gì? (wait type)
3. Đọc plan   → scan/lookup? ước lượng lệch thực tế? spill? implicit conversion?
4. Sửa        → index / viết lại query / statistics / cấu hình
5. Xác nhận   → so sánh lại trên Query Store
```

### 7.2. Query Store — trọng tâm của phần này

```sql
ALTER DATABASE MyDb SET QUERY_STORE = ON
    (OPERATION_MODE = READ_WRITE,
     QUERY_CAPTURE_MODE = AUTO,          -- ALL | AUTO | NONE | CUSTOM
     MAX_STORAGE_SIZE_MB = 1000,
     DATA_FLUSH_INTERVAL_SECONDS = 900,
     INTERVAL_LENGTH_MINUTES = 60,
     SIZE_BASED_CLEANUP_MODE = AUTO,
     STALE_QUERY_THRESHOLD_DAYS = 30);
```

- **Bật mặc định** trên Azure SQL và **SQL Server 2022+**.
- Lưu **lịch sử plan + thống kê runtime** trong chính database ⇒ sống sót qua restart
  (khác plan cache), và đi theo database khi backup/restore.
- **Plan forcing**: `EXEC sp_query_store_force_plan @query_id, @plan_id;` — đáp án kinh điển
  cho "sau khi nâng cấp/cập nhật statistics, truy vấn đột nhiên chậm hẳn (plan regression)".
- **Query Store hints** (2022+): `sp_query_store_set_hints` — áp hint (vd `OPTION(RECOMPILE)`)
  cho truy vấn **mà không sửa được mã nguồn** (ứng dụng đóng gói/bên thứ ba). Rất hay ra đề.
- View chính: `sys.query_store_query`, `..._query_text`, `..._plan`, `..._runtime_stats`.

### 7.3. Statistics & Cardinality Estimation

- `AUTO_CREATE_STATISTICS`, `AUTO_UPDATE_STATISTICS` (mặc định ON), `AUTO_UPDATE_STATISTICS_ASYNC` (tránh truy vấn phải chờ cập nhật).
- Ngưỡng tự cập nhật hiện đại: khi số thay đổi vượt `SQRT(1000 * số dòng)` (compat ≥130) — bảng lớn được cập nhật thường xuyên hơn ngày xưa (ngưỡng cũ 20% + 500).
- Ước lượng lệch nhiều ⇒ `UPDATE STATISTICS T WITH FULLSCAN`.
- **Ascending key problem** (dữ liệu mới nằm ngoài histogram) ⇒ cập nhật statistics thường xuyên hơn hoặc dùng `OPTION(RECOMPILE)`.

### 7.4. Intelligent Query Processing (IQP) — danh sách phải thuộc

| Tính năng | Bản | Giải quyết vấn đề |
|---|---|---|
| Batch mode on rowstore | 2019 | Truy vấn phân tích trên bảng rowstore |
| Memory grant feedback | 2017 batch / **2019 row / 2022 percentile & persistence** | Cấp bộ nhớ quá nhiều (waste) hoặc quá ít (**spill to tempdb**) |
| Adaptive joins | 2017 | Chọn sai Nested Loops vs Hash Join |
| Interleaved execution | 2017 | mTVF ước lượng sai số dòng |
| Table variable deferred compilation | 2019 | Biến bảng luôn ước lượng 1 dòng |
| Scalar UDF inlining | 2019 | Scalar UDF chạy từng dòng |
| Approximate count distinct | 2019 | `APPROX_COUNT_DISTINCT` nhanh, sai số ~2% |
| **Parameter Sensitive Plan (PSP) optimization** | **2022** | **Parameter sniffing** — một plan cho nhiều dải giá trị lệch |
| Degree of parallelism feedback | 2022 | MAXDOP không phù hợp |
| Cardinality Estimation feedback | 2022 | Giả định CE sai |
| Optimized plan forcing | 2022 | Giảm chi phí biên dịch lại |

> 🎯 Đề mô tả "cùng một stored procedure, khi thì rất nhanh khi thì rất chậm tuỳ tham số"
> ⇒ **parameter sniffing**. Cách sửa theo thứ tự ưu tiên: nâng compat level 160 để bật
> **PSP optimization** → `OPTION (RECOMPILE)` → `OPTIMIZE FOR UNKNOWN` → tách procedure.

### 7.5. Wait statistics — bảng tra cứu

| Wait type | Nghĩa | Hướng xử lý |
|---|---|---|
| `CXPACKET` / `CXCONSUMER` | Song song hoá | Chỉnh `MAXDOP`, `Cost Threshold for Parallelism` (mặc định 5 là quá thấp — nên 25–50) |
| `PAGEIOLATCH_*` | Chờ đọc trang từ đĩa | Thiếu RAM, thiếu index, I/O chậm |
| `PAGELATCH_*` | Tranh chấp trang trong RAM | Hot page/last-page insert ⇒ `OPTIMIZE_FOR_SEQUENTIAL_KEY`; tempdb contention ⇒ nhiều data file |
| `LCK_M_*` | Chờ khoá | Transaction dài, thiếu index, cân nhắc **RCSI** |
| `WRITELOG` | Chờ ghi transaction log | Đĩa log chậm, cân nhắc **Delayed Durability** |
| `RESOURCE_SEMAPHORE` | Chờ cấp bộ nhớ | Memory grant quá lớn, truy vấn sắp xếp nặng |
| `SOS_SCHEDULER_YIELD` | Nghẽn CPU | Truy vấn tốn CPU, thiếu index |
| `THREADPOOL` | Hết worker thread | Quá nhiều kết nối/blocking nghiêm trọng |

DMV: `sys.dm_os_wait_stats` (tích luỹ từ lúc khởi động), `sys.dm_exec_requests` (đang chờ ngay lúc này), `sys.dm_db_wait_stats` (Azure SQL).

### 7.6. Đồng thời & khoá

| Isolation level | Đọc bẩn | Non-repeatable | Phantom | Cơ chế |
|---|---|---|---|---|
| READ UNCOMMITTED | ✅ | ✅ | ✅ | Không khoá đọc (`NOLOCK`) |
| **READ COMMITTED** (mặc định) | ❌ | ✅ | ✅ | Shared lock ngắn |
| **RCSI** (`READ_COMMITTED_SNAPSHOT ON`) | ❌ | ✅ | ✅ | **Row versioning** — người đọc không chặn người ghi |
| REPEATABLE READ | ❌ | ❌ | ✅ | Giữ shared lock đến hết transaction |
| SNAPSHOT | ❌ | ❌ | ❌ | Row versioning toàn transaction |
| SERIALIZABLE | ❌ | ❌ | ❌ | Range lock |

> 🎯 "Báo cáo chạy lâu đang chặn nghiệp vụ ghi, nhưng không được đọc dữ liệu bẩn"
> ⇒ **bật RCSI** (đổi 1 dòng cấu hình, không sửa ứng dụng). Đừng chọn `NOLOCK`.
> RCSI mặc định **BẬT trên Azure SQL Database**, **TẮT trên SQL Server**.
> Cái giá: tăng tải **tempdb** (version store).

### 7.7. Các cấu hình hay được hỏi

- **`ALTER DATABASE SCOPED CONFIGURATION`**: `MAXDOP`, `LEGACY_CARDINALITY_ESTIMATION`, `PARAMETER_SNIFFING`, `QUERY_OPTIMIZER_HOTFIXES`, `CLEAR PROCEDURE_CACHE` — chỉnh ở cấp **database** (dùng được trên Azure SQL, nơi không có `sp_configure`).
- **tempdb**: nhiều data file bằng nhau (1/core, tối đa 8), cùng kích thước, `AUTOGROWTH` đều — chống tranh chấp allocation page.
- **Resource Governor**: giới hạn CPU/RAM/IOPS theo workload group (chỉ Enterprise, không có trên Azure SQL DB).
- **Azure SQL**: chọn mô hình mua **DTU** vs **vCore**; **Serverless** (tự scale, auto-pause) cho workload gián đoạn; **Hyperscale** cho DB > 4 TB và cần restore nhanh; **Elastic pool** khi nhiều DB dùng tài nguyên lệch giờ.

---

## 8. TRIỂN KHAI, CI/CD & KIỂM THỬ

### 8.1. Hai trường phái deployment

| | **State-based (khai báo)** | **Migration-based (mệnh lệnh)** |
|---|---|---|
| Công cụ | **SSDT / DACPAC / SqlPackage**, Visual Studio DB Project | **Flyway**, **Liquibase**, EF Core Migrations, DbUp |
| Nguồn chân lý | Trạng thái mong muốn cuối cùng | Chuỗi script thay đổi có thứ tự |
| So sánh & sinh script | Tự động (schema compare) | Người viết tay |
| Ưu | Đơn giản, luôn hội tụ về đúng schema | Kiểm soát tuyệt đối dữ liệu, dễ xử lý refactor phức tạp |
| Nhược | Có thể sinh thao tác gây **mất dữ liệu** (đổi tên cột = drop + add) | Phải tự bảo đảm thứ tự, dễ trôi (drift) |

**Từ khoá của SqlPackage cần nhớ:**
- `/Action:Extract` → tạo `.dacpac` (chỉ schema) từ DB đang chạy
- `/Action:Export` → tạo `.bacpac` (**schema + dữ liệu**) — dùng để di chuyển sang Azure SQL
- `/Action:Publish` → triển khai `.dacpac` lên DB đích
- `/Action:Script` → **chỉ sinh script** để review trước (bắt buộc với môi trường production)
- `/Action:DeployReport` → báo cáo thay đổi + cảnh báo mất dữ liệu
- Tham số an toàn: `/p:BlockOnPossibleDataLoss=True` (mặc định True), `/p:DropObjectsNotInSource`, `/p:GenerateSmartDefaults`

> 🎯 **`.dacpac` = schema. `.bacpac` = schema + data.** Đây là câu hỏi gần như chắc chắn có.

### 8.2. SQL Database Projects & pipeline mẫu

- **Microsoft.Build.Sql** (SDK-style project) — thay thế SSDT cũ, chạy đa nền tảng, dùng được với `dotnet build`.
- Tiện ích mở rộng **SQL Database Projects** trong Azure Data Studio / VS Code.
- Pipeline điển hình (Azure DevOps / GitHub Actions):
  ```
  build (dotnet build → .dacpac)
    → deploy DEV (SqlPackage /Action:Publish)
      → test (tSQLt / integration tests)
        → sinh script cho PROD (/Action:Script) → người duyệt (approval gate)
          → deploy PROD
  ```
- Xác thực trong pipeline: **service principal / managed identity** + Azure Key Vault, **không** nhúng mật khẩu.

### 8.3. Kiểm thử cơ sở dữ liệu

| Loại | Công cụ / kỹ thuật |
|---|---|
| Unit test T-SQL | **tSQLt** (FakeTable, FakeFunction, AssertEquals, chạy trong transaction tự rollback) |
| Kiểm thử schema/data trong pipeline | SQL Server Data Tools test, dbatools, Pester |
| Sinh dữ liệu test an toàn | Data masking khi copy từ production, hoặc sinh dữ liệu tổng hợp |
| Kiểm thử hiệu năng hồi quy | So sánh Query Store trước/sau; **Distributed Replay**; A/B với compat level |

### 8.4. Nâng cấp & di chuyển

- **Database Compatibility Level**: nâng cấp engine trước, **giữ compat level cũ**, bật **Query Store**, rồi mới nâng compat và dùng plan forcing để xử lý hồi quy. Đây là "Microsoft recommended upgrade workflow" — hay ra đề dạng sắp xếp bước.
- **Data Migration Assistant (DMA)**: đánh giá tương thích trước khi di chuyển.
- **Azure Database Migration Service (DMS)**: di chuyển online/offline sang Azure.
- **Managed Instance link** / **Log Replay Service**: di chuyển ít downtime.
- Chọn đích trên Azure:
  - Cần SQL Agent, cross-database query, CLR, Service Broker → **Azure SQL Managed Instance**
  - Ứng dụng mới, một database, muốn ít quản trị nhất → **Azure SQL Database**
  - Cần toàn quyền OS, tính năng đặc thù → **SQL Server on Azure VM**

### 8.5. Khả dụng cao & khôi phục (thường hỏi kèm)

- **Recovery model**: `FULL` (point-in-time, phải backup log), `BULK_LOGGED`, `SIMPLE` (không PITR).
- Chiến lược backup: Full + Differential + Log; `RESTORE ... WITH NORECOVERY` cho các bước trung gian, `WITH RECOVERY` cho bước cuối, `STOPAT` để phục hồi tới thời điểm.
- **Azure SQL**: backup tự động (PITR 1–35 ngày), **LTR** tới 10 năm, **Active geo-replication** / **Failover group** cho DR, **Zone-redundant** cho HA.
- On-prem: **Always On Availability Group** (đọc trên secondary), Failover Cluster Instance, Log shipping.

---

## 9. BẢNG QUYẾT ĐỊNH NHANH (in ra ôn trước giờ thi)

| Đề bài nói... | Đáp án |
|---|---|
| Mất băng backup / mất ổ đĩa, dữ liệu không được lộ | **TDE** (+ backup encryption) |
| **Kể cả DBA/sysadmin cũng không được xem** | **Always Encrypted** (CMK ngoài DB) |
| Always Encrypted nhưng vẫn cần `LIKE`, so sánh dải | **Secure enclaves** |
| Always Encrypted nhưng vẫn cần `=`, `JOIN`, index | **DETERMINISTIC** encryption |
| Khách hàng đòi tự quản lý khoá trên Azure SQL | **CMK/BYOK + Azure Key Vault** |
| Che số thẻ trên màn hình hỗ trợ, không đổi ứng dụng | **Dynamic Data Masking** |
| Mỗi khách thuê chỉ thấy dữ liệu của mình, dùng chung bảng | **RLS: FILTER + BLOCK predicate** |
| Ngăn người dùng chèn dòng sang tenant khác | **BLOCK PREDICATE AFTER INSERT** |
| Cho phép chạy proc mà không cấp quyền lên bảng | **Ownership chaining** (hoặc **module signing** nếu có SQL động) |
| "Ai đã đọc bảng lương lúc mấy giờ?" | **SQL Server Audit** |
| Không được phép có thao tác nào không ghi vết | **`ON_FAILURE = SHUTDOWN`** |
| Đồng bộ thay đổi kèm giá trị cũ/mới sang DW | **CDC** |
| Chỉ cần biết khoá nào đổi, chi phí thấp nhất | **Change Tracking** |
| Sau nâng cấp, một truy vấn chậm hẳn | **Query Store → force plan cũ** |
| Không sửa được mã nguồn nhưng cần thêm hint | **Query Store hints (2022+)** |
| Cùng proc lúc nhanh lúc chậm theo tham số | **Parameter sniffing → PSP optimization / RECOMPILE** |
| Báo cáo dài chặn nghiệp vụ ghi, cấm đọc bẩn | **Bật RCSI** |
| Truy vấn tràn (spill) ra tempdb do cấp bộ nhớ sai | **Memory grant feedback** |
| Nghẽn tempdb ở allocation page | **Nhiều data file tempdb bằng nhau** |
| Chuyển schema-only lên môi trường khác | **DACPAC** |
| Chuyển cả schema + dữ liệu lên Azure SQL | **BACPAC** |
| Bắt buộc review thay đổi trước khi lên production | **SqlPackage /Action:Script (+ DeployReport)** |
| Unit test T-SQL trong pipeline | **tSQLt** |
| Cần SQL Agent + cross-DB query trên Azure | **SQL Managed Instance** |
| DB > 4 TB, cần restore nhanh trên Azure | **Hyperscale** |
| Nhiều DB nhỏ dùng tài nguyên lệch giờ | **Elastic pool** |
| Workload gián đoạn, muốn tiết kiệm chi phí | **Serverless (auto-pause)** |

---

## 10. LỘ TRÌNH ÔN 7 NGÀY CHO MIỀN 2

| Ngày | Nội dung | Lab |
|---|---|---|
| 1 | Bức tranh bảo mật, TDE, key hierarchy, backup encryption | Lab 01 (phần A) |
| 2 | Always Encrypted, deterministic vs randomized, secure enclaves | Lab 01 (phần B) |
| 3 | DDM, RLS (filter/block), quyền, ownership chaining, module signing | Lab 02 |
| 4 | SQL Audit, Extended Events, CDC vs Change Tracking | Lab 03 |
| 5 | Query Store, plan forcing, statistics, parameter sniffing, IQP | Lab 04 (phần A) |
| 6 | Wait stats, isolation level & RCSI, tempdb, cấu hình Azure | Lab 04 (phần B) |
| 7 | DACPAC/BACPAC, pipeline CI/CD, tSQLt, migration + làm Quiz | Lab 05 + Quiz |

**Cách học hiệu quả nhất:** với mỗi tính năng bảo mật, tự hỏi **"cái này chống được ai,
và ai vẫn vượt qua được?"**. Đề thi miền 2 gần như luôn được xây trên đúng câu hỏi đó.
