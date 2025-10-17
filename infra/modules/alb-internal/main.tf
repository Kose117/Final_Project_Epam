# ==============================================================================
# INTERNAL ALB MODULE - Balanceador de la capa de aplicación
# ==============================================================================
# Load balancer interno (HTTP) que distribuye tráfico entre instancias backend.
# Recibe tráfico únicamente desde la capa de frontend dentro de la VPC.
# ==============================================================================

# ------------------------------------------------------------------------------
# SECURITY GROUP - Reglas de firewall para el ALB interno
# ------------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name   = "${var.name_prefix}-alb-internal-sg"
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_client_sg_ids
    content {
      description     = "HTTP from allowed SG"
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  dynamic "ingress" {
    for_each = var.allowed_ingress_cidrs
    content {
      description = "HTTP from allowed CIDR"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-alb-internal-sg" }
}

# ------------------------------------------------------------------------------
# INTERNAL APPLICATION LOAD BALANCER
# ------------------------------------------------------------------------------
resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb-internal"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids
  idle_timeout       = 60

  tags = { Name = "${var.name_prefix}-alb-internal" }
}

# ------------------------------------------------------------------------------
# TARGET GROUP - Backend
# ------------------------------------------------------------------------------
resource "aws_lb_target_group" "backend" {
  name     = "${var.name_prefix}-tg-backend-internal"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = var.backend_health_path
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# ------------------------------------------------------------------------------
# LISTENER - Puerto 80 (HTTP)
# ------------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
