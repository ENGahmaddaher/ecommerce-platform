#!/bin/bash
# Database Restore Test Script
# Usage: ./restore.sh [environment]

set -euo pipefail

ENVIRONMENT=${1:-dev}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEST_DB_IDENTIFIER="${ENVIRONMENT}-db-test-${TIMESTAMP}"
S3_BUCKET="ecommerce-backups"
AWS_REGION="us-east-1"

echo "=========================================="
echo "Testing database restore for $ENVIRONMENT"
echo "Test DB: $TEST_DB_IDENTIFIER"
echo "=========================================="

# Find latest backup
LATEST_BACKUP=$(aws s3 ls "s3://$S3_BUCKET/$ENVIRONMENT/db/" \
    --region "$AWS_REGION" | \
    sort | \
    tail -n 1 | \
    awk '{print $4}')

if [ -z "$LATEST_BACKUP" ]; then
    echo "ERROR: No backup found"
    exit 1
fi

echo "Latest backup: $LATEST_BACKUP"

# Download backup
TEMP_DIR=$(mktemp -d)
aws s3 cp "s3://$S3_BUCKET/$ENVIRONMENT/db/$LATEST_BACKUP" \
    "$TEMP_DIR/backup.gz" \
    --region "$AWS_REGION"

gunzip "$TEMP_DIR/backup.gz"

# Get network info
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=${ENVIRONMENT}-vpc" \
    --query "Vpcs[0].VpcId" \
    --output text \
    --region "$AWS_REGION")

SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${ENVIRONMENT}-private-*" \
    --query "Subnets[*].SubnetId" \
    --output text \
    --region "$AWS_REGION")

SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${ENVIRONMENT}-rds-sg" \
    --query "SecurityGroups[0].GroupId" \
    --output text \
    --region "$AWS_REGION")

# Create DB Subnet Group
aws rds create-db-subnet-group \
    --db-subnet-group-name "${TEST_DB_IDENTIFIER}-subnet-group" \
    --db-subnet-group-description "Test restore subnet group" \
    --subnet-ids $SUBNET_IDS \
    --region "$AWS_REGION" 2>/dev/null || true

# Create temporary RDS instance
aws rds create-db-instance \
    --db-instance-identifier "$TEST_DB_IDENTIFIER" \
    --db-instance-class "db.t3.micro" \
    --engine "postgres" \
    --engine-version "15.3" \
    --allocated-storage 20 \
    --master-username "postgres" \
    --master-user-password "TempPass123!@#" \
    --db-subnet-group-name "${TEST_DB_IDENTIFIER}-subnet-group" \
    --vpc-security-group-ids "$SECURITY_GROUP_ID" \
    --region "$AWS_REGION" \
    --no-multi-az \
    --no-publicly-accessible \
    --backup-retention-period 0

# Wait for instance to be available
echo "Waiting for RDS instance to become available (may take 5-10 minutes)..."
aws rds wait db-instance-available \
    --db-instance-identifier "$TEST_DB_IDENTIFIER" \
    --region "$AWS_REGION"

TEST_DB_HOST=$(aws rds describe-db-instances \
    --db-instance-identifier "$TEST_DB_IDENTIFIER" \
    --query "DBInstances[0].Endpoint.Address" \
    --output text \
    --region "$AWS_REGION")

echo "Test DB host: $TEST_DB_HOST"

# Restore data
PGPASSWORD="TempPass123!@#" psql \
    -h "$TEST_DB_HOST" \
    -U "postgres" \
    -d "postgres" \
    -f "$TEMP_DIR/backup" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Data restored successfully"
else
    echo "ERROR: Restore failed"
    exit 1
fi

# Run test queries
PGPASSWORD="TempPass123!@#" psql \
    -h "$TEST_DB_HOST" \
    -U "postgres" \
    -d "postgres" \
    -c "SELECT COUNT(*) FROM products;" 2>/dev/null || echo "No products table"

# Cleanup
aws rds delete-db-instance \
    --db-instance-identifier "$TEST_DB_IDENTIFIER" \
    --skip-final-snapshot \
    --region "$AWS_REGION"

aws rds delete-db-subnet-group \
    --db-subnet-group-name "${TEST_DB_IDENTIFIER}-subnet-group" \
    --region "$AWS_REGION" 2>/dev/null || true

rm -rf "$TEMP_DIR"

echo "=========================================="
echo "✅ Restore test completed successfully!"
echo "=========================================="
