# DP-800 — BỔ SUNG: TÍCH HỢP AZURE, AI-ASSISTED TOOLS & CÁC CHỦ ĐỀ THIẾU

> **Tài liệu bổ sung** — dành cho các điểm yếu: Azure Integration, AI-Assisted Tools,
> GitHub Copilot, Data API Builder, SQL Graph, Fabric SQL Database.
> **Tại sao cần?** Đánh giá kỹ năng cho thấy các vùng kiến thức trọng tâm cần bổ sung:
> 1. Design and implement SQL solutions by using AI-assisted tools
> 2. Integrate SQL solutions with Azure services
> 3. Design and implement database objects
>
> File này bổ sung những kiến thức **chưa được đề cập đầy đủ** trong 3 guide chính.

---

## PHẦN A — TÍCH HỢP VỚI AZURE SERVICES

---

### A1. DATA API BUILDER (DAB) — Expose CSDL thành REST/GraphQL

#### A1.1. DAB là gì?

**Data API Builder (DAB)** là công cụ mã nguồn mở của Microsoft, cho phép bạn tạo
REST API và GraphQL API từ cơ sở dữ liệu **mà không cần viết code backend**. Chỉ cần
một file cấu hình JSON (`dab-config.json`).

```
┌──────────┐     ┌──────────────┐     ┌──────────────┐
│ Client   │────▶│ Data API     │────▶│ Azure SQL    │
│ (App/AI) │◀────│ Builder      │◀────│ Database     │
└──────────┘     └──────────────┘     └──────────────┘
                  dab-config.json
                  (cấu hình entity,
                   permissions, roles)
```

#### A1.2. Cấu trúc file dab-config.json

```json
{
  "$schema": "...",
  "data-source": {
    "database-type": "mssql",
    "connection-string": "@env('MSSQL_CONNECTION_STRING')"
  },
  "runtime": {
    "host": {
      "mode": "Production",
      "authentication": {
        "provider": "StaticWebApps"
      }
    },
    "rest": { "enabled": true },
    "graphql": { "enabled": true }
  },
  "entities": {
    "Procedures": {
      "source": { "type": "table", "object": "dbo.Procedures" },
      "permissions": [
        { "role": "anonymous", "actions": ["read"] }
      ]
    },
    "Transactions": {
      "source": { "type": "table", "object": "dbo.Transactions" },
      "permissions": [
        { "role": "authenticated", "actions": ["read", "create"] }
      ]
    },
    "UpdateProcedure": {
      "source": {
        "type": "stored-procedure",
        "object": "dbo.sp_UpdateProcedurePatient"
      },
      "permissions": [
        { "role": "authenticated", "actions": ["execute"] }
      ]
    }
  }
}
```

#### A1.3. Bảng quyết định nhanh — Permissions

| Yêu cầu đề bài | Role | Actions |
|---|---|---|
| "Đọc dữ liệu **không cần đăng nhập**" | `anonymous` | `["read"]` |
| "Đọc và ghi **sau khi đăng nhập**" | `authenticated` | `["read", "create"]` |
| "Chạy stored procedure **sau khi đăng nhập**" | `authenticated` | `["execute"]` |
| "Admin được toàn quyền" | `admin` (custom) | `["*"]` |
| "Không ai được xoá" | Không cấp `"delete"` cho bất kỳ role nào | |

> 🎯 **Hai role hệ thống cần nhớ:**
> - `anonymous` = không cần xác thực
> - `authenticated` = đã xác thực nhưng không thuộc role cụ thể nào

#### A1.4. Cách khởi tạo DAB (câu hỏi đề thi)

```bash
# ĐÁP ÁN ĐÚNG — dùng @env() để đọc connection string từ biến môi trường
dab init \
  --database-type mssql \
  --connection-string "@env('MSSQL_CONNECTION_STRING')" \
  --host-mode Production \
  --config dab-config.json
```

| Cú pháp | Đúng/Sai | Giải thích |
|---|---|---|
| `@env('MSSQL_CONNECTION_STRING')` | ✅ | DAB đọc biến môi trường tại runtime |
| `secretref:MSSQL_CONNECTION_STRING` | ❌ | `secretref:` là của Azure Container Apps YAML, không phải DAB CLI |
| `@env('DAB_CONFIG_BASE64')` | ❌ | Sai biến — cái này chứa config DAB, không phải connection string |
| Connection string viết trực tiếp | ❌ | Lộ thông tin nhạy cảm, anti-pattern |

---

### A2. AZURE FUNCTIONS — SQL TRIGGER BINDING

#### A2.1. Azure SQL Trigger là gì?

Azure SQL Trigger cho Azure Functions cho phép function **tự động kích hoạt** khi dữ liệu
trong bảng thay đổi (INSERT, UPDATE, DELETE). Nó dựa trên **Change Tracking**, KHÔNG phải
DML trigger hay CDC.

