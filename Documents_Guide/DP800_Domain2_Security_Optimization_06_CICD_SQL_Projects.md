# DP-800 Miền 2 — CI/CD với SQL Database Projects

> **Miền 2:** Bảo mật, tối ưu và triển khai giải pháp cơ sở dữ liệu (35–40%)  
> **Chủ đề:** Quản lý schema bằng Git, build DACPAC, kiểm thử và triển khai qua pipeline  
> **Cập nhật:** 09/08/2026  
> **Blueprint áp dụng:** DP-800 — Skills measured as of March 12, 2026  
> **Cập nhật cách trình bày:** 12/08/2026

## Vì sao cơ sở dữ liệu cũng cần CI/CD?

Nếu một DBA sửa trực tiếp bảng ở môi trường thật bằng SSMS nhưng không lưu thay đổi vào Git, nhóm phát triển sẽ không biết lược đồ thật đang khác mã nguồn ở điểm nào. Lần triển khai sau có thể ghi đè thay đổi, làm mất dữ liệu hoặc khiến ứng dụng và cơ sở dữ liệu không còn tương thích.

SQL Database Project giải quyết vấn đề đó bằng cách coi lược đồ như mã nguồn:

```text
Developer sửa file .sql trong branch
        ↓
Pull request để người khác xem lại
        ↓
Pipeline build và kiểm tra database model
        ↓
Tạo một file .dacpac đã được kiểm chứng
        ↓
Xem trước thay đổi và chặn thay đổi nguy hiểm
        ↓
Phê duyệt rồi mới triển khai vào database đích
```

Chương này không yêu cầu bạn trở thành chuyên gia DevOps. Bạn cần hiểu nguồn chuẩn nằm ở đâu, mỗi bước bảo vệ hệ thống khỏi lỗi gì, và vì sao không được lưu password hoặc sửa schema production tùy ý.

---

## 0. PHẠM VI THI CHÍNH THỨC

DP-800 yêu cầu:

- Chiến lược kiểm thử: **unit test và integration test**.
- Dữ liệu tham chiếu/tĩnh trong Git.
- SQL Database Projects, gồm **SDK-style models**.
- Quản lý mã nguồn.
- Branch, pull request và xử lý xung đột.
- Quản lý bí mật.
- Phát hiện schema drift — sai khác giữa schema thật và schema được quản lý.
- Cập nhật project và triển khai thay đổi.
- Kiểm soát quy trình: chính sách nhánh, phê duyệt, điều kiện kích hoạt, xác thực và người chịu trách nhiệm mã nguồn.

