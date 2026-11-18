output "cloudflare_zone_id" {
  description = "Cloudflare zone of silversoft.com.br."
  value       = data.cloudflare_zone.this.zone_id
}

output "vpc_id" {
  description = "ID of the shared VPC."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnets for the load balancer and the API tasks."
  value       = module.network.public_subnet_ids
}

output "alb_security_group_id" {
  description = "Security group of the shared load balancer."
  value       = module.alb.security_group_id
}

output "alb_dns_name" {
  description = "DNS name of the shared load balancer."
  value       = module.alb.dns_name
}

output "https_listener_arn" {
  description = "HTTPS listener where each environment adds its host rule."
  value       = module.alb.https_listener_arn
}

output "database_address" {
  description = "Host name of the shared PostgreSQL instance."
  value       = module.database.address
}

output "database_port" {
  description = "Port of the shared PostgreSQL instance."
  value       = module.database.port
}

output "database_security_group_id" {
  description = "Security group of the shared database."
  value       = module.database.security_group_id
}

output "database_master_secret_arn" {
  description = "RDS-managed master credentials, used only by the database setup tasks."
  value       = module.database.master_user_secret_arn
}

output "ecr_repository_url" {
  description = "Repository of the backend image (ECR_REPOSITORY_URL of the backend workflows)."
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the backend image repository."
  value       = module.ecr.repository_arn
}
