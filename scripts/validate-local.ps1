param(
  [switch]$SkipDocker,
  [switch]$SkipTerraformInit,
  [switch]$SkipAudit,
  [switch]$SkipDbt
)

$ErrorActionPreference = "Stop"

function Test-Command {
  param([string]$Name)
  $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-Step {
  param(
    [string]$Name,
    [scriptblock]$Script
  )
  Write-Host "==> $Name"
  & $Script
}

Invoke-Step "Python tests" {
  python -m pip install -e .
  python -m pytest
}

Invoke-Step "Python compile" {
  python -m compileall -q src services tests
}

if (Test-Command ruff) {
  Invoke-Step "Ruff lint" {
    ruff check .
  }
} else {
  Write-Host "SKIP ruff: command not found"
}

if (-not $SkipAudit -and (Test-Command pip-audit)) {
  foreach ($requirements in @(
    "requirements-dev.txt",
    "requirements-dbt.txt",
    "services/healthcare-api/requirements.txt",
    "services/etl-service/requirements.txt",
    "services/notification-service/requirements.txt"
  )) {
    Invoke-Step "pip-audit $requirements" {
      pip-audit -r $requirements
    }
  }
} else {
  Write-Host "SKIP pip-audit: command not found or SkipAudit supplied"
}

Invoke-Step "JSON and YAML parse" {
  python -c "import json, pathlib, yaml; [json.loads(p.read_text(encoding='utf-8')) for p in pathlib.Path('.').rglob('*.json')]; yaml_paths=list(pathlib.Path('.').rglob('*.yaml')) + list(pathlib.Path('.').rglob('*.yml')); [list(yaml.safe_load_all(p.read_text(encoding='utf-8'))) for p in yaml_paths if not ('helm-charts' in p.parts and 'templates' in p.parts)]"
}

if (Test-Command terraform) {
  Invoke-Step "Terraform fmt" {
    terraform fmt -check -recursive terraform
  }
  foreach ($envName in @("dev", "prod")) {
    Invoke-Step "Terraform validate $envName" {
      Push-Location "terraform/environments/$envName"
      try {
        $env:TF_DATA_DIR = Join-Path $env:TEMP "shap-tfdata-$envName"
        if (-not $SkipTerraformInit) {
          terraform init -backend=false
        }
        terraform validate
      } finally {
        Pop-Location
      }
    }
  }
} else {
  Write-Host "SKIP terraform: command not found"
}

if (Test-Command helm) {
  Invoke-Step "Helm lint and template" {
    helm lint helm-charts/healthcare-platform
    helm template healthcare helm-charts/healthcare-platform --namespace healthcare-dev | Out-Null
  }
} else {
  Write-Host "SKIP helm: command not found"
}

if (-not $SkipDbt -and (Test-Command dbt)) {
  Invoke-Step "dbt deps and parse" {
    $profiles = Join-Path $env:TEMP "shap-dbt-profiles"
    New-Item -ItemType Directory -Force -Path $profiles | Out-Null
    Copy-Item "dbt/profiles.yml.example" (Join-Path $profiles "profiles.yml") -Force
    $key = Join-Path $env:TEMP "shap_dummy_snowflake_key.pem"
    New-Item -ItemType File -Force -Path $key | Out-Null
    $env:SNOWFLAKE_ACCOUNT = "example-account"
    $env:SNOWFLAKE_USER = "SERVICE_DBT_HEALTHCARE"
    $env:SNOWFLAKE_ROLE = "TRANSFORMER"
    $env:SNOWFLAKE_WAREHOUSE = "HEALTHCARE_TRANSFORMING_WH"
    $env:SNOWFLAKE_DATABASE = "HEALTHCARE_ANALYTICS"
    $env:SNOWFLAKE_SCHEMA = "ANALYTICS"
    $env:SNOWFLAKE_PRIVATE_KEY_PATH = $key
    dbt deps --project-dir dbt --profiles-dir $profiles
    dbt parse --project-dir dbt --profiles-dir $profiles
  }
} else {
  Write-Host "SKIP dbt: command not found or SkipDbt supplied"
}

if (-not $SkipDocker -and (Test-Command docker)) {
  foreach ($service in @("healthcare-api", "etl-service", "notification-service")) {
    Invoke-Step "Docker build $service" {
      docker build -f "services/$service/Dockerfile" -t "smart-healthcare/$service:local" .
    }
  }
} else {
  Write-Host "SKIP docker: command not found or SkipDocker supplied"
}
