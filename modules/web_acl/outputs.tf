output "arn" {
  description = "ARN of the web ACL."
  value       = aws_wafv2_web_acl.this.arn
}
