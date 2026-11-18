variable "name" {
  description = "Name prefix for the network resources."
  type        = string
}

variable "region" {
  description = "AWS region of the VPC, used for the S3 gateway endpoint service name."
  type        = string
}

variable "cidr_block" {
  description = "CIDR block of the VPC. Public subnets take the first /24s, isolated subnets start at the 11th."
  type        = string
  default     = "10.40.0.0/16"
}

variable "flow_log_retention_days" {
  description = "Retention of the VPC flow logs (rejected traffic only). 0 disables flow logs."
  type        = number
  default     = 14
}

variable "availability_zones" {
  description = "Availability zones of the subnets, pinned so the layout never changes silently (two are required by the ALB and RDS)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
