#!/bin/bash
# Health Check Script
# Usage: ./health-check.sh [environment]

set -euo pipefail

ENVIRONMENT=${1:-dev}
AWS_REGION="us-east-1"

echo "=========================================="
echo "Health Check for $ENVIRONMENT environment"
echo "Time: $(date)"
echo "=========================================="

ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names "${ENVIRONMENT}-alb" \
    --query "LoadBalancers[0].DNSName" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -z "$ALB_DNS" ]; then
    echo "❌ ALB not found"
    exit 1
fi

echo "ALB DNS: $ALB_DNS"

echo -n "Checking ALB... "
ALB_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/health" 2>/dev/null || echo "000")
if [ "$ALB_STATUS" = "200" ] || [ "$ALB_STATUS" = "502" ]; then
    echo "✅ Responding (HTTP $ALB_STATUS)"
else
    echo "❌ Unhealthy (HTTP $ALB_STATUS)"
fi

echo -n "Checking Backend API... "
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/api/products" 2>/dev/null || echo "000")
if [ "$API_STATUS" = "200" ]; then
    echo "✅ Healthy"
elif [ "$API_STATUS" = "502" ]; then
    echo "⚠️ No servers (502)"
else
    echo "❌ Unhealthy (HTTP $API_STATUS)"
fi

echo -n "Checking Frontend... "
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/" 2>/dev/null || echo "000")
if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "✅ Healthy"
elif [ "$FRONTEND_STATUS" = "502" ]; then
    echo "⚠️ No servers (502)"
else
    echo "❌ Unhealthy (HTTP $FRONTEND_STATUS)"
fi

echo ""
echo "Auto Scaling Group Status:"
ASG_NAME="${ENVIRONMENT}-app-asg"
aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query "AutoScalingGroups[0].{Instances:Instances[?HealthStatus=='Healthy'] | length([*]), Desired:DesiredCapacity, Min:MinSize, Max:MaxSize}" \
    --output table \
    --region "$AWS_REGION" 2>/dev/null || echo "ASG not found"

echo ""
echo "RDS Status:"
RDS_ID="${ENVIRONMENT}-db"
RDS_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_ID" \
    --query "DBInstances[0].DBInstanceStatus" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "Not found")

if [ "$RDS_STATUS" = "available" ]; then
    echo "✅ RDS: $RDS_STATUS"
elif [ -n "$RDS_STATUS" ]; then
    echo "⚠️ RDS: $RDS_STATUS"
else
    echo "❌ RDS not found"
fi

echo ""
echo "CloudWatch Alarms in ALARM state:"
aws cloudwatch describe-alarms \
    --alarm-name-prefix "$ENVIRONMENT" \
    --state-value "ALARM" \
    --query "MetricAlarms[].AlarmName" \
    --output table \
    --region "$AWS_REGION" 2>/dev/null || echo "No alarms in ALARM state"

echo "=========================================="
echo "Health Check Completed"
echo "=========================================="
