locals {
  name_prefix = "${var.environment}-${var.agent_name}-agent"
  # Underscore convention, max 48 chars + "_runtime" suffix
  runtime_base_name = substr(replace("${var.environment}_${var.agent_name}", "-", "_"), 0, 48)
  runtime_name      = "${local.runtime_base_name}_runtime"
}

# --- ECR Repository for Agent Runtime Image ---

resource "aws_ecr_repository" "runtime" {
  name                 = "${local.name_prefix}-agent-runtime"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "runtime" {
  repository = aws_ecr_repository.runtime.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_retention_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire snapshot/dev images after retention window"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["snapshot-"]
          countType     = "sinceImagePushed"
          countUnit     = "days"
          countNumber   = var.snapshot_retention_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 3
        description  = "Keep last N release images for rollback"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.release_image_count
        }
        action = { type = "expire" }
      },
    ]
  })
}

# --- Security Group (egress HTTPS 443 only — AgentCore only needs outbound HTTPS) ---

resource "aws_security_group" "this" {
  name        = "${local.name_prefix}-agentcore-runtime-sg"
  description = "AgentCore runtime - egress HTTPS only"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow outbound HTTPS for AgentCore control plane and Bedrock API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-agentcore-runtime-sg" })
}

# --- CloudWatch Log Group ---

resource "aws_cloudwatch_log_group" "runtime" {
  name              = "/aws/agentcore/${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# --- AgentCore Agent Runtime ---

resource "aws_bedrockagentcore_agent_runtime" "this" {
  agent_runtime_name = local.runtime_name

  agent_runtime_artifact {
    container_configuration {
      container_uri = var.container_image
    }
  }

  dynamic "network_configuration" {
    for_each = var.network_mode == "VPC" ? [1] : []
    content {
      network_mode = "VPC"
      network_mode_config {
        subnets         = var.private_subnet_ids
        security_groups = [aws_security_group.this.id]
      }
    }
  }

  dynamic "network_configuration" {
    for_each = var.network_mode == "PUBLIC" ? [1] : []
    content {
      network_mode = "PUBLIC"
    }
  }

  role_arn = var.iam_role_arn

  environment_variables = merge(var.base_environment_variables, var.additional_environment_variables)

  protocol_configuration {
    server_protocol = "HTTP"
  }

  lifecycle_configuration {
    idle_runtime_session_timeout = var.idle_timeout
    max_lifetime                 = var.max_lifetime
  }

  tags = var.tags

  # The CD pipeline rolls new images imperatively via update-agent-runtime
  # (creating new runtime versions). Terraform bootstraps the runtime with the
  # ":latest" image but must not revert the pipeline-deployed image on later
  # applies, so the container artifact is ignored after creation. Mirrors the
  # ECS service ignoring desired_count.
  lifecycle {
    ignore_changes = [agent_runtime_artifact]
  }
}

# --- AgentCore Runtime Endpoint ---

resource "aws_bedrockagentcore_agent_runtime_endpoint" "this" {
  agent_runtime_id      = aws_bedrockagentcore_agent_runtime.this.agent_runtime_id
  agent_runtime_version = aws_bedrockagentcore_agent_runtime.this.agent_runtime_version
  name                  = "${local.runtime_base_name}_endpoint"

  tags = var.tags
}
