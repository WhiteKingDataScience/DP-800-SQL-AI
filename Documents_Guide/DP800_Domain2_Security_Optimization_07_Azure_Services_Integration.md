# DP-800 Domain 2: Integrate SQL Solutions with Azure Services

> **Miền 2:** Secure, Optimize, and Deploy Database Solutions (35–40%)  
> **Chủ đề:** Integrate SQL Solutions with Azure Services  
> **🚨 ĐÂY LÀ ĐIỂM YẾU SỐ 2 TRONG SCORE REPORT (TOP PRIORITIZED SKILL):** Nắm chắc Data API builder (DAB), tệp `dab-config.json`, tích hợp Azure Monitor và các cơ chế xử lý thay đổi dữ liệu (Change Tracking, CDC, CES, Azure Functions SQL Trigger).

---

## 📘 PHẦN 1: LÝ THUYẾT & KIẾN THỨC CỐT LÕI (CORE THEORY)

### 1. Data API Builder (DAB) cho REST & GraphQL
- **Data API builder (DAB) là gì?**  
  Là một công cụ mã nguồn mở của Microsoft cho phép tự động biến CSDL SQL Server, Azure SQL hoặc Fabric SQL thành các API chuẩn **REST** và **GraphQL** mà không cần viết backend code.
- **Tệp Cấu Hình `dab-config.json`:**
  - *Data Source:* Cấu hình kiểu CSDL và chuỗi kết nối (Bắt buộc dùng `@env('DATABASE_CONNECTION_STRING')` để bảo mật).
  - *Runtime:* Bật/tắt REST endpoint (`/api`), GraphQL endpoint (`/graphql`), CORS, Caching, Authentication (Entra ID / Static Web Apps).
  - *Entities:* Định nghĩa danh sách các Bảng, View, Stored Procedure được expose ra API.
- **Tính năng REST & GraphQL của DAB:**
  - *Pagination:* Phân trang tự động (`$first`, `$after` trong GraphQL hoặc `$skip`, `$top` trong REST).
  - *Filtering & Searching:* Lọc dữ liệu qua tham số truy vấn (`$filter=Amount gt 100`).
  - *Relationships:* Định nghĩa mối quan hệ 1-N hoặc N-N giữa các entity GraphQL (ví dụ: `Customer` ➔ `Orders`).
  - *Exposing Stored Procedures:* Expose SP dưới dạng HTTP `POST` trong REST hoặc Mutation/Query trong GraphQL.

### 2. Tích Hợp Azure Monitor & Log Analytics Workspace
- **Diagnostic Settings (Cài đặt chẩn đoán):**  
  Cấu hình Azure SQL Database đẩy telemetry, log và metric sang **Log Analytics Workspace** hoặc **Application Insights**.
- **Các Log Categories Quan Trọng:** `SQLSecurityAuditEvents`, `Deadlocks`, `Errors`, `Timeouts`, `Blocks`, `DatabaseWaitStatistics`.
- **Ngôn ngữ Truy vấn KQL (Kusto Query Language):** Dùng KQL trong Log Analytics để chẩn đoán sự cố:
  ```kusto
  AzureDiagnostics
  | where Category == "Deadlocks"
  | project TimeGenerated, ResourceId, error_xml_s
  ```

### 3. Xử Lý Thay Đổi Dữ Liệu (Handling Data Changes Matrix)

| Công nghệ | Đặc điểm & Cơ chế hoạt động | Trường hợp sử dụng tối ưu (Use Case) |
|---|---|---|
| **Change Tracking (CT)** | Nhẹ, chỉ ghi nhận ID dòng nào bị thay đổi (INSERT/UPDATE/DELETE). Không lưu lịch sử dữ liệu cũ. | Đồng bộ dữ liệu hai chiều giữa SQL và CSDL ứng dụng Client. |
| **CDC (Change Data Capture)** | Ghi nhận chi tiết dữ liệu trước và sau khi thay đổi vào bảng cắp lịch sử. Dùng SQL Agent. | ETL/ELT pipelines, nạp dữ liệu sang Data Lake / Warehouse. |
| **Azure Functions (SQL Trigger Binding)** | Tự động kích hoạt (Trigger) hàm C# / Python / JS Serverless ngay khi có dòng dữ liệu mới chèn vào CSDL SQL. | Kiến trúc Event-Driven, gửi Email thông báo khi có đơn hàng mới. |
| **Change Event Streaming (CES)** | Đẩy luồng sự kiện thay đổi dữ liệu theo thời gian thực sang Azure Event Hubs / Event Grid. | Tích hợp hệ thống phân tán Real-Time Streaming Data. |
| **Azure Logic Apps** | Workflow low-code tích hợp connector SQL Server với hơn 500 dịch vụ Azure. | Tự động hóa quy trình nghiệp vụ kinh doanh. |

---

## 💻 PHẦN 2: MÃ CẤU HÌNH & CODE SNIPPETS (HANDS-ON LABS)

### 1. Tệp Cấu Hình Data API Builder (`dab-config.json`) Hoàn Chỉnh