```
┌──────────────┐   Change    ┌──────────────────┐   Kích hoạt   ┌──────────────┐
│ Azure SQL    │──Tracking──▶│ Azure Functions  │─────────────▶│ Xử lý logic  │
│ Database     │             │ SQL Trigger      │              │ (ghi log,    │
│              │             │ Binding          │              │  gọi API...) │
└──────────────┘             └──────────────────┘              └──────────────┘
```

#### A2.2. Cấu hình bắt buộc — 2 lớp

**Lớp 1: Database (phía SQL Server)**
```sql
-- Bước 1: Bật Change Tracking ở cấp DATABASE
ALTER DATABASE [TodoDB]
SET CHANGE_TRACKING = ON
    (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);

-- Bước 2: Bật Change Tracking ở cấp TABLE
ALTER TABLE dbo.ToDo
ENABLE CHANGE_TRACKING;
```

**Lớp 2: Application (phía Azure Functions)**
```json
// local.settings.json hoặc Azure Portal > Configuration
{
  "Sql_Trigger_MaxBatchSize": "100",
  "Sql_Trigger_PollingIntervalMs": "5000"
}
```

#### A2.3. Bảng quyết định — Đề hỏi "cấu hình nào thuộc database?"

| Câu hỏi đề thi | Đáp án |
|---|---|
| "Cấu hình **database** để hỗ trợ SQL trigger binding" | Bật Change Tracking ở DB + Table |
| "Cấu hình **polling interval 5 giây**" | `Sql_Trigger_PollingIntervalMs = 5000` (app setting) |
| "Cấu hình **batch size 100**" | `Sql_Trigger_MaxBatchSize = 100` (app setting) |
| "Hai cấu hình **database** cần thiết" | (1) DB-level tracking ON + (2) Table-level tracking ON |

> ⚠️ **Bẫy đề thi cực kỳ phổ biến:**
> Đề hỏi "Which **database** configurations?" — MaxBatchSize và PollingInterval là
> **application settings**, KHÔNG phải database configuration → loại ngay!

#### A2.4. Change Tracking vs CDC vs DML Trigger

| | Change Tracking | CDC | DML Trigger |
|---|---|---|---|
| **Mục đích** | Phát hiện dòng nào thay đổi | Ghi lại chi tiết thay đổi (before/after) | Thực thi logic khi INSERT/UPDATE/DELETE |
| **Dùng cho Azure Functions SQL Trigger** | ✅ **Chính xác** | ❌ Không hỗ trợ | ❌ Không hỗ trợ |
| **Overhead** | Thấp | Trung bình–Cao | Tuỳ logic trigger |
| **Lưu gì** | Phiên bản thay đổi (version) | Toàn bộ dữ liệu trước/sau | Không lưu tự động |
| **Khi nào dùng** | Sync, Azure Functions | Audit chi tiết, ETL, Data warehouse | Logic nghiệp vụ tức thời |

> 🎯 **Mẹo thi:** Nếu đề nói "Azure Functions SQL trigger" → đáp án LUÔN là **Change Tracking**.
> Nếu đề nói "embedding maintenance minimize CPU" → đáp án là **CDC + Azure Functions** (offload).

---

### A3. MANAGED IDENTITY & PASSWORDLESS AUTHENTICATION

#### A3.1. Tại sao cần Managed Identity?

| Cách cũ (sai) | Cách mới (đúng) |
|---|---|
| Connection string chứa username + password | Managed Identity — **không có password** |
| Phải lưu secret trong Key Vault, xoay key định kỳ | Azure tự quản lý token |
| Rủi ro lộ thông tin | Zero credential exposure |

#### A3.2. Các bước cấu hình

1. **Bật Managed Identity** trên App Service / Azure Functions
2. **Tạo user trong database** từ Managed Identity:
```sql
-- Tạo user từ Entra ID managed identity
CREATE USER [app-service-name] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [app-service-name];
ALTER ROLE db_datawriter ADD MEMBER [app-service-name];
```
3. **Connection string** không chứa password:
```
Server=myserver.database.windows.net;
Authentication=Active Directory Default;
Database=mydb;
```

#### A3.3. Credential cho REST endpoint (từ T-SQL)

Khi gọi Azure OpenAI từ SQL Server qua `sp_invoke_external_rest_endpoint`:

```sql
-- ĐÁP ÁN ĐÚNG — Managed Identity + resource ID
CREATE DATABASE SCOPED CREDENTIAL [AzureOpenAI_Cred]
WITH IDENTITY = 'Managed Identity',
     SECRET = '{"resourceid":"https://cognitiveservices.azure.com"}';
```

