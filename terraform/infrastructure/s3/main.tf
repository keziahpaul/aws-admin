# Get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Terraform backend configuration
terraform {
  backend "s3" {}
}

# Extract enabled data sources and their prefixes
locals {
  enabled_data_sources = {
    for key, config in var.data_sources : key => config
    if config.enabled
  }

  # Get all uploaded prefixes from enabled sources
  uploaded_prefixes = flatten([
    for key, config in local.enabled_data_sources : config.uploaded_prefixes
  ])

  # Common tags
  tags = {
    Name       = var.bucket_name
    Project    = var.project
    CostCentre = var.cost_centre
    ManagedBy  = "terragrunt"
  }
}

# KMS Key for S3 encryption
resource "aws_kms_key" "s3_kms_key" {
  description             = "KMS key for ${var.bucket_name} S3 bucket encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        # Root account full access (required for key administration)
        {
          Sid    = "RootAccess"
          Effect = "Allow"
          Principal = {
            AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          }
          Action   = "kms:*"
          Resource = "*"
        }
      ],
      # All same-account principals (Lambda, SSO users, etc.) - scoped to S3 service only
      [
        {
          Sid    = "S3ServiceAccess"
          Effect = "Allow"
          Principal = {
            AWS = concat(["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"], var.business_user_role_arns)
          }
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:DescribeKey"
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "kms:ViaService" = "s3.${var.aws_region}.amazonaws.com"
            }
          }
        }
      ]
    )
  })

  tags = {
    Name        = "${var.bucket_name}-key"
    Environment = var.env_type
    Team        = "onedata-snowflake"
    Project     = var.project
    CostCentre  = var.cost_centre
    ManagedBy   = "terragrunt"
  }
}

resource "aws_kms_alias" "s3_kms_alias" {
  name          = "alias/${var.bucket_name}-kms-key"
  target_key_id = aws_kms_key.s3_kms_key.key_id
}

# Use the generic S3 module
module "s3" {
  source = "../modules/s3"

  bucket_list = [var.bucket_name]
  kms_key_id  = aws_kms_key.s3_kms_key.arn
  tags        = local.tags

  # No principals here - we'll handle access via the prefix-based policy below
  principal_arns = []

  enable_logs_delivery = false
}

# Create folder markers for uploaded prefixes so they're visible in S3 console
resource "aws_s3_object" "uploaded_folder_markers" {
  for_each = toset(local.uploaded_prefixes)

  bucket  = module.s3.bucket_id[var.bucket_name]
  key     = "${each.value}/"
  content = ""

  depends_on = [module.s3]
}

# Bucket policy - protect folder markers only
data "aws_iam_policy_document" "prefix_based_policy" {
  # Deny deletion of folder markers (keys ending with /)
  statement {
    sid    = "DenyFolderMarkerDeletion"
    effect = "Deny"
    actions = [
      "s3:DeleteObject"
    ]
    resources = [
      for prefix in local.uploaded_prefixes : "${module.s3.bucket_arn[var.bucket_name]}/${prefix}/"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

# Override the module's bucket policy with our prefix-based policy
resource "aws_s3_bucket_policy" "prefix_based_access" {
  bucket = module.s3.bucket_id[var.bucket_name]
  policy = data.aws_iam_policy_document.prefix_based_policy.json

  depends_on = [module.s3]
}

