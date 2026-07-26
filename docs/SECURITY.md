# Security Controls

- Private AKS cluster with Entra ID RBAC, Azure RBAC, Azure Policy, OIDC issuer,
  and Workload Identity enabled.
- ADLS Gen2 hierarchical namespace, disabled public access, disabled shared keys,
  customer-managed key support, and private endpoints for DFS and Blob.
- Event Hubs, ACR, Key Vault, and Data Factory public network access disabled
  with private endpoints and private DNS zones.
- Key Vault soft delete, purge protection, RBAC authorization, and least
  privilege assignments for workload identity.
- Containers run as non-root users, drop Linux capabilities, disable privilege
  escalation, define health checks, and use read-only root filesystems in AKS.
- Helm includes NetworkPolicy, PDB, HPA, CSI Key Vault integration, and Prometheus
  scraping annotations.
- GitHub Actions use OIDC for Azure login and pin third-party actions to commit
  SHAs.
- Snowflake SQL includes separate loader, transformer, and reader roles plus
  masking and row-access policy templates.

Account-specific security tasks still required:

- Configure Key Vault secrets: `identifier-salt`, Snowflake credentials, webhook
  URLs, and any source-system credentials.
- Approve Snowflake Azure storage integration consent after `DESC STORAGE
  INTEGRATION`.
- Configure private DNS resolution from build agents or private runners when all
  public access is disabled.
- Attach approved Azure Monitor diagnostic settings and budget alerts required by
  the target organization.
