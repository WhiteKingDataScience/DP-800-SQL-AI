# DP-800 — MIỀN 2: BỘ CÂU HỎI TỰ KIỂM TRA (60 câu)

> Đi kèm [Claude_DP800_D2_SecurityPerfDeploy_Guide.md](./Claude_DP800_D2_SecurityPerfDeploy_Guide.md).
> **Cách dùng:** làm hết phần A, chấm điểm, rồi mới đọc đáp án phần B.
> Mục tiêu: **≥ 48/60 (80%)**.

---

# PHẦN A — CÂU HỎI

## A1. Mã hoá (câu 1–10)

**1.** Công ty lo ngại băng backup bị đánh cắp. Yêu cầu: không được sửa ứng dụng. Chọn:
- A. Always Encrypted B. TDE C. Dynamic Data Masking D. Row-Level Security

**2.** Yêu cầu: "kể cả quản trị viên cơ sở dữ liệu cũng không được xem số CMND của khách hàng". Chọn:
- A. TDE B. DDM C. Always Encrypted D. Cell-level encryption

**3.** Thứ tự đúng của chuỗi khoá TDE, từ gốc xuống?
- A. DMK → SMK → Certificate → DEK
- B. SMK → DMK → Certificate → DEK
- C. Certificate → SMK → DMK → DEK
- D. DEK → Certificate → DMK → SMK

**4.** Bước nào trong quy trình bật TDE, nếu bỏ qua, sẽ khiến bạn **mất dữ liệu vĩnh viễn** khi phải restore ở server khác?
- A. `CREATE MASTER KEY` B. `BACKUP CERTIFICATE` + private key
- C. `CREATE DATABASE ENCRYPTION KEY` D. `SET ENCRYPTION ON`

**5.** Sau khi bật TDE cho một database, điều gì xảy ra với `tempdb`?
- A. Không ảnh hưởng B. `tempdb` cũng bị mã hoá, ảnh hưởng toàn instance
- C. `tempdb` bị khoá D. Phải tạo lại `tempdb`

**6.** Cột dùng Always Encrypted `DETERMINISTIC` hỗ trợ thao tác nào?
- A. `LIKE '%abc%'` B. `WHERE col > 100` C. `WHERE col = @p` và `JOIN` D. `SUM(col)`

**7.** Cột chuỗi dùng Always Encrypted DETERMINISTIC bắt buộc phải có:
- A. Collation `_BIN2` B. `NOT NULL` C. Index D. Kiểu `NVARCHAR(MAX)`

**8.** Ứng dụng cần Always Encrypted nhưng vẫn phải chạy `WHERE Name LIKE 'Nguyen%'`. Giải pháp:
- A. Đổi sang DETERMINISTIC B. Always Encrypted with **secure enclaves**
- C. Bỏ mã hoá cột đó D. Dùng RANDOMIZED

**9.** Column Master Key (CMK) được lưu ở đâu?
- A. Trong bảng hệ thống của database B. Trong `master`
- C. **Ngoài database**: Windows Certificate Store / Azure Key Vault / HSM D. Trong file backup

**10.** Khách hàng dùng Azure SQL Database và yêu cầu tự quản lý khoá mã hoá. Chọn:
- A. Service-managed TDE B. **Customer-Managed Key (BYOK) + Azure Key Vault**
- C. Always Encrypted D. Backup encryption

---

## A2. DDM & RLS (câu 11–20)

**11.** Hàm mask nào giữ 3 ký tự đầu và 2 ký tự cuối của số điện thoại?
- A. `default()` B. `email()` C. `partial(3,"XXXX",2)` D. `random(3,2)`

**12.** Ai vẫn thấy dữ liệu thật dù cột đã bị mask?
- A. Chỉ sysadmin B. Người có quyền `UNMASK`, `db_owner`, sysadmin
- C. Không ai D. Chỉ chủ sở hữu bảng

**13.** Vì sao DDM **không** được coi là biện pháp bảo mật thật sự?
- A. Vì nó làm chậm truy vấn
- B. Vì vị từ `WHERE` vẫn chạy trên giá trị **thật** nên có thể dò được dữ liệu
- C. Vì nó không hỗ trợ kiểu số
- D. Vì nó chỉ có trên Enterprise

**14.** Hàm vị từ của RLS bắt buộc phải là:
- A. Scalar UDF B. Multi-statement TVF
- C. **Inline TVF + `WITH SCHEMABINDING`** D. Stored procedure

