variable "name" {
  description = "Identifier of the database instance and prefix of its resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC of the database."
  type        = string
}

variable "subnet_ids" {
  description = "Isolated subnets (no internet route) in at least two availability zones."
  type        = list(string)
}

variable "engine_major_version" {
  description = "PostgreSQL major version; minor versions are upgraded automatically."
  type        = string
  default     = "17"
}

variable "instance_class" {
  description = "Instance class of the database."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage_gb" {
  description = "Initial gp3 storage in GB."
  type        = number
  default     = 20
}

variable "max_allocated_storage_gb" {
  description = "Upper limit for storage autoscaling in GB."
  type        = number
  default     = 50
}

variable "backup_retention_days" {
  description = "Days of automated backups (point-in-time recovery window)."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Protect the instance against deletion."
  type        = bool
  default     = true
}
