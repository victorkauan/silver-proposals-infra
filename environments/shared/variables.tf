variable "monthly_budget_usd" {
  description = "Monthly cost limit of the account in USD (overrun alert, set above the expected cost)."
  type        = number
  default     = 100
}

variable "budget_alert_emails" {
  description = "E-mail addresses for the budget and alarm notifications. Set TF_VAR_budget_alert_emails (JSON list) or a git-ignored *.tfvars file; never commit them."
  type        = list(string)
  sensitive   = true
}

variable "enforce_waf" {
  description = "Switch the regional ACL from Count to Block after reviewing the metrics."
  type        = bool
  default     = false
}

variable "enable_access_logs" {
  description = "Deliver ALB access logs after the frontend uses the body-based public share resolver."
  type        = bool
  default     = false
}