**15.** Security policy chỉ có `FILTER PREDICATE`. Người dùng tenant 1 chạy `INSERT` với `TenantId = 2`. Kết quả?
- A. Bị chặn với lỗi B. **Chèn thành công**, rồi dòng đó biến mất khỏi mắt họ
- C. Chèn nhưng đổi thành TenantId = 1 D. Báo cảnh báo

**16.** Để chặn người dùng chèn dòng thuộc tenant khác, cần thêm:
- A. `FILTER PREDICATE` B. `BLOCK PREDICATE AFTER INSERT` C. `CHECK` constraint D. Trigger

**17.** `FILTER PREDICATE` ẩn dòng khỏi `SELECT`. Nó có ảnh hưởng `UPDATE`/`DELETE` không?
- A. Không B. **Có** — không sửa/xoá được dòng không nhìn thấy
- C. Chỉ ảnh hưởng `DELETE` D. Chỉ khi thêm BLOCK predicate

**18.** Cách truyền danh tính nào **KHÔNG an toàn** để dùng trong vị từ RLS?
- A. `SESSION_CONTEXT()` B. `USER_NAME()` C. `SUSER_SNAME()` D. `APP_NAME()`

**19.** Vì sao `sp_set_session_context` nên dùng `@read_only = 1`?
- A. Tăng hiệu năng B. **Ngăn kẻ khai thác SQL injection tự đổi danh tính trong phiên**
- C. Bắt buộc về cú pháp D. Để dùng được với connection pool

**20.** Yếu tố nào quan trọng nhất về **hiệu năng** khi triển khai RLS?
- A. Số lượng tenant B. **Index trên cột được lọc** C. Kích thước bảng D. Loại isolation

---

## A3. Quyền & kiểm toán (câu 21–32)

**21.** User thuộc role được `GRANT SELECT`, nhưng cá nhân bị `DENY SELECT`. Kết quả?
- A. Đọc được B. **Không đọc được** C. Tuỳ thứ tự cấp D. Báo lỗi cấu hình

**22.** Đã `DENY SELECT` cho user. Muốn user đọc được lại, phải:
- A. `GRANT SELECT` thêm B. **`REVOKE`** cái DENY C. Xoá user D. Thêm vào db_owner

**23.** Muốn cho người dùng chạy stored procedure đọc dữ liệu bảng lương mà **không** cấp quyền trên bảng. Cơ chế:
- A. RLS B. **Ownership chaining** C. DDM D. `db_datareader`

**24.** Stored procedure dùng SQL động (`EXEC(@sql)`) làm **đứt** chuỗi sở hữu. Giải pháp **tốt nhất** (giữ được danh tính người gọi cho audit)?
- A. Cấp `SELECT` trực tiếp lên bảng B. `EXECUTE AS OWNER`
- C. **Module signing** (ký module bằng certificate) D. Thêm user vào `db_owner`

**25.** Bên trong procedure có `WITH EXECUTE AS OWNER`, hàm nào trả về danh tính **thật** của người gọi?
- A. `USER_NAME()` B. `SUSER_SNAME()` C. **`ORIGINAL_LOGIN()`** D. `CURRENT_USER`

**26.** SQL Server Audit gồm mấy phần và thứ tự tạo?
- A. Server Audit → Audit Specification B. Audit Specification → Server Audit
- C. Chỉ cần Audit Specification D. Server Audit → Trigger

**27.** Yêu cầu tuân thủ: "tuyệt đối không được phép có thao tác nào không được ghi vết". Cấu hình:
- A. `ON_FAILURE = CONTINUE` B. `ON_FAILURE = FAIL_OPERATION`
- C. **`ON_FAILURE = SHUTDOWN`** D. `QUEUE_DELAY = 0`

**28.** Trong `CREATE DATABASE AUDIT SPECIFICATION`, vì sao nên viết `BY public`?
- A. Bắt buộc cú pháp B. **Để bao trùm mọi principal**, không bỏ sót ai
- C. Để giảm dung lượng log D. Để audit nhanh hơn

**29.** Hàm nào đọc file audit?
- A. `sys.fn_trace_gettable` B. **`sys.fn_get_audit_file`** C. `sys.dm_exec_requests` D. `fn_dblog`

**30.** Cần đồng bộ thay đổi sang data warehouse, **biết cả giá trị cũ và mới**. Chọn:
- A. Change Tracking B. **CDC** C. Temporal table D. SQL Audit

