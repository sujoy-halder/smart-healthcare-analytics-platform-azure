data "azurerm_client_config" "current" {}

locals {
  clean_prefix = replace(lower(var.name_prefix), "-", "")
  name_base    = "${lower(var.name_prefix)}-${var.environment}"
  storage_name = substr("${local.clean_prefix}${var.environment}${random_string.suffix.result}", 0, 24)

  event_hubs = {
    ehr                  = "ehr-events"
    lab_result           = "lab-result-events"
    pharmacy_transaction = "pharmacy-transaction-events"
    appointment          = "appointment-events"
    imaging_metadata     = "imaging-metadata-events"
    patient_monitoring   = "patient-monitoring-events"
    insurance_claim      = "insurance-claim-events"
  }
}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "azurerm_resource_group" "platform" {
  name     = "rg-${local.name_base}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_user_assigned_identity" "workload" {
  name                = "id-${local.name_base}-workloads"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = var.tags
}

resource "azurerm_log_analytics_workspace" "platform" {
  name                = "law-${local.name_base}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = var.tags
}

resource "azurerm_application_insights" "platform" {
  name                = "appi-${local.name_base}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.platform.id
  tags                = var.tags
}

resource "azurerm_virtual_network" "platform" {
  name                = "vnet-${local.name_base}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  address_space       = ["10.42.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.platform.name
  address_prefixes     = ["10.42.0.0/20"]
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-private-endpoints"
  resource_group_name               = azurerm_resource_group.platform.name
  virtual_network_name              = azurerm_virtual_network.platform.name
  address_prefixes                  = ["10.42.16.0/24"]
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet" "databricks_public" {
  name                 = "snet-dbx-public"
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.platform.name
  address_prefixes     = ["10.42.32.0/24"]

  delegation {
    name = "databricks"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

resource "azurerm_subnet" "databricks_private" {
  name                 = "snet-dbx-private"
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.platform.name
  address_prefixes     = ["10.42.33.0/24"]

  delegation {
    name = "databricks"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

resource "azurerm_key_vault" "platform" {
  name                          = "kv-${local.name_base}-${random_string.suffix.result}"
  location                      = azurerm_resource_group.platform.location
  resource_group_name           = azurerm_resource_group.platform.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  enable_rbac_authorization     = true
  public_network_access_enabled = false
  tags                          = var.tags

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

resource "azurerm_role_assignment" "deployer_key_vault_admin" {
  scope                = azurerm_key_vault.platform.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.deployer_object_id
}

resource "azurerm_role_assignment" "workload_key_vault_secrets" {
  scope                = azurerm_key_vault.platform.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}

resource "azurerm_role_assignment" "workload_key_vault_crypto" {
  scope                = azurerm_key_vault.platform.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}

resource "azurerm_key_vault_key" "cmk" {
  name         = "cmk-${local.name_base}"
  key_vault_id = azurerm_key_vault.platform.id
  key_type     = "RSA"
  key_size     = 4096
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]

  depends_on = [azurerm_role_assignment.deployer_key_vault_admin]
}

resource "azurerm_storage_account" "lake" {
  name                              = local.storage_name
  resource_group_name               = azurerm_resource_group.platform.name
  location                          = azurerm_resource_group.platform.location
  account_tier                      = "Standard"
  account_replication_type          = var.storage_replication_type
  account_kind                      = "StorageV2"
  is_hns_enabled                    = true
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = false
  shared_access_key_enabled         = false
  infrastructure_encryption_enabled = true
  tags                              = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.workload.id]
  }

  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.cmk.id
    user_assigned_identity_id = azurerm_user_assigned_identity.workload.id
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_storage_data_lake_gen2_filesystem" "medallion" {
  for_each           = toset(["bronze", "silver", "gold", "quarantine", "checkpoints"])
  name               = each.key
  storage_account_id = azurerm_storage_account.lake.id
}

resource "azurerm_eventhub_namespace" "platform" {
  name                          = "ehns-${local.name_base}-${random_string.suffix.result}"
  location                      = azurerm_resource_group.platform.location
  resource_group_name           = azurerm_resource_group.platform.name
  sku                           = "Standard"
  capacity                      = 2
  auto_inflate_enabled          = true
  maximum_throughput_units      = 8
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags
}

resource "azurerm_eventhub" "sources" {
  for_each            = local.event_hubs
  name                = each.value
  namespace_name      = azurerm_eventhub_namespace.platform.name
  resource_group_name = azurerm_resource_group.platform.name
  partition_count     = 4
  message_retention   = 7
}

resource "azurerm_container_registry" "platform" {
  name                          = substr("${local.clean_prefix}${var.environment}acr${random_string.suffix.result}", 0, 50)
  resource_group_name           = azurerm_resource_group.platform.name
  location                      = azurerm_resource_group.platform.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false
  zone_redundancy_enabled       = true
  tags                          = var.tags
}

resource "azurerm_kubernetes_cluster" "platform" {
  name                      = "aks-${local.name_base}"
  location                  = azurerm_resource_group.platform.location
  resource_group_name       = azurerm_resource_group.platform.name
  dns_prefix                = "aks-${local.name_base}"
  private_cluster_enabled   = true
  sku_tier                  = var.environment == "prod" ? "Standard" : "Free"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  azure_policy_enabled      = true
  local_account_disabled    = true
  tags                      = var.tags

  default_node_pool {
    name           = "system"
    node_count     = var.aks_node_count
    vm_size        = var.aks_node_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  azure_active_directory_role_based_access_control {
    managed                = true
    admin_group_object_ids = var.aks_admin_group_object_ids
    azure_rbac_enabled     = true
  }

  identity {
    type = "SystemAssigned"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.platform.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.platform.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "workload_storage_blob" {
  scope                = azurerm_storage_account.lake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}

resource "azurerm_role_assignment" "workload_eventhub_sender" {
  scope                = azurerm_eventhub_namespace.platform.id
  role_definition_name = "Azure Event Hubs Data Sender"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}

resource "azurerm_role_assignment" "workload_eventhub_receiver" {
  scope                = azurerm_eventhub_namespace.platform.id
  role_definition_name = "Azure Event Hubs Data Receiver"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}

resource "azurerm_federated_identity_credential" "aks_workload" {
  name                = "fic-${local.name_base}-healthcare-workloads"
  resource_group_name = azurerm_resource_group.platform.name
  parent_id           = azurerm_user_assigned_identity.workload.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.platform.oidc_issuer_url
  subject             = "system:serviceaccount:healthcare-${var.environment}:healthcare-workloads"
}

resource "azurerm_data_factory" "platform" {
  name                   = "adf-${local.name_base}-${random_string.suffix.result}"
  location               = azurerm_resource_group.platform.location
  resource_group_name    = azurerm_resource_group.platform.name
  public_network_enabled = false
  tags                   = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "adf_storage_blob" {
  scope                = azurerm_storage_account.lake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.platform.identity[0].principal_id
}

resource "azurerm_databricks_workspace" "platform" {
  count                                 = var.enable_databricks_workspace ? 1 : 0
  name                                  = "dbw-${local.name_base}"
  resource_group_name                   = azurerm_resource_group.platform.name
  location                              = azurerm_resource_group.platform.location
  sku                                   = "premium"
  public_network_access_enabled         = false
  network_security_group_rules_required = "NoAzureDatabricksRules"
  tags                                  = var.tags

  custom_parameters {
    no_public_ip        = true
    virtual_network_id  = azurerm_virtual_network.platform.id
    public_subnet_name  = azurerm_subnet.databricks_public.name
    private_subnet_name = azurerm_subnet.databricks_private.name
  }
}

resource "azurerm_private_dns_zone" "zones" {
  for_each = {
    blob        = "privatelink.blob.core.windows.net"
    dfs         = "privatelink.dfs.core.windows.net"
    vault       = "privatelink.vaultcore.azure.net"
    eventhub    = "privatelink.servicebus.windows.net"
    acr         = "privatelink.azurecr.io"
    datafactory = "privatelink.datafactory.azure.net"
  }

  name                = each.value
  resource_group_name = azurerm_resource_group.platform.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each              = azurerm_private_dns_zone.zones
  name                  = "link-${each.key}-${local.name_base}"
  resource_group_name   = azurerm_resource_group.platform.name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.platform.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-${local.name_base}-blob"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${local.name_base}-blob"
    private_connection_resource_id = azurerm_storage_account.lake.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["blob"].id]
  }
}

resource "azurerm_private_endpoint" "storage_dfs" {
  name                = "pe-${local.name_base}-dfs"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${local.name_base}-dfs"
    private_connection_resource_id = azurerm_storage_account.lake.id
    subresource_names              = ["dfs"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["dfs"].id]
  }
}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-${local.name_base}-kv"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${local.name_base}-kv"
    private_connection_resource_id = azurerm_key_vault.platform.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["vault"].id]
  }
}

resource "azurerm_private_endpoint" "eventhub" {
  name                = "pe-${local.name_base}-eh"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${local.name_base}-eh"
    private_connection_resource_id = azurerm_eventhub_namespace.platform.id
    subresource_names              = ["namespace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["eventhub"].id]
  }
}

resource "azurerm_private_endpoint" "acr" {
  name                = "pe-${local.name_base}-acr"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${local.name_base}-acr"
    private_connection_resource_id = azurerm_container_registry.platform.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["acr"].id]
  }
}

resource "azurerm_private_endpoint" "data_factory" {
  name                = "pe-${local.name_base}-adf"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${local.name_base}-adf"
    private_connection_resource_id = azurerm_data_factory.platform.id
    subresource_names              = ["dataFactory"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["datafactory"].id]
  }
}

resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "diag-${local.name_base}-kv"
  target_resource_id         = azurerm_key_vault.platform.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "eventhub" {
  name                       = "diag-${local.name_base}-eh"
  target_resource_id         = azurerm_eventhub_namespace.platform.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "data_factory" {
  name                       = "diag-${local.name_base}-adf"
  target_resource_id         = azurerm_data_factory.platform.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "diag-${local.name_base}-aks"
  target_resource_id         = azurerm_kubernetes_cluster.platform.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
