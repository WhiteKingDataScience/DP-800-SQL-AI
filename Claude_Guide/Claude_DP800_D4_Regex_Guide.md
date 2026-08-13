# DP-800 — BỔ SUNG: HÀM REGEX TRONG SQL SERVER 2025 & MICROSOFT FABRIC

> **Tài liệu bổ sung** — dành cho thí sinh yếu mảng Regular Expression.
> **Nền tảng:** SQL Server 2025 (compatibility level 170) / SQL database in Microsoft Fabric.
> **Tại sao cần?** Đề thi DP-800 có ≥5 câu hỏi liên quan đến regex — từ trích xuất,
> thay thế, đếm đến kết hợp với JSON_VALUE. Nếu không nắm chắc 5 hàm regex cốt lõi,
> bạn sẽ rất khó xử lý chính xác các bài toán liên quan đến xử lý và làm sạch chuỗi.

---

## 1. TỔNG QUAN VỀ REGEX TRONG SQL SERVER

### 1.1. Trước SQL Server 2025 — Thời kỳ "ám ảnh"

Trước SQL Server 2025, bạn **không có** hàm regex gốc (native). Bạn chỉ có:

| Công cụ cũ | Hạn chế |
|---|---|
| `LIKE` | Chỉ hỗ trợ wildcard đơn giản: `%`, `_`, `[a-z]` |
| `PATINDEX` | Tìm vị trí pattern đơn giản, không hỗ trợ quantifier (`+`, `*`, `?`) |
| `CHARINDEX` | Tìm chuỗi cố định, không phải pattern |
| CLR function | Cần viết C#, triển khai phức tạp, không dùng được trên Azure SQL |

### 1.2. SQL Server 2025 — Cách mạng regex

SQL Server 2025 giới thiệu **6 hàm regex gốc** (native) dựa trên engine **RE2** (linear-time,
tránh catastrophic backtracking — tức là không bao giờ bị "treo" do pattern phức tạp).

> ⚠️ **Điều kiện tiên quyết:**
> Database phải ở **compatibility level 170** trở lên.
> ```sql
> -- Kiểm tra
> SELECT compatibility_level FROM sys.databases WHERE name = DB_NAME();
> -- Nâng cấp nếu cần
> ALTER DATABASE [TenDB] SET COMPATIBILITY_LEVEL = 170;
> ```

> ⚠️ **Giới hạn kiểu dữ liệu:**
> Các hàm regex **KHÔNG** hỗ trợ trực tiếp `nvarchar(max)` hay `varchar(max)`.
> Bạn phải **CAST** sang `nvarchar(4000)` hoặc `varchar(8000)` trước khi gọi hàm regex.
> (Từ CU5 trở đi mới hỗ trợ LOB lên đến 2MB — nhưng trong thi, mặc định coi là phải cast).

---

## 2. BẢNG TỔNG HỢP 6 HÀM REGEX

| Hàm | Mục đích | Trả về | Dùng ở đâu |
|---|---|---|---|
| `REGEXP_LIKE` | Kiểm tra chuỗi **có khớp** pattern không | `TRUE/FALSE` | `WHERE`, `CASE WHEN` |
| `REGEXP_REPLACE` | **Thay thế** phần khớp bằng chuỗi khác | `nvarchar` / `varchar` | `SELECT`, `UPDATE SET` |
| `REGEXP_SUBSTR` | **Trích xuất** chuỗi con đầu tiên khớp pattern | `nvarchar` / `varchar` hoặc `NULL` | `SELECT` |
| `REGEXP_INSTR` | Trả về **vị trí** (index) của match đầu tiên | `int` | `SELECT`, `WHERE` |
| `REGEXP_COUNT` | **Đếm** số lần pattern xuất hiện | `int` | `SELECT`, `WHERE`, `HAVING` |
| `REGEXP_MATCHES` | Trả về **bảng** gồm tất cả các nhóm captured | Table (các cột match) | `CROSS APPLY` |

