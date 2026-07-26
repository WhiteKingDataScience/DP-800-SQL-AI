# DP-800 — MIỀN 1: BỘ CÂU HỎI TỰ KIỂM TRA (60 câu)

> Đi kèm [Claude_DP800_D1_Design_Guide.md](./Claude_DP800_D1_Design_Guide.md).
> **Cách dùng:** làm hết phần A trước, chấm điểm, rồi mới đọc phần đáp án B.
> Mục tiêu: **≥ 48/60 (80%)** trước khi vào phòng thi.
> Đáp án kèm **giải thích + vì sao các lựa chọn khác sai** — phần này quan trọng
> hơn điểm số, vì đề thật đổi số liệu chứ không đổi nguyên lý.

---

# PHẦN A — CÂU HỎI

## A1. Thiết kế bảng & kiểu dữ liệu (câu 1–8)

**1.** Ứng dụng kế toán cần lưu số tiền và phải cộng dồn hàng triệu bản ghi mà không sai lệch. Chọn kiểu dữ liệu:
- A. `FLOAT(53)` B. `REAL` C. `DECIMAL(19,4)` D. `NVARCHAR(50)`

**2.** Bảng có clustered PK trên `UNIQUEIDENTIFIER DEFAULT NEWID()` bị phân mảnh 98% sau một tuần. Giải pháp **ít thay đổi ứng dụng nhất**?
- A. Đổi PK sang `INT IDENTITY`
- B. Đổi DEFAULT sang `NEWSEQUENTIALID()`
- C. Chạy `ALTER INDEX ... REORGANIZE` mỗi giờ
- D. Đặt `FILLFACTOR = 50`

**3.** Cột computed `Margin AS (Revenue - Cost)` với `Revenue`, `Cost` kiểu `FLOAT`. Muốn tạo index trên `Margin` cần gì?
- A. Không cần gì, tạo được ngay
- B. Thêm `PERSISTED`
- C. Thêm `WITH SCHEMABINDING`
- D. Đổi index thành filtered index

**4.** Ba bảng `Invoice`, `CreditNote`, `DebitNote` phải dùng chung một dãy số chứng từ liên tục, và ứng dụng cần biết số trước khi ghi. Chọn:
- A. `IDENTITY` trên mỗi bảng B. `SEQUENCE` C. `NEWID()` D. `ROW_NUMBER()`

**5.** Cột `MiddleName` NULL ở 85% số dòng, bảng 200 triệu dòng. Kỹ thuật tiết kiệm dung lượng phù hợp nhất?
- A. `SPARSE` B. `DATA_COMPRESSION = PAGE` C. Sparse + `COLUMN_SET` D. Cả A và C đều đúng tuỳ nhu cầu truy cập

**6.** Câu nào **SAI** về `NVARCHAR(MAX)`?
- A. Không dùng làm key column của index B-Tree
- B. Dùng được làm `INCLUDE` column
- C. Lưu off-row khi vượt 8000 bytes
- D. Có thể là cột phân vùng

**7.** Bạn cần index một cột chỉ dùng ở `SELECT`, không bao giờ ở `WHERE`/`JOIN`/`ORDER BY`. Đặt nó ở đâu?
- A. Key column đầu tiên B. Key column cuối cùng C. `INCLUDE` D. Filtered index

**8.** Bảng OLTP có nhiều phiên chèn song song, chờ `PAGELATCH_EX` trên trang cuối của clustered index `IDENTITY`. Đáp án ưu tiên của DP-800:
- A. Tăng `FILLFACTOR` B. `OPTIMIZE_FOR_SEQUENTIAL_KEY = ON` C. Thêm NCCI D. Bỏ clustered index

---

## A2. Ràng buộc (câu 9–14)

**9.** `CHECK (Age > 18)` trên cột `Age INT NULL`. Lệnh `INSERT ... VALUES (NULL)` sẽ:
- A. Thất bại, Msg 547 B. Thành công C. Thành công nhưng ghi 0 D. Thất bại vì NULL không so sánh được

**10.** Cần đảm bảo `Email` là duy nhất nhưng cho phép **nhiều** dòng NULL. Chọn:
- A. `UNIQUE` constraint B. `PRIMARY KEY` C. Unique filtered index `WHERE Email IS NOT NULL` D. `CHECK` constraint