```json
{
  "$schema": "https://github.com/Azure/data-api-builder/releases/download/v0.10.0/dab.draft-01.schema.json",
  "data-source": {
    "database-type": "mssql",
    "connection-string": "@env('DATABASE_CONNECTION_STRING')"
  },
  "runtime": {
    "rest": {
      "enabled": true,
      "path": "/api"
    },
    "graphql": {
      "enabled": true,
      "path": "/graphql"
    },
    "host": {
      "mode": "development",
      "cors": {
        "origins": ["https://localhost:3000"]
      }
    }
  },
  "entities": {
    "Customer": {
      "source": "dbo.Customers",
      "permissions": [
        {
          "role": "anonymous",
          "actions": [
            {
              "action": "read",
              "fields": { "include": ["CustomerId", "FullName", "Email"] }
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
      "source": "dbo.Orders",
      "permissions": [
        {
          "role": "authenticated",
          "actions": ["create", "read", "update"]
        }
      ]
    },
    "ProcessOrder": {
      "source": "dbo.sp_ProcessOrder",
      "rest": { "methods": ["post"] },
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

### 2. Azure Function với SQL Trigger Binding (C# Serverless Event-Driven)

```csharp
using System.Collections.Generic;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Extensions.Sql;
using Microsoft.Extensions.Logging;

public class SqlTriggerHandler
{
    private readonly ILogger _logger;

    public SqlTriggerHandler(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<SqlTriggerHandler>();
    }

    // Tự động kích hoạt khi bảng dbo.Orders có dòng mới
    [Function("OnOrderCreated")]
    public void Run(
        [SqlTrigger("[dbo].[Orders]", "SqlConnectionString")] IReadOnlyList<SqlChange<OrderDto>> changes)
    {
        foreach (SqlChange<OrderDto> change in changes)
        {
            OrderDto order = change.Item;
            _logger.LogInformation($"[SQL TRIGGER] Đơn hàng mới ID: {order.OrderId}, Số tiền: {order.TotalAmount}");
            // Thực hiện gửi sự kiện sang Event Grid hoặc gửi Email thông báo
        }
    }
}

public record OrderDto(int OrderId, int CustomerId, decimal TotalAmount);
```

---

## 📝 PHẦN 3: CÂU HỎI THI THỬ & TÌNH HUỐNG (MOCK TEST QUESTIONS)

#### Question 1 (Data API Builder Secrets Management Scenario):
**Scenario:** You are deploying Data API builder (DAB) to Azure Container Apps to expose your Azure SQL Database as a REST and GraphQL API. Your company's security baseline strictly forbids storing plaintext database passwords inside repository code or JSON files. How should you configure the `data-source` connection string in `dab-config.json`?
- A. Hardcode the connection string inside the `dab-config.json` file.
- B. Set `"connection-string": "@env('DATABASE_CONNECTION_STRING')"` in `dab-config.json` and inject the connection string via Container App environment variables linked to Azure Key Vault.
- C. Store the connection string in a SQL Server System View `sys.dab_config`.
- D. Disable authentication on the Data API Builder endpoint.

**👉 Correct Answer: B**  
*Explanation (Giải thích):* Trong Data API builder (DAB), cú pháp **`@env('VARIABLE_NAME')`** Được sử dụng để đọc giá trị từ biến môi trường của hệ thống host (như Azure Container Apps hoặc Key Vault integration), giúp bảo vệ tuyệt đối không bị rò rỉ Connection String/Password trong mã nguồn tệp JSON.

---

#### Question 2 (Event-Driven Real-Time Data Change Scenario):
**Scenario:** You need to build an event-driven architecture where an external C# microservice is immediately executed whenever a new row is inserted into a table named `dbo.InventoryLogs` in Azure SQL Database. The solution must require minimal infrastructure code and run in a serverless model. Which Azure integration component should you use?
- A. Change Data Capture (CDC) with SSIS.
- B. Azure Functions with SQL Trigger binding (`[SqlTrigger]`).
- C. SQL Server Agent Job with PowerShell.
- D. PolyBase External Table.

**👉 Correct Answer: B**  
*Explanation (Giải thích):* **Azure Functions với SQL Trigger Binding (`[SqlTrigger]`)** là giải pháp Serverless event-driven chuẩn nhất của Azure cho phép tự động kích hoạt mã C#/Python/JS ngay lập tức khi có sự kiện `INSERT/UPDATE/DELETE` xảy ra tại bảng SQL Server mà không cần quản lý hạ tầng hay viết code polling thủ công.

---

#### Question 3 (DAB Exposing Stored Procedures Scenario):
**Scenario:** You have an existing complex T-SQL stored procedure `dbo.CalculateMonthlyBonus` in Azure SQL Database. You want to expose this stored procedure as an HTTP POST endpoint via Data API builder without modifying the procedure. How should you define this entity in `dab-config.json`?
- A. Set `"source": "dbo.CalculateMonthlyBonus"` and specify `"rest": { "methods": ["post"] }` under the entity definition.
- B. Rebuild the stored procedure as a Clustered Columnstore Index.
- C. Convert the stored procedure into a GraphQL Subscription.
- D. Call the stored procedure using `sp_invoke_external_rest_endpoint`.

**👉 Correct Answer: A**  
*Explanation (Giải thích):* Trong Data API builder (DAB), để expose một Stored Procedure thành API endpoint, ta định nghĩa entity có `"source"` chỉ tới tên SP và chỉ định phương thức HTTP trong phần `"rest": { "methods": ["post"] }`.
