# One topic for every alarm of the project; each address must confirm its subscription once.
#trivy:ignore:AWS-0095 CloudWatch alarms cannot publish to a topic encrypted with the AWS-managed SNS key; alerts hold no sensitive data.
resource "aws_sns_topic" "alerts" {
  #checkov:skip=CKV_AWS_26:CloudWatch alarms cannot publish to a topic encrypted with the AWS-managed SNS key, and a customer-managed key adds cost; alerts hold no sensitive data.
  name = "${local.name}-alerts"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  for_each = toset(nonsensitive(var.budget_alert_emails))

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

locals {
  db_dimensions = { DBInstanceIdentifier = module.database.identifier }
  alert_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "db_cpu" {
  alarm_name          = "${local.name}-db-cpu"
  alarm_description   = "CPU of the shared database is above 80% for 15 minutes."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = local.db_dimensions
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  treat_missing_data  = "breaching"
  alarm_actions       = local.alert_actions
  ok_actions          = local.alert_actions
}

resource "aws_cloudwatch_metric_alarm" "db_storage" {
  alarm_name          = "${local.name}-db-storage"
  alarm_description   = "The shared database has less than 2 GiB of free storage."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = local.db_dimensions
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "LessThanThreshold"
  threshold           = 2 * 1024 * 1024 * 1024
  treat_missing_data  = "breaching"
  alarm_actions       = local.alert_actions
  ok_actions          = local.alert_actions
}

resource "aws_cloudwatch_metric_alarm" "db_memory" {
  alarm_name          = "${local.name}-db-memory"
  alarm_description   = "The shared database has less than 64 MiB of freeable memory for 15 minutes."
  namespace           = "AWS/RDS"
  metric_name         = "FreeableMemory"
  dimensions          = local.db_dimensions
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "LessThanThreshold"
  threshold           = 64 * 1024 * 1024
  treat_missing_data  = "breaching"
  alarm_actions       = local.alert_actions
  ok_actions          = local.alert_actions
}

resource "aws_cloudwatch_metric_alarm" "db_connections" {
  alarm_name          = "${local.name}-db-connections"
  alarm_description   = "The shared database has more than 60 connections (db.t4g.micro allows about 80)."
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  dimensions          = local.db_dimensions
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 60
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alert_actions
  ok_actions          = local.alert_actions
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name}-alb-5xx"
  alarm_description   = "The load balancer itself returned 5 or more 5xx responses in 5 minutes (no healthy target, timeouts)."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  dimensions          = { LoadBalancer = module.alb.arn_suffix }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alert_actions
  ok_actions          = local.alert_actions
}