### 🎯 Bảng quyết định nhanh: "Đề hỏi gì → chọn hàm nào"

| Đề bài hỏi | Hàm đúng | Hàm sai thường gặp |
|---|---|---|
| "Tìm các dòng có email hợp lệ" | `REGEXP_LIKE` | `REGEXP_SUBSTR` (trích xuất, không filter) |
| "Xoá ký tự đặc biệt khỏi chuỗi" | `REGEXP_REPLACE` | `REGEXP_SUBSTR` (không thay thế) |
| "Trích xuất số điện thoại từ text" | `REGEXP_SUBSTR` | `REGEXP_INSTR` (chỉ trả vị trí, không trích xuất) |
| "Đếm bao nhiêu lần pattern xuất hiện" | `REGEXP_COUNT` | `REGEXP_LIKE` (chỉ TRUE/FALSE) |
| "Tìm vị trí bắt đầu của match" | `REGEXP_INSTR` | `REGEXP_COUNT` (đếm, không trả vị trí) |
| "Tách chuỗi thành nhiều dòng" | `REGEXP_SPLIT_TO_TABLE` | `REGEXP_MATCHES` |

---

## 3. CHI TIẾT TỪNG HÀM VỚI VÍ DỤ THỰC TẾ

### 3.1. REGEXP_LIKE — Kiểm tra pattern (trả về TRUE/FALSE)

**Cú pháp:**
```sql
REGEXP_LIKE(input_string, pattern [, flags])
```

**Ví dụ thực tế — Lọc email hợp lệ:**
```sql
SELECT EmailAddress
FROM dbo.Contacts
WHERE REGEXP_LIKE(EmailAddress, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
```

**Ví dụ đề thi — Kiểm tra phone có tồn tại:**
```sql
-- Trong CASE WHEN để tạo cột PhoneStatus
CASE
    WHEN REGEXP_COUNT(MessageRaw, '\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}') >= 1
    THEN 'valid'
    ELSE 'Missing'
END AS PhoneStatus
```

> 💡 **Bẫy đề thi:** `REGEXP_LIKE` trả về boolean → dùng trong `WHERE` hoặc `CASE`.
> **KHÔNG THỂ** dùng `REGEXP_LIKE` để trích xuất text hay đếm số lần match.

---

### 3.2. REGEXP_REPLACE — Thay thế theo pattern

**Cú pháp:**
```sql
REGEXP_REPLACE(input_string, pattern, replacement [, flags])
```

**Ví dụ kinh điển đề thi — Loại bỏ subaddressing trong email:**

Đề bài: Email `user1+newsletter@contoso.com` → cần chuẩn hoá thành `user1@contoso.com`

```sql
-- ĐÁP ÁN ĐÚNG:
REGEXP_REPLACE(
    JSON_VALUE(Payload, '$.customer_email'),
    '\+.*@',    -- Tìm: dấu + ... mọi ký tự ... cho đến @
    '@'          -- Thay bằng: chỉ giữ @
)
-- user1+newsletter@contoso.com → user1@contoso.com ✅
```

**Tại sao các đáp án khác sai:**

| Pattern sai | Kết quả | Lý do sai |
|---|---|---|
| `'\+.*$'` thay bằng `''` | `user1` (mất `@contoso.com`) | `.*$` ăn hết đến cuối chuỗi, bao gồm cả `@domain` |
| `'\+.*'` thay bằng `''` | `user1` (mất `@contoso.com`) | Tương tự — `.*` greedy, ăn hết |
| Dùng `REGEXP_SUBSTR` | Cần concat thêm | Phức tạp hơn, không hiệu quả |

> 🎯 **Mẹo nhớ cho REGEXP_REPLACE với email:**
> Pattern `\+.*@` thay bằng `@` = "cắt bỏ phần giữa `+` và `@`, rồi nối lại".

**Ví dụ nữa — Xoá tất cả ký tự không phải số:**
```sql
-- Biến '+84 123-456-7890' thành '841234567890'
SELECT REGEXP_REPLACE(PhoneNumber, '\D', '') AS DigitsOnly;
-- \D = ký tự KHÔNG phải digit (non-digit)
```

