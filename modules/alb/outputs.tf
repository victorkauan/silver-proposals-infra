output "dns_name" {
  description = "DNS name of the load balancer (target of the API CNAME records)."
  value       = aws_lb.this.dns_name
}

output "https_listener_arn" {
  description = "HTTPS listener where each environment adds its host-based rule."
  value       = aws_lb_listener.https.arn
}

output "security_group_id" {
  description = "Security group of the load balancer, the only allowed source of task traffic."
  value       = aws_security_group.alb.id
}

output "arn_suffix" {
  description = "ARN suffix of the load balancer, for CloudWatch metrics."
  value       = aws_lb.this.arn_suffix
}
