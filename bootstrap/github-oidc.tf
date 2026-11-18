# GitHub Actions authenticates to AWS with short-lived OIDC tokens; there are no access keys in GitHub.
# An account holds one provider per URL; if it already exists, import it instead of creating it
# (see docs/runbooks/terraform-state-bootstrap.md). Other roles may trust it, so it is never destroyed.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  boundary_arn = "${local.account_arn}:policy/${var.workload_boundary_name}"
}

# ---------------------------------------------------------------- permissions boundary

# Every role that Terraform creates for the application carries this boundary, so even a role with
# broad inline policies can never exceed what the workloads and their deploy pipelines need.
data "aws_iam_policy_document" "workload_boundary" {
  #checkov:skip=CKV_AWS_111:A permissions boundary is a ceiling, not a grant; each role's own policy scopes the resources.
  #checkov:skip=CKV_AWS_108:Same: the boundary grants nothing by itself.
  #checkov:skip=CKV_AWS_356:Same: resources are restricted in each role's own policy.
  statement {
    sid    = "WorkloadServices"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "secretsmanager:GetSecretValue",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:DescribeImages",
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeServices",
      "ecs:UpdateService",
      "ecs:RunTask",
      "ecs:DescribeTasks",
      "ecs:TagResource",
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "PassOnlyWorkloadRolesToEcs"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["${local.account_arn}:role/silver-proposals-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "workload_boundary" {
  name        = var.workload_boundary_name
  description = "Permissions boundary for every role Terraform creates for Silver Proposals workloads and deploys"
  policy      = data.aws_iam_policy_document.workload_boundary.json
}

# ---------------------------------------------------------------- Terraform CI roles

locals {
  state_arn = aws_s3_bucket.state.arn

  ci_roles = merge(
    { for env in var.environments : "${env}-plan" => { environment = env, mode = "plan" } },
    { for env in var.environments : env => { environment = env, mode = "apply" } },
  )
}

data "aws_iam_policy_document" "ci_assume" {
  for_each = local.ci_roles

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Plan roles serve pull requests and main (read-only); apply roles only jobs in the protected GitHub
    # environment, so changing a workflow in a branch can never apply anything.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = (
        each.value.mode == "plan"
        ? ["${var.github_infra_subject_prefix}:pull_request", "${var.github_infra_subject_prefix}:ref:refs/heads/main"]
        : ["${var.github_infra_subject_prefix}:environment:${each.value.environment}"]
      )
    }
  }
}

resource "aws_iam_role" "ci" {
  for_each = local.ci_roles

  name                 = "${var.ci_role_prefix}-${each.key}"
  description          = "Terraform ${each.value.mode} for ${each.value.environment} from GitHub Actions (OIDC)"
  assume_role_policy   = data.aws_iam_policy_document.ci_assume[each.key].json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "ci_state" {
  for_each = local.ci_roles

  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [local.state_arn]
  }

  statement {
    sid       = "ReadWriteOwnStateAndLock"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_arn}/${each.value.environment}/*"]
  }

  statement {
    sid       = "ReadSharedState"
    actions   = ["s3:GetObject"]
    resources = ["${local.state_arn}/${var.shared_state_prefix}/*"]
  }
}

resource "aws_iam_role_policy" "ci_state" {
  for_each = local.ci_roles

  name   = "terraform-state"
  role   = aws_iam_role.ci[each.key].id
  policy = data.aws_iam_policy_document.ci_state[each.key].json
}

# Plan roles: read everything Terraform refreshes, plus the environment's own app secret (refreshing a
# secret version reads its value). ReadOnlyAccess does not include secret values.
resource "aws_iam_role_policy_attachment" "plan_read_only" {
  for_each = { for key, role in local.ci_roles : key => role if role.mode == "plan" }

  role       = aws_iam_role.ci[each.key].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "plan_secrets" {
  statement {
    sid       = "ReadEnvironmentAppSecrets"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:${data.aws_partition.current.partition}:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:silver-proposals-*"]
  }
}

resource "aws_iam_role_policy" "plan_secrets" {
  for_each = { for key, role in local.ci_roles : key => role if role.mode == "plan" && role.environment != "shared" }

  name   = "read-app-secrets"
  role   = aws_iam_role.ci[each.key].id
  policy = data.aws_iam_policy_document.plan_secrets.json
}

# Apply roles: every AWS service except IAM (PowerUserAccess), plus IAM limited to the project's
# roles, which must carry the workload boundary.
resource "aws_iam_role_policy_attachment" "apply_power_user" {
  for_each = { for key, role in local.ci_roles : key => role if role.mode == "apply" }

  role       = aws_iam_role.ci[each.key].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/PowerUserAccess"
}

data "aws_iam_policy_document" "apply_iam" {
  statement {
    sid       = "ReadIam"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }

  statement {
    sid = "ManageProjectRolesWithBoundary"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePermissionsBoundary",
    ]
    resources = ["${local.account_arn}:role/silver-proposals-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.boundary_arn]
    }
  }

  statement {
    sid = "ManageProjectRoles"
    actions = [
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
    ]
    resources = ["${local.account_arn}:role/silver-proposals-*"]
  }

  statement {
    sid       = "PassProjectRoles"
    actions   = ["iam:PassRole"]
    resources = ["${local.account_arn}:role/silver-proposals-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com", "vpc-flow-logs.amazonaws.com"]
    }
  }

  statement {
    sid       = "ServiceLinkedRoles"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["${local.account_arn}:role/aws-service-role/*"]
  }

  # The pipeline must never weaken its own guard rails.
  statement {
    sid    = "ProtectGuardRails"
    effect = "Deny"
    actions = [
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:DeleteRolePermissionsBoundary",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ProtectCiRoles"
    effect    = "Deny"
    actions   = ["iam:*"]
    resources = ["${local.account_arn}:role/${var.ci_role_prefix}-*", aws_iam_openid_connect_provider.github.arn]
  }

  statement {
    sid    = "ProtectStateBucketConfiguration"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutLifecycleConfiguration",
      "s3:PutBucketOwnershipControls",
    ]
    resources = [local.state_arn]
  }
}

resource "aws_iam_role_policy" "apply_iam" {
  for_each = { for key, role in local.ci_roles : key => role if role.mode == "apply" }

  name   = "project-iam"
  role   = aws_iam_role.ci[each.key].id
  policy = data.aws_iam_policy_document.apply_iam.json
}