---

### 3.3. REGEXP_SUBSTR — Trích xuất chuỗi con khớp pattern

**Cú pháp:**
```sql
REGEXP_SUBSTR(input_string, pattern [, start_position [, occurrence [, flags]]])
```

**Ví dụ đề thi — Trích xuất số điện thoại đầu tiên:**
```sql
SELECT
    MessageID,
    REGEXP_SUBSTR(
        CAST(MessageRaw AS nvarchar(4000)),  -- BẮT BUỘC cast từ nvarchar(max)!
        '\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}'
    ) AS RawNumber
FROM dbo.CustomerMessages;
```

> ⚠️ **Bẫy đề thi cực phổ biến:**
> Cột `nvarchar(max)` + hàm regex → **PHẢI cast sang `nvarchar(4000)` trước**.
> Đây là câu hỏi "Bạn cần làm gì TRƯỚC khi gọi REGEXP_SUBSTR?" — đáp án là **Cast**.

**Tham số `occurrence` (lần xuất hiện thứ mấy):**
```sql
-- Lấy email thứ 2 trong chuỗi
REGEXP_SUBSTR(text, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+', 1, 2)
--                                                        ^  ^
--                                                 start=1  lần=2
```

---

### 3.4. REGEXP_INSTR — Vị trí bắt đầu của match

**Cú pháp:**
```sql
REGEXP_INSTR(input_string, pattern [, start_position [, occurrence [, return_option [, flags]]]])
```

`return_option`:
- `0` (mặc định) = trả vị trí **bắt đầu** của match
- `1` = trả vị trí **kết thúc** + 1 (tức vị trí ký tự ngay sau match)

**Ví dụ:**
```sql
SELECT REGEXP_INSTR('Product ID: 98765', '\d+');
-- Kết quả: 13 (vị trí ký tự '9' — ký tự đầu tiên của match '98765')
```

> 💡 **Khi nào dùng REGEXP_INSTR?** Khi đề hỏi "vị trí" hoặc "index", KHÔNG phải "giá trị".
> Hầu hết đề thi DP-800 hỏi trích xuất giá trị → dùng `REGEXP_SUBSTR`, **không phải** `REGEXP_INSTR`.

---

### 3.5. REGEXP_COUNT — Đếm số lần match

**Cú pháp:**
```sql
REGEXP_COUNT(input_string, pattern [, start_position [, flags]])
```

**Ví dụ đề thi — Kiểm tra pattern tồn tại:**
```sql
CASE
    WHEN REGEXP_COUNT(
        CAST(MessageRaw AS nvarchar(4000)),
        '\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}'
    ) >= 1
    THEN 'valid'
    ELSE 'Missing'
END AS PhoneStatus
```

> 🎯 **REGEXP_COUNT vs REGEXP_LIKE:**
> - `REGEXP_LIKE` → chỉ TRUE/FALSE (có match hay không)
> - `REGEXP_COUNT` → số lần match (0, 1, 2, 3...)
> - Đề thi hỏi "bao nhiêu lần" → `REGEXP_COUNT`
> - Đề thi hỏi "có hay không" → `REGEXP_LIKE`

---

### 3.6. REGEXP_MATCHES — Trả về bảng (table-valued)

```sql
-- Trích xuất TẤT CẢ email từ một chuỗi text dài
SELECT m.value
FROM dbo.Messages
CROSS APPLY REGEXP_MATCHES(MessageBody, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+') m;
```

---

## 4. CÁC FLAG (CỜ) REGEX

| Flag | Ý nghĩa | Ví dụ |
|---|---|---|
| `'i'` | **Case-insensitive** (không phân biệt hoa/thường) | `REGEXP_LIKE(col, 'abc', 'i')` khớp `ABC`, `Abc` |
| `'c'` | **Case-sensitive** (phân biệt hoa/thường) | Mặc định trong collation CS |
| `'m'` | **Multi-line** (`^` và `$` khớp đầu/cuối mỗi dòng) | Hữu ích khi text chứa `\n` |
| `'s'` | **Dot-all** (`.` khớp cả newline `\n`) | Mặc định `.` KHÔNG khớp `\n` |

