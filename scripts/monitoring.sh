#!/bin/bash
# System Monitoring Script
# Usage: ./monitoring.sh [environment]

set -euo pipefail

ENVIRONMENT=${1:-dev}
AWS_REGION="us-east-1"

echo "=========================================="
echo "System Monitoring for $ENVIRONMENT"
echo "Time: $(date)"
echo "=========================================="

ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names "${ENVIRONMENT}-alb" \
    --query "LoadBalancers[0].DNSName" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "")

echo "Application Metrics:"
if [ -n "$ALB_DNS" ]; then
    curl -s "http://$ALB_DNS/api/metrics" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "Unable to fetch metrics"
else
    echo "ALB not found"
fi

echo ""
echo "CloudWatch Metrics (Last Hour):"
END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_TIME=$(date -u -d '1 hour ago' +"%Y-%m-%dT%H:%M:%SZ")

REQUESTS=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name RequestCount \
    --dimensions Name=LoadBalancer,Value="${ENVIRONMENT}-alb" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 3600 \
    --statistics Sum \
    --query "Datapoints[0].Sum" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "N/A")
echo "Total Requests (last hour): ${REQUESTS:-0}"

ERRORS=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name HTTPCode_Target_5XX_Count \
    --dimensions Name=LoadBalancer,Value="${ENVIRONMENT}-alb" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 3600 \
    --statistics Sum \
    --query "Datapoints[0].Sum" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "N/A")
echo "5xx Errors (last hour): ${ERRORS:-0}"

ASG_NAME="${ENVIRONMENT}-app-asg"
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query "AutoScalingGroups[0].Instances[].InstanceId" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -n "$INSTANCE_IDS" ]; then
    echo ""
    echo "CPU Utilization:"
    for INSTANCE_ID in $INSTANCE_IDS; do
        CPU=$(aws cloudwatch get-metric-statistics \
            --namespace AWS/EC2 \
            --metric-name CPUUtilization \
            --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
            --start-time "$START_TIME" \
            --end-time "$END_TIME" \
            --period 3600 \
            --statistics Average \
            --query "Datapoints[0].Average" \
            --output text \
            --region "$AWS_REGION" 2>/dev/null || echo "N/A")
        echo "  Instance $INSTANCE_ID: ${CPU:-N/A}%"
    done
fi

RDS_ID="${ENVIRONMENT}-db"
RDS_CONNECTIONS=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name DatabaseConnections \
    --dimensions Name=DBInstanceIdentifier,Value="$RDS_ID" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 3600 \
    --statistics Average \
    --query "Datapoints[0].Average" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "N/A")
echo ""
echo "RDS Connections (avg last hour): ${RDS_CONNECTIONS:-0}"

BACKUP_COUNT=$(aws s3 ls "s3://ecommerce-backups/$ENVIRONMENT/db/" \
    --region "$AWS_REGION" 2>/dev/null | wc -l)
echo "Backup Files in S3: $BACKUP_COUNT"

echo "=========================================="
echo "Monitoring Completed"
echo "=========================================="
