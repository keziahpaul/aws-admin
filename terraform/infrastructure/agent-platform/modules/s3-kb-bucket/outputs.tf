output "bucket_name" {
  description = "Name of the S3 knowledge base bucket"
  value       = aws_s3_bucket.kb.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 knowledge base bucket"
  value       = aws_s3_bucket.kb.arn
}

output "bucket_id" {
  description = "ID (name) of the S3 knowledge base bucket"
  value       = aws_s3_bucket.kb.id
}
