# ==============================================================================
# AMBIENTE QA - Infraestructura de pruebas
# ==============================================================================
# Despliega toda la infraestructura en ambiente de Quality Assurance.
# Usa workspace "qa" para separar el state de producción.
# ==============================================================================

terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {}  // Configurado vía backend.hcl
}

provider "aws" {
  region = var.region
  
  # Tags aplicados automáticamente a TODOS los recursos
  default_tags {
    tags = {
      Project     = "movie-analyst"
      Environment = local.env
      ManagedBy   = "terraform"
      Team        = "devops"
      CostCenter  = "migration-project"
    }
  }
}

locals {
  app         = "movie-analyst"
  env         = terraform.workspace  // Usa el nombre del workspace (qa)
  name_prefix = "${local.app}-${local.env}"
  
  # Tags adicionales para recursos específicos
  common_tags = {
    Application = local.app
    Environment = local.env
  }
}

# ------------------------------------------------------------------------------
# VPC - Red virtual privada
# ------------------------------------------------------------------------------
module "vpc" {
  source               = "../../modules/vpc"
  name_prefix          = local.name_prefix
  cidr_block           = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# ------------------------------------------------------------------------------
# NAT INSTANCE - Salida a Internet para subnets privadas
# ------------------------------------------------------------------------------
module "nat" {
  source                  = "../../modules/nat-instance"
  name_prefix             = local.name_prefix
  vpc_id                  = module.vpc.vpc_id
  public_subnet_id        = module.vpc.public_subnet_ids[0]
  private_route_table_ids = module.vpc.private_route_table_ids
  private_subnet_cidrs    = var.private_subnet_cidrs
  instance_type           = var.instance_type
  key_name                = var.ssh_key_name
  allowed_ssh_cidrs       = var.allowed_ssh_cidrs
}

# ------------------------------------------------------------------------------
# BASTION - Jump server para acceso SSH
# ------------------------------------------------------------------------------
module "bastion" {
  source            = "../../modules/bastion"
  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  public_subnet_id  = module.vpc.public_subnet_ids[0]
  private_subnet_cidrs = var.private_subnet_cidrs
  instance_type     = var.instance_type
  key_name          = var.ssh_key_name
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

# ------------------------------------------------------------------------------
# ALB - Application Load Balancer
# ------------------------------------------------------------------------------
module "alb" {
  source               = "../../modules/alb"
  name_prefix          = local.name_prefix
  vpc_id               = module.vpc.vpc_id
  public_subnet_ids    = module.vpc.public_subnet_ids
  frontend_health_path = "/"
  backend_health_path  = "/api/health"
}

# ------------------------------------------------------------------------------
# EC2 FRONTEND - Servidor web en subnet privada
# ------------------------------------------------------------------------------
module "frontend" {
  source        = "../../modules/ec2-frontend"
  name_prefix   = local.name_prefix
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.private_subnet_ids[0]
  instance_type = var.instance_type
  key_name      = var.ssh_key_name
  alb_sg_id     = module.alb.alb_sg_id
  bastion_sg_id = module.bastion.sg_id
  tags          = local.common_tags
}

# ------------------------------------------------------------------------------
# EC2 BACKEND - Servidor de aplicación en subnet privada
# ------------------------------------------------------------------------------
module "backend" {
  source        = "../../modules/ec2-backend"
  name_prefix   = local.name_prefix
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.private_subnet_ids[1]
  instance_type = var.instance_type
  key_name      = var.ssh_key_name
  alb_sg_id     = module.alb.alb_sg_id
  bastion_sg_id = module.bastion.sg_id
  tags          = local.common_tags
}

# ------------------------------------------------------------------------------
# TARGET GROUP ATTACHMENTS - Registra instancias en el ALB
# ------------------------------------------------------------------------------
resource "aws_lb_target_group_attachment" "fe_attach" {
  target_group_arn = module.alb.tg_frontend_arn
  target_id        = module.frontend.instance_id
  port             = 80
}

resource "aws_lb_target_group_attachment" "be_attach" {
  target_group_arn = module.alb.tg_backend_arn
  target_id        = module.backend.instance_id
  port             = 80
}

# ------------------------------------------------------------------------------
# RDS MYSQL - Base de datos en subnet privada
# ------------------------------------------------------------------------------
module "rds" {
  source             = "../../modules/rds-mysql"
  name_prefix        = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  db_name            = var.db_name
  username           = var.db_username
  password           = var.db_password
  instance_class     = var.db_instance_class
  allocated_storage  = var.db_allocated_storage
  allowed_sg_ids     = [module.backend.sg_id]
}

# ------------------------------------------------------------------------------
# CLOUDWATCH - Monitoreo y alarmas
# ------------------------------------------------------------------------------
module "monitoring" {
  source            = "../../modules/cloudwatch"
  name_prefix       = local.name_prefix
  region            = var.region
  alb_arn_suffix    = module.alb.alb_arn_suffix
  frontend_instance = module.frontend.instance_id
  backend_instance  = module.backend.instance_id
  rds_instance      = module.rds.db_instance_id
  tg_frontend_arn   = module.alb.tg_frontend_arn_suffix
  tg_backend_arn    = module.alb.tg_backend_arn_suffix
}