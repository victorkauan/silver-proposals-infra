output "app_url" {
  description = "Public URL of the frontend."
  value       = module.environment.app_url
}

output "api_url" {
  description = "Public URL of the API (VITE_API_BASE_URL of the frontend build)."
  value       = module.environment.api_url
}

output "frontend_bucket_name" {
  description = "Bucket that receives the frontend build (S3_BUCKET)."
  value       = module.environment.frontend_bucket_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution to invalidate after a frontend deploy (CLOUDFRONT_DISTRIBUTION_ID)."
  value       = module.environment.cloudfront_distribution_id
}

output "ecs_cluster_name" {
  description = "ECS cluster of the API (ECS_CLUSTER)."
  value       = module.environment.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS service of the API (ECS_SERVICE)."
  value       = module.environment.ecs_service_name
}

output "ecs_task_definition_family" {
  description = "Task definition family of the API."
  value       = module.environment.ecs_task_definition_family
}

output "ecs_task_role_arn" {
  description = "Task role of the API (Bedrock access, no keys)."
  value       = module.environment.ecs_task_role_arn
}

output "ecs_execution_role_arn" {
  description = "Execution role of the API tasks."
  value       = module.environment.ecs_execution_role_arn
}

output "api_log_group_name" {
  description = "CloudWatch log group of the API."
  value       = module.environment.api_log_group_name
}

output "app_secret_arn" {
  description = "Secrets Manager secret of the API."
  value       = module.environment.app_secret_arn
}

output "backend_deploy_role_arn" {
  description = "OIDC role of the backend deploy workflow (AWS_DEPLOY_ROLE_ARN in the backend repository)."
  value       = module.environment.backend_deploy_role_arn
}

output "frontend_deploy_role_arn" {
  description = "OIDC role of the frontend deploy workflow (AWS_DEPLOY_ROLE_ARN in the frontend repository)."
  value       = module.environment.frontend_deploy_role_arn
}

output "ecs_task_security_group_id" {
  description = "Security group for one-off API tasks such as migrations (ECS_SECURITY_GROUP)."
  value       = module.environment.ecs_task_security_group_id
}

output "ecs_subnet_ids" {
  description = "Subnets for one-off API tasks such as migrations (ECS_SUBNETS)."
  value       = module.environment.ecs_subnet_ids
}