| Phương thức | Bảo mật | Đề thi hỏi "highest security" |
|---|---|---|
| Managed Identity + resource ID | ⭐⭐⭐ Cao nhất | ✅ Đáp án đúng |
| API Key trong SECRET | ⭐ Thấp | ❌ |
| HTTPEndpointHeaders + Bearer token | ⭐⭐ Trung bình | ❌ |

---

### A4. PRIVATE ENDPOINT & NETWORK ISOLATION

#### A4.1. Khi đề hỏi "traffic must stay within subscription"

```
┌──────────────────────────────────────────────────────────┐
│  Azure Subscription                                       │
│  ┌────────────┐  Private    ┌──────────────┐             │
│  │ App Service│──Endpoint──▶│ Azure SQL DB │             │
│  │ (VNet      │  (Private   │ (Public      │             │
│  │  subnet)   │   IP)       │  access OFF) │             │
│  └────────────┘             └──────────────┘             │
│                                                           │
│  ❌ Internet → BLOCKED (public access disabled)          │
└──────────────────────────────────────────────────────────┘
```

| Yêu cầu đề bài | Giải pháp |
|---|---|
| "Passwordless authentication" | Managed Identity + Entra ID |
| "Traffic stays within subscription" | Private Endpoint + disable public access |
| "Minimize administrative effort" | Managed Identity (không cần rotate password) |

---

### A5. AZURE SQL INPUT/OUTPUT BINDING (Azure Functions)

Ngoài SQL Trigger binding, Azure Functions còn hỗ trợ:

| Binding type | Hướng | Mô tả |
|---|---|---|
| **SQL Input Binding** | DB → Function | Đọc dữ liệu từ bảng/view khi function kích hoạt |
| **SQL Output Binding** | Function → DB | Ghi dữ liệu vào bảng khi function kết thúc |
| **SQL Trigger Binding** | DB → Function | Tự kích hoạt khi bảng thay đổi (Change Tracking) |

---

## PHẦN B — AI-ASSISTED TOOLS (GITHUB COPILOT & MCP)

---

### B1. GITHUB COPILOT CHAT TRONG SSMS

#### B1.1. Bản chất hoạt động

```
┌────────────┐   Gửi prompt   ┌──────────────┐   Trả code    ┌────────────┐
│ Developer  │───────────────▶│ GitHub       │──────────────▶│ SSMS       │
│            │                │ Copilot Chat │              │ Query      │
│            │                │ (AI service) │              │ Window     │
└────────────┘                └──────────────┘              └────────────┘
                                                                  │
                                                                  ▼
                                                            ┌────────────┐
                                                            │ Azure SQL  │
                                                            │ DB (dùng   │
                                                            │ permission │
                                                            │ của dev)   │
                                                            └────────────┘
```

> 🎯 **Điểm then chốt cho thi:**
> Copilot Chat chạy query bằng **database identity và permissions của developer**.
> Nó **KHÔNG** có credentials riêng, **KHÔNG** chạy trong sandbox riêng,
> **KHÔNG** filter kết quả ở client side.

#### B1.2. Bảo mật khi dùng Copilot Chat

| Tình huống | Cách đúng | Cách sai |
|---|---|---|
| Company cấm chia sẻ PII với AI | Chỉ cung cấp **schema details** (cấu trúc bảng, tên cột) | Copy dữ liệu thật vào chat |
| Cần Copilot tạo stored procedure | Mô tả bằng schema: "table Patients(PatientID, Name), table Procedures(ProcID, PatientID, Date)" | Paste kết quả SELECT vào chat |
| Cần validate SP | Mô tả logic cần kiểm tra | Chia sẻ connection string |

---

### B2. GITHUB COPILOT — REPOSITORY INSTRUCTIONS

#### B2.1. File `.github/copilot-instructions.md`

Đây là file hướng dẫn Copilot tuân theo quy tắc riêng của project. Ví dụ:
```markdown
# Quy tắc SQL
- Luôn dùng schema prefix (dbo.)
- Luôn dùng SET NOCOUNT ON
- Dùng THROW thay vì RAISERROR
```

#### B2.2. Tắt instructions cho bản thân mà không ảnh hưởng team

| Cách | Ảnh hưởng team? | Đúng/Sai |
|---|---|---|
| Sửa **User Settings** trong VS Code | ❌ Không | ✅ **Đáp án đúng** |
| Thêm flag `--debug` | ❌ Không, nhưng không tắt instructions | ❌ Sai mục đích |
| Xoá file `.github/copilot-instructions.md` | ⚠️ CÓ — xoá cho cả team | ❌ Sai |

---

### B3. MCP SERVER (MODEL CONTEXT PROTOCOL)

#### B3.1. MCP là gì?