**Nguồn chuẩn:**
- [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
- [Microsoft Learn — Implement CI/CD by using SQL Database Projects](https://learn.microsoft.com/en-us/training/modules/implement-cicd-sql-database-projects/)

---

# PHẦN 1 — CÁCH HÌNH DUNG MỘT SQL DATABASE PROJECT

## 1. Mô hình khai báo trạng thái mong muốn

SQL project mô tả **trạng thái mong muốn** của database schema.

```text
.sql trong Git
      ↓ build bằng dotnet
Kiểm tra database model
      ↓
.dacpac
      ↓ SqlPackage / tác vụ triển khai
Database đích
```

**Nguồn chuẩn duy nhất** nên là mã trong Git và gói kết quả do quy trình CI/CD tạo ra, không phải các thay đổi tùy ý trên môi trường thật.

---

## 2. SDK-style `Microsoft.Build.Sql`

### 2.1 Vì sao kỳ thi quan tâm?

SDK-style project:
- cross-platform với modern .NET tooling,
- default globbing cho `.sql`,
- package references,
- build bằng `dotnet build`,
- output `.dacpac`.

Tính đến 09/08/2026, bản GA hiện hành của package Microsoft-owned **Microsoft.Build.Sql** là dòng 2.x; ví dụ 2.2.0 được phát hành tháng 06/2026. Không nên học thuộc version preview cũ như `0.1.12-preview`.

### 2.2 `.sqlproj` tối giản

```xml
<Project Sdk="Microsoft.Build.Sql/2.2.0">
  <PropertyGroup>
    <Name>DP800_DatabaseProject</Name>
    <DSP>Microsoft.Data.Tools.Schema.Sql.SqlAzureV12DatabaseSchemaProvider</DSP>
  </PropertyGroup>
</Project>
```

> Package version sẽ tiếp tục thay đổi; trong đời thực hãy kiểm tra NuGet/release hiện hành. Trong exam, trọng tâm là **SDK-style + Microsoft.Build.Sql + dotnet build + dacpac**, không phải thuộc số version.

### 2.3 Điểm khác biệt giữa các công cụ — cập nhật 2026

- Kiểu SDK `Microsoft.Build.Sql` là định dạng được ưu tiên cho dòng lệnh/VS Code và là hướng phát triển hiện đại.
- Tài liệu Microsoft hiện hành lưu ý **Visual Studio 2026 chỉ hỗ trợ định dạng SQL project nguyên bản**; kiểu SDK trong Visual Studio 2022 vẫn là thành phần Preview, trong khi VS Code hỗ trợ kiểu SDK tốt hơn.
- Trong kỳ thi, nếu câu hỏi hỏi **mô hình/định dạng project** hãy dựa vào yêu cầu, không suy luận rằng mọi IDE đều hỗ trợ kiểu SDK giống nhau.

Tham khảo:
- [SQL Database Projects](https://learn.microsoft.com/en-us/sql/tools/sql-database-projects/sql-database-projects?view=sql-server-ver17)
- [Microsoft.Build.Sql on NuGet](https://www.nuget.org/packages/Microsoft.Build.Sql)
- [SDK-style SQL projects tooling](https://learn.microsoft.com/en-us/sql/ssdt/sql-server-data-tools-sdk-style?view=sql-server-ver17)

---

# PHẦN 2 — TẠO, BIÊN DỊCH VÀ KIỂM TRA PROJECT

## 3. Quy trình dòng lệnh

Cài template nếu môi trường chưa có:

```bash
dotnet new install Microsoft.Build.Sql.Templates
```

Tạo project:

```bash
dotnet new sqlproj -n DP800_DatabaseProject
cd DP800_DatabaseProject
```

Ví dụ object file `Tables/Customer.sql`:

```sql
CREATE TABLE dbo.Customer
(
    CustomerId int IDENTITY(1,1) NOT NULL,
    FullName nvarchar(200) NOT NULL,
    Email nvarchar(320) NULL,
    CONSTRAINT PK_Customer PRIMARY KEY (CustomerId)
);
```

Build:

```bash
dotnet build
```

Kết quả quan trọng: `.dacpac`.

### Bước biên dịch phát hiện được lỗi gì?

- syntax/model errors,
- unresolved/broken object references trong phạm vi model,
- các lỗi model validation.

**Build thành công không chứng minh business logic đúng.** Vì thế blueprint còn yêu cầu unit/integration tests.

---

# PHẦN 3 — SCRIPT TRƯỚC/SAU TRIỂN KHAI VÀ DỮ LIỆU THAM CHIẾU

## 4. Dữ liệu tham chiếu hoặc dữ liệu tĩnh

DACPAC chủ yếu mô tả schema model. Lookup/reference rows thường được quản lý bằng **post-deployment script** để deployment idempotent.

### 4.1 File project

```xml
<ItemGroup>
  <PostDeploy Include="Scripts\Script.PostDeployment.sql" />
</ItemGroup>
```

Chỉ có một entry point post-deploy; file đó có thể include file con bằng SQLCMD `:r`.

`Scripts/Script.PostDeployment.sql`:

```sql
:r .\ReferenceData\OrderStatus.sql
:r .\ReferenceData\Currency.sql
```

Các script được `:r` nên được loại khỏi normal model build nếu project globbing bắt chúng như object scripts.

### 4.2 Nạp dữ liệu tham chiếu theo cách chạy lại vẫn an toàn bằng `MERGE`

```sql
PRINT N'Đồng bộ dbo.OrderStatus';

MERGE dbo.OrderStatus AS T
USING
(
    VALUES
      (1, N'Pending'),
      (2, N'Processing'),
      (3, N'Completed'),
      (4, N'Cancelled')
) AS S(StatusId, StatusName)
ON T.StatusId = S.StatusId
WHEN MATCHED
    AND T.StatusName <> S.StatusName
THEN UPDATE
    SET StatusName = S.StatusName
WHEN NOT MATCHED BY TARGET
THEN INSERT(StatusId, StatusName)
     VALUES(S.StatusId, S.StatusName);
GO
```

**Exam keyword:** “default lookup rows must exist after every deployment, no duplicates” → post-deployment idempotent script.

Tham khảo: [Pre/post-deployment scripts](https://learn.microsoft.com/en-us/sql/tools/sql-database-projects/concepts/pre-post-deployment-scripts?view=sql-server-ver17)

---

# PHẦN 4 — CHIẾN LƯỢC KIỂM THỬ

## 5. Ba tầng kiểm thử

| Tầng | Mục tiêu | Ví dụ |
|---|---|---|
| Build validation | schema compile/resolve được | `dotnet build` |
| Unit test | một SP/function trả đúng cho input xác định | test `usp_CalculateTax` |
| Integration test | nhiều đối tượng và bước xử lý phối hợp đúng | triển khai database test rồi chạy luồng tạo đơn hàng |

### 5.1 Mẫu kiểm thử đơn vị

```text
Arrange / Pre-test
    ↓
Act / Execute object
    ↓
Assert
    ↓
Cleanup / Reset
```

Ví dụ T-SQL test logic:

```sql
BEGIN TRAN;

BEGIN TRY
    -- Arrange
    INSERT dbo.OrderStatus(StatusId, StatusName)
    VALUES (99, N'Test');

    -- Act
    DECLARE @name nvarchar(100);
    SELECT @name = StatusName
    FROM dbo.OrderStatus
    WHERE StatusId = 99;

    -- Assert đơn giản
    IF @name <> N'Test'
        THROW 51000, 'Unit test failed', 1;

    ROLLBACK; -- cleanup
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK;
    THROW;
END CATCH;
GO
```

Trong ecosystem có SSDT database unit tests, tSQLt hoặc framework khác. **Exam hỏi strategy**, nên quan trọng là biết:
- unit = object logic cô lập,
- integration = deployed database + end-to-end behavior,
- tests không chạy production,
- reset state để repeatable.

Tham khảo: [Design and implement a testing strategy — Microsoft Learn](https://learn.microsoft.com/en-us/training/modules/implement-cicd-sql-database-projects/07-design-implement-testing-strategy)

---

# PHẦN 5 — GIT, NHÁNH, PULL REQUEST VÀ XUNG ĐỘT

## 6. Quy trình khuyến nghị

```text
main
 ↑ PR + review + CI
feature/order-discount
```

- Short-lived feature branch.
- Pull Request trước khi merge.
- CI build SQL project trên PR.
- Conflict được resolve trong source, sau đó **build/test lại**.
- Không “sửa trực tiếp production cho nhanh” rồi quên đưa lại source.

### CODEOWNERS

`.github/CODEOWNERS`:

```text
/Database/ @db-team
*.sql @db-team @dba-lead
```

**Exam keyword:** “DBA team must approve changes to SQL files” → CODEOWNERS/required reviewers.

---

# PHẦN 6 — SAI LỆCH LƯỢC ĐỒ (SCHEMA DRIFT): PHẦN DỄ HỌC SAI NHẤT

## 7. Sai lệch lược đồ là gì?

Live database khác source-controlled desired schema vì:
- hotfix trực tiếp,
- manual `ALTER`,
- deployment ngoài pipeline,
- artifact/source không đồng bộ.

## 7.1 Ba khái niệm phải phân biệt

### A. Schema Compare

So sánh project, DACPAC và database để xem điểm khác nhau. Cách này phù hợp để phát hiện hoặc đồng bộ sai lệch schema trong quá trình phát triển và quản trị.

### B. Trích xuất model rồi so với Git — quy trình phát hiện sai lệch tổng quát

Bạn có thể extract current database schema thành model/project rồi dùng Git diff/status để thấy thay đổi.

Ví dụ skeleton:

```bash
sqlpackage \
  /Action:Extract \
  /SourceConnectionString:"Server=tcp:<server>;Initial Catalog=<db>;Authentication=Active Directory Default;Encrypt=True" \
  /TargetFile:"CurrentDatabase.dacpac"
```

Sau đó so sánh model/DACPAC bằng công cụ phù hợp hoặc trích xuất thành project theo hướng dẫn Microsoft Learn.

### C. `/Action:DriftReport` — **registered DAC**

Đây là điểm cần sửa so với nhiều note cũ.

`DriftReport` tạo XML report về changes đã xảy ra trên một database **được đăng ký như Data-tier Application (DAC)** kể từ lúc nó được register/deploy state tương ứng. Không nên mô tả nó như “generic Git-vs-live comparison” cho mọi database.

```bash
sqlpackage \
  /Action:DriftReport \
  /TargetConnectionString:"Server=tcp:<server>;Initial Catalog=<db>;Authentication=Active Directory Default;Encrypt=True" \
  /OutputPath:"drift.xml"
```

> Nếu database không ở mô hình registered DAC phù hợp, hãy nghĩ đến Schema Compare / Extract + compare thay vì ép `DriftReport`.

### 7.2 Xem trước triển khai không phải báo cáo sai lệch

- `/Action:Script`: sinh deployment script.
- `/Action:DeployReport`: mô tả changes sẽ được deployment thực hiện.
- `/Action:Publish`: thực sự deploy.

**Bẫy thường gặp trong đề:**
- “What *would change* if dacpac is deployed?” → `DeployReport`/`Script`.
- “What changed ad hoc on a registered DAC?” → `DriftReport`.
- “Generic source vs live drift” → Schema Compare / extract+source comparison.

Tham khảo:
- [SqlPackage](https://learn.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage?view=sql-server-ver17)
- [SqlPackage DriftReport](https://learn.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage-drift-report?view=sql-server-ver17)
- [Schema Compare](https://learn.microsoft.com/en-us/sql/tools/sql-database-projects/concepts/schema-comparison?view=sql-server-ver17)

---

# PHẦN 7 — TRIỂN KHAI

## 8. Cài SqlPackage

```bash
dotnet tool install --global microsoft.sqlpackage
```

Update:

```bash
dotnet tool update --global microsoft.sqlpackage
```

### Xem trước thay đổi sẽ triển khai

Bước này tạo báo cáo triển khai hoặc script xem trước để nhóm biết chính xác schema sẽ thay đổi ra sao trước khi publish vào database đích.

```bash
sqlpackage \
  /Action:DeployReport \
  /SourceFile:"./bin/Release/DP800_DatabaseProject.dacpac" \
  /TargetConnectionString:"Server=tcp:<server>;Initial Catalog=<db>;Authentication=Active Directory Default;Encrypt=True" \
  /OutputPath:"deploy-report.xml"
```

### Thực hiện triển khai

```bash
sqlpackage \
  /Action:Publish \
  /SourceFile:"./bin/Release/DP800_DatabaseProject.dacpac" \
  /TargetConnectionString:"Server=tcp:<server>;Initial Catalog=<db>;Authentication=Active Directory Default;Encrypt=True"
```

**Best practice:** build một artifact, promote **cùng artifact** qua dev → test → staging → production thay vì build lại mỗi môi trường.

---

# PHẦN 8 — QUẢN LÝ BÍ MẬT VÀ CI/CD KHÔNG DÙNG MẬT KHẨU

## 9. Thứ tự ưu tiên

1. **OIDC/federated identity/passwordless** nếu platform hỗ trợ.
2. Managed identity trên self-hosted Azure runner/agent khi phù hợp.
3. Azure Key Vault / environment secrets.
4. Tránh SQL username/password lâu dài.
5. Tuyệt đối không hardcode secret trong YAML/Git.

### GitHub OIDC concept

`azure/login@v2` có thể dùng federated credentials:
- client ID
- tenant ID
- subscription ID

Không cần client secret nếu OIDC federation đã được cấu hình.

Federated credential phải giới hạn đúng **repository + branch/tag/environment subject**; OIDC không tự an toàn nếu trust expression quá rộng. `client-id`, `tenant-id`, `subscription-id` là identifiers, không phải passwords; có thể lưu trong repository/environment variables. Secret thực, nếu còn bắt buộc, phải nằm trong GitHub environment secret/Key Vault và không được in ra log.

Tham khảo: [GitHub Actions OIDC with Azure](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect)

---

# PHẦN 9 — QUY TRÌNH CI/CD HOÀN CHỈNH

## 10. GitHub Actions: biên dịch một lần, triển khai cùng một gói kết quả

```yaml
name: SQL Project CI-CD

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Build SQL project
        run: dotnet build ./DP800_DatabaseProject.sqlproj -c Release -o ./artifact

      - name: Upload dacpac
        uses: actions/upload-artifact@v4
        with:
          name: database-dacpac
          path: ./artifact/*.dacpac
          if-no-files-found: error

  deploy:
    if: github.event_name == 'push'
    needs: build
    runs-on: ubuntu-latest
    environment: production
    permissions:
      contents: read
      id-token: write
    concurrency:
      group: sql-production
      cancel-in-progress: false

    steps:
      - name: Download dacpac
        uses: actions/download-artifact@v4
        with:
          name: database-dacpac
          path: ./artifact

      - name: Azure login by OIDC
        uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - name: Install SqlPackage
        run: dotnet tool install --global microsoft.sqlpackage

      - name: Deployment report
        shell: bash
        run: |
          TARGET_CS="Server=tcp:${{ vars.AZURE_SQL_SERVER }},1433;Initial Catalog=${{ vars.AZURE_SQL_DATABASE }};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False"
          sqlpackage \
            /Action:DeployReport \
            /SourceFile:"./artifact/DP800_DatabaseProject.dacpac" \
            /TargetConnectionString:"$TARGET_CS" \
            /OutputPath:"deploy-report.xml"

      - name: Preserve deployment report
        uses: actions/upload-artifact@v4
        with:
          name: production-deploy-report
          path: deploy-report.xml
          if-no-files-found: error

      # Production publish nên đi sau environment approval/protection rule.
      - name: Publish
        shell: bash
        run: |
          TARGET_CS="Server=tcp:${{ vars.AZURE_SQL_SERVER }},1433;Initial Catalog=${{ vars.AZURE_SQL_DATABASE }};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False"
          sqlpackage \
            /Action:Publish \
            /SourceFile:"./artifact/DP800_DatabaseProject.dacpac" \
            /TargetConnectionString:"$TARGET_CS" \
            /p:BlockOnPossibleDataLoss=True
```

> Quy trình này minh họa cách **không dùng mật khẩu**: `azure/login` dùng OIDC và SqlPackage dùng xác thực Entra. Chỉ cấp `id-token: write` cho job triển khai, không cấp thừa cho job build của pull request. `concurrency` ngăn hai lần triển khai schema vào production chạy chồng nhau. Danh tính triển khai phải được tạo trong database đích và chỉ nhận các quyền cần thiết. Nếu công cụ cụ thể chưa hỗ trợ luồng này, dùng environment secret hoặc Key Vault thay vì ghi cứng credential.

> **Approval nuance:** GitHub environment approval diễn ra trước khi toàn bộ deploy job chạy. Nếu policy bắt buộc con người xem `DeployReport` rồi mới cho `Publish`, hãy tách preview và publish thành **hai jobs/environments**; publish job `needs` preview và có required reviewers. Chỉ đặt hai steps liên tiếp trong cùng một job không tạo ra approval gate ở giữa.

Microsoft Learn cũng nêu `azure/sql-action` cho GitHub Actions và `SqlAzureDacpacDeployment` cho Azure DevOps.

---

# PHẦN 10 — CÁC ĐIỂM KIỂM SOÁT KHI TRIỂN KHAI

## 11. Các điểm kiểm soát cần nhận diện

- Required PR reviewers.
- Build validation.
- Environment protection + required reviewers.
- Deployment branch restriction.
- `CODEOWNERS`.
- Approval gate trước production.
- Service connection / identity chỉ production pipeline được dùng.
- Least privilege cho deployment principal.
- Trigger rõ ràng: PR → validate; merge/main/tag → deploy tùy policy.

**Exam principle:** database pipeline là DevSecOps pipeline; “automate” không có nghĩa “bỏ review”.

---

# PHẦN 11 — BẢNG CHỌN GIẢI PHÁP

| Tình huống | Chọn |
|---|---|
| Tạo modern cross-platform SQL project | SDK-style `Microsoft.Build.Sql` |
| File `.sql` mới tự vào model | default globbing |
| Validate model | `dotnet build` |
| Artifact deploy | `.dacpac` |
| Lookup rows phải có sau deploy | post-deployment idempotent script |
| Xem changes trước publish | `/Action:DeployReport` hoặc `/Action:Script` |
| Thực thi deployment | `/Action:Publish` |
| Ad-hoc drift trên registered DAC | `/Action:DriftReport` |
| Generic project/live comparison | Schema Compare / Extract + compare |
| Secretless GitHub→Azure | OIDC/federated identity |
| DBA bắt buộc review SQL PR | CODEOWNERS + required reviewers |
| SP compile được nhưng logic có thể sai | unit test |
| Quy trình có nhiều đối tượng phối hợp | integration test |
| Production approval | environment/gate/reviewer controls |

---

# PHẦN 12 — CÂU HỎI TỰ KIỂM TRA

### Câu 1
Build `.sqlproj` thành công. Có chứng minh stored procedure tính đúng thuế không?

**Đáp án:** Không. Build validation chỉ xác nhận model/syntax/references; cần unit test cho logic.

### Câu 2
Bạn muốn xem deployment sẽ thay đổi production object nào nhưng không thay DB.

**Đáp án:** `DeployReport` hoặc `Script`, tùy yêu cầu về đầu ra.

### Câu 3
Lead DBA nói “DriftReport phải so Git repo với bất kỳ live DB nào”. Phát biểu này đúng?

**Đáp án:** Không hoàn toàn. `DriftReport` gắn với registered DAC. Khi cần so schema trong Git với database thật theo cách tổng quát, dùng Schema Compare hoặc quy trình trích xuất rồi so sánh.

### Câu 4
Project thêm file `Tables/NewTable.sql`, không sửa `.sqlproj`, vẫn build vào model. Tính năng?

**Đáp án:** Default globbing của SDK-style project.

### Câu 5
GitHub Action cần đăng nhập Azure nhưng policy cấm client secret.

**Đáp án:** OIDC/federated credentials với `azure/login`.

### Câu 6
Production chỉ deploy khi 2 DBA approve.

**Đáp án:** Environment protection/approval gate + required reviewers.

### Câu 7
Cần seed `CurrencyCodes` lặp lại nhiều lần mà không duplicate.

**Đáp án:** Post-deployment script idempotent (`MERGE`/equivalent safe pattern).

---

# PHẦN 13 — DANH SÁCH TỰ KIỂM TRA

- [ ] Tự tạo SDK-style `.sqlproj`.
- [ ] `dotnet build` và biết `.dacpac` là gì.
- [ ] Phân biệt build validation/unit/integration tests.
- [ ] Viết post-deployment reference data idempotent.
- [ ] Hiểu branch/PR/conflict/build lại.
- [ ] Phân biệt `Script`, `DeployReport`, `Publish`, `DriftReport`, `Extract`.
- [ ] Biết giới hạn “registered DAC” của `DriftReport`.
- [ ] Thiết kế OIDC/secrets/Key Vault.
- [ ] Viết GitHub Actions build→artifact→deploy.
- [ ] Thiết kế CODEOWNERS/approvals/branch protection.

---

# TÀI LIỆU THAM KHẢO

1. [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
2. [Implement CI/CD by using SQL Database Projects](https://learn.microsoft.com/en-us/training/modules/implement-cicd-sql-database-projects/)
3. [SQL Database Projects](https://learn.microsoft.com/en-us/sql/tools/sql-database-projects/sql-database-projects?view=sql-server-ver17)
4. [Microsoft.Build.Sql](https://www.nuget.org/packages/Microsoft.Build.Sql)
5. [SqlPackage](https://learn.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage?view=sql-server-ver17)
6. [DriftReport](https://learn.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage-drift-report?view=sql-server-ver17)
7. [GitHub Actions for SQL deployments — Microsoft Learn module](https://learn.microsoft.com/en-us/training/modules/implement-cicd-sql-database-projects/06-implement-cicd-pipelines)
8. [Testing strategy — Microsoft Learn module](https://learn.microsoft.com/en-us/training/modules/implement-cicd-sql-database-projects/07-design-implement-testing-strategy)
