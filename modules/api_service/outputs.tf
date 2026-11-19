output "cluster_name" {
  description = "ECS cluster of the environment (backend deploy target)."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "ECS service of the API (backend deploy target)."
  value       = aws_ecs_service.api.name
}

output "task_definition_family" {
  description = "Task definition family of the API, for new revisions on deploy."
  value       = aws_ecs_task_definition.api.family
}

output "task_role_arn" {
  description = "Role the API runs with (Bedrock access, no keys)."
  value       = aws_iam_role.task.arn
}

output "execution_role_arn" {
  description = "Role ECS uses to pull the image, read the secrets, and write logs."
  value       = aws_iam_role.execution.arn
}

output "app_secret_arn" {
  description = "Secrets Manager secret with the API's JWT secret and database URL."
  value       = aws_secretsmanager_secret.app.arn
}

output "log_group_name" {
  description = "CloudWatch log group of the API."
  value       = aws_cloudwatch_log_group.api.name
}

output "url" {
  description = "Public URL of the API."
  value       = "https://${var.api_host_name}"
}

output "deploy_role_arn" {
  description = "Role the backend deploy workflow assumes through OIDC (AWS_DEPLOY_ROLE_ARN)."
  value       = aws_iam_role.deploy.arn
}

output "task_security_group_id" {
  description = "Security group of the API tasks, for one-off tasks such as migrations."
  value       = aws_security_group.task.id
}

output "subnet_ids" {
  description = "Subnets of the API tasks, for one-off tasks such as migrations."
  value       = var.subnet_ids
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the API target group, for CloudWatch metrics."
  value       = aws_lb_target_group.api.arn_suffix
}
