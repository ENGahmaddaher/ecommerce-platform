#!/bin/bash
set -euo pipefail
ENVIRONMENT=${1:-dev}
AWS_REGION="us-east-1"

ALB_DNS=$(aws elbv2 describe-load-balancers --names "${ENVIRONMENT}-alb" --query "LoadBalancers[0].DNSName" --output text --region "$AWS_REGION" 2>/dev/null || echo "")
if [ -z "$ALB_DNS" ]; then echo "❌ ALB not found"; exit 1; fi

echo "Health check for $ENVIRONMENT"
curl -sf "http://$ALB_DNS/health" >/dev/null && echo "✅ ALB healthy" || { echo "❌ ALB unhealthy"; exit 1; }
curl -sf "http://$ALB_DNS/api/products" >/dev/null && echo "✅ API healthy" || echo "⚠️ API issue"
curl -sf "http://$ALB_DNS/" >/dev/null && echo "✅ Frontend healthy" || echo "⚠️ Frontend issue"

echo "ASG Status:"
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "${ENVIRONMENT}-app-asg" --query "AutoScalingGroups[0].{Instances:Instances[?HealthStatus=='Healthy'] | length([*]), Desired:DesiredCapacity}" --output table --region "$AWS_REGION"
