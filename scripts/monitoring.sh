k#!/bin/bash
set -euo pipefail
ENVIRONMENT=${1:-dev}
AWS_REGION="us-east-1"
echo "Monitoring for $ENVIRONMENT"
ALB_DNS=$(aws elbv2 describe-load-balancers --names "${ENVIRONMENT}-alb" --query "LoadBalancers[0].DNSName" --output text --region "$AWS_REGION" 2>/dev/null)
if [ -n "$ALB_DNS" ]; then
    curl -s "http://$ALB_DNS/api/metrics" | python3 -m json.tool || echo "Unable to fetch metrics"
fi
END=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START=$(date -u -d '1 hour ago' +"%Y-%m-%dT%H:%M:%SZ")
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name RequestCount --dimensions Name=LoadBalancer,Value="${ENVIRONMENT}-alb" --start-time "$START" --end-time "$END" --period 3600 --statistics Sum --query "Datapoints[0].Sum" --output text --region "$AWS_REGION" 2>/dev/null && echo " requests last hour"