---

## 5. CÁC PATTERN REGEX PHỔ BIẾN TRONG ĐỀ THI

### 5.1. Bảng tra cứu ký hiệu regex

| Ký hiệu | Ý nghĩa | Ví dụ |
|---|---|---|
| `.` | Bất kỳ ký tự nào (trừ `\n`) | `a.c` khớp `abc`, `a1c` |
| `\d` | Chữ số (digit) = `[0-9]` | `\d{3}` khớp `123` |
| `\D` | KHÔNG phải chữ số | `\D+` khớp `abc`, `---` |
| `\w` | Ký tự "word" = `[a-zA-Z0-9_]` | `\w+` khớp `hello_world` |
| `\s` | Khoảng trắng (space, tab, newline) | `\s+` khớp `   ` |
| `+` | Lặp **1 lần trở lên** | `\d+` khớp `1`, `123`, `99999` |
| `*` | Lặp **0 lần trở lên** | `\d*` khớp `""`, `1`, `123` |
| `?` | Lặp **0 hoặc 1 lần** | `\d?` khớp `""`, `1` |
| `{n}` | Lặp **đúng n lần** | `\d{4}` khớp `2026` |
| `{n,m}` | Lặp **từ n đến m lần** | `\d{2,4}` khớp `12`, `123`, `1234` |
| `^` | **Đầu** chuỗi (hoặc đầu dòng với flag `m`) | `^Hello` |
| `$` | **Cuối** chuỗi (hoặc cuối dòng với flag `m`) | `world$` |
| `\` | **Escape** ký tự đặc biệt | `\+` khớp ký tự `+` thật (không phải quantifier) |
| `[abc]` | Bất kỳ ký tự nào trong tập hợp | `[aeiou]` khớp nguyên âm |
| `[^abc]` | Bất kỳ ký tự nào KHÔNG trong tập hợp | `[^0-9]` = ký tự không phải số |
| `(...)` | Nhóm capturing (capture group) | `(\d{3})-(\d{4})` |
| `\|` | HOẶC (OR) | `cat\|dog` khớp `cat` hoặc `dog` |

### 5.2. Các pattern đề thi hay hỏi

| Mục đích | Pattern | Giải thích |
|---|---|---|
| Số điện thoại US | `\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}` | Tùy chọn dấu `(`, 3 số, tùy chọn `)`, separator, 3 số, separator, 4 số |
| Email | `[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}` | username@domain.tld |
| Xoá subaddressing email | `\+.*@` (thay bằng `@`) | Bỏ phần `+tag` trong email |
| Chỉ giữ số | `\D` (thay bằng `''`) | Xoá mọi ký tự không phải số |
| IP address | `\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}` | 4 nhóm số cách bởi dấu `.` |
| Mã ID dạng `ABC-12345` | `[A-Z]{3}-\d{5}` | 3 chữ cái viết hoa + dash + 5 số |

---

## 6. KẾT HỢP REGEX VỚI JSON — DẠNG ĐỀ THI CỰC PHỔ BIẾN

Đề thi DP-800 rất thích kết hợp `JSON_VALUE` + regex:

```sql
-- Pattern đề thi điển hình:
SELECT
    CustomerID,
    JSON_VALUE(ProfileJson, '$.phone') AS PhoneRaw,
    REGEXP_REPLACE(
        JSON_VALUE(ProfileJson, '$.phone'),
        '\D', ''                              -- Xoá mọi ký tự không phải số
    ) AS PhoneDigitsOnly
