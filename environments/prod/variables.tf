variable "image_tag" {
  description = "Tag of the backend image to run (set by the deploy pipeline)."
  type        = string
  default     = "unreleased"
}

variable "desired_count" {
  description = "Number of running API tasks; stays 0 until the first image is published."
  type        = number
  default     = 0
}


variable "initialize_app_secret" {
  description = "Create the initial application secret for an empty environment."
  type        = bool
  default     = false
}
