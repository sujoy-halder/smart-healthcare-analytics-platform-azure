output "deployment_summary" {
  description = "Resource names and IDs needed by CI/CD and runbooks."
  value       = module.platform.deployment_summary
}
