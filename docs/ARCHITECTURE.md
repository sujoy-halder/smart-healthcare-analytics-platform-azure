# Architecture

The platform uses Azure as the operational control plane and Snowflake as the
analytics warehouse.

1. Hospital APIs, HL7/FHIR feeds, SQL Server, Oracle, CSV drops, wearable
   devices, IoT sensors, and payer systems publish to the ingestion API, Event
   Hubs, or ADF batch pipelines.
2. ADLS Gen2 stores medallion data in `bronze`, `silver`, `gold`,
   `quarantine`, and `checkpoints` filesystems.
3. Databricks Delta Live Tables performs streaming ingestion, Auto Loader
   processing, data quality checks, deduplication, and gold aggregations.
4. Snowflake receives curated gold outputs and exposes dbt marts for patient
   analytics, claims analytics, hospital operations, and executive dashboards.
5. AKS runs the healthcare API, ETL worker, notification service, and operational
   jobs with Azure Workload Identity.
6. Azure Monitor, Log Analytics, Prometheus, and Grafana track latency, failures,
   cluster utilization, freshness, quality, and cost signals.

Security is built around private endpoints, disabled public access where the
Azure service supports it, Key Vault, customer-managed keys, Entra ID, RBAC,
non-root containers, network policies, and GitHub OIDC deployment.
