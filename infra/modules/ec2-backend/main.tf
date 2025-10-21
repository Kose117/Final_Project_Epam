# ==============================================================================
# EC2 BACKEND MODULE - Multiples Instancias para Alta Disponibilidad
# ==============================================================================
# Crea N instancias de backend distribuidas en diferentes subnets/AZs.
# El ALB distribuye la carga entre todas las instancias.
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
# SECURITY GROUP - Compartido por todas las instancias backend
# ------------------------------------------------------------------------------
resource "aws_security_group" "app" {
  name   = "${var.name_prefix}-be-sg"
  vpc_id = var.vpc_id

  # HTTP solo desde el ALB
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  # SSH solo desde el Bastion
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg_id]
  }

  # Permite todo el trafico saliente
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    { Name = "${var.name_prefix}-be-sg" }
  )
}

# ------------------------------------------------------------------------------
# BACKEND INSTANCES - Multiples instancias distribuidas
# ------------------------------------------------------------------------------
resource "aws_instance" "be" {
  count = var.instance_count

  ami           = data.aws_ami.al2023.id
  instance_type = var.instance_type

  # Distribuye instancias en diferentes subnets (diferentes AZs)
  subnet_id = var.subnet_ids[count.index % length(var.subnet_ids)]

  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = var.key_name
  associate_public_ip_address = false

  # User data basico - Ansible configurara la aplicacion real
  user_data = <<-EOF
    #!/bin/bash
    set -eux
    # Reintentos para instalar python3
    for i in $(seq 1 20); do
      if command -v python3 >/dev/null 2>&1; then break; fi
      dnf -y install python3 && break || true
      sleep 15
    done

    # Servidor HTTP placeholder (Ansible instalara Node.js despues)
    if command -v python3 >/dev/null 2>&1; then
    cat >/usr/local/bin/app.py <<PY
from http.server import BaseHTTPRequestHandler, HTTPServer
import socket
class H(BaseHTTPRequestHandler):
  def do_GET(self):
    hostname = socket.gethostname()
    if self.path.startswith('/api'):
      self.send_response(200)
      self.send_header('Content-type', 'text/plain')
      self.end_headers()
      self.wfile.write(f'Backend OK from {hostname}\n'.encode())
    else:
      self.send_response(404)
      self.end_headers()
HTTPServer(('', 80), H).serve_forever()
PY
    chmod +x /usr/local/bin/app.py
    nohup python3 /usr/local/bin/app.py >/var/log/app.log 2>&1 || true &
    fi
  EOF

  user_data_replace_on_change = true

  tags = merge(
    var.tags,
    {
      Name     = "${var.name_prefix}-backend-${count.index + 1}"
      Role     = "backend"
      Instance = "${count.index + 1}"
    }
  )
}
