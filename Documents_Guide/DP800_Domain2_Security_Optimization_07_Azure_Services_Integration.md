# DP-800 Domain 2: Integrate SQL Solutions with Azure Services

> **Miền 2:** Secure, Optimize, and Deploy Database Solutions (35–40%)  
> **Chủ đề:** Integrate SQL Solutions with Azure Services  
> **Cập nhật:** 09/08/2026  
> **Blueprint áp dụng:** DP-800 — Skills measured as of March 12, 2026  
> **Ưu tiên cao:** Đây là skill area cần đặc biệt luyện scenario/hands-on.  
> **Mục tiêu:** Nắm Data API builder (DAB) 2.0, observability và lựa chọn đúng cơ chế change/event.

---

## 0. PHẠM VI THI CHÍNH THỨC

Bạn phải nắm:

- Tạo **DAB configuration files**.
- Entities cho REST/GraphQL: **caching, pagination, searching/filtering**.
- REST/GraphQL endpoints.
- Expose database objects, views, stored procedures, **GraphQL relationships**.
- Deploy DAB.
- Azure Monitor: **Application Insights + Log Analytics**.
- Handle changes bằng **CES, CDC, Change Tracking, Azure Functions SQL trigger, Azure Logic Apps**.

**Nguồn chuẩn:**
- [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
- [Integrate SQL solutions with Azure services — Microsoft Learn](https://learn.microsoft.com/en-us/training/modules/integrate-sql-solutions-azure-services/)

---

# PHẦN 1 — DATA API BUILDER (DAB) 2.0

## 1. DAB là gì?

DAB biến database objects thành:
- REST API,
- GraphQL API,
- và từ DAB 2.0 có khả năng MCP/AI integration phong phú hơn,

mà không cần tự viết CRUD backend boilerplate.

**DAB 2.0 đã GA từ tháng 06/2026.** Khi học syntax hiện tại, ưu tiên docs 2.0 thay vì config 0.x/1.x cũ.

Tham khảo: [What's new in DAB 2.0](https://learn.microsoft.com/en-us/azure/data-api-builder/whats-new/version-2-0)

---

## 2. Cài và khởi tạo

```bash
dotnet tool install --global Microsoft.DataApiBuilder
```

Kiểm tra:

```bash
dab --version
```

Khởi tạo với connection string lấy từ environment variable:

```bash
# Bash
export SQL_CONNECTION_STRING='Server=tcp:<server>.database.windows.net,1433;Initial Catalog=<db>;Authentication=Active Directory Default;Encrypt=True'

dab init \
  --database-type mssql \
  --connection-string "@env('SQL_CONNECTION_STRING')"
```

> Production: ưu tiên Managed Identity/passwordless; không commit password vào config.

---

# PHẦN 2 — DAB CONFIG 2.0

## 3. Schema URL hiện hành

Dùng latest schema:

```json
{
  "$schema": "https://github.com/Azure/data-api-builder/releases/latest/download/dab.draft.schema.json"
}
```

Không nên cố học schema `v0.10.0` cũ.

---

## 4. Config hoàn chỉnh, dễ đọc

Ví dụ database có `dbo.Customers`, `dbo.Orders`, `dbo.usp_ProcessOrder`.

```json
{
  "$schema": "https://github.com/Azure/data-api-builder/releases/latest/download/dab.draft.schema.json",

  "data-source": {
    "database-type": "mssql",
    "connection-string": "@env('SQL_CONNECTION_STRING')"
  },

  "runtime": {
    "rest": {
      "enabled": true,
      "path": "/api"
    },
    "graphql": {
      "enabled": true,
      "path": "/graphql",
      "allow-introspection": false
    },
    "pagination": {
      "default-page-size": 100,
      "max-page-size": 1000,
      "next-link-relative": true
    },
    "host": {
      "mode": "production",
      "authentication": {
        "provider": "EntraId",
        "jwt": {
          "audience": "<APPLICATION-CLIENT-ID>",
          "issuer": "https://login.microsoftonline.com/<TENANT-ID>/v2.0"
        }
      }
    }
  },

  "entities": {
    "Customer": {
      "source": {
        "type": "table",
        "object": "dbo.Customers"
      },
      "rest": {
        "enabled": true
      },
      "graphql": {
        "enabled": true
      },
      "cache": {
        "enabled": true,
        "ttl-seconds": 30,
        "level": "L1"
      },
      "permissions": [
        {
          "role": "authenticated",
          "actions": [
            {
              "action": "read",
              "fields": {
                "include": [
                  "CustomerId",
                  "FullName",
                  "Email"
                ]
              }
            }
          ]
        }
      ],
      "relationships": {
        "orders": {
          "cardinality": "many",
          "target.entity": "Order",
          "source.fields": ["CustomerId"],
          "target.fields": ["CustomerId"]
        }
      }
    },

    "Order": {
      "source": {
        "type": "table",
        "object": "dbo.Orders"
      },
      "permissions": [
        {
          "role": "authenticated",
          "actions": ["read", "create", "update"]
        }
      ]
    },

    "ProcessOrder": {
      "source": {
        "type": "stored-procedure",
        "object": "dbo.usp_ProcessOrder"
      },
      "rest": {
        "methods": ["POST"]
      },
      "graphql": {
        "operation": "mutation"
      },
      "permissions": [
        {
          "role": "authenticated",
          "actions": ["execute"]
        }
      ]
    }
  }
}
```

### 4.1 Những thay đổi 2.0 cần nhớ

- `source` nên dùng object form với `type` + `object`.
- `mappings` cũ đang deprecated; DAB 2.0 chuyển dần sang **`fields` array** cho field metadata/alias/primary key.
- `source.key-fields` cũng deprecated trong 2.0 khi có thể dùng `fields[].primary-key`.
- Entity cache có `enabled`, `ttl-seconds`, `level` (`L1` hoặc `L1L2`).
- DAB 2.0 bổ sung **autoentities**, **OBO**, MCP integration/custom tools.

Tham khảo:
- [DAB entities schema](https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/entities)
- [DAB runtime schema](https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/runtime)

---

# PHẦN 3 — REST & GRAPHQL

## 5. REST query parameters hiện hành

### Filter / searching theo điều kiện

```http
GET /api/Order?$filter=TotalAmount gt 1000
```

REST DAB hiện hành **không có một query parameter generic tên `$search`** trong bộ query operators chuẩn. Khi đề nói “search/filter” trên REST entity, hãy nghĩ đến `$filter` với các toán tử so sánh/logical được hỗ trợ. Với GraphQL, structured `filter` còn hỗ trợ các string operators như `contains`, `startsWith` trong các trường hợp được hỗ trợ.

```graphql
query {
  orders(filter: { Status: { eq: "Pending" } }) {
    items {
      OrderId
      Status
    }
  }
}
```

Tham khảo: [REST `$filter`](https://learn.microsoft.com/en-us/azure/data-api-builder/keywords/filter-rest) và [GraphQL filtering](https://learn.microsoft.com/en-us/azure/data-api-builder/keywords/filter-graphql).

### Sort

```http
GET /api/Order?$orderby=OrderDate desc
```

### Projection

```http
GET /api/Order?$select=OrderId,CustomerId,TotalAmount
```

### Pagination — **không học `$skip/$top` cho DAB current**

Giới hạn page:

```http
GET /api/Order?$first=20
```

Response có `nextLink`/continuation token. Page kế:

```http
GET /api/Order?$first=20&$after=<opaque-continuation-token>
```

DAB current dùng **keyset/continuation pagination** với `$first` + `$after`.

Tham khảo: [DAB REST overview](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/rest/overview)

---

## 6. GraphQL pagination và relationships

Concept:

```graphql
query {
  customers(first: 20) {
    items {
      CustomerId
      FullName
      orders {
        items {
          OrderId
          TotalAmount
        }
      }
    }
    hasNextPage
    endCursor
  }
}
```

- `first` giới hạn số item.
- `after` dùng cursor/continuation cho page sau.
- Relationships trong DAB phục vụ GraphQL navigation giữa exposed entities.
- Many-to-many có thể cần linking object/fields.

**Exam keyword:** “retrieve customer together with related orders via GraphQL” → configure entity relationship.

Tham khảo: [DAB relationships](https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/entities#relationships-entity-name-entities)

---

# PHẦN 4 — STORED PROCEDURES & VIEWS

## 7. Stored procedure

Current DAB:
- `source.type = "stored-procedure"`
- `source.object = "schema.proc"`
- REST hỗ trợ methods phù hợp (GET/POST theo current DAB docs).
- permission action = `execute`.
- GraphQL operation có thể là query/mutation.
- Stored procedure endpoint có limitations riêng: đừng kỳ vọng DAB auto pagination/filter/order như table entity.

CLI:

```bash
dab add ProcessOrder \
  --source dbo.usp_ProcessOrder \
  --source.type stored-procedure \
  --permissions "authenticated:execute" \
  --rest.methods post
```

Tham khảo: [Stored procedures in DAB](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/database/stored-procedures)

---

## 8. Views

View không có primary key metadata tự nhiên như table trong một số tình huống, nên DAB cần biết key fields/field primary-key metadata để hỗ trợ operations thích hợp.

**Exam principle:** expose read-only reporting view → permissions `read`, hạn chế write.

---

# PHẦN 5 — CACHE

## 9. L1 vs L1L2

| Level | Ý nghĩa |
|---|---|
| L1 | in-memory cache của một DAB instance |
| L1L2 | L1 + distributed cache (Redis), phù hợp scale-out |

Entity:

```json
"cache": {
  "enabled": true,
  "ttl-seconds": 30,
  "level": "L1L2"
}
```

**Bẫy:** cache tăng performance nhưng tăng khả năng dữ liệu stale. Không cache tùy tiện dữ liệu security-sensitive/per-user nếu configuration/identity semantics không phù hợp.

DAB 2.0 OBO yêu cầu xem kỹ cache constraints; current DAB 2.0 docs nêu global cache phải được disable khi dùng OBO.

Tham khảo: [DAB cache configuration](https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/entities#cache-entity-name-entities)

---

# PHẦN 6 — AUTHENTICATION, AUTHORIZATION & OBO

## 10. DAB authentication

DAB 2.0 có provider `Unauthenticated` cho anonymous-only scenario, nhưng production sensitive API thường cần Entra/custom auth.

**Authentication** xác minh token.  
**Authorization** dựa trên role/entity permissions để quyết định action/field.

### 10.1 Service identity vs caller identity

Mặc định, DAB có thể vào SQL bằng service identity. Nếu DB RLS/audit cần thấy **actual caller**, DAB 2.0 có **On-Behalf-Of (OBO)** user delegation cho Microsoft SQL.

Concept config:

```json
"data-source": {
  "database-type": "mssql",
  "connection-string": "@env('SQL_CONNECTION_STRING')",
  "user-delegated-auth": {
    "enabled": true,
    "provider": "EntraId",
    "database-audience": "https://database.windows.net"
  }
}
```

OBO cần Entra app/prerequisites và secret/config tương ứng; production nên quản lý secret qua secure secret store/federation patterns phù hợp.

Tham khảo: [DAB 2.0 OBO](https://learn.microsoft.com/en-us/azure/data-api-builder/whats-new/version-2-0#introducing-on-behalf-of-obo-user-delegation)

---

# PHẦN 7 — MCP TRONG DAB 2.0

## 11. Vì sao liên quan?

DP-800 Domain 2 yêu cầu secure MCP endpoints, còn Domain 1 yêu cầu MCP tool options. DAB 2.0 nối hai phần này.

Stored procedure có thể thành **custom MCP tool**:

```bash
dab add GetOrderById \
  --source dbo.usp_GetOrderById \
  --source.type stored-procedure \
  --permissions "authenticated:execute" \
  --mcp.custom-tool true
```

Config concept:

```json
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
```

**Security:** agent chỉ được thấy/call tools cần thiết; validation/authorization vẫn phải ở server/database layer.

Tham khảo: [DAB 2.0 custom MCP tools](https://learn.microsoft.com/en-us/azure/data-api-builder/whats-new/version-2-0#introducing-custom-mcp-tools)

---

# PHẦN 8 — DEPLOYMENT DAB

## 12. Hosting options

Các lựa chọn Azure phổ biến:
- Azure Container Apps
- Azure App Service
- Azure Container Instances
- các integration/hosting patterns khác theo kiến trúc

### Container concept

```dockerfile
FROM mcr.microsoft.com/azure-databases/data-api-builder:latest
COPY dab-config.json /App/dab-config.json
```

> Production nên pin version/tag theo release policy của tổ chức thay vì blindly dùng `latest`.

Secrets/connection strings:
- environment variables,
- managed identity,
- Key Vault references.

Tham khảo: [DAB deployment documentation](https://learn.microsoft.com/en-us/azure/data-api-builder/deployment/)

---

# PHẦN 9 — AZURE MONITOR / APPLICATION INSIGHTS / LOG ANALYTICS

## 13. Chọn đúng công cụ

### Application Insights

Tốt cho application/API telemetry:
- request latency/status,
- dependency calls tới SQL,
- exceptions,
- distributed tracing.

DAB nhận Application Insights connection string từ environment variable:

```text
APPLICATIONINSIGHTS_CONNECTION_STRING=<value>
```

KQL example:

```kusto
requests
| where timestamp > ago(24h)
| summarize
    RequestCount = count(),
    AvgDuration = avg(duration),
    P95Duration = percentile(duration, 95),
    FailureRate = 100.0 * countif(success == false) / count()
```

Slow SQL dependencies:

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

### Log Analytics

Tốt cho central log analytics/KQL across resources.

Ví dụ Container Apps console logs:

```kusto
ContainerAppConsoleLogs_CL
| where Log_s contains "error"
    or Log_s contains "exception"
| project TimeGenerated, ContainerName_s, Log_s
| order by TimeGenerated desc
```

### Exam decision

- “REST/GraphQL latency, dependency trace, exception” → **Application Insights**.
- “centralized logs, KQL across Azure resources” → **Log Analytics workspace**.
- “proactive notification threshold” → Azure Monitor **alert rule + action group**.

Tham khảo: [Recommend Azure Monitor configurations — Microsoft Learn](https://learn.microsoft.com/en-us/training/modules/integrate-sql-solutions-azure-services/6-recommend-azure-monitor-configurations)

---

# PHẦN 10 — HANDLE DATA CHANGES

## 14. Decision matrix cần thuộc

| Cơ chế | Có before/after values? | Polling? | Lịch sử? | Use case |
|---|---:|---:|---:|---|
| **Change Tracking (CT)** | Không, chủ yếu biết row/key changed | Có | Limited/version-based | Lightweight sync |
| **CDC** | Có change data chi tiết | Consumer thường đọc change tables | Có theo retention | ETL/audit/change history |
| **Azure Functions SQL trigger** | nhận changed rows/operation | Extension dùng CT/polling internals | Không thay CDC history | Serverless reaction |
| **CES** | stream change event | **Không polling consumer DB** theo mô hình push | Stream, không phải history store | High-throughput/low-latency Event Hubs |
| **Logic Apps** | workflow/connectors | tùy trigger/action | không phải database history | Low-code orchestration |

---

## 15. Change Tracking (CT)

```sql
ALTER DATABASE YourDatabase
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

App có thể dùng:
- `CHANGE_TRACKING_CURRENT_VERSION()`
- `CHANGETABLE(CHANGES ...)`

**Chọn CT khi:** chỉ cần biết row nào thay đổi để sync, không cần full old/new history.

Tham khảo: [Track data changes with Change Tracking](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/track-data-changes-sql-server?view=sql-server-ver17)

---

## 16. CDC

```sql
-- Database
EXEC sys.sp_cdc_enable_db;
GO

-- Table
EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name = N'Orders',
    @role_name = NULL,
    @supports_net_changes = 1;
GO
```

Query changes bằng LSN:

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
    N'all'
);
GO
```

> Engine/service-specific CDC capture implementation khác nhau. Trong SQL Server truyền thống, capture/cleanup jobs gắn với SQL Server Agent; trên managed services cần theo docs của dịch vụ.

**Chọn CDC:** cần change history/before-after detail, downstream ETL/ELT.

Tham khảo: [Change Data Capture](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-data-capture-sql-server?view=sql-server-ver17)

---

## 17. Azure Functions SQL trigger binding

### Bẫy quan trọng nhất

**SQL trigger binding của Azure Functions dựa trên Change Tracking, không phải CDC.**

Vì vậy phải enable CT trên database và table trước.

C# isolated-worker style concept:

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

**Chọn:** muốn serverless code phản ứng nhanh với INSERT/UPDATE/DELETE mà không tự viết polling logic.

Tham khảo: [Azure SQL trigger for Functions](https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-azure-sql-trigger)

---

## 18. Change Event Streaming (CES) — Preview nhưng có trong blueprint

CES hiện là Preview trên SQL Server 2025/Azure SQL Database/Azure SQL Managed Instance theo tài liệu hiện hành.

### Đặc điểm

- stream thay đổi DML trực tiếp tới **Azure Event Hubs**,
- push/event-streaming, không yêu cầu downstream polling change table,
- event format hỗ trợ CloudEvents JSON/Avro theo current CES docs,
- phù hợp low-latency/high-throughput event pipeline.

### Cấu hình concept

Syntax preview có thể thay đổi; học **sequence**:

```text
1. Tạo/configure Event Hubs
2. Enable CES prerequisites
3. CREATE EVENT STREAMING GROUP
4. Add tables vào streaming group
5. Start/monitor stream
```

**Không học sai:** CES không đồng nghĩa “push thẳng tới Event Grid”. Target cốt lõi trong current SQL CES là **Azure Event Hubs**; từ đó downstream có thể nối vào Functions/Fabric Eventstream/etc.

### Compatibility traps

Current CES docs có các giới hạn/incompatibilities với một số change replication/mirroring technologies. Khi thiết kế, luôn kiểm tra current limitations vì đây là Preview.

Tham khảo: [Change Event Streaming overview](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/overview?view=sql-server-ver17)

---

## 19. Azure Logic Apps

Logic Apps phù hợp khi:
- cần low-code workflow,
- nối SQL event/data với email, Teams, Service Bus, HTTP, approvals, SaaS connectors,
- business orchestration quan trọng hơn raw throughput/code control.

**Exam keyword:** “minimal code / workflow / many SaaS connectors / approval” → Logic Apps.

Tham khảo: [SQL Server connector for Azure Logic Apps](https://learn.microsoft.com/en-us/azure/connectors/connectors-create-api-sqlazure)

---

# PHẦN 11 — DAB 2.0 UPDATE: AUTOENTITIES

## 20. Auto configuration

DAB 2.0 có `autoentities` để expose objects khớp pattern.

Ví dụ CLI concept:

```bash
dab auto-config my-def \
  --patterns.include "dbo.%" \
  --patterns.exclude "dbo.internal%" \
  --patterns.name "{schema}_{object}" \
  --permissions "authenticated:read"
```

Preview objects trước:

```bash
dab auto-config-simulate
```

**Khi thi:** đây là kiến thức current/related. Core blueprint vẫn yêu cầu bạn biết manual entity config; không dùng autoentities để bỏ qua fundamentals.

---

# PHẦN 12 — DECISION TABLE ĐI THI

| Scenario | Chọn |
|---|---|
| Expose SQL table nhanh qua CRUD API | DAB |
| REST current pagination | `$first` + `$after` |
| Filter REST | `$filter` |
| Choose returned fields | `$select` |
| GraphQL nested Customer→Orders | relationship |
| Stored procedure endpoint | `source.type=stored-procedure` + `execute` |
| Scale-out cache | L1L2 |
| API request latency/dependency traces | Application Insights |
| Central KQL logs | Log Analytics |
| Lightweight “which rows changed?” | Change Tracking |
| Full change history/detail | CDC |
| Serverless code on SQL change | Azure Functions SQL trigger + CT |
| Push high-throughput stream to Event Hubs | CES |
| Low-code business workflow | Logic Apps |
| DB RLS must see actual API caller | DAB OBO |
| Agent needs purpose-built SP tool | DAB 2.0 MCP custom tool |

---

# PHẦN 13 — MOCK QUESTIONS

### Câu 1
DAB REST API cần page 2. Developer dùng `$skip=100&$top=100`. Có đúng với DAB current?

**Đáp án:** Không. DAB current dùng `$first` và continuation `$after`.

### Câu 2
Stored procedure được expose nhưng permissions đặt `read`. Có đúng?

**Đáp án:** Stored procedure entity dùng action `execute`.

### Câu 3
Azure Function SQL trigger không fire. Database chưa enable CDC. Bạn nên enable CDC hay CT?

**Đáp án:** **Change Tracking**; SQL trigger binding dựa trên CT.

### Câu 4
Cần complete before/after history cho ETL.

**Đáp án:** CDC.

### Câu 5
Cần sub-second style streaming không polling tới Azure Event Hubs.

**Đáp án:** CES, nếu platform/preview constraints phù hợp.

### Câu 6
Cần visualize DAB REST p95 latency và SQL dependency duration.

**Đáp án:** Application Insights.

### Câu 7
DAB dùng one service identity nhưng SQL RLS phải áp theo actual end-user.

**Đáp án:** Xem DAB 2.0 OBO.

### Câu 8
Scale-out nhiều DAB replicas và muốn shared cache.

**Đáp án:** L1L2 (distributed cache layer) thay vì chỉ L1.

### Câu 9
Stored procedure trả result set và bạn muốn tự `$filter/$orderby` trên SP REST endpoint như table.

**Đáp án:** Không giả định được. Stored-procedure endpoints có limitations; filtering/pagination/ordering tự động không hoạt động như table entities.

---

# PHẦN 14 — CHECKLIST “EXAM READY”

- [ ] Cài/init DAB và dùng `@env(...)`.
- [ ] Viết DAB 2.0 `source.type` + `source.object`.
- [ ] Config Entra auth + permissions.
- [ ] Viết REST `$filter/$orderby/$select/$first/$after`.
- [ ] Viết GraphQL relationship.
- [ ] Expose stored procedure với `execute`.
- [ ] Phân biệt L1/L1L2 cache.
- [ ] Hiểu DAB OBO và MCP custom tool.
- [ ] Chọn Container Apps/App Service hosting.
- [ ] Viết KQL cơ bản cho Application Insights/Log Analytics.
- [ ] Phân biệt CT/CDC/Functions SQL trigger/CES/Logic Apps.
- [ ] Nhớ SQL trigger binding yêu cầu CT.
- [ ] Nhớ CES current target chính là Event Hubs và vẫn Preview.

---

# TÀI LIỆU THAM KHẢO

1. [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
2. [Integrate SQL solutions with Azure services — Microsoft Learn](https://learn.microsoft.com/en-us/training/modules/integrate-sql-solutions-azure-services/)
3. [DAB 2.0 — What's new](https://learn.microsoft.com/en-us/azure/data-api-builder/whats-new/version-2-0)
4. [DAB entities configuration](https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/entities)
5. [DAB runtime configuration](https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/runtime)
6. [DAB REST API](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/rest/overview)
7. [Azure Monitor configuration for DAB](https://learn.microsoft.com/en-us/training/modules/integrate-sql-solutions-azure-services/6-recommend-azure-monitor-configurations)
8. [Event-driven patterns](https://learn.microsoft.com/en-us/training/modules/integrate-sql-solutions-azure-services/7-handle-changes-event-driven-patterns)
9. [Azure Functions SQL trigger](https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-azure-sql-trigger)
10. [Change Event Streaming](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/overview?view=sql-server-ver17)
