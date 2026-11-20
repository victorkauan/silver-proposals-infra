output "id" {
  description = "Name of the archive bucket."
  value       = aws_s3_bucket.this.id
}

output "arn" {
  description = "ARN of the archive bucket."
  value       = aws_s3_bucket.this.arn
}
