variable "host_name" {
  description = "Public host name of the app (for example app.silversoft.com.br)."
  type        = string
}

variable "bucket_name" {
  description = "Globally unique name of the bucket that holds the build."
  type        = string
}

variable "certificate_arn" {
  description = "Validated ACM certificate (us-east-1) for the host name."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone of the host name."
  type        = string
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary attached to every IAM role this module creates."
  type        = string
}

variable "environment" {
  description = "Environment name, used in the deploy role and its OIDC subject."
  type        = string
}

variable "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider trusted by the deploy role."
  type        = string
}

variable "github_subject_prefix" {
  description = "OIDC subject prefix of the frontend repository (immutable form, with numeric IDs)."
  type        = string
}
