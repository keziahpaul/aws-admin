output "kms_key_arn" {
  description = "ARN of the KMS key for SCIM token secrets"
  value       = aws_kms_key.scim_tokens.arn
}

output "kms_key_alias" {
  description = "Alias of the KMS key"
  value       = aws_kms_alias.scim_tokens.name
}

output "secret_arns" {
  description = "Map of account name to secret ARN"
  value = {
    for account, secret in aws_secretsmanager_secret.scim_token : account => secret.arn
  }
}
