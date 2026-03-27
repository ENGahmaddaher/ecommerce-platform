kvariable "environment" {}
variable "vpc_cidr" {}
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "availability_zones" { type = list(string) }
variable "enable_nat_gateway" { default = true }
variable "tags" { default = {} }
