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
