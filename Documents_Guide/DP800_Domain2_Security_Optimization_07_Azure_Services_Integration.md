# DP-800 Domain 2: Integrate SQL Solutions with Azure Services

> **Miền 2:** Secure, Optimize, and Deploy Database Solutions (35–40%)  
> **Chủ đề:** Integrate SQL solutions with Azure services  
> **Ưu tiên cá nhân:** **Score Weak Point #2**  
> **Blueprint:** DP-800 — Skills measured as of **March 12, 2026**  
> **Rà soát:** **12/08/2026**  
> **Mục tiêu:** Biến phần Azure Integration từ “nhớ tên dịch vụ” thành bài **requirement → technology → reason**.

> [!IMPORTANT]
> Đây là phần bạn nên ưu tiên hands-on nhiều nhất. Đừng học Azure lan man. DP-800 tập trung vào: **Data API builder (DAB), Azure Monitor, và các data-change/event patterns**.

---

# 1. PHẠM VI THI CHÍNH THỨC

Theo [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800), bạn phải có thể:

1. Create configuration files for **Data API builder (DAB)**.
2. Configure entities for **REST và GraphQL**, gồm caching, pagination, searching, filtering.
3. Configure REST hoặc GraphQL endpoints.
4. Expose database objects, stored procedures, views, gồm GraphQL relationships.
5. Configure và implement DAB deployment.
6. Recommend **Azure Monitor** configurations, gồm Application Insights và Log Analytics.
7. Handle changes bằng **CES, CDC, Change Tracking, Azure Functions SQL trigger, Logic Apps**.

---

# PHẦN A — AZURE INTEGRATION MENTAL MODEL

## 2. Chỉ cần 4 hộp

```text
1. API / expose SQL
   → Data API builder

2. Observe / diagnose
   → Azure Monitor
      ├─ Application Insights
      └─ Log Analytics

3. Detect/react to data changes
   → CT / CDC / Functions SQL Trigger / CES / Logic Apps

4. Authenticate securely
   → Microsoft Entra ID / Managed Identity / least privilege
```

Nếu đọc một câu Azure dài, hãy hỏi trước:

> **Business muốn làm gì với SQL?**

---

# PHẦN B — DATA API BUILDER (DAB)

