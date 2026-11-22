locals {
  name   = "silver-proposals"
  region = "us-east-2"
  domain = "silversoft.com.br"

  # Created by bootstrap/; every role in this account's project carries it.
  permissions_boundary_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/silver-proposals-workload-boundary"
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

provider "aws" {
  region = local.region

  default_tags {
    tags = {
      Project     = "silver-proposals"
      Environment = "shared"
      ManagedBy   = "terraform"
    }
  }
}

# Reads CLOUDFLARE_API_TOKEN from the environment; the token is scoped to this zone's DNS.
provider "cloudflare" {}

data "cloudflare_zone" "this" {
  filter = {
    name = local.domain
  }
}

module "network" {
  source = "../../modules/network"

  name                     = local.name
  region                   = local.region
  permissions_boundary_arn = local.permissions_boundary_arn
}

module "api_certificate" {
  source = "../../modules/acm_certificate"

  domain_names       = ["api.${local.domain}", "api-staging.${local.domain}"]
  cloudflare_zone_id = data.cloudflare_zone.this.zone_id
}

module "alb" {
  source = "../../modules/alb"

  name               = local.name
  vpc_id             = module.network.vpc_id
  vpc_cidr_block     = module.network.vpc_cidr_block
  subnet_ids         = module.network.public_subnet_ids
  certificate_arn    = module.api_certificate.certificate_arn
  enforce_waf        = var.enforce_waf
  enable_access_logs = var.enable_access_logs
}

module "database" {
  source = "../../modules/database"

  name       = local.name
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.isolated_subnet_ids
  # The account is on the AWS Free plan, which rejects longer automated backup retention
  # (FreeTierRestrictionError). Raise to the module default (7) on a Paid plan.
  backup_retention_days = 1
}

module "ecr" {
  source = "../../modules/ecr"

  name = "${local.name}-backend"
}

module "budget" {
  source = "../../modules/budget"

  name              = "${local.name}-monthly"
  monthly_limit_usd = var.monthly_budget_usd
  alert_emails      = var.budget_alert_emails
}
