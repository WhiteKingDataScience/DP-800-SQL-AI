# DP-800 — MIỀN 1: THIẾT KẾ & PHÁT TRIỂN GIẢI PHÁP CƠ SỞ DỮ LIỆU (35–40%)

> **Cẩm nang ôn thi chuyên sâu** — góc nhìn của Database Solutions Architect.
> **Nền tảng mục tiêu:** SQL Server 2022 / SQL Server 2025 / Azure SQL Database.
> **Bộ lab đi kèm:**
> - [Claude_DP800_D1_Lab01_Tables_Constraints.sql](./Claude_DP800_D1_Lab01_Tables_Constraints.sql)
> - [Claude_DP800_D1_Lab02_Indexes_Columnstore.sql](./Claude_DP800_D1_Lab02_Indexes_Columnstore.sql)
> - [Claude_DP800_D1_Lab03_SpecializedTables_JSON.sql](./Claude_DP800_D1_Lab03_SpecializedTables_JSON.sql)
> - [Claude_DP800_D1_Lab04_Partitioning.sql](./Claude_DP800_D1_Lab04_Partitioning.sql)
> - [Claude_DP800_D1_Lab05_Views_Functions_Triggers.sql](./Claude_DP800_D1_Lab05_Views_Functions_Triggers.sql)
> - [Claude_DP800_D1_Quiz.md](./Claude_DP800_D1_Quiz.md) — 60 câu tự kiểm tra kèm giải thích

### Môi trường chạy lab

Toàn bộ 5 lab đã được **chạy thực tế và kiểm chứng trên SQL Server 2019 Developer Edition**
(instance `localhost` của máy này). Sau khi chạy, script chỉ còn để lại đúng những
**lỗi cố ý** (được đánh dấu `[LỖI CỐ Ý]`) — mọi lỗi ngoài ý muốn đã được sửa.

Các tính năng cần bản mới hơn được **bọc kiểm tra phiên bản** hoặc để dưới dạng chú thích
đọc-hiểu, nên script vẫn chạy trọn vẹn trên 2019:

| Tính năng | Bản tối thiểu | Trạng thái trên SQL 2019 |
|---|---|---|
| `ORDER (...)` cho Clustered Columnstore | 2022 | Tự bỏ qua, tạo CCI thường |
| `JSON_PATH_EXISTS` | 2022 | Tự bỏ qua |
| Ledger table | 2022 | Bọc `TRY…CATCH`, in thông báo |
| External table (PolyBase 2022) | 2022 | Chỉ đọc chú thích, không chạy |
| Kiểu `JSON`, `VECTOR`, `AI_GENERATE_EMBEDDINGS`, JSON index | 2025 | Chỉ đọc chú thích, không chạy |

Hai database được tạo: `DP800_Lab` (Lab 01, 02, 03, 05) và `DP800_Part` (Lab 04 — script
tự `DROP` và tạo lại mỗi lần chạy). **Chỉ chạy trên instance TEST.**

---

## 0. CÁCH ĐỀ THI HỎI MIỀN NÀY

Miền 1 chiếm 35–40% → khoảng **18–24 câu** trên đề ~50–60 câu. Đề **không hỏi cú pháp thuộc lòng**, mà hỏi theo 3 khuôn mẫu:

| Khuôn mẫu | Ví dụ đề bài | Kỹ năng cần |
|---|---|---|
| **Chọn đối tượng phù hợp** | "Cần báo cáo tổng hợp real-time trên bảng OLTP đang ghi liên tục, không được ảnh hưởng hiệu năng ghi. Bạn làm gì?" | Bảng so sánh trade-off |
| **Sửa lỗi / hoàn thiện code** | Cho đoạn `CREATE VIEW ... WITH SCHEMABINDING`, hỏi tại sao `CREATE UNIQUE CLUSTERED INDEX` thất bại | Nhớ **điều kiện bắt buộc** của từng tính năng |
| **Sắp xếp thứ tự thao tác** | Drag-and-drop: các bước thiết lập partitioning / sliding window | Nhớ **trình tự** |

**Nguyên tắc vàng khi làm bài:** đọc kỹ 3 từ khóa ràng buộc — *(1) khối lượng dữ liệu, (2) loại workload (OLTP/OLAP/HTAP), (3) yêu cầu phi chức năng (downtime, audit, immutability, latency)*. Ba từ khóa này quyết định đáp án gần như tuyệt đối.

---

## 1. THIẾT KẾ BẢNG (TABLE DESIGN)

### 1.1. Chọn kiểu dữ liệu — điểm ăn/mất dễ nhất

| Nhu cầu | Dùng | Tránh | Lý do |
|---|---|---|---|
| Tiền tệ | `DECIMAL(19,4)` / `MONEY` | `FLOAT`, `REAL` | Float là số xấp xỉ → sai số cộng dồn |
| Ngày + giờ | `DATETIME2(n)` | `DATETIME` | Chính xác 100ns, dải rộng hơn, chuẩn ANSI |
| Ngày + giờ + múi giờ | `DATETIMEOFFSET` | lưu 2 cột rời | Giữ offset UTC |
| Khóa thay thế (surrogate) | `INT`/`BIGINT IDENTITY` | `UNIQUEIDENTIFIER` mặc định | GUID ngẫu nhiên gây **phân mảnh clustered index** |
| GUID bắt buộc (phân tán) | `UNIQUEIDENTIFIER` + `NEWSEQUENTIALID()` | `NEWID()` làm clustered key | Sequential giảm page split |
| Chuỗi Unicode | `NVARCHAR(n)` | `NVARCHAR(MAX)` khi không cần | MAX → LOB, không index trực tiếp được |
| Chuỗi ASCII lớn | `VARCHAR(n)` + collation `_UTF8` | `NVARCHAR` | Collation UTF-8 tiết kiệm ~50% với dữ liệu Latin |
| Vector nhúng (AI) | `VECTOR(n)` *(SQL 2025)* | `VARBINARY`, `NVARCHAR(MAX)` | Có toán tử khoảng cách + vector index |
| Tài liệu JSON | `JSON` *(SQL 2025)* | `NVARCHAR(MAX)` | Lưu dạng binary đã parse, nhanh hơn, có JSON index |

