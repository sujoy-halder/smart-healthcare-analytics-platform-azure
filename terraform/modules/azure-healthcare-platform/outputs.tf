output "deployment_summary" {
  description = "Important deployment outputs."
  value = {
    resource_group_name            = azurerm_resource_group.platform.name
    location                       = azurerm_resource_group.platform.location
    adls_account_name              = azurerm_storage_account.lake.name
    eventhub_namespace_name        = azurerm_eventhub_namespace.platform.name
    eventhub_names                 = local.event_hubs
    acr_login_server               = azurerm_container_registry.platform.login_server
    aks_name                       = azurerm_kubernetes_cluster.platform.name
    key_vault_name                 = azurerm_key_vault.platform.name
    data_factory_name              = azurerm_data_factory.platform.name
    databricks_workspace_url       = try(azurerm_databricks_workspace.platform[0].workspace_url, null)
    workload_identity_client_id    = azurerm_user_assigned_identity.workload.client_id
    workload_identity_principal_id = azurerm_user_assigned_identity.workload.principal_id
    log_analytics_workspace_id     = azurerm_log_analytics_workspace.platform.workspace_id
  }
}
