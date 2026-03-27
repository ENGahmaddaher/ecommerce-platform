variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "app_security_group_ids" { type = list(string); default = [] }
variable "bastion_security_group_ids" { type = list(string); default = [] }
variable "db_port" { type = number; default = 5432 }
variable "engine" { type = string; default = "postgres" }
variable "engine_version" { type = string; default = "15.3" }
variable "instance_class" { type = string; default = "db.t3.micro" }
variable "allocated_storage" { type = number; default = 20 }
variable "db_name" { type = string; default = "ecommerce" }
variable "db_username" { type = string; default = "postgres" }
variable "backup_retention_period" { type = number; default = 7 }
variable "backup_window" { type = string; default = "03:00-04:00" }
variable "maintenance_window" { type = string; default = "sun:04:00-sun:05:00" }
variable "multi_az" { type = bool; default = false }
variable "deletion_protection" { type = bool; default = false }
variable "skip_final_snapshot" { type = bool; default = false }
variable "performance_insights_enabled" { type = bool; default = true }
variable "tags" { type = map(string); default = {} }