**Model Context Protocol (MCP)** là giao thức chuẩn cho phép AI agent (Copilot, Claude...)
giao tiếp với các **tool servers** bên ngoài — ví dụ truy vấn GitHub repo, đọc database schema,
chạy command.

#### B3.2. Cấu hình MCP Server cho GitHub Copilot

**Trong VS Code:**
```
Command Palette → "MCP: add server"
→ Chọn "HTTP (HTTP or Server-Sent Events)"
→ Nhập URL: https://api.githubcopilot.com/mcp/
→ Lưu vào: Workspace settings (scoped to repo)
            hoặc User settings (global)
```

**Trong Visual Studio (KHÔNG phải VS Code):**
```
Tạo file .mcp.json ở thư mục gốc của project
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    }
  }
}
```

#### B3.3. Bảng quyết định — Câu hỏi MCP trong đề thi

| Yêu cầu đề bài | IDE | Đáp án |
|---|---|---|
| "Scoped to **repository**" + VS Code | VS Code | Lưu vào **workspace settings** |
| "Scoped to **user**" + VS Code | VS Code | Lưu vào **user settings** |
| "Dùng **OAuth**" (không PAT) | VS Code / VS | URL https://api.githubcopilot.com/mcp/ |
| "Visual Studio" (KHÔNG phải VS Code) | Visual Studio | Tạo file `.mcp.json` |

| Đáp án sai thường gặp | Tại sao sai |
|---|---|
| Lưu PAT trong `.vscode/mcp.json` | Lộ credential, anti-pattern |
| Lưu PAT trong `.github/mcp.json` | Lộ credential, anti-pattern |
| Lưu vào user settings khi đề yêu cầu repo-scoped | User settings = global, không scoped |
| Tạo `.vscode/settings.json` khi IDE là Visual Studio | `.vscode` là cho VS Code, VS dùng `.mcp.json` hoặc `.vs` |

---

## PHẦN C — SQL GRAPH (MATCH OPERATOR)

---

### C1. SQL Graph Tables — Khái niệm cơ bản

SQL Server hỗ trợ **graph database** với 2 loại bảng đặc biệt:

| Loại | Mô tả | Ví dụ |
|---|---|---|
| **NODE** | Thực thể (entity) | `Person`, `Product`, `City` |
| **EDGE** | Mối quan hệ (relationship) | `Knows`, `Purchased`, `LivesIn` |

```sql
-- Tạo Node table
CREATE TABLE dbo.Person (
    PersonID INT PRIMARY KEY,
    DisplayName NVARCHAR(100)
) AS NODE;

-- Tạo Edge table
CREATE TABLE dbo.Knows (
    StartDate DATE
) AS EDGE;
```

### C2. MATCH Operator — Cú pháp duyệt graph

**Cú pháp:**
```sql
MATCH(node1-(edge1)->node2-(edge2)->node3)
```

Các quy tắc QUAN TRỌNG:
1. **Dấu mũi tên chỉ hướng:** `->` = quan hệ từ trái sang phải
2. **Mọi hop phải nằm trong MỘT MATCH():** KHÔNG tách thành 2 MATCH() nối bằng AND
3. **Cần khai báo đủ bảng trong FROM:** mỗi node/edge cần alias riêng

**Ví dụ đề thi — Tìm người cách 2 hop:**
```sql
-- Tìm tất cả người cách @StartPersonId đúng 2 bước "knows"
SELECT p3.PersonID, p3.DisplayName
FROM dbo.Person AS p1,
     dbo.Knows AS k1,
     dbo.Person AS p2,
     dbo.Knows AS k2,
     dbo.Person AS p3
WHERE p1.PersonId = @StartPersonId
  AND MATCH(p1-(k1)->p2-(k2)->p3);
```

### C3. Bẫy đề thi về MATCH

| Đáp án sai | Tại sao sai |
|---|---|
| `WHERE p1.DisplayName = p1.DisplayName` | Tautology — thiếu filter `@StartPersonId` |
| `MATCH(p3-(k2)->p2-(k1)->p1)` | Ngược hướng — tìm người "biết" root thay vì root "biết" họ |
| `MATCH(p1-(k1)->p2) AND MATCH(p2-(k2)->p3)` | 2 MATCH tách rời — SQL Graph **không hỗ trợ** |
| Thiếu alias cho k1, k2 trong FROM | Lỗi cú pháp — mỗi edge cần alias riêng |

---

## PHẦN D — CI/CD VỚI SQL DATABASE PROJECTS

---

### D1. SDK-Style SQL Database Project

SQL Database Project (.sqlproj) cho phép quản lý schema dưới dạng code:

