data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_vpc" "this" {
  id = var.vpc_id
}

locals {
  name       = "silver-proposals-${var.environment}"
  partition  = data.aws_partition.current.partition
  account_id = data.aws_caller_identity.current.account_id
  db_name    = "silver_proposals_${var.environment}"
  db_user    = "silver_app_${var.environment}"

  bedrock_region = coalesce(var.bedrock_region, var.region)
  bedrock_model_arns = [
    for region in var.bedrock_model_regions :
    "arn:${local.partition}:bedrock:${region}::foundation-model/${var.bedrock_foundation_model_id}"
  ]
  bedrock_profile_arn = "arn:${local.partition}:bedrock:${local.bedrock_region}:${local.account_id}:inference-profile/${var.bedrock_model_id}"

  # Client IPs are personal data (LGPD) and not needed for troubleshooting: drop them before export.
  client_ip_attributes = [
    "client.address", "http.client_ip", "net.peer.ip", "net.sock.peer.addr", "network.peer.address",
    "http.request.header.x_forwarded_for",
  ]
  otel_collector_config = yamlencode({
    receivers = { otlp = { protocols = { http = { endpoint = "127.0.0.1:4318" } } } }
    processors = {
      "attributes/drop_client_ip" = {
        actions = [for key in local.client_ip_attributes : { key = key, action = "delete" }]
      }
      batch = {}
    }
    exporters = { awsxray = { region = var.region } }
    service = {
      pipelines = {
        traces = {
          receivers  = ["otlp"]
          processors = ["attributes/drop_client_ip", "batch"]
          exporters  = ["awsxray"]
        }
      }
    }
  })
}

# ---------------------------------------------------------------- secrets

removed {
  from = random_password.jwt

  lifecycle {
    destroy = false
  }
}

removed {
  from = random_bytes.totp_key

  lifecycle {
    destroy = false
  }
}

removed {
  from = random_password.db

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_secretsmanager_secret_version.app

  lifecycle {
    destroy = false
  }
}

ephemeral "random_password" "jwt" {
  count   = var.initialize_app_secret ? 1 : 0
  length  = 64
  special = false
}

ephemeral "random_bytes" "totp" {
  count  = var.initialize_app_secret ? 1 : 0
  length = 32
}

ephemeral "random_password" "db" {
  count   = var.initialize_app_secret ? 1 : 0
  length  = 40
  special = false
}

resource "aws_secretsmanager_secret" "app" {
  #checkov:skip=CKV_AWS_149:The AWS-managed key (aws/secretsmanager) is enough; a customer-managed KMS key adds cost.
  #checkov:skip=CKV2_AWS_57:Rotation needs a Lambda; application credential rotation is an explicit operation.
  name                    = "${local.name}/app"
  description             = "Application secrets of the ${var.environment} API"
  recovery_window_in_days = 7
}

# The key's value is set by hand (docs/runbooks/apply-environments.md), so it never passes through Terraform or CI.
resource "aws_secretsmanager_secret" "deepinfra" {
  #checkov:skip=CKV_AWS_149:The AWS-managed key (aws/secretsmanager) is enough; a customer-managed KMS key adds cost.
  #checkov:skip=CKV2_AWS_57:A third-party API key cannot be rotated by AWS; it is replaced by hand.
  count                   = var.ai_provider == "deepinfra" ? 1 : 0
  name                    = "${local.name}/deepinfra"
  description             = "DeepInfra API key of the ${var.environment} API"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "initial" {
  count                    = var.initialize_app_secret ? 1 : 0
  secret_id                = aws_secretsmanager_secret.app.id
  secret_string_wo_version = 1
  secret_string_wo = jsonencode({
    jwt_secret          = ephemeral.random_password.jwt[0].result
    totp_encryption_key = ephemeral.random_bytes.totp[0].base64
    db_password         = ephemeral.random_password.db[0].result
    database_url        = "postgresql+psycopg://${local.db_user}:${ephemeral.random_password.db[0].result}@${var.database_address}:${var.database_port}/${local.db_name}?sslmode=require"
  })

  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------- logs

resource "aws_cloudwatch_log_group" "api" {
  #checkov:skip=CKV_AWS_158:Logs are encrypted with the CloudWatch default key; a customer-managed KMS key adds cost.
  #checkov:skip=CKV_AWS_338:Two weeks of application logs are enough for this project.
  name              = "/ecs/${local.name}-api"
  retention_in_days = var.log_retention_days
}

# ---------------------------------------------------------------- IAM

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "execution" {
  name                 = "${local.name}-api-execution"
  assume_role_policy   = data.aws_iam_policy_document.ecs_tasks_assume.json
  permissions_boundary = var.permissions_boundary_arn
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_secrets" {
  statement {
    sid       = "ReadEnvironmentSecrets"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = concat([aws_secretsmanager_secret.app.arn], aws_secretsmanager_secret.deepinfra[*].arn)
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "read-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets.json
}

resource "aws_iam_role" "database_setup_execution" {
  name                 = "${local.name}-db-setup-execution"
  assume_role_policy   = data.aws_iam_policy_document.ecs_tasks_assume.json
  permissions_boundary = var.permissions_boundary_arn
}

resource "aws_iam_role_policy_attachment" "database_setup_execution" {
  role       = aws_iam_role.database_setup_execution.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "database_setup_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.app.arn, var.database_master_secret_arn]
  }
}

resource "aws_iam_role_policy" "database_setup_secrets" {
  name   = "read-setup-secrets"
  role   = aws_iam_role.database_setup_execution.id
  policy = data.aws_iam_policy_document.database_setup_secrets.json
}

# The application authenticates to Bedrock with this role; there are no AI keys anywhere.
resource "aws_iam_role" "task" {
  name                 = "${local.name}-api-task"
  assume_role_policy   = data.aws_iam_policy_document.ecs_tasks_assume.json
  permissions_boundary = var.permissions_boundary_arn
}

data "aws_iam_policy_document" "task_bedrock" {
  statement {
    sid       = "InvokeThroughInferenceProfile"
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = [local.bedrock_profile_arn]
  }

  # A cross-region inference profile routes to the model in several regions; each must be allowed,
  # but only when the call comes through the profile.
  statement {
    sid       = "InvokeUnderlyingModels"
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = local.bedrock_model_arns

    condition {
      test     = "StringLike"
      variable = "bedrock:InferenceProfileArn"
      values   = [local.bedrock_profile_arn]
    }
  }
}

resource "aws_iam_role_policy" "task_bedrock" {
  name   = "invoke-bedrock"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_bedrock.json
}

data "aws_iam_policy_document" "task_tracing" {
  #checkov:skip=CKV_AWS_111:X-Ray write actions do not support resource-level permissions.
  #checkov:skip=CKV_AWS_356:Same: X-Ray trace and sampling actions only accept "*".
  statement {
    sid = "SendTracesToXRay"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task_tracing" {
  name   = "send-traces"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_tracing.json
}

# ---------------------------------------------------------------- network

resource "aws_security_group" "task" {
  name        = "${local.name}-api-task"
  description = "API tasks: inbound only from the load balancer"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "task_from_alb" {
  security_group_id            = aws_security_group.task.id
  description                  = "API traffic from the load balancer only"
  referenced_security_group_id = var.alb_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
}

#trivy:ignore:AWS-0104 Only 443/TCP: without a NAT Gateway the tasks reach AWS APIs (Bedrock, ECR, Secrets Manager, CloudWatch) through the internet gateway.
resource "aws_vpc_security_group_egress_rule" "task_https" {
  security_group_id = aws_security_group.task.id
  description       = "HTTPS to AWS APIs (Bedrock, ECR, Secrets Manager, CloudWatch) through the internet gateway"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "task_database" {
  security_group_id            = aws_security_group.task.id
  description                  = "PostgreSQL"
  referenced_security_group_id = var.database_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = var.database_port
  to_port                      = var.database_port
}

resource "aws_vpc_security_group_ingress_rule" "database_from_task" {
  security_group_id            = var.database_security_group_id
  description                  = "PostgreSQL from the ${var.environment} API tasks"
  referenced_security_group_id = aws_security_group.task.id
  ip_protocol                  = "tcp"
  from_port                    = var.database_port
  to_port                      = var.database_port
}

resource "aws_vpc_security_group_egress_rule" "alb_to_task" {
  security_group_id            = var.alb_security_group_id
  description                  = "Load balancer to the ${var.environment} API tasks"
  referenced_security_group_id = aws_security_group.task.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
}

# ---------------------------------------------------------------- ECS

resource "aws_ecs_cluster" "this" {
  #checkov:skip=CKV_AWS_65:Container Insights adds per-metric cost; service metrics come from the default CloudWatch namespace.
  name = local.name
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${local.name}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${var.image_repository_url}:${var.image_tag}"
      essential = true
      # Only the ALB (inside the VPC) is trusted: with "*" Uvicorn takes the leftmost, client-set
      # X-Forwarded-For entry, so the per-IP rate limits could be bypassed.
      # The app logs each request itself; Uvicorn's access log would print raw paths with share tokens.
      command = [
        "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", tostring(var.container_port),
        "--proxy-headers", "--forwarded-allow-ips", data.aws_vpc.this.cidr_block, "--no-access-log",
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:${var.container_port}/health', timeout=3)\""]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 20
      }
      readonlyRootFilesystem = true
      portMappings           = [{ containerPort = var.container_port, protocol = "tcp" }]
      environment = concat([
        { name = "ENVIRONMENT", value = var.environment },
        { name = "CORS_ORIGINS", value = jsonencode(var.cors_origins) },
        { name = "AI_PROVIDER", value = var.ai_provider },
        { name = "BEDROCK_MODEL_ID", value = var.bedrock_model_id },
        { name = "BEDROCK_REGION", value = local.bedrock_region },
        { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://127.0.0.1:4318" },
        { name = "OTEL_SERVICE_NAME", value = "silver-proposals-api-${var.environment}" },
        ], var.ai_provider == "deepinfra" ? [
        { name = "DEEPINFRA_MODEL_ID", value = var.deepinfra_model_id },
      ] : [])
      secrets = concat([
        { name = "JWT_SECRET", valueFrom = "${aws_secretsmanager_secret.app.arn}:jwt_secret::" },
        { name = "TOTP_ENCRYPTION_KEY", valueFrom = "${aws_secretsmanager_secret.app.arn}:totp_encryption_key::" },
        { name = "DATABASE_URL", valueFrom = "${aws_secretsmanager_secret.app.arn}:database_url::" },
      ], [for arn in aws_secretsmanager_secret.deepinfra[*].arn : { name = "DEEPINFRA_API_KEY", valueFrom = arn }])
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "api"
        }
      }
    },
    # AWS Distro for OpenTelemetry: receives the API's traces on localhost and sends them to X-Ray.
    {
      name                   = "otel-collector"
      image                  = var.otel_collector_image
      essential              = false
      readonlyRootFilesystem = true
      environment            = [{ name = "AOT_CONFIG_CONTENT", value = local.otel_collector_config }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "otel"
        }
      }
    },
  ])

  depends_on = [aws_secretsmanager_secret_version.initial]
}

