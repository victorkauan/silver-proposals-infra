output "state_bucket_name" {
  description = "Name of the S3 bucket that stores the Terraform states (used in each backend block)."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the state bucket, for the IAM policies of the CI Terraform roles."
  value       = aws_s3_bucket.state.arn
}

output "state_keys" {
  description = "State object key of each environment."
  value       = { for env in var.environments : env => "${env}/terraform.tfstate" }
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "workload_boundary_arn" {
  description = "Permissions boundary that every application role must carry."
  value       = aws_iam_policy.workload_boundary.arn
}

output "ci_role_arns" {
  description = "Terraform CI roles: <root> applies (protected environment), <root>-plan plans (pull requests)."
  value       = { for key, role in aws_iam_role.ci : key => role.arn }
}
