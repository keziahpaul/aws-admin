output "bucket_id" {
  description = "Map of bucket names to their IDs"
  value = {
    for k, v in aws_s3_bucket.this : k => v.id
  }
}

output "bucket_arn" {
  description = "Map of bucket names to their ARNs"
  value = {
    for k, v in aws_s3_bucket.this : k => v.arn
  }
}

output "bucket_domain_name" {
  description = "Map of bucket names to their domain names"
  value = {
    for k, v in aws_s3_bucket.this : k => v.bucket_domain_name
  }
}
