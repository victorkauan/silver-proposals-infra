variable "environment" {
  description = "Environment name: staging or prod."
  type        = string
}

variable "region" {
  description = "AWS region of the environment."
  type        = string
}

variable "domain" {
  description = "DNS zone that holds the environment's host names."
  type        = string
}

variable "app_subdomain" {
  description = "Subdomain of the frontend (app or app-staging)."
  type        = string
}

variable "api_subdomain" {
  description = "Subdomain of the API (api or api-staging)."
  type        = string
}

variable "listener_rule_priority" {
  description = "Priority of the environment's rule on the shared HTTPS listener."
  type        = number
}

variable "image_tag" {
  description = "Tag of the API image to run."
  type        = string
}

variable "desired_count" {
  description = "Number of running API tasks."
  type        = number
}

variable "shared" {
  description = "Outputs of the shared root module (network, load balancer, database, registry, DNS zone)."
  type = object({
    cloudflare_zone_id         = string
    vpc_id                     = string
    public_subnet_ids          = list(string)
    alb_security_group_id      = string
    alb_dns_name               = string
    https_listener_arn         = string
    database_address           = string
    database_port              = number
    database_security_group_id = string
    database_master_secret_arn = string
    ecr_repository_url         = string
    ecr_repository_arn         = string
  })
}

variable "github_owner" {
  description = "GitHub owner of the backend and frontend repositories (OIDC subjects of the deploy roles)."
  type        = string
  default     = "victorkauan"
}
