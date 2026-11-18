output "repository_url" {
  description = "URL of the repository, used to push and pull images."
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN of the repository, for push permissions."
  value       = aws_ecr_repository.this.arn
}
