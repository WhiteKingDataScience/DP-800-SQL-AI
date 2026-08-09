# DP-800 Domain 1: Design & Implement SQL Solutions by Using AI-Assisted Tools

> **Miền 1:** Design and Develop Database Solutions (35–40%)  
> **Chủ đề:** Design and implement SQL solutions by using AI-assisted tools  
> **Trọng tâm cá nhân:** **Score Weak Point #1** trong score report  
> **Blueprint:** DP-800 skills measured as of **March 12, 2026**  
> **Rà soát/cập nhật:** **09/08/2026**

> [!IMPORTANT]
> Đây là file cần ưu tiên cao nhất. Phần này thay đổi nhanh theo sản phẩm, vì vậy các con số phiên bản/capacity/configuration trong bản cũ đã được cập nhật theo Microsoft Learn hiện hành. Trong kỳ thi, hãy ưu tiên **concept + security + lựa chọn công cụ đúng scenario**, không học thuộc tên model hoặc UI có thể thay đổi.

---

# 1. CHECKLIST BLUEPRINT — MICROSOFT MUỐN BẠN BIẾT GÌ?

Theo DP-800 Study Guide, bạn phải có thể:

1. **Interpret the security impact of AI-assisted tools.**
2. **Enable GitHub Copilot and Microsoft Copilot in Fabric.**
3. **Configure model and MCP tool options** in GitHub Copilot hoặc Copilot in Fabric chat.
4. **Create and configure GitHub Copilot instruction files.**
5. **Connect MCP server endpoints**, bao gồm SQL Server và Fabric lakehouse.

Nguồn chuẩn: [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)

---

# 2. NHỮNG ĐIỂM BẢN CŨ CẦN SỬA

Bản cũ chưa đủ exam-ready vì:

1. Ghi **Fabric F64+** mới dùng Copilot — đã lỗi thời. Hướng dẫn hiện tại yêu cầu paid Fabric capacity **F2+** hoặc Power BI Premium **P1+**, cộng tenant/capacity/workspace configuration phù hợp.
2. Dùng ví dụ MCP package `@modelcontextprotocol/server-sql` như một SQL Server MCP chuẩn — không còn phù hợp với hướng Microsoft hiện tại. Microsoft có **SQL MCP Server** chính thức xây trên **Data API builder (DAB)**.
3. Chưa phân biệt rõ **Ask mode vs Agent mode** trong GitHub Copilot in SSMS; MCP trong SSMS cần **Agent mode**.
4. Chưa giải thích SQL MCP Server **không phải NL2SQL tùy ý**; Microsoft chủ động dùng entity/RBAC/query-builder deterministic model.
5. Chưa giải thích SQL MCP Server tập trung vào **DML/existing objects**, không phải DDL schema authoring.
6. Chưa cập nhật **seven DML tools** của SQL MCP Server 2.0.
7. Custom instructions mới chỉ nói `.github/copilot-instructions.md`, chưa nhắc path-specific `.github/instructions/*.instructions.md`.
8. Security section dùng một số policy wording cũ và quá tuyệt đối. Phiên bản này chuyển sang nguyên tắc bền vững: data classification, least privilege, no secrets, review output, RBAC, approval, tenant/data-boundary settings.

---

# 3. MENTAL MODEL — AI-ASSISTED SQL THỰC RA LÀ GÌ?

Hãy nhớ chuỗi sau:

```text
User intent / prompt
        ↓
Copilot / AI client
        ↓
Context + Instructions + Selected model
        ↓
(Optional) Agent mode / MCP client
        ↓
MCP Server exposes controlled tools
        ↓
RBAC / permissions / database login
        ↓
SQL / Fabric data systems
```

### Bốn lớp cần phân biệt

| Lớp | Vai trò |
|---|---|
| **Model** | sinh reasoning/text/code dựa trên context |
| **Copilot client** | UI/host như SSMS, VS Code, Fabric |
| **MCP** | protocol để AI client discover/call external tools |
| **Database security** | giới hạn dữ liệu/thao tác thực sự được phép |

**Exam trap:** MCP **không tự cấp thêm quyền database**. Tool/agent cuối cùng vẫn bị giới hạn bởi auth/RBAC/login/permissions được cấu hình.

---

# 4. SECURITY IMPACT — PHẦN CẦN SUY LUẬN, KHÔNG HỌC VẸT

## 4.1 Rủi ro #1 — Prompt/data leakage

Không dán vào prompt:

- password;
- API key;
- connection string chứa secret;
- access token;
- production PII không cần thiết;
- payment/health/customer secrets;
- dữ liệu vượt data-classification policy.

### Pattern an toàn

