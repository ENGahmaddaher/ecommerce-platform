terraform {
  backend "s3" {
    bucket         = "ecommerce-terraform-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks-prod"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_ami" "debian_12" {
  most_recent = true
  owners      = ["136693071363"]
  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }
}

locals {
  environment = "prod"
  azs         = slice(data.aws_availability_zones.available.names, 0, 3)
  tags = {
    Environment = "production"
    Project     = "ecommerce"
    ManagedBy   = "terraform"
  }
}

# ECR
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

# Bastion (مع تقييد عناوين IP)
module "bastion" {
  source = "../../modules/bastion"

  environment       = local.environment
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  ami_id            = data.aws_ami.debian_12.id
  instance_type     = "t3.micro"
  key_name          = var.key_name
  tags              = local.tags
}

# ALB (مع شهادة SSL)
module "alb" {
  source = "../../modules/alb"

  environment               = local.environment
  vpc_id                    = module.networking.vpc_id
  public_subnet_ids         = module.networking.public_subnet_ids
  enable_deletion_protection = true
  certificate_arn           = var.certificate_arn
  tags                      = local.tags
}

# RDS (Multi-AZ)
module "rds" {
  source = "../../modules/rds"

  environment              = local.environment
  vpc_id                   = module.networking.vpc_id
  private_subnet_ids       = module.networking.private_subnet_ids
  app_security_group_ids   = [module.alb.alb_security_group_id]
  bastion_security_group_ids = [module.bastion.bastion_security_group_id]
  instance_class           = var.rds_instance_class
  allocated_storage        = var.rds_allocated_storage
  backup_retention_period  = 30
  multi_az                 = true
  deletion_protection      = true
  skip_final_snapshot      = false
  db_name                  = "ecommerce"
  db_username              = "postgres"
  tags                     = local.tags
}

# ASG (أكبر)
module "asg" {
  source = "../../modules/asg"

  environment          = local.environment
  private_subnet_ids   = module.networking.private_subnet_ids
  target_group_arn     = module.alb.target_group_arn
  ami_id               = data.aws_ami.debian_12.id
  instance_type        = var.app_instance_type
  key_name             = var.key_name
  aws_region           = var.aws_region
  ecr_repo_backend     = module.ecr.backend_repository_url
  ecr_repo_frontend    = module.ecr.frontend_repository_url
  secrets_arns         = [module.rds.db_password_secret_arn]
  app_security_group_id = module.alb.alb_security_group_id
  db_host              = module.rds.db_address
  db_name              = module.rds.db_name
  db_user              = module.rds.db_username
  min_size             = 2
  max_size             = 10
  desired_capacity     = 2
  root_volume_size     = 50
  tags                 = local.tags
}

# S3 + CloudFront
module "static_assets" {
  source = "../../modules/s3_cloudfront"

  environment   = local.environment
  force_destroy = false
  tags          = local.tags
}

# Route53 (لنطاق مخصص)
module "route53" {
  source = "../../modules/route53"

  domain_name                 = var.domain_name
  api_subdomain               = "api"
  static_subdomain            = "static"
  api_alb_dns_name            = module.alb.alb_dns_name
  api_alb_zone_id             = module.alb.alb_zone_id
  static_cloudfront_domain_name = module.static_assets.cloudfront_domain_name
}

output "alb_dns_name" { value = module.alb.alb_dns_name }
output "bastion_ip" { value = module.bastion.bastion_public_ip }
output "cloudfront_url" { value = module.static_assets.cloudfront_domain_name }
output "api_domain" { value = module.route53.api_fqdn }
output "static_domain" { value = module.route53.static_fqdn }
output "rds_endpoint" { value = module.rds.db_endpoint; sensitive = true }