resource "aws_lb_target_group" "api" {
  #checkov:skip=CKV_AWS_378:TLS ends at the load balancer; the hop to the task stays inside the VPC.
  name                 = "${local.name}-api"
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/ready"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = var.https_listener_arn
  priority     = var.listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    host_header {
      values = [var.api_host_name]
    }
  }
}

resource "aws_ecs_service" "api" {
  #checkov:skip=CKV_AWS_333:Public IPs replace a NAT Gateway (cost decision); the security group admits only the load balancer.
  name                   = "api"
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.api.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  propagate_tags         = "SERVICE"
  enable_execute_command = false

  health_check_grace_period_seconds = 30

  # Public IPs instead of a NAT Gateway; the security group admits only the load balancer.
  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # The backend pipeline rolls out images: it registers a revision from the latest one (which carries
  # Terraform's configuration) with the new image, and sets the task count. Terraform must not undo it.
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  depends_on = [aws_lb_listener_rule.api, terraform_data.database_setup]
}

# ---------------------------------------------------------------- database setup

# One-off task that creates this environment's role and database on the shared instance, with the
# master credentials RDS keeps in Secrets Manager. It runs inside the VPC because the database has
# no public endpoint, and it is idempotent.
resource "aws_ecs_task_definition" "database_setup" {
  family                   = "${local.name}-db-setup"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.database_setup_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name                   = "db-setup"
      image                  = var.database_setup_image
      essential              = true
      readonlyRootFilesystem = true
      command                = ["sh", "-c", file("${path.module}/scripts/database-setup.sh")]
      environment = [
        { name = "PGHOST", value = var.database_address },
        { name = "PGPORT", value = tostring(var.database_port) },
        { name = "PGDATABASE", value = "postgres" },
        { name = "PGSSLMODE", value = "require" },
        { name = "APP_DB", value = local.db_name },
        { name = "APP_USER", value = local.db_user },
      ]
      secrets = [
        { name = "PGUSER", valueFrom = "${var.database_master_secret_arn}:username::" },
        { name = "PGPASSWORD", valueFrom = "${var.database_master_secret_arn}:password::" },
        { name = "APP_PASSWORD", valueFrom = "${aws_secretsmanager_secret.app.arn}:db_password::" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "db-setup"
        }
      }
    },
  ])
}