**31.** Chỉ cần biết **dòng nào** đã đổi để đồng bộ, chi phí thấp nhất, không cần SQL Agent. Chọn:
- A. **Change Tracking** B. CDC C. Trigger D. Ledger

**32.** Bảng `cdc.*_CT` rỗng dù dữ liệu đã thay đổi. Nguyên nhân khả dĩ nhất?
- A. CDC chưa bật cho bảng B. **SQL Server Agent không chạy** (capture job không hoạt động)
- C. Bảng thiếu PK D. Thiếu quyền

---

## A4. Hiệu năng (câu 33–48)

**33.** Query Store lưu dữ liệu ở đâu?
- A. Trong `msdb` B. **Trong chính database** C. Trong plan cache (RAM) D. Trong `tempdb`

**34.** Ưu điểm chính của Query Store so với plan cache?
- A. Nhanh hơn B. **Sống sót qua restart và đi theo backup/restore**
- C. Tốn ít bộ nhớ hơn D. Tự tối ưu truy vấn

**35.** Query Store đột nhiên ngừng thu thập dữ liệu mới. Kiểm tra đầu tiên?
- A. Compatibility level B. **`actual_state_desc` = READ_ONLY do đầy dung lượng**
- C. SQL Agent D. Recovery model

**36.** Sau khi nâng cấp SQL Server, một truy vấn quan trọng chậm hẳn. Cách khôi phục nhanh nhất **không sửa mã nguồn**?
- A. Rebuild index B. `UPDATE STATISTICS`
- C. **Query Store → `sp_query_store_force_plan`** D. Hạ compatibility level toàn DB

**37.** Ứng dụng bên thứ ba không sửa được mã nguồn, nhưng cần thêm `OPTION(RECOMPILE)`. Trên SQL Server 2022:
- A. Plan guide B. **`sp_query_store_set_hints`** C. Trigger D. Không làm được

**38.** Triệu chứng: "cùng một proc, lúc 50ms lúc 30 giây, restart server thì tự hết một thời gian". Nguyên nhân?
- A. Thiếu index B. **Parameter sniffing** C. Deadlock D. Thiếu bộ nhớ

**39.** Trên SQL Server 2022, cách xử lý parameter sniffing **không cần sửa mã nguồn**?
- A. `OPTION(RECOMPILE)` B. `OPTIMIZE FOR UNKNOWN`
- C. **Nâng compatibility level 160 → PSP optimization** D. Tách procedure

**40.** `OPTION (OPTIMIZE FOR UNKNOWN)` làm gì?
- A. Biên dịch lại mỗi lần B. **Dùng ước lượng trung bình từ histogram, bỏ qua giá trị tham số**
- C. Ép plan cụ thể D. Tắt plan cache

**41.** Ngưỡng tự động cập nhật statistics hiện đại (compat ≥ 130) là:
- A. 20% + 500 dòng B. **`SQRT(1000 × số dòng)`** C. 10% D. Cố định 1000 dòng

**42.** "Ascending key problem" gây ra vấn đề gì?
- A. Phân mảnh index B. **Dữ liệu mới nằm ngoài histogram → ước lượng 1 dòng → plan tệ**
- C. Deadlock D. Tràn tempdb

**43.** `REBUILD` index có cập nhật statistics không? Còn `REORGANIZE`?
- A. Cả hai đều có B. **REBUILD có (FULLSCAN), REORGANIZE không** C. Cả hai đều không D. Ngược lại

**44.** Wait type `ASYNC_NETWORK_IO` cao nghĩa là gì?
- A. Mạng chậm B. Đĩa chậm C. **Ứng dụng client xử lý kết quả chậm** D. Thiếu CPU

**45.** Phân biệt `PAGEIOLATCH_*` và `PAGELATCH_*`?
- A. Giống nhau B. **PAGEIOLATCH = chờ đọc từ đĩa; PAGELATCH = tranh chấp trang trong RAM**
- C. Ngược lại D. PAGELATCH chỉ có ở tempdb

**46.** "Báo cáo chạy lâu đang chặn nghiệp vụ ghi, không được đọc dữ liệu bẩn, không sửa ứng dụng". Chọn:
- A. `WITH (NOLOCK)` B. `READ UNCOMMITTED`
- C. **Bật `READ_COMMITTED_SNAPSHOT`** D. `SERIALIZABLE`