> ⚠️ **Bẫy:** `VARCHAR(MAX)`/`NVARCHAR(MAX)`/`XML`/`VECTOR` **không được làm khóa index** (key column). Với chúng, giải pháp là *computed column PERSISTED* + index, hoặc index chuyên biệt (JSON index, vector index).

### 1.2. Computed Columns

```sql
ALTER TABLE Sales.OrderLine
ADD LineTotal AS (Quantity * UnitPrice * (1 - Discount)) PERSISTED;
```

- **Không PERSISTED**: tính lại mỗi lần đọc, không tốn chỗ. Vẫn index được **nếu** biểu thức *deterministic* và *precise*.
- **PERSISTED**: ghi vật lý vào row → **bắt buộc** khi biểu thức dùng `FLOAT`/`REAL` (imprecise), khi cần làm cột phân vùng, hoặc khi cần FK/CHECK tham chiếu.
- Không được tham chiếu cột ở bảng khác, không dùng subquery.

### 1.3. IDENTITY vs SEQUENCE (câu hỏi kinh điển)

| | `IDENTITY` | `SEQUENCE` |
|---|---|---|
| Phạm vi | Thuộc **1 cột của 1 bảng** | Đối tượng schema **độc lập**, dùng chung nhiều bảng |
| Lấy giá trị trước khi INSERT | ❌ | ✅ `NEXT VALUE FOR` |
| Reset / đặt lại | `DBCC CHECKIDENT` | `ALTER SEQUENCE ... RESTART` |
| Cấp phát hàng loạt | ❌ | ✅ `sp_sequence_get_range` |
| Vòng lặp giá trị | ❌ | ✅ `CYCLE` |
| Dùng trong `DEFAULT` | ngầm định | ✅ `DEFAULT (NEXT VALUE FOR dbo.Seq)` |

> 💡 Đề hỏi *"nhiều bảng phải dùng chung một dãy số thứ tự liên tục"* → **SEQUENCE**. Hỏi *"cần biết ID trước khi ghi bản ghi cha để ghi bản ghi con"* → **SEQUENCE**.

### 1.4. Nén dữ liệu & Sparse columns

- `DATA_COMPRESSION = ROW` : nén kiểu lưu trữ độ dài thay đổi. Chi phí CPU thấp.
- `DATA_COMPRESSION = PAGE` : ROW + prefix + dictionary. Tốt cho bảng đọc nhiều, dữ liệu lặp lại.
- `DATA_COMPRESSION = COLUMNSTORE` / `COLUMNSTORE_ARCHIVE` : chỉ cho columnstore; ARCHIVE nén thêm ~30% nhưng chậm khi đọc → dùng cho partition dữ liệu lạnh.
- **Sparse column**: `SPARSE` tiết kiệm chỗ khi cột NULL >~ 40–60%; đi kèm `COLUMN_SET` để đọc/ghi hàng loạt cột thưa dưới dạng XML.

---

## 2. RÀNG BUỘC & TOÀN VẸN DỮ LIỆU (CONSTRAINTS)

### 2.1. Bảng tổng hợp

| Ràng buộc | Cho phép NULL? | Số lượng / bảng | Tạo index ngầm? |
|---|---|---|---|
| `PRIMARY KEY` | ❌ (cột phải NOT NULL) | 1 | ✅ mặc định **CLUSTERED** |
| `UNIQUE` | ✅ nhưng **chỉ 1 dòng NULL** | nhiều | ✅ mặc định **NONCLUSTERED** |
| `FOREIGN KEY` | ✅ (NULL = bỏ qua kiểm tra) | nhiều | ❌ **không** — phải tự tạo |
| `CHECK` | logic trả `UNKNOWN` ⇒ **được chấp nhận** | nhiều | ❌ |
| `DEFAULT` | — | 1/cột | ❌ |

> ⚠️ **Ba bẫy hay gặp nhất:**
> 1. `CHECK (Age > 18)` **không chặn** `Age = NULL` (vì `NULL > 18` = UNKNOWN, không phải FALSE). Muốn chặn phải thêm `AND Age IS NOT NULL` hoặc `NOT NULL` cho cột.
> 2. `UNIQUE` chỉ cho **một** giá trị NULL. Cần nhiều NULL → dùng **unique filtered index**: `CREATE UNIQUE INDEX ... WHERE Col IS NOT NULL`.
> 3. **FOREIGN KEY không tự tạo index** → nguyên nhân số 1 gây scan bảng con khi xóa bản ghi cha.

### 2.2. Trusted vs Untrusted constraint

```sql
ALTER TABLE T WITH NOCHECK ADD CONSTRAINT CK_x CHECK (...);  -- untrusted!
ALTER TABLE T WITH CHECK CHECK CONSTRAINT CK_x;              -- làm cho trusted trở lại
```

`WITH NOCHECK` bỏ qua kiểm tra dữ liệu cũ → constraint bị đánh dấu `is_not_trusted = 1` và **Query Optimizer sẽ không dùng nó để tối ưu**. Kiểm tra:

```sql
SELECT name, is_not_trusted FROM sys.check_constraints WHERE is_not_trusted = 1;
SELECT name, is_not_trusted FROM sys.foreign_keys      WHERE is_not_trusted = 1;
```

### 2.3. Hành vi tham chiếu FK

| Hành động | Ý nghĩa |
|---|---|
| `NO ACTION` (mặc định) | Chặn thao tác, báo lỗi |
| `CASCADE` | Xóa/sửa lan xuống bảng con |
| `SET NULL` | Cột FK ở con → NULL (cột phải nullable) |
| `SET DEFAULT` | Cột FK ở con → giá trị DEFAULT (giá trị đó phải tồn tại ở bảng cha) |

