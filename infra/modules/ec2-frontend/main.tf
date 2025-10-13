data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "app" {
  name   = "${var.name_prefix}-fe-sg"
  vpc_id = var.vpc_id

  # Tráfico HTTP desde el ALB
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  # SSH desde Bastion ← AGREGAR ESTO
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    { Name = "${var.name_prefix}-fe-sg" }
  )  # ← TAGS DINÁMICOS
}

resource "aws_instance" "fe" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = var.key_name
  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    dnf update -y
    dnf install -y nginx
    echo "Frontend OK" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOF

  tags = merge(
    var.tags,
    { Name = "${var.name_prefix}-fe" }
  )  # ← TAGS DINÁMICOS
}