data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"]
  filter { name = "name"   values = ["al2023-ami-*-kernel-6.1-x86_64"] }
  filter { name = "state"  values = ["available"] }
}

resource "aws_security_group" "app" {
  name   = "${var.name_prefix}-be-sg"
  vpc_id = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-be-sg" }
}

resource "aws_instance" "be" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = var.key_name
  associate_public_ip_address = false

  # Placeholder: HTTP mínimo; luego Ansible pone Node/Express
  user_data = <<-EOF
    #!/bin/bash
    set -eux
    dnf update -y
    dnf install -y python3
    cat >/usr/local/bin/app.py <<PY
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
  def do_GET(self):
    if self.path.startswith('/api'):
      self.send_response(200); self.end_headers(); self.wfile.write(b'Backend OK')
    else:
      self.send_response(404); self.end_headers()
HTTPServer(('', 80), H).serve_forever()
PY
    chmod +x /usr/local/bin/app.py
    nohup python3 /usr/local/bin/app.py >/var/log/app.log 2>&1 &
  EOF

  tags = { Name = "${var.name_prefix}-be" }
}