resource "terraform_data" "database_setup" {
  triggers_replace = [
    aws_ecs_task_definition.database_setup.revision,
    aws_secretsmanager_secret_version.initial[*].version_id,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/run-task.sh"
    environment = {
      AWS_REGION      = var.region
      CLUSTER         = aws_ecs_cluster.this.name
      TASK_DEFINITION = aws_ecs_task_definition.database_setup.arn
      SUBNETS         = join(",", var.subnet_ids)
      SECURITY_GROUP  = aws_security_group.task.id
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.database_setup_execution,
    aws_iam_role_policy.database_setup_secrets,
    aws_vpc_security_group_ingress_rule.database_from_task,
    aws_vpc_security_group_egress_rule.task_database,
  ]
}

# ---------------------------------------------------------------- DNS

resource "cloudflare_dns_record" "api" {
  zone_id = var.cloudflare_zone_id
  name    = var.api_host_name
  type    = "CNAME"
  content = var.alb_dns_name
  ttl     = 300
  proxied = false
  comment = "API (managed by Terraform)"
}

# ---------------------------------------------------------------- deploy role (backend pipeline)

data "aws_iam_policy_document" "deploy_assume" {
  #checkov:skip=CKV_AWS_358:The subject is one exact repository and environment, enforced by the validation on github_subject_prefix (no wildcards); Checkov cannot resolve the module variable.
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only jobs in this environment of the backend repository (protected in GitHub) can deploy.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${var.github_subject_prefix}:environment:${var.environment}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name                 = "${local.name}-deploy-backend"
  description          = "Backend deploy to ${var.environment} from GitHub Actions (OIDC)"
  assume_role_policy   = data.aws_iam_policy_document.deploy_assume.json
  permissions_boundary = var.permissions_boundary_arn
  max_session_duration = 3600
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadImages"
    actions   = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:DescribeImages", "ecr:GetDownloadUrlForLayer"]
    resources = [var.image_repository_arn]
  }

  # Only staging builds and pushes images; production promotes an image that staging already ran.
  dynamic "statement" {
    for_each = var.allow_image_push ? [1] : []

    content {
      sid       = "PushImages"
      actions   = ["ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage"]
      resources = [var.image_repository_arn]
    }
  }

  statement {
    sid       = "TaskDefinitions"
    actions   = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
    resources = ["*"]
  }

  statement {
    sid       = "RollOutService"
    actions   = ["ecs:UpdateService", "ecs:DescribeServices"]
    resources = ["arn:${local.partition}:ecs:${var.region}:${local.account_id}:service/${local.name}/api"]
  }

  statement {
    sid       = "RunMigrations"
    actions   = ["ecs:RunTask"]
    resources = ["arn:${local.partition}:ecs:${var.region}:${local.account_id}:task-definition/${local.name}-api:*"]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [aws_ecs_cluster.this.arn]
    }
  }

  statement {
    sid       = "WatchMigrations"
    actions   = ["ecs:DescribeTasks"]
    resources = ["arn:${local.partition}:ecs:${var.region}:${local.account_id}:task/${local.name}/*"]
  }

  statement {
    sid       = "PassTaskRoles"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.execution.arn, aws_iam_role.task.arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy-backend"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
