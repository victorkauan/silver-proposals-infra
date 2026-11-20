locals {
  managed_rules = {
    AWSManagedRulesCommonRuleSet         = { priority = 10, metric = "CoreRules" }
    AWSManagedRulesKnownBadInputsRuleSet = { priority = 20, metric = "KnownBadInputs" }
  }
}

resource "aws_wafv2_web_acl" "this" {
  #checkov:skip=CKV_AWS_192:The AWS Known Bad Inputs managed rule group includes the Log4JRCE rules.
  #checkov:skip=CKV2_AWS_31:Full WAF records can expose capability URLs and matched text; aggregate WAF rule metrics are enabled.
  name  = var.name
  scope = var.scope

  default_action {
    allow {}
  }

  rule {
    name     = "PerIpRate"
    priority = 0

    action {
      dynamic "block" {
        for_each = var.enforce ? [1] : []
        content {}
      }

      dynamic "count" {
        for_each = var.enforce ? [] : [1]
        content {}
      }
    }

    statement {
      rate_based_statement {
        limit                 = var.request_limit
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "PerIpRate"
      sampled_requests_enabled   = false
    }
  }

  dynamic "rule" {
    for_each = local.managed_rules
    content {
      name     = rule.key
      priority = rule.value.priority

      override_action {
        dynamic "none" {
          for_each = var.enforce ? [1] : []
          content {}
        }

        dynamic "count" {
          for_each = var.enforce ? [] : [1]
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.key
          vendor_name = "AWS"

          # Proposal content can be 200,000 characters; the application validates that limit.
          dynamic "rule_action_override" {
            for_each = rule.key == "AWSManagedRulesCommonRuleSet" && var.scope == "REGIONAL" ? ["SizeRestrictions_BODY"] : []
            content {
              name = rule_action_override.value
              action_to_use {
                count {}
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.metric
        sampled_requests_enabled   = false
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.name
    sampled_requests_enabled   = false
  }
}
