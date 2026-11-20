locals {
  backup_name               = "${local.name}-backup"
  backup_schedule_group_arn = "arn:${local.partition}:scheduler:${var.region}:${local.account_id}:schedule-group/${local.backup_name}"
}

module "backups" {
  source = "../private_archive"

  name           = "${local.backup_name}-${local.account_id}"
  retention_days = 14
}

data "aws_iam_policy_document" "backups" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [module.backups.arn, "${module.backups.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "RestrictRestore"
    effect    = "Deny"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${module.backups.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values = [
        "arn:${local.partition}:iam::${local.account_id}:root",
        "arn:${local.partition}:iam::${local.account_id}:user/${var.archive_operator_name}",
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "backups" {
  bucket = module.backups.id
  policy = data.aws_iam_policy_document.backups.json
}

resource "aws_iam_role" "backup_task" {
  name                 = "${local.backup_name}-task"
  assume_role_policy   = data.aws_iam_policy_document.ecs_tasks_assume.json
  permissions_boundary = var.permissions_boundary_arn
}

data "aws_iam_policy_document" "write_backup" {
  statement {
    actions   = ["s3:PutObject", "s3:AbortMultipartUpload"]
    resources = ["${module.backups.arn}/dumps/*"]
  }
}

resource "aws_iam_role_policy" "write_backup" {
  name   = "upload-dump"
  role   = aws_iam_role.backup_task.id
  policy = data.aws_iam_policy_document.write_backup.json
}

resource "aws_ecs_task_definition" "backup" {
  family                   = local.backup_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.backup_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  volume {
    name = "backup"
  }

  container_definitions = jsonencode([
    {
      name                   = "dump"
      image                  = var.database_setup_image
      essential              = false
      readonlyRootFilesystem = true
      entryPoint             = ["/bin/sh", "-ec"]
      command                = [file("${path.module}/scripts/dump-database.sh")]
      environment = [
        { name = "PGHOST", value = var.database_address },
        { name = "PGPORT", value = tostring(var.database_port) },
        { name = "PGDATABASE", value = local.db_name },
        { name = "PGUSER", value = local.db_user },
        { name = "PGSSLMODE", value = "require" },
      ]
      secrets = [
        { name = "PGPASSWORD", valueFrom = "${aws_secretsmanager_secret.app.arn}:db_password::" },
      ]
      mountPoints = [
        { sourceVolume = "backup", containerPath = "/backup", readOnly = false },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "backup"
        }
      }
    },
    {
      name                   = "upload"
      image                  = var.backup_upload_image
      essential              = true
      readonlyRootFilesystem = true
      entryPoint             = ["/bin/sh", "-ec"]
      command                = [file("${path.module}/scripts/upload-backup.sh")]
      dependsOn              = [{ containerName = "dump", condition = "SUCCESS" }]
      environment = [
        { name = "BACKUP_BUCKET", value = module.backups.id },
        { name = "AWS_DEFAULT_REGION", value = var.region },
        { name = "AWS_PAGER", value = "" },
      ]
      mountPoints = [
        { sourceVolume = "backup", containerPath = "/backup", readOnly = true },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "backup"
        }
      }
    }
  ])
}

resource "aws_scheduler_schedule_group" "backup" {
  name = local.backup_name
}

data "aws_iam_policy_document" "backup_scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [local.backup_schedule_group_arn]
    }
  }
}

resource "aws_iam_role" "backup_scheduler" {
  name                 = "${local.backup_name}-scheduler"
  assume_role_policy   = data.aws_iam_policy_document.backup_scheduler_assume.json
  permissions_boundary = var.permissions_boundary_arn
}

data "aws_iam_policy_document" "run_backup" {
  statement {
    actions   = ["ecs:RunTask"]
    resources = [aws_ecs_task_definition.backup.arn]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [aws_ecs_cluster.this.arn]
    }
  }

  statement {
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.execution.arn, aws_iam_role.backup_task.arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "run_backup" {
  name   = "run-backup-task"
  role   = aws_iam_role.backup_scheduler.id
  policy = data.aws_iam_policy_document.run_backup.json
}

resource "aws_scheduler_schedule" "backup" {
  #checkov:skip=CKV_AWS_297:The schedule contains task and network identifiers only and uses AWS-managed encryption.
  name                         = "daily-database-dump"
  group_name                   = aws_scheduler_schedule_group.backup.name
  schedule_expression          = var.environment == "staging" ? "cron(0 6 * * ? *)" : "cron(30 6 * * ? *)"
  schedule_expression_timezone = "UTC"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_ecs_cluster.this.arn
    role_arn = aws_iam_role.backup_scheduler.arn

    retry_policy {
      maximum_event_age_in_seconds = 3600
      maximum_retry_attempts       = 2
    }

    ecs_parameters {
      launch_type         = "FARGATE"
      task_definition_arn = aws_ecs_task_definition.backup.arn

      network_configuration {
        subnets          = var.subnet_ids
        security_groups  = [aws_security_group.task.id]
        assign_public_ip = true
      }
    }
  }

  depends_on = [
    aws_iam_role_policy.run_backup,
    aws_iam_role_policy.write_backup,
    aws_s3_bucket_policy.backups,
    terraform_data.database_setup,
  ]
}

resource "aws_cloudwatch_log_metric_filter" "backup_uploaded" {
  name           = "${local.backup_name}-uploaded"
  log_group_name = aws_cloudwatch_log_group.api.name
  pattern        = "\"database backup uploaded\""

  metric_transformation {
    name      = "${local.backup_name}-success"
    namespace = "SilverProposals/Backups"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "missing_backup" {
  alarm_name          = "${local.backup_name}-missing"
  alarm_description   = "No successful dump upload in the latest two daily UTC periods"
  namespace           = "SilverProposals/Backups"
  metric_name         = aws_cloudwatch_log_metric_filter.backup_uploaded.metric_transformation[0].name
  statistic           = "Sum"
  period              = 86400
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  treat_missing_data  = "breaching"
  alarm_actions       = [var.alerts_topic_arn]
  ok_actions          = [var.alerts_topic_arn]
}
