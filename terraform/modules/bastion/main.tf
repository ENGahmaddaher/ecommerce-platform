resource "aws_security_group" "bastion" {
  name        = "${var.environment}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.environment}-bastion-sg" })
}

resource "aws_instance" "bastion" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = var.key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    environment = var.environment
  })

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(var.tags, { Name = "${var.environment}-bastion" })
}

resource "aws_eip" "bastion" {
  count    = var.allocate_eip ? 1 : 0
  instance = aws_instance.bastion.id
  domain   = "vpc"
  tags     = merge(var.tags, { Name = "${var.environment}-bastion-eip" })
}
