terraform {
  backend "s3" {
    bucket         = "ecommerce-terraform-state-global"
    key            = "iam/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks-global"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# مستخدم IAM لـ GitHub Actions
resource "aws_iam_user" "github_actions" {
  name = "github-actions"
}

# سياسة تسمح بالإدارة الكاملة لـ ECR, Terraform state, و Secrets Manager
resource "aws_iam_policy" "github_actions" {
  name        = "github-actions-policy"
  description = "Policy for GitHub Actions to deploy infrastructure"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::ecommerce-terraform-state-*",
          "arn:aws:s3:::ecommerce-terraform-state-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/terraform-locks-*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:*-db-password*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:CreateTags",
          "elasticloadbalancing:Describe*",
          "elasticloadbalancing:Create*",
          "elasticloadbalancing:Delete*",
          "elasticloadbalancing:Modify*",
          "autoscaling:Describe*",
          "autoscaling:Create*",
          "autoscaling:Delete*",
          "autoscaling:Update*",
          "rds:Describe*",
          "rds:Create*",
          "rds:Delete*",
          "rds:Modify*",
          "iam:PassRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "github_actions" {
  user       = aws_iam_user.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}

# مفتاح الوصول لـ GitHub Actions
resource "aws_iam_access_key" "github_actions" {
  user = aws_iam_user.github_actions.name
}

output "access_key_id" {
  value     = aws_iam_access_key.github_actions.id
  sensitive = true
}

output "secret_access_key" {
  value     = aws_iam_access_key.github_actions.secret
  sensitive = true
}
