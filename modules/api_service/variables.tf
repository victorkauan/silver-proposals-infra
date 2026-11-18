variable "environment" {
  description = "Environment name (staging or prod); also the ENVIRONMENT of the API."
  type        = string

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "environment must be staging or prod."
  }
}

variable "region" {
  description = "AWS region of the service and of the Bedrock inference profile."
  type        = string
}

variable "api_host_name" {
  description = "Public host name of the API (for example api.silversoft.com.br)."
  type        = string
}

variable "cors_origins" {
  description = "Origins allowed to call the API with credentials."
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC of the shared network."
  type        = string
}

variable "subnet_ids" {
  description = "Public subnets for the tasks (no NAT Gateway)."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group of the shared load balancer."
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the shared load balancer (target of the API CNAME)."
  type        = string
}

variable "https_listener_arn" {
  description = "HTTPS listener of the shared load balancer."
  type        = string
}

variable "listener_rule_priority" {
  description = "Priority of this environment's host-based rule on the shared listener; unique per environment."
  type        = number
}

variable "database_address" {
  description = "Host name of the shared PostgreSQL instance."
  type        = string
}

variable "database_port" {
  description = "Port of the shared PostgreSQL instance."
  type        = number
}

variable "database_security_group_id" {
  description = "Security group of the shared database; this module adds an ingress rule for its tasks."
  type        = string
}

variable "database_master_secret_arn" {
  description = "RDS-managed secret with the master credentials, used only by the one-off database setup task."
  type        = string
}

variable "database_setup_image" {
  description = "Container image with psql used by the database setup task."
  type        = string
  default     = "public.ecr.aws/docker/library/postgres:17-alpine"
}

variable "image_repository_url" {
  description = "ECR repository of the API image."
  type        = string
}

variable "image_tag" {
  description = "Tag of the API image to run."
  type        = string
}

variable "desired_count" {
  description = "Number of running API tasks; 0 until the first image is published."
  type        = number
  default     = 0
}

variable "cpu" {
  description = "CPU units of an API task (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory of an API task in MiB (the API plus the OpenTelemetry collector sidecar)."
  type        = number
  default     = 1024
}

variable "otel_collector_image" {
  description = "AWS Distro for OpenTelemetry collector image, pinned by digest."
  type        = string
  default     = "public.ecr.aws/aws-observability/aws-otel-collector:v0.51.0@sha256:955e240b27d7fd3c7995fd937db4b963975948eb553f656d8c37a564e5b5e07d"
}

variable "container_port" {
  description = "Port the API listens on inside the container."
  type        = number
  default     = 8000
}

variable "bedrock_model_id" {
  description = "Bedrock inference profile used by the API (BEDROCK_MODEL_ID)."
  type        = string
  default     = "us.amazon.nova-2-lite-v1:0"
}

variable "bedrock_foundation_model_id" {
  description = "Foundation model behind the inference profile."
  type        = string
  default     = "amazon.nova-2-lite-v1:0"
}

variable "bedrock_model_regions" {
  description = "Regions the inference profile routes to; each needs permission on the foundation model."
  type        = list(string)
  default     = ["us-east-1", "us-east-2", "us-west-2"]
}

variable "log_retention_days" {
  description = "Retention of the API logs."
  type        = number
  default     = 14
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone of the API host name."
  type        = string
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary attached to every IAM role this module creates."
  type        = string
}

variable "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider trusted by the deploy role."
  type        = string
}

variable "github_subject_prefix" {
  description = "OIDC subject prefix of the backend repository (immutable form, with numeric IDs)."
  type        = string

  # The deploy role must trust exactly one repository: no wildcards and no extra subject parts.
  validation {
    condition     = can(regex("^repo:[^:*?/]+/[^:*?/]+$", var.github_subject_prefix))
    error_message = "github_subject_prefix must be repo:<owner>/<repository> (optionally with @ids), without wildcards."
  }
}

variable "image_repository_arn" {
  description = "ARN of the ECR repository the deploy role reads (and, in staging, pushes to)."
  type        = string
}

variable "allow_image_push" {
  description = "Whether this environment's deploy role may push images (true only where images are built)."
  type        = bool
}
