variable "name" {
  description = "Globally unique name of the private archive."
  type        = string
}

variable "retention_days" {
  description = "Days before current objects expire."
  type        = number
}
