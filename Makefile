SHELL := /bin/bash
ENV ?= dev
AWS_REGION := us-east-1
APP_NAME := ecommerce

.PHONY: help init plan apply destroy build push deploy-dev deploy-prod backup restore health clean

help:
	@echo "Available commands:"
	@echo "  make init          - Initialize Terraform for selected environment"
	@echo "  make plan          - Show Terraform plan"
	@echo "  make apply         - Apply Terraform changes"
	@echo "  make destroy       - Destroy infrastructure"
	@echo "  make build         - Build Docker images"
	@echo "  make push          - Push Docker images to ECR"
	@echo "  make deploy-dev    - Full deploy to dev environment"
	@echo "  make deploy-prod   - Full deploy to prod environment"
	@echo "  make backup        - Run database backup"
	@echo "  make restore       - Test database restore"
	@echo "  make health        - Check system health"
	@echo "  make clean         - Clean temporary files"

init:
	@echo "Initializing Terraform for $(ENV)..."
	cd terraform/environments/$(ENV) && terraform init

plan:
	@echo "Planning Terraform changes for $(ENV)..."
	cd terraform/environments/$(ENV) && terraform plan

apply:
	@echo "Applying Terraform changes for $(ENV)..."
	cd terraform/environments/$(ENV) && terraform apply -auto-approve

destroy:
	@echo "WARNING: Destroying $(ENV) infrastructure!"
	cd terraform/environments/$(ENV) && terraform destroy -auto-approve

build:
	@echo "Building Docker images..."
	cd app/backend && docker build -t $(APP_NAME)-backend:latest .
	cd app/frontend && docker build -t $(APP_NAME)-frontend:latest .

push:
	@echo "Pushing Docker images to ECR..."
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$(AWS_REGION).amazonaws.com
	docker tag $(APP_NAME)-backend:latest $$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$(AWS_REGION).amazonaws.com/$(APP_NAME)-backend:latest
	docker push $$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$(AWS_REGION).amazonaws.com/$(APP_NAME)-backend:latest
	docker tag $(APP_NAME)-frontend:latest $$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$(AWS_REGION).amazonaws.com/$(APP_NAME)-frontend:latest
	docker push $$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$(AWS_REGION).amazonaws.com/$(APP_NAME)-frontend:latest

deploy-dev:
	@echo "Deploying to dev environment..."
	ENV=dev make apply

deploy-prod:
	@echo "Deploying to prod environment..."
	ENV=prod make apply

backup:
	@echo "Running database backup for $(ENV)..."
	./scripts/backup.sh $(ENV)

restore:
	@echo "Testing database restore for $(ENV)..."
	./scripts/restore.sh $(ENV)

health:
	@echo "Checking system health for $(ENV)..."
	./scripts/health-check.sh $(ENV)

clean:
	@echo "Cleaning temporary files..."
	find . -name "*.tfstate*" -delete
	find . -name "*.tfplan" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
