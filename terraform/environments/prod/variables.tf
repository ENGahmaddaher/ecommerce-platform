variable "aws_region" { default = "us-east-1" }
variable "vpc_cidr" { default = "10.0.0.0/16" }
variable "public_subnet_cidrs" { default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"] }
variable "private_subnet_cidrs" { default = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"] }
variable "allowed_ssh_cidrs" { type = list(string) }
variable "key_name" {}
variable "rds_instance_class" { default = "db.t3.large" }
variable "rds_allocated_storage" { default = 100 }
variable "app_instance_type" { default = "t3.medium" }
variable "certificate_arn" {}
variable "domain_name" {}
variable "route53_zone_id" {}