> ⚠️ Không thể dùng `CASCADE` nếu tạo thành **vòng lặp tham chiếu** hoặc nhiều đường dẫn cascade tới cùng một bảng → lỗi *"may cause cycles or multiple cascade paths"*. Giải pháp: dùng `NO ACTION` + trigger `INSTEAD OF`/stored procedure.

---

## 3. CHỈ MỤC ROWSTORE (B-TREE)

### 3.1. Cấu trúc

- **Clustered Index (CI)**: chính là dữ liệu bảng, sắp xếp theo khóa. **Tối đa 1**. Không có CI → bảng là **Heap** (dữ liệu vô trật tự, định vị bằng RID).
- **Nonclustered Index (NCI)**: cây B-Tree riêng; leaf chứa key + **bookmark** (clustered key nếu có CI, RID nếu heap). Tối đa 999.
- **Key columns** (tối đa 32 cột / 1700 bytes): dùng để *tìm kiếm, JOIN, ORDER BY, GROUP BY*.
- **INCLUDE columns**: chỉ nằm ở **leaf level**, không tính vào giới hạn kích thước khóa, không sắp xếp. Dùng cho cột chỉ xuất hiện ở `SELECT` → tạo **covering index**, triệt tiêu Key Lookup.

### 3.2. Thứ tự cột khóa — quy tắc thực chiến

Đặt theo thứ tự: **Equality → Inequality → (INCLUDE) Output**.

```sql
-- WHERE CustomerID = @c AND OrderDate >= @d  SELECT TotalDue, Status
CREATE NONCLUSTERED INDEX IX_SO_Cust_Date
    ON Sales.SalesOrder (CustomerID, OrderDate)   -- equality trước, range sau
    INCLUDE (TotalDue, Status);
```

### 3.3. Các biến thể cần nhớ

| Loại | Cú pháp then chốt | Khi nào dùng |
|---|---|---|
| **Filtered index** | `CREATE INDEX ... WHERE Status = 'Active'` | Truy vấn luôn lọc trên tập nhỏ; dữ liệu thưa; ép unique bỏ qua NULL |
| **Unique index** | `CREATE UNIQUE INDEX ...` | Vừa ép ràng buộc vừa cho optimizer biết tính duy nhất |
| **Index trên computed column** | cần `PERSISTED` nếu imprecise | Index hóa `JSON_VALUE()`, biểu thức |
| **Index có nén** | `WITH (DATA_COMPRESSION = PAGE)` | Index lớn, đọc nhiều |
| **Index ONLINE** | `WITH (ONLINE = ON, RESUMABLE = ON)` | Không được downtime; RESUMABLE cho phép `PAUSE`/`RESUME` |
| **Optimize for sequential key** | `WITH (OPTIMIZE_FOR_SEQUENTIAL_KEY = ON)` | Khóa tăng dần gây **last-page insert contention** (PAGELATCH_EX) |

### 3.4. Bảo trì

| Phân mảnh | Hành động |
|---|---|
| < 5% | Không làm gì |
| 5–30% | `ALTER INDEX ... REORGANIZE` (luôn online, không cần lock dài) |
| > 30% | `ALTER INDEX ... REBUILD WITH (ONLINE = ON)` |

Thống kê: `UPDATE STATISTICS tbl WITH FULLSCAN`. `REBUILD` cập nhật statistics kèm theo; `REORGANIZE` **thì không**.

> 💡 Truy vấn chẩn đoán ruột gan: `sys.dm_db_index_physical_stats`, `sys.dm_db_index_usage_stats` (index có ai dùng không), `sys.dm_db_missing_index_details` (gợi ý index còn thiếu — *tham khảo, không áp dụng mù quáng*).

---

## 4. COLUMNSTORE

### 4.1. Cơ chế lưu trữ

```
Bảng → chia thành Rowgroup (~1.048.576 dòng)
      → mỗi Rowgroup chia theo cột thành Column Segment
      → mỗi Segment nén độc lập + lưu metadata min/max
```

Ba lợi ích cộng dồn:
1. **Nén cao** (10x) do dữ liệu cùng cột đồng nhất.
2. **Segment elimination** — nhờ min/max, bỏ qua cả segment không thỏa `WHERE`.
3. **Batch mode execution** — xử lý 900 dòng/lần thay vì từng dòng → giảm CPU rất mạnh cho `SUM`/`GROUP BY`.

### 4.2. CCI vs NCCI

| | **Clustered Columnstore (CCI)** | **Nonclustered Columnstore (NCCI)** |
|---|---|---|
| Bản chất | **Là** toàn bộ bảng | Index **phụ** trên bảng rowstore |
| Workload | Data Warehouse / OLAP thuần | **HTAP / Operational Analytics** |
| Kết hợp | Có thể thêm NCI B-Tree lên trên | Bảng gốc vẫn có CI + NCI |
| Có thể lọc? | ❌ | ✅ `WHERE` (filtered NCCI) — chỉ nén phần dữ liệu nguội |

> 🎯 **Đáp án tủ:** "*Chạy báo cáo phân tích trực tiếp trên bảng OLTP, tối thiểu ảnh hưởng giao dịch, không dựng ETL/DW*" → **Nonclustered Columnstore Index**, thường kèm `WHERE OrderDate < ...` để tách dữ liệu nóng.

### 4.3. Delta store & Tuple Mover

- INSERT lẻ tẻ → vào **delta rowgroup** (dạng rowstore B-Tree, trạng thái `OPEN`).
- Đủ ~1.048.576 dòng → `CLOSED` → **Tuple Mover** nén thành `COMPRESSED`.
- **Bulk insert ≥ 102.400 dòng/batch** → ghi **thẳng** vào rowgroup nén, bỏ qua delta store. *(Con số 102.400 rất hay bị hỏi.)*
- Ép nén thủ công:
  ```sql
  ALTER INDEX cci ON dbo.FactSales REORGANIZE WITH (COMPRESS_ALL_ROW_GROUPS = ON);
  ```
