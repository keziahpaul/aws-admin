locals {
  # Merge created secret ARNs and existing secret ARNs into one unified map.
  # Callers use this single map without caring about the origin of the secret.
  _created_arns   = { for k, s in aws_secretsmanager_secret.created : k => s.arn }
  _existing_arns  = { for k, s in data.aws_secretsmanager_secret.existing : k => s.arn }
  all_secret_arns = merge(local._created_arns, local._existing_arns)
}

output "secret_arns" {
  description = "Map of logical name to ARN for all secrets (created and existing)"
  value       = local.all_secret_arns
}

output "secret_arns_list" {
  description = "Flat list of all secret ARNs (created and existing) for use in IAM resource arrays"
  value       = values(local.all_secret_arns)
}
