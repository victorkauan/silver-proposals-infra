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
    alerts_topic_arn           = string
    alb_arn_suffix             = string
    db_instance_identifier     = string
  })
}

# The account uses immutable OIDC subjects (owner and repository with their numeric IDs).
# Read them with: gh api repos/<owner>/<repo>/actions/oidc/customization/sub
variable "backend_github_subject_prefix" {
  description = "OIDC subject prefix of the backend repository."
  type        = string
  default     = "repo:victorkauan@71532562/silver-proposals-backend@1460360885"
}

variable "frontend_github_subject_prefix" {
  description = "OIDC subject prefix of the frontend repository."
  type        = string
  default     = "repo:victorkauan@71532562/silver-proposals-frontend@1460352038"
}


variable "initialize_app_secret" {
  description = "Create the initial Secrets Manager value with write-only inputs. Use only for an empty environment; keep the setting after initialization."
  type        = bool
  default     = false
}

variable "enforce_waf" {
  description = "Switch the edge ACL from Count to Block after reviewing the metrics."
  type        = bool
  default     = false
}
