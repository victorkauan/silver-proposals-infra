locals {
  app_host_name = "${var.app_subdomain}.${var.domain}"
  api_host_name = "${var.api_subdomain}.${var.domain}"
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
  image_tag            = var.image_tag
  desired_count        = var.desired_count

  cloudflare_zone_id = var.shared.cloudflare_zone_id
}