**11.** Sau `ALTER TABLE T WITH NOCHECK ADD CONSTRAINT CK CHECK(...)`, hậu quả nào là **nghiêm trọng nhất về hiệu năng**?
- A. Constraint không hoạt động với dữ liệu mới
- B. Query Optimizer không dùng constraint để tối ưu (untrusted)
- C. Bảng bị khoá
- D. Statistics bị vô hiệu

**12.** Câu nào **đúng** về FOREIGN KEY?
- A. Tự động tạo index trên cột FK ở bảng con
- B. Không cho phép NULL ở cột FK
- C. Cột được tham chiếu phải có PK hoặc UNIQUE
- D. Mỗi bảng chỉ có 1 FK

**13.** `CREATE TABLE Trip (FromCityId INT REFERENCES City(CityId) ON DELETE CASCADE, ToCityId INT REFERENCES City(CityId) ON DELETE CASCADE)` gây lỗi Msg 1785. Cách xử lý đúng?
- A. Bỏ cả hai FK
- B. Đổi một trong hai thành `NO ACTION` (hoặc cả hai) và xử lý logic bằng trigger/SP
- C. Đổi thành `SET NULL` cho cả hai
- D. Tạo index trên cả hai cột

**14.** Muốn tìm mọi constraint đang ở trạng thái untrusted trong database, bạn truy vấn:
- A. `sys.objects` B. `sys.check_constraints` và `sys.foreign_keys` với `is_not_trusted = 1`
- C. `sys.indexes` D. `sys.dm_db_index_usage_stats`

---

## A3. Index rowstore (câu 15–22)

**15.** Truy vấn `WHERE CustomerId = @c AND OrderDate >= @d`. Thứ tự cột khóa tối ưu?
- A. `(OrderDate, CustomerId)` B. `(CustomerId, OrderDate)` C. `(OrderDate)` INCLUDE CustomerId D. Không quan trọng

**16.** Execution plan hiện "Index Seek + Key Lookup + Nested Loops". Cách loại bỏ Key Lookup?
- A. Rebuild index B. `INCLUDE` các cột còn thiếu vào index C. Cập nhật statistics D. Thêm `OPTION(RECOMPILE)`

**17.** Điều kiện nào làm truy vấn trở nên **non-sargable**?
- A. `WHERE OrderDate >= '2025-01-01'` B. `WHERE YEAR(OrderDate) = 2025`
- C. `WHERE CustomerId IN (1,2,3)` D. `WHERE Name LIKE 'abc%'`

**18.** Index phân mảnh 22%, có 5000 trang. Theo khuyến nghị của Microsoft, làm gì?
- A. Bỏ qua B. `REORGANIZE` C. `REBUILD` D. `DROP` và tạo lại

**19.** Điểm khác biệt nào là **đúng** giữa REORGANIZE và REBUILD?
- A. REORGANIZE cập nhật statistics, REBUILD thì không
- B. REBUILD cập nhật statistics (FULLSCAN), REORGANIZE thì không
- C. Cả hai đều luôn online
- D. REORGANIZE không thể dừng giữa chừng

**20.** Đã tạo filtered index `WHERE Status = 4` nhưng truy vấn `WHERE Status = @st` không dùng nó. Cách khắc phục nhanh nhất?
- A. Rebuild index B. Thêm `OPTION (RECOMPILE)` C. Đổi thành index thường D. Cập nhật statistics

**21.** Cần rebuild index 500 GB trên hệ thống 24/7, và thao tác có thể bị gián đoạn do failover. Chọn tuỳ chọn:
- A. `ONLINE = ON` B. `ONLINE = ON, RESUMABLE = ON` C. `MAXDOP = 1` D. `SORT_IN_TEMPDB = ON`

**22.** Index có `user_seeks = 0, user_scans = 0, user_lookups = 0, user_updates = 2,000,000`. Kết luận?
- A. Index rất quan trọng B. Ứng viên để DROP vì chỉ tốn chi phí ghi
- C. Cần rebuild D. Thiếu statistics

---

## A4. Columnstore (câu 23–30)

**23.** Bảng OLTP `Orders` đang ghi liên tục 24/7. Cần dashboard tổng hợp **real-time** mà không sao chép dữ liệu và không ảnh hưởng nhiều tới ghi. Chọn:
- A. Clustered Columnstore Index B. Nonclustered Columnstore Index
- C. Indexed view D. Temporal table

