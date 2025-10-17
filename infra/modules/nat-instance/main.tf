# ==============================================================================
# NAT INSTANCE MODULE - Salida a Internet para subnets privadas
# ==============================================================================
# Usa una instancia EC2 t3.micro como NAT en vez de NAT Gateway.
# ==============================================================================

# ------------------------------------------------------------------------------
# AMI - Amazon Linux 2023
# ------------------------------------------------------------------------------
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"]  // AWS cuenta oficial
  
  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# ------------------------------------------------------------------------------
# SECURITY GROUP - Reglas de firewall
# ------------------------------------------------------------------------------
resource "aws_security_group" "nat" {
  name        = "${var.name_prefix}-nat-sg"
  description = "NAT instance SG"
  vpc_id      = var.vpc_id

  # Permite HTTP/HTTPS únicamente desde las subnets de aplicación
  dynamic "ingress" {
    for_each = var.private_subnet_cidrs
    content {
      description = "HTTP from private subnets"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  dynamic "ingress" {
    for_each = var.private_subnet_cidrs
    content {
      description = "HTTPS from private subnets"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # Permite todo el tráfico saliente
  egress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "DNS TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "DNS UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-nat-sg" }
}

# ------------------------------------------------------------------------------
# NAT INSTANCE - Instancia EC2 actuando como NAT
# ------------------------------------------------------------------------------
resource "aws_instance" "nat" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.nat.id]
  key_name                    = var.key_name
  source_dest_check           = false  // CRÍTICO: permite reenvío de paquetes
  associate_public_ip_address = true

  # Configuración inicial: habilita IP forwarding y NAT con iptables
  user_data = <<-EOF
    #!/bin/bash
    set -eux
    # Habilita reenvío de IP (routing)
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    
    # Configura NAT con iptables
    IPT=$(which iptables)
    $IPT -t nat -A POSTROUTING -o eth0 -j MASQUERADE  // Enmascara IPs privadas
    $IPT -A FORWARD -i eth0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    $IPT -A FORWARD -s 0.0.0.0/0 -o eth0 -j ACCEPT
  EOF

  tags = { Name = "${var.name_prefix}-nat" }
}

# ------------------------------------------------------------------------------
# ROUTES - Rutas default hacia la instancia NAT
# ------------------------------------------------------------------------------
# Agrega ruta 0.0.0.0/0 -> NAT instance en cada tabla de rutas de la capa de aplicación.
# ------------------------------------------------------------------------------
resource "aws_route" "private_default" {
  for_each               = toset(var.private_route_table_ids)
  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = aws_instance.nat.id
}