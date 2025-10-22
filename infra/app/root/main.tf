# ==============================================================================
# ROOT MODULE - Infraestructura Unificada
# ==============================================================================
# Modulo raiz unico parametrizado con variables.
# Reemplaza los antiguos env/qa/main.tf y env/prod/main.tf
# 
# Uso:
#   terraform workspace select qa
#   terraform apply -var-file=../environments/qa.tfvars
# ==============================================================================

terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws   = { source = "hashicorp/aws", version = "~> 5.0" }
    tls   = { source = "hashicorp/tls", version = "~> 4.0" }
    local = { source = "hashicorp/local", version = "~> 2.4" }
    http  = { source = "hashicorp/http", version = "~> 3.4" }
  }
  backend "s3" {} # Configurado via backend.hcl
}

provider "aws" {
  region = var.region

  # Tags aplicados automaticamente a TODOS los recursos
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Team        = var.team
      CostCenter  = var.cost_center
    }
  }
}

# ------------------------------------------------------------------------------
# LOCALS - Variables derivadas
# ------------------------------------------------------------------------------
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Application = var.project_name
    Environment = var.environment
    Workspace   = terraform.workspace
  }
  # IP publica detectada automaticamente para SSH
  detected_ssh_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
  # Lista final de CIDRs permitidos para SSH:
  # - Incluye los definidos por el usuario
  # - Incluye la IP detectada (si include_detected_ip=true)
  # - Opcionalmente incluye 0.0.0.0/0 si allow_ssh_anywhere=true
  effective_ssh_cidrs = distinct(
    concat(
      var.allowed_ssh_cidrs,
      var.include_detected_ip ? [local.detected_ssh_ip_cidr] : [],
      var.allow_ssh_anywhere ? ["0.0.0.0/0"] : []
    )
  )
}

# Descubre tu IP publica para permitir SSH automaticamente en el bastion
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

# ------------------------------------------------------------------------------
# IAM - Instance Profile para SSM Session Manager (acceso sin abrir SSH)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# SSH KEY - Generacion automatica del key pair de acceso
# ------------------------------------------------------------------------------
module "ssh_key" {
  source           = "../modules/ssh-key"
  key_name         = var.ssh_key_name
  private_key_path = var.ssh_private_key_path
  create           = var.generate_ssh_key
  tags             = local.common_tags
}

# ------------------------------------------------------------------------------
# VPC - Red virtual privada
# ------------------------------------------------------------------------------
module "vpc" {
  source                = "../modules/vpc"
  name_prefix           = local.name_prefix
  cidr_block            = var.vpc_cidr
  azs                   = var.azs
  public_subnet_cidrs   = var.public_subnet_cidrs
  frontend_subnet_cidrs = var.frontend_subnet_cidrs
  backend_subnet_cidrs  = var.backend_subnet_cidrs
  db_subnet_cidrs       = var.db_subnet_cidrs
}

# ------------------------------------------------------------------------------
# NAT INSTANCE - Salida a Internet para la capa de aplicacion
# ------------------------------------------------------------------------------
module "nat" {
  source                  = "../modules/nat-gateway"
  name_prefix             = local.name_prefix
  vpc_id                  = module.vpc.vpc_id
  public_subnet_id        = module.vpc.public_subnet_ids[0]
  private_route_table_ids = concat(module.vpc.frontend_route_table_ids, module.vpc.backend_route_table_ids)
}

# ------------------------------------------------------------------------------
# BASTION - Jump server para acceso SSH
# ------------------------------------------------------------------------------
module "bastion" {
  source               = "../modules/bastion"
  name_prefix          = local.name_prefix
  vpc_id               = module.vpc.vpc_id
  public_subnet_id     = module.vpc.public_subnet_ids[0]
  private_subnet_cidrs = concat(var.frontend_subnet_cidrs, var.backend_subnet_cidrs)
  instance_type        = var.instance_type
  key_name             = module.ssh_key.key_name
  allowed_ssh_cidrs    = local.effective_ssh_cidrs
}