**24.** Bảng fact 800 triệu dòng trong kho dữ liệu, chỉ nạp theo lô hàng đêm và quét tổng hợp. Chọn:
- A. CCI B. NCCI C. Heap + NCI D. Memory-optimized table

**25.** Số dòng lý tưởng của một rowgroup nén, và ngưỡng bulk-load để ghi thẳng vào rowgroup nén (bỏ qua delta store), lần lượt là:
- A. 102.400 và 1.048.576 B. 1.048.576 và 102.400 C. 1.000.000 và 100.000 D. 8.060 và 102.400

**26.** `state_desc = 'OPEN'` của một rowgroup nghĩa là gì?
- A. Đã nén, sẵn sàng đọc B. Delta store, đang lưu dạng rowstore, CHƯA nén
- C. Rowgroup rỗng chờ dọn D. Đủ dòng, chờ Tuple Mover

**27.** `DELETE` trên rowgroup đã nén thực chất làm gì?
- A. Xoá vật lý ngay B. Đánh dấu vào delete bitmap, dữ liệu vẫn còn
- C. Chuyển dòng sang delta store D. Rebuild rowgroup

**28.** Bảng CCI có `deleted_rows` chiếm 25% tổng số dòng. Hành động đúng?
- A. Không làm gì B. `ALTER INDEX ... REORGANIZE` (hoặc REBUILD) để dọn
- C. `TRUNCATE TABLE` D. Tạo thêm NCCI

**29.** `CREATE CLUSTERED COLUMNSTORE INDEX ... ORDER (OrderDate)` giải quyết bài toán gì?
- A. Ép duy nhất theo OrderDate
- B. Tăng hiệu quả **segment elimination** khi lọc theo dải OrderDate
- C. Thay thế partitioning
- D. Cho phép UPDATE nhanh hơn

**30.** Trường hợp nào **không nên** dùng columnstore?
- A. Bảng fact 500 triệu dòng
- B. Bảng 50.000 dòng có nhiều UPDATE lẻ tẻ và tra cứu theo khóa
- C. Truy vấn tổng hợp SUM/COUNT trên vài cột
- D. Bảng rộng 60 cột nhưng truy vấn chỉ đọc 4 cột

---

## A5. Bảng chuyên biệt (câu 31–40)

**31.** Yêu cầu: "truy vấn xem dữ liệu bảng `Employee` trông như thế nào vào 01/03/2026". Chọn:
- A. Temporal table + `FOR SYSTEM_TIME AS OF` B. Ledger table C. CDC D. Trigger + bảng lịch sử

**32.** Yêu cầu: "kiểm toán viên phải chứng minh bằng **mật mã** rằng dữ liệu chưa từng bị sửa, kể cả bởi DBA". Chọn:
- A. Temporal table B. Ledger table C. Always Encrypted D. TDE

**33.** Mệnh đề nào trả về các dòng **nằm trọn** trong khoảng thời gian cho trước?
- A. `FOR SYSTEM_TIME AS OF` B. `FROM ... TO ...` C. `BETWEEN ... AND ...` D. `CONTAINED IN (...)`

**34.** Bảng temporal history **không được** có gì?
- A. Clustered index B. PRIMARY KEY, FOREIGN KEY, IDENTITY, constraint
- C. Nén dữ liệu D. Columnstore index

**35.** Bảng staging cho ETL, cần tốc độ ghi tối đa, dữ liệu mất khi restart cũng không sao. Chọn:
- A. `#temp` table B. Memory-optimized `DURABILITY = SCHEMA_ONLY`
- C. Memory-optimized `DURABILITY = SCHEMA_AND_DATA` D. Table variable

**36.** Trên bảng memory-optimized, index nào hỗ trợ truy vấn dải (`BETWEEN`, `>`)?
- A. HASH index B. NONCLUSTERED (Bw-tree) index C. Clustered index D. Columnstore

**37.** `BUCKET_COUNT` của HASH index nên đặt bằng bao nhiêu?
- A. Bằng số dòng tối đa B. ~1–2× số giá trị DISTINCT của cột khóa, làm tròn lên lũy thừa 2
- C. Luôn 1024 D. Bằng số CPU core