- Theo dõi: `sys.dm_db_column_store_row_group_physical_stats` (xem `state_desc`, `deleted_rows`, `trim_reason_desc`).

### 4.4. Ordered Clustered Columnstore (SQL 2022+)

```sql
CREATE CLUSTERED COLUMNSTORE INDEX CCI_Fact ON dbo.FactSales
    ORDER (OrderDate) WITH (DROP_EXISTING = ON, MAXDOP = 1);
```
Sắp xếp dữ liệu trước khi nén → min/max của các segment không chồng lấn → **segment elimination hiệu quả hơn nhiều**. Dùng `MAXDOP = 1` khi build để tránh chồng lấn giữa các thread.

### 4.5. Khi **không** nên dùng columnstore

- Bảng < ~100.000 dòng (không đủ 1 rowgroup → không nén hiệu quả).
- Workload chủ yếu **singleton lookup** theo khóa (`WHERE ID = 123`) → B-Tree seek thắng tuyệt đối.
- Nhiều `UPDATE`/`DELETE` lẻ: mỗi UPDATE = DELETE (đánh dấu bit) + INSERT (vào delta) → phình `deleted_rows`, cần REORGANIZE định kỳ.

---

## 5. CÁC BẢNG CHUYÊN BIỆT

### 5.1. Temporal Table (System-Versioned)

**Bắt buộc có:** PRIMARY KEY + 2 cột `DATETIME2 GENERATED ALWAYS AS ROW START/END` + `PERIOD FOR SYSTEM_TIME`.

```sql
CREATE TABLE HR.Employee (
    EmployeeID  INT NOT NULL PRIMARY KEY,
    Salary      DECIMAL(19,4) NOT NULL,
    ValidFrom   DATETIME2(7) GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
    ValidTo     DATETIME2(7) GENERATED ALWAYS AS ROW END   HIDDEN NOT NULL,
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON (
        HISTORY_TABLE = HR.EmployeeHistory,
        HISTORY_RETENTION_PERIOD = 7 YEARS));
```

Mệnh đề truy vấn thời gian:

| Cú pháp | Trả về |
|---|---|
| `FOR SYSTEM_TIME AS OF @t` | Ảnh chụp trạng thái **tại thời điểm** @t |
| `BETWEEN @a AND @b` | Dòng active trong khoảng; **bao gồm** dòng bắt đầu đúng tại @b |
| `FROM @a TO @b` | Như trên nhưng **loại trừ** dòng bắt đầu tại @b |
| `CONTAINED IN (@a, @b)` | Dòng **mở và đóng hoàn toàn** trong khoảng |
| `ALL` | Toàn bộ current + history |

> ⚠️ Không `TRUNCATE` được bảng temporal. Muốn `ALTER`/`DROP` phải `SET (SYSTEM_VERSIONING = OFF)` trước — nhớ bật lại! Thời gian ghi là **UTC**, lấy tại thời điểm **bắt đầu transaction**.
> ⚠️ Phân biệt với **Ledger**: Temporal = *audit lịch sử*, người có quyền `db_owner` vẫn sửa được history. Ledger = *chống giả mạo bằng mật mã*.

### 5.2. Ledger Table

| | **Updatable Ledger** | **Append-Only Ledger** |
|---|---|---|
| `INSERT` | ✅ | ✅ |
| `UPDATE`/`DELETE` | ✅ (ghi vết vào history) | ❌ **bị chặn hoàn toàn** |
| Bảng phụ sinh ra | `*_History` + ledger view | chỉ ledger view |
| Kịch bản | Sổ cái tài chính cần sửa đổi có kiểm chứng | Log sự kiện, nhật ký bất biến |

Cơ chế: mỗi transaction băm SHA-256, gom vào **Merkle tree**, sinh **database digest** có thể lưu ra Azure Blob **immutable storage / Confidential Ledger** → xác minh bằng `sys.sp_verify_database_ledger`.

> 🎯 Từ khóa đề bài: *"tamper-evident"*, *"cryptographically verifiable"*, *"chứng minh với kiểm toán viên rằng DBA cũng không thể sửa"* → **Ledger**, không phải Temporal.

### 5.3. Memory-Optimized Table (In-Memory OLTP)

```sql
ALTER DATABASE X ADD FILEGROUP FG_IMOLTP CONTAINS MEMORY_OPTIMIZED_DATA;
ALTER DATABASE X ADD FILE (NAME='imoltp', FILENAME='...') TO FILEGROUP FG_IMOLTP;

CREATE TABLE dbo.Session (
    SessionID   INT NOT NULL PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT = 1048576),
    UserID      INT NOT NULL INDEX IX_User NONCLUSTERED,
    LastSeen    DATETIME2 NOT NULL
) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);
```

- **DURABILITY**: `SCHEMA_AND_DATA` (bền vững, mặc định) vs `SCHEMA_ONLY` (mất khi restart — dùng cho **staging ETL, session state**, nhanh hơn vì không ghi log).
- **HASH index**: chỉ hiệu quả với `WHERE col = value` (equality). `BUCKET_COUNT` nên ≈ 1–2× số **giá trị khóa phân biệt**, làm tròn lên lũy thừa 2. Đặt quá nhỏ → chuỗi va chạm dài; quá lớn → phí bộ nhớ.
- **NONCLUSTERED (range/Bw-tree) index**: hỗ trợ range scan và `ORDER BY`.
- Không có index nào là clustered; **không có latch, không có lock** → dùng **optimistic MVCC**, xung đột sinh lỗi 41302/41305 → **bắt buộc viết retry logic**.
- **Natively Compiled SP**: `WITH NATIVE_COMPILATION, SCHEMABINDING` + `BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english')`. Chỉ truy cập được bảng memory-optimized.

### 5.4. Graph Table