FROM dbo.Customers;
```

### So sánh TRANSLATE vs REGEXP_REPLACE

| | `TRANSLATE` | `REGEXP_REPLACE` |
|---|---|---|
| Hoạt động | Thay thế **từng ký tự** 1-1 | Thay thế **pattern** |
| Ví dụ | `TRANSLATE(phone, '+ -', '   ')` | `REGEXP_REPLACE(phone, '\D', '')` |
| Khi nào dùng | Biết chính xác ký tự cần xoá | Pattern phức tạp / không biết trước |
| Đề thi hỏi | "Phone format cố định `+000 000-000-0000`" | "Phone có thể ở nhiều format" |

> 🎯 **Mẹo thi:** Nếu đề cho format phone **cố định**, đáp án thường là `TRANSLATE`.
> Nếu phone có **nhiều format khác nhau**, đáp án thường là `REGEXP_REPLACE`.

---

## 7. HÀM ĐO ĐỘ TƯƠNG TỰ (FUZZY MATCHING)

Đề thi cũng hỏi về các hàm **fuzzy matching** kết hợp với regex:

### 7.1. EDIT_DISTANCE (Levenshtein Distance)

Đo số thao tác chỉnh sửa tối thiểu (thêm, xoá, thay ký tự) để biến chuỗi A thành chuỗi B.

```sql
SELECT EDIT_DISTANCE('kitten', 'sitting');  -- Kết quả: 3
-- k→s (thay), e→i (thay), thêm 'g' = 3 thao tác
```

### 7.2. EDIT_DISTANCE_SIMILARITY

Trả về điểm tương tự dưới dạng phần trăm (0–100).

```sql
SELECT EDIT_DISTANCE_SIMILARITY('database', 'databases');  -- ~88
```

### 7.3. Ví dụ đề thi kết hợp

```sql
-- Trích xuất feedback text từ JSON, tính fuzzy similarity, sắp xếp
SELECT
    JSON_VALUE(f.FeedbackJson, '$.text') AS FeedbackText,
    EDIT_DISTANCE_SIMILARITY(
        JSON_VALUE(f.FeedbackJson, '$.text'),
        @KnownIssueDescription
    ) AS SimilarityScore
FROM dbo.CustomerFeedback f
WHERE EDIT_DISTANCE(JSON_VALUE(f.FeedbackJson, '$.text'), @Keyword) < 3
ORDER BY SimilarityScore DESC;
```

**Giải thích từng phần:**
- `JSON_VALUE(...)` → trích xuất text từ JSON
- `EDIT_DISTANCE(...) < 3` → filter: chỉ lấy dòng có ≤2 thao tác chỉnh sửa
- `EDIT_DISTANCE_SIMILARITY(...)` → tính điểm tương tự để ORDER BY
- `ORDER BY ... DESC` → điểm cao nhất (giống nhất) lên trước

---

## 8. CÂU HỎI TỰ KIỂM TRA (20 CÂU)

### Câu 1
Bạn có cột `MessageRaw nvarchar(max)`. Bạn cần dùng `REGEXP_SUBSTR` để trích xuất ID.
Bạn phải làm gì **TRƯỚC** khi gọi `REGEXP_SUBSTR`?

A. `STRING_ESCAPE(MessageText, 'json')`
B. `CAST(MessageText AS nvarchar(4000))`
C. `COLLATE Latin1_General_CS_AS`
D. `TRY_CONVERT(varchar(max), MessageText)`

**Đáp án: B** — Hàm regex không hỗ trợ `nvarchar(max)` trực tiếp, phải cast xuống.

---

### Câu 2
Bạn cần chuẩn hoá email `user+tag@domain.com` → `user@domain.com`. Pattern nào đúng?

A. `REGEXP_REPLACE(email, '\+.*$', '')`
B. `REGEXP_REPLACE(email, '\+.*@', '@')`
C. `REGEXP_SUBSTR(email, '^[^+]+@.*$')`
D. `REGEXP_REPLACE(email, '\+.*', '')`

**Đáp án: B** — `\+.*@` khớp từ `+` đến `@`, thay bằng `@` → giữ domain.
A/D sẽ xoá cả `@domain.com`.

---

### Câu 3
Bạn cần kiểm tra xem chuỗi có chứa email hợp lệ không, trong mệnh đề `WHERE`. Hàm nào?

A. `REGEXP_SUBSTR`   B. `REGEXP_LIKE`   C. `REGEXP_COUNT`   D. `REGEXP_INSTR`

**Đáp án: B** — `REGEXP_LIKE` trả về TRUE/FALSE, dùng trong `WHERE`.

---

### Câu 4
Bạn cần **đếm** số lần một pattern điện thoại xuất hiện trong chuỗi. Hàm nào?

A. `REGEXP_LIKE`   B. `REGEXP_INSTR`   C. `REGEXP_COUNT`   D. `REGEXP_SUBSTR`

**Đáp án: C** — `REGEXP_COUNT` đếm số lần match.

---

### Câu 5
Bạn cần **trích xuất** chuỗi con đầu tiên khớp pattern. Hàm nào?

A. `REGEXP_INSTR`   B. `REGEXP_SUBSTR`   C. `REGEXP_LIKE`   D. `REGEXP_COUNT`

**Đáp án: B** — `REGEXP_SUBSTR` trích xuất chuỗi con.

---

### Câu 6
Pattern `\D` khớp với gì?

A. Bất kỳ chữ số nào   B. Bất kỳ ký tự nào không phải chữ số
C. Bất kỳ chữ cái nào   D. Ký tự xuống dòng

**Đáp án: B** — `\D` = NOT digit = `[^0-9]`.

---

### Câu 7
`REGEXP_REPLACE('ABC-123-XYZ', '\d', '#')` trả về gì?

A. `ABC-###-XYZ`   B. `###-123-###`   C. `ABC-123-XYZ`   D. `######-###-######`

