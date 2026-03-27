#!/bin/bash
# Database Backup Script
# Usage: ./backup.sh [environment]

set -euo pipefail

ENVIRONMENT=${1:-dev}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/backups"
S3_BUCKET="ecommerce-backups"
AWS_REGION="us-east-1"
RETENTION_DAYS=30

echo "=========================================="
echo "Starting database backup for $ENVIRONMENT"
echo "Timestamp: $TIMESTAMP"
echo "=========================================="

mkdir -p "$BACKUP_DIR"

# Get database info from AWS
DB_HOST=$(aws rds describe-db-instances \
    --db-instance-identifier "${ENVIRONMENT}-db" \
    --query "DBInstances[0].Endpoint.Address" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "")

DB_NAME=$(aws rds describe-db-instances \
    --db-instance-identifier "${ENVIRONMENT}-db" \
    --query "DBInstances[0].DBName" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "ecommerce")

DB_USER="postgres"

if [ -z "$DB_HOST" ]; then
    echo "ERROR: Could not get database host for $ENVIRONMENT"
    exit 1
fi

# Get password from Secrets Manager
DB_PASSWORD=$(aws secretsmanager get-secret-value \
    --secret-id "${ENVIRONMENT}-db-password" \
    --query "SecretString" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -z "$DB_PASSWORD" ]; then
    echo "ERROR: Could not get database password"
    exit 1
fi

echo "Database: $DB_HOST/$DB_NAME"

# Perform pg_dump
BACKUP_FILE="$BACKUP_DIR/${ENVIRONMENT}-db-backup-${TIMESTAMP}.sql"
PGPASSWORD="$DB_PASSWORD" pg_dump \
    -h "$DB_HOST" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -F p \
    -f "$BACKUP_FILE" \
    2>/dev/null

if [ $? -ne 0 ] || [ ! -s "$BACKUP_FILE" ]; then
    echo "ERROR: pg_dump failed or produced empty file"
    exit 1
fi

# Compress
gzip "$BACKUP_FILE"
GZIP_FILE="${BACKUP_FILE}.gz"

# Upload to S3
aws s3 cp "$GZIP_FILE" \
    "s3://$S3_BUCKET/$ENVIRONMENT/db/" \
    --region "$AWS_REGION" \
    --storage-class STANDARD_IA

if [ $? -eq 0 ]; then
    echo "✅ Backup uploaded successfully"
else
    echo "ERROR: Upload failed"
    exit 1
fi

# Clean local
rm -f "$GZIP_FILE"

# Delete old backups (older than RETENTION_DAYS)
echo "Cleaning old backups (older than $RETENTION_DAYS days)..."
aws s3 ls "s3://$S3_BUCKET/$ENVIRONMENT/db/" \
    --region "$AWS_REGION" | \
    while read -r line; do
        file_date=$(echo "$line" | awk '{print $1}')
        file_name=$(echo "$line" | awk '{print $4}')
        file_timestamp=$(date -d "$file_date" +%s 2>/dev/null || echo 0)
        current_timestamp=$(date +%s)
        age_days=$(( (current_timestamp - file_timestamp) / 86400 ))
        if [ $age_days -gt $RETENTION_DAYS ]; then
            echo "Deleting old backup: $file_name"
            aws s3 rm "s3://$S3_BUCKET/$ENVIRONMENT/db/$file_name" --region "$AWS_REGION"
        fi
    done

echo "=========================================="
echo "✅ Backup completed successfully"
echo "=========================================="
