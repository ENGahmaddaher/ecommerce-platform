# IAM Role للخوادم
resource "aws_iam_role" "app" {
  name = "${var.environment}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "app" {
  name = "${var.environment}-app-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = var.secrets_arns
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["cloudwatch:PutMetricData"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.app.arn
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.environment}-app-instance-profile"
  role = aws_iam_role.app.name
}

# Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "${var.environment}-app-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  vpc_security_group_ids = [var.app_security_group_id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    environment         = var.environment
    aws_region          = var.aws_region
    ecr_repo_backend    = var.ecr_repo_backend
    ecr_repo_frontend   = var.ecr_repo_frontend
    backend_image_tag   = var.backend_image_tag
    frontend_image_tag  = var.frontend_image_tag
    db_host             = var.db_host
    db_name             = var.db_name
    db_user             = var.db_user
    db_secret_name      = "${var.environment}-db-password"
  }))

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, { Name = "${var.environment}-app-instance" })
  }

  tags = merge(var.tags, { Name = "${var.environment}-app-lt" })
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name               = "${var.environment}-app-asg"
  vpc_zone_identifier = var.private_subnet_ids
  min_size           = var.min_size
  max_size           = var.max_size
  desired_capacity   = var.desired_capacity

  target_group_arns = [var.target_group_arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-app-instance"
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# Scaling policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.environment}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_scale_up_threshold
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.environment}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.environment}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_scale_down_threshold
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
}
