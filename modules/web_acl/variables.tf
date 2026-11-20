variable "name" {
  description = "Name of the ACL and its CloudWatch metric."
  type        = string
}

variable "scope" {
  description = "WAF scope: REGIONAL for the ALB or CLOUDFRONT for the edge."
  type        = string
}

variable "request_limit" {
  description = "Requests per client IP in a five-minute evaluation window."
  type        = number
}

variable "enforce" {
  description = "Block matching requests after reviewing the initial Count metrics."
  type        = bool
  default     = false
}