**38.** Bài toán "tìm chuỗi quan hệ giữa hai người trong mạng lưới, độ sâu không xác định". Chọn:
- A. Recursive CTE B. Graph table + `SHORTEST_PATH` C. HIERARCHYID D. Self-join

**39.** Thứ tự đúng để tạo external table trên Azure Blob (CSV)?
- A. External table → data source → file format → credential
- B. Master key → credential → data source → file format → external table
- C. Data source → external table → credential → file format
- D. File format → external table → data source → credential

**40.** Với SQL Server 2025, tìm 5 đoạn văn bản gần nghĩa nhất với câu hỏi người dùng trên bảng 50 triệu chunk. Chọn cách **hiệu quả nhất**:
- A. `VECTOR_DISTANCE` + `ORDER BY` toàn bảng
- B. `CREATE VECTOR INDEX` + `VECTOR_SEARCH` (ANN)
- C. Full-text index
- D. `LIKE '%...%'`

---

## A6. JSON (câu 41–46)

**41.** `JSON_VALUE(@j, '$.specs')` với `specs` là một object. Kết quả (lax mode)?
- A. Trả chuỗi JSON của object B. Trả NULL C. Báo lỗi D. Trả rỗng

**42.** Muốn lấy nguyên mảng `$.tags` ra dưới dạng chuỗi JSON, dùng:
- A. `JSON_VALUE` B. `JSON_QUERY` C. `OPENJSON` D. `JSON_MODIFY`

**43.** Trong `OPENJSON(...) WITH (Tags NVARCHAR(MAX) '$.tags')`, cột `Tags` trả NULL. Nguyên nhân?
- A. Đường dẫn sai B. Thiếu từ khoá `AS JSON` C. Kiểu dữ liệu sai D. Cần `CROSS APPLY`

**44.** `JSON_MODIFY(@j, '$.warranty', NULL)` ở lax mode làm gì?
- A. Gán giá trị null cho key B. **Xoá** key `warranty` C. Báo lỗi D. Không làm gì

**45.** Cách tăng tốc `WHERE JSON_VALUE(Attributes,'$.brand') = 'Dell'` trên SQL Server 2022?
- A. Full-text index B. Computed column `CAST(JSON_VALUE(...) AS NVARCHAR(50))` + index
- C. Columnstore index D. Không thể tăng tốc

**46.** Khi nào **không** nên dùng JSON mà nên dùng cột quan hệ?
- A. Thuộc tính thưa, thay đổi theo từng loại sản phẩm
- B. Thuộc tính cốt lõi, thường xuyên lọc/JOIN/cần FK và UNIQUE
- C. Payload nguyên vẹn từ API bên ngoài
- D. Dữ liệu bán cấu trúc ít khi truy vấn

---

## A7. Phân vùng (câu 47–52)

**47.** `CREATE PARTITION FUNCTION PF (DATE) AS RANGE RIGHT FOR VALUES ('2024-01-01','2025-01-01','2026-01-01')` tạo ra bao nhiêu partition?
- A. 3 B. 4 C. 5 D. Tuỳ số filegroup

**48.** Với `RANGE RIGHT` và biên `'2025-01-01'`, giá trị `'2025-01-01'` thuộc partition nào?
- A. Partition bên trái (cũ) B. Partition bên phải (mới) C. Cả hai D. Không thuộc partition nào

**49.** Thứ tự đúng của một chu trình sliding window?
- A. SPLIT → NEXT USED → MERGE → SWITCH
- B. NEXT USED → SPLIT → SWITCH OUT → MERGE
- C. SWITCH → SPLIT → NEXT USED → MERGE
- D. MERGE → SWITCH → SPLIT → NEXT USED

**50.** `ALTER TABLE FactSales SWITCH PARTITION 2 TO FactSales_Archive` báo Msg 4904 "not in the same filegroup". Nguyên nhân?
- A. Bảng đích không rỗng B. Bảng đích nằm trên filegroup khác với partition 2
- C. Thiếu CHECK constraint D. Index không aligned

**51.** Điều kiện nào **không** bắt buộc để SWITCH thành công?
- A. Cùng filegroup B. Cấu trúc cột giống hệt C. Mọi index aligned D. Hai bảng cùng số dòng

