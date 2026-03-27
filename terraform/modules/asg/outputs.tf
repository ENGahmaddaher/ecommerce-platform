output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = aws_launch_template.app.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.app.arn
}
