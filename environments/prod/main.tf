locals {
  environment = "prod"
  region      = "us-east-1"
}

provider "aws" {
  region = local.region

  default_tags {
    tags = {
      Project     = "silver-proposals"
      Environment = local.environment
      ManagedBy   = "terraform"
    }
  }
}

# Reads CLOUDFLARE_API_TOKEN from the environment; the token is scoped to this zone's DNS.
provider "cloudflare" {}

data "terraform_remote_state" "shared" {
  backend = "s3"

  config = {
    bucket = "silversoft-silver-proposals-tfstate"
    key    = "shared/terraform.tfstate"
    region = local.region
  }
}

module "environment" {
  source = "../../modules/app_environment"

  environment            = local.environment
  region                 = local.region
  domain                 = "silversoft.com.br"
  app_subdomain          = "app"
  api_subdomain          = "api"
  listener_rule_priority = 100
  image_tag              = var.image_tag
  desired_count          = var.desired_count

  shared = {
    for key in [
      "cloudflare_zone_id", "vpc_id", "public_subnet_ids", "alb_security_group_id", "alb_dns_name",
      "https_listener_arn", "database_address", "database_port", "database_security_group_id",
      "database_master_secret_arn", "ecr_repository_url", "ecr_repository_arn",
    ] : key => data.terraform_remote_state.shared.outputs[key]
  }
}
