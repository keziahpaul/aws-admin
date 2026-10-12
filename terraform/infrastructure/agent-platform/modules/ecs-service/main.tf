data "aws_region" "current" {}

locals {
  name_prefix = "${var.environment}-${var.agent_name}-agent"
}

# --- ECR Repository (conditional) ---

resource "aws_ecr_repository" "slack_bot" {
  count = var.create_ecr_repository ? 1 : 0

  name                 = "${local.name_prefix}-slack-bot"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "slack_bot" {
  count = var.create_ecr_repository ? 1 : 0

  repository = aws_ecr_repository.slack_bot[0].name

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

# --- ECS Cluster ---

resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-slack-bot"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

# --- Capacity Providers ---

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = var.use_fargate_spot ? ["FARGATE", "FARGATE_SPOT"] : ["FARGATE"]

  dynamic "default_capacity_provider_strategy" {
    for_each = var.use_fargate_spot ? [1] : []
    content {
      capacity_provider = "FARGATE_SPOT"
      weight            = 1
      base              = 0
    }
  }

  dynamic "default_capacity_provider_strategy" {
    for_each = var.use_fargate_spot ? [] : [1]
    content {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 1
    }
  }
}

# --- CloudWatch Log Group ---

resource "aws_cloudwatch_log_group" "slack_bot" {
  name              = "/ecs/${local.name_prefix}/slack-bot"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# --- Security Group (egress-only, Socket Mode) ---

resource "aws_security_group" "slack_bot" {
  name        = "${local.name_prefix}-slack-bot-sg"
  description = "Slack bot ECS tasks - egress only (Socket Mode WebSocket)"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound traffic for Slack Socket Mode WebSocket"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-slack-bot-sg" })
}

# --- ECS Task Definition ---

locals {
  slack_bot_image = var.create_ecr_repository ? "${aws_ecr_repository.slack_bot[0].repository_url}:latest" : var.slack_bot_image

  # Build the environment variable list — inject KB ID only when provided
  base_env_vars = [
    { name = "AGENTCORE_RUNTIME_ARN", value = var.runtime_arn },
    { name = "AWS_REGION", value = data.aws_region.current.name },
    { name = "ENVIRONMENT", value = var.environment },
  ]

  kb_env_var = var.kb_knowledge_base_id != "" ? [
    { name = "KNOWLEDGE_BASE_ID", value = var.kb_knowledge_base_id }
  ] : []

  memory_env_vars = var.memory_id != "" ? [
    { name = "MEMORY_ID", value = var.memory_id },
    { name = "MEMORY_STRATEGY_ID", value = var.memory_strategy_id },
  ] : []

  container_env_vars = concat(local.base_env_vars, local.kb_env_var, local.memory_env_vars)

  # Transform secret_arns map → ECS secrets list [{name, valueFrom}]
  # For Slack secrets (key contains "slack"), extract JSON sub-keys (token, app_token)
  # NOTE: regexall(...) > 0 instead of strcontains() — the deploy runner's
  # Terraform predates strcontains (added in TF 1.5), and this is equivalent.
  container_secrets = flatten([
    for k, arn in var.secret_arns : (
      length(regexall("slack", k)) > 0 ? [
        { name = "SLACK_BOT_TOKEN", valueFrom = "${arn}:token::" },
        { name = "SLACK_APP_TOKEN", valueFrom = "${arn}:app_token::" },
        ] : [
        { name = upper(replace(k, "-", "_")), valueFrom = arn },
      ]
    )
  ])
}

resource "aws_ecs_task_definition" "slack_bot" {
  family                   = "${local.name_prefix}-slack-bot"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "slack-bot"
      image     = local.slack_bot_image
      essential = true

      environment = local.container_env_vars
      secrets     = local.container_secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.slack_bot.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "slack-bot"
        }
      }
    }
  ])

  tags = var.tags
}

# --- ECS Service ---

resource "aws_ecs_service" "slack_bot" {
  name            = "${local.name_prefix}-slack-bot"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.slack_bot.arn
  desired_count   = var.desired_count

  # Socket Mode: use capacity provider strategy rather than hardcoded launch_type
  # when Fargate Spot is enabled, so we get the mixed strategy
  dynamic "capacity_provider_strategy" {
    for_each = var.use_fargate_spot ? [1] : []
    content {
      capacity_provider = "FARGATE_SPOT"
      weight            = 1
      base              = 0
    }
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.use_fargate_spot ? [] : [1]
    content {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 1
    }
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  enable_ecs_managed_tags = true

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.slack_bot.id]
    assign_public_ip = false
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = var.tags

  depends_on = [aws_ecs_cluster_capacity_providers.this]
}

# --- App Auto Scaling (conditional: only when desired_count > 0) ---

resource "aws_appautoscaling_target" "slack_bot" {
  count = var.desired_count > 0 ? 1 : 0

  max_capacity       = max(var.desired_count * 4, 4)
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.slack_bot.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.slack_bot]
}

resource "aws_appautoscaling_policy" "slack_bot_cpu" {
  count = var.desired_count > 0 ? 1 : 0

  name               = "${local.name_prefix}-slack-bot-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.slack_bot[0].resource_id
  scalable_dimension = aws_appautoscaling_target.slack_bot[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.slack_bot[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