```
my-db-project/
├── dbo/
│   ├── Tables/
│   │   ├── Orders.sql
│   │   └── Customers.sql
│   └── StoredProcedures/
│       └── sp_GetOrders.sql
├── my-db.sqlproj
└── .github/
    └── workflows/
        └── deploy.yml
```

### D2. Pipeline CI/CD — Các bước

```yaml
name: Deploy DB
on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      # 1. Build — Schema validation xảy ra ở ĐÂY
      - run: dotnet build my-db.sqlproj --configuration Release
        # → Tạo .dacpac artifact
        # → Validate dependencies, data types, constraints

      # 2. Test (tuỳ chọn)
      - run: dotnet test

      # 3. Deploy — Chỉ apply changes, KHÔNG validate lại
      - run: SqlPackage /Action:Publish /SourceFile:my-db.dacpac ...
```

### D3. Câu hỏi đề thi về CI/CD

| Câu hỏi | Đáp án |
|---|---|
| "Schema validation xảy ra ở bước nào?" | **Build** (dotnet build) |
| "Schema validation có xảy ra ở Deploy không?" | **Không** — Deploy chỉ apply |
| "Unit tests chạy tự động khi push main?" | **Có** — nếu workflow trigger on push main |
| "Deploy dùng configuration nào?" | **Release** (theo yêu cầu đề) |

### D4. Git Workflow cho SQL Project

```bash
# Bước 1: Fetch latest từ remote
git fetch origin

# Bước 2: Merge main vào feature branch
git merge origin/main

# Bước 3: Tạo Pull Request bằng GitHub CLI
gh pr create \
  --title "Add new table" \
  --body "Description" \
  --head feature/add-table \
  --base main
```

| Lệnh | Mục đích |
|---|---|
| `git fetch origin` | Lấy thông tin mới nhất từ remote (KHÔNG merge) |
| `git merge origin/main` | Merge remote main vào local branch |
| `gh pr create` | Tạo Pull Request trên GitHub |
| `git pull` | = `git fetch` + `git merge` (nhưng đề thường tách) |

---

## PHẦN E — MICROSOFT FABRIC SQL DATABASE

---

### E1. Fabric SQL Database là gì?

Fabric SQL Database là phiên bản SQL Database chạy trong **Microsoft Fabric workspace**.
Nó hỗ trợ hầu hết tính năng của Azure SQL Database, bao gồm:

- T-SQL đầy đủ
- Hàm regex (REGEXP_*)
- Vector search
- GraphQL API qua Fabric

### E2. Fabric-specific: GraphQL API Permissions

```
┌─────────────────────────────────────────────────┐
│ Fabric Workspace                                 │
│  ┌──────────────┐    ┌──────────────────────┐   │
│  │ SQL Database  │    │ API for GraphQL      │   │
│  │ (SalesDB)    │    │ (SalesApi)           │   │
│  └──────────────┘    └──────────────────────┘   │
│                                                   │
│  Workspace roles: Viewer, Contributor, Admin     │
│  API permissions: separate from workspace roles  │
└─────────────────────────────────────────────────┘
```

#### Bảng permission Fabric GraphQL

| Permission | Cho phép |
|---|---|
| "Run Queries and Mutations" (checked) | Đọc VÀ ghi dữ liệu qua API |
| "Run Queries and Mutations" (unchecked) | ❌ KHÔNG đọc, KHÔNG ghi qua API |
| "View and Edit GraphQL item" (checked) | Sửa cấu trúc API (field mappings, schema) |
| Workspace "Viewer" role | Chỉ xem workspace — **KHÔNG** tự động cấp quyền API |

> 🎯 **Bẫy đề thi:**
> - Viewer role ≠ quyền đọc qua GraphQL API
> - Phải có **"Run Queries and Mutations"** mới đọc/ghi được qua API
> - "View and Edit" cho phép sửa **cấu hình** API, không phải dữ liệu

---

## PHẦN F — BLOCKING CHAIN & TRANSACTION TROUBLESHOOTING

---

### F1. Phân tích Blocking Chain bằng DMV

Khi users report "queries bị timeout", bạn cần kiểm tra blocking chain:

```sql
-- Truy vấn chẩn đoán blocking
SELECT
    s.session_id,
    s.status,
    s.open_transaction_count,
    r.blocking_session_id,
    r.wait_type,
    r.wait_time,
    t.text AS sql_text,
    ib.event_info AS last_input
FROM sys.dm_exec_sessions s
LEFT OUTER JOIN sys.dm_exec_requests r
    ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t
OUTER APPLY sys.dm_exec_input_buffer(s.session_id, NULL) ib
WHERE s.session_id IN (
    -- Sessions đang bị block hoặc đang block người khác
    SELECT blocking_session_id FROM sys.dm_exec_requests
    WHERE blocking_session_id <> 0
    UNION
    SELECT session_id FROM sys.dm_exec_requests
    WHERE blocking_session_id <> 0
);
```