**47.** Khác biệt giữa `READ_COMMITTED_SNAPSHOT ON` và `ALLOW_SNAPSHOT_ISOLATION ON`?
- A. Giống nhau
- B. **RCSI đổi hành vi mặc định (không sửa app); ALLOW_SNAPSHOT chỉ mở khả năng dùng `SET TRANSACTION ISOLATION LEVEL SNAPSHOT`**
- C. RCSI chỉ cho Azure D. ALLOW_SNAPSHOT nhanh hơn

**48.** Khuyến nghị số data file cho `tempdb`?
- A. Luôn 1 B. **Bằng số logical CPU, tối đa 8, kích thước và autogrowth bằng nhau**
- C. Bằng số database D. Bằng số ổ đĩa

---

## A5. Triển khai, CI/CD & kiểm thử (câu 49–60)

**49.** `.dacpac` chứa gì?
- A. Schema + dữ liệu B. **Chỉ schema** C. Chỉ dữ liệu D. Backup nén

**50.** Cần đưa database on-prem (schema + toàn bộ dữ liệu) lên Azure SQL Database. Dùng:
- A. `.dacpac` B. **`.bacpac`** C. `.bak` D. Log shipping

**51.** Action nào của SqlPackage tạo `.dacpac` từ database đang chạy?
- A. Export B. **Extract** C. Publish D. Import

**52.** Trước khi deploy lên production, bắt buộc phải:
- A. `/Action:Publish` ngay B. **`/Action:Script` (+ `DeployReport`) để người duyệt review**
- C. `/Action:Import` D. Backup rồi publish

**53.** Deploy thất bại với "possible data loss". Nguyên nhân điển hình?
- A. Thiếu quyền B. **Thu hẹp cột / đổi kiểu dữ liệu / xoá cột**
- C. Mạng chậm D. Sai phiên bản dacpac

**54.** Tham số nào **nguy hiểm** vì xoá mọi đối tượng không có trong dacpac?
- A. `BlockOnPossibleDataLoss` B. **`DropObjectsNotInSource=True`** C. `GenerateSmartDefaults` D. `VerifyDeployment`

**55.** Nhược điểm chính của state-based (DACPAC) so với migration-based?
- A. Chậm hơn B. **Đổi tên cột bị hiểu là DROP + ADD ⇒ mất dữ liệu**
- C. Không dùng được với Git D. Không hỗ trợ Azure

**56.** Chiến lược deploy schema không downtime cho thay đổi phá vỡ tương thích:
- A. Deploy thẳng lúc thấp điểm B. **Expand → migrate → contract** C. Blue-green D. Dừng ứng dụng

**57.** `tSQLt.FakeTable` dùng để làm gì?
- A. Tạo bảng tạm
- B. **Thay bảng thật bằng bảng rỗng cùng cấu trúc, bỏ constraint ⇒ cô lập test**
- C. Sinh dữ liệu ngẫu nhiên D. So sánh 2 bảng

**58.** Vì sao mỗi test tSQLt tự chạy trong transaction và rollback?
- A. Để nhanh hơn B. **Để test độc lập, không để lại dữ liệu rác** C. Bắt buộc cú pháp D. Để đo hiệu năng

**59.** Chuỗi restore point-in-time đúng:
- A. Tất cả `WITH RECOVERY`
- B. **Full `NORECOVERY` → Diff `NORECOVERY` → Log `NORECOVERY` → Log cuối `WITH STOPAT, RECOVERY`**
- C. Full `RECOVERY` → Log `NORECOVERY` D. Chỉ cần Log

**60.** Ứng dụng dùng SQL Agent job và cross-database query, cần chuyển lên Azure. Chọn:
- A. Azure SQL Database B. **Azure SQL Managed Instance** C. Elastic pool D. Serverless

---
---

# PHẦN B — ĐÁP ÁN & GIẢI THÍCH

| # | Đ.A | Giải thích ngắn |
|---|---|---|
| 1 | **B** | TDE bảo vệ at rest, trong suốt với ứng dụng. Always Encrypted phải sửa connection string + driver ⇒ vi phạm "không sửa ứng dụng". |
| 2 | **C** | Chỉ Always Encrypted giữ khoá (CMK) NGOÀI database ⇒ DBA không có khoá. TDE/DDM/cell encryption đều bị DBA vượt qua. |
| 3 | **B** | SMK (DPAPI bảo vệ) → DMK (password) → Certificate → DEK (AES_256) → dữ liệu. |
| 4 | **B** | Không có certificate + private key thì backup mã hoá là khối dữ liệu vô dụng ở server khác. |
| 5 | **B** | Bất kỳ DB nào bật TDE ⇒ `tempdb` bị mã hoá, ảnh hưởng CPU của mọi DB trên instance. |
| 6 | **C** | DETERMINISTIC hỗ trợ `=`, JOIN, GROUP BY, DISTINCT, index. LIKE/dải/aggregate đều không. |
| 7 | **A** | Collation `_BIN2` là bắt buộc để so sánh nhị phân chính xác. |
| 8 | **B** | Secure enclaves là tính năng duy nhất mở khoá `LIKE` và so sánh dải cho Always Encrypted. |
| 9 | **C** | CMK ở kho khoá ngoài; CEK (đã bị CMK mã hoá) mới nằm trong DB. Đây là nền tảng của mô hình tin cậy. |
| 10 | **B** | CMK/BYOK trong Azure Key Vault. |
| 11 | **C** | `partial(prefix, padding, suffix)`. |
| 12 | **B** | Quyền `UNMASK` (2022 cấp được tới từng cột), cộng `db_owner`/sysadmin. |
| 13 | **B** | Mask chỉ áp ở tầng hiển thị; `WHERE` vẫn lọc trên giá trị thật ⇒ dò nhị phân được. |
| 14 | **C** | Bắt buộc inline TVF + SCHEMABINDING. |
| 15 | **B** | FILTER chỉ ẩn dòng; không chặn ghi ⇒ dữ liệu bị nhiễm bẩn âm thầm. |
| 16 | **B** | `BLOCK PREDICATE ... AFTER INSERT` ⇒ Msg 33504. |
| 17 | **B** | FILTER áp cho cả đọc lẫn ghi ngầm: dòng không thấy thì không sửa/xoá được. |
| 18 | **D** | `APP_NAME()` do client tự khai trong connection string ⇒ giả mạo dễ dàng. |
| 19 | **B** | `@read_only = 1` khoá giá trị trong phiên, chống leo thang qua injection. |
| 20 | **B** | Vị từ được nối vào mọi truy vấn ⇒ không có index trên cột lọc thì mọi truy vấn đều scan. |
| 21 | **B** | DENY luôn thắng GRANT (trừ sysadmin). |
| 22 | **B** | REVOKE xoá dòng cấp quyền (kể cả DENY). GRANT thêm không có tác dụng. |
| 23 | **B** | Ownership chaining: proc và bảng cùng owner ⇒ không kiểm tra quyền trên bảng. |
| 24 | **C** | Module signing giữ nguyên danh tính người gọi (audit chính xác) và cấp quyền đúng phạm vi. `EXECUTE AS OWNER` làm mất danh tính. |
| 25 | **C** | `ORIGINAL_LOGIN()` xuyên qua mọi lớp impersonation. |
| 26 | **A** | Server Audit (ghi ra đâu) → Audit Specification (ghi cái gì). Gỡ thì ngược lại. |
| 27 | **C** | `SHUTDOWN` tắt instance nếu không ghi được audit. |
| 28 | **B** | `BY <user>` chỉ audit user đó; người khác đọc bảng sẽ không bị ghi vết. |
| 29 | **B** | `sys.fn_get_audit_file('path\*.sqlaudit', DEFAULT, DEFAULT)`. |
| 30 | **B** | Chỉ CDC lưu cả giá trị trước (`__$operation` 3) và sau (4). |
| 31 | **A** | Change Tracking: đồng bộ, nhẹ, chỉ lưu khoá + phiên bản, không cần Agent, có trên mọi edition. |
| 32 | **B** | CDC đọc transaction log qua job của SQL Agent; Agent dừng ⇒ bảng CT rỗng. |
| 33 | **B** | Nằm trong chính database ⇒ đi theo backup/restore. |
| 34 | **B** | Plan cache mất khi restart; Query Store thì không. |
| 35 | **B** | Đầy `MAX_STORAGE_SIZE_MB` ⇒ tự chuyển READ_ONLY (xem `readonly_reason`). |
| 36 | **C** | Đây là kịch bản kinh điển của plan forcing. |
| 37 | **B** | Query Store hints (2022+) áp hint mà không đụng mã nguồn. Plan guide là giải pháp cũ, kém hơn. |
| 38 | **B** | Plan cache theo giá trị biên dịch lần đầu; restart xoá cache nên "tự hết". |
| 39 | **C** | PSP optimization tự giữ nhiều plan cho các dải giá trị khác nhau. |
| 40 | **B** | Dùng vector mật độ trung bình, bỏ qua giá trị thực của tham số. |
| 41 | **B** | Ngưỡng động, bảng càng lớn càng cập nhật sớm hơn so với quy tắc 20% cũ. |
| 42 | **B** | Giá trị mới nhất chưa có trong histogram ⇒ ước lượng cực thấp. |
| 43 | **B** | Rebuild tạo lại index nên statistics được cập nhật FULLSCAN. |
| 44 | **C** | SQL đã gửi kết quả xong nhưng client đọc chậm — lỗi ở tầng ứng dụng. |
| 45 | **B** | Có chữ "IO" = phải đi xuống đĩa. Không có "IO" = trang đã ở RAM, chỉ tranh chấp latch. |
| 46 | **C** | RCSI cho người đọc dùng phiên bản dòng ⇒ không chặn người ghi, không đọc bẩn, không sửa app. |
| 47 | **B** | RCSI đổi hành vi của READ COMMITTED; ALLOW_SNAPSHOT chỉ bật khả năng dùng mức SNAPSHOT. |
| 48 | **B** | Và phải bằng nhau, nếu không proportional fill lại dồn vào 1 file. |
| 49 | **B** | Chữ B trong BACPAC = có data. DACPAC chỉ schema. |
| 50 | **B** | BACPAC = schema + data, đúng công cụ để import vào Azure SQL. |
| 51 | **B** | Extract → dacpac; Export → bacpac. |
| 52 | **B** | Sinh script để review là bước bắt buộc trong quy trình có kiểm soát. |
| 53 | **B** | `BlockOnPossibleDataLoss=True` (mặc định) chặn các thao tác này. |
| 54 | **B** | Xoá mọi đối tượng không có trong nguồn — dễ xoá nhầm đối tượng do môi trường đích tạo. |
| 55 | **B** | Công cụ so sánh không biết ý định "đổi tên"; xử lý bằng refactorlog hoặc chuyển sang migration-based. |
| 56 | **B** | Ba pha cho phép nhiều phiên bản ứng dụng chạy song song trong lúc chuyển đổi. |
| 57 | **B** | Cô lập test khỏi dữ liệu và ràng buộc thật ⇒ test không phụ thuộc trạng thái DB. |
| 58 | **B** | Test độc lập, thứ tự chạy không quan trọng, không cần dọn dẹp thủ công. |
| 59 | **B** | NORECOVERY ở mọi bước trung gian, RECOVERY chỉ ở bước cuối, STOPAT cho point-in-time. |
| 60 | **B** | Azure SQL Database không có SQL Agent và cross-database query; MI có cả hai. |

