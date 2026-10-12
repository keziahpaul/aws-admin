locals {
  metric_namespace = coalesce(var.custom_metric_namespace, "${upper(var.agent_name)}/Agent")
  name_prefix      = "${var.environment}-${var.agent_name}-agent"
}

# --- SNS Topic for Alarm Notifications ---

resource "aws_sns_topic" "alarms" {
  name = "${local.name_prefix}-alarms"

  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.alarm_sns_emails)

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = each.value
}

# --- CloudWatch Alarms ---

resource "aws_cloudwatch_metric_alarm" "error_rate" {
  alarm_name          = "${local.name_prefix}-error-rate"
  alarm_description   = "Agent ${var.agent_name} error count exceeded threshold in 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ErrorCount"
  namespace           = local.metric_namespace
  period              = 300
  statistic           = "Sum"
  threshold           = var.error_rate_threshold
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "latency_p99" {
  alarm_name          = "${local.name_prefix}-latency-p99"
  alarm_description   = "Agent ${var.agent_name} P99 response latency exceeded ${var.latency_p99_threshold}ms"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ResponseLatency"
  namespace           = local.metric_namespace
  period              = 300
  extended_statistic  = "p99"
  threshold           = var.latency_p99_threshold
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_running_tasks" {
  alarm_name          = "${local.name_prefix}-ecs-no-running-tasks"
  alarm_description   = "ECS service ${var.ecs_service_name} has fewer than 1 running task"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  # RunningTaskCount is a Container Insights metric (the cluster has Insights
  # enabled). The classic AWS/ECS namespace only carries CPU/Memory utilization,
  # so with treat_missing_data=breaching this alarm was firing on missing data
  # rather than on a genuinely stopped service.
  namespace          = "ECS/ContainerInsights"
  period             = 60
  statistic          = "Average"
  threshold          = 1
  treat_missing_data = "breaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = var.tags
}

# --- CloudWatch Dashboard ---

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${local.name_prefix}-agent"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Invocation Count"
          view   = "timeSeries"
          region = "ap-southeast-2"
          metrics = [
            [local.metric_namespace, "InvocationCount", { stat = "Sum", period = 300 }]
          ]
          yAxis = { left = { min = 0 } }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Response Latency (P50 / P95 / P99)"
          view   = "timeSeries"
          region = "ap-southeast-2"
          metrics = [
            [local.metric_namespace, "ResponseLatency", { stat = "p50", period = 300, label = "P50" }],
            [local.metric_namespace, "ResponseLatency", { stat = "p95", period = 300, label = "P95" }],
            [local.metric_namespace, "ResponseLatency", { stat = "p99", period = 300, label = "P99" }],
          ]
          yAxis = { left = { min = 0 } }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Error Rate"
          view   = "timeSeries"
          region = "ap-southeast-2"
          metrics = [
            [local.metric_namespace, "ErrorCount", { stat = "Sum", period = 300, color = "#d62728" }]
          ]
          yAxis = { left = { min = 0 } }
          annotations = {
            horizontal = [
              { label = "Threshold", value = var.error_rate_threshold, color = "#ff7f0e" }
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ECS Running Task Count"
          view   = "timeSeries"
          region = "ap-southeast-2"
          metrics = [
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name, { stat = "Average", period = 60 }]
          ]
          yAxis = { left = { min = 0 } }
          annotations = {
            horizontal = [
              { label = "Minimum", value = 1, color = "#d62728", fill = "below" }
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title  = "KB Retrieval Latency (Titan embedding)"
          view   = "timeSeries"
          region = "ap-southeast-2"
          # KnowledgeBaseRetrieveAndGenerateLatency is only emitted by the
          # RetrieveAndGenerate API; PIA uses Retrieve, so that metric never
          # appears. The retrieval's measurable Bedrock work is the query-
          # embedding call on the Titan embed model, whose InvocationLatency IS
          # emitted. This reflects actual KB retrieval latency.
          metrics = [
            ["AWS/Bedrock", "InvocationLatency", "ModelId", "arn:aws:bedrock:ap-southeast-2::foundation-model/amazon.titan-embed-text-v2:0", { stat = "p99", period = 300, label = "Embedding Invocation P99" }]
          ]
          yAxis = { left = { min = 0 } }
        }
      },
    ]
  })
}