**52.** `WHERE YEAR(OrderDate) = 2025` trên bảng phân vùng theo `OrderDate` gây hậu quả gì?
- A. Báo lỗi B. Mất partition elimination, quét tất cả partition
- C. Chỉ quét 1 partition D. Tự động dùng index

---

## A8. View / Function / Trigger (câu 53–60)

**53.** `CREATE UNIQUE CLUSTERED INDEX` trên view thất bại với Msg 1939. Thiếu gì?
- A. `COUNT_BIG(*)` B. `WITH SCHEMABINDING` C. `WITH CHECK OPTION` D. Tên hai phần

**54.** View có `GROUP BY` muốn tạo indexed view **bắt buộc** phải có:
- A. `COUNT(*)` B. `COUNT_BIG(*)` C. `DISTINCT` D. `ORDER BY`

**55.** Yếu tố nào **được phép** trong một indexed view?
- A. `LEFT OUTER JOIN` B. `UNION ALL` C. `SUM()` với `GROUP BY` + `COUNT_BIG(*)` D. `TOP 100`

**56.** Trên SQL Server Standard Edition, truy vấn không tự dùng indexed view. Khắc phục:
- A. Rebuild index của view B. Thêm hint `WITH (NOEXPAND)` C. Bỏ SCHEMABINDING D. Nâng compatibility level

**57.** TVF chạy chậm, plan cho thấy ước lượng 100 dòng nhưng thực tế 500.000. Cách sửa tốt nhất:
- A. Cập nhật statistics B. Viết lại thành **inline TVF** C. Thêm `OPTION(RECOMPILE)` D. Đổi thành scalar UDF

**58.** Điều nào làm scalar UDF **không** inline được (SQL 2019+)?
- A. Có một câu `SELECT` duy nhất B. Có vòng lặp `WHILE` hoặc biến bảng
- C. Có `WITH SCHEMABINDING` D. Trả về `INT`

**59.** Trigger chứa `SELECT @id = CustomerId FROM inserted` rồi ghi audit. Lỗi gì?
- A. Không có lỗi B. Chỉ ghi được 1 dòng khi INSERT nhiều dòng (trigger chạy set-based)
- C. Gây deadlock D. Thiếu `SET NOCOUNT ON`

**60.** Yêu cầu "mọi thao tác xoá dữ liệu phải được ghi vết". Chỉ tạo AFTER DELETE trigger là **chưa đủ** vì:
- A. Trigger có thể bị disable
- B. `TRUNCATE TABLE` không kích hoạt DML trigger ⇒ phải thu hồi quyền `ALTER`
- C. Trigger không ghi được người dùng
- D. `DELETE` hàng loạt bỏ qua trigger

---
---

# PHẦN B — ĐÁP ÁN & GIẢI THÍCH

