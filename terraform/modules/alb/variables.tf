variable "environment" {}
variable "vpc_id" {}
variable "public_subnet_ids" { type = list(string) }
variable "app_port" { default = 5000 }
variable "health_check_path" { default = "/health" }
variable "health_check_healthy_threshold" { default = 2 }
variable "health_check_unhealthy_threshold" { default = 2 }
variable "health_check_timeout" { default = 5 }
variable "health_check_interval" { default = 30 }
variable "health_check_matcher" { default = "200" }
variable "enable_deletion_protection" { default = false }
variable "certificate_arn" { default = "" }
variable "domain_name" { default = "" }
variable "route53_zone_id" { default = "" }
variable "tags" { default = {} }
