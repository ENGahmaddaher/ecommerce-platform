ENV ?= dev
AWS_REGION ?= us-east-1
APP_NAME ?= ecommerce
TERRAFORM_DIR = terraform/environments/$(ENV)
ANSIBLE_INVENTORY = ansible/inventory/$(ENV)/hosts
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text)
ECR_URL = $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
.PHONY: help
help:
	@echo "E-Commerce Platform Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make tf-init       - Initialize Terraform for $(ENV)"
	@echo "  make tf-plan       - Show Terraform plan for $(ENV)"
	@echo "  make tf-apply      - Apply Terraform changes for $(ENV)"
	@echo "  make tf-destroy    - Destroy infrastructure for $(ENV)"
	@echo "  make build         - Build Docker images (backend + frontend)"
	@echo "  make push          - Push Docker images to ECR (logs in, tags, pushes)"
	@echo "  make build-push    - Build and push images (shortcut)"
	@echo "  make ansible-ping  - Test Ansible connection to all hosts"
	@echo "  make ansible-bastion - Configure Bastion host"
	@echo "  make ansible-app   - Configure application servers (needs variables)"
	@echo "  make backup        - Run database backup for $(ENV)"
	@echo "  make restore       - Test database restore for $(ENV)"
	@echo "  make health        - Run health check for $(ENV)"
	@echo "  make monitor       - Run monitoring script for $(ENV)"
	@echo "  make rotate-logs   - Rotate application logs"
	@echo "  make deploy        - Full deployment (build, push, terraform apply, health check)"
	@echo "  make clean         - Clean temporary files"
	@echo ""
	@echo "Environment: ENV=$(ENV) (dev or prod)"

# ============================================================
# Terraform targets
# ============================================================
.PHONY: tf-init tf-plan tf-apply tf-destroy
tf-init:
	@echo "Initializing Terraform for $(ENV)..."
	cd $(TERRAFORM_DIR) && terraform init

tf-plan: tf-init
	@echo "Planning Terraform changes for $(ENV)..."
	cd $(TERRAFORM_DIR) && terraform plan

tf-apply: tf-init
	@echo "Applying Terraform changes for $(ENV)..."
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve

tf-destroy: tf-init
	@echo "WARNING: Destroying infrastructure for $(ENV)..."
	cd $(TERRAFORM_DIR) && terraform destroy -auto-approve

# ============================================================
# Docker targets
# ============================================================
.PHONY: build push build-push

build:
	@echo "Building Docker images..."
	cd app/backend && docker build -t $(APP_NAME)-backend:latest .
	cd app/frontend && docker build -t $(APP_NAME)-frontend:latest .

ecr-login:
	@echo "Logging in to Amazon ECR..."
	aws ecr get-login-password --region $(AWS_REGION) | \
		docker login --username AWS --password-stdin $(ECR_URL)

push: ecr-login
	@echo "Tagging and pushing images to ECR..."
	docker tag $(APP_NAME)-backend:latest $(ECR_URL)/$(APP_NAME)-backend:latest
	docker tag $(APP_NAME)-backend:latest $(ECR_URL)/$(APP_NAME)-backend:$(shell git rev-parse --short HEAD)
	docker push $(ECR_URL)/$(APP_NAME)-backend:latest
	docker push $(ECR_URL)/$(APP_NAME)-backend:$(shell git rev-parse --short HEAD)
	docker tag $(APP_NAME)-frontend:latest $(ECR_URL)/$(APP_NAME)-frontend:latest
	docker tag $(APP_NAME)-frontend:latest $(ECR_URL)/$(APP_NAME)-frontend:$(shell git rev-parse --short HEAD)
	docker push $(ECR_URL)/$(APP_NAME)-frontend:latest
	docker push $(ECR_URL)/$(APP_NAME)-frontend:$(shell git rev-parse --short HEAD)
	@echo "✅ Images pushed to ECR"

build-push: build push
	@echo "✅ Build and push completed"

# ============================================================
# Ansible targets
# ============================================================
.PHONY: ansible-ping ansible-bastion ansible-app

ansible-ping:
	ansible -i $(ANSIBLE_INVENTORY) all -m ping

ansible-bastion:
	ansible-playbook -i $(ANSIBLE_INVENTORY) ansible/playbooks/bastion.yml


ansible-app:
	@echo "Running Ansible for application servers (requires terraform outputs)..."
	cd $(TERRAFORM_DIR) && \
	ECR_BACKEND=$$(terraform output -raw backend_ecr_url 2>/dev/null) && \
	ECR_FRONTEND=$$(terraform output -raw frontend_ecr_url 2>/dev/null) && \
	DB_HOST=$$(terraform output -raw db_endpoint 2>/dev/null) && \
	cd - >/dev/null && \
	ansible-playbook -i $(ANSIBLE_INVENTORY) ansible/playbooks/app.yml \
		-e "ecr_repo_backend=$$ECR_BACKEND" \
		-e "ecr_repo_frontend=$$ECR_FRONTEND" \
		-e "backend_image_tag=latest" \
		-e "frontend_image_tag=latest" \
		-e "db_host=$$DB_HOST" \
		-e "db_name=ecommerce" \
		-e "db_user=postgres"

# ============================================================
# Scripts targets
# ============================================================
.PHONY: backup restore health monitor rotate-logs

backup:
	./scripts/backup.sh $(ENV)

restore:
	./scripts/restore.sh $(ENV)

health:
	./scripts/health-check.sh $(ENV)

monitor:
	./scripts/monitoring.sh $(ENV)

rotate-logs:
	./scripts/rotate-logs.sh

# ============================================================
# Deployment target (full CI/CD)
# ============================================================
.PHONY: deploy

deploy: build-push tf-apply health
	@echo "✅ Deployment completed for $(ENV)"

# ============================================================
# Cleanup
# ============================================================
.PHONY: clean

clean:
	@echo "Cleaning temporary files..."
	find . -name "*.tfstate*" -delete
	find . -name "*.tfplan" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.pyc" -delete
	rm -rf ansible/facts_cache
	@echo "Cleanup done"