**Đáp án: A** — `\d` khớp từng chữ số, thay mỗi chữ số bằng `#`.

---

### Câu 8
Bạn cần trích xuất tất cả email từ một cột text, mỗi email trên một dòng riêng. Dùng gì?

A. `REGEXP_SUBSTR`   B. `REGEXP_COUNT`
C. `CROSS APPLY REGEXP_MATCHES`   D. `REGEXP_LIKE`

**Đáp án: C** — `REGEXP_MATCHES` là table-valued function, trả về nhiều dòng.

---

### Câu 9
`REGEXP_INSTR('Mã đơn: ORD-98765', '\d+')` trả về gì?

A. `98765`   B. `10`   C. `5`   D. `ORD-98765`

**Đáp án: B** — `REGEXP_INSTR` trả về **vị trí** (index) của match, không phải giá trị.

---

### Câu 10
Bạn biến phone `'+84 123-456-7890'` thành `'841234567890'`. Cách nào đúng?

A. `REGEXP_REPLACE(phone, '\D', '')`
B. `REGEXP_SUBSTR(phone, '\d+')`
C. `TRANSLATE(phone, '+ -', '')`
D. A hoặc C đều đúng

**Đáp án: D** — Cả `REGEXP_REPLACE` xoá non-digit và `TRANSLATE` xoá ký tự cụ thể đều cho
kết quả đúng. Nhưng nếu đề hỏi "format cố định" → `TRANSLATE`; "nhiều format" → `REGEXP_REPLACE`.

---

### Câu 11
Bạn cần tạo cột `PhoneStatus`: nếu có phone thì `'valid'`, không có thì `'Missing'`.
Dùng hàm nào trong `CASE WHEN`?

A. `REGEXP_LIKE`   B. `REGEXP_COUNT`   C. `REGEXP_SUBSTR`   D. A hoặc B

**Đáp án: D** — Cả `REGEXP_LIKE(msg, pattern)` (TRUE/FALSE) lẫn
`REGEXP_COUNT(msg, pattern) >= 1` đều hoạt động. Tuỳ đề cho option nào.

---

### Câu 12
`EDIT_DISTANCE('cat', 'car')` trả về bao nhiêu?

A. 0   B. 1   C. 2   D. 3

**Đáp án: B** — Chỉ cần thay `t` → `r` = 1 thao tác.

