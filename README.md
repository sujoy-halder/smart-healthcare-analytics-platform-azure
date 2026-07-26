# Project 2 - Smart Healthcare Analytics Platform on Azure

This repository is a deployment-ready enterprise healthcare analytics scaffold
for Azure, Databricks, Snowflake, dbt, Informatica, AKS, Terraform, and GitHub
Actions.

It covers Electronic Health Records, lab results, pharmacy transactions,
appointments, imaging metadata, IoT patient monitoring, and insurance claims
through bronze, silver, and gold medallion layers.

## What Is Implemented

- Azure Terraform for ADLS Gen2, Event Hubs, ADF, AKS, ACR, Key Vault, managed
  identity, private networking, private endpoints, Log Analytics, Application
  Insights, and Azure Databricks.
- AKS Helm chart for healthcare APIs, ETL service, notification service,
  scheduled quality jobs, Workload Identity, Key Vault CSI, autoscaling,
  NetworkPolicy, PDBs, probes, and Prometheus scraping.
- Python ingestion contracts, data quality validation, de-identification, local
  outbox fallback, CloudEvents, FastAPI API, ETL worker, and notification API.
- Databricks Delta Live Tables with Auto Loader, streaming ETL, quality
  expectations, incremental deduplication, and gold healthcare aggregates.
- Snowflake SQL and dbt marts for patient analytics, claims analytics, hospital
  operations, and executive dashboards.
- Informatica mapping specifications for Epic, Cerner, insurance systems, and
  master data management.
- GitHub Actions for quality gates, Terraform validation, Helm rendering, Docker
  builds, and controlled Azure deployment.
- Monitoring assets for Prometheus and Grafana.

## Quick Start

```powershell
python -m pip install -r requirements-dev.txt
python -m pip install -e .
python -m pytest
.\scripts\validate-local.ps1 -SkipDocker
```

For real deployment, follow [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md). Every
`REPLACE_WITH_*` value must be replaced with account-specific Azure, Databricks,
Snowflake, or Informatica details before applying to a live environment.

## Boundaries

This repository is ready for authenticated real-environment deployment, but a
live deployment requires your Azure subscription, Terraform backend, Entra IDs,
Snowflake account, Databricks workspace authentication, Informatica org, source
system credentials, and network approvals. Local validation is not evidence that
those external systems have been deployed or connected.
