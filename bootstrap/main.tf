provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "silver-proposals"
      Component = "terraform-state"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_arn   = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}"
  operator_arns = [for name in var.operator_user_names : "${local.account_arn}:user/${name}"]
  ci_role_arn   = "${local.account_arn}:role/${var.ci_role_prefix}-*"
}

resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV_AWS_145:SSE-S3 is enough for a single-account project; a customer-managed KMS key adds cost and a key policy without extra protection here.
  #checkov:skip=CKV_AWS_18:Access is limited to the operators and the CI roles by the bucket policy; audit logging is covered by the observability work.
  #checkov:skip=CKV_AWS_144:Single-region decision (us-east-1); versioning covers recovery from bad writes.
  #checkov:skip=CKV2_AWS_62:Nothing needs to react to state writes.
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

data "aws_iam_policy_document" "state" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]

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

  # Only operators and the CI Terraform roles may touch the state. The root user can still change
  # this policy, which is the recovery path if the allow list is ever wrong.
  statement {
    sid     = "DenyEveryoneElse"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values   = concat(local.operator_arns, [local.ci_role_arn])
    }
  }

  # Each environment's CI role may only write its own state and lock file.
  dynamic "statement" {
    for_each = toset(var.environments)

    content {
      sid           = "DenyCrossEnvironmentWrite${title(statement.value)}"
      effect        = "Deny"
      actions       = ["s3:PutObject", "s3:DeleteObject"]
      not_resources = ["${aws_s3_bucket.state.arn}/${statement.value}/*"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "ArnLike"
        variable = "aws:PrincipalArn"
        values   = ["${local.account_arn}:role/${var.ci_role_prefix}-${statement.value}"]
      }
    }
  }

  # Each environment's CI role may read its own state and the shared state (network, load balancer,
  # database outputs), but never the other environment's or the bootstrap state.
  dynamic "statement" {
    for_each = toset(var.environments)

    content {
      sid     = "DenyCrossEnvironmentRead${title(statement.value)}"
      effect  = "Deny"
      actions = ["s3:GetObject", "s3:GetObjectVersion"]
      not_resources = distinct([
        "${aws_s3_bucket.state.arn}/${statement.value}/*",
        "${aws_s3_bucket.state.arn}/${var.shared_state_prefix}/*",
      ])

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "ArnLike"
        variable = "aws:PrincipalArn"
        values   = ["${local.account_arn}:role/${var.ci_role_prefix}-${statement.value}"]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state.json

  depends_on = [aws_s3_bucket_public_access_block.state]
}