# ------------------------------------------------------------------------------
# ALB - Application Load Balancer
# ------------------------------------------------------------------------------
module "alb_public" {
  source                  = "../modules/alb"
  name_prefix             = local.name_prefix
  vpc_id                  = module.vpc.vpc_id
  public_subnet_ids       = module.vpc.public_subnet_ids
  frontend_health_path    = "/"
  enable_backend_listener = false
}

# ------------------------------------------------------------------------------
# EC2 FRONTEND - Servidor web en subnet privada
# ------------------------------------------------------------------------------
module "frontend" {
  source        = "../modules/ec2-frontend"
  name_prefix   = local.name_prefix
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.frontend_subnet_ids[0]
  alb_sg_id     = module.alb_public.alb_sg_id
  bastion_sg_id = module.bastion.sg_id
  tags          = local.common_tags
  instance_type  = var.instance_type
  key_name       = module.ssh_key.key_name
}

# ------------------------------------------------------------------------------
# INTERNAL ALB - Balanceador privado para el backend
# ------------------------------------------------------------------------------
module "alb_internal" {
  source                = "../modules/alb-internal"
  name_prefix           = local.name_prefix
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.backend_subnet_ids
  backend_health_path   = "/api/health"
  allowed_client_sg_ids = [module.frontend.sg_id, module.bastion.sg_id]
}

# ------------------------------------------------------------------------------
# EC2 BACKEND - Servidor de aplicacion en subnet privada
# ------------------------------------------------------------------------------
module "backend" {
  source         = "../modules/ec2-backend"
  name_prefix    = local.name_prefix
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.backend_subnet_ids
  instance_count = var.backend_instance_count
  instance_type  = var.instance_type
  key_name       = module.ssh_key.key_name
  alb_sg_id      = module.alb_internal.alb_sg_id
  bastion_sg_id  = module.bastion.sg_id
  tags           = local.common_tags
}

# ------------------------------------------------------------------------------
# TARGET GROUP ATTACHMENTS - Registra instancias en el ALB
# ------------------------------------------------------------------------------
resource "aws_lb_target_group_attachment" "fe_attach" {
  target_group_arn = module.alb_public.tg_frontend_arn
  target_id        = module.frontend.instance_id
  port             = 80
}

resource "aws_lb_target_group_attachment" "be_attach" {
  for_each         = { for idx, id in module.backend.instance_ids : tostring(idx) => id }
  target_group_arn = module.alb_internal.tg_backend_arn
  target_id        = each.value
  port             = 80
}

# ------------------------------------------------------------------------------
# RDS MYSQL - Base de datos en subnets de la capa de datos
# ------------------------------------------------------------------------------
module "rds" {
  source            = "../modules/rds-mysql"
  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  db_subnet_ids     = module.vpc.db_subnet_ids
  db_name           = var.db_name
  username          = var.db_username
  password          = var.db_password
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  allowed_sg_ids    = [module.backend.sg_id, module.bastion.sg_id]
}

# ------------------------------------------------------------------------------
# CLOUDWATCH - Monitoreo y alarmas
# ------------------------------------------------------------------------------
module "monitoring" {
  source                  = "../modules/cloudwatch"
  name_prefix             = local.name_prefix
  region                  = var.region
  public_alb_arn_suffix   = module.alb_public.alb_arn_suffix
  internal_alb_arn_suffix = module.alb_internal.alb_arn_suffix
  frontend_instance       = module.frontend.instance_id
  backend_instances       = module.backend.instance_ids
  rds_instance            = module.rds.db_instance_id
  tg_frontend_arn_suffix  = module.alb_public.tg_frontend_arn_suffix
  tg_backend_arn_suffix   = module.alb_internal.tg_backend_arn_suffix
}