### F2. Tại sao dùng LEFT OUTER JOIN và OUTER APPLY?

| Operator | Lý do |
|---|---|
| `LEFT OUTER JOIN sys.dm_exec_requests` | Session "sleeping" **không có** active request → INNER JOIN sẽ bỏ sót |
| `OUTER APPLY sys.dm_exec_sql_text` | Nếu không có sql_handle → vẫn giữ row |
| `OUTER APPLY sys.dm_exec_input_buffer` | Lấy câu lệnh cuối cùng client gửi |

### F3. Bảng chẩn đoán — "Nguyên nhân blocking là gì?"

| Triệu chứng | Nguyên nhân | Giải pháp |
|---|---|---|
| `status = 'sleeping'` + `open_transaction_count = 1` | **Transaction mở nhưng chưa COMMIT/ROLLBACK** | Terminate session hoặc fix app code |
| Nhiều session chờ cùng 1 session | **Explicit transaction** giữ lock | Tìm và fix code chưa commit |
| Deadlock (cycle 2+ sessions) | SQL tự detect trong vài giây | Check deadlock graph, fix access order |
| Lock escalation | Quá nhiều row/page locks → table lock | Optimize query, dùng ROWLOCK hint |

> 🎯 **Câu hỏi đề thi phổ biến:**
> "Session 72 sleeping, open_transaction_count = 1, nhiều session bị block bởi 72."
> → **Đáp án: Explicit transaction mở nhưng chưa commit/rollback.**
> KHÔNG phải deadlock (SQL tự giải quyết), KHÔNG phải SELECT blocking (RCSI ngăn),
> KHÔNG phải lock escalation (triệu chứng khác).

---

## PHẦN G — TRANSACTION ISOLATION LEVELS

---

### G1. Bảng so sánh

| Level | Dirty Read | Non-repeatable Read | Phantom | Đặc điểm |
|---|---|---|---|---|
| READ UNCOMMITTED | ✅ Có thể | ✅ Có thể | ✅ Có thể | Nhanh nhất, rủi ro nhất |
| READ COMMITTED | ❌ Chặn | ✅ Có thể | ✅ Có thể | Mặc định SQL Server |
| **REPEATABLE READ** | ❌ Chặn | ❌ Chặn | ✅ Có thể | Dữ liệu đã đọc KHÔNG bị sửa |
| **SERIALIZABLE** | ❌ Chặn | ❌ Chặn | ❌ Chặn | Chặn hoàn toàn, chậm nhất |
| SNAPSHOT | ❌ Chặn | ❌ Chặn | ❌ Chặn | Row versioning, không lock |
| READ COMMITTED SNAPSHOT (RCSI) | ❌ Chặn | ✅ Có thể | ✅ Có thể | Row versioning, mặc định Azure SQL |

### G2. Khi nào dùng cái nào? (Đề thi)

| Yêu cầu đề bài | Isolation Level |
|---|---|
| "Dữ liệu **KHÔNG được thay đổi** bởi transaction khác trong khi SP chạy" | **REPEATABLE READ** |
| "Chặn hoàn toàn mọi thay đổi kể cả phantom reads" | **SERIALIZABLE** |
| "Đọc không block ghi, ghi không block đọc" | **SNAPSHOT** hoặc **RCSI** |
| "Mặc định Azure SQL Database" | **RCSI** (Read Committed Snapshot Isolation) |

---

## PHẦN H — QUERY STORE & PLAN REGRESSION

---

### H1. Khi có Plan Regression — Chọn lệnh nào?

| Lệnh | Mục đích | Khi nào dùng |
|---|---|---|
| `sp_query_store_force_plan` | Ép dùng plan cũ (tốt) | ✅ Plan regression — đáp án đúng nhất |
| `sp_query_store_set_hints` | Thêm query hint | Cần tinh chỉnh, không khẩn cấp |
| `DBCC FREEPROCCACHE` | Xoá toàn bộ plan cache | ❌ Có thể tạo lại plan xấu + ảnh hưởng global |
| `ALTER DATABASE` | Sửa cấu hình DB | Quá rộng, không nhắm trúng vấn đề |

### H2. Covering Index để loại bỏ Key Lookup

Khi execution plan cho thấy **Key Lookup** → tạo covering index:

```sql
-- Đề thi: Query filter bằng CustomerId, sort bằng OrderDate DESC
-- Key Lookup lấy Status, TotalAmount
CREATE NONCLUSTERED INDEX IX_Orders_CustDate
ON dbo.Orders (CustomerId, OrderDate DESC)
INCLUDE (Status, TotalAmount);
```

