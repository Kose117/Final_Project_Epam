# ==============================================================================
# EC2 FRONTEND MODULE - Servidor web (Nginx)
# ==============================================================================
# Instancia en subnet privada que sirve el frontend de la aplicacion.
# Solo acepta trafico HTTP desde el ALB y SSH desde el Bastion.
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
resource "aws_security_group" "app" {
  name   = "${var.name_prefix}-fe-sg"
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

  # Permite todo el trafico saliente (para instalar paquetes via NAT)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    { Name = "${var.name_prefix}-fe-sg" }
  )
}

# ------------------------------------------------------------------------------
# FRONTEND INSTANCE
# ------------------------------------------------------------------------------
resource "aws_instance" "fe" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = var.key_name
  associate_public_ip_address = false  // Sin IP publica (esta en subnet privada)

  # Configuracion inicial: intenta instalar python3 con reintentos y
  # levanta un servidor HTTP minimo en el puerto 80 para health checks.
  # Evita depender de la disponibilidad inmediata del NAT.
  user_data = <<-EOF
    #!/bin/bash
    set -eux
    # Reintentos para instalar python3 (20 intentos x 15s = ~5 min)
    for i in $(seq 1 20); do
      if command -v python3 >/dev/null 2>&1; then break; fi
      dnf -y install python3 && break || true
      sleep 15
    done
    if command -v python3 >/dev/null 2>&1; then
    cat >/usr/local/bin/frontend.py <<'PY'
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
  def do_GET(self):
    self.send_response(200)
    self.send_header('Content-type', 'text/plain')
    self.end_headers()
    self.wfile.write(b'Frontend OK')
HTTPServer(('', 80), H).serve_forever()
PY
    chmod +x /usr/local/bin/frontend.py
    nohup python3 /usr/local/bin/frontend.py >/var/log/frontend.log 2>&1 || true &
    fi
  EOF

  user_data_replace_on_change = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-frontend"
      Role = "frontend"
    }
  )
}