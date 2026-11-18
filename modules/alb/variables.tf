variable "name" {
  description = "Name of the load balancer and prefix of its security group."
  type        = string
}

variable "vpc_id" {
  description = "VPC of the load balancer."
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC; the ALB only sends traffic inside it."
  type        = string
}

variable "subnet_ids" {
  description = "Public subnets in at least two availability zones."
  type        = list(string)
}

variable "certificate_arn" {
  description = "Default certificate of the HTTPS listener."
  type        = string
}

variable "target_port" {
  description = "Port the targets listen on."
  type        = number
  default     = 8000
}

variable "idle_timeout_seconds" {
  description = "Idle timeout of client connections, long enough for streamed generation."
  type        = number
  default     = 300
}

variable "deletion_protection" {
  description = "Protect the load balancer against deletion."
  type        = bool
  default     = true
}
