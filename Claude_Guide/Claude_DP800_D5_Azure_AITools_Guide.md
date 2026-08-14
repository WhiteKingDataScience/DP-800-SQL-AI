# DP-800 — BỔ SUNG: AZURE INTEGRATION, AI-ASSISTED TOOLS & CÁC CHỦ ĐỀ THIẾU

> **Mục tiêu:** biến các phần cloud/AI dễ nhầm của DP-800 thành decision rules có thể dùng ngay khi làm scenario.
>
> **Cập nhật:** 14/08/2026  
> **Blueprint:** DP-800 — Skills measured as of March 12, 2026.
>
> Nguồn chính:
> - [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
> - [Data API builder](https://learn.microsoft.com/en-us/azure/data-api-builder/)
> - [DAB 2.0 — What's new](https://learn.microsoft.com/en-us/azure/data-api-builder/whats-new/version-2-0)
> - [SQL MCP Server](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/overview)
> - [Azure Functions SQL trigger](https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-azure-sql-trigger)
> - [Change Event Streaming](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/overview?view=sql-server-ver17)
> - [GitHub Copilot in SSMS](https://learn.microsoft.com/en-us/ssms/github-copilot/overview)

---

# 0. BỐN HỘP AZURE CẦN NHỚ

Đừng học Azure như danh sách hàng chục dịch vụ. Với DP-800, hãy gom scenario vào 4 hộp:

```text
1. API
   → Data API builder (DAB)

2. Monitoring
   → Azure Monitor
   → Application Insights
   → Log Analytics

3. Data changes / events
   → Change Tracking
   → CDC
   → Azure Functions SQL trigger
   → CES
   → Logic Apps

4. Identity / security
   → Microsoft Entra ID
   → Managed Identity
```

Nếu chưa biết câu hỏi thuộc hộp nào, chưa nên nhìn đáp án.

---

# PHẦN A — DATA API BUILDER (DAB) 2.0

## A1. DAB giải quyết gì?

DAB tạo **REST**, **GraphQL** và **MCP** surface trên database mà không cần tự viết CRUD backend.

```text
Client / App / AI Agent
          ↓
   REST / GraphQL / MCP
          ↓
    Data API builder
          ↓
SQL Server / Azure SQL / ...
```

**Exam trigger:**
- "Expose SQL as REST/GraphQL";
- "minimal custom backend";
- "table/view/stored procedure through API";
- "database relationships through GraphQL".

→ nghĩ **DAB**.

DAB 2.0 đã GA từ June 2026.

---

## A2. Cấu hình tối thiểu

```json
{
  "$schema": "https://github.com/Azure/data-api-builder/releases/latest/download/dab.draft.schema.json",
  "data-source": {
    "database-type": "mssql",
    "connection-string": "@env('MSSQL_CONNECTION_STRING')"
  },
  "runtime": {
    "rest": { "enabled": true },
    "graphql": { "enabled": true },
    "mcp": { "enabled": true }
  },
  "entities": {
    "Orders": {
      "source": {
        "type": "table",
        "object": "dbo.Orders"
      },
      "permissions": [
        {
          "role": "authenticated",
          "actions": ["read"]
        }
      ]
    }
  }
}
```

Không hardcode password trong config/Git.

---

## A3. CLI workflow

```bash
dab init \
  --database-type mssql \
  --connection-string "@env('MSSQL_CONNECTION_STRING')"

dab add Orders \
  --source dbo.Orders \
  --permissions "authenticated:read"

dab start
```

Kiểm tra config:

```bash
dab validate
```

---

## A4. Tables, views và stored procedures

### Table

```bash
dab add Orders \
  --source dbo.Orders \
  --source.type table \
  --permissions "authenticated:read,create,update"
```

### View

```bash
dab add ActiveOrders \
  --source dbo.vw_ActiveOrders \
  --source.type view \
  --permissions "authenticated:read"
```

### Stored procedure

```bash
dab add GetOrderSummary \
  --source dbo.usp_GetOrderSummary \
  --source.type stored-procedure \
  --permissions "authenticated:execute"
```

**Exam:** stored procedure không phải CRUD table; permission cần nhận diện `execute`.

---

## A5. REST filtering / sorting / projection / pagination

Các query operators quan trọng:

```text
$filter
$orderby
$select
$first
$after
```

Ví dụ:

```http
GET /api/Orders?$filter=Status eq 'Open'&$orderby=OrderDate desc&$first=20
```

### Pagination hiện hành

Trang đầu:

```http
GET /api/Orders?$first=20
```

Response trả continuation/next link. Trang sau dùng token:

```http
GET /api/Orders?$first=20&$after=<continuation-token>
```

**Không học `$skip/$top` như DAB REST pagination hiện hành.**

DAB dùng keyset/continuation pagination với `$first` + `$after`.

---

## A6. GraphQL relationships

Ví dụ relationship:

```json
{
  "entities": {
    "Customers": {
      "source": {
        "type": "table",
        "object": "dbo.Customers"
      },
      "relationships": {
        "orders": {
          "cardinality": "many",
          "target.entity": "Orders",
          "source.fields": ["CustomerId"],
          "target.fields": ["CustomerId"]
        }
      }
    }
  }
}
```

Mental model:

```text
FK / relationship
      ↓
DAB relationship config
      ↓
GraphQL nested query
```

Nếu đề muốn một request trả Customer và related Orders → GraphQL relationship là ứng viên mạnh.

---

## A7. DAB caching

DAB hỗ trợ cache để giảm query lặp lại.

Mental model:
- **L1** = in-memory;
- **L2** = distributed cache/Redis trong các cấu hình hỗ trợ;
- cache giảm latency/load nhưng tạo trade-off về freshness.

**Exam:** nếu dữ liệu thay đổi liên tục và phải luôn fresh, đừng mặc định cache là tốt nhất.

---

## A8. DAB authentication vs authorization

Authentication trả lời:

> "Bạn là ai?"

Authorization trả lời:

> "Role này được làm gì với entity?"

Không nhầm DAB role permission với database permission. Hai lớp đều quan trọng:

```text
Identity/token
    ↓
DAB authentication
    ↓
DAB role/entity permission
    ↓
Database identity/permission
```

**Least privilege ở cả hai lớp.**

---

# PHẦN B — SQL MCP SERVER (DAB 2.0)

## B1. MCP trong DP-800

MCP cho phép AI agent gọi tools/data source theo protocol chuẩn.

Trong SQL MCP Server hiện hành, DAB là runtime cung cấp MCP endpoint/tools.

```text
Copilot / Agent
      ↓ MCP
SQL MCP Server (DAB)
      ↓
tables / views / stored procedures
      ↓
SQL permission + DAB RBAC
```

---

## B2. Enable MCP

```bash
dab configure --runtime.mcp.enabled true
```

Concept config:

```json
{
  "runtime": {
    "mcp": {
      "enabled": true
    }
  }
}
```

Tables/views tham gia qua DML tools theo config. Có thể disable MCP/DML tool cho entity nhạy cảm.

---

## B3. Stored procedure thành custom MCP tool

```bash
dab add GetOrderById \
  --source dbo.usp_GetOrderById \
  --source.type stored-procedure \
  --permissions "authenticated:execute" \
  --mcp.custom-tool true
```

Concept:

```json
{
  "GetOrderById": {
    "source": {
      "type": "stored-procedure",
      "object": "dbo.usp_GetOrderById"
    },
    "mcp": {
      "custom-tool": true
    },
    "permissions": [
      {
        "role": "authenticated",
        "actions": ["execute"]
      }
    ]
  }
}
```

**Security rule:** tool xuất hiện với agent không có nghĩa agent được phép vượt database/DAB authorization.

---

# PHẦN C — GITHUB COPILOT / AGENT / INSTRUCTIONS

## C1. Không coi Copilot là security boundary

AI-generated SQL phải:
- review;
- test;
- chạy bằng identity/permission thực;
- không được tin chỉ vì "Copilot generated".

Copilot không tự thay RLS/GRANT/DENY.

---

## C2. Instructions

Repository instructions:

```text
.github/copilot-instructions.md
```

Dùng để truyền conventions/context cho Copilot, ví dụ:

```markdown
# SQL rules
- Always use schema-qualified names.
- Prefer THROW over RAISERROR for new code.
- Never generate destructive statements without explicit warning.
```

**Instruction ≠ permission.**

Một instruction "chỉ SELECT" không thể thay quyền read-only thật ở SQL.

---

## C3. Ask mode vs Agent mode

Mental model:

```text
Ask
→ trả lời / đề xuất

Agent
→ có thể dùng tools để thực hiện nhiều bước
```

Vì Agent có khả năng gọi tools, hãy kiểm soát:
- MCP tool surface;
- identity;
- approval;
- least privilege;
- review.

---

# PHẦN D — AZURE MONITOR / APP INSIGHTS / LOG ANALYTICS

## D1. Chọn đúng thành phần

| Requirement | Nghĩ tới |
|---|---|
| request latency, exceptions, dependencies | **Application Insights** |
| centralized logs + KQL across resources | **Log Analytics Workspace** |
| metric/log alert + notification/action | **Azure Monitor alert rule + action group** |

Mental model:

```text
Application / DAB / Azure resource
              ↓ telemetry
          Azure Monitor
           /        \
Application Insights  Log Analytics
```

---

## D2. KQL sample — App Insights

```kusto
requests
| where timestamp > ago(24h)
| summarize
    Count = count(),
    AvgDuration = avg(duration),
    Failures = countif(success == false)
```

SQL dependencies:

```kusto
dependencies
| where type == "SQL"
| summarize
    Calls = count(),
    AvgDuration = avg(duration),
    Failures = countif(success == false)
  by data
| top 20 by AvgDuration desc
```

---

# PHẦN E — DATA CHANGE DECISION MATRIX

## E1. Bảng phải thuộc

| Requirement | Công nghệ |
|---|---|
| Biết row/key nào đổi để sync | **Change Tracking (CT)** |
| Cần detailed change history / before-after cho ETL | **CDC** |
| SQL row đổi → chạy serverless code | **Azure Functions SQL trigger** |
| Stream DML change events gần realtime tới Event Hubs | **CES** |
| Low-code workflow/orchestration | **Logic Apps** |

Không học một keyword tuyệt đối kiểu "minimize CPU = luôn CDC". Hãy đọc toàn bộ requirement.

---

## E2. Change Tracking

Enable database:

```sql
ALTER DATABASE CURRENT
SET CHANGE_TRACKING = ON
(
    CHANGE_RETENTION = 2 DAYS,
    AUTO_CLEANUP = ON
);
GO
```

Enable table:

```sql
ALTER TABLE dbo.Orders
ENABLE CHANGE_TRACKING;
GO
```

Consumer:

```sql
DECLARE @last_sync_version bigint = 0;
DECLARE @current_version bigint =
    CHANGE_TRACKING_CURRENT_VERSION();

SELECT
    CT.OrderId,
    CT.SYS_CHANGE_VERSION,
    CT.SYS_CHANGE_OPERATION,
    O.Status,
    O.Amount
FROM CHANGETABLE
(
    CHANGES dbo.Orders,
    @last_sync_version
) AS CT
LEFT JOIN dbo.Orders AS O
  ON O.OrderId = CT.OrderId
WHERE CT.SYS_CHANGE_VERSION <= @current_version;
```

Vì row delete không còn trong base table nên thường cần `LEFT JOIN`.

CT không phải full old/new history.

---

## E3. CDC

```sql
EXEC sys.sp_cdc_enable_db;
GO

EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name = N'Orders',
    @role_name = NULL,
    @supports_net_changes = 1;
GO
```

Query:

```sql
DECLARE @from_lsn binary(10),
        @to_lsn binary(10);

SET @from_lsn =
    sys.fn_cdc_get_min_lsn('dbo_Orders');

SET @to_lsn =
    sys.fn_cdc_get_max_lsn();

SELECT *
FROM cdc.fn_cdc_get_all_changes_dbo_Orders
(
    @from_lsn,
    @to_lsn,
    N'all update old'
);
```

`all update old` giúp thấy before/after image cho update theo semantics CDC.

---

## E4. Azure Functions SQL trigger

**Bẫy bắt buộc nhớ:** Azure Functions SQL Trigger dựa trên **Change Tracking**, không phải CDC.

Database/table phải bật CT.

Concept C# isolated worker:

```csharp
[Function("OrderChanged")]
public void Run(
    [SqlTrigger("[dbo].[Orders]", "SqlConnectionString")]
    IReadOnlyList<SqlChange<Order>> changes)
{
    foreach (var change in changes)
    {
        // xử lý I/U/D
    }
}
```

Đây là serverless reaction pattern. Extension xử lý polling/state nội bộ; bạn không tự viết polling loop.

---

## E5. CES — Change Event Streaming

CES là Preview và current Microsoft docs liệt kê nguồn:
- SQL Server 2025;
- Azure SQL Database;
- Azure SQL Managed Instance (policy phù hợp).

CES đọc transaction log và stream DML changes gần real time đến **Azure Event Hubs** dưới CloudEvents.

Mental model:

```text
INSERT/UPDATE/DELETE
       ↓ transaction log
      CES
       ↓
Azure Event Hubs
       ↓
consumers
```

Use when:
- high-throughput/near-real-time event stream;
- downstream event-driven systems;
- không muốn consumer polling database change table.

Không phải history store như CDC.

**Platform trap:** đừng suy diễn rằng "Fabric Eventstream tồn tại" đồng nghĩa SQL database in Fabric chắc chắn là nguồn CES. Luôn đọc `Applies to` của CES đúng ngày thi.

Nguồn:
[CES overview](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/overview?view=sql-server-ver17)

---

## E6. Logic Apps

Chọn khi requirement nhấn mạnh:
- low-code/no-code workflow;
- connectors;
- orchestration giữa SQL và nhiều SaaS/services;
- approvals/business process.

Nếu yêu cầu "run C# serverless code when row changes" → Functions phù hợp hơn.

---

# PHẦN F — MANAGED IDENTITY / PASSWORDLESS

## F1. Mental model

```text
Azure resource identity
       ↓ Entra token
Azure SQL
       ↓ CREATE USER ... FROM EXTERNAL PROVIDER
DB permissions
```

Example:

```sql
CREATE USER [orders-api-mi]
FROM EXTERNAL PROVIDER;
GO

GRANT SELECT, INSERT, UPDATE
ON dbo.Orders
TO [orders-api-mi];
GO
```

Connection concept:

```text
Authentication=Active Directory Default;
```

**Managed Identity không tự cấp database permission.**

---

# PHẦN G — CI/CD DELTA CẦN NHỚ

## G1. Core pipeline

```text
.sql files
   ↓
SDK-style SQL project
   ↓ dotnet build
.dacpac
   ↓ preview
DeployReport / Script
   ↓
approval
   ↓
Publish
```

### Decision table

| Scenario | Chọn |
|---|---|
| Validate model + produce dacpac | `dotnet build` |
| What would change if deployed? | `DeployReport` / `Script` |
| Actually deploy | `Publish` |
| Ad-hoc drift on registered DAC | `DriftReport` |
| Generic project/live comparison | Schema Compare / Extract + compare |
| Passwordless GitHub → Azure | OIDC/federated identity |
| SQL files require DBA reviewer | `CODEOWNERS` + required reviewers |

**Sửa overclaim cũ:** deployment tooling vẫn có validation/safety checks; không nên học câu "Deploy chỉ apply và không validate gì". Điểm thi quan trọng là **build validates project/model**, còn deployment compares source model với target và có deployment checks/options.

---

# PHẦN H — ONNX LOCAL MODEL: SYNTAX HIỆN HÀNH

Không dùng syntax cũ:

```sql
CREATE EXTERNAL MODEL X WITH (ONNX, LOCATION = '...');
```

Current developer-preview pattern của SQL Server 2025:

```sql
ALTER DATABASE SCOPED CONFIGURATION
SET PREVIEW_FEATURES = ON;
GO

EXECUTE sys.sp_configure
    'external AI runtimes enabled',
    1;
RECONFIGURE WITH OVERRIDE;
GO

CREATE EXTERNAL MODEL LocalEmbeddingModel
WITH
(
    LOCATION = 'C:\onnx_runtime\model\all-MiniLM-L6-v2-onnx',
    API_FORMAT = 'ONNX Runtime',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'allMiniLM',
    PARAMETERS = '{"valid":"JSON"}',
    LOCAL_RUNTIME_PATH = 'C:\onnx_runtime\'
);
GO
```

Đây là **Developer Preview**, không phải lựa chọn mặc định cho mọi scenario.

---

# PHẦN I — 20 SCENARIO QUESTIONS

### Câu 1
Expose table/view/SP qua REST và GraphQL, không muốn tự viết CRUD backend.

**Đáp án:** DAB.

### Câu 2
REST pagination DAB hiện hành?

**Đáp án:** `$first` + `$after`.

### Câu 3
GraphQL cần Customer chứa Orders nested.

**Đáp án:** DAB relationship.

### Câu 4
Request latency + dependency + exception.

**Đáp án:** Application Insights.

### Câu 5
Central logs và KQL nhiều Azure resources.

**Đáp án:** Log Analytics.

### Câu 6
Biết PK nào thay đổi kể từ version trước.

**Đáp án:** Change Tracking.

### Câu 7
Cần before/after detail cho ETL.

**Đáp án:** CDC.

### Câu 8
SQL change → run C# serverless.

**Đáp án:** Azure Functions SQL trigger.

### Câu 9
Functions SQL trigger dùng CDC?

**Đáp án:** Không. Dùng Change Tracking.

### Câu 10
High-throughput event stream → Event Hubs.

**Đáp án:** CES.

### Câu 11
Low-code multi-service workflow.

**Đáp án:** Logic Apps.

### Câu 12
Không lưu password khi app vào Azure SQL.

**Đáp án:** Managed Identity/Entra + DB user/permission.

### Câu 13
Instruction file nói "read-only", agent có thể UPDATE nếu DB identity có UPDATE?

**Đáp án:** Có thể. Instruction không phải security boundary.

### Câu 14
Muốn stored procedure thành named MCP tool.

**Đáp án:** `source.type=stored-procedure` + `mcp.custom-tool=true`.

### Câu 15
Muốn ngăn agent gọi một sensitive entity.

**Đáp án:** giới hạn MCP/entity config + RBAC/database permission, không chỉ prompt.

### Câu 16
Schema build artifact.

**Đáp án:** `.dacpac`.

### Câu 17
Generic source-vs-live drift.

**Đáp án:** Schema Compare/Extract + compare, không mặc định DriftReport.

### Câu 18
No internet SQL Server 2025, local embedding inference.

**Đáp án:** ONNX Runtime developer-preview pattern nếu environment đáp ứng prerequisites.

### Câu 19
DAB cache dùng cho data luôn phải fresh từng mili-giây?

**Đáp án:** Không mặc định; cache có freshness trade-off.

### Câu 20
CES source platform cần xác minh ở đâu?

**Đáp án:** current `Applies to`/limitations của CES, vì feature đang Preview.

---

# CHEAT SHEET

```text
REST/GraphQL SQL        → DAB
DAB pagination          → $first + $after
App telemetry           → Application Insights
Central logs/KQL        → Log Analytics
Row/key changed         → Change Tracking
Detailed history        → CDC
Run serverless code     → Functions SQL trigger
Stream to Event Hubs    → CES
Low-code workflow       → Logic Apps
Passwordless            → Managed Identity / Entra
AI agent → SQL          → SQL MCP Server (DAB)
Stored proc MCP tool    → custom-tool=true
Project artifact        → dacpac
Generic drift           → Schema Compare
Registered DAC drift    → DriftReport
```
