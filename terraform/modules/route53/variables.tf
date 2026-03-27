variable "domain_name" { type = string }
variable "api_subdomain" { type = string; default = "api" }
variable "static_subdomain" { type = string; default = "static" }
variable "api_alb_dns_name" { type = string; default = "" }
variable "api_alb_zone_id" { type = string; default = "" }
variable "static_cloudfront_domain_name" { type = string; default = "" }
