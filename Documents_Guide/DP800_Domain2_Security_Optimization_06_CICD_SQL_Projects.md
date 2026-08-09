# DP-800 Domain 2: Implement CI/CD by Using SQL Database Projects

> **Miền 2:** Secure, Optimize, and Deploy Database Solutions (35–40%)  
> **Chủ đề:** Implement CI/CD by Using SQL Database Projects  
> **Trọng tâm thi:** SDK-Style SQL Projects (`Microsoft.Build.Sql`), Schema Drift Detection (`SqlPackage /Action:DriftReport`), Reference/Static Data với `MERGE` Post-Deployment, Secret Management, Deployment Controls.

---

## 📘 PHẦN 1: LÝ THUYẾT & KIẾN THỨC CỐT LÕI (CORE THEORY)

### 1. Kiến Trúc SQL Database Projects SDK-Style (`Microsoft.Build.Sql`)
- **SDK-Style SQL Project là gì?**  
  Là định dạng Project CSDL chuẩn mới chạy trên **.NET 8 SDK**, sử dụng Package `Microsoft.Build.Sql`. Nhẹ hơn rất nhiều so với định dạng legacy MSBuild (.sqlproj cũ).
- **Tính năng Default Globbing:** Tự động đưa toàn bộ các tệp `.sql` trong thư mục project vào quá trình biên dịch mà không cần khai báo danh sách từng file trong tệp cấu hình `.sqlproj`.
- **Nguyên lý "Source of Truth":** Mã nguồn trong Git Repository là chuẩn duy nhất đại diện cho CSDL. Live Database chỉ là bản triển khai từ artifact biên dịch (`.dacpac`).

### 2. Phát Hiện Sai Lệch Cấu Trúc (Schema Drift Detection)
- **Khái niệm Schema Drift:** Xảy ra khi có ai đó truy cập trực tiếp Live Database và thực hiện lệnh sửa đổi ad-hoc (`ALTER TABLE`, `DROP INDEX...`), khiến cấu trúc Live DB bị lệch so với code lưu trong Git.
- **Công cụ `SqlPackage.exe` & Các Action Quan Trọng:**
  - `/Action:DriftReport`: Tạo báo cáo dạng XML ghi nhận các khác biệt giữa Live DB và DACPAC **mà không làm thay đổi hay ảnh hưởng đến Live Database**.
  - `/Action:DeployReport`: Sinh script XML liệt kê các thay đổi sẽ diễn ra khi Deploy.
  - `/Action:Script`: Sinh file script T-SQL chuyển đổi (`.sql`) để review thủ công trước khi chạy.
  - `/Action:Publish`: Thực thi cập nhật DACPAC vào CSDL thật.

### 3. Quản Lý Dữ Liệu Tĩnh / Danh Mục (Reference & Static Data Management)
- DACPAC chỉ biên dịch và đồng bộ cấu trúc Schema, không tự động chứa dữ liệu bảng.
- **Giải pháp:** Sử dụng **Post-Deployment Script (`Script.PostDeployment.sql`)** kết hợp lệnh **`MERGE`** để chèn/cập nhật dữ liệu danh mục (Lookup Data như Mã Tỉnh Thành, Loại Tiền Tệ) một cách an toàn mà không làm mất dữ liệu hiện tại.

### 4. Kiểm Thử CSDL & Quản Lý Bí Mật trong Pipeline
- **Kiểm thử (Testing Strategy):**
  - *Unit Test:* Kiểm thử các hàm UDF, Stored Procedure cô lập (dùng framework tSQLt).
  - *Integration Test:* Kiểm thử luồng tích hợp với CSDL thật trong đợt Build Pipeline.
- **Quản lý bí mật (Secrets Management):** Sử dụng **Azure Key Vault Task** trong GitHub Actions / Azure DevOps Pipeline để nạp Connection String và Mật khẩu dưới dạng biến môi trường bảo mật (`@env('DB_PASS')`), tuyệt đối không commit password vào Git.

### 5. Kiểm Soát Triển Khai (Deployment Pipeline Controls)
- Thiết lập **Branch Policies** (bắt buộc Pull Request, không commit trực tiếp vào `main`).
- Thiết lập **CODEOWNERS** yêu cầu Lead DBA phê duyệt PR khi có thay đổi cấu trúc bảng core.
- Thiết lập **Approval Gates** trước khi Deploy lên môi trường Production.

---

## 💻 PHẦN 2: MÃ CẤU HÌNH & PIPELINE (HANDS-ON CONFIGS & YAML)

### 1. Tệp `.sqlproj` Chuẩn SDK-Style (`Microsoft.Build.Sql`)

```xml
<Project Sdk="Microsoft.Build.Sql/0.1.12-preview">
  <PropertyGroup>
    <Name>DP800_DatabaseProject</Name>
    <DSP>Microsoft.Data.Tools.Schema.Sql.SqlAzureV12DatabaseSchemaProvider</DSP>
    <ModelBuilderType>MSDeploy</ModelBuilderType>
    <TargetDatabaseSet>True</TargetDatabaseSet>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
</Project>
```

### 2. Tệp Post-Deployment Script (`Script.PostDeployment.sql`) Dùng `MERGE`

