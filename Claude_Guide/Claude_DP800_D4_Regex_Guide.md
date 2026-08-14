# DP-800 — BỔ SUNG: REGEX & FUZZY STRING MATCHING (SQL SERVER 2025 / AZURE SQL / FABRIC)

> **Mục tiêu:** học đúng các hàm xử lý chuỗi mới có thể xuất hiện trong DP-800, hiểu khi nào dùng từng hàm và tránh các bẫy syntax/version.
>
> **Cập nhật:** 14/08/2026  
> **Blueprint:** DP-800 — Skills measured as of March 12, 2026.
>
> Nguồn chính:
> - [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
> - [Regular expressions in SQL Server 2025](https://learn.microsoft.com/en-us/sql/relational-databases/regular-expressions/overview?view=sql-server-ver17)
> - [REGEXP_MATCHES](https://learn.microsoft.com/en-us/sql/t-sql/functions/regexp-matches-transact-sql?view=sql-server-ver17)
> - [REGEXP_SPLIT_TO_TABLE](https://learn.microsoft.com/en-us/sql/t-sql/functions/regexp-split-to-table-transact-sql?view=sql-server-ver17)
> - [Fuzzy string matching overview](https://learn.microsoft.com/en-us/sql/relational-databases/fuzzy-string-match/overview?view=sql-server-ver17)

---

## 1. Mental model: đề hỏi gì → chọn hàm gì?

| Requirement | Hàm nên nghĩ tới |
|---|---|
| Có khớp pattern hay không? | `REGEXP_LIKE` |
| Thay đoạn khớp bằng chuỗi khác | `REGEXP_REPLACE` |
| Lấy substring khớp | `REGEXP_SUBSTR` |
| Lấy vị trí match | `REGEXP_INSTR` |
| Đếm số match | `REGEXP_COUNT` |
| Trả **mọi match thành nhiều dòng** | `REGEXP_MATCHES` |
| Split chuỗi thành nhiều dòng theo regex delimiter | `REGEXP_SPLIT_TO_TABLE` |
| Đếm số phép sửa giữa hai chuỗi | `EDIT_DISTANCE` |
| Điểm giống nhau 0–100 | `EDIT_DISTANCE_SIMILARITY` |
| So chuỗi ưu tiên prefix giống nhau | `JARO_WINKLER_DISTANCE` / `JARO_WINKLER_SIMILARITY` |

**Bẫy quan trọng:** `REGEXP_MATCHES` và `REGEXP_SPLIT_TO_TABLE` là **table-valued functions**, nên thường dùng trong `FROM` hoặc `CROSS APPLY`.

---

## 2. Compatibility và kiểu dữ liệu

Các hàm regex hiện hành yêu cầu compatibility level 170, trừ một số trường hợp TVF có cấu hình đặc biệt.

```sql
SELECT name, compatibility_level
FROM sys.databases
WHERE name = DB_NAME();
GO

ALTER DATABASE [YourDatabase]
SET COMPATIBILITY_LEVEL = 170;
GO
```

### Sửa kiến thức cũ về LOB

Tài liệu cũ thường ghi phải cast `nvarchar(max)`/`varchar(max)` sang 4000/8000. Điều này **không còn đúng tuyệt đối**.

Tài liệu Microsoft hiện hành cho biết `REGEXP_*` hỗ trợ LOB (`varchar(max)`, `nvarchar(max)`) cho `string_expression` **tới 2 MB**.

Vì vậy:

```sql
-- Hợp lệ nếu input nằm trong giới hạn hỗ trợ hiện hành
SELECT REGEXP_SUBSTR(MessageBody, N'\d+')
FROM dbo.Messages;
```

Bạn vẫn nên:
- tránh đưa chuỗi cực lớn vào regex nếu không cần;
- kiểm tra giới hạn/version khi triển khai thật;
- nhớ rằng **fuzzy matching functions** vẫn không nhận `varchar(max)` / `nvarchar(max)` theo docs hiện hành.

---

# PHẦN A — REGEX

## 3. `REGEXP_LIKE`

Dùng để kiểm tra có match hay không.

```sql
SELECT ContactId, Email
FROM dbo.Contacts
WHERE REGEXP_LIKE
(
    Email,
    N'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
);
```

Phù hợp cho:
- validation/filtering;
- `WHERE`;
- `CASE WHEN`.

Không dùng để lấy substring hay đếm match.

---

## 4. `REGEXP_REPLACE`

```sql
SELECT REGEXP_REPLACE
(
    N'user+newsletter@contoso.com',
    N'\+.*@',
    N'@'
) AS NormalizedEmail;
```

Kết quả:

```text
user@contoso.com
```

Ví dụ chỉ giữ số:

```sql
SELECT REGEXP_REPLACE
(
    N'+84 (090) 123-4567',
    N'\D',
    N''
) AS DigitsOnly;
```

---

## 5. `REGEXP_SUBSTR`

Dùng khi đề yêu cầu **trích xuất giá trị**.

```sql
SELECT
    TicketId,
    REGEXP_SUBSTR
    (
        MessageText,
        N'ORD-\d{6}'
    ) AS OrderCode
FROM dbo.SupportTickets;
```

Occurrence:

```sql
SELECT REGEXP_SUBSTR
(
    N'a@x.com b@y.com c@z.com',
    N'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
    1,
    2
) AS SecondEmail;
```

---

## 6. `REGEXP_INSTR`

Dùng khi đề hỏi vị trí/index.

```sql
SELECT REGEXP_INSTR
(
    N'Product ID: 98765',
    N'\d+'
) AS StartPosition;
```

Nếu cần **giá trị** thì dùng `REGEXP_SUBSTR`, không phải `REGEXP_INSTR`.

---

## 7. `REGEXP_COUNT`

```sql
SELECT REGEXP_COUNT
(
    N'ERR-1 OK ERR-2 OK ERR-3',
    N'ERR-\d+'
) AS ErrorCount;
```

Decision:
- "có hay không" → `REGEXP_LIKE`;
- "bao nhiêu lần" → `REGEXP_COUNT`.

---

## 8. `REGEXP_MATCHES` — TVF rất dễ ra bẫy

Cú pháp:

```sql
SELECT *
FROM REGEXP_MATCHES
(
    N'Learning #AzureSQL #DP800',
    N'#([A-Za-z0-9_]+)'
);
```

Current output columns quan trọng:

```text
match_id
start_position
end_position
match_value
substring_matches
```

### Sửa lỗi tài liệu cũ

Không dùng:

```sql
m.value
```

nếu bạn muốn full match. Dùng:

```sql
SELECT
    m.match_id,
    m.match_value,
    m.start_position,
    m.end_position,
    m.substring_matches
FROM REGEXP_MATCHES
(
    N'Learning #AzureSQL #DP800',
    N'#([A-Za-z0-9_]+)'
) AS m;
```

Ví dụ với table:

```sql
SELECT
    x.MessageId,
    m.match_id,
    m.match_value
FROM dbo.Messages AS x
CROSS APPLY REGEXP_MATCHES
(
    x.MessageBody,
    N'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
) AS m;
```

---

## 9. `REGEXP_SPLIT_TO_TABLE`

Dùng khi delimiter là regex.

```sql
SELECT s.value
FROM REGEXP_SPLIT_TO_TABLE
(
    N'SQL,Azure;Fabric|AI',
    N'[,;|]'
) AS s;
```

Khác với `REGEXP_MATCHES`:
- `MATCHES` trả các đoạn **khớp**;
- `SPLIT_TO_TABLE` trả các đoạn **sau khi tách**.

---

## 10. Flags

| Flag | Ý nghĩa |
|---|---|
| `c` | case-sensitive, mặc định |
| `i` | case-insensitive |
| `m` | multiline |
| `s` | dot-all: `.` match newline |

```sql
SELECT REGEXP_LIKE
(
    N'AzureSQL',
    N'azuresql',
    'i'
);
```

---

# PHẦN B — FUZZY STRING MATCHING

## 11. Vì sao fuzzy khác regex?

Regex trả lời:

> "Chuỗi có đúng pattern không?"

Fuzzy trả lời:

> "Hai chuỗi giống nhau tới mức nào?"

Use case:
- tên khách hàng gõ sai;
- deduplication;
- matching dữ liệu khác spelling;
- typo tolerance.

---

## 12. `EDIT_DISTANCE`

Số phép biến đổi cần thiết.

```sql
SELECT EDIT_DISTANCE
(
    N'Colour',
    N'Color'
) AS Distance;
```

**Nhỏ hơn = giống hơn.**

Có thể chỉ định `maximum_distance`:

```sql
SELECT EDIT_DISTANCE
(
    N'Microsoft',
    N'Msft',
    3
) AS DistanceWithinThreshold;
```

---

## 13. `EDIT_DISTANCE_SIMILARITY`

```sql
SELECT EDIT_DISTANCE_SIMILARITY
(
    N'Colour',
    N'Color'
) AS Similarity;
```

Kết quả là **0–100**, không phải 0–1.

- `100` = giống hoàn toàn;
- gần `0` = rất khác.

Ví dụ threshold:

```sql
SELECT CustomerId, FullName
FROM dbo.Customers
WHERE EDIT_DISTANCE_SIMILARITY
(
    FullName COLLATE Latin1_General_100_CI_AS,
    N'Nguyen Van An' COLLATE Latin1_General_100_CI_AS
) >= 85;
```

---

## 14. `JARO_WINKLER_DISTANCE`

Ưu tiên các chuỗi giống nhau ở phần đầu.

```sql
SELECT JARO_WINKLER_DISTANCE
(
    N'Colour',
    N'Color'
) AS Distance;
```

**Nhỏ hơn = giống hơn.**

---

## 15. `JARO_WINKLER_SIMILARITY`

```sql
SELECT JARO_WINKLER_SIMILARITY
(
    N'Colour',
    N'Color'
) AS Similarity;
```

**Lớn hơn = giống hơn**, thang 0–100.

---

## 16. Fuzzy và collation

Fuzzy functions có các giới hạn collation/version riêng. Khi database dùng collation không phù hợp, có thể áp `COLLATE` trên expression.

```sql
SELECT EDIT_DISTANCE_SIMILARITY
(
    NameA COLLATE Latin1_General_100_CI_AS,
    NameB COLLATE Latin1_General_100_CI_AS
);
```

**Exam mindset:** nếu đề cho lỗi fuzzy liên quan collation, đừng mặc định function sai; kiểm tra loại collation/platform.

---

# PHẦN C — DECISION TABLE THI

| Scenario | Chọn |
|---|---|
| Validate email pattern | `REGEXP_LIKE` |
| Remove punctuation | `REGEXP_REPLACE` |
| Extract Order ID | `REGEXP_SUBSTR` |
| Find position of first number | `REGEXP_INSTR` |
| Count hashtags | `REGEXP_COUNT` |
| Return all hashtags as rows | `REGEXP_MATCHES` |
| Split CSV-like string with multiple delimiters | `REGEXP_SPLIT_TO_TABLE` |
| Exact number of edits between strings | `EDIT_DISTANCE` |
| Need similarity threshold 0–100 | `EDIT_DISTANCE_SIMILARITY` |
| Prefix similarity important | Jaro-Winkler |

---

# PHẦN D — 15 CÂU TỰ KIỂM TRA

### Câu 1
Cần biết chuỗi có chứa SKU theo format `SKU-\d{5}` không.

**Đáp án:** `REGEXP_LIKE`.

### Câu 2
Cần lấy SKU đầu tiên.

**Đáp án:** `REGEXP_SUBSTR`.

### Câu 3
Cần vị trí SKU đầu tiên.

**Đáp án:** `REGEXP_INSTR`.

### Câu 4
Cần đếm tất cả SKU.

**Đáp án:** `REGEXP_COUNT`.

### Câu 5
Cần trả tất cả SKU thành nhiều dòng.

**Đáp án:** `REGEXP_MATCHES`.

### Câu 6
Full match của `REGEXP_MATCHES` nằm ở cột nào?

**Đáp án:** `match_value`.

### Câu 7
`REGEXP_MATCHES` là scalar function?

**Đáp án:** Không. Là TVF.

### Câu 8
Regex hiện luôn bắt buộc cast `nvarchar(max)` về `nvarchar(4000)`?

**Đáp án:** Không. Current docs hỗ trợ LOB input tới 2 MB cho `REGEXP_*`.

### Câu 9
`EDIT_DISTANCE_SIMILARITY` trả 0–1?

**Đáp án:** Không. Trả 0–100.

### Câu 10
`EDIT_DISTANCE` càng lớn càng giống?

**Đáp án:** Sai. Distance càng nhỏ càng giống.

### Câu 11
Jaro-Winkler hữu ích khi phần đầu chuỗi giống nhau có ý nghĩa?

**Đáp án:** Đúng.

### Câu 12
Cần split `A,B;C|D` thành 4 rows.

**Đáp án:** `REGEXP_SPLIT_TO_TABLE`.

### Câu 13
Cần case-insensitive regex.

**Đáp án:** flag `i`.

### Câu 14
Database compatibility level thường cần cho regex SQL Server 2025?

**Đáp án:** 170.

### Câu 15
Cần so hai customer names bị typo và chọn score >= 90.

**Đáp án:** similarity function như `EDIT_DISTANCE_SIMILARITY` / `JARO_WINKLER_SIMILARITY` tùy requirement.

---

# CHECKLIST EXAM-READY

- [ ] Phân biệt 7 regex functions.
- [ ] Biết `REGEXP_MATCHES`/`REGEXP_SPLIT_TO_TABLE` là TVF.
- [ ] Nhớ `match_value` của `REGEXP_MATCHES`.
- [ ] Không còn học quy tắc cũ “LOB luôn phải CAST”.
- [ ] Biết 4 fuzzy functions.
- [ ] Nhớ distance nhỏ hơn = gần hơn.
- [ ] Nhớ similarity lớn hơn = gần hơn.
- [ ] Nhớ `EDIT_DISTANCE_SIMILARITY` = 0–100.
- [ ] Biết fuzzy có collation/platform constraints.
