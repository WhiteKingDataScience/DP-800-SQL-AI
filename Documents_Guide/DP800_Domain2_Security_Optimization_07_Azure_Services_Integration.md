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
    "cache": {
      "enabled": true,
      "ttl-seconds": 30
    },
    "mcp": {
      "enabled": false
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
- `mappings` đã deprecated; DAB 2.0 dùng **`fields[].alias`**.
- `source.key-fields` đã deprecated; dùng **`fields[].primary-key`**. Schema không cho `fields` tồn tại cùng `mappings` hoặc `source.key-fields` trong một entity.
- Entity cache có `enabled`, `ttl-seconds`, `level` (`L1` hoặc `L1L2`).
- DAB 2.0 bổ sung **autoentities**, **OBO**, MCP integration/custom tools.

Ví dụ field metadata hiện hành cho một view/table cần alias và khai báo key:

```json
{
  "fields": [
    {
      "name": "CustomerId",
      "alias": "id",
      "description": "Định danh duy nhất của khách hàng",
      "primary-key": true
    },
    {
      "name": "FullName",
      "alias": "name",
      "description": "Tên hiển thị của khách hàng"
    }
  ]
}
```

> Trong config hoàn chỉnh, MCP được tắt rõ vì API này chưa có requirement cho agent. DAB runtime 2.0 hiện có MCP enabled mặc định; secure-by-design nghĩa là chỉ bật endpoint/tool surface khi cần, không dựa vào việc “chưa ai biết URL”.

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

Muốn cache thực sự hoạt động phải bật **cả global runtime cache lẫn entity cache**. `runtime.cache.enabled` mặc định là `false`; nếu global là `false` thì entity đặt `enabled: true` vẫn không có tác dụng.

Ví dụ scale-out đầy đủ với Redis:

```json
{
  "runtime": {
    "cache": {
      "enabled": true,
      "ttl-seconds": 30,
      "level-2": {
        "enabled": true,
        "provider": "redis",
        "connection-string": "@env('REDIS_CONNECTION_STRING')",
        "partition": "dp800-production"
      }
    }
  },
  "entities": {
    "Customer": {
      "cache": {
        "enabled": true,
        "ttl-seconds": 30,
        "level": "L1L2"
      }
    }
  }
}
```

Nếu entity chọn `L1L2` nhưng global `level-2.enabled` chưa bật/cấu hình thì entity chỉ hoạt động như `L1`. `partition` tách namespace/cache backplane giữa các môi trường hoặc ứng dụng.

**Bẫy:** cache tăng performance nhưng tăng khả năng dữ liệu stale. Không cache tùy tiện dữ liệu security-sensitive/per-user nếu configuration/identity semantics không phù hợp.

DAB 2.0 OBO yêu cầu xem kỹ cache constraints; current DAB 2.0 docs nêu global cache phải được disable khi dùng OBO.

Tham khảo:
- [DAB runtime cache](https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/runtime#cache-runtime)
- [DAB Level 2 cache](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/cache/level-2)

---

# PHẦN 6 — AUTHENTICATION, AUTHORIZATION & OBO

## 10. DAB authentication

DAB 2.0 có provider `Unauthenticated` cho anonymous-only scenario, nhưng production sensitive API thường cần Entra/custom auth.

### Bẫy DAB 2.0: default authentication và role inheritance

- `dab init` mới dùng **`Unauthenticated` làm default**. DAB không validate JWT; mọi request chạy với role `anonymous`, kể cả khi một reverse proxy phía trước đã authenticate user. Khi provider này active, `authenticated` và custom roles trong entity không bao giờ được kích hoạt.
- Role inheritance chạy theo chuỗi **named role → authenticated → anonymous**. Nếu entity chỉ khai báo `anonymous:read`, authenticated và custom role không được cấu hình riêng cũng thừa hưởng read.
- Entity không có permission nào vẫn secure-by-default (không ai truy cập được), nhưng permission `anonymous` quá rộng có thể lan lên các role khác qua inheritance.

Không đoán effective permissions bằng mắt; dùng CLI:

```bash
dab configure --show-effective-permissions --config dab-config.json
dab validate --config dab-config.json
```

Nguồn: [DAB authorization và role inheritance](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/security/authorization-overview#role-inheritance)

**Authentication** xác minh token.  
**Authorization** dựa trên role/entity permissions để quyết định action/field.

### 10.1 Service identity vs caller identity

Mặc định, DAB có thể vào SQL bằng service identity. Nếu DB RLS/audit cần thấy **actual caller**, DAB 2.0 có **On-Behalf-Of (OBO)** user delegation cho Microsoft SQL.

Config đầy đủ cốt lõi:

```json
{
  "data-source": {
    "database-type": "mssql",
    "connection-string": "@env('SQL_CONNECTION_STRING')",
    "user-delegated-auth": {
      "enabled": true,
      "provider": "EntraId",
      "database-audience": "https://database.windows.net"
    }
  },
  "runtime": {
    "cache": {
      "enabled": false
    }
  }
}
```

Environment variables mà DAB 2.0 OBO hiện hành đọc:

```bash
export DAB_OBO_CLIENT_ID="<application-client-id>"
export DAB_OBO_TENANT_ID="<tenant-id>"
export DAB_OBO_CLIENT_SECRET="<client-secret>"
```

- `DAB_OBO_CLIENT_SECRET` là secret: đưa vào Key Vault/secret mechanism của hosting platform, không commit.
- `SQL_CONNECTION_STRING` phải là bare connection string, **không có `Authentication=`**, ví dụ `Server=tcp:<server>.database.windows.net,1433;Database=<db>;Encrypt=true;TrustServerCertificate=false`.
- Cache global phải tắt để không phục vụ kết quả của user này cho user khác.
- OBO hiện chỉ hỗ trợ Microsoft SQL với Entra ID; DAB giữ connection pool riêng theo user.

Tham khảo: [Configure DAB OBO](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/security/authenticate-on-behalf-of)

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

Hoặc cấu hình rõ trong DAB 2.0 mà vẫn lấy giá trị từ environment:

```json
{
  "runtime": {
    "telemetry": {
      "application-insights": {
        "enabled": true,
        "connection-string": "@env('APPLICATIONINSIGHTS_CONNECTION_STRING')"
      }
    }
  }
}
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

DAB 2.0 có thể gửi telemetry trực tiếp qua Data Collection Endpoint/Rule. Ba giá trị trong `auth` đều bắt buộc khi bật sink này:

```json
{
  "runtime": {
    "telemetry": {
      "azure-log-analytics": {
        "enabled": true,
        "dab-identifier": "orders-api-production",
        "flush-interval-seconds": 10,
        "auth": {
          "custom-table-name": "DabTelemetry_CL",
          "dcr-immutable-id": "@env('DAB_LOG_DCR_IMMUTABLE_ID')",
          "dce-endpoint": "@env('DAB_LOG_DCE_ENDPOINT')"
        }
      }
    }
  }
}
```

Hosting identity còn cần quyền gửi dữ liệu phù hợp tới DCR/DCE. Tên table, schema và DCR phải được provision trước; một JSON đúng cú pháp không tự tạo Azure Monitor resources.

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

Tham khảo:
- [Recommend Azure Monitor configurations — Microsoft Learn](https://learn.microsoft.com/en-us/training/modules/integrate-sql-solutions-azure-services/6-recommend-azure-monitor-configurations)
- [DAB runtime telemetry configuration](https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/runtime#telemetry-runtime)

---

# PHẦN 10 — HANDLE DATA CHANGES

## 14. Decision matrix cần thuộc

| Cơ chế | Có before/after values? | Polling? | Lịch sử? | Use case |
|---|---:|---:|---:|---|
| **Change Tracking (CT)** | Không, chủ yếu biết row/key changed | Có | Limited/version-based | Lightweight sync |
| **CDC** | Có change data chi tiết | Consumer thường đọc change tables | Có theo retention | ETL/audit/change history |
| **Azure Functions SQL trigger** | nhận changed rows/operation | Extension dùng CT/polling internals | Không thay CDC history | Serverless reaction |
| **CES** | stream change event | **Không polling consumer DB** theo mô hình push | Stream, không phải history store | High-throughput/low-latency Event Hubs hoặc Fabric Eventstream |
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

Consumer pattern đầy đủ (application phải lưu checkpoint bền vững sau khi xử lý thành công):

```sql
-- Trong thực tế, load giá trị này từ bảng checkpoint của consumer.
DECLARE @last_sync_version bigint = 0;
DECLARE @min_valid_version bigint =
    CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID(N'dbo.Orders'));
DECLARE @next_sync_version bigint =
    CHANGE_TRACKING_CURRENT_VERSION();

IF @min_valid_version IS NULL
    THROW 50000, N'Table chưa enable Change Tracking hoặc không tồn tại.', 1;

-- Nếu checkpoint đã cũ hơn retention window, CT không còn đủ dữ liệu;
-- consumer phải full-resync rồi lấy checkpoint mới.
IF @last_sync_version < @min_valid_version
    THROW 50001, N'Checkpoint Change Tracking đã hết hiệu lực; cần full resync.', 1;

SELECT
    CT.OrderId,
    CT.SYS_CHANGE_VERSION,
    CT.SYS_CHANGE_OPERATION,  -- I, U hoặc D
    O.CustomerId,
    O.Status
FROM CHANGETABLE(CHANGES dbo.Orders, @last_sync_version) AS CT
LEFT JOIN dbo.Orders AS O
  ON O.OrderId = CT.OrderId
WHERE CT.SYS_CHANGE_VERSION <= @next_sync_version;

-- Sau khi downstream xử lý/commit thành công,
-- persist @next_sync_version làm @last_sync_version cho lần kế tiếp.
```

`LEFT JOIN` là cần thiết vì row đã delete không còn trong base table. CT yêu cầu table có primary key và trả **latest change information per key trong khoảng version**, không phải mọi before/after event như CDC. Retention quá ngắn so với downtime làm checkpoint mất hiệu lực.

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
    N'all update old'
);
GO
```

`N'all update old'` trả cả update-before (`__$operation = 3`) và update-after (`4`). Các code khác: delete `1`, insert `2`. Nếu chỉ cần một update image sau cùng, dùng `N'all'`; đừng khẳng định `all` luôn chứa cả old/new image.

> Engine/service-specific CDC capture implementation khác nhau. Trong SQL Server truyền thống, capture/cleanup jobs gắn với SQL Server Agent; trên managed services cần theo docs của dịch vụ.

**Chọn CDC:** cần change history/before-after detail, downstream ETL/ELT.

Tham khảo: [Change Data Capture](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-data-capture-sql-server?view=sql-server-ver17)

---

## 17. Azure Functions SQL trigger binding

### Bẫy quan trọng nhất

**SQL trigger binding của Azure Functions dựa trên Change Tracking, không phải CDC.**

Vì vậy phải enable CT trên database và table trước.

Binding dùng polling loop nội bộ; bạn không phải tự viết polling, nhưng đây không phải push stream và không thay thế CDC history. Với .NET, ưu tiên isolated worker; support cho in-process model kết thúc ngày **10/11/2026** theo Azure Functions docs hiện hành.

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

Database principal/Managed Identity của Function cần nhiều hơn `db_datareader`/`db_datawriter`. Mẫu least-privilege theo tài liệu binding:

```sql
-- Chạy bởi Entra admin/principal đủ quyền trong target database.
CREATE USER [orders-function-mi] FROM EXTERNAL PROVIDER;
GO

GRANT CREATE TABLE TO [orders-function-mi];
GRANT CREATE SCHEMA TO [orders-function-mi];
GRANT SELECT ON [dbo].[Orders] TO [orders-function-mi];
GRANT VIEW CHANGE TRACKING ON [dbo].[Orders] TO [orders-function-mi];
GO

IF SCHEMA_ID(N'az_func') IS NULL
    EXEC(N'CREATE SCHEMA az_func AUTHORIZATION dbo;');
GO

GRANT ALTER ON SCHEMA::az_func TO [orders-function-mi];
GRANT SELECT, INSERT, UPDATE, DELETE
    ON SCHEMA::az_func TO [orders-function-mi];
GO
```

Schema `az_func` chứa state/change-tracking/lease tables nội bộ của trigger. Nếu nhiều triggers dùng cùng identity, rà soát scope theo database/schema và không cấp `db_owner` chỉ để “cho chạy được”.

**Chọn:** muốn serverless code phản ứng nhanh với INSERT/UPDATE/DELETE mà không tự viết polling logic.

Tham khảo: [Azure SQL trigger for Functions](https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-azure-sql-trigger)

---

## 18. Change Event Streaming (CES) — Preview nhưng có trong blueprint

CES hiện là **Preview** trên **SQL Server 2025**, **Azure SQL Database**, **Azure SQL Managed Instance** và **SQL database in Microsoft Fabric**. CES đọc transaction log và đẩy từng thay đổi `INSERT`/`UPDATE`/`DELETE` gần real time trực tiếp tới **Azure Event Hubs hoặc Fabric Eventstream**.

### Đặc điểm

- Push/event-streaming: downstream không cần polling change table.
- Event là **CloudEvent**, serialize dưới dạng JSON hoặc Avro Binary; có schema hiện hành, previous values và new values theo cấu hình.
- Mỗi row bị tác động tạo một event riêng. CES là stream, **không phải history store** và không seed dữ liệu đã có trước lúc bật.
- Delivery là **at least once**: consumer phải idempotent, ví dụ deduplicate bằng event/transaction metadata trước khi ghi đích.

### Prerequisites và quyền

- Principal cấu hình cần `db_owner` hoặc `CONTROL DATABASE`. Không cấp quyền rộng này cho runtime consumer.
- SQL Server 2025 cần database ở `FULL` recovery và bật `PREVIEW_FEATURES`; Azure SQL Database/Managed Instance luôn dùng `FULL` và không cần bật setting Preview này.
- Azure SQL Managed Instance phải dùng update policy **SQL Server 2025** hoặc **Always-up-to-date**.
- Với Managed Identity, gán role **Azure Event Hubs Data Sender** tại đúng Event Hub (least privilege), không mặc định ở cả namespace. SQL Server 2025 hỗ trợ Entra authentication từ CU3 khi chạy trên Azure VM hoặc enabled by Azure Arc.
- Kafka publisher dùng outbound port `9093`. Theo giới hạn hiện hành, CES chỉ phát tới public endpoint; private endpoint/service endpoint chưa được hỗ trợ.

### Breaking change rất dễ ra câu hỏi: ngày 15/08/2026

Tài liệu được cập nhật ngày **09/08/2026**, ngay trước một breaking change đã được Microsoft công bố:

| Thời điểm tạo stream group | `@destination_type` | Ghi nhớ |
|---|---|---|
| Đến hết 14/08/2026 | `AzureEventHubsApacheKafka` cho Kafka; `AzureEventHubsAmqp` cho AMQP | Đây là giá trị API đang hoạt động ở ngày cập nhật tài liệu |
| Từ 15/08/2026 | **chỉ `AzureEventHubs`** | Vẫn publish bằng Kafka; hai giá trị cũ sẽ fail khi tạo group mới |
| Group AMQP đã tồn tại | tiếp tục chạy đến tháng 04/2027 | Phải migrate sang Kafka trước thời hạn |

Từ 15/08/2026, Kafka hỗ trợ Entra hoặc service key; **SAS authentication không còn dùng cho CES group mới**. Consumer Event Hubs vẫn có thể đọc bằng AMQP hoặc Kafka vì consumer protocol độc lập với publisher protocol. Hãy kiểm tra lại trang [AMQP protocol deprecation](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/amqp-deprecation?view=sql-server-ver17) nếu lab sau ngày chuyển đổi.

### Lab T-SQL hoàn chỉnh — Kafka + Managed Identity

Ví dụ dưới đây dùng API còn hiệu lực tại ngày **09/08/2026**. Sau ngày 15/08/2026, đổi `AzureEventHubsApacheKafka` thành `AzureEventHubs` theo bảng trên và đối chiếu [Configure CES](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/configure?view=sql-server-ver17), vì CES vẫn là Preview.

```sql
USE [YourDatabase];
GO

-- Chỉ SQL Server 2025: Azure SQL Database/Managed Instance bỏ qua hai lệnh này.
ALTER DATABASE [YourDatabase] SET RECOVERY FULL;
GO
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
GO

-- Chỉ tạo một lần cho database; giữ password trong secret manager, không commit.
IF NOT EXISTS
(
    SELECT 1
    FROM sys.symmetric_keys
    WHERE name = N'##MS_DatabaseMasterKey##'
)
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = '<Mật-khẩu-rất-mạnh>';
GO

-- Managed Identity của logical server/MI/SQL Server phải có
-- Azure Event Hubs Data Sender trên Event Hub đích.
CREATE DATABASE SCOPED CREDENTIAL [CesEventHubsManagedIdentity]
WITH IDENTITY = 'Managed Identity';
GO

EXEC sys.sp_enable_event_stream;
GO

EXEC sys.sp_create_event_stream_group
    @stream_group_name = N'orders_stream',
    @destination_type = N'AzureEventHubsApacheKafka', -- đến hết 14/08/2026
    @destination_location = N'<namespace>.servicebus.windows.net:9093/<event-hub>',
    @destination_credential = N'CesEventHubsManagedIdentity',
    @max_message_size_kb = 256,  -- hợp lệ: 128..1024; mặc định 256
    @partition_key_scheme = N'Table',
    @encoding = N'JSON';
GO

EXEC sys.sp_add_object_to_event_stream_group
    @stream_group_name = N'orders_stream',
    @object_name = N'dbo.Orders',
    @include_all_columns = 1,
    @include_old_values = 1,
    @include_old_lob_values = 0;
GO

-- Kiểm tra cấu hình và theo dõi lỗi/độ trễ log scan.
SELECT name, is_event_stream_enabled
FROM sys.databases
WHERE database_id = DB_ID();

EXEC sys.sp_help_change_feed_table
    @source_schema = N'dbo',
    @source_name = N'Orders';

SELECT *
FROM sys.dm_change_feed_errors
ORDER BY entry_time DESC;

SELECT *
FROM sys.dm_change_feed_log_scan_sessions
ORDER BY start_time DESC;
```

`@partition_key_scheme` thường gặp: `None` (round robin), `StreamGroup`, `Table`, hoặc `Column`. Chọn `Column` khi cần giữ thứ tự theo business key và truyền thêm `@partition_key_column_name`; tránh tạo hot partition với key lệch phân bố. `@max_message_size_kb` điều khiển chunk 128–1024 KB, nhưng **mỗi column value lớn hơn 1 MB vẫn bị truncate vô điều kiện mà không có warning/error**.

### Traps về vận hành, compatibility và security

- **Log growth:** CES giữ log chưa phát được để bảo đảm at-least-once. Destination/credential/network lỗi lâu có thể chặn log truncation; SQL Server có thể hết log và fail writes, còn Azure SQL Database/MI có thể tự disable CES hoặc kill long transaction khi gần giới hạn. Theo dõi hai DMV ở trên và log size.
- Nếu CES bị disable, thay đổi trong thời gian tắt **không được capture**; bật lại không tự backfill. DDL không phát event, nhưng schema của DML event tiếp theo phản ánh schema mới.
- CES không cùng tồn tại với **CDC**, transactional replication, Fabric Mirrored Databases for SQL Server hoặc Azure Synapse Link; **Change Tracking có thể cùng tồn tại**.
- CES không hỗ trợ nhiều kiểu table/column đặc biệt, ví dụ memory-optimized, graph, external table, clustered columnstore, Always Encrypted, temporal/ledger history table; luôn kiểm tra current limitations trước triển khai.
- **Bẫy rò rỉ dữ liệu:** RLS không lọc payload CES và Dynamic Data Masking không mask payload; CES phát mọi row và dữ liệu nguyên bản. Vì vậy phải bảo vệ Event Hub/Eventstream, RBAC, network và retention như một bản sao dữ liệu nhạy cảm.
- CES không phải Event Grid target. Đích trực tiếp hiện hành là **Azure Event Hubs hoặc Fabric Eventstream**.

Tham khảo:

- [Change Event Streaming overview](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/overview?view=sql-server-ver17)
- [Configure Change Event Streaming](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/configure?view=sql-server-ver17)
- [AMQP protocol deprecation — timeline và migration](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/amqp-deprecation?view=sql-server-ver17)
- [Stream SQL change events to Fabric Eventstream](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/event-streams/stream-sql-change-events-to-eventstream)
- [Monitor delivery errors](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-change-feed-errors?view=sql-server-ver17) và [monitor log scan sessions](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-change-feed-log-scan-sessions?view=sql-server-ver17)

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
| Push high-throughput stream to Event Hubs/Fabric Eventstream | CES |
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
- [ ] Nhớ CES trực tiếp tới Event Hubs/Fabric Eventstream, vẫn Preview, at-least-once và không backfill.
- [ ] Nhớ breaking change `destination_type=AzureEventHubs` từ 15/08/2026; group AMQP cũ phải migrate trước 04/2027.

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
11. [Configure Change Event Streaming](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/configure?view=sql-server-ver17)
12. [CES AMQP protocol deprecation](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/change-event-streaming/amqp-deprecation?view=sql-server-ver17)
