<div align="center">

# Smart Healthcare Analytics Platform on Azure

### Deployment-ready enterprise healthcare analytics platform using Azure, Databricks, Snowflake, dbt, Informatica, AKS, Terraform, FastAPI, Helm, monitoring, and GitHub Actions.

![Azure](https://img.shields.io/badge/Microsoft%20Azure-Cloud%20Platform-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white)
![Python](https://img.shields.io/badge/Python-FastAPI-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Databricks](https://img.shields.io/badge/Databricks-Delta%20Lake-FF3621?style=for-the-badge&logo=databricks&logoColor=white)
![Snowflake](https://img.shields.io/badge/Snowflake-Warehouse-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)
![dbt](https://img.shields.io/badge/dbt-Marts%20%2B%20Tests-FF694B?style=for-the-badge&logo=dbt&logoColor=white)
![AKS](https://img.shields.io/badge/AKS-Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-IaC-844FBA?style=for-the-badge&logo=terraform&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-CI%2FCD-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)

</div>

---

## Project Overview

**Smart Healthcare Analytics Platform on Azure** is a deployment-ready enterprise healthcare analytics scaffold.

The project demonstrates how healthcare data from Electronic Health Records, lab results, pharmacy transactions, appointments, imaging metadata, IoT patient monitoring, and insurance claims can move through Bronze, Silver, and Gold medallion layers using Azure, Databricks, Snowflake, dbt, Informatica, AKS, Terraform, and GitHub Actions.

---

## What Is Implemented

| Layer | Implementation |
|---|---|
| Cloud Infrastructure | ADLS Gen2, Event Hubs, ADF, AKS, ACR, Key Vault, managed identity |
| Networking | Private networking, private endpoints, secure deployment boundaries |
| Lakehouse | Databricks Delta Live Tables, Auto Loader, streaming ETL, medallion layers |
| APIs | FastAPI healthcare API, ETL worker, notification API |
| Data Quality | Ingestion contracts, validation, de-identification, quality expectations |
| Warehouse | Snowflake SQL and dbt marts |
| Healthcare Analytics | Patient analytics, claims analytics, hospital operations, executive dashboards |
| Enterprise Integration | Informatica mappings for Epic, Cerner, insurance systems, and MDM |
| Kubernetes | AKS Helm chart, Workload Identity, Key Vault CSI, autoscaling, NetworkPolicy |
| Monitoring | Log Analytics, Application Insights, Prometheus, Grafana |
| CI/CD | GitHub Actions for tests, Terraform validation, Helm rendering, Docker builds |

---

## Architecture

```mermaid
flowchart LR
    EHR["EHR Systems"] --> EventHubs["Azure Event Hubs"]
    Labs["Lab Results"] --> ADF["Azure Data Factory"]
    Claims["Insurance Claims"] --> ADF
    IoT["IoT Patient Monitoring"] --> EventHubs
    Pharmacy["Pharmacy Transactions"] --> ADF

    EventHubs --> ADLSB["ADLS Gen2 Bronze"]
    ADF --> ADLSB
    ADLSB --> DBR["Azure Databricks Auto Loader + DLT"]
    DBR --> Silver["Silver Delta Tables"]
    Silver --> Quality["Quality + De-identification"]
    Quality --> Gold["Gold Healthcare Aggregates"]

    Gold --> Snowflake["Snowflake Warehouse"]
    Snowflake --> DBT["dbt Healthcare Marts"]
    DBT --> BI["Patient, Claims, Operations Analytics"]

    AKS["AKS Healthcare APIs"] -. serves .-> EventHubs
    KeyVault["Azure Key Vault"] -. secures .-> AKS
    Monitor["Log Analytics + Grafana"] -. observes .-> AKS

    classDef source fill:#DBEAFE,stroke:#0078D4,color:#111827;
    classDef azure fill:#E0F2FE,stroke:#0284C7,color:#111827;
    classDef lake fill:#DCFCE7,stroke:#16A34A,color:#111827;
    classDef warehouse fill:#EDE9FE,stroke:#7C3AED,color:#111827;
    classDef security fill:#FEF3C7,stroke:#D97706,color:#111827;

    class EHR,Labs,Claims,IoT,Pharmacy source;
    class EventHubs,ADF,ADLSB,AKS,KeyVault,Monitor azure;
    class DBR,Silver,Quality,Gold lake;
    class Snowflake,DBT,BI warehouse;
```

---

## Repository Map

```text
terraform/       Azure infrastructure modules and environments
helm-charts/     AKS Helm charts for healthcare services
services/        FastAPI APIs, ETL worker, and notification service
src/             Python ingestion contracts and shared application code
databricks/      Delta Live Tables, Auto Loader, and streaming ETL assets
dbt/             dbt marts for healthcare analytics
snowflake/       Snowflake SQL setup
informatica/     Epic, Cerner, insurance, and MDM mapping specifications
adf/             Azure Data Factory assets
monitoring/      Prometheus and Grafana monitoring assets
docs/            Deployment documentation and operational guidance
.github/         GitHub Actions quality gates and deployment workflows
```

---

## Quick Start

```powershell
python -m pip install -r requirements-dev.txt
python -m pip install -e .
python -m pytest
.\scripts\validate-local.ps1 -SkipDocker
```

For real deployment, follow:

```text
docs/DEPLOYMENT.md
```

Every `REPLACE_WITH_*` value must be replaced with account-specific Azure, Databricks, Snowflake, or Informatica details before applying to a live environment.

---

## Security And Deployment Notes

- No real secrets should be committed.
- Runtime secrets should come from Azure Key Vault, GitHub Actions secrets, Databricks secrets, Snowflake key-pair auth, or Informatica secure configuration.
- AKS uses Workload Identity and Key Vault CSI.
- Private endpoints and private networking are included for secure deployment boundaries.
- Local validation is not proof that external systems have been deployed or connected.

---

## Author

**Sujoy Halder**  
Azure | Data Engineering | Databricks | Snowflake | dbt | AKS | Terraform | FastAPI | CI/CD

<div align="center">

### Built for enterprise healthcare analytics and cloud data engineering

![Type](https://img.shields.io/badge/Type-Healthcare%20Analytics-0078D4?style=for-the-badge)
![Architecture](https://img.shields.io/badge/Architecture-Medallion%20Lakehouse-16A34A?style=for-the-badge)
![Cloud](https://img.shields.io/badge/Cloud-Microsoft%20Azure-29B5E8?style=for-the-badge)
![Focus](https://img.shields.io/badge/Focus-Secure%20Deployment-D97706?style=for-the-badge)

</div>
