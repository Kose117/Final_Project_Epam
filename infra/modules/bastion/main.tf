# ==============================================================================
# BASTION MODULE - Jump Server para acceso SSH
# ==============================================================================
# Instancia pública que permite acceso SSH a instancias privadas.
# Único punto de entrada a la infraestructura privada.
# ==============================================================================

# ------------------------------------------------------------------------------
# AMI - Amazon Linux 2023
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# SECURITY GROUP - Reglas de firewall
# ------------------------------------------------------------------------------
resource "aws_security_group" "bastion" {
  name   = "${var.name_prefix}-bastion-sg"
  vpc_id = var.vpc_id

  # SSH solo desde IPs específicas (no 0.0.0.0/0 por seguridad)
  dynamic "ingress" {
    for_each = var.allowed_ssh_cidrs
    content {
      description = "SSH from allowed IPs"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # Egress SSH solo a instancias privadas (más seguro)
  egress {
    description = "SSH to private instances"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs  # Solo a subnets privadas
  }

  # Egress HTTPS para actualizaciones del sistema
  egress {
    description = "HTTPS for system updates"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress HTTP para repositorios
  egress {
    description = "HTTP for package repos"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-bastion-sg" }
}

# ------------------------------------------------------------------------------
# BASTION INSTANCE - Jump server
# ------------------------------------------------------------------------------
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  
  # Deshabilita acceso con contraseña, solo keypair
  user_data = <<-EOF
    #!/bin/bash
    set -eux
    # Endurece el acceso SSH a la instancia
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd
    

    # Actualiza paquetes base y prepara dependencias para Ansible
    dnf update -y
    dnf install -y \
      ansible-core \
      awscli \
      git \
      python3 \
      python3-pip \
      sshpass \
      tar \
      unzip \
      jq \
      fail2ban

    # Asegura la versión más reciente de pip y librerías necesarias para módulos cloud
    python3 -m pip install --upgrade pip
    python3 -m pip install --upgrade boto3 botocore

    # Directorio estándar para playbooks e inventario
    install -o ec2-user -g ec2-user -d /home/ec2-user/ansible/playbooks
    install -o ec2-user -g ec2-user -d /home/ec2-user/ansible/inventory
    install -o ec2-user -g ec2-user -d /home/ec2-user/ansible/roles

    # Archivo de configuración por defecto para reducir warnings de SSH
    cat <<'CFG' > /home/ec2-user/ansible/ansible.cfg
    [defaults]
    host_key_checking = False
    inventory = /home/ec2-user/ansible/inventory
    roles_path = /home/ec2-user/ansible/roles
    retry_files_enabled = False
    CFG
    chown ec2-user:ec2-user /home/ec2-user/ansible/ansible.cfg

    # Habilita fail2ban para proteger contra ataques de fuerza bruta
    systemctl enable --now fail2ban
  EOF

  tags = { Name = "${var.name_prefix}-bastion" }
}

# ------------------------------------------------------------------------------
# ELASTIC IP - IP pública estática
# ------------------------------------------------------------------------------
# Mantiene la misma IP pública incluso si la instancia se detiene/reinicia.
# ------------------------------------------------------------------------------
resource "aws_eip" "this" {
  domain   = "vpc"
  instance = aws_instance.bastion.id
  tags     = { Name = "${var.name_prefix}-bastion-eip" }
}