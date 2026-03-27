#!/bin/bash
set -euo pipefail
ENVIRONMENT=${1:-dev}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEST_DB_IDENTIFIER="${ENVIRONMENT}-db-test-${TIMESTAMP}"
S3_BUCKET="ecommerce-backups"
AWS_REGION="us-east-1"

LATEST=$(aws s3 ls "s3://$S3_BUCKET/$ENVIRONMENT/db/" --region "$AWS_REGION" | sort | tail -1 | awk '{print $4}')
if [ -z "$LATEST" ]; then echo "No backup found"; exit 1; fi
echo "Using backup: $LATEST"

TEMP_DIR=$(mktemp -d)
aws s3 cp "s3://$S3_BUCKET/$ENVIRONMENT/db/$LATEST" "$TEMP_DIR/backup.gz" --region "$AWS_REGION"
gunzip "$TEMP_DIR/backup.gz"

# Create temporary RDS instance
aws rds create-db-instance \
    --db-instance-identifier "$TEST_DB_IDENTIFIER" \
    --db-instance-class db.t3.micro \
    --engine postgres --engine-version 15.3 \
    --allocated-storage 20 \
    --master-username postgres --master-user-password TempPass123! \
    --db-subnet-group-name "${ENVIRONMENT}-rds-subnet-group" \
    --vpc-security-group-ids "$(aws ec2 describe-security-groups --filters Name=group-name,Values=${ENVIRONMENT}-rds-sg --query 'SecurityGroups[0].GroupId' --output text)" \
    --region "$AWS_REGION" --no-multi-az --no-publicly-accessible
aws rds wait db-instance-available --db-instance-identifier "$TEST_DB_IDENTIFIER" --region "$AWS_REGION"

TEST_HOST=$(aws rds describe-db-instances --db-instance-identifier "$TEST_DB_IDENTIFIER" --query "DBInstances[0].Endpoint.Address" --output text --region "$AWS_REGION")
PGPASSWORD="TempPass123!" psql -h "$TEST_HOST" -U postgres -d postgres -f "$TEMP_DIR/backup"
PGPASSWORD="TempPass123!" psql -h "$TEST_HOST" -U postgres -d postgres -c "SELECT COUNT(*) FROM products;"
echo "Restore test successful"

# Cleanup
aws rds delete-db-instance --db-instance-identifier "$TEST_DB_IDENTIFIER" --skip-final-snapshot --region "$AWS_REGION"
rm -rf "$TEMP_DIR"
