output "db_endpoint" { value = aws_db_instance.main.endpoint }
output "db_address" { value = aws_db_instance.main.address }
output "db_port" { value = aws_db_instance.main.port }
output "db_name" { value = aws_db_instance.main.db_name }
output "db_username" { value = aws_db_instance.main.username; sensitive = true }
output "db_password_secret_arn" { value = aws_secretsmanager_secret.db_password.arn }
output "db_security_group_id" { value = aws_security_group.rds.id }
