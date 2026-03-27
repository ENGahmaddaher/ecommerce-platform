resource "aws_security_group" "this" {
  name        = "${var.environment}-bastion-sg"
  description = "Bastion security group"
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

resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.this.id]
  key_name               = var.key_name
  associate_public_ip_address = true
  user_data = templatefile("${path.module}/user_data.sh", { environment = var.environment })
  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }
  tags = merge(var.tags, { Name = "${var.environment}-bastion" })
}

resource "aws_eip" "this" {
  count    = var.allocate_eip ? 1 : 0
  instance = aws_instance.this.id
  domain   = "vpc"
  tags     = merge(var.tags, { Name = "${var.environment}-bastion-eip" })
}
