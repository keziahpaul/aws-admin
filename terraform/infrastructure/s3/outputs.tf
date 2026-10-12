output "bucket_id" {
  description = "The ID of the S3 bucket"
  value       = module.s3.bucket_id[var.bucket_name]
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = module.s3.bucket_arn[var.bucket_name]
}

output "bucket_name" {
  description = "The name of the S3 bucket"
  value       = var.bucket_name
}

output "bucket_domain_name" {
  description = "The domain name of the S3 bucket"
  value       = module.s3.bucket_domain_name[var.bucket_name]
}

output "kms_key_id" {
  description = "The ID of the KMS key used for S3 encryption"
  value       = aws_kms_key.s3_kms_key.key_id
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for S3 encryption"
  value       = aws_kms_key.s3_kms_key.arn
}

output "enabled_data_sources" {
  description = "List of enabled data sources"
  value       = keys(local.enabled_data_sources)
}

output "uploaded_prefixes" {
  description = "List of uploaded prefixes for enabled data sources"
  value       = local.uploaded_prefixes
}
