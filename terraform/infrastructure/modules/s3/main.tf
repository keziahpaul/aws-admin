resource "aws_s3_bucket" "this" {
  for_each = toset(var.bucket_list)
  bucket   = each.value
  
  tags = merge(
    var.tags,
    {
      "Name"      = each.value
      "Terraform" = "true"
    }
  )
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = toset(var.bucket_list)
  bucket   = aws_s3_bucket.this[each.key].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = toset(var.bucket_list)
  bucket   = aws_s3_bucket.this[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_id
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = toset(var.bucket_list)
  bucket   = aws_s3_bucket.this[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = toset(var.bucket_list)
  bucket   = aws_s3_bucket.this[each.key].id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
  }
}

# Basic IAM policy for principal access
data "aws_iam_policy_document" "bucket_policy" {
  for_each = length(var.principal_arns) > 0 || var.enable_logs_delivery ? toset(var.bucket_list) : []
  
  dynamic "statement" {
    for_each = length(var.principal_arns) > 0 ? [1] : []
    content {
      sid = "PrincipalAccess"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      resources = [
        aws_s3_bucket.this[each.key].arn,
        "${aws_s3_bucket.this[each.key].arn}/*"
      ]
      principals {
        type        = "AWS"
        identifiers = var.principal_arns
      }
    }
  }

  # Optional log delivery access
  dynamic "statement" {
    for_each = var.enable_logs_delivery ? [1] : []
    content {
      sid = "AWSLogDeliveryAccess"
      actions = [
        "s3:GetBucketAcl",
        "s3:PutBucketAcl",
        "s3:PutObject"
      ]
      resources = [
        aws_s3_bucket.this[each.key].arn,
        "${aws_s3_bucket.this[each.key].arn}/*"
      ]
      principals {
        type        = "Service"
        identifiers = ["delivery.logs.amazonaws.com"]
      }
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  for_each = toset(var.bucket_list)
  bucket   = aws_s3_bucket.this[each.key].id
  
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "this" {
  for_each   = var.enable_logs_delivery ? toset(var.bucket_list) : []
  depends_on = [aws_s3_bucket_ownership_controls.this]
  bucket     = aws_s3_bucket.this[each.key].id
  acl        = "log-delivery-write"
}

resource "aws_s3_bucket_policy" "this" {
  for_each = length(var.principal_arns) > 0 || var.enable_logs_delivery ? toset(var.bucket_list) : []
  bucket   = aws_s3_bucket.this[each.key].id
  policy   = data.aws_iam_policy_document.bucket_policy[each.key].json
}