Nguồn:
- [Data API builder docs](https://learn.microsoft.com/en-us/azure/data-api-builder/)
- [What's new in DAB 2.0](https://learn.microsoft.com/en-us/azure/data-api-builder/whats-new/version-2-0)
- [REST API overview](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/rest/overview)
- [Entities configuration](https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/entities)

## 3. DAB là gì?

DAB tạo REST/GraphQL API trên database objects mà không cần viết một backend CRUD đầy đủ.

```text
Client
  ↓
REST / GraphQL
  ↓
DAB
  ↓
Entities + permissions + mappings
  ↓
SQL table / view / stored procedure
```

### Exam keywords

- “Expose SQL through REST/GraphQL”
- “Minimal custom backend code”
- “Entity/relationship”
- “Stored procedure as endpoint”
- “Caching/pagination/filtering”

→ nghĩ **DAB**.

---

## 4. DAB 2.0

DAB 2.0 đã GA vào tháng 06/2026. Các điểm nên nhận diện:

- MCP/AI integration;
- auto-configuration/autoentities;
- simplified authentication defaults;
- telemetry/observability;
- cache L1/L2;
- improved REST/OpenAPI behavior.

**Không học thuộc version package nhỏ.** Học capability + current config schema.

---

# PHẦN C — DAB LAB TỪ ZERO

## 5. Tạo database objects

```sql
CREATE TABLE dbo.Customers
(
    CustomerId int IDENTITY PRIMARY KEY,
    FullName   nvarchar(200) NOT NULL,
    Email      nvarchar(320) NOT NULL
);
GO

CREATE TABLE dbo.Orders
(
    OrderId     int IDENTITY PRIMARY KEY,
    CustomerId  int NOT NULL,
    OrderDate   datetime2 NOT NULL DEFAULT sysutcdatetime(),
    Status      varchar(20) NOT NULL,
    TotalAmount decimal(19,2) NOT NULL,
    CONSTRAINT FK_Orders_Customers
        FOREIGN KEY(CustomerId)
        REFERENCES dbo.Customers(CustomerId)
);
GO

CREATE OR ALTER VIEW dbo.vw_OpenOrders
AS
SELECT OrderId, CustomerId, OrderDate, TotalAmount
FROM dbo.Orders
WHERE Status = 'Open';
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetOrderById
    @OrderId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT OrderId, CustomerId, OrderDate, Status, TotalAmount
    FROM dbo.Orders
    WHERE OrderId = @OrderId;
END;
GO
```

---

## 6. Cài DAB CLI

```bash
dotnet tool install --global Microsoft.DataApiBuilder
dab --version
```

Environment variable:

```text
DATABASE_CONNECTION_STRING=Server=localhost;Database=DP800Lab;Trusted_Connection=True;TrustServerCertificate=True
```

> Production: ưu tiên Managed Identity/approved secret store. Không commit connection string có password.

---

## 7. Init config

```bash
dab init \
  --database-type mssql \
  --connection-string "@env('DATABASE_CONNECTION_STRING')" \
  --host-mode Development \
  --config dab-config.json
```

Thêm entity:

```bash
dab add Customer \
  --source dbo.Customers \
  --permissions "anonymous:read"

dab add Order \
  --source dbo.Orders \
  --permissions "authenticated:create,read,update"

dab add OpenOrder \
  --source dbo.vw_OpenOrders \
  --source.type view \
  --permissions "authenticated:read"

dab add GetOrderById \
  --source dbo.usp_GetOrderById \
  --source.type stored-procedure \
  --permissions "authenticated:execute"
```

> CLI/options có thể thay đổi theo release; exam quan trọng hơn ở **table/view/SP → DAB entity → permission → API behavior**.

---

# PHẦN D — REST

## 8. REST endpoint mental model

```text
GET    /api/Customer
GET    /api/Order
POST   /api/Order
PATCH  /api/Order/<key>
DELETE /api/Order/<key>
```

### Current REST query options quan trọng

| Requirement | DAB REST |
|---|---|
| Project fields | `$select` |
| Filter | `$filter` |
| Sort | `$orderby` |
| Page size | `$first` |
| Continue page | `$after` |

Ví dụ:

```http
GET /api/Order?$filter=TotalAmount gt 100&$orderby=OrderDate desc&$first=20
```

Trang tiếp theo dùng continuation token:

```http
GET /api/Order?$first=20&$after=<opaque-token>
```

> **Bẫy:** DAB REST hiện dùng keyset/cursor-style pagination với `$first` + `$after`. Đừng học `$skip/$top` như pattern chính hiện hành.

Nguồn:
- [REST overview](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/rest/overview)
- [`$after`](https://learn.microsoft.com/en-us/azure/data-api-builder/keywords/after-rest)

---

# PHẦN E — GRAPHQL

## 9. GraphQL dùng khi nào?

- Client muốn query shape linh hoạt.
- Cần nested relationships.
- Muốn lấy Customer + Orders trong một query.

Mental model:

```text
Customer
   └── orders
        └── Order
```

Ví dụ concept:

```graphql
query {
  customers(first: 10) {
    items {
      CustomerId
      FullName
      orders(first: 5) {
        items {
          OrderId
          TotalAmount
        }
      }
    }
  }
}
```

## 10. Relationship

Trong DAB, relationship mô tả entity relationship để GraphQL có thể navigation giữa objects.

Exam clue:

> “Expose Customer and its related Orders through GraphQL.”

→ DAB entities + relationship.

---

# PHẦN F — STORED PROCEDURES VÀ VIEWS

## 11. View

View thường expose read-oriented shape.

```text
SQL View → DAB entity → REST/GraphQL read
```

## 12. Stored procedure

Use case:

- business logic đã có trong DB;
- muốn endpoint gọi operation có kiểm soát;
- không muốn rewrite SP thành app code.

```text
Stored procedure → DAB entity → execute / HTTP endpoint
```

DAB 2.0 còn có thể dùng stored procedure entity như custom MCP tool trong scenario AI agent.

---

# PHẦN G — DAB SECURITY

Nguồn: [Microsoft Entra ID authentication for DAB](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/security/authenticate-entra)

## 13. Hai authentication layers

```text
Client → DAB
        authentication/role
               ↓
DAB → Azure SQL
        Managed Identity / DB identity
```

Đừng nhầm:

- **client authentication**: ai gọi API?
- **database identity**: DAB kết nối SQL bằng ai?

### Good pattern

```text
Client → Entra token → DAB
DAB → Managed Identity → Azure SQL
```

Và database vẫn cấp least privilege cho Managed Identity.

---

# PHẦN H — DAB CACHING

## 14. Cache mental model

DAB 2.0 hỗ trợ:

- `L1`: in-memory trong process;
- `L1L2`: L1 + distributed L2 (Redis), phù hợp scale-out.

Ví dụ entity:

```json
{
  "entities": {
    "Product": {
      "source": {
        "type": "table",
        "object": "dbo.Products"
      },
      "cache": {
        "enabled": true,
        "ttl-seconds": 30,
        "level": "L1L2"
      }
    }
  }
}
```

### Khi dùng cache?

- read-heavy;
- dữ liệu không đổi quá nhanh;
- muốn giảm DB round trips.

### Bẫy

Cache không phải giải pháp cho mọi query. Nếu dữ liệu phải luôn cực mới, TTL/cache policy phải phù hợp.

---

# PHẦN I — DAB DEPLOYMENT

## 15. Hosting

Các lựa chọn thường gặp:

- Azure Container Apps;
- Azure App Service;
- container hosting phù hợp.

Container concept:

```dockerfile
FROM mcr.microsoft.com/azure-databases/data-api-builder:latest
COPY dab-config.json /App/dab-config.json
```

Production nên pin version/tag theo release policy.

## 16. Secrets

Không hardcode production secret trong `dab-config.json`.

Dùng:

- environment variables;
- Managed Identity;
- Key Vault/secret references phù hợp host.

---

# PHẦN J — AZURE MONITOR

Nguồn: [Microsoft Learn — Recommend Azure Monitor configurations](https://learn.microsoft.com/en-us/training/modules/integrate-sql-solutions-azure-services/6-recommend-azure-monitor-configurations)

## 17. Mental model

```text
Application / DAB / Azure SQL
          ↓ telemetry
      Azure Monitor
       /          \
Application      Log Analytics
Insights         Workspace
   ↓                 ↓
requests/         centralized logs
dependencies      KQL
exceptions
```

---

## 18. Application Insights

Chọn khi requirement nói:

- application/API requests;
- latency;
- dependency calls;
- exceptions;
- distributed tracing.

Ví dụ KQL:

```kusto
requests
| where timestamp > ago(24h)
| summarize
    Count = count(),
    AvgDuration = avg(duration),
    P95 = percentile(duration, 95),
    Failures = countif(success == false)
```

SQL dependencies:

```kusto
dependencies
| where timestamp > ago(1h)
| where type == "SQL"
| summarize
    Calls = count(),
    AvgDuration = avg(duration),
    Failures = countif(success == false)
  by data
| top 20 by AvgDuration desc
```

---

## 19. Log Analytics

Chọn khi:

- centralized logs;
- query logs across Azure resources;
- KQL analytics;
- operational troubleshooting.

Exam clue:

> “Query centralized diagnostic logs with KQL.”

→ **Log Analytics workspace**.

---

## 20. Alerts

Requirement:

> “Notify operations when error/latency exceeds threshold.”

→ Azure Monitor **alert rule + action group**.

---

# PHẦN K — HANDLE DATA CHANGES

## 21. Decision matrix phải thuộc

| Requirement | Chọn |
|---|---|
| Chỉ cần biết row/key nào thay đổi | **Change Tracking** |
| Cần change data/history/before-after cho ETL | **CDC** |
| Khi row đổi phải chạy serverless code | **Azure Functions SQL trigger** |
| Cần stream change events near-real-time | **CES** |
| Low-code workflow, connector nhiều dịch vụ | **Logic Apps** |

---

# PHẦN L — CHANGE TRACKING (CT)

Nguồn: [Change Tracking](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-tracking-sql-server?view=sql-server-ver17)

## 22. Enable CT

```sql
ALTER DATABASE DP800Lab
SET CHANGE_TRACKING = ON
(
    CHANGE_RETENTION = 2 DAYS,
    AUTO_CLEANUP = ON
);
GO

ALTER TABLE dbo.Orders
ENABLE CHANGE_TRACKING;
GO
```

## 23. Query changes

```sql
DECLARE @last_sync_version bigint = 0;

SELECT
    CT.OrderId,
    CT.SYS_CHANGE_VERSION,
    CT.SYS_CHANGE_OPERATION,
    O.CustomerId,
    O.Status
FROM CHANGETABLE(CHANGES dbo.Orders, @last_sync_version) AS CT
LEFT JOIN dbo.Orders AS O
  ON O.OrderId = CT.OrderId;
GO
```

### Cần nhớ

- lightweight;
- table cần primary key;
- trả changed key/version/operation;
- row delete không còn trong base table → thường `LEFT JOIN`;
- không phải full before/after history như CDC.

---

# PHẦN M — CDC

Nguồn: [Change Data Capture](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-data-capture-sql-server?view=sql-server-ver17)

## 24. Enable CDC

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

## 25. Query CDC

```sql
DECLARE @from_lsn binary(10),
        @to_lsn binary(10);

SET @from_lsn = sys.fn_cdc_get_min_lsn('dbo_Orders');
SET @to_lsn = sys.fn_cdc_get_max_lsn();

SELECT *
FROM cdc.fn_cdc_get_all_changes_dbo_Orders
(
    @from_lsn,
    @to_lsn,
    N'all update old'
);
GO
```

### Chọn CDC khi

- ETL/ELT;
- cần change rows;
- cần update before/after detail theo mode phù hợp;
- retention/history quan trọng.

---

# PHẦN N — AZURE FUNCTIONS SQL TRIGGER

Nguồn: [Azure SQL trigger for Functions](https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-azure-sql-trigger)

## 26. Trap quan trọng

> **Azure Functions SQL trigger sử dụng SQL Change Tracking.**

Nó dùng polling loop nội bộ; bạn không phải tự viết polling.

Vì vậy phải enable CT trên database + table.

## 27. C# isolated worker example

```csharp
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Extensions.Sql;
using Microsoft.Extensions.Logging;

public record Order(
    int OrderId,
    int CustomerId,
    string Status
);

public class OrderChanged
{
    private readonly ILogger<OrderChanged> _logger;

    public OrderChanged(ILogger<OrderChanged> logger)
    {
        _logger = logger;
    }

    [Function("OrderChanged")]
    public void Run(
        [SqlTrigger("[dbo].[Orders]", "SqlConnectionString")]
        IReadOnlyList<SqlChange<Order>> changes)
    {
        foreach (var change in changes)
        {
            _logger.LogInformation(
                "Operation={Operation}, OrderId={OrderId}",
                change.Operation,
                change.Item.OrderId
            );
        }
    }
}
```

> Microsoft hiện khuyến nghị isolated worker; support in-process model kết thúc 10/11/2026.

## 28. Permissions với Managed Identity

Trigger cần nhiều hơn `db_datareader`/`db_datawriter`.

```sql
CREATE USER [orders-function-mi] FROM EXTERNAL PROVIDER;
GO

GRANT CREATE TABLE TO [orders-function-mi];
GRANT CREATE SCHEMA TO [orders-function-mi];

GRANT SELECT ON dbo.Orders TO [orders-function-mi];
GRANT VIEW CHANGE TRACKING ON dbo.Orders TO [orders-function-mi];
GO

IF SCHEMA_ID(N'az_func') IS NULL
    EXEC(N'CREATE SCHEMA az_func AUTHORIZATION dbo;');
GO

GRANT ALTER ON SCHEMA::az_func TO [orders-function-mi];
GRANT SELECT, INSERT, UPDATE, DELETE
ON SCHEMA::az_func TO [orders-function-mi];
GO
```

---

# PHẦN O — CHANGE EVENT STREAMING (CES)

Nguồn:
- [CES overview](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/overview?view=sql-server-ver17)
- [Configure CES](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/configure?view=sql-server-ver17)
- [AMQP protocol deprecation](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/amqp-deprecation?view=sql-server-ver17)
- [Stream SQL changes to Fabric Eventstream](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/event-streams/stream-sql-change-events-to-eventstream)

## 29. CES là gì?

CES đọc data changes và stream near-real-time tới Azure Event Hubs. Events dùng CloudEvents, với JSON hoặc Avro Binary tùy cấu hình.

Use case:

- event-driven systems;
- near-real-time integration;
- push/streaming thay vì consumer polling change table.

## 30. Platform note — rất quan trọng

Microsoft documentation đang thay đổi nhanh:

- Trang CES **Overview/Configure** hiện liệt kê trực tiếp: **SQL Server 2025, Azure SQL Database, Azure SQL Managed Instance**.
- Một số trang liên quan, ví dụ AMQP deprecation, cũng nhắc **SQL database in Microsoft Fabric**.
- Fabric **Eventstream** có thể đóng vai trò destination/custom endpoint cho SQL change events.

### Exam strategy

1. Nếu đề nêu platform cụ thể, chỉ chọn capability được hỗ trợ cho platform đó trong wording/docs hiện hành.
2. Không suy diễn “Fabric Eventstream là destination” = “mọi Fabric SQL surface đều là CES source”.
3. Với Preview feature, đọc `Applies to`/limitations nếu có quyền tra Microsoft Learn trong exam.

## 31. CES vs CDC

```text
CDC
  → change tables/functions
  → consumer đọc/pull
  → ETL/history-oriented

CES
  → near-real-time event stream
  → Azure Event Hubs / Eventstream destination
  → event-driven integration
```

## 32. Delivery semantics

CES là **at least once** → downstream consumer phải idempotent/deduplicate nếu cần.

CES là stream, không phải một history store vô hạn.

---

## 33. Breaking change ngày 15/08/2026

Từ **15/08/2026**, Microsoft yêu cầu **new stream groups** dùng:

```text
@destination_type = 'AzureEventHubs'
```

Hai value cũ:

```text
AzureEventHubsAMQP
AzureEventHubsApacheKafka
```

sẽ fail cho stream group mới.

Kafka publisher dùng port `9093`.

### Trước ngày 15/08/2026

Repo/lab cũ có thể vẫn thấy:

```text
AzureEventHubsApacheKafka
```

### Từ ngày 15/08/2026

Dùng:

```text
AzureEventHubs
```

> Tài liệu này được rà soát ngày **12/08/2026**, ba ngày trước breaking change. Nếu bạn chạy lab sau 15/08, dùng syntax mới và kiểm tra trang deprecation/configure.

---

## 34. CES lab concept — syntax sau 15/08/2026

```sql
-- SQL Server 2025: cần FULL recovery + PREVIEW_FEATURES.
-- Azure SQL/MI có platform-specific behavior; đọc docs.

CREATE DATABASE SCOPED CREDENTIAL CesEventHubsMI
WITH IDENTITY = 'Managed Identity';
GO

EXEC sys.sp_enable_event_stream;
GO

EXEC sys.sp_create_event_stream_group
    @stream_group_name = N'orders_stream',
    @destination_type = N'AzureEventHubs',
    @destination_location =
        N'<namespace>.servicebus.windows.net:9093/<event-hub>',
    @destination_credential = N'CesEventHubsMI',
    @max_message_size_kb = 256,
    @partition_key_scheme = N'Table',
    @encoding = N'JSON';
GO

EXEC sys.sp_add_object_to_event_stream_group
    @stream_group_name = N'orders_stream',
    @object_name = N'dbo.Orders',
    @include_all_columns = 1,
    @include_old_values = 1;
GO
```

Managed Identity cần quyền gửi đúng Azure Event Hubs destination, áp dụng least privilege.

---

# PHẦN P — LOGIC APPS

## 35. Khi nào chọn?

- low-code/no-code workflow;
- nhiều connector;
- approval/email/SaaS orchestration;
- business process automation.

Ví dụ:

```text
Order changed
  ↓
Logic App
  ↓
Send email
  ↓
Create Teams notification
  ↓
Call another SaaS/API
```

Nếu requirement nói “run C# serverless code when SQL row changes” → **Azure Functions SQL trigger**, không phải Logic Apps.

---

# PHẦN Q — DECISION TREE 30 GIÂY

```text
Question mentions Azure integration
          ↓
What is the goal?
          |
          +-- REST/GraphQL over SQL?
          |       → DAB
          |
          +-- App requests/dependencies/exceptions?
          |       → Application Insights
          |
          +-- Central logs + KQL?
          |       → Log Analytics
          |
          +-- Which row changed only?
          |       → Change Tracking
          |
          +-- Change details/history for ETL?
          |       → CDC
          |
          +-- Run serverless code on change?
          |       → Azure Functions SQL Trigger
          |
          +-- Stream events near real-time?
          |       → CES
          |
          +-- Low-code workflow/connectors?
                  → Logic Apps
```

---

# PHẦN R — EXAM TRAPS

1. **DAB pagination không học `$skip/$top` như pattern hiện hành** → nhớ `$first/$after`.
2. **DAB ≠ public anonymous API mặc định an toàn** → cần auth/roles/permissions.
3. **Application Insights ≠ Log Analytics**.
4. **CT ≠ CDC**.
5. **Azure Functions SQL trigger dùng Change Tracking**.
6. **CES ≠ CDC** và CES không phải history store.
7. **Fabric Eventstream destination ≠ mọi Fabric SQL surface là CES source**.
8. **Managed Identity vẫn cần DB/Azure resource permissions**.
9. **Logic Apps ≠ Azure Functions**.
10. Preview/platform wording quan trọng.

---

# PHẦN S — MOCK SCENARIOS

### Q1
Cần expose tables, views và SP qua REST/GraphQL với ít backend code.  
**Đáp án:** DAB.

### Q2
REST client cần lấy 20 rows rồi tiếp tục trang sau ổn định.  
**Đáp án:** `$first=20` + `$after=<continuation-token>`.

### Q3
Client cần Customer cùng Orders nested.  
**Đáp án:** DAB GraphQL relationship.

### Q4
API có request latency và SQL dependency chậm.  
**Đáp án:** Application Insights.

### Q5
Cần query centralized diagnostic logs bằng KQL.  
**Đáp án:** Log Analytics workspace.

### Q6
Mobile sync chỉ cần biết key nào thay đổi.  
**Đáp án:** Change Tracking.

### Q7
ETL cần detailed change data và update history.  
**Đáp án:** CDC.

### Q8
Khi Orders thay đổi phải chạy C# serverless.  
**Đáp án:** Azure Functions SQL trigger.

### Q9
Function trigger không chạy; table chưa enable CT.  
**Đáp án:** enable Change Tracking DB + table.

### Q10
Cần stream DML events near-real-time tới Event Hubs.  
**Đáp án:** CES.

### Q11
Business muốn workflow low-code: khi order mới → approval → Teams/email.  
**Đáp án:** Logic Apps.

### Q12
DAB production connection không được chứa password.  
**Đáp án:** Managed Identity/Entra + environment/secret mechanism phù hợp.

### Q13
Từ 15/08/2026 tạo CES stream group mới.  
**Đáp án:** `@destination_type = 'AzureEventHubs'`.

### Q14
Đề nói Fabric Eventstream là destination. Có kết luận SQL database in Fabric chắc chắn là CES source không?  
**Đáp án:** Không. Phải đọc platform/`Applies to`; destination và source capability là hai việc khác nhau.

### Q15
Read-heavy endpoint scale-out, cần shared cache.  
**Đáp án:** DAB L1L2/distributed L2 scenario nếu phù hợp.

---

# PHẦN T — HANDS-ON CHECKLIST

Chỉ đánh dấu khi **tự làm không nhìn tài liệu**:

## DAB
- [ ] Cài DAB CLI.
- [ ] Tạo table/view/SP.
- [ ] Init `dab-config.json`.
- [ ] Expose table.
- [ ] Expose view.
- [ ] Expose SP.
- [ ] Tạo relationship.
- [ ] Gọi REST GET/POST.
- [ ] Dùng `$filter`, `$orderby`, `$first`, `$after`.
- [ ] Viết GraphQL nested query.
- [ ] Giải thích DAB client auth vs DB identity.
- [ ] Giải thích L1 vs L1L2 cache.
- [ ] Mô tả deployment lên Container Apps/App Service.

## Monitoring
- [ ] Phân biệt Application Insights vs Log Analytics.
- [ ] Viết một KQL query cho requests.
- [ ] Viết một KQL query cho SQL dependencies.
- [ ] Biết alert rule + action group dùng khi nào.

## Data changes
- [ ] Enable Change Tracking.
- [ ] Query `CHANGETABLE`.
- [ ] Enable CDC.
- [ ] Query CDC changes.
- [ ] Giải thích CT vs CDC.
- [ ] Tạo Azure Functions SQL trigger sample.
- [ ] Nhớ trigger dùng CT.
- [ ] Giải thích CES vs CDC.
- [ ] Nhớ CES at-least-once.
- [ ] Biết change `AzureEventHubs` từ 15/08/2026.
- [ ] Phân biệt CES source platform vs Fabric Eventstream destination.
- [ ] Biết khi nào Logic Apps phù hợp.

---

# PHẦN U — CHEAT SHEET

```text
REST + GraphQL + SQL       -> DAB
DAB REST paging            -> $first + $after
Nested relationships       -> GraphQL relationships
App telemetry              -> Application Insights
Central logs + KQL         -> Log Analytics
Alert threshold            -> Azure Monitor alert + action group

Which keys changed?        -> Change Tracking
Detailed change history    -> CDC
Run C# on SQL change       -> Azure Functions SQL Trigger
SQL Trigger internals      -> Change Tracking
Near-real-time stream      -> CES
Low-code orchestration     -> Logic Apps

No stored password         -> Entra / Managed Identity
CES from 15-Aug-2026       -> destination_type = AzureEventHubs
CES delivery               -> at least once
Fabric Eventstream         -> can be destination; don't infer every Fabric SQL surface is source
```

---

# TÀI LIỆU THAM KHẢO

## DP-800
- [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
- [Integrate SQL solutions with Azure services — Microsoft Learn](https://learn.microsoft.com/en-us/training/modules/integrate-sql-solutions-azure-services/)

## Data API builder
- [DAB documentation](https://learn.microsoft.com/en-us/azure/data-api-builder/)
- [DAB 2.0](https://learn.microsoft.com/en-us/azure/data-api-builder/whats-new/version-2-0)
- [REST API](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/rest/overview)
- [`$after` pagination](https://learn.microsoft.com/en-us/azure/data-api-builder/keywords/after-rest)
- [Entities](https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/entities)
- [Entra authentication](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/security/authenticate-entra)

## Data changes
- [Change Tracking](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-tracking-sql-server?view=sql-server-ver17)
- [CDC](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-data-capture-sql-server?view=sql-server-ver17)
- [Azure SQL trigger for Functions](https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-azure-sql-trigger)
- [CES overview](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/overview?view=sql-server-ver17)
- [Configure CES](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/configure?view=sql-server-ver17)
- [AMQP deprecation / 15-Aug-2026 breaking change](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/amqp-deprecation?view=sql-server-ver17)
- [Stream SQL change events to Fabric Eventstream](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/event-streams/stream-sql-change-events-to-eventstream)

---

> **Kết luận học:** Nếu bạn chỉ đọc definitions DAB/CDC/CT/CES thì vẫn dễ sai. Chỉ coi phần này hoàn tất khi bạn đọc một scenario và trong 10–20 giây xác định được **goal → service → tại sao không chọn 2–3 công nghệ gần giống**.
