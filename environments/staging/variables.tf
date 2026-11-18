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