---

## THANG ĐIỂM

| Điểm | Nhận định |
|---|---|
| 54–60 | Sẵn sàng thi miền 2. |
| 48–53 | Đạt. Đọc lại đúng mục sai, chạy lại lab tương ứng. |
| 40–47 | Chưa an toàn. Ôn lại guide + chạy lại Lab 01, 02, 04. |
| < 40 | Học lại theo lộ trình 7 ngày ở mục 10 của guide. |

## BẢN ĐỒ CÂU HỎI → TÀI LIỆU ÔN

| Câu | Mục trong Guide | Lab |
|---|---|---|
| 1–10 | 2. Mã hoá | [Lab 01](./Claude_DP800_D2_Lab01_Encryption.sql) |
| 11–20 | 3. DDM, 4. RLS | [Lab 02](./Claude_DP800_D2_Lab02_DDM_RLS_Permissions.sql) §1–7 |
| 21–25 | 5. Quyền | [Lab 02](./Claude_DP800_D2_Lab02_DDM_RLS_Permissions.sql) §8–11 |
| 26–32 | 6. Kiểm toán | [Lab 03](./Claude_DP800_D2_Lab03_Auditing.sql) |
| 33–48 | 7. Tối ưu hiệu năng | [Lab 04](./Claude_DP800_D2_Lab04_Performance.sql) |
| 49–60 | 8. Triển khai & kiểm thử | [Lab 05](./Claude_DP800_D2_Lab05_Deployment_CICD.sql) |
