variable "environment" {
  description = "Environment name"
  type        = string
}

variable "force_destroy" {
  description = "Force destroy S3 bucket"
  type        = bool
  default     = false
}

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "default_ttl" {
  description = "Default TTL for CloudFront"
  type        = number
  default     = 3600
}

variable "max_ttl" {
  description = "Maximum TTL for CloudFront"
  type        = number
  default     = 86400
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
