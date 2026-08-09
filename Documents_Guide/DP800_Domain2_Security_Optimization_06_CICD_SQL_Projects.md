# DP-800 Domain 2: Implement CI/CD by Using SQL Database Projects

> **Miền 2:** Secure, Optimize, and Deploy Database Solutions (35–40%)  
> **Chủ đề:** Implement CI/CD by Using SQL Database Projects  
> **Cập nhật:** 09/08/2026  
> **Blueprint áp dụng:** DP-800 — Skills measured as of March 12, 2026  
> **Mục tiêu:** Biến database schema thành source-controlled artifact có thể build, test, review và deploy lặp lại.

---

## 0. PHẠM VI THI CHÍNH THỨC

DP-800 yêu cầu:

- Testing strategy: **unit tests + integration tests**.
- Reference/static data trong source control.
- SQL Database Projects, gồm **SDK-style models**.
- Source control.
- Branching, pull requests, conflict resolution.
- Secrets management.
- Schema drift detection.
- Update project và deploy changes.
- Deployment pipeline controls: branch policies, approvals/triggers, authentication, code owners.

**Nguồn chuẩn:**
- [DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)
- [Microsoft Learn — Implement CI/CD by using SQL Database Projects](https://learn.microsoft.com/en-us/training/modules/implement-cicd-sql-database-projects/)

---

# PHẦN 1 — SQL DATABASE PROJECT MENTAL MODEL

## 1. Declarative model

SQL project mô tả **trạng thái mong muốn** của database schema.

```text
.sql files trong Git
      ↓ dotnet build
Database model validation
      ↓
.dacpac
      ↓ SqlPackage / deployment task
Target database
```

**Source of truth** nên là source control + project artifact, không phải các thay đổi ad-hoc trên production.

---

## 2. SDK-style `Microsoft.Build.Sql`

### 2.1 Vì sao exam quan tâm?

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

### 2.3 Tooling nuance cập nhật 2026

- SDK-style `Microsoft.Build.Sql` là định dạng được ưu tiên cho command line/VS Code và là hướng phát triển hiện đại.
- Current Microsoft docs lưu ý **Visual Studio 2026 chỉ hỗ trợ original SQL project format**; SDK-style trong Visual Studio 2022 vẫn là component preview, trong khi VS Code hỗ trợ SDK-style tốt hơn.
- Trong kỳ thi, nếu câu hỏi hỏi **model/project format** hãy dựa vào requirement, không suy luận rằng mọi IDE đều hỗ trợ SDK-style giống nhau.

Tham khảo:
- [SQL Database Projects](https://learn.microsoft.com/en-us/sql/tools/sql-database-projects/sql-database-projects?view=sql-server-ver17)
- [Microsoft.Build.Sql on NuGet](https://www.nuget.org/packages/Microsoft.Build.Sql)
- [SDK-style SQL projects tooling](https://learn.microsoft.com/en-us/sql/ssdt/sql-server-data-tools-sdk-style?view=sql-server-ver17)

---

# PHẦN 2 — CREATE, BUILD, VALIDATE

## 3. CLI workflow

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

### Build validation bắt được gì?

- syntax/model errors,
- unresolved/broken object references trong phạm vi model,
- các lỗi model validation.

**Build thành công không chứng minh business logic đúng.** Vì thế blueprint còn yêu cầu unit/integration tests.

---

# PHẦN 3 — PRE/POST-DEPLOYMENT & REFERENCE DATA

## 4. Reference/static data

DACPAC chủ yếu mô tả schema model. Lookup/reference rows thường được quản lý bằng **post-deployment script** để deployment idempotent.

### 4.1 Project file

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

### 4.2 Idempotent reference data bằng `MERGE`

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

# PHẦN 4 — TESTING STRATEGY

## 5. Ba tầng test

| Tầng | Mục tiêu | Ví dụ |
|---|---|---|
| Build validation | schema compile/resolve được | `dotnet build` |
| Unit test | một SP/function trả đúng cho input xác định | test `usp_CalculateTax` |
| Integration test | nhiều object/workflow phối hợp đúng | deploy DB test rồi chạy order flow |

### 5.1 Unit test pattern

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

# PHẦN 5 — SOURCE CONTROL, BRANCH, PR, CONFLICTS

## 6. Workflow khuyến nghị

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

# PHẦN 6 — SCHEMA DRIFT: PHẦN DỄ HỌC SAI NHẤT

## 7. Schema drift là gì?

Live database khác source-controlled desired schema vì:
- hotfix trực tiếp,
- manual `ALTER`,
- deployment ngoài pipeline,
- artifact/source không đồng bộ.

## 7.1 Ba khái niệm phải phân biệt

### A. Schema Compare

So sánh project/dacpac/database và xem differences. Phù hợp để phát hiện/sync drift trong development/admin workflow.

### B. Extract model rồi so Git — generic drift workflow

Bạn có thể extract current database schema thành model/project rồi dùng Git diff/status để thấy thay đổi.

Ví dụ skeleton:

```bash
sqlpackage \
  /Action:Extract \
  /SourceConnectionString:"Server=tcp:<server>;Initial Catalog=<db>;Authentication=Active Directory Default;Encrypt=True" \
  /TargetFile:"CurrentDatabase.dacpac"
```

Sau đó compare model/dacpac bằng tooling phù hợp hoặc extract project form theo workflow Microsoft Learn.

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

### 7.2 Deploy preview ≠ Drift

- `/Action:Script`: sinh deployment script.
- `/Action:DeployReport`: mô tả changes sẽ được deployment thực hiện.
- `/Action:Publish`: thực sự deploy.

**Exam trap:**
- “What *would change* if dacpac is deployed?” → `DeployReport`/`Script`.
- “What changed ad hoc on a registered DAC?” → `DriftReport`.
- “Generic source vs live drift” → Schema Compare / extract+source comparison.

Tham khảo:
- [SqlPackage](https://learn.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage?view=sql-server-ver17)
- [SqlPackage DriftReport](https://learn.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage-drift-report?view=sql-server-ver17)
- [Schema Compare](https://learn.microsoft.com/en-us/sql/tools/sql-database-projects/concepts/schema-comparison?view=sql-server-ver17)

---

# PHẦN 7 — DEPLOYMENT

## 8. Install SqlPackage

```bash
dotnet tool install --global microsoft.sqlpackage
```

Update:

```bash
dotnet tool update --global microsoft.sqlpackage
```

### Preview deployment

```bash
sqlpackage \
  /Action:DeployReport \
  /SourceFile:"./bin/Release/DP800_DatabaseProject.dacpac" \
  /TargetConnectionString:"Server=tcp:<server>;Initial Catalog=<db>;Authentication=Active Directory Default;Encrypt=True" \
  /OutputPath:"deploy-report.xml"
```

### Publish

```bash
sqlpackage \
  /Action:Publish \
  /SourceFile:"./bin/Release/DP800_DatabaseProject.dacpac" \
  /TargetConnectionString:"Server=tcp:<server>;Initial Catalog=<db>;Authentication=Active Directory Default;Encrypt=True"
```

**Best practice:** build một artifact, promote **cùng artifact** qua dev → test → staging → production thay vì build lại mỗi môi trường.

---

# PHẦN 8 — SECRETS & PASSWORDLESS CI/CD

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

Tham khảo: [GitHub Actions OIDC with Azure](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect)

---

# PHẦN 9 — PIPELINE HOÀN CHỈNH

## 10. GitHub Actions: build một lần, deploy artifact

```yaml
name: SQL Project CI-CD

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest

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

  deploy:
    if: github.event_name == 'push'
    needs: build
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Download dacpac
        uses: actions/download-artifact@v4
        with:
          name: database-dacpac
          path: ./artifact

      - name: Azure login by OIDC
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Install SqlPackage
        run: dotnet tool install --global microsoft.sqlpackage

      - name: Deployment report
        shell: bash
        run: |
          TARGET_CS="Server=tcp:${{ vars.AZURE_SQL_SERVER }},1433;Initial Catalog=${{ vars.AZURE_SQL_DATABASE }};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False"
          sqlpackage \
            /Action:DeployReport \
            /SourceFile:"$(find ./artifact -name '*.dacpac' | head -1)" \
            /TargetConnectionString:"$TARGET_CS" \
            /OutputPath:"deploy-report.xml"

      # Production publish nên đi sau environment approval/protection rule.
      - name: Publish
        shell: bash
        run: |
          TARGET_CS="Server=tcp:${{ vars.AZURE_SQL_SERVER }},1433;Initial Catalog=${{ vars.AZURE_SQL_DATABASE }};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False"
          sqlpackage \
            /Action:Publish \
            /SourceFile:"$(find ./artifact -name '*.dacpac' | head -1)" \
            /TargetConnectionString:"$TARGET_CS"
```

> Workflow này minh họa hướng **passwordless**: `azure/login` dùng OIDC và SqlPackage dùng Entra authentication. Deployment principal/service principal phải được tạo trong target database và chỉ được cấp quyền deployment cần thiết. Nếu môi trường/tooling cụ thể không hỗ trợ luồng này, dùng environment secret/Key Vault thay vì hardcode credential.

Microsoft Learn cũng nêu `azure/sql-action` cho GitHub Actions và `SqlAzureDacpacDeployment` cho Azure DevOps.

---

# PHẦN 10 — DEPLOYMENT CONTROLS

## 11. Controls cần nhận diện

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

# PHẦN 11 — DECISION TABLE ĐI THI

| Scenario | Chọn |
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
| Workflow nhiều object | integration test |
| Production approval | environment/gate/reviewer controls |

---

# PHẦN 12 — MOCK QUESTIONS

### Câu 1
Build `.sqlproj` thành công. Có chứng minh stored procedure tính đúng thuế không?

**Đáp án:** Không. Build validation chỉ xác nhận model/syntax/references; cần unit test cho logic.

### Câu 2
Bạn muốn xem deployment sẽ thay đổi production object nào nhưng không thay DB.

**Đáp án:** `DeployReport` hoặc `Script` tùy output requirement.

### Câu 3
Lead DBA nói “DriftReport phải so Git repo với bất kỳ live DB nào”. Phát biểu này đúng?

**Đáp án:** Không hoàn toàn. `DriftReport` gắn với registered DAC. Generic source/live drift nên dùng Schema Compare hoặc extract/compare workflow.

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

# PHẦN 13 — CHECKLIST “EXAM READY”

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
