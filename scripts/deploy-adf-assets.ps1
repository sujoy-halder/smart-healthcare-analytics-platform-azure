param(
  [Parameter(Mandatory = $true)]
  [string]$ResourceGroupName,
  [Parameter(Mandatory = $true)]
  [string]$DataFactoryName,
  [Parameter(Mandatory = $true)]
  [string]$AdlsAccountName,
  [Parameter(Mandatory = $true)]
  [string]$DatabricksWorkspaceUrl,
  [Parameter(Mandatory = $true)]
  [string]$DatabricksWorkspaceResourceId,
  [Parameter(Mandatory = $true)]
  [string]$DatabricksClusterId
)

$ErrorActionPreference = "Stop"
$normalizedDatabricksWorkspaceUrl = $DatabricksWorkspaceUrl.TrimEnd("/")
if (-not $normalizedDatabricksWorkspaceUrl.StartsWith("https://", [System.StringComparison]::OrdinalIgnoreCase)) {
  $normalizedDatabricksWorkspaceUrl = "https://$normalizedDatabricksWorkspaceUrl"
}

function New-TemporaryAdfAsset {
  param(
    [string]$Path,
    [switch]$PropertiesOnly
  )
  $content = Get-Content $Path -Raw
  $content = $content.Replace("<ADLS_ACCOUNT_NAME>", $AdlsAccountName)
  $content = $content.Replace("<DATABRICKS_WORKSPACE_URL>", $normalizedDatabricksWorkspaceUrl)
  $content = $content.Replace("<SUBSCRIPTION_ID>", (az account show --query id -o tsv))
  $content = $content.Replace("<RESOURCE_GROUP_NAME>", $ResourceGroupName)
  $content = $content.Replace("<DATABRICKS_WORKSPACE_NAME>", (Split-Path $DatabricksWorkspaceResourceId -Leaf))
  $content = $content.Replace("<DATABRICKS_CLUSTER_ID>", $DatabricksClusterId)

  if ($PropertiesOnly) {
    $parsed = $content | ConvertFrom-Json
    if (-not $parsed.properties) {
      throw "ADF asset $Path does not contain a top-level properties object."
    }
    $content = $parsed.properties | ConvertTo-Json -Depth 100
  }

  $temp = Join-Path $env:TEMP ([System.IO.Path]::GetRandomFileName() + ".json")
  $content | Out-File -FilePath $temp -Encoding utf8
  return $temp
}

foreach ($linkedService in Get-ChildItem adf/linkedServices -Filter *.json) {
  $asset = New-TemporaryAdfAsset -Path $linkedService.FullName -PropertiesOnly
  try {
    az datafactory linked-service create `
      --resource-group $ResourceGroupName `
      --factory-name $DataFactoryName `
      --name $linkedService.BaseName `
      --properties "@$asset"
  } finally {
    Remove-Item -LiteralPath $asset -Force
  }
}

foreach ($dataset in Get-ChildItem adf/datasets -Filter *.json) {
  $asset = New-TemporaryAdfAsset -Path $dataset.FullName -PropertiesOnly
  try {
    az datafactory dataset create `
      --resource-group $ResourceGroupName `
      --factory-name $DataFactoryName `
      --name $dataset.BaseName `
      --properties "@$asset"
  } finally {
    Remove-Item -LiteralPath $asset -Force
  }
}

az datafactory pipeline create `
  --resource-group $ResourceGroupName `
  --factory-name $DataFactoryName `
  --name healthcare_ingestion_pipeline `
  --pipeline "@adf/pipelines/healthcare_ingestion_pipeline.json"

$trigger = New-TemporaryAdfAsset -Path "adf/triggers/fifteen_minute_healthcare_ingestion.json" -PropertiesOnly
try {
  az datafactory trigger create `
    --resource-group $ResourceGroupName `
    --factory-name $DataFactoryName `
    --name fifteen_minute_healthcare_ingestion `
    --properties "@$trigger"
} finally {
  Remove-Item -LiteralPath $trigger -Force
}