```sql
CREATE TABLE dbo.Person   (ID INT PRIMARY KEY, Name NVARCHAR(100)) AS NODE;
CREATE TABLE dbo.Follows  (StartDate DATE,
    CONSTRAINT EC_Follows CONNECTION (dbo.Person TO dbo.Person)) AS EDGE;

SELECT p2.Name
FROM dbo.Person p1, dbo.Follows f, dbo.Person p2
WHERE MATCH(p1-(f)->p2) AND p1.Name = N'An';

-- Đường đi đệ quy (bạn của bạn của bạn...)
SELECT p1.Name, STRING_AGG(p2.Name, '->') WITHIN GROUP (GRAPH PATH) AS Chain
FROM dbo.Person p1, dbo.Follows FOR PATH f, dbo.Person FOR PATH p2
WHERE MATCH(SHORTEST_PATH(p1(-(f)->p2)+)) AND p1.Name = N'An';
```

- Node có cột ẩn `$node_id`; edge có `$edge_id`, `$from_id`, `$to_id`.
- `CONNECTION (...)` = **edge constraint**, giới hạn edge chỉ nối đúng loại node.
- Dùng khi truy vấn **nhiều cấp quan hệ, độ sâu thay đổi** (mạng xã hội, phát hiện gian lận, đề xuất). Quan hệ cố định 1–2 cấp → bảng quan hệ thường vẫn tốt hơn.

### 5.5. External Table (PolyBase / Data Virtualization)

Trình tự 4 bước — hay bị hỏi dạng sắp xếp:
1. `CREATE MASTER KEY ENCRYPTION BY PASSWORD = ...`
2. `CREATE DATABASE SCOPED CREDENTIAL` (SAS token / Managed Identity)
3. `CREATE EXTERNAL DATA SOURCE` (`LOCATION = 'abs://container@account.blob.core.windows.net'`)
4. `CREATE EXTERNAL FILE FORMAT` → `CREATE EXTERNAL TABLE`

Đọc trực tiếp Parquet/CSV/Delta trên ADLS/S3 mà không nạp vào SQL. Không tạo được index B-Tree trên external table.
`CREATE EXTERNAL TABLE AS SELECT` (CETAS) = xuất kết quả truy vấn ra data lake.

### 5.6. Vector & AI (SQL Server 2025) — điểm mới rất dễ ra đề

```sql
CREATE TABLE dbo.DocChunk (
    ChunkID    INT IDENTITY PRIMARY KEY,
    Content    NVARCHAR(MAX),
    Embedding  VECTOR(1536)          -- tối đa 1998 chiều
);

-- Khoảng cách vector: 'cosine' | 'euclidean' | 'dot'
SELECT TOP (5) Content, VECTOR_DISTANCE('cosine', Embedding, @q) AS Dist
FROM dbo.DocChunk ORDER BY Dist;

-- Chỉ mục vector xấp xỉ (DiskANN) cho tập lớn
CREATE VECTOR INDEX VI_Doc ON dbo.DocChunk (Embedding)
    WITH (METRIC = 'cosine', TYPE = 'diskann');
```

- `VECTOR_DISTANCE` = **exact / brute force** (KNN chính xác, chậm khi dữ liệu lớn).
- `VECTOR_SEARCH` + vector index = **ANN xấp xỉ** (nhanh, đánh đổi độ chính xác — chỉnh bằng tham số hiệu chỉnh).
- `CREATE EXTERNAL MODEL` khai báo endpoint (Azure OpenAI / Ollama), rồi `AI_GENERATE_EMBEDDINGS(@text USE MODEL MyModel)` sinh embedding **ngay trong T-SQL**.
- **Hybrid search** = kết hợp full-text/BM25 + vector similarity, xếp hạng lại (RRF) — mẫu thiết kế RAG chuẩn.

---

## 6. JSON TRONG SQL SERVER

### 6.1. Lưu trữ

| Cách | Điều kiện | Ghi chú |
|---|---|---|
| `NVARCHAR(MAX)` + `CHECK (ISJSON(col) = 1)` | Mọi phiên bản | Lưu **nguyên văn chuỗi**, phải parse mỗi lần đọc |
| Kiểu `JSON` (SQL 2025 / Azure SQL) | Mới | Lưu **binary đã parse**, đọc nhanh hơn, hỗ trợ **JSON index** |

`ISJSON(expr, VALUE|ARRAY|OBJECT|SCALAR)` — biến thể có tham số kiểu là của **SQL Server 2022+**.

### 6.2. Bộ hàm cần thuộc

| Hàm | Trả về | Dùng khi |
|---|---|---|
| `JSON_VALUE(json, '$.path')` | **giá trị vô hướng** (nvarchar(4000)) | Lấy 1 trường đơn |
| `JSON_QUERY(json, '$.path')` | **object / array** | Lấy nhánh con |
| `JSON_MODIFY(json, path, val)` | JSON mới | Cập nhật/chèn/xóa (`NULL` = xóa), `append` để thêm phần tử |
| `OPENJSON(json) WITH (...)` | **bảng** | Chuyển JSON → quan hệ (shred) |
| `FOR JSON PATH / AUTO` | chuỗi JSON | Quan hệ → JSON |
| `JSON_PATH_EXISTS` | 0/1 | Kiểm tra tồn tại path (2022+) |
| `JSON_OBJECT()` / `JSON_ARRAY()` | JSON | Dựng JSON có kiểu (2022+) |
| `JSON_OBJECTAGG()` / `JSON_ARRAYAGG()` | JSON | **Gộp nhóm** thành object/array (2025) |

> ⚠️ `JSON_VALUE` trả về `NULL` nếu path trỏ tới object/array (lax mode). `JSON_QUERY` trả `NULL` nếu path trỏ tới giá trị vô hướng. **Nhớ ngược lại là mất điểm.**
> ⚠️ `lax` (mặc định) → path không tồn tại trả `NULL`. `strict` → **báo lỗi**. `JSON_VALUE(c, 'strict $.a.b')`.

### 6.3. Đánh chỉ mục JSON

**Cách kinh điển (mọi phiên bản)** — computed column PERSISTED:

