# E-Commerce Platform - Production Ready Infrastructure

## Overview
This project provides a complete, production-grade infrastructure for an e-commerce application. It uses modern DevOps practices: Infrastructure as Code (Terraform), Configuration Management (Ansible), Containerization (Docker), and CI/CD (GitHub Actions).

## Architecture
- **Network**: VPC with public/private subnets across multiple AZs, NAT Gateways, Internet Gateway.
- **Compute**: Auto Scaling Group of EC2 instances running Docker containers.
- **Database**: RDS PostgreSQL with Multi-AZ (production) and automated backups.
- **Storage**: S3 + CloudFront for static assets.
- **DNS**: Route 53 for custom domains.
- **Secrets**: AWS Secrets Manager for database passwords.
- **Monitoring**: CloudWatch dashboards and alarms.
- **CI/CD**: GitHub Actions to build, push, and deploy.

## Prerequisites
- AWS account with IAM permissions
- Terraform v1.5+
- Ansible v2.9+
- Docker
- AWS CLI configured
- GitHub repository (for CI/CD)

## Getting Started

### 1. Clone the repository
```bash
git clone https://github.com/your-org/ecommerce-platform.git
cd ecommerce-platform
2. Create S3 bucket for Terraform state (one-time)
bash
aws s3 mb s3://ecommerce-terraform-state --region us-east-1
aws dynamodb create-table \
    --table-name terraform-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
3. Create ECR repositories (optional, Terraform can create them)
bash
aws ecr create-repository --repository-name ecommerce-backend
aws ecr create-repository --repository-name ecommerce-frontend
4. Build and push Docker images
bash
make build
make push
5. Deploy infrastructure
bash
# Deploy dev environment
make deploy-dev

# Deploy prod environment (after updating tfvars)
make deploy-prod
6. Access the application
Get ALB DNS: terraform output -raw alb_dns_name

Static site via CloudFront: terraform output -raw cloudfront_domain_name

Environment Variables
ENV: dev or prod

AWS_REGION: us-east-1 (default)

Cleanup
bash
make destroy ENV=dev
License
MIT
