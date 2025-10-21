# ==============================================================================
# RDS MYSQL MODULE - Base de datos MySQL
# ==============================================================================
# Base de datos administrada en subnet privada con backups automaticos.
# Solo acepta conexiones desde el security group del backend.
# ==============================================================================

# ------------------------------------------------------------------------------
# DB SUBNET GROUP - Grupo de subnets para RDS
# ------------------------------------------------------------------------------
# RDS requiere al menos 2 subnets en diferentes AZs para alta disponibilidad.
# ------------------------------------------------------------------------------
resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-rds-subnetgrp"
  subnet_ids = var.db_subnet_ids
  tags       = { Name = "${var.name_prefix}-rds-subnetgrp" }
}

# ------------------------------------------------------------------------------
# SECURITY GROUP - Reglas de firewall
# ------------------------------------------------------------------------------
resource "aws_security_group" "mysql" {
  name   = "${var.name_prefix}-rds-sg"
  vpc_id = var.vpc_id

  # MySQL solo desde security groups especificados (backend)
  dynamic "ingress" {
    for_each = var.allowed_sg_ids
    content {
      description     = "MySQL from app"
      from_port       = 3306
      to_port         = 3306
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  # Permite todo el trafico saliente
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = { Name = "${var.name_prefix}-rds-sg" }
}

# ------------------------------------------------------------------------------
# PARAMETER GROUP - Configuracion de MySQL
# ------------------------------------------------------------------------------
resource "aws_db_parameter_group" "this" {
  name        = "${var.name_prefix}-mysql-params"
  family      = "mysql8.0"
  description = "Parametros personalizados para MySQL 8.0"
  
  parameter {
    name  = "time_zone"
    value = "UTC"
  }
  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }
}

# ------------------------------------------------------------------------------
# RDS INSTANCE - Base de datos MySQL
# ------------------------------------------------------------------------------
resource "aws_db_instance" "this" {
  identifier             = "${var.name_prefix}-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.mysql.id]
  
  db_name  = var.db_name
  username = var.username
  password = var.password
  
  skip_final_snapshot        = true   // No crear snapshot al destruir (dev/qa)
  apply_immediately          = true   // Aplicar cambios inmediatamente
  publicly_accessible        = false  // No accesible desde Internet
  multi_az                   = false  // Single-AZ (ahorra costos)
  parameter_group_name       = aws_db_parameter_group.this.name
  storage_encrypted          = true   // Encriptacion en reposo
  deletion_protection        = false  // Permite destruir (cambiar a true en prod)
  auto_minor_version_upgrade = true   // Actualiza versiones menores automaticamente
  backup_retention_period    = 1      // Retiene backups por 1 dia (minimo)
  
  tags = { Name = "${var.name_prefix}-mysql" }
}