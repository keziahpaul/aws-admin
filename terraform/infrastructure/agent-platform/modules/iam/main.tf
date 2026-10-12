data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.environment}-${var.agent_name}-agent"
}

# ---------------------------------------------------------------------------
# ECS Task Execution Role
# Used by the ECS control plane to pull images and inject secrets.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "task_execution" {
  name = "${local.name_prefix}-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-task-execution"
    Role = "ecs-task-execution"
  })
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "task_execution_inline" {
  name = "secrets-and-logs"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerGetValue"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        # Scope to the secret ARNs provided; allow wildcard suffix for versioned ARNs
        Resource = length(var.secret_arns) > 0 ? [for arn in var.secret_arns : "${arn}*"] : ["arn:aws:secretsmanager:*:*:secret:${var.environment}/${var.agent_name}-agent/*"]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = [
          "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.environment}-${var.agent_name}*",
        ]
      },
    ]
  })
}

# ---------------------------------------------------------------------------
# ECS Task Role
# Used by the running container. Grants Bedrock, KB, CloudWatch, VPC.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "task_role" {
  name = "${local.name_prefix}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-task-role"
    Role = "ecs-task"
  })
}

resource "aws_iam_role_policy" "task_role_inline" {
  name = "agent-permissions"
  role = aws_iam_role.task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "BedrockInvoke"
          Effect = "Allow"
          Action = [
            "bedrock:InvokeModel",
            "bedrock:InvokeModelWithResponseStream",
            "bedrock:GetInferenceProfile",
            "bedrock:InvokeModelWithResponseStream",
            "bedrock:Converse",
            "bedrock:ConverseStream",
            "bedrock-agentcore:InvokeAgentRuntime",
            "bedrock:ConverseStream",
            "bedrock:GetInferenceProfile",
          ]
          # Inference profiles route cross-region; Resource must be *
          Resource = ["*"]
        },
        {
          Sid      = "CloudWatchMetrics"
          Effect   = "Allow"
          Action   = ["cloudwatch:PutMetricData"]
          Resource = ["*"]
          Condition = {
            StringEquals = {
              "cloudwatch:namespace" = "${upper(var.agent_name)}/Agent"
            }
          }
        },
        {
          Sid    = "VPCNetworking"
          Effect = "Allow"
          Action = [
            "ec2:CreateNetworkInterface",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DeleteNetworkInterface",
            "ec2:DescribeSubnets",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeVpcs",
          ]
          Resource = ["*"]
          Condition = {
            StringEquals = {
              "aws:RequestedRegion" = var.aws_region
            }
          }
        },
      ],
      # Optional: KB retrieve permissions (only when kb_bucket_arn is set)
      var.kb_bucket_arn != "" ? [
        {
          Sid    = "BedrockKBRetrieve"
          Effect = "Allow"
          Action = [
            "bedrock:Retrieve",
            "bedrock:RetrieveAndGenerate",
          ]
          Resource = ["arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"]
        },
        {
          Sid      = "S3KBRead"
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:ListBucket"]
          Resource = [var.kb_bucket_arn, "${var.kb_bucket_arn}/*"]
        },
      ] : [],
      # Dynamic additional statements injected by callers (e.g., memory, gateway)
      [for stmt in var.additional_iam_statements : {
        Sid      = stmt.sid
        Effect   = stmt.effect
        Action   = stmt.actions
        Resource = stmt.resources
      }]
    )
  })
}

# ---------------------------------------------------------------------------
# Bedrock KB Service Role
# Assumed by bedrock.amazonaws.com to index/retrieve from S3 + AOSS.
# Only created when a KB bucket is provided.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "bedrock_kb" {
  count = var.create_kb_role ? 1 : 0

  name = "${local.name_prefix}-bedrock-kb"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "bedrock.amazonaws.com" }
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          # Scope to KB resources in this account; KB ARN not known at role creation time
          "aws:SourceArn" = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"
        }
      }
    }]
  })

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-bedrock-kb"
    Role = "bedrock-kb"
  })
}

resource "aws_iam_role_policy" "bedrock_kb_inline" {
  count = var.create_kb_role ? 1 : 0

  name = "bedrock-kb-permissions"
  role = aws_iam_role.bedrock_kb[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3KBRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [var.kb_bucket_arn, "${var.kb_bucket_arn}/*"]
        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "BedrockEmbedding"
        Effect = "Allow"
        Action = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream", "bedrock:GetInferenceProfile"]
        # Scoped to foundation-model and inference-profile resource types
        # rather than a blanket "*". Inference profiles route cross-region, so
        # the region segment stays wildcarded, but the resource TYPE is now
        # constrained (no access to other Bedrock resource types).
        Resource = [
          "arn:aws:bedrock:*::foundation-model/*",
          "arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*",
        ]
      },
      {
        Sid      = "AOSSAccess"
        Effect   = "Allow"
        Action   = ["aoss:APIAccessAll"]
        Resource = [var.opensearch_collection_arn]
      },
    ]
  })
}

# ---------------------------------------------------------------------------
# AgentCore Runtime Role
# Used by the AgentCore service to run the agent container.
# Trust: bedrock-agentcore.amazonaws.com
# ---------------------------------------------------------------------------

resource "aws_iam_role" "agentcore_runtime" {
  name = "${local.name_prefix}-runtime"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "bedrock-agentcore.amazonaws.com" }
    }]
  })

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-runtime"
    Role = "agentcore-runtime"
  })
}

resource "aws_iam_role_policy" "agentcore_runtime_inline" {
  name = "agentcore-runtime-permissions"
  role = aws_iam_role.agentcore_runtime.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid    = "BedrockInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:GetInferenceProfile",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:Converse",
          "bedrock:ConverseStream",
          "bedrock-agentcore:InvokeAgentRuntime",
          "bedrock:ConverseStream",
          "bedrock:GetInferenceProfile",
          "bedrock:ApplyGuardrail",
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate",
        ]
        Resource = ["*"]
      },
      {
        Sid      = "ECRPull"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
        Resource = ["*"]
      },
      {
        Sid    = "VPCNetworking"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
        ]
        Resource = ["*"]
      },
      {
        Sid      = "CloudWatchLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
        Resource = ["arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/agentcore/*", "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/*"]
      },
      {
        # The runtime (agent_handler.py) emits PIA/Agent metrics
        # (InvocationCount, ResponseLatency, ErrorCount) around supervisor.run().
        # supervisor.run() executes in THIS AgentCore runtime, not the ECS slack
        # bot, so the grant must live here. Namespace-scoped so the runtime can
        # only write its own metrics.
        Sid      = "CloudWatchMetrics"
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = ["*"]
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "${upper(var.agent_name)}/Agent"
          }
        }
      },
    ])
  })
}
