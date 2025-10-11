resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-rds-subnetgrp"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.name_prefix}-rds-subnetgrp" }
}

resource "aws_security_group" "mysql" {
  name   = "${var.name_prefix}-rds-sg"
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_sg_ids
    content {
      description     = "MySQL from app SG"
      from_port       = 3306
      to_port         = 3306
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
  tags = { Name = "${var.name_prefix}-rds-sg" }
}

resource "aws_db_parameter_group" "this" {
  name        = "${var.name_prefix}-mysql-params"
  family      = "mysql8.0"
  description = "Parametros básicos"
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

resource "aws_db_instance" "this" {
  identifier              = "${var.name_prefix}-mysql"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.mysql.id]
  db_name                 = var.db_name
  username                = var.username
  password                = var.password
  skip_final_snapshot     = true
  apply_immediately       = true
  publicly_accessible     = false
  multi_az                = false
  parameter_group_name    = aws_db_parameter_group.this.name
  storage_encrypted       = true
  deletion_protection     = false
  auto_minor_version_upgrade = true
  backup_retention_period = 1
  tags = { Name = "${var.name_prefix}-mysql" }
}
