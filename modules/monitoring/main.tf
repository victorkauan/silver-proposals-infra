locals {
  name      = "silver-proposals-${var.environment}"
  namespace = "SilverProposals/${var.environment}"
  tg        = { LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix }
  ecs       = { ClusterName = var.cluster_name, ServiceName = var.service_name }
  actions   = [var.alerts_topic_arn]
}

# ---------------------------------------------------------------- metrics from the API's JSON logs

resource "aws_cloudwatch_log_metric_filter" "generation_completed" {
  name           = "${local.name}-generation-completed"
  log_group_name = var.log_group_name
  pattern        = "{ $.event = \"generation_completed\" }"

  metric_transformation {
    name      = "GenerationsCompleted"
    namespace = local.namespace
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "generation_latency" {
  name           = "${local.name}-generation-latency"
  log_group_name = var.log_group_name
  pattern        = "{ $.event = \"generation_completed\" }"

  metric_transformation {
    name      = "GenerationLatency"
    namespace = local.namespace
    value     = "$.latency_ms"
    unit      = "Milliseconds"
  }
}

resource "aws_cloudwatch_log_metric_filter" "generation_failed" {
  name           = "${local.name}-generation-failed"
  log_group_name = var.log_group_name
  pattern        = "{ $.event = \"generation_failed\" }"

  metric_transformation {
    name          = "GenerationsFailed"
    namespace     = local.namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "errors" {
  name           = "${local.name}-errors"
  log_group_name = var.log_group_name
  pattern        = "{ $.level = \"ERROR\" }"

  metric_transformation {
    name          = "Errors"
    namespace     = local.namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

# ---------------------------------------------------------------- alarms

resource "aws_cloudwatch_metric_alarm" "no_healthy_targets" {
  alarm_name          = "${local.name}-api-down"
  alarm_description   = "The ${var.environment} API has no healthy target behind the load balancer."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  dimensions          = local.tg
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  treat_missing_data  = "breaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

resource "aws_cloudwatch_metric_alarm" "target_5xx" {
  alarm_name          = "${local.name}-api-5xx"
  alarm_description   = "The ${var.environment} API returned 5 or more server errors in 5 minutes."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = local.tg
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

resource "aws_cloudwatch_metric_alarm" "latency" {
  alarm_name          = "${local.name}-api-latency"
  alarm_description   = "p95 time to first byte of the ${var.environment} API is above 2 s for 15 minutes."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = local.tg
  extended_statistic  = "p95"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 2
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "${local.name}-api-cpu"
  alarm_description   = "CPU of the ${var.environment} API service is above 80% for 15 minutes."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions          = local.ecs
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

resource "aws_cloudwatch_metric_alarm" "memory" {
  alarm_name          = "${local.name}-api-memory"
  alarm_description   = "Memory of the ${var.environment} API service is above 85% for 15 minutes."
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  dimensions          = local.ecs
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 85
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

resource "aws_cloudwatch_metric_alarm" "generation_failures" {
  alarm_name          = "${local.name}-generation-failures"
  alarm_description   = "3 or more proposal generations failed in 15 minutes (Bedrock errors or timeouts) in ${var.environment}."
  namespace           = local.namespace
  metric_name         = "GenerationsFailed"
  statistic           = "Sum"
  period              = 900
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 3
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "${local.name}-api-errors"
  alarm_description   = "The ${var.environment} API logged 5 or more errors in 5 minutes."
  namespace           = local.namespace
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

resource "aws_cloudwatch_metric_alarm" "frontend_5xx" {
  alarm_name          = "${local.name}-app-5xx"
  alarm_description   = "More than 5% of the ${var.environment} app's requests failed with 5xx for 15 minutes."
  namespace           = "AWS/CloudFront"
  metric_name         = "5xxErrorRate"
  dimensions          = { DistributionId = var.distribution_id, Region = "Global" }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

# ---------------------------------------------------------------- dashboard

locals {
  widgets = [
    {
      type = "metric", x = 0, y = 0, width = 12, height = 6
      properties = {
        title = "API requests and errors", region = var.region, stat = "Sum", period = 60
        metrics = [
          ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix],
          [".", "HTTPCode_Target_4XX_Count", ".", ".", ".", "."],
          [".", "HTTPCode_Target_5XX_Count", ".", ".", ".", "."],
        ]
      }
    },
    {
      type = "metric", x = 12, y = 0, width = 12, height = 6
      properties = {
        title = "API latency (time to first byte, s)", region = var.region, period = 60
        metrics = [
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "p50", label = "p50" }],
          ["...", { stat = "p95", label = "p95" }],
        ]
      }
    },
    {
      type = "metric", x = 0, y = 6, width = 8, height = 6
      properties = {
        title   = "Healthy API targets", region = var.region, stat = "Minimum", period = 60
        metrics = [["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix]]
      }
    },
    {
      type = "metric", x = 8, y = 6, width = 8, height = 6
      properties = {
        title = "API service CPU and memory (%)", region = var.region, stat = "Average", period = 300
        metrics = [
          ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name, "ServiceName", var.service_name],
          [".", "MemoryUtilization", ".", ".", ".", "."],
        ]
      }
    },
    {
      type = "metric", x = 16, y = 6, width = 8, height = 6
      properties = {
        title = "Proposal generations (Bedrock)", region = var.region, stat = "Sum", period = 300
        metrics = [
          [local.namespace, "GenerationsCompleted"],
          [".", "GenerationsFailed"],
          [".", "GenerationLatency", { stat = "Average", yAxis = "right", label = "latency (ms)" }],
        ]
      }
    },
    {
      type = "metric", x = 0, y = 12, width = 12, height = 6
      properties = {
        title = "Database (shared instance)", region = var.region, stat = "Average", period = 300
        metrics = [
          ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_instance_identifier],
          [".", "DatabaseConnections", ".", ".", { yAxis = "right" }],
        ]
      }
    },
    {
      type = "log", x = 12, y = 12, width = 12, height = 6
      properties = {
        title = "Recent API errors", region = var.region
        query = "SOURCE '${var.log_group_name}' | fields @timestamp, event, route, status, request_id, error_code | filter level = 'ERROR' or event = 'generation_failed' | sort @timestamp desc | limit 20"
        view  = "table"
      }
    },
    {
      type = "alarm", x = 0, y = 18, width = 24, height = 3
      properties = {
        title = "Alarms"
        alarms = [
          aws_cloudwatch_metric_alarm.no_healthy_targets.arn,
          aws_cloudwatch_metric_alarm.target_5xx.arn,
          aws_cloudwatch_metric_alarm.latency.arn,
          aws_cloudwatch_metric_alarm.cpu.arn,
          aws_cloudwatch_metric_alarm.memory.arn,
          aws_cloudwatch_metric_alarm.generation_failures.arn,
          aws_cloudwatch_metric_alarm.errors.arn,
          aws_cloudwatch_metric_alarm.frontend_5xx.arn,
        ]
      }
    },
  ]
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = local.name
  dashboard_body = jsonencode({ widgets = local.widgets })
}
