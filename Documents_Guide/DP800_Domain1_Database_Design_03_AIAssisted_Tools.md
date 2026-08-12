# DP-800 Miền 1 — Phát triển SQL với công cụ hỗ trợ AI

> **Miền 1:** Thiết kế và phát triển giải pháp cơ sở dữ liệu (35–40%)  
> **Chủ đề:** Copilot, hướng dẫn cho AI, Agent mode và Model Context Protocol (MCP)  
> **Ưu tiên cá nhân:** **Score Weak Point #1**  
> **Blueprint:** DP-800 — Skills measured as of **March 12, 2026**  
> **Rà soát:** **12/08/2026**

> [!IMPORTANT]
> Mục tiêu của file này không phải học thuộc tên sản phẩm. Bạn phải hiểu chuỗi **Copilot → hướng dẫn/ngữ cảnh → Agent/MCP → danh tính → quyền database** và chọn đúng giải pháp cho từng tình huống.

## Chương này giúp bạn làm được việc gì?

Copilot có thể giải thích một truy vấn, gợi ý T-SQL hoặc dùng MCP để gọi công cụ. Nhưng AI không tự biết quy ước đặt tên của công ty, không tự có quyền truy cập cơ sở dữ liệu và cũng không bảo đảm mã sinh ra là an toàn.

Ví dụ, bạn yêu cầu AI “xóa các đơn hàng thử nghiệm”. Một hệ thống an toàn phải trả lời được:

- AI đang dùng model và ngữ cảnh nào?
- AI chỉ tư vấn hay được phép tự gọi tool?
- tool nào được bật?
- tool chạy dưới danh tính nào?
- danh tính đó có quyền `DELETE` trên bảng nào?
- ai sẽ xem lại thay đổi trước khi chạy?

Đó chính là trọng tâm của chương: dùng AI để tăng năng suất nhưng vẫn giữ **đặc quyền tối thiểu (least privilege)**, kiểm soát dữ liệu gửi ra ngoài và không xem câu trả lời của model như mã đã được tin cậy.

---

## 1. Phạm vi thi chính thức

Theo [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800), bạn phải có thể:

1. Giải thích ảnh hưởng bảo mật của công cụ hỗ trợ AI.
2. Bật GitHub Copilot và Microsoft Copilot trong Fabric.
3. Cấu hình model và các MCP tool trong Copilot chat.
4. Tạo file hướng dẫn cho GitHub Copilot.
5. Kết nối MCP endpoint cho Microsoft SQL Server và Fabric lakehouse.

---

# PHẦN A — CÁCH HÌNH DUNG TOÀN BỘ HỆ THỐNG

## 2. Phát triển SQL có AI hỗ trợ gồm những lớp nào?

```text
Yêu cầu của người dùng
   ↓
Copilot / AI client
   ↓
Model + ngữ cảnh + hướng dẫn
   ↓
Ask mode hoặc Agent mode
   ↓
(Optional) MCP tools
   ↓
Xác thực / RBAC / quyền database
   ↓
SQL Server / Azure SQL / Fabric
```

| Lớp | Vai trò | Điều không nên nhầm |
|---|---|---|
| Model | Lập luận và sinh mã | Không cấp quyền cơ sở dữ liệu |
| Copilot client | UI/host | Không phải MCP server |
| Instructions | Hướng dẫn hành vi | Không phải security boundary |
| MCP | Cho agent discover/call tools | Không tự cấp quyền |
| DB security | Enforce permission thật | Đây mới là boundary cuối |

**Quy tắc thi:** Instruction có thể nói “không xóa”, nhưng nếu tool `delete_record` vẫn bật và identity có `DELETE`, hệ thống vẫn chưa đạt least privilege.

---

# PHẦN B — ẢNH HƯỞNG BẢO MẬT

## 3. Rò rỉ dữ liệu qua câu lệnh gửi cho AI (prompt)

Không đưa vào prompt nếu policy không cho phép:

- password, API key, access token;
- connection string có secret;
- PII/PHI/payment data không cần thiết;
- production data vượt data-classification/residency policy.

**Cách làm an toàn hơn:** dùng Managed Identity, biến môi trường hoặc Key Vault; trong prompt chỉ dùng giá trị giữ chỗ, không dán bí mật thật.

## 4. Mã do AI sinh ra không mặc nhiên đáng tin cậy

AI có thể sinh:

- SQL Injection;
- `UPDATE`/`DELETE` thiếu `WHERE`;
- Cartesian join;
- non-SARGable predicates;
- index thừa;
- transaction sai;
- query gây scan/lock lớn.