| Thành phần index | Vai trò |
|---|---|
| **Key column:** CustomerId | Index Seek thay vì Scan |
| **Key column:** OrderDate DESC | Loại bỏ Sort operator (pre-sorted) |
| **INCLUDE:** Status, TotalAmount | Loại bỏ Key Lookup (covering) |

> ⚠️ **Bẫy đề thi:** CustomerId đặt vào **INCLUDE** thay vì **KEY** column
> → KHÔNG loại bỏ được Sort, vì INCLUDE không tham gia vào thứ tự sắp xếp B-tree.

---

## PHẦN I — EMBEDDING MAINTENANCE

---

### I1. Khi nào dùng phương pháp nào?

| Phương pháp | Khi nào | Ưu điểm | Nhược điểm |
|---|---|---|---|
| **Change Tracking + external app** | Cần detect thay đổi, offload xử lý | CPU thấp trên DB | Cần thêm component |
| **CDC + Azure Functions** | Cần chi tiết before/after + offload | Near real-time, minimal DB CPU | Phức tạp hơn CT |
| **DML Trigger + AI call** | Cần instant update | Real-time | ❌ CPU spike, blocks transactions |
| **Nightly batch job** | Dữ liệu ít thay đổi | Đơn giản | ❌ Stale data đến 24h |

> 🎯 **Mẹo thi:**
> - "Minimize CPU on SalesDB" → CDC + Azure Functions (offload)
> - "Updated every time content changes" → Change Tracking (detect changes)
> - "Must NOT require nightly batch" → Change Tracking HOẶC CDC

---

## PHẦN J — ONNX RUNTIME & LOCAL MODEL

---

### J1. SQL Server 2025 — External Model Project

Khi SQL Server **không có kết nối internet** (isolated):

```sql
-- Tạo external model từ file ONNX local
CREATE EXTERNAL MODEL [EmbeddingModel]
WITH (ONNX, LOCATION = 'C:\Models\minilm.onnx');

-- Cấp quyền EXECUTE cho user cụ thể
GRANT EXECUTE ON EXTERNAL MODEL::[EmbeddingModel]
TO [AIApplicationUser];
```

| Yêu cầu | Giải pháp |
|---|---|
| Không có internet | ONNX Runtime + local file path |
| Chỉ 1 user được chạy model | GRANT EXECUTE ON EXTERNAL MODEL |
| Principle of least privilege | ❌ KHÔNG dùng CONTROL permission |

---

## CÂU HỎI TỰ KIỂM TRA (15 CÂU)

### Câu 1
Bạn triển khai DAB trên Azure Container Apps. Connection string lưu trong secret `MSSQL_CONNECTION_STRING`.
Cách nào khởi tạo DAB đúng?

A. `--connection-string "secretref:MSSQL_CONNECTION_STRING"`
B. `--connection-string "@env('MSSQL_CONNECTION_STRING')"`
C. `--connection-string "secretref:mssql-connection-string"`
D. `--connection-string "@env('DAB_CONFIG_BASE64')"`

**Đáp án: B** — DAB CLI dùng `@env()`, không phải `secretref:`.

---

### Câu 2
Bạn cần cấu hình Azure Functions SQL trigger. 2 cấu hình **database** nào cần thiết?

A. Tạo DML trigger + Set MaxBatchSize
B. Bật CDC ở DB và table level
C. Bật Change Tracking ở DB level + Table level
D. Set PollingIntervalMs + MaxBatchSize

**Đáp án: C** — Change Tracking ở cả DB và table. MaxBatchSize/PollingInterval là app settings.

---

### Câu 3
GitHub Copilot Chat trong SSMS chạy query bằng quyền nào?

A. Sandbox read-only riêng
B. Quyền database của developer hiện tại
C. Client-side filtering
D. RLS policy riêng

**Đáp án: B** — Copilot dùng identity và permissions của developer.

---

### Câu 4
Bạn muốn disable Copilot repository instructions **chỉ cho mình**. Làm gì?

A. Xoá `.github/copilot-instructions.md`
B. Sửa User Settings trong VS Code
C. Thêm flag `--debug`

**Đáp án: B** — User Settings chỉ ảnh hưởng bản thân bạn.

---

### Câu 5
MCP server cần scope to repository trong VS Code. Lưu ở đâu?

A. User settings   B. Workspace settings   C. `.github/mcp.json`   D. `.vs/settings.json`

**Đáp án: B** — Workspace settings = scoped to repository.

---

### Câu 6
Visual Studio (KHÔNG phải VS Code) cần MCP server. Tạo file nào?

A. `.vscode/settings.json`   B. `.mcp.json`   C. `.vs/settings.json`   D. `.github/mcp.json`

**Đáp án: B** — Visual Studio dùng `.mcp.json` ở root.

---

