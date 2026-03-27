output "bastion_id" {
  description = "ID of the Bastion instance"
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Public IP of the Bastion instance"
  value       = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  description = "Private IP of the Bastion instance"
  value       = aws_instance.bastion.private_ip
}

output "bastion_security_group_id" {
  description = "Security group ID of the Bastion"
  value       = aws_security_group.bastion.id
}

output "bastion_eip" {
  description = "Elastic IP of the Bastion"
  value       = try(aws_eip.bastion[0].public_ip, null)
}
