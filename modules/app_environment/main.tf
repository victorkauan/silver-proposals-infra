data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  app_host_name = "${var.app_subdomain}.${var.domain}"
  api_host_name = "${var.api_subdomain}.${var.domain}"

  account_arn              = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}"
  permissions_boundary_arn = "${local.account_arn}:policy/silver-proposals-workload-boundary"
  github_oidc_provider_arn = "${local.account_arn}:oidc-provider/token.actions.githubusercontent.com"
}

module "app_certificate" {
  source = "../acm_certificate"

  domain_names       = [local.app_host_name]
  cloudflare_zone_id = var.shared.cloudflare_zone_id
}

module "frontend" {
  source = "../frontend"

  host_name          = local.app_host_name
  bucket_name        = "silversoft-silver-proposals-app-${var.environment}"
  certificate_arn    = module.app_certificate.certificate_arn
  cloudflare_zone_id = var.shared.cloudflare_zone_id

  environment              = var.environment
  permissions_boundary_arn = local.permissions_boundary_arn
  github_oidc_provider_arn = local.github_oidc_provider_arn
  github_subject_prefix    = var.frontend_github_subject_prefix
}

module "api" {
  source = "../api_service"

  environment   = var.environment
  region        = var.region
  api_host_name = local.api_host_name
  cors_origins  = ["https://${local.app_host_name}"]

  vpc_id                 = var.shared.vpc_id
  subnet_ids             = var.shared.public_subnet_ids
  alb_security_group_id  = var.shared.alb_security_group_id
  alb_dns_name           = var.shared.alb_dns_name
  https_listener_arn     = var.shared.https_listener_arn
  listener_rule_priority = var.listener_rule_priority

  database_address           = var.shared.database_address
  database_port              = var.shared.database_port
  database_security_group_id = var.shared.database_security_group_id
  database_master_secret_arn = var.shared.database_master_secret_arn

  image_repository_url = var.shared.ecr_repository_url
  image_repository_arn = var.shared.ecr_repository_arn
  allow_image_push     = var.environment == "staging"
  image_tag            = var.image_tag
  desired_count        = var.desired_count

  permissions_boundary_arn = local.permissions_boundary_arn
  github_oidc_provider_arn = local.github_oidc_provider_arn
  github_subject_prefix    = var.backend_github_subject_prefix

  cloudflare_zone_id = var.shared.cloudflare_zone_id
}

module "monitoring" {
  source = "../monitoring"

  environment             = var.environment
  region                  = var.region
  alerts_topic_arn        = var.shared.alerts_topic_arn
  alb_arn_suffix          = var.shared.alb_arn_suffix
  target_group_arn_suffix = module.api.target_group_arn_suffix
  cluster_name            = module.api.cluster_name
  service_name            = module.api.service_name
  log_group_name          = module.api.log_group_name
  distribution_id         = module.frontend.distribution_id
  db_instance_identifier  = var.shared.db_instance_identifier
}
