variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "app_port" { type = number; default = 5000 }
variable "health_check_path" { type = string; default = "/health" }
variable "health_check_healthy_threshold" { type = number; default = 2 }
variable "health_check_unhealthy_threshold" { type = number; default = 2 }
variable "health_check_timeout" { type = number; default = 5 }
variable "health_check_interval" { type = number; default = 30 }
variable "health_check_matcher" { type = string; default = "200" }
variable "enable_deletion_protection" { type = bool; default = false }
variable "certificate_arn" { type = string; default = "" }
variable "tags" { type = map(string); default = {} }
