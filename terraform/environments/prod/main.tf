module "platform" {
  source = "../../modules/azure-healthcare-platform"

  environment                 = "prod"
  location                    = var.location
  name_prefix                 = var.name_prefix
  deployer_object_id          = var.deployer_object_id
  aks_admin_group_object_ids  = var.aks_admin_group_object_ids
  storage_replication_type    = "ZRS"
  aks_node_count              = 3
  aks_node_vm_size            = "Standard_D8s_v5"
  enable_databricks_workspace = var.enable_databricks_workspace

  tags = var.tags
}
