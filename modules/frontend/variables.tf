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