```sql
-- ============================================================================
-- SCRIPT POST-DEPLOYMENT ĐỒNG BỘ DỮ LIỆU TĨNH
-- ============================================================================
PRINT N'Đang đồng bộ dữ liệu tĩnh cho bảng dbo.OrderStatus...';

MERGE INTO dbo.OrderStatus AS Target
USING (VALUES 
    (1, N'Pending', N'Đơn hàng mới tạo'),
    (2, N'Processing', N'Đang xử lý thanh toán'),
    (3, N'Completed', N'Hoàn tất giao hàng'),
    (4, N'Cancelled', N'Đã hủy')
) AS Source (StatusId, StatusName, Description)
ON Target.StatusId = Source.StatusId
WHEN MATCHED THEN
    UPDATE SET Target.StatusName = Source.StatusName, Target.Description = Source.Description
WHEN NOT MATCHED BY TARGET THEN
    INSERT (StatusId, StatusName, Description)
    VALUES (Source.StatusId, Source.StatusName, Source.Description);
GO
```

### 3. Pipeline YAML (GitHub Actions) - Phát Hiện Schema Drift & Publish DACPAC

```yaml
name: CI-CD SQL Database Project

on:
  push:
    branches: [ main ]

jobs:
  build-and-detect-drift:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    # 1. Build SDK-Style Project ra file .dacpac
    - name: Build SQL Project
      run: dotnet build ./DP800_DatabaseProject.sqlproj -c Release

    # 2. Phát hiện Schema Drift trên Live Database
    - name: Detect Schema Drift
      run: |
        SqlPackage /Action:DriftReport \
          /SourceServerName:"${{ secrets.DB_SERVER }}" \
          /SourceDatabaseName:"${{ secrets.DB_NAME }}" \
          /SourceUser:"${{ secrets.DB_USER }}" \
          /SourcePassword:"${{ secrets.DB_PASS }}" \
          /OutputPath:"./drift_report.xml"

    # 3. Publish DACPAC lên Azure SQL Database
    - name: Deploy DACPAC
      run: |
        SqlPackage /Action:Publish \
          /SourceFile:"./bin/Release/net8.0/DP800_DatabaseProject.dacpac" \
          /TargetServerName:"${{ secrets.DB_SERVER }}" \
          /TargetDatabaseName:"${{ secrets.DB_NAME }}" \
          /TargetUser:"${{ secrets.DB_USER }}" \
          /TargetPassword:"${{ secrets.DB_PASS }}"
```

---

## 📝 PHẦN 3: CÂU HỎI THI THỬ & TÌNH HUỐNG (MOCK TEST QUESTIONS)

#### Question 1 (Schema Drift Detection Scenario):
**Scenario:** You are managing a CI/CD deployment pipeline for an SDK-style SQL Database Project using Azure DevOps. Before executing a deployment to Production, the lead DBA requests an automated check to verify whether anyone made manual, unauthorized schema changes directly on the production database. The check must generate a report without modifying the production database structure or data. Which `SqlPackage.exe` action should you run?
- A. `/Action:Publish`
- B. `/Action:DriftReport`
- C. `/Action:DeployReport`
- D. `/Action:Export`

**👉 Correct Answer: B**  
*Explanation (Giải thích):* Lệnh `SqlPackage.exe /Action:DriftReport` So sánh cấu trúc thực tế của Live Production Database với mô hình DACPAC và tạo ra tệp báo cáo XML liệt kê các điểm sai lệch (Schema Drift) **mà hoàn toàn không làm thay đổi hay sửa đổi CSDL**.

---

#### Question 2 (Reference Data Management Scenario):
**Scenario:** You maintain a lookup table `dbo.CurrencyCodes` in your SQL Database Project. You need to ensure that whenever the project is deployed, default reference rows (USD, EUR, VND) are inserted or updated without deleting existing transactional records or causing duplicate key errors. What object should you add to the SQL Project?
- A. A Pre-Deployment Script containing `TRUNCATE TABLE dbo.CurrencyCodes`.
- B. A Post-Deployment Script containing a `MERGE` statement.
- C. A Clustered Columnstore Index on `dbo.CurrencyCodes`.
- D. An AFTER INSERT Trigger on the base table.

**👉 Correct Answer: B**  
*Explanation (Giải thích):* Chuẩn tốt nhất để quản lý dữ liệu danh mục tĩnh (Reference/Static Data) trong SQL Database Project là đặt câu lệnh **`MERGE`** bên trong **Post-Deployment Script (`Script.PostDeployment.sql`)**. Cấu trúc `MERGE` giúp cập nhật dữ liệu nếu đã có hoặc chèn mới nếu chưa có một cách an toàn (Idempotent).

---

#### Question 3 (SDK-Style SQL Project Feature Scenario):
**Scenario:** Your development team is migrating legacy `.sqlproj` files to the modern SDK-style SQL Project format (`Microsoft.Build.Sql`). Which advantage does the SDK-style format provide regarding script file management?
- A. It automatically encrypts all `.sql` files using Always Encrypted.
- B. It uses default globbing, so adding new `.sql` files to the directory automatically includes them in the project build without editing project files.
- C. It removes the need for `SqlPackage.exe`.
- D. It disables git version control automatically.

**👉 Correct Answer: B**  
*Explanation (Giải thích):* Dự án SQL Database Project SDK-Style (`Microsoft.Build.Sql`) hỗ trợ tính năng **Default Globbing**, tự động quét và bao gồm tất cả các file `.sql` mới tạo trong thư mục dự án vào quá trình biên dịch mà không cần người dùng phải khai báo thủ công từng file trong tệp `.sqlproj`.
