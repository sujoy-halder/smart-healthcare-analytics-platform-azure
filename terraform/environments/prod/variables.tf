variable "subscription_id" {
  type        = string
  description = "Azure subscription ID used by the provider."
}

variable "tenant_id" {
  type        = string
  description = "Microsoft Entra tenant ID used by the provider."
}

variable "deployer_object_id" {
  type        = string
  description = "Object ID of the user or service principal running Terraform."
}

variable "aks_admin_group_object_ids" {
  type        = list(string)
  description = "Microsoft Entra group object IDs with AKS cluster-admin permissions."
}

variable "location" {
  type        = string
  description = "Azure region for the platform."
  default     = "eastus2"
}

variable "name_prefix" {
  type        = string
  description = "Short lowercase prefix used for globally unique resource names."
  default     = "shap"
}

variable "enable_databricks_workspace" {
  type        = bool
  description = "Create the Azure Databricks workspace in this environment."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default = {
    workload         = "smart-healthcare-analytics-platform"
    data_class       = "regulated-healthcare"
    environment      = "prod"
    deployment_owner = "platform-engineering"
  }
}
