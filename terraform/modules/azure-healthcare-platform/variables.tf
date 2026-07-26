variable "environment" {
  type        = string
  description = "Deployment environment name."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "name_prefix" {
  type        = string
  description = "Short lowercase resource prefix."
}

variable "deployer_object_id" {
  type        = string
  description = "Object ID of Terraform deployer for Key Vault key management."
}

variable "aks_admin_group_object_ids" {
  type        = list(string)
  description = "Microsoft Entra group object IDs with AKS admin access."
}

variable "storage_replication_type" {
  type        = string
  description = "Storage replication type for ADLS Gen2."
  default     = "ZRS"
}

variable "aks_node_count" {
  type        = number
  description = "Default AKS node count."
}

variable "aks_node_vm_size" {
  type        = string
  description = "Default AKS VM size."
}

variable "enable_databricks_workspace" {
  type        = bool
  description = "Whether to create Azure Databricks workspace."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to supported resources."
}
