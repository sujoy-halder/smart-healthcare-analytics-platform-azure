# Operations Runbook

## Signals

- Pipeline latency: ADF activity duration, Databricks DLT update duration, and
  Event Hubs consumer lag.
- Job failures: ADF failed activities, DLT failed updates, Kubernetes failed
  jobs, and dbt failed tests.
- Cluster utilization: AKS node CPU/memory, Databricks cluster utilization, and
  Snowflake warehouse credit use.
- Data freshness: latest bronze file timestamp, latest silver table watermark,
  latest gold export timestamp, and dbt model max loaded time.
- Data quality: DLT expectations, dbt tests, rejected ingestion events, and
  quarantine counts.
- Cost: Azure Cost Management by tag, Databricks cluster spend, Snowflake
  warehouse credits, and Event Hubs throughput.

## Triage

1. Check `HealthcareIngestionErrorsHigh` and inspect API 422 responses by source
   type.
2. Check Event Hubs incoming messages and consumer lag.
3. Check Databricks DLT expectations for dropped rows and schema evolution.
4. Check Snowflake `QUERY_HISTORY` and dbt artifacts for failed marts.
5. Check AKS pod restarts, HPA events, and node pressure.
6. If source credentials fail, rotate only the affected Key Vault secret and
   restart the dependent workload.