Quy trình an toàn:

```text
Generate → Review → Test → Check permissions → Inspect impact → Execute
```

## 5. Nguyên tắc đặc quyền tối thiểu (least privilege)

Nếu support agent chỉ cần xem inventory:

```text
BAD:
db_owner + create/read/update/delete

GOOD:
read-only identity
+ expose đúng entity
+ enable read/describe
+ disable write/delete
```

---

# PHẦN C — GITHUB COPILOT TRONG SSMS

Nguồn:
- [GitHub Copilot in SSMS](https://learn.microsoft.com/en-us/ssms/github-copilot/overview)
- [Agent mode](https://learn.microsoft.com/en-us/ssms/github-copilot/agent-mode)
- [MCP servers in SSMS](https://learn.microsoft.com/en-us/ssms/github-copilot/mcp-servers)

## 6. So sánh chế độ hỏi đáp và chế độ tác nhân

### Chế độ hỏi đáp (Ask mode)
- giải thích/sinh/sửa T-SQL;
- hỏi schema/context;
- thường là quy trình hỏi–đáp một lượt.

### Chế độ tác nhân (Agent mode)
- goal nhiều bước;
- chạy query/tools;
- có thể gọi MCP;
- tự lặp lại tới khi hoàn thành hoặc cần user input.

**Nhớ:** MCP tools trong SSMS gắn với **Agent mode**.

---

# PHẦN D — HƯỚNG DẪN TÙY CHỈNH CHO COPILOT

## 7. Hướng dẫn áp dụng cho toàn bộ kho mã nguồn

File:

```text
.github/copilot-instructions.md
```

Ví dụ:

```markdown
# Hướng dẫn phát triển SQL

- Target SQL Server 2025 and Azure SQL Database unless stated otherwise.
- Qualify objects with schema names.
- Never embed passwords, access tokens, or API keys.
- For dynamic SQL, use sys.sp_executesql with parameters.
- Avoid SELECT * in production examples.
- Prefer set-based T-SQL over cursors where practical.
- Treat UPDATE/DELETE as destructive operations.
- Explain security and performance trade-offs.
```

Nguồn: [GitHub repository custom instructions](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions)

## 8. Hướng dẫn riêng cho từng đường dẫn

Ví dụ sau giới hạn hướng dẫn cho những file hoặc thư mục nhất định, tránh áp dụng một quy tắc không phù hợp cho toàn repository.

```text
.github/instructions/sql.instructions.md
```

```markdown
---
applyTo: "**/*.sql"
---

- Use schema-qualified object names.
- Use parameterized dynamic SQL.
- Dùng TRY/CATCH cho quy trình ghi dữ liệu có transaction.
```

GitHub cũng hỗ trợ `AGENTS.md` trên một số Copilot agent surfaces. Hỗ trợ phụ thuộc client/surface, nên không học máy móc một file cho mọi nơi.

---

# PHẦN E — CẬP NHẬT 2026: HƯỚNG DẪN Ở CẤP DATABASE TRONG SSMS

Đây là phần mới cần bổ sung so với bản repo ngày 09/08/2026.

Nguồn:
- [Database instructions in SSMS](https://learn.microsoft.com/en-us/ssms/github-copilot/database-instructions)
- [Execution context for GitHub Copilot](https://learn.microsoft.com/en-us/ssms/github-copilot/execution-context)

## 9. Phân biệt hướng dẫn trong kho mã nguồn và hướng dẫn trong cơ sở dữ liệu

```text
Git repository:
  .github/copilot-instructions.md
  .github/instructions/*.instructions.md
  AGENTS.md (surface-dependent)

SSMS database metadata:
  AGENTS.md extended property
  CONSTITUTION.md extended property
```

Tên có thể giống nhau nhưng storage/scope khác nhau.

## 10. Object-level `AGENTS.md`

Dùng để cung cấp semantic/business context ngay trong database.

```sql
EXEC sys.sp_addextendedproperty
    @name = N'AGENTS.md',
    @value = N'
dbo.Orders stores customer orders.
Status values:
1 = New
2 = Paid
3 = Shipped
9 = Cancelled.',
    @level0type = N'SCHEMA',
    @level0name = N'dbo',
    @level1type = N'TABLE',
    @level1name = N'Orders';
GO
```

Trường hợp sử dụng: tên cột hoặc đối tượng khó hiểu, Copilot cần biết ý nghĩa nghiệp vụ và quy ước chuẩn.

## 11. Database `CONSTITUTION.md`

Constitution đưa ra guidance cấp database, precedence cao.

```sql
EXEC sys.sp_addextendedproperty
    @name = N'CONSTITUTION.md',
    @value = N'
Use schema-qualified object names.
Do not use SELECT *.
Treat UPDATE and DELETE as destructive operations.';
GO
```

## 12. Chế độ thực thi theo người dùng với `agentExecuteAsUser`

Trong Agent mode, `CONSTITUTION.md` có thể chỉ định identity để Copilot execute query:

```sql
EXEC sys.sp_addextendedproperty
    @name = N'CONSTITUTION.md',
    @value = N'---
agentExecuteAsUser: ReportingUser
---
Use schema-qualified names.
Do not modify production data.';
GO
```

Tạo low-privilege user:

```sql
CREATE USER ReportingUser WITHOUT LOGIN;
GO

GRANT SELECT ON SCHEMA::dbo TO ReportingUser;
GO

GRANT IMPERSONATE ON USER::ReportingUser TO AppDeveloper;
GO
```

### Điểm cần nhớ về bảo mật khi làm bài

- `agentExecuteAsUser` scope theo database.
- Connected user cần `IMPERSONATE` phù hợp.
- Không dùng `sa`, `dbo`, `db_owner` nếu không thật sự cần.
- Nếu account không có quyền, không nên “fix” bằng cách cấp full control.
- SQL permissions vẫn là enforcement boundary.

Kiểm tra constitution:

```sql
SELECT name, CAST(value AS nvarchar(max)) AS ConstitutionContent
FROM sys.extended_properties
WHERE class = 0
  AND name = N'CONSTITUTION.md';
GO
```

---

# PHẦN F — MICROSOFT COPILOT TRONG FABRIC

Nguồn: [Enable and configure Copilot in Microsoft Fabric](https://learn.microsoft.com/en-us/fabric/fundamentals/copilot-enable-fabric)

## 13. Điều kiện cần có hiện hành

- paid Fabric capacity **F2+** hoặc Power BI Premium **P1+**;
- tenant settings;
- supported capacity/region;
- workspace được assign đúng capacity;
- user/workspace permission phù hợp.

```text
Capacity → Tenant settings → Workspace → User access → Copilot
```

**Bẫy:** “Copilot in Fabric cần F64+” là thông tin cũ.

---

# PHẦN G — CHỌN MODEL AI

## 14. Không học thuộc máy móc danh sách model

Model availability thay đổi theo:

- Copilot plan;
- organization policy;
- client/surface;
- thời điểm.

Khi đề hỏi model option, nghĩ:

```text
task fit + capability + latency + cost + organization policy
```

Model choice **không thay** DB permission.

---

# PHẦN H — MODEL CONTEXT PROTOCOL (MCP)

## 15. MCP là gì?

MCP cho AI client/agent:

1. discover tool;
2. hiểu input/output schema;
3. invoke tool;
4. nhận structured response.

```text
MCP client ↔ MCP server ↔ external system/database/API
```

MCP không tự tăng quyền. Tool execution vẫn chịu authentication, RBAC và permissions.

---

# PHẦN I — MICROSOFT SQL MCP SERVER

Nguồn:
- [SQL MCP Server overview](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/overview)
- [DML tools](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/data-manipulation-language-tools)
- [Stdio transport](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/stdio-transport)

Microsoft SQL MCP Server hiện nằm trên **Data API builder (DAB)**.

```text
Agent
 ↓
SQL MCP Server / DAB
 ↓
Entity abstraction + RBAC + policies
 ↓
SQL database
```

## 16. Bảy công cụ DML

1. `describe_entities`
2. `create_record`
3. `read_records`
4. `update_record`
5. `delete_record`
6. `execute_entity`
7. `aggregate_records`

**Nhớ:** Describe + CRUD + Execute + Aggregate.

SQL MCP Server không nên được hiểu là arbitrary NL2SQL server. Agent thao tác qua approved typed tools/entities.

---

# PHẦN J — THỰC HÀNH SQL MCP

## 17. Bảng dữ liệu mẫu

Bảng nhỏ này là dữ liệu thử để MCP đọc. Không dùng dữ liệu nhạy cảm hoặc dữ liệu production khi học cách cấu hình tool.

```sql
CREATE TABLE dbo.Products
(
    Id        int PRIMARY KEY,
    Name      nvarchar(100) NOT NULL,
    Inventory int NOT NULL,
    Price     decimal(10,2) NOT NULL
);
GO

INSERT dbo.Products(Id, Name, Inventory, Price)
VALUES
(1, N'Action Figure', 40, 14.99),
(2, N'Building Blocks', 25, 29.99);
GO
```

## 18. Cài DAB

```bash
dotnet tool install --global Microsoft.DataApiBuilder
dab --version
```

Environment variable:

```text
MSSQL_CONNECTION_STRING=Server=localhost;Database=ProductsDb;Trusted_Connection=True;TrustServerCertificate=True
```

Init:

```bash
dab init \
  --database-type mssql \
  --connection-string "@env('MSSQL_CONNECTION_STRING')" \
  --host-mode Development \
  --config dab-config.json
```

Expose entity:

```bash
dab add Products \
  --source dbo.Products \
  --permissions "anonymous:read" \
  --description "Products with inventory and retail price."
```

## 19. Bật MCP read-only

Merge fragment sau vào config:

```json
{
  "runtime": {
    "mcp": {
      "enabled": true,
      "dml-tools": {
        "describe-entities": true,
        "create-record": false,
        "read-records": true,
        "update-record": false,
        "delete-record": false,
        "execute-entity": false,
        "aggregate-records": true
      }
    }
  }
}
```

## 20. STDIO local

```bash
dab start --mcp-stdio --config ./dab-config.json
```

`.vscode/mcp.json`:

```json
{
  "servers": {
    "sql-mcp-server": {
      "type": "stdio",
      "command": "dab",
      "args": [
        "start",
        "--mcp-stdio",
        "role:anonymous",
        "--loglevel",
        "error",
        "--config",
        "${workspaceFolder}/dab-config.json"
      ]
    }
  }
}
```

---

# PHẦN K — SO SÁNH SQL MCP VÀ FABRIC MCP

| Tình huống | Chọn |
|---|---|
| CRUD/aggregate/execute approved SQL entities | SQL MCP Server / DAB |
| Fabric APIs / OneLake / Fabric items | Fabric MCP Server |
| Giải thích/sinh T-SQL | Copilot Chat/Ask |
| Multi-step + external tools | Agent mode + MCP |

---

# PHẦN L — SQL ĐỘNG AN TOÀN KHI DÙNG VỚI AI

Nguy hiểm:

```sql
DECLARE @Sql nvarchar(max) =
    N'SELECT * FROM dbo.Customers WHERE Email = ''' + @Email + N'''';

EXEC(@Sql);
```

An toàn hơn:

```sql
DECLARE @Sql nvarchar(max) =
N'SELECT CustomerId, FullName, Email
  FROM dbo.Customers
  WHERE Email = @pEmail;';

EXEC sys.sp_executesql
    @Sql,
    N'@pEmail nvarchar(320)',
    @pEmail = @Email;
```

---

# PHẦN M — BẢNG CHỌN GIẢI PHÁP

| Tình huống | Đáp án ưu tiên |
|---|---|
| Persistent rules toàn repo | `.github/copilot-instructions.md` |
| Rules chỉ `*.sql` | `.github/instructions/*.instructions.md` |
| DB object business context trong SSMS | DB `AGENTS.md` extended property |
| DB-wide Copilot policy | `CONSTITUTION.md` |
| Agent chạy dưới user hạn chế | `agentExecuteAsUser` + `IMPERSONATE` |
| External tools từ Copilot | MCP |
| MCP trong SSMS | Agent mode |
| Controlled SQL CRUD | SQL MCP Server / DAB |
| Fabric APIs/OneLake | Fabric MCP Server |
| Chỉ cần read | disable create/update/delete + restricted identity |
| Fabric Copilot | F2+/P1+ + tenant/workspace settings |
| AI dynamic SQL | `sp_executesql` + parameters |
| Prompt có secrets | remove/redact + secret store/identity |

---

# PHẦN N — BẪY THƯỜNG GẶP TRONG ĐỀ

1. **Instruction ≠ permission.**
2. **MCP ≠ database admin quyền cao.**
3. **SQL MCP ≠ arbitrary NL2SQL.**
4. **Ask mode ≠ Agent mode.**
5. **Fabric F64+ là thông tin cũ.**
6. **Repository `AGENTS.md` ≠ SSMS database `AGENTS.md`.**
7. `agentExecuteAsUser` phải đi cùng least privilege/`IMPERSONATE`.
8. AI output luôn cần review/test.

---

# PHẦN O — CÂU HỎI TỰ KIỂM TRA

### Q1
Nhóm muốn mọi mã do AI sinh trong kho mã nguồn đều ghi đầy đủ tên schema.  
**Đáp án:** `.github/copilot-instructions.md`.

### Q2
Chỉ `.sql` files phải có rule riêng.  
**Đáp án:** `.github/instructions/*.instructions.md` + `applyTo`.

### Q3
Copilot trong SSMS cần biết `Status=9` nghĩa là Cancelled.  
**Đáp án:** database instruction `AGENTS.md` trên object phù hợp.

### Q4
Mọi Copilot interaction của database cần policy chung.  
**Đáp án:** `CONSTITUTION.md`.

### Q5
Agent phải execute dưới `ReportingUser` read-only.  
**Đáp án:** `agentExecuteAsUser`, cấp `IMPERSONATE` cần thiết, giữ ReportingUser least privilege.

### Q6
Agent cần CRUD approved entities qua typed tools.  
**Đáp án:** SQL MCP Server/DAB.

### Q7
Agent cần Fabric APIs/OneLake.  
**Đáp án:** Fabric MCP Server.

### Q8
Support agent chỉ đọc inventory nhưng `delete_record` đang enabled.  
**Đáp án:** disable destructive tools và hạn chế DB permission.

### Q9
Copilot sinh dynamic SQL nối input.  
**Đáp án:** parameterized `sys.sp_executesql`.

### Q10
Fabric workspace ở F4 và tenant settings phù hợp.  
**Đáp án:** F4 đáp ứng F2+ prerequisite; không cần F64.

### Q11
Instruction nói “never delete” nhưng login có `DELETE`.  
**Đáp án:** chưa đủ; permission/tool scope mới enforce.

### Q12
MCP cần chạy trong quy trình nhiều bước của SSMS.  
**Đáp án:** Agent mode.

---

# PHẦN P — DANH SÁCH BÀI THỰC HÀNH

- [ ] Giải thích model, Copilot client, MCP, DB permission.
- [ ] Nêu 4 security risks.
- [ ] Phân biệt Ask/Agent.
- [ ] Tạo `.github/copilot-instructions.md`.
- [ ] Tạo path-specific instruction.
- [ ] Tạo DB object `AGENTS.md`.
- [ ] Tạo `CONSTITUTION.md`.
- [ ] Cấu hình `agentExecuteAsUser`.
- [ ] Giải thích `IMPERSONATE`.
- [ ] Nhớ Fabric F2+/P1+.
- [ ] Cài DAB.
- [ ] Expose read-only entity.
- [ ] Bật SQL MCP read-only.
- [ ] Cấu hình stdio MCP.
- [ ] Nhớ 7 DML tools.
- [ ] Sửa SQL Injection do AI sinh.
- [ ] Trả lời 12 câu hỏi tự kiểm tra và giải thích được vì sao các phương án khác sai.

---

# PHẦN Q — BẢNG GHI NHỚ NHANH

Phần này chỉ tóm tắt mối quan hệ giữa các thành phần; hãy quay lại phần tương ứng nếu chưa giải thích được vì sao mỗi lựa chọn an toàn hoặc không an toàn.

```text
Repo-wide rules         -> .github/copilot-instructions.md
Path rules              -> .github/instructions/*.instructions.md
SSMS DB object context  -> AGENTS.md extended property
SSMS DB-wide policy     -> CONSTITUTION.md
Execution identity      -> agentExecuteAsUser + IMPERSONATE
Security                -> least privilege + DB permissions
MCP in SSMS             -> Agent mode
SQL MCP                 -> DAB
SQL MCP tools           -> describe/create/read/update/delete/execute/aggregate
Fabric Copilot          -> F2+/P1+ + tenant/workspace settings
Dynamic SQL             -> sp_executesql + parameters
```

---

# TÀI LIỆU THAM KHẢO

- [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
- [GitHub Copilot in SSMS](https://learn.microsoft.com/en-us/ssms/github-copilot/overview)
- [Agent mode](https://learn.microsoft.com/en-us/ssms/github-copilot/agent-mode)
- [Database instructions](https://learn.microsoft.com/en-us/ssms/github-copilot/database-instructions)
- [Execution context](https://learn.microsoft.com/en-us/ssms/github-copilot/execution-context)
- [GitHub repository custom instructions](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions)
- [Custom instruction support](https://docs.github.com/en/copilot/reference/custom-instructions-support)
- [Enable Copilot in Fabric](https://learn.microsoft.com/en-us/fabric/fundamentals/copilot-enable-fabric)
- [SQL MCP Server](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/overview)
- [SQL MCP DML tools](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/data-manipulation-language-tools)
- [SQL MCP stdio](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/stdio-transport)
