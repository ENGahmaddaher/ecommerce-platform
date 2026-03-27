variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "allowed_ssh_cidrs" { type = list(string); default = ["0.0.0.0/0"] }
variable "ami_id" { type = string }
variable "instance_type" { type = string; default = "t3.micro" }
variable "key_name" { type = string }
variable "root_volume_size" { type = number; default = 20 }
variable "allocate_eip" { type = bool; default = true }
variable "tags" { type = map(string); default = {} }
