data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Amazon
  filter { name = "name"   values = ["al2023-ami-*-kernel-6.1-x86_64"] }
  filter { name = "state"  values = ["available"] }
}

resource "aws_security_group" "nat" {
  name        = "${var.name_prefix}-nat-sg"
  description = "NAT instance SG"
  vpc_id      = var.vpc_id

  # SSH solo desde tus rangos
  dynamic "ingress" {
    for_each = var.allowed_ssh_cidrs
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # Egress total
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-nat-sg" }
}

resource "aws_instance" "nat" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.nat.id]
  key_name               = var.key_name
  source_dest_check      = false
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    # NAT via iptables
    IPT=$(which iptables)
    $IPT -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    $IPT -A FORWARD -i eth0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    $IPT -A FORWARD -s 0.0.0.0/0 -o eth0 -j ACCEPT
  EOF

  tags = { Name = "${var.name_prefix}-nat" }
}

# Rutas por cada RT privada: default a la instancia NAT
resource "aws_route" "private_default" {
  for_each               = toset(var.private_route_table_ids)
  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = aws_instance.nat.id
}
