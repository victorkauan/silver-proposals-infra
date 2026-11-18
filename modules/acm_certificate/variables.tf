variable "domain_names" {
  description = "Host names on the certificate; the first one is the primary domain."
  type        = list(string)
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone that receives the DNS validation records."
  type        = string
}
