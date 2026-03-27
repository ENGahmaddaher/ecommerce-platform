E-Commerce Platform - Production Ready Infrastructure
This project provides a fully automated, production-grade infrastructure for an e‑commerce application on AWS. It uses Infrastructure as Code (Terraform), configuration management (Ansible), containerization (Docker), and CI/CD (GitHub Actions) to deliver a scalable, highly available, and secure environment.

Architecture Overview
User → Route53 → CloudFront (static) + ALB → Auto Scaling Group (Docker containers) → RDS (PostgreSQL)
Network: VPC with public/private subnets, NAT Gateways, and Internet Gateway.

Compute: Auto Scaling Group of EC2 instances running Docker containers (backend API + frontend).

Database: RDS PostgreSQL with automated backups and optional Multi‑AZ.

Storage: S3 for static assets + CloudFront CDN.

CI/CD: GitHub Actions builds Docker images, pushes to ECR, and applies Terraform changes.

Monitoring: CloudWatch dashboards, alarms, and custom metrics.

Tech Stack
Tool/Service	Purpose
Terraform	Infrastructure as Code
Ansible	Configuration management
Docker	Containerization
GitHub Actions	CI/CD pipeline
AWS (EC2, RDS, ALB, ECR, S3, CloudFront, Route53, Secrets Manager)	Cloud infrastructure
Python (Flask)	Backend API
HTML/CSS/JS	Frontend
Prerequisites
AWS account with appropriate permissions.

Terraform (>= 1.5)

Ansible (>= 2.9)

Docker

AWS CLI configured with credentials.

Git

Getting Started
Clone the repository

```bash
git clone https://github.com/ENGahmaddaher/ecommerce-platform.git
cd ecommerce-platform
```
Configure AWS credentials (if not already done)

```bash
aws configure
```
Create Terraform state bucket (one‑time)

```bash
aws s3 mb s3://ecommerce-terraform-state --region us-east-1
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```
Build and push Docker images (first time)

```bash
make build-push
```
Deploy infrastructure

```bash
make deploy ENV=dev      # deploys to development environment
make deploy ENV=prod     # deploys to production environment
```
Makefile Commands

Command	Description

make help	Show available commands

make deploy ENV=dev	Full deployment (build, push, terraform apply, health check)

make tf-apply	Apply Terraform changes for current ENV

make build-push	Build Docker images and push to ECR

make ansible-bastion	Configure Bastion host

make ansible-app	Configure application servers (needs Terraform outputs)

make backup	Run database backup for current ENV

make health	Run health check

make monitor	Run system monitoring script

make clean	Remove temporary files

Environment Variables

The Makefile uses ENV (default: dev) to target the appropriate environment. Terraform variables are set in terraform/environments/<env>/terraform.tfvars.


CI/CD
Development: Pushes to develop automatically deploy to the dev environment.

Production: Pushes to main trigger deployment to prod (requires manual approval if environment protection is enabled).

All workflows build Docker images, push them to ECR, run Terraform, and execute health checks.

Monitoring & Backup

CloudWatch: Dashboards, alarms for CPU, 5xx errors, and RDS connections.

Backup: Automated daily database backups stored in S3 (30‑day retention).

Restore testing: The make restore command creates a temporary RDS instance, restores the latest backup, and verifies data integrity.

Cleanup
To destroy all resources (use with caution):

```bash
make tf-destroy ENV=dev
```
License
MIT
