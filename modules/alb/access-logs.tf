data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

module "access_logs" {
  source = "../private_archive"

  name           = "${var.name}-alb-logs-${data.aws_caller_identity.current.account_id}"
  retention_days = 184
}

data "aws_iam_policy_document" "access_logs" {
  statement {
    sid       = "AllowLoadBalancerDelivery"
    actions   = ["s3:PutObject"]
    resources = ["${module.access_logs.arn}/access/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [module.access_logs.arn, "${module.access_logs.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }

    condition {
      test     = "Bool"
      variable = "aws:PrincipalIsAWSService"
      values   = ["false"]
    }
  }
  statement {
    sid       = "RestrictLogRead"
    effect    = "Deny"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${module.access_logs.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values = [
        "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root",
        "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.archive_operator_role_name}",
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = module.access_logs.id
  policy = data.aws_iam_policy_document.access_logs.json
}
