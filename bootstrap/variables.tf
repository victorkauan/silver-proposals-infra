variable "state_bucket_name" {
  description = "Globally unique name of the S3 bucket that stores every Terraform state of the project."
  type        = string
  default     = "silversoft-silver-proposals-tfstate"
}

variable "operator_user_names" {
  description = "IAM users allowed to read and write the state from a workstation (human operators)."
  type        = list(string)
  default     = ["victor-admin"]
}

variable "ci_role_prefix" {
  description = "Name prefix of the IAM roles that CI assumes through GitHub OIDC to run Terraform, one per environment (for example <prefix>-staging)."
  type        = string
  default     = "silver-proposals-terraform"
}

variable "environments" {
  description = "Environments that keep their state under <environment>/terraform.tfstate in the bucket."
  type        = list(string)
  default     = ["staging", "prod"]
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep previous versions of a state file before they expire."
  type        = number
  default     = 90
}
