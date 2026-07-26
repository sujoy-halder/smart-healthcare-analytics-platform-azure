# Deployment Runbook

## Prerequisites

- Azure subscription with permissions to create Resource Groups, AKS, ACR,
  Event Hubs, ADLS Gen2, Key Vault, Data Factory, Private Endpoints, role
  assignments, Log Analytics, and Azure Databricks.
- Local or runner tools: Azure CLI, Terraform, Docker, Helm, kubectl, Python,
  dbt, and Databricks CLI.
- Remote Terraform state storage account and container already created.
- Microsoft Entra group object ID for AKS administrators.
- Snowflake account, warehouses, roles, and key-pair authentication for dbt.
- Databricks CLI and bundle authentication for DLT deployment.
- Informatica org and secure agents for Epic, Cerner, payer, SQL Server, Oracle,
  SFTP, and API connectors.
- A private self-hosted GitHub Actions runner, or equivalent private deployment
  runner, with DNS/network access to the private endpoints, ACR, private AKS API,
  Terraform backend, Key Vault, Event Hubs, and ADLS Gen2.

## Local Validation

```powershell
python -m pip install -r requirements-dev.txt
python -m pip install -r requirements-dbt.txt
.\scripts\validate-local.ps1 -SkipDocker
```

Run without `-SkipDocker` when Docker Desktop is available.

## Azure Infrastructure

Copy the example tfvars and replace every placeholder:

```powershell
copy terraform\environments\dev\terraform.tfvars.example terraform\environments\dev\terraform.tfvars
notepad terraform\environments\dev\terraform.tfvars
```

Plan:

```powershell
.\scripts\deploy-azure.ps1 `
  -Environment dev `
  -BackendResourceGroup rg-terraform-state `
  -BackendStorageAccount shapterraformstate
```

Apply:

```powershell
.\scripts\deploy-azure.ps1 `
  -Environment dev `
  -BackendResourceGroup rg-terraform-state `
  -BackendStorageAccount shapterraformstate `
  -Apply `
  -ImageTag 0.1.0
```

## Data Factory Assets

After Terraform creates the Data Factory, deploy the pipeline and trigger:

```powershell
.\scripts\deploy-adf-assets.ps1 `
  -ResourceGroupName rg-shap-dev `
  -DataFactoryName adf-shap-dev-xxxxxx `
  -AdlsAccountName shapdevlake `
  -DatabricksWorkspaceUrl https://adb-xxxxxxxx.azuredatabricks.net `
  -DatabricksWorkspaceResourceId /subscriptions/<subscription-id>/resourceGroups/rg-shap-dev/providers/Microsoft.Databricks/workspaces/dbw-shap-dev `
  -DatabricksClusterId <cluster-id>
```

## Databricks DLT

Replace workspace and ADLS values in `databricks/bundle.yml`, then deploy:

```powershell
databricks bundle validate -t dev
databricks bundle deploy -t dev
databricks bundle run healthcare_dlt -t dev
```

## Snowflake and dbt

Run the SQL files in `snowflake/sql` in order, then configure dbt:

```powershell
copy dbt\profiles.yml.example dbt\profiles.yml
notepad dbt\profiles.yml
cd dbt
dbt deps
dbt parse
dbt run
dbt test
```

## Live Smoke Tests

After AKS deploy:

```powershell
kubectl -n healthcare-dev get pods
kubectl -n healthcare-dev rollout status deploy/healthcare-healthcare-platform-api
kubectl -n healthcare-dev port-forward svc/healthcare-healthcare-platform-api 8080:80
curl http://127.0.0.1:8080/healthz
```

Cloud success should only be claimed after Terraform apply, AKS rollout checks,
Databricks pipeline run, Snowflake/dbt execution, ADF trigger execution,
Informatica secure-agent connectivity, and monitoring alert evaluation pass in
the target account.
