resource "aws_security_group" "rds" {
  name        = "${var.environment}-rds-sg"
  description = "Security group for RDS"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.app_security_group_ids
    content {
      description     = "PostgreSQL from app servers"
      from_port       = var.db_port
      to_port         = var.db_port
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  dynamic "ingress" {
    for_each = var.bastion_security_group_ids
    content {
      description     = "PostgreSQL from bastion"
      from_port       = var.db_port
      to_port         = var.db_port
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.environment}-rds-sg" })
}

resource "aws_db_subnet_group" "rds" {
  name        = "${var.environment}-rds-subnet-group"
  subnet_ids  = var.private_subnet_ids
  tags = merge(var.tags, { Name = "${var.environment}-rds-subnet-group" })
}

resource "random_password" "db_password" {
  length  = 16
  special = false
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.environment}-db-password"
  rotation_rules {
    automatically_after_days = 30
  }
  tags = merge(var.tags, { Name = "${var.environment}-db-password" })
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

resource "aws_db_instance" "main" {
  identifier     = "${var.environment}-db"
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class
  allocated_storage     = var.allocated_storage
  storage_encrypted     = true
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  multi_az               = var.multi_az
  publicly_accessible    = false
  deletion_protection    = var.deletion_protection
  skip_final_snapshot    = var.skip_final_snapshot
  performance_insights_enabled = var.performance_insights_enabled
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = merge(var.tags, { Name = "${var.environment}-rds" })
}
