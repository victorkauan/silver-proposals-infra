variable "environment" {
  description = "Environment name (staging or prod)."
  type        = string
}

variable "region" {
  description = "AWS region of the metrics."
  type        = string
}

variable "alerts_topic_arn" {
  description = "SNS topic that receives alarm and recovery notifications."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the shared load balancer."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the environment's API target group."
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster of the API."
  type        = string
}

variable "service_name" {
  description = "ECS service of the API."
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group of the API (JSON logs)."
  type        = string
}

variable "distribution_id" {
  description = "CloudFront distribution of the app."
  type        = string
}

variable "db_instance_identifier" {
  description = "Identifier of the shared database instance."
  type        = string
}
