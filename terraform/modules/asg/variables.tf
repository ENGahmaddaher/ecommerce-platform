variable "environment" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "target_group_arn" { type = string }
variable "ami_id" { type = string }
variable "instance_type" { type = string; default = "t3.micro" }
variable "key_name" { type = string }
variable "app_port" { type = number; default = 5000 }
variable "aws_region" { type = string; default = "us-east-1" }
variable "ecr_repo_backend" { type = string }
variable "ecr_repo_frontend" { type = string }
variable "backend_image_tag" { type = string; default = "latest" }
variable "frontend_image_tag" { type = string; default = "latest" }
variable "secrets_arns" { type = list(string); default = [] }
variable "app_security_group_id" { type = string }
variable "db_host" { type = string; default = "" }
variable "db_name" { type = string; default = "ecommerce" }
variable "db_user" { type = string; default = "postgres" }
variable "min_size" { type = number; default = 1 }
variable "max_size" { type = number; default = 3 }
variable "desired_capacity" { type = number; default = 1 }
variable "root_volume_size" { type = number; default = 20 }
variable "cpu_scale_up_threshold" { type = number; default = 70 }
variable "cpu_scale_down_threshold" { type = number; default = 30 }
variable "tags" { type = map(string); default = {} }
