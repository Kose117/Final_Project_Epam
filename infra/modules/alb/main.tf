# ==============================================================================
# ALB MODULE - Application Load Balancer
# ==============================================================================
# Load balancer L7 (HTTP) que distribuye tráfico entre frontend y backend.
# Regla: /api/* -> backend, resto -> frontend.
# ==============================================================================

# ------------------------------------------------------------------------------
# SECURITY GROUP - Reglas de firewall para el ALB
# ------------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name   = "${var.name_prefix}-alb-sg"
  vpc_id = var.vpc_id

  # Acepta tráfico HTTP desde cualquier IP
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permite todo el tráfico saliente
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-alb-sg" }
}

# ------------------------------------------------------------------------------
# APPLICATION LOAD BALANCER
# ------------------------------------------------------------------------------
resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"  // network(Capa 4) / application(Capa 7)
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
  idle_timeout       = 60  // Segundos antes de cerrar conexión inactiva
  
  tags = { Name = "${var.name_prefix}-alb" }
}

# ------------------------------------------------------------------------------
# TARGET GROUP - Frontend
# ------------------------------------------------------------------------------
# Agrupa instancias frontend para health checks y distribución de carga.
# ------------------------------------------------------------------------------
resource "aws_lb_target_group" "frontend" {
  name     = "${var.name_prefix}-tg-frontend"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  health_check {
    enabled             = true
    path                = var.frontend_health_path
    matcher             = "200-399"  // Códigos HTTP considerados saludables
    interval            = 30         // Segundos entre checks
    timeout             = 5          // Segundos esperando respuesta
    healthy_threshold   = 2          // Checks exitosos para marcar como healthy
    unhealthy_threshold = 3          // Checks fallidos para marcar como unhealthy
  }
}

# ------------------------------------------------------------------------------
# TARGET GROUP - Backend
# ------------------------------------------------------------------------------
resource "aws_lb_target_group" "backend" {
  name     = "${var.name_prefix}-tg-backend"
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
# Por defecto, todo el tráfico va al frontend.
# ------------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# ------------------------------------------------------------------------------
# LISTENER RULE - Rutas /api/* al backend
# ------------------------------------------------------------------------------
resource "aws_lb_listener_rule" "api_to_backend" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10  // Menor número = mayor prioridad

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}