output "address" {
  description = "Host name of the database endpoint."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port of the database endpoint."
  value       = aws_db_instance.this.port
}

output "security_group_id" {
  description = "Security group of the database; each environment allows its tasks in."
  value       = aws_security_group.database.id
}

output "master_user_secret_arn" {
  description = "Secrets Manager secret (managed by RDS) with the master user's credentials."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "identifier" {
  description = "Identifier of the database instance, for CloudWatch metrics."
  value       = aws_db_instance.this.identifier
}