### Câu 7
SQL Graph: tìm người cách 2 hop từ @StartPersonId. Cú pháp MATCH nào đúng?

A. `MATCH(p1-(k1)->p2) AND MATCH(p2-(k2)->p3)`
B. `MATCH(p3-(k2)->p2-(k1)->p1)`
C. `MATCH(p1-(k1)->p2-(k2)->p3)`
D. Không cần WHERE filter @StartPersonId

**Đáp án: C** — Chain phải nằm trong MỘT MATCH(), hướng đúng từ p1 ra.

---

### Câu 8
Session 72 sleeping, open_transaction_count = 1, nhiều session blocked by 72.
Nguyên nhân gì?

A. Long-running SELECT   B. Deadlock   C. Explicit transaction chưa commit   D. Lock escalation

**Đáp án: C** — sleeping + open_transaction = transaction mở nhưng chưa commit/rollback.

---

### Câu 9
Query Store thấy plan mới chậm hơn plan cũ. Cách nhanh nhất khôi phục?

A. `DBCC FREEPROCCACHE`   B. `sp_query_store_force_plan`
C. `sp_query_store_set_hints`   D. `ALTER DATABASE`

**Đáp án: B** — Force plan cũ (tốt) ngay lập tức.

---

### Câu 10
SQL Server 2025 không có internet. Cần tạo embedding. 2 bước nào?

A. CONTROL permission + REST endpoint
B. EXECUTE permission + ONNX local model
C. db_owner + Azure OpenAI endpoint
D. EXECUTE permission + Azure AI Foundry

**Đáp án: B** — Không có internet → ONNX local. Least privilege → GRANT EXECUTE.

---

### Câu 11
Dữ liệu 2 triệu articles thay đổi thường xuyên. Embedding stale 1 ngày. Minimize CPU trên DB.

A. VECTOR_DISTANCE thay VECTOR_SEARCH
B. CDC + Azure Functions
C. Hourly T-SQL job
D. DML trigger + AI_GENERATE_EMBEDDINGS

**Đáp án: B** — CDC + offload embedding generation ra Azure Functions.

---

### Câu 12
App kết nối passwordless đến Azure SQL. Traffic phải ở trong subscription. 2 giải pháp?

A. SQL login + Key Vault rotation
B. Managed Identity + Entra ID authentication
C. Private Endpoint + disable public access
D. VNet firewall rules chỉ cho IP

**Đáp án: B, C** — Managed Identity = passwordless, Private Endpoint = in-subscription traffic.

---

### Câu 13
sp_UpdateProcedureForPatient: dữ liệu KHÔNG được thay đổi bởi transaction khác khi SP chạy.
Transaction level nào?

A. REPEATABLE READ   B. SERIALIZABLE   C. SNAPSHOT   D. READ COMMITTED SNAPSHOT

**Đáp án: A** — REPEATABLE READ ngăn dữ liệu đã đọc bị sửa.

---

### Câu 14
Fabric GraphQL API: SqlUsers có "View and Edit GraphQL item" nhưng KHÔNG có "Run Queries and Mutations".
SqlUsers có đọc được data qua API không?

A. Có   B. Không

**Đáp án: B** — Cần "Run Queries and Mutations" để đọc/ghi qua API.

---

### Câu 15
Bạn cần tạo credential gọi Azure OpenAI từ T-SQL. Yêu cầu "highest security". Chọn gì?

A. API Key trong SECRET
B. Managed Identity + resourceid
C. Bearer token trong HTTPEndpointHeaders
D. Hardcode connection string

**Đáp án: B** — Managed Identity = highest security, không có secret cần rotate.

---

## TÓM TẮT — CHEAT SHEET NGÀY THI

```
┌──────────────────────────────────────────────────────┐
│  DAB: @env('VAR_NAME') — KHÔNG dùng secretref:       │
│  SQL Trigger: Change Tracking (DB + Table)            │
│  Batch/Polling: App settings, KHÔNG phải DB config    │
│  Copilot: dùng dev permissions, không có sandbox      │
│  MCP VS Code: workspace settings = repo-scoped        │
│  MCP Visual Studio: .mcp.json ở root                  │
│  Graph MATCH: chain trong MỘT MATCH(), hướng đúng     │
│  Blocking: sleeping + open_transaction = chưa commit   │
│  Plan regression: sp_query_store_force_plan            │
│  Passwordless: Managed Identity + Entra ID             │
│  No internet: ONNX local + GRANT EXECUTE on model      │
│  Minimize CPU embedding: CDC + Azure Functions          │
│  REPEATABLE READ: ngăn sửa dữ liệu đã đọc             │
│  Fabric GraphQL: "Run Queries" ≠ Workspace Viewer role │
└──────────────────────────────────────────────────────┘
```
