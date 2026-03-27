terraform {
  backend "s3" {
    bucket         = "ecommerce-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  environment = "dev"
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)
  tags = {
    Environment = "dev"
    Project     = "ecommerce"
    ManagedBy   = "terraform"
  }
}

# ECR repositories
module "ecr" {
  source = "../../modules/ecr"
  tags   = local.tags
}

# Networking
module "networking" {
  source = "../../modules/networking"
  environment         = local.environment
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = local.azs
  enable_nat_gateway   = true
  tags                 = local.tags
}

# Bastion
module "bastion" {
  source = "../../modules/bastion"
  environment           = local.environment
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  allowed_ssh_cidrs     = var.allowed_ssh_cidrs
  ami_id                = data.aws_ami.debian_12.id
  instance_type         = "t3.micro"
  key_name              = var.key_name
  root_volume_size      = 20
  allocate_eip          = true
  tags                  = local.tags
}

# ALB
module "alb" {
  source = "../../modules/alb"
  environment               = local.environment
  vpc_id                    = module.networking.vpc_id
  public_subnet_ids         = module.networking.public_subnet_ids
  app_port                  = 5000
  health_check_path         = "/health"
  enable_deletion_protection = false
  certificate_arn           = var.certificate_arn
  domain_name               = var.domain_name != "" ? "dev.${var.domain_name}" : ""
  route53_zone_id           = var.route53_zone_id
  tags                      = local.tags
}

# RDS
module "rds" {
  source = "../../modules/rds"
  environment              = local.environment
  vpc_id                   = module.networking.vpc_id
  private_subnet_ids       = module.networking.private_subnet_ids
  app_security_group_ids   = [module.alb.alb_security_group_id]
  bastion_security_group_ids = [module.bastion.bastion_security_group_id]
  db_port                  = 5432
  engine                   = "postgres"
  engine_version           = "15.3"
  instance_class           = var.rds_instance_class
  allocated_storage        = var.rds_allocated_storage
  backup_retention_period  = 7
  multi_az                 = false
  deletion_protection      = false
  skip_final_snapshot      = true
  db_name                  = "ecommerce"
  db_username              = "postgres"
  tags                     = local.tags
}

# ASG
module "asg" {
  source = "../../modules/asg"
  environment          = local.environment
  private_subnet_ids   = module.networking.private_subnet_ids
  target_group_arn     = module.alb.target_group_arn
  ami_id               = data.aws_ami.debian_12.id
  instance_type        = var.app_instance_type
  key_name             = var.key_name
  app_port             = 5000
  aws_region           = var.aws_region
  ecr_repo_backend     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/ecommerce-backend"
  ecr_repo_frontend    = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/ecommerce-frontend"
  secrets_arns         = [module.rds.db_password_secret_arn]
  app_security_group_id = module.alb.alb_security_group_id
  db_host              = module.rds.db_endpoint
  db_name              = module.rds.db_name
  db_user              = module.rds.db_username
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  root_volume_size     = 20
  cpu_scale_up_threshold   = 70
  cpu_scale_down_threshold = 30
  tags                 = local.tags
}

# S3 + CloudFront
module "static_assets" {
  source = "../../modules/s3_cloudfront"
  environment   = local.environment
  force_destroy = true
  price_class   = "PriceClass_100"
  default_ttl   = 3600
  max_ttl       = 86400
  tags          = local.tags
}

# Data
data "aws_ami" "debian_12" {
  most_recent = true
  owners      = ["136693071363"]
  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }
}
data "aws_caller_identity" "current" {}

output "alb_dns_name" { value = module.alb.alb_dns_name }
output "cloudfront_url" { value = module.static_assets.cloudfront_domain_name }
output "bastion_ip" { value = module.bastion.bastion_public_ip }