---

### Câu 13
Khi nào dùng `EDIT_DISTANCE_SIMILARITY` thay vì `EDIT_DISTANCE`?

A. Khi cần filter (WHERE)   B. Khi cần ORDER BY theo độ giống nhau
C. Khi cần đếm ký tự   D. Khi cần JOIN hai bảng

**Đáp án: B** — `EDIT_DISTANCE_SIMILARITY` trả phần trăm (0–100), phù hợp để ORDER BY DESC.

---

### Câu 14
Database compatibility level cần tối thiểu bao nhiêu để dùng hàm regex?

A. 150   B. 160   C. 170   D. 140

**Đáp án: C** — Level 170 (SQL Server 2025).

---

### Câu 15
`REGEXP_REPLACE('hello   world', '\s+', ' ')` trả về gì?

A. `'hello   world'`   B. `'hello world'`   C. `'helloworld'`   D. `'hello_world'`

**Đáp án: B** — `\s+` khớp 1+ khoảng trắng, thay bằng 1 khoảng trắng.

---

### Câu 16
Bạn có chuỗi `'ABC123DEF456'`. `REGEXP_SUBSTR(str, '\d+', 1, 2)` trả về gì?

A. `'123'`   B. `'456'`   C. `'123456'`   D. `'DEF456'`

**Đáp án: B** — Tham số `occurrence = 2` → lấy match thứ 2 = `'456'`.

---

### Câu 17
`REGEXP_COUNT('data data data science', 'data')` trả về bao nhiêu?

A. 1   B. 2   C. 3   D. 4

**Đáp án: C** — Có 3 lần `'data'` xuất hiện.

---

### Câu 18
Bạn muốn tìm case-insensitive. Bạn thêm flag gì?

A. `'c'`   B. `'i'`   C. `'m'`   D. `'s'`

**Đáp án: B** — Flag `'i'` = case-insensitive.

---

### Câu 19
Pattern `^` trong regex nghĩa là gì?

A. Ký tự mũ   B. Đầu chuỗi/dòng   C. Phủ định (trong `[^...]`)   D. B hoặc C tuỳ ngữ cảnh

**Đáp án: D** — Ngoài `[]` → đầu chuỗi. Trong `[^...]` → phủ định.

---

### Câu 20
Bạn cần kết hợp `JSON_VALUE` và regex để xoá ký tự đặc biệt từ phone lưu trong JSON.
Thứ tự đúng là gì?

A. `REGEXP_REPLACE(JSON_VALUE(col, '$.phone'), '\D', '')`
B. `JSON_VALUE(REGEXP_REPLACE(col, '\D', ''), '$.phone')`
C. `REGEXP_REPLACE(col, '\D', '')`
D. `JSON_VALUE(col, '$.phone')`

**Đáp án: A** — Trước hết `JSON_VALUE` trích xuất giá trị phone,
rồi `REGEXP_REPLACE` xoá ký tự đặc biệt.
Option B sai vì bạn không thể dùng regex trên toàn bộ JSON document trước khi trích xuất.

---

## 9. TÓM TẮT — CHEAT SHEET CHO NGÀY THI

```
┌─────────────────────────────────────────────────────────┐
│  "Có/Không có pattern?"      → REGEXP_LIKE (boolean)    │
│  "Trích xuất match?"         → REGEXP_SUBSTR (string)   │
│  "Thay thế match?"           → REGEXP_REPLACE (string)  │
│  "Đếm bao nhiêu match?"     → REGEXP_COUNT (int)       │
│  "Vị trí match ở đâu?"      → REGEXP_INSTR (int)       │
│  "Tất cả match thành bảng?" → REGEXP_MATCHES (table)   │
│                                                         │
│  nvarchar(max) + regex → PHẢI CAST trước!               │
│  Email subaddress: \+.*@ → thay bằng @                  │
│  Chỉ giữ số: \D → thay bằng ''                        │
│  Compatibility level ≥ 170                              │
└─────────────────────────────────────────────────────────┘
```
