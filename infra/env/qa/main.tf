terraform {
  required_version = ">= 1.9.0"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 5.0" } }
  backend "s3" {}
}

provider "aws" {
  region = var.region
  
  # Tags por defecto en TODOS los recursos ← AGREGAR ESTO
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
  env         = terraform.workspace  # ← Cambia esto para que use el workspace
  name_prefix = "${local.app}-${local.env}"
  
  # Tags comunes para recursos específicos
  common_tags = {
    Application = local.app
    Environment = local.env
  }
}

# 1) VPC y subredes
module "vpc" {
  source               = "../../modules/vpc"
  name_prefix          = local.name_prefix
  cidr_block           = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# 2) NAT instance
module "nat" {
  source                  = "../../modules/nat-instance"
  name_prefix             = local.name_prefix
  vpc_id                  = module.vpc.vpc_id
  public_subnet_id        = module.vpc.public_subnet_ids[0]
  private_route_table_ids = module.vpc.private_route_table_ids
  instance_type           = var.instance_type
  key_name                = var.ssh_key_name
  allowed_ssh_cidrs       = var.allowed_ssh_cidrs
}

# 3) Bastion
module "bastion" {
  source            = "../../modules/bastion"
  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  public_subnet_id  = module.vpc.public_subnet_ids[0]
  instance_type     = var.instance_type
  key_name          = var.ssh_key_name
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

# 4) ALB
module "alb" {
  source               = "../../modules/alb"
  name_prefix          = local.name_prefix
  vpc_id               = module.vpc.vpc_id
  public_subnet_ids    = module.vpc.public_subnet_ids
  frontend_health_path = "/"
  backend_health_path  = "/api/health"
}

# 5) EC2 Frontend
module "frontend" {
  source         = "../../modules/ec2-frontend"
  name_prefix    = local.name_prefix
  vpc_id         = module.vpc.vpc_id
  subnet_id      = module.vpc.private_subnet_ids[0]
  instance_type  = var.instance_type
  key_name       = var.ssh_key_name
  alb_sg_id      = module.alb.alb_sg_id
  bastion_sg_id  = module.bastion.sg_id  # ← AGREGAR ESTO
  tags           = local.common_tags      # ← AGREGAR ESTO
}

# 6) EC2 Backend
module "backend" {
  source         = "../../modules/ec2-backend"
  name_prefix    = local.name_prefix
  vpc_id         = module.vpc.vpc_id
  subnet_id      = module.vpc.private_subnet_ids[1]
  instance_type  = var.instance_type
  key_name       = var.ssh_key_name
  alb_sg_id      = module.alb.alb_sg_id
  bastion_sg_id  = module.bastion.sg_id  # ← AGREGAR ESTO
  tags           = local.common_tags      # ← AGREGAR ESTO
}

# 7) Adjuntar instancias a Target Groups
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

# 8) RDS MySQL
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

# 9) Monitoring ← AGREGAR MÓDULO NUEVO
module "monitoring" {
  source            = "../../modules/monitoring"
  name_prefix       = local.name_prefix
  region            = var.region
  alb_arn_suffix    = module.alb.alb_arn_suffix
  frontend_instance = module.frontend.instance_id
  backend_instance  = module.backend.instance_id
  rds_instance      = module.rds.db_instance_id
  tg_frontend_arn   = module.alb.tg_frontend_arn_suffix
  tg_backend_arn    = module.alb.tg_backend_arn_suffix
}