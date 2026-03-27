variable "environment" {}
variable "private_subnet_ids" { type = list(string) }
variable "target_group_arn" {}
variable "ami_id" {}
variable "instance_type" {}
variable "key_name" {}
variable "app_port" { default = 5000 }
variable "aws_region" { default = "us-east-1" }
variable "ecr_repo_backend" {}
variable "ecr_repo_frontend" {}
variable "backend_image_tag" { default = "latest" }
variable "frontend_image_tag" { default = "latest" }
variable "secrets_arns" { type = list(string) }
variable "app_security_group_id" {}
variable "db_host" { default = "" }
variable "db_name" { default = "ecommerce" }
variable "db_user" { default = "postgres" }
variable "min_size" { default = 1 }
variable "max_size" { default = 5 }
variable "desired_capacity" { default = 1 }
variable "root_volume_size" { default = 20 }
variable "cpu_scale_up_threshold" { default = 70 }
variable "cpu_scale_down_threshold" { default = 30 }
variable "tags" { default = {} }
