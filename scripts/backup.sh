#!/bin/bash
set -euo pipefail
ENVIRONMENT=${1:-dev}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/backups"
S3_BUCKET="ecommerce-backups"
AWS_REGION="us-east-1"

mkdir -p "$BACKUP_DIR"

DB_HOST=$(aws rds describe-db-instances --db-instance-identifier "${ENVIRONMENT}-db" --query "DBInstances[0].Endpoint.Address" --output text --region "$AWS_REGION")
DB_NAME=$(aws rds describe-db-instances --db-instance-identifier "${ENVIRONMENT}-db" --query "DBInstances[0].DBName" --output text --region "$AWS_REGION")
DB_USER="postgres"
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "${ENVIRONMENT}-db-password" --query "SecretString" --output text --region "$AWS_REGION")

echo "Backing up $DB_HOST/$DB_NAME"
PGPASSWORD="$DB_PASSWORD" pg_dump -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -F p > "$BACKUP_DIR/${ENVIRONMENT}-db-backup-${TIMESTAMP}.sql"
gzip "$BACKUP_DIR/${ENVIRONMENT}-db-backup-${TIMESTAMP}.sql"
aws s3 cp "$BACKUP_DIR/${ENVIRONMENT}-db-backup-${TIMESTAMP}.sql.gz" "s3://$S3_BUCKET/$ENVIRONMENT/db/" --region "$AWS_REGION"
rm -f "$BACKUP_DIR/${ENVIRONMENT}-db-backup-"*

# Keep last 30 days
aws s3 ls "s3://$S3_BUCKET/$ENVIRONMENT/db/" --region "$AWS_REGION" | sort | head -n -30 | awk '{print $4}' | while read f; do
    aws s3 rm "s3://$S3_BUCKET/$ENVIRONMENT/db/$f" --region "$AWS_REGION"
done
