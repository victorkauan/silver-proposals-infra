output "app_url" {
  description = "Public URL of the frontend."
  value       = module.frontend.url
}

output "api_url" {
  description = "Public URL of the API (VITE_API_BASE_URL of the frontend build)."
  value       = module.api.url
}

output "frontend_bucket_name" {
  description = "Bucket that receives the frontend build."
  value       = module.frontend.bucket_name
}

output "frontend_bucket_arn" {
  description = "ARN of the frontend bucket."
  value       = module.frontend.bucket_arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution of the frontend."
  value       = module.frontend.distribution_id
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution."
  value       = module.frontend.distribution_arn
}

output "ecs_cluster_name" {
  description = "ECS cluster of the API."
  value       = module.api.cluster_name
}

output "ecs_service_name" {
  description = "ECS service of the API."
  value       = module.api.service_name
}

output "ecs_task_definition_family" {
  description = "Task definition family of the API."
  value       = module.api.task_definition_family
}

output "ecs_task_role_arn" {
  description = "Task role of the API."
  value       = module.api.task_role_arn
}

output "ecs_execution_role_arn" {
  description = "Execution role of the API tasks."
  value       = module.api.execution_role_arn
}

output "api_log_group_name" {
  description = "CloudWatch log group of the API."
  value       = module.api.log_group_name
}

output "app_secret_arn" {
  description = "Secrets Manager secret of the API."
  value       = module.api.app_secret_arn
}

output "backend_deploy_role_arn" {
  description = "OIDC role of the backend deploy workflow."
  value       = module.api.deploy_role_arn
}

output "frontend_deploy_role_arn" {
  description = "OIDC role of the frontend deploy workflow."
  value       = module.frontend.deploy_role_arn
}

output "ecs_task_security_group_id" {
  description = "Security group for one-off API tasks (migrations)."
  value       = module.api.task_security_group_id
}

output "ecs_subnet_ids" {
  description = "Subnets for one-off API tasks (migrations)."
  value       = module.api.subnet_ids
}
