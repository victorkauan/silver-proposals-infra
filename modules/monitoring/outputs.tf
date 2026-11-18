output "dashboard_name" {
  description = "CloudWatch dashboard of the environment."
  value       = aws_cloudwatch_dashboard.this.dashboard_name
}