```text
BAD:
“Đây là password prod: P@ss..., hãy sửa connection string.”

BETTER:
“Connection string lấy secret từ approved secret store/environment variable.
Hãy viết mẫu không chứa credential thực.”
```

---

## 4.2 Rủi ro #2 — AI-generated code có thể sai

AI có thể sinh:

- SQL Injection;
- thiếu `WHERE` trong `UPDATE/DELETE`;
- Cartesian join;
- non-SARGable predicate;
- index quá nhiều;
- transaction/error handling sai;
- schema-changing DDL không mong muốn;
- query gây scan/lock lớn.

### Quy tắc thi

**AI output ≠ trusted code.**

Luôn:

1. review;
2. test;
3. dùng least privilege;
4. xem execution plan nếu liên quan performance;
5. xác nhận destructive actions trước khi chạy.

Microsoft cũng nêu rõ GitHub Copilot in SSMS có thể tạo nội dung không chính xác và output cần người có năng lực đánh giá trước khi sử dụng.

Nguồn: [GitHub Copilot in SSMS Overview](https://learn.microsoft.com/en-us/ssms/github-copilot/overview)

---

## 4.3 Rủi ro #3 — Permission amplification

AI agent chỉ nên được cấp quyền tối thiểu cần thiết.

Ví dụ:

- Agent chỉ đọc inventory ⇒ cấp `SELECT`, không cấp `db_owner`.
- MCP chỉ cần một entity ⇒ chỉ expose entity đó.
- Không cho `delete_record` nếu nghiệp vụ không cần delete.

**Exam clue:** “most secure / least privilege” ⇒ giới hạn **identity + role + entity + operation + field**.

---

## 4.4 Rủi ro #4 — Data boundary / compliance

Fabric có tenant settings liên quan việc dữ liệu gửi đến Azure OpenAI có thể được xử lý/lưu ngoài geographic region, compliance boundary hoặc national cloud instance. Đây là lựa chọn governance, không phải chỉ một toggle “bật AI”.

Nguồn:

- [Enable and configure Copilot in Microsoft Fabric](https://learn.microsoft.com/en-us/fabric/fundamentals/copilot-enable-fabric)
- [Copilot and Agent tenant settings](https://learn.microsoft.com/en-us/fabric/admin/service-admin-portal-copilot)

---

# 5. GITHUB COPILOT IN SSMS — TRẠNG THÁI HIỆN HÀNH

## 5.1 SSMS version matrix — đừng gom mọi capability thành “SSMS 22+”

Copilot cũ trong SSMS 21 đã được thay bởi **GitHub Copilot in SSMS 22**. Tài liệu ôn thi hiện tại nên học theo SSMS 22.

| Capability | Phiên bản tối thiểu theo tài liệu hiện hành | Trạng thái cần nhớ |
|---|---:|---|
| Chat/code assistance | SSMS 22 với AI Assistance workload | GitHub account có Copilot access, hoặc entitlement miễn phí được hỗ trợ |
| Autocompletions trong query editor | **SSMS 22.2** | Không suy diễn rằng có ở mọi bản 22.0/22.1 |
| Agent mode | **SSMS 22.7** | **Preview** |
| MCP servers trong SSMS | **SSMS 22.7** + Agent mode | Ask mode không gọi MCP |

GitHub Copilot in SSMS hỗ trợ SQL Server, Azure SQL Database, Azure SQL Managed Instance và SQL Database in Fabric.

Nguồn:

- [GitHub Copilot in SSMS Overview](https://learn.microsoft.com/en-us/ssms/github-copilot/overview)
- [SSMS 22 Release Notes](https://learn.microsoft.com/en-us/ssms/release-notes-22)

---

## 5.2 Cách kích hoạt theo tư duy thi

Bạn không cần học từng pixel UI. Hãy nhớ prerequisites:

1. Dùng **SSMS 22** cho Chat; dùng **22.7+** nếu scenario yêu cầu Agent mode/MCP.
2. Cài **AI Assistance workload** bằng SSMS installer.
3. Đăng nhập GitHub account có Copilot access phù hợp.
4. Organization policy có thể kiểm soát feature/model access.
5. Connect tới database bằng login có đúng permissions.

### Điểm cực quan trọng

Copilot chạy query dựa trên **permissions của login hiện tại**. Nếu login không được `SELECT` table, Copilot không biến login đó thành admin.

Theo trang Overview hiện hành, prompts, responses và system metadata của Copilot in SSMS không được SSMS/Copilot giữ lại để train/retrain model. Tuy vậy, tổ chức vẫn phải áp dụng data-classification, tenant/organization policy và quy tắc không đưa secret vào prompt; một privacy statement của sản phẩm không phải lý do để bỏ governance.

---

# 6. ASK MODE VS AGENT MODE

## Ask mode

Phù hợp khi:

- hỏi giải thích SQL;
- sinh hoặc sửa T-SQL;
- hỏi schema/context;
- muốn người dùng chủ động kiểm soát các bước.

## Agent mode

Agent mode có thể xử lý goal nhiều bước, chọn tool và thực hiện action theo workflow. Trong SSMS hiện hành, Agent mode là nơi có thể dùng MCP servers.

### Câu cần thuộc

```text
MCP in GitHub Copilot in SSMS => Agent mode
Ask mode => không hỗ trợ MCP server tools trong SSMS
```

Sau khi thêm MCP server, tools có thể **disabled by default** và cần bật theo nhu cầu.

Administrator có thể tắt Agent/MCP hoặc đặt **MCP server allow list**. Vì vậy “đã thêm server vào `%USERPROFILE%\.mcp.json`” chưa bảo đảm server/tool được phép dùng trong organization. File này là global configuration theo user cho SSMS, không phải repository config:

```json
{
  "servers": {
    "approved-service": {
      "url": "https://mcp.contoso.example/mcp"
    }
  }
}
```

Nguồn: [Use MCP servers with GitHub Copilot in SSMS](https://learn.microsoft.com/en-us/ssms/github-copilot/mcp-servers)

---

# 7. MODEL OPTIONS — ĐỪNG HỌC THUỘC DANH SÁCH MODEL

GitHub Copilot có model picker và model availability phụ thuộc:

- Copilot plan;
- organization policy;
- feature/surface;
- model availability tại thời điểm sử dụng.

### Exam strategy

Nếu hỏi “configure model option”, hãy nghĩ:

- chọn model trong model picker/client settings;
- organization có thể hạn chế models;
- chọn model phù hợp task/cost/latency/capability;
- model choice **không thay thế database permissions**.

Không nên học thuộc một danh sách model cụ thể vì danh sách thay đổi nhanh.

---

# 8. MICROSOFT COPILOT IN FABRIC — CÁCH ENABLE ĐÚNG HIỆN NAY

## 8.1 Prerequisites quan trọng

Theo Microsoft Learn hiện hành:

- paid Fabric capacity **F2 hoặc cao hơn**, hoặc Power BI Premium **P1 hoặc cao hơn**;
- capacity ở supported region;
- tenant settings cho Copilot;
- workspace được assign vào capacity phù hợp;
- users có workspace access;
- có thể scope bằng security groups.

> Bản cũ ghi `F64+`; điểm này đã được sửa.

## 8.2 Quy trình tư duy

```text
Capacity supported
    ↓
Tenant settings
    ↓
(Optional) delegated capacity settings
    ↓
Workspace assigned to capacity
    ↓
User/workspace permission
    ↓
Copilot experience available
```

Nguồn: [Enable and configure Copilot in Microsoft Fabric](https://learn.microsoft.com/en-us/fabric/fundamentals/copilot-enable-fabric)

---

# 9. GITHUB COPILOT CUSTOM INSTRUCTIONS

## 9.1 Repository-wide instructions

File:

```text
.github/copilot-instructions.md
```

Áp dụng các hướng dẫn chung cho repository context.

### Mẫu cho SQL project

```markdown
# SQL development instructions

- Target SQL Server 2025 and Azure SQL Database unless the task says otherwise.
- Generate idempotent deployment-friendly scripts when practical.
- Never embed passwords, access tokens, or API keys in code.
- For dynamic SQL with untrusted values, use sys.sp_executesql and parameters.
- Do not use SELECT * in production examples unless explicitly requested.
- Prefer set-based T-SQL over cursors/RBAR when practical.
- Treat UPDATE and DELETE as destructive operations: verify the predicate first.
- For performance recommendations, explain the expected access path and trade-offs.
- Before suggesting a new index, check whether an equivalent index already exists.
- For transactions, use TRY/CATCH and safe rollback behavior.
```

### Bẫy

Instruction file **hướng dẫn AI**, không phải database security boundary. Một instruction “never delete data” không thay thế `DENY DELETE`/RBAC/permissions.

---

## 9.2 Path-specific instructions

GitHub cũng hỗ trợ:

```text
.github/instructions/NAME.instructions.md
```

Ví dụ chỉ áp dụng cho `.sql`:

```markdown
---
applyTo: "**/*.sql"
---

- Use T-SQL syntax supported by the project's target platform.
- Qualify objects with schema names.
- Use parameterized dynamic SQL.
- Include rollback-safe migration notes for destructive schema changes.
```

Nguồn:

- [GitHub — Repository custom instructions](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions)
- [GitHub — Custom instruction support](https://docs.github.com/en/copilot/reference/custom-instructions-support)

---

# 10. MCP — MODEL CONTEXT PROTOCOL TỪ ZERO

## 10.1 MCP là gì?

MCP là một standard để AI agent/client:

1. discover tools;
2. biết input/output schema;
3. invoke tool;
4. nhận structured response.

### Thành phần

```text
MCP Client / Host
    ↕ protocol
MCP Server
    ↕
External service / database / API
```

Ví dụ:

- SSMS Copilot Agent = MCP client/host.
- SQL MCP Server = MCP server.
- SQL database = system mà tools thao tác.

---

## 10.2 MCP tool không phải prompt text thuần

Một MCP tool có contract rõ hơn prompt kiểu “hãy đoán SQL”. Tool có thể là:

```text
read_records
create_record
update_record
execute_entity
```

Agent chọn tool và truyền arguments theo schema.

**Security implication:** chỉ expose tools mà agent thực sự cần.

---

# 11. SQL MCP SERVER — PHẦN MỚI QUAN TRỌNG NHẤT

Microsoft hiện có **SQL MCP Server** chính thức, là một phần của **Data API builder (DAB)**.

## 11.1 Kiến trúc

```text
Copilot / MCP client
        ↓
SQL MCP Server (DAB)
        ↓
Entity abstraction + RBAC + policy
        ↓
DAB Query Builder / Stored Procedure
        ↓
SQL database
```

## 11.2 Điều rất dễ ra bẫy

### SQL MCP Server không chủ trương NL2SQL tùy ý

Microsoft thiết kế SQL MCP Server theo hướng deterministic qua DAB entity abstraction/query builder, thay vì để LLM sinh SQL tự do rồi chạy trực tiếp.

### SQL MCP Server tập trung DML, không DDL

Nó phục vụ interaction với dữ liệu/object đã expose:

- create/read/update/delete records;
- aggregate;
- execute stored-procedure entity.

Không coi nó là công cụ chính để `CREATE TABLE` / `ALTER TABLE` schema.

Nguồn: [SQL MCP Server Overview](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/overview)

---

# 12. SQL MCP SERVER — LAB CHẠY LOCAL VỚI VS CODE

> Microsoft Learn: SQL MCP Server có từ DAB 1.7+, nhưng nên dùng latest **2.0** để có capability/bug fixes mới.

## 12.1 Cài DAB CLI

```bash
dotnet new tool-manifest
dotnet tool install microsoft.dataapibuilder
dotnet tool restore
```

Kiểm tra:

```bash
dab --version
```

---

## 12.2 Tạo database sample

```sql
CREATE DATABASE ProductsDb;
GO

USE ProductsDb;
GO

CREATE TABLE dbo.Products
(
    Id        INT NOT NULL PRIMARY KEY,
    Name      NVARCHAR(100) NOT NULL,
    Inventory INT NOT NULL,
    Price     DECIMAL(10,2) NOT NULL,
    Cost      DECIMAL(10,2) NOT NULL
);
GO

INSERT dbo.Products(Id, Name, Inventory, Price, Cost)
VALUES
(1, N'Action Figure', 40, 14.99, 5.00),
(2, N'Building Blocks', 25, 29.99, 10.00),
(3, N'Board Game', 20, 34.99, 12.50);
GO
```

---

## 12.3 Không hardcode secret vào config

Tạo `.env` local hoặc dùng environment variable/secret store phù hợp:

```text
MSSQL_CONNECTION_STRING=Server=localhost;Database=ProductsDb;Trusted_Connection=True;TrustServerCertificate=True
```

> Không commit `.env` chứa production secrets vào Git.

---

## 12.4 Khởi tạo `dab-config.json`

```bash
dab init \
  --database-type mssql \
  --connection-string "@env('MSSQL_CONNECTION_STRING')" \
  --host-mode Development \
  --config dab-config.json
```

Expose entity chỉ read:

```bash
dab add Products \
  --source dbo.Products \
  --permissions "anonymous:read" \
  --description "Toy store products with inventory, price, and cost."
```

### Vì sao description quan trọng?

Agent cần semantic metadata để hiểu entity/field đúng hơn. Microsoft khuyến nghị mô tả field thay vì bắt model đoán ý nghĩa tên cột.

Ví dụ:

```bash
dab update Products --fields.name Id        --fields.primary-key true --fields.description "Product Id"
dab update Products --fields.name Name      --fields.description "Product name"
dab update Products --fields.name Inventory --fields.description "Units in stock"
dab update Products --fields.name Price     --fields.description "Retail price"
dab update Products --fields.name Cost      --fields.description "Store cost"
```

## 12.5 Bật MCP rõ ràng trong `dab-config.json` cho STDIO

Với `stdio`, Microsoft yêu cầu `runtime.mcp.enabled = true`. Để học thi và tránh phụ thuộc default của phiên bản DAB, hãy cấu hình rõ:

```json
{
  "runtime": {
    "mcp": {
      "enabled": true,
      "path": "/mcp",
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

Đây là ví dụ **read-oriented**: chỉ bật tool cần thiết. Trong config, tên option dùng dạng có dấu gạch ngang như `read-records`; khi MCP expose tool cho client, tool name là dạng `read_records`.

> Không thay nguyên file `dab-config.json` bằng fragment trên. Hãy merge `runtime.mcp` vào config do `dab init` tạo.

Nguồn: [Stdio transport for SQL MCP Server](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/stdio-transport)

---

# 13. SQL MCP TRANSPORT — HTTP VS STDIO

SQL MCP Server hỗ trợ hai transport chính:

| Transport | Dùng khi |
|---|---|
| `stdio` | local development, VS Code agent, CLI workflows |
| streamable HTTP | hosted/cloud/server scenarios |

## 13.1 STDIO — recommended cho local dev

DAB chạy như child process của MCP client.

```bash
dab start --mcp-stdio --config ./dab-config.json
```

Có role:

```bash
dab start --mcp-stdio role:authenticated --config ./dab-config.json
```

Các chi tiết dễ bị hỏi/sai khi cấu hình:

- `role:<name>` là positional argument và phải đứng **ngay sau** `--mcp-stdio`; bỏ qua thì mặc định là `anonymous`;
- `runtime.mcp.path` chỉ dùng cho HTTP, bị bỏ qua trong `stdio`;
- `stdio` ép authentication provider thành `Simulator`, phù hợp local development chứ không phải cơ chế bảo vệ production HTTP endpoint;
- mỗi incoming request trong `stdio` hiện bị giới hạn **1 MB**;
- thiếu `runtime.mcp` hoặc đặt `enabled: false` thì DAB không khởi động ở `stdio` mode.

Nguồn: [Stdio transport for SQL MCP Server](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/stdio-transport)

---

## 13.2 `.vscode/mcp.json` — config chính thức mẫu

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

> Schema `mcp.json` phụ thuộc MCP client. Đừng trộn config của client này với client khác rồi kết luận MCP server “sai”.

Nguồn: [SQL MCP Server — VS Code local quickstart](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/quickstart-visual-studio-code)

---

# 14. SEVEN DML TOOLS CỦA SQL MCP SERVER 2.0

SQL MCP Server hiện expose bảy DML tools chính:

1. `describe_entities`
2. `create_record`
3. `read_records`
4. `update_record`
5. `delete_record`
6. `execute_entity`
7. `aggregate_records`

### Cách nhớ

```text
Describe schema/context
CRUD records
Execute exposed entity/SP
Aggregate records
```

Mỗi tool chịu RBAC/entity permission/policy của DAB.

### Hạn chế destructive tool

Nếu agent không được phép delete, cấu hình để không expose/cho phép delete thay vì chỉ ghi prompt “đừng xóa”.

Nguồn: [SQL MCP Server Overview](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/overview)

---

# 15. STORED PROCEDURE AS CUSTOM MCP TOOL

DAB 2.0 có thể expose stored procedure entity như named custom MCP tool.

Ý tưởng config:

```json
{
  "entities": {
    "GetProductById": {
      "source": {
        "type": "stored-procedure",
        "object": "dbo.GetProductById"
      },
      "mcp": {
        "custom-tool": true
      }
    }
  }
}
```

**Use case:** thay vì cho model tự dựng query phức tạp, expose một stored procedure đã kiểm soát logic và permission.

---

# 16. FABRIC MCP SERVER — LOCAL

Microsoft có **Fabric MCP Server** cho AI agents làm việc với Fabric APIs, OneLake data và item definitions.

## 16.1 Cách đơn giản

Microsoft khuyến nghị có thể cài Fabric MCP Server extension trong VS Code; extension tự register MCP server.

## 16.2 npm/npx config

Với MCP client hỗ trợ cấu hình kiểu này:

```json
{
  "mcpServers": {
    "fabric-mcp-server": {
      "command": "npx",
      "args": [
        "-y",
        "@microsoft/fabric-mcp@latest",
        "server",
        "start",
        "--mode",
        "all"
      ]
    }
  }
}
```

Prerequisite cho npm/npx hiện tại: Node.js 20 LTS+.

Nguồn: [Get started with Fabric MCP Server (local)](https://learn.microsoft.com/en-us/rest/api/fabric/articles/mcp-servers/pro-dev-local/get-started-local)

---

# 17. FABRIC MCP VS SQL MCP — CHỌN CÁI NÀO?

| Scenario | Công cụ hợp lý |
|---|---|
| AI agent cần CRUD SQL entities với RBAC/DAB | **SQL MCP Server** |
| Agent cần Fabric APIs/items/OneLake/Fabric environment | **Fabric MCP Server** |
| Chỉ hỏi/sinh T-SQL trong SSMS | GitHub Copilot in SSMS Ask/Chat |
| Multi-step agent + external tools trong SSMS | Agent mode + MCP |
| Need schema/data access controlled by SQL login | database permissions + MCP/config |

Không chọn MCP chỉ vì câu hỏi có chữ “AI”. MCP cần khi AI phải **discover/invoke external tools**.

---

# 18. CONFIGURE MCP TOOL OPTIONS — TƯ DUY THI

Blueprint nhắc “configure model and MCP tool options”. Bạn nên hiểu tool option ở mức:

- server nào được connect;
- tool nào enabled/disabled;
- role/permission nào được dùng;
- entity nào exposed;
- operation nào allowed;
- read vs write/destructive scope;
- Agent mode có quyền gọi tool nào.

### Principle

```text
Enable the minimum tool surface required for the task.
```

Ví dụ support agent chỉ cần xem inventory:

```text
Expose Products
Allow read
Disable create/update/delete
Do not expose Cost if not needed
Use a restricted database identity
```

Đây an toàn hơn nhiều so với expose toàn database rồi dựa vào prompt instruction.

---

# 19. PROMPTING CHO SQL — CẤU TRÚC TỐT

Một prompt tốt nên có:

1. **Goal** — muốn làm gì.
2. **Platform/version** — SQL Server 2025, Azure SQL, Fabric SQL…
3. **Schema/context** — tables/keys/indexes liên quan.
4. **Constraints** — security/performance/compatibility.
5. **Expected output** — query, explanation, test cases, plan review.

### Ví dụ index tuning

```text
Mục tiêu: tối ưu query dưới đây trên SQL Server 2025.
Schema: dbo.Orders có 80M rows; PK(OrderId), hiện có IX_Orders_CustomerId.
Workload: query chạy 500 lần/phút, trả <100 rows.
Yêu cầu:
1. Giữ predicate SARGable.
2. Chỉ đề xuất index nếu index hiện tại không cover.
3. Giải thích key columns vs INCLUDE.
4. Nêu write/storage trade-off.
5. Không chạy DDL; chỉ sinh script để review.
```

### Ví dụ query generation an toàn

```text
Viết stored procedure tìm customer theo email.
- Target: Azure SQL Database.
- Không nối chuỗi input.
- Nếu cần dynamic SQL, dùng sys.sp_executesql với parameter.
- Chỉ SELECT các cột CustomerId, FullName, Email.
- Giải thích index phù hợp.
```

Nguồn: [GitHub Copilot prompt engineering](https://docs.github.com/en/copilot/concepts/prompting/prompt-engineering)

---

# 20. SECURITY LAB — AI-SAFE DYNAMIC SQL

Giả sử Copilot đề xuất:

```sql
-- NGUY HIỂM
DECLARE @Sql NVARCHAR(MAX) =
    N'SELECT * FROM dbo.Customers WHERE Email = ''' + @Email + N'''';
EXEC(@Sql);
```

Bạn phải nhận ra SQL Injection risk và sửa:

```sql
DECLARE @Sql NVARCHAR(MAX) =
N'SELECT CustomerId, FullName, Email
  FROM dbo.Customers
  WHERE Email = @pEmail;';

EXEC sys.sp_executesql
    @Sql,
    N'@pEmail NVARCHAR(320)',
    @pEmail = @Email;
```

**Exam pattern:** AI-generated code + concatenated user input ⇒ reject/repair with parameterization.

---

# 21. SECURITY LAB — LEAST-PRIVILEGE DATABASE IDENTITY

Ví dụ minh họa read-only database user:

```sql
CREATE USER [app_mcp_reader] WITHOUT LOGIN;
GO

GRANT SELECT ON OBJECT::dbo.Products TO [app_mcp_reader];
GO

-- Không grant UPDATE/DELETE/ALTER/CONTROL.
```

Trong môi trường Azure thực tế, thường kết hợp Entra identity/managed identity và database permissions phù hợp. Điểm thi cần nhớ là **identity được cấp đúng quyền tối thiểu**, không phải “AI cần db_owner để hoạt động”.

---

# 22. CÁC BẪY THI CỰC QUAN TRỌNG

## Bẫy 1 — “MCP = AI được query mọi thứ”

Sai. MCP chỉ expose tools; access còn bị security/configuration giới hạn.

## Bẫy 2 — “Instruction file là security control”

Sai. Instruction ảnh hưởng model behavior; RBAC/permissions mới là enforcement boundary.

## Bẫy 3 — “SQL MCP Server = NL2SQL server”

Sai theo thiết kế hiện tại của Microsoft SQL MCP Server. Nó dùng DAB entity abstraction + deterministic query builder.

## Bẫy 4 — “SQL MCP để CREATE/ALTER schema”

Không phải mục tiêu chính. SQL MCP Server được thiết kế quanh DML/existing entities; DDL có công cụ development khác.

## Bẫy 5 — “Fabric Copilot cần F64+”

Thông tin cũ. Hiện tại paid **F2+** hoặc **P1+** là prerequisite chính, kèm tenant/capacity/workspace requirements.

## Bẫy 6 — “Ask mode trong SSMS dùng MCP tools”

Hiện tại MCP server integration trong SSMS cần **Agent mode**.

## Bẫy 7 — “AI sinh code thì code đúng”

Không. Microsoft yêu cầu review AI output; agent cũng chịu permissions.

## Bẫy 8 — “Hardcode API key trong instruction/config để Copilot dễ dùng”

Không. Secret phải nằm ở approved secret store/environment/identity mechanism, không ở repo instruction file.

---

# 23. EXAM DECISION TABLE

| Từ khóa scenario | Ưu tiên nghĩ tới |
|---|---|
| Persistent repo-wide Copilot rules | `.github/copilot-instructions.md` |
| Rules only for `*.sql` files | `.github/instructions/*.instructions.md` + `applyTo` |
| External tools/services from Copilot | MCP |
| MCP in SSMS | Agent mode |
| Controlled SQL CRUD for agents | SQL MCP Server / DAB |
| Fabric APIs / OneLake / item definitions | Fabric MCP Server |
| Fabric Copilot enablement | F2+/P1+, tenant settings, capacity/workspace access |
| Agent should only read data | least privilege + read-only tool/entity permission |
| Prevent destructive agent action | disable/restrict write/delete tool + DB permission |
| AI-generated dynamic SQL | `sp_executesql` + parameters |
| Sensitive prompt data | redact/avoid + follow governance |
| Need consistent agent understanding of field meaning | semantic descriptions / schema context |
| Model choice | model picker/policy; don't memorize transient model list |

---

# 24. MOCK QUESTIONS — SÁT DẠNG DECISION-MAKING

## Q1 — Fabric capacity

Tổ chức muốn bật Copilot in Fabric. Workspace ở Fabric F4 capacity và admin đã bật tenant settings cho nhóm người dùng phù hợp.

**Kết luận:** F4 đáp ứng ngưỡng paid F2+; không cần F64 chỉ vì dùng Copilot.

---

## Q2 — MCP mode in SSMS

Bạn thêm một MCP server vào GitHub Copilot in SSMS nhưng đang dùng Ask mode và không thấy tool được gọi.

**Đáp án:** chuyển sang **Agent mode**, sau đó kiểm tra MCP tools được enable.

---

## Q3 — Least privilege

Support agent chỉ cần xem order status nhưng MCP role có `create/update/delete` toàn bộ Orders.

**Đáp án:** giới hạn entity/tool/role xuống read-only và database permissions tối thiểu.

---

## Q4 — Instruction file

Team muốn mọi Copilot request trong repo tuân theo T-SQL coding rules.

**Đáp án:** `.github/copilot-instructions.md`.

---

## Q5 — Path-specific instruction

Chỉ `.sql` files phải có schema-qualified names.

**Đáp án:** `.github/instructions/<name>.instructions.md` với `applyTo: "**/*.sql"`.

---

## Q6 — SQL MCP architecture

Agent cần deterministic CRUD vào approved SQL entities, không muốn model tự dựng arbitrary SQL.

**Đáp án:** Microsoft SQL MCP Server với DAB entity abstraction/RBAC.

---

## Q7 — DDL

Agent phải thay schema liên tục bằng `ALTER TABLE`. Bạn được hỏi SQL MCP Server có phải DDL engine chính không.

**Đáp án:** không; SQL MCP Server thiết kế quanh DML/existing entities. DDL nên dùng database development tooling/workflow phù hợp.

---

## Q8 — Secret

Developer định thêm production connection string/password vào `.github/copilot-instructions.md`.

**Đáp án:** không; instruction file nằm trong repo và không phải secret store.

---

## Q9 — SQL Injection

Copilot sinh `EXEC('... WHERE Email=''' + @Email + '''')`.

**Đáp án:** sửa sang `sys.sp_executesql` parameterized.

---

## Q10 — Fabric MCP

Agent cần discover/work với Fabric APIs, OneLake và Fabric item definitions từ development machine.

**Đáp án:** Fabric MCP Server.

---

## Q11 — SQL entity semantic context

Agent thường đoán sai ý nghĩa `InvQty`.

**Đáp án:** thêm semantic/field description trong DAB configuration, thay vì chỉ tăng model temperature hay cấp thêm quyền.

---

## Q12 — MCP security enforcement

Repo instruction viết “never delete records”, nhưng MCP role vẫn có delete và DB login có delete.

**Đáp án:** instruction không đủ. Phải hạn chế/delete tool, DAB permissions và/hoặc database permission.

---

# 25. HANDS-ON CHECKLIST — CHỈ ĐÁNH DẤU KHI TỰ LÀM ĐƯỢC

- [ ] Giải thích model, Copilot client, MCP client, MCP server, database permission khác nhau thế nào.
- [ ] Giải thích security risks của prompt/data/code/tool access.
- [ ] Biết GitHub Copilot in SSMS hiện theo **SSMS 22**.
- [ ] Phân biệt Ask mode và Agent mode.
- [ ] Biết MCP trong SSMS cần Agent mode.
- [ ] Biết Fabric Copilot prerequisite **F2+ hoặc P1+** và tenant/workspace controls.
- [ ] Tạo `.github/copilot-instructions.md`.
- [ ] Tạo path-specific `.github/instructions/*.instructions.md` với `applyTo`.
- [ ] Giải thích MCP protocol ở mức client/server/tool/discovery/invocation.
- [ ] Cài DAB CLI và tạo `dab-config.json`.
- [ ] Expose entity read-only bằng DAB.
- [ ] Cấu hình `.vscode/mcp.json` để chạy SQL MCP qua stdio.
- [ ] Nhớ SQL MCP Server 2.0 có 7 DML tools chính.
- [ ] Giải thích vì sao SQL MCP Server không phải arbitrary NL2SQL engine.
- [ ] Giải thích vì sao instruction file không thay thế RBAC.
- [ ] Nhận diện Fabric MCP Server scenario.
- [ ] Review được AI-generated dynamic SQL và sửa SQL Injection.

---

# 26. LINK THAM KHẢO CHÍNH THỨC

## DP-800

- [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)

## GitHub Copilot in SSMS

- [What is GitHub Copilot in SSMS?](https://learn.microsoft.com/en-us/ssms/github-copilot/overview)
- [GitHub Copilot Agent Mode](https://learn.microsoft.com/en-us/ssms/github-copilot/agent-mode)
- [Use MCP servers with GitHub Copilot in SSMS](https://learn.microsoft.com/en-us/ssms/github-copilot/mcp-servers)
- [SSMS 22 Release Notes](https://learn.microsoft.com/en-us/ssms/release-notes-22)

## Fabric Copilot

- [Enable and configure Copilot in Microsoft Fabric](https://learn.microsoft.com/en-us/fabric/fundamentals/copilot-enable-fabric)
- [Copilot and Agent tenant settings](https://learn.microsoft.com/en-us/fabric/admin/service-admin-portal-copilot)

## GitHub Copilot instructions

- [Repository custom instructions](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions)
- [Custom instructions support](https://docs.github.com/en/copilot/reference/custom-instructions-support)
- [Prompt engineering for GitHub Copilot](https://docs.github.com/en/copilot/concepts/prompting/prompt-engineering)

## SQL MCP Server

- [SQL MCP Server Overview](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/overview)
- [SQL MCP Server — VS Code local quickstart](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/quickstart-visual-studio-code)
- [Stdio transport](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/stdio-transport)
- [Data API builder documentation](https://learn.microsoft.com/en-us/azure/data-api-builder/)

## Fabric MCP

- [Get started with Fabric MCP Server (local)](https://learn.microsoft.com/en-us/rest/api/fabric/articles/mcp-servers/pro-dev-local/get-started-local)

---

# 27. CHEAT SHEET 60 GIÂY TRƯỚC KHI THI

```text
AI output              -> must review/test
Repo-wide rules        -> .github/copilot-instructions.md
Path-specific rules    -> .github/instructions/*.instructions.md + applyTo
Instruction file       -> behavior guidance, NOT security boundary
Least privilege        -> identity + RBAC + entity + operation + fields
SSMS current AI        -> GitHub Copilot in SSMS 22
SSMS MCP               -> Agent mode
Fabric Copilot         -> paid F2+ or P1+ + tenant/capacity/workspace controls
MCP                     -> client/server/tools, discover + invoke
SQL MCP                -> Data API builder
SQL MCP local           -> stdio is recommended for VS Code local dev
SQL MCP                -> deterministic DAB abstraction, not arbitrary NL2SQL
SQL MCP                -> DML/existing entities, not DDL engine
SQL MCP 2.0 tools      -> describe/create/read/update/delete/execute/aggregate
Fabric APIs/OneLake    -> Fabric MCP Server
Dynamic SQL            -> sp_executesql + parameters
Secrets/PII            -> do not place in prompts/repo config unless explicitly approved/protected
```
