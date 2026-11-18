variable "name" {
  description = "Name of the image repository."
  type        = string
}

variable "images_to_keep" {
  description = "Number of images kept; older ones expire."
  type        = number
  default     = 30
}
