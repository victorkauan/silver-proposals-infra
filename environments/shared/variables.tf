variable "monthly_budget_usd" {
  description = "Monthly cost limit of the account in USD (early-warning alert)."
  type        = number
  default     = 40
}

variable "budget_alert_emails" {
  description = "E-mail addresses for the budget and alarm notifications. Set TF_VAR_budget_alert_emails (JSON list) or a git-ignored *.tfvars file; never commit them."
  type        = list(string)
  sensitive   = true
}