| # | Đ.A | Giải thích ngắn |
|---|---|---|
| 1 | **C** | `DECIMAL` là exact numeric. `FLOAT`/`REAL` là xấp xỉ ⇒ sai số cộng dồn. `NVARCHAR` không tính toán được. |
| 2 | **B** | `NEWSEQUENTIALID()` giữ nguyên kiểu cột và ứng dụng, chỉ đổi DEFAULT ⇒ ít tác động nhất. A đúng về kỹ thuật nhưng phải sửa toàn bộ ứng dụng. C/D chỉ giảm triệu chứng. |
| 3 | **B** | Biểu thức dùng `FLOAT` là **imprecise** ⇒ bắt buộc `PERSISTED` mới index được (Msg 2799). |
| 4 | **B** | `SEQUENCE` là đối tượng độc lập, dùng chung nhiều bảng, và `NEXT VALUE FOR` lấy được số **trước** khi INSERT. `IDENTITY` không làm được cả hai. |
| 5 | **D** | `SPARSE` tối ưu cho NULL nhiều; thêm `COLUMN_SET` khi cần đọc/ghi hàng loạt cột thưa. Lưu ý SPARSE không kết hợp với nén PAGE. |
| 6 | **D** | LOB không dùng làm cột phân vùng. A, B, C đều đúng. |
| 7 | **C** | Cột chỉ ở SELECT list ⇒ `INCLUDE` (nằm ở leaf, không phình cây, không tính vào giới hạn 1700 bytes). |
| 8 | **B** | `OPTIMIZE_FOR_SEQUENTIAL_KEY` (SQL 2019+) là tính năng chuyên trị last-page insert contention. |
| 9 | **B** | `NULL > 18` = UNKNOWN; CHECK chỉ từ chối khi FALSE ⇒ NULL lọt lưới. |
| 10 | **C** | `UNIQUE` chỉ cho **một** NULL. Unique filtered index là đáp án chuẩn. |
| 11 | **B** | Untrusted ⇒ optimizer bỏ qua constraint khi lập plan (mất constraint elimination). Constraint **vẫn** áp dụng cho dữ liệu mới, nên A sai. |
| 12 | **C** | FK phải trỏ tới PK/UNIQUE. FK **không** tự tạo index (A sai), cho phép NULL (B sai), nhiều FK/bảng (D sai). |
| 13 | **B** | Nhiều đường cascade tới cùng bảng cha bị cấm ⇒ dùng `NO ACTION` + xử lý thủ công. |
| 14 | **B** | Hai catalog view này có cột `is_not_trusted`. |
| 15 | **B** | Equality (`=`) trước, range (`>=`) sau ⇒ seek chính xác rồi quét dải liên tục. |
| 16 | **B** | Key Lookup = index thiếu cột ⇒ `INCLUDE` để thành covering index. |
| 17 | **B** | Hàm bọc quanh cột ⇒ không dùng được index seek. D vẫn sargable vì wildcard ở cuối. |
| 18 | **B** | 5% < 22% ≤ 30% ⇒ REORGANIZE. Trên 30% mới REBUILD. |
| 19 | **B** | REBUILD tạo lại index nên statistics được cập nhật FULLSCAN; REORGANIZE thì không. REORGANIZE luôn online và có thể dừng giữa chừng. |
| 20 | **B** | Tham số hoá làm plan cache không khớp vị từ filtered index ⇒ `OPTION (RECOMPILE)` cho optimizer thấy giá trị thật. |
| 21 | **B** | `RESUMABLE = ON` cho phép PAUSE/RESUME và sống sót qua failover; bắt buộc dùng kèm `ONLINE = ON`. |
| 22 | **B** | Chỉ có chi phí bảo trì, không có lợi ích đọc ⇒ cân nhắc DROP. |
| 23 | **B** | HTAP / real-time operational analytics = **NCCI** trên bảng rowstore. CCI sẽ phá cấu trúc OLTP. |
| 24 | **A** | Kho dữ liệu, bảng fact lớn, nạp theo lô ⇒ CCI. |
| 25 | **B** | Rowgroup lý tưởng 1.048.576 dòng; bulk load ≥ 102.400 dòng ghi thẳng vào rowgroup nén. |
| 26 | **B** | OPEN = delta store, lưu dạng B-Tree rowstore, chưa nén. CLOSED mới là "chờ Tuple Mover". |
| 27 | **B** | Delete bitmap. Đó là lý do columnstore không hợp workload cập nhật nhiều. |
| 28 | **B** | REORGANIZE dọn dòng đã xoá và gộp rowgroup nhỏ. |
| 29 | **B** | ORDERED CCI làm segment min/max không chồng lấn ⇒ loại bỏ rowgroup hiệu quả hơn nhiều. |
| 30 | **B** | Bảng nhỏ + UPDATE lẻ tẻ + tra cứu khóa ⇒ rowstore. |
| 31 | **A** | Temporal + `FOR SYSTEM_TIME AS OF`. |
| 32 | **B** | Ledger: Merkle tree + database digest lưu ngoài ⇒ chống được cả sysadmin. |
| 33 | **D** | `CONTAINED IN` = dòng có toàn bộ khoảng hiệu lực nằm trong khoảng truy vấn. |
| 34 | **B** | History table không được có PK/FK/IDENTITY/constraint và không sửa trực tiếp; vẫn được có clustered index và nén (thường dùng CCI). |
| 35 | **B** | `SCHEMA_ONLY` = nhanh nhất, không ghi log dữ liệu, mất khi restart — đúng yêu cầu. |
| 36 | **B** | HASH chỉ phục vụ tìm bằng (`=`). Range/ORDER BY cần Bw-tree nonclustered. |
| 37 | **B** | 1–2× số DISTINCT, tự làm tròn lên lũy thừa 2. Quá nhỏ ⇒ chuỗi va chạm dài. |
| 38 | **B** | Độ sâu không xác định + nhiều loại quan hệ ⇒ graph + `SHORTEST_PATH`. |
| 39 | **B** | Master key → credential → data source → file format → external table. |
| 40 | **B** | 50 triệu chunk ⇒ ANN với vector index. `VECTOR_DISTANCE` + ORDER BY là exact KNN, quét toàn bảng. |
| 41 | **B** | `JSON_VALUE` chỉ trả scalar; gặp object/array ⇒ NULL ở lax mode (lỗi ở strict mode). |
| 42 | **B** | `JSON_QUERY` trả object/array. |
| 43 | **B** | Cột object/array trong `OPENJSON ... WITH` phải khai `AS JSON` và kiểu `NVARCHAR(MAX)`. |
| 44 | **B** | lax mode: gán NULL = xoá key. Muốn gán null thật phải dùng `strict`. |
| 45 | **B** | Computed column + index; optimizer tự khớp lại biểu thức nên không cần sửa ứng dụng. (SQL 2025 có JSON INDEX.) |
| 46 | **B** | Thuộc tính cốt lõi, cần ràng buộc và JOIN ⇒ cột quan hệ thật. |
| 47 | **B** | n biên ⇒ n+1 partition. |
| 48 | **B** | RANGE RIGHT ⇒ biên thuộc partition bên phải, khoảng `[a, b)`. |
| 49 | **B** | NEXT USED → SPLIT (tạo chỗ) → SWITCH OUT (đẩy dữ liệu cũ) → MERGE (gộp partition rỗng). |
| 50 | **B** | Msg 4904 nói rõ về filegroup. Bảng staging phải nằm đúng filegroup của partition đó. |
| 51 | **D** | Số dòng không liên quan; bảng/partition đích chỉ cần **rỗng** khi switch vào. |
| 52 | **B** | Hàm bọc quanh cột phân vùng ⇒ mất elimination (kiểm chứng bằng "Actual Partitions Accessed"). |
| 53 | **B** | Msg 1939 = "not schema bound". |
| 54 | **B** | `COUNT_BIG(*)` để engine bảo trì tăng dần. `COUNT(*)` không được chấp nhận. |
| 55 | **C** | OUTER JOIN, UNION ALL, TOP đều bị cấm trong indexed view. |
| 56 | **B** | Automatic matching chỉ có ở Enterprise/Developer/Azure SQL; bản khác phải `NOEXPAND`. |
| 57 | **B** | mTVF ước lượng cố định 100 dòng ⇒ viết lại thành iTVF để optimizer thấy thống kê thật. |
| 58 | **B** | WHILE, biến bảng, bảng tạm, EXEC, đệ quy... đều chặn inlining. |
| 59 | **B** | `inserted` là **bảng** có thể nhiều dòng; phải viết set-based bằng JOIN. |
| 60 | **B** | `TRUNCATE` (và `BULK INSERT` mặc định) không bắn trigger ⇒ phải kiểm soát bằng quyền. |

