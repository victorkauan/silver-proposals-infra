variable "name" {
  description = "Name of the budget."
  type        = string
}

variable "monthly_limit_usd" {
  description = "Monthly cost limit in USD; alerts fire at 80% and 100% of actual cost and at 100% of the forecast."
  type        = number
}

variable "alert_emails" {
  description = "E-mail addresses that receive the budget alerts."
  type        = list(string)
  sensitive   = true
}
