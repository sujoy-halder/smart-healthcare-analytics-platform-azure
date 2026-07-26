param(
  [ValidateSet("dev", "prod")]
  [string]$Environment = "dev",
  [switch]$Apply,
  [string]$BackendResourceGroup,
  [string]$BackendStorageAccount,
  [string]$BackendContainer = "tfstate",
  [string]$ImageTag = "0.1.0"
)

$ErrorActionPreference = "Stop"

if (-not $BackendResourceGroup -or -not $BackendStorageAccount) {
  throw "Provide -BackendResourceGroup and -BackendStorageAccount for the remote Terraform backend."
}

$tfRoot = "terraform/environments/$Environment"
$env:TF_DATA_DIR = Join-Path $env:TEMP "shap-tfdata-$Environment"

Push-Location $tfRoot
try {
  terraform init `
    -backend-config="resource_group_name=$BackendResourceGroup" `
    -backend-config="storage_account_name=$BackendStorageAccount" `
    -backend-config="container_name=$BackendContainer" `
    -backend-config="key=smart-healthcare-$Environment.tfstate"

  terraform plan -out=tfplan
  if ($Apply) {
    terraform apply -auto-approve tfplan
    terraform output -json deployment_summary | Out-File -Encoding utf8 deployment-summary.json
  }
} finally {
  Pop-Location
}

if (-not $Apply) {
  Write-Host "Plan completed. Re-run with -Apply to deploy Azure resources and workloads."
  exit 0
}

$summary = Get-Content "$tfRoot/deployment-summary.json" | ConvertFrom-Json
$acr = $summary.acr_login_server
$namespace = "healthcare-$Environment"

az acr login --name ($acr -replace "\.azurecr\.io$", "")

foreach ($service in @("healthcare-api", "etl-service", "notification-service")) {
  docker build -f "services/$service/Dockerfile" -t "$acr/$service`:$ImageTag" .
  docker push "$acr/$service`:$ImageTag"
}

az aks get-credentials --resource-group $summary.resource_group_name --name $summary.aks_name --overwrite-existing

helm upgrade --install healthcare helm-charts/healthcare-platform `
  --namespace $namespace `
  --create-namespace `
  --set "global.imageRegistry=$acr" `
  --set "global.imageTag=$ImageTag" `
  --set "azure.workloadIdentityClientId=$($summary.workload_identity_client_id)" `
  --set "azure.keyVaultName=$($summary.key_vault_name)" `
  --set "azure.eventHubNamespace=$($summary.eventhub_namespace_name)" `
  --set "azure.adlsAccountName=$($summary.adls_account_name)"

kubectl -n $namespace rollout status deploy/healthcare-healthcare-platform-api --timeout=180s
kubectl -n $namespace rollout status deploy/healthcare-healthcare-platform-notification --timeout=180s