---

## THANG ĐIỂM

| Điểm | Nhận định |
|---|---|
| 54–60 | Sẵn sàng thi miền 1. Chuyển sang miền khác. |
| 48–53 | Đạt. Đọc lại đúng các mục sai, làm lại lab tương ứng. |
| 40–47 | Chưa an toàn. Ôn lại toàn bộ guide + chạy lại Lab 02, 04, 05. |
| < 40 | Học lại từ đầu theo lộ trình 7 ngày ở mục 12 của guide. |

## BẢN ĐỒ CÂU HỎI → TÀI LIỆU ÔN

| Câu | Mục trong Guide | Lab |
|---|---|---|
| 1–8 | 1. Thiết kế bảng | Lab 01 §1–4, 10 |
| 9–14 | 2. Ràng buộc | Lab 01 §5–9 |
| 15–22 | 3. Index rowstore | Lab 02 §2–7 |
| 23–30 | 4. Columnstore | Lab 02 §8–13 |
| 31–40 | 5. Bảng chuyên biệt | Lab 03 §1–6 |
| 41–46 | 6. JSON | Lab 03 §7–11 |
| 47–52 | 7. Phân vùng | Lab 04 (toàn bộ) |
| 53–60 | 8–10. View/Function/Trigger | Lab 05 (toàn bộ) |