```sql
ALTER TABLE dbo.Orders
ADD CustomerEmail AS JSON_VALUE(Payload, '$.customer.email');   -- deterministic
CREATE NONCLUSTERED INDEX IX_Orders_Email ON dbo.Orders (CustomerEmail);
```
*(Cần `PERSISTED` nếu muốn dùng làm khóa phân vùng hoặc ràng buộc; với `JSON_VALUE` thường không bắt buộc PERSISTED để index.)*

**Cách mới (SQL Server 2025, cột kiểu `JSON`)**:
```sql
CREATE JSON INDEX JI_Orders ON dbo.Orders (Payload) FOR ('$.customer');
```
Index hóa **mọi path** dưới nhánh chỉ định → không cần biết trước sẽ lọc theo trường nào.

### 6.4. Khi nào chọn JSON thay vì cột quan hệ

✅ Dùng JSON khi: schema thay đổi theo từng bản ghi (thuộc tính sản phẩm), lưu payload thô từ API, cấu hình động, dữ liệu chỉ đọc nguyên khối.
❌ Không dùng khi: cần JOIN/tổng hợp/ràng buộc FK trên các trường bên trong, cần thống kê chính xác cho optimizer.
🎯 **Thực chiến:** *hybrid* — trích các trường "nóng" ra computed column có index, phần còn lại giữ trong JSON.

---

## 7. PHÂN VÙNG (PARTITIONING)

### 7.1. Ba bước + 1 (thứ tự bắt buộc)

```sql
-- (0) Filegroup (tùy chọn nhưng khuyến nghị)
ALTER DATABASE X ADD FILEGROUP FG2024; ...

-- (1) Partition FUNCTION: định nghĩa biên
CREATE PARTITION FUNCTION PF_ByYear (DATE)
    AS RANGE RIGHT FOR VALUES ('2024-01-01', '2025-01-01', '2026-01-01');

-- (2) Partition SCHEME: ánh xạ vào filegroup
CREATE PARTITION SCHEME PS_ByYear
    AS PARTITION PF_ByYear TO (FG_Old, FG2024, FG2025, FG2026);

-- (3) Bảng/Index đặt trên scheme
CREATE TABLE dbo.FactSales (... OrderDate DATE NOT NULL ...) ON PS_ByYear (OrderDate);
```

`n` biên ⇒ **`n + 1` partition** (đánh số từ 1).

### 7.2. RANGE LEFT vs RANGE RIGHT — bẫy kinh điển

Với biên `'2025-01-01'`:

| | Giá trị `'2025-01-01'` thuộc về |
|---|---|
| `RANGE LEFT` | partition **bên trái** (partition cũ) → khoảng `(... , '2025-01-01']` |
| `RANGE RIGHT` | partition **bên phải** (partition mới) → khoảng `['2025-01-01', ...)` |

> 🎯 Với dữ liệu **ngày tháng, luôn dùng `RANGE RIGHT`** — biên là ngày đầu kỳ, tránh hoàn toàn rắc rối về phần thời gian 23:59:59.997.

### 7.3. Sliding Window (SWITCH) — nghiệp vụ lưu trữ chuẩn

`SWITCH PARTITION` là thao tác **metadata-only**, gần như **tức thời**, không ghi transaction log dữ liệu — thay thế cho `DELETE` hàng chục triệu dòng.

**Điều kiện bắt buộc để SWITCH thành công (đề rất hay hỏi):**
1. Bảng nguồn và đích **cùng filegroup** với partition đó.
2. **Cấu trúc cột giống hệt** (kiểu, nullability, thứ tự, collation).
3. Mọi index trên bảng phân vùng phải **aligned** (dùng cùng partition scheme + cột phân vùng); index nonclustered không aligned → phải drop.
4. Bảng đích phải **rỗng** (khi switch OUT) và có **CHECK constraint** giới hạn đúng khoảng giá trị (khi switch IN).
5. Không có FK trỏ **tới** bảng đích; các thuộc tính khác (compression, indexed view) phải khớp.

Chu trình sliding window đầy đủ:
```sql
-- 1. Chuẩn bị partition mới ở cuối
ALTER PARTITION SCHEME  PS_ByYear NEXT USED FG2027;
ALTER PARTITION FUNCTION PF_ByYear() SPLIT RANGE ('2027-01-01');

-- 2. Đẩy partition cũ nhất ra bảng staging (tức thời)
ALTER TABLE dbo.FactSales SWITCH PARTITION 2 TO dbo.FactSales_Archive PARTITION 2;

-- 3. Gộp biên đã trống
ALTER PARTITION FUNCTION PF_ByYear() MERGE RANGE ('2024-01-01');
```

> ⚠️ **Luôn `SPLIT` một partition rỗng** và **`MERGE` biên của partition rỗng**. Split/merge trên partition có dữ liệu gây **di chuyển dữ liệu vật lý + khóa bảng + phình log**.

### 7.4. Kiến thức bổ trợ

- Tối đa **15.000 partition**/bảng.
- `$PARTITION.PF_ByYear(@value)` → cho biết giá trị rơi vào partition số mấy.
- `TRUNCATE TABLE dbo.FactSales WITH (PARTITIONS (2, 4 TO 6));` — xóa nhanh theo partition (2016+).
- **Partition elimination**: optimizer chỉ đọc partition liên quan — **chỉ hoạt động khi `WHERE` lọc trực tiếp trên cột phân vùng** (đừng bọc hàm quanh nó!).
- Cột phân vùng **phải nằm trong khóa** của mọi unique index/PK phân vùng.
- Nén khác nhau theo partition: `REBUILD PARTITION = 2 WITH (DATA_COMPRESSION = COLUMNSTORE_ARCHIVE)`.
- Mục đích chính của partitioning là **quản trị dữ liệu (load/archive/maintenance)**, hiệu năng truy vấn chỉ là lợi ích phụ. Đừng chọn đáp án "partition để tăng tốc OLTP".

---

## 8. VIEWS

### 8.1. Các tùy chọn khi tạo view

