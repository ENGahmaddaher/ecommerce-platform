#!/bin/bash
set -e

echo "Starting user_data for ${environment}"

apt-get update -y
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker admin || true
usermod -aG docker ubuntu || true

# Install AWS CLI
apt-get install -y awscli

# Login to ECR
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${ecr_repo_backend%%/*}

# Pull images
docker pull ${ecr_repo_backend}:${backend_image_tag}
docker pull ${ecr_repo_frontend}:${frontend_image_tag}

# Create network
docker network create app-network || true

# Run backend container
docker run -d \
  --name backend \
  --network app-network \
  -p 5000:5000 \
  -e ENVIRONMENT=${environment} \
  -e DB_HOST=${db_host} \
  -e DB_NAME=${db_name} \
  -e DB_USER=${db_user} \
  -e DB_SECRET_NAME=${db_secret_name} \
  -e AWS_REGION=${aws_region} \
  --restart unless-stopped \
  ${ecr_repo_backend}:${backend_image_tag}

# Run frontend container
docker run -d \
  --name frontend \
  --network app-network \
  -p 80:80 \
  --link backend:backend \
  --restart unless-stopped \
  ${ecr_repo_frontend}:${frontend_image_tag}

echo "User data completed"