| Tùy chọn | Tác dụng |
|---|---|
| `WITH SCHEMABINDING` | Khóa schema bảng nguồn (không được `DROP`/`ALTER` cột đang dùng). **Bắt buộc** cho indexed view |
| `WITH ENCRYPTION` | Che định nghĩa (không phải cơ chế bảo mật thực sự) |
| `WITH CHECK OPTION` | Chặn `INSERT`/`UPDATE` tạo ra dòng **không còn nhìn thấy** qua view |
| `WITH VIEW_METADATA` | Trả metadata của view thay vì bảng gốc |

### 8.2. Indexed View (Materialized View)

**Điều kiện tạo `UNIQUE CLUSTERED INDEX` trên view — danh sách "vàng":**
- View phải `WITH SCHEMABINDING`, tham chiếu **tên hai phần** (`dbo.Bang`).
- Chỉ dùng hàm **deterministic**; không `GETDATE()`, `NEWID()`, `RAND()`.
- **Cấm**: `OUTER JOIN`, `UNION`, `DISTINCT`, `TOP`, `subquery`, `CTE`, `ORDER BY`, hàm cửa sổ, `MIN`/`MAX`/`AVG` khi có `GROUP BY`, `COUNT(*)`.
- Nếu có `GROUP BY` thì **bắt buộc có `COUNT_BIG(*)`** trong danh sách select (để engine bảo trì tăng dần).
- 7 tùy chọn SET phải `ON` khi tạo & khi ghi dữ liệu: `ANSI_NULLS`, `ANSI_PADDING`, `ANSI_WARNINGS`, `ARITHABORT`, `CONCAT_NULL_YIELDS_NULL`, `QUOTED_IDENTIFIER`; và `NUMERIC_ROUNDABORT` phải `OFF`.
- Index đầu tiên **phải là UNIQUE CLUSTERED**.

> 💡 **Automatic matching**: bản Enterprise/Developer/Azure SQL, optimizer có thể tự dùng indexed view kể cả khi truy vấn không nhắc tên view. Các bản khác (Standard) phải chỉ định `WITH (NOEXPAND)`.
> ⚠️ Cái giá: mọi `INSERT/UPDATE/DELETE` trên bảng nền phải cập nhật đồng bộ indexed view → **giảm tốc độ ghi**. Không dùng cho bảng ghi nặng.

### 8.3. Cập nhật qua view

View **updatable** khi: chỉ đụng tới **một** bảng nền, không `DISTINCT`/`GROUP BY`/aggregate/`UNION`, cột đích không phải computed. Nếu vi phạm → dùng **`INSTEAD OF` trigger** để tự viết logic ghi.

---

## 9. HÀM (FUNCTIONS)

### 9.1. Ba loại + so sánh hiệu năng

| Loại | Cú pháp | Hiệu năng | Ghi chú |
|---|---|---|---|
| **Scalar UDF** | `RETURNS INT ... BEGIN ... END` | ❌ Tệ nhất (gọi từng dòng, chặn parallelism) | SQL 2019+ có **UDF inlining** (Froid) cứu vãn nếu đủ điều kiện |
| **Inline TVF (iTVF)** | `RETURNS TABLE AS RETURN (SELECT ...)` | ✅ **Tốt nhất** — được "nở" vào query như view có tham số | Ưu tiên tuyệt đối |
| **Multi-statement TVF (mTVF)** | `RETURNS @t TABLE (...) BEGIN ... END` | ⚠️ Kém — ước lượng số dòng cố định (100 từ 2014+; 1 ở bản cũ) | SQL 2017+ có *interleaved execution* giúp ước lượng đúng |

> 🎯 **Câu hỏi tủ:** "Hàm bảng đang gây chậm, viết lại thế nào?" → **Chuyển mTVF thành iTVF** (viết lại thành một câu `SELECT` duy nhất).

### 9.2. Scalar UDF Inlining (SQL Server 2019+)

Yêu cầu: compatibility level ≥ 150. Kiểm tra khả năng inline:
```sql
SELECT name, is_inlineable FROM sys.sql_modules m JOIN sys.objects o ON ...;
```
Tắt/bật thủ công: `CREATE FUNCTION ... WITH INLINE = OFF`.
**Không inline được** nếu hàm có: vòng lặp `WHILE`, `EXEC`, biến bảng, truy cập bảng tạm, gọi `GETDATE()` trong một số ngữ cảnh, đệ quy, `TIME ZONE` conversions...

### 9.3. Các tùy chọn quan trọng

- `WITH SCHEMABINDING` → giúp hàm được coi là deterministic hơn, cần cho index trên computed column dùng hàm.
- `RETURNS NULL ON NULL INPUT` → bỏ qua thân hàm khi tham số NULL (nhanh hơn).
- Trong hàm **không được**: gọi thủ tục lưu trữ (trừ extended), dùng `TRY...CATCH`, thao tác thay đổi dữ liệu bảng thật, `RAISERROR`/`THROW`.

---

## 10. TRIGGERS

### 10.1. Ba loại

| Loại | Kích hoạt bởi | Bảng ảo | Ghi chú |
|---|---|---|---|
| **DML AFTER/FOR** | `INSERT`/`UPDATE`/`DELETE` sau khi ràng buộc đã kiểm tra | `inserted`, `deleted` | Chỉ trên bảng, **không** trên view |
| **DML INSTEAD OF** | thay thế lệnh gốc | `inserted`, `deleted` | Dùng được trên **view**; không dùng được với FK có `CASCADE` |
| **DDL** | `CREATE`/`ALTER`/`DROP` (scope DATABASE hoặc ALL SERVER) | `EVENTDATA()` (XML) | Audit thay đổi schema, chặn `DROP TABLE` |
| **LOGON** | phiên đăng nhập | `EVENTDATA()` | Giới hạn số kết nối, chặn theo giờ |

### 10.2. Quy tắc sống còn

- Trigger **luôn chạy theo tập hợp (set-based)**, KHÔNG chạy 1 lần/dòng. Viết trigger giả định `inserted` chỉ có 1 dòng là **lỗi kinh điển** → phải viết dạng `JOIN`, không dùng `SELECT @var = ... FROM inserted`.
- Phân biệt thao tác trong 1 trigger:
  ```sql
  IF EXISTS(SELECT 1 FROM inserted) AND EXISTS(SELECT 1 FROM deleted) -- UPDATE
  IF EXISTS(SELECT 1 FROM inserted) AND NOT EXISTS(SELECT 1 FROM deleted) -- INSERT
  ```
- `UPDATE(ColName)` / `COLUMNS_UPDATED()` → kiểm tra cột nào bị đụng tới.
- **`TRUNCATE TABLE` KHÔNG kích hoạt DML trigger** (cũng không log từng dòng) → nếu yêu cầu là "mọi thao tác xóa đều phải được ghi vết", phải **thu hồi quyền TRUNCATE**.
- `BULK INSERT`/`bcp` mặc định **không** bắn trigger, trừ khi chỉ định `FIRE_TRIGGERS`.
- Trigger nằm **trong cùng transaction** với lệnh gốc → `ROLLBACK TRANSACTION` trong trigger sẽ hủy cả lệnh gốc. Luôn `SET NOCOUNT ON`.
- **Nested triggers** (mặc định ON, tối đa 32 cấp) vs **recursive triggers** (mặc định OFF, cấp DB).
- Nhiều trigger cùng loại trên 1 bảng → chỉ điều khiển được cái **đầu tiên và cuối cùng** bằng `sp_settriggerorder`.

### 10.3. Khi nào KHÔNG dùng trigger

| Nhu cầu | Giải pháp tốt hơn trigger |
|---|---|
| Ghi lịch sử thay đổi dữ liệu | **Temporal table** |
| Chống giả mạo, audit tuân thủ | **Ledger table** |
| Kiểm tra giá trị hợp lệ | **CHECK constraint** |
| Lấy dữ liệu vừa ghi | **`OUTPUT` clause** |
| Đồng bộ ra hệ thống khác | **Change Data Capture / Change Tracking / CES** |

> Trigger là công cụ mạnh nhưng **ẩn**, khó debug, và chạy đồng bộ trong transaction → luôn cân nhắc phương án khai báo (declarative) trước.

---

## 11. BẢNG QUYẾT ĐỊNH NHANH (in ra ôn trước giờ thi)

| Đề bài nói... | Đáp án |
|---|---|
| Báo cáo tổng hợp real-time trên OLTP đang chạy | **Nonclustered Columnstore Index** |
| Kho dữ liệu, bảng fact hàng trăm triệu dòng | **Clustered Columnstore Index** |
| Truy vấn "dữ liệu trông thế nào hôm 01/01" | **Temporal table + `FOR SYSTEM_TIME AS OF`** |
| "Tamper-evident", chứng minh với kiểm toán bằng mật mã | **Ledger table** |
| Chỉ được INSERT, cấm sửa/xóa vĩnh viễn | **Append-only ledger table** |
| Xóa 200 triệu dòng cũ mà không phình log, không downtime | **SWITCH PARTITION** sang bảng archive |
| Giao dịch cực nhanh, nghẽn ở lock/latch | **Memory-optimized table + natively compiled SP** |
| Bảng staging tạm cho ETL, tốc độ tối đa, không cần bền vững | **Memory-optimized `DURABILITY = SCHEMA_ONLY`** |
| Nhiều bảng dùng chung dãy số, cần biết ID trước | **SEQUENCE** |
| Ép duy nhất nhưng cho phép nhiều NULL | **Unique filtered index** `WHERE col IS NOT NULL` |
| Tăng tốc `WHERE JSON_VALUE(...)` | **Computed column + index** (hoặc **JSON INDEX** trên kiểu `JSON`) |
| Tổng hợp lặp lại tốn kém, bảng nền ít thay đổi | **Indexed view** |
| Query dùng indexed view nhưng bản Standard | Thêm hint **`WITH (NOEXPAND)`** |
| Hàm bảng chạy chậm, ước lượng dòng sai | **Viết lại thành inline TVF** |
| Tìm kiếm ngữ nghĩa trên tài liệu (RAG) | **`VECTOR` + `VECTOR_DISTANCE`/vector index** |
| Truy vấn Parquet trên data lake, không nạp vào SQL | **External table (PolyBase)** |
| Quan hệ nhiều tầng, độ sâu không xác định | **Graph table + `MATCH` / `SHORTEST_PATH`** |
| Cần index nhưng tuyệt đối không downtime | **`WITH (ONLINE = ON, RESUMABLE = ON)`** |
| Nghẽn chèn ở trang cuối (PAGELATCH_EX) | **`OPTIMIZE_FOR_SEQUENTIAL_KEY = ON`** |

---

## 12. LỘ TRÌNH ÔN 7 NGÀY CHO MIỀN 1

| Ngày | Nội dung | Lab |
|---|---|---|
| 1 | Kiểu dữ liệu, computed column, IDENTITY/SEQUENCE, constraint | Lab 01 |
| 2 | Index rowstore: key vs include, filtered, bảo trì, đọc execution plan | Lab 02 (phần A) |
| 3 | Columnstore: rowgroup, delta store, CCI vs NCCI, ordered CCI | Lab 02 (phần B) |
| 4 | Temporal, Ledger, Graph, Memory-optimized, Vector | Lab 03 (phần A) |
| 5 | JSON: hàm, OPENJSON, FOR JSON, đánh chỉ mục | Lab 03 (phần B) |
| 6 | Partitioning + Sliding window | Lab 04 |
| 7 | View / Function / Trigger + làm bộ Quiz | Lab 05 + Quiz |

**Cách học hiệu quả nhất:** chạy từng lab, **cố tình làm sai** (bỏ `COUNT_BIG(*)` khi tạo indexed view, `SWITCH` khi thiếu CHECK constraint, `CHECK` với giá trị NULL...) rồi đọc thông báo lỗi. Đề thi hỏi chính xác những thông báo lỗi đó.
