# ==============================================================================
# QA ENVIRONMENT CONFIGURATION
# ==============================================================================
# Variables específicas para el ambiente de Quality Assurance
# 
# Uso:
#   terraform workspace select qa
#   terraform apply -var-file=../environments/qa.tfvars
# ==============================================================================

# ------------------------------------------------------------------------------
# Project & Environment
# ------------------------------------------------------------------------------
project_name = "movie-analyst"
environment  = "qa"
team         = "devops"
cost_center  = "migration-project"

# ------------------------------------------------------------------------------
# AWS Configuration
# ------------------------------------------------------------------------------
region = "us-east-1"
azs    = ["us-east-1a", "us-east-1b"]

# ------------------------------------------------------------------------------
# Networking - QA usa rangos 10.10.x.x (2 públicas, 2 privadas App, 2 privadas DB)
# ------------------------------------------------------------------------------
vpc_cidr            = "10.10.0.0/16"
public_subnet_cidrs = ["10.10.1.0/24", "10.10.2.0/24"]
app_subnet_cidrs    = ["10.10.11.0/24", "10.10.12.0/24"]
db_subnet_cidrs     = ["10.10.21.0/24", "10.10.22.0/24"]

# ------------------------------------------------------------------------------
# Compute - EC2 Instances
# ------------------------------------------------------------------------------
instance_type = "t3.micro"  # Free tier eligible
backend_instance_count = 2

# ⚠️ TODO: CAMBIAR POR TU KEY PAIR
# Debe existir en AWS: EC2 → Key Pairs
ssh_key_name = "devops-keypair"

# ⚠️ TODO: CAMBIAR POR TU IP PÚBLICA
# Obtener con: curl ifconfig.me
# Formato: ["123.45.67.89/32"]
allowed_ssh_cidrs = ["0.0.0.0/0"]  # ⚠️ CAMBIAR: Permite SSH desde cualquier IP (inseguro, solo para testing)

# ------------------------------------------------------------------------------
# Database - RDS MySQL
# ------------------------------------------------------------------------------
db_name     = "appdb"
db_username = "appuser"

# ⚠️ TODO: CAMBIAR POR PASSWORD SEGURO
# IMPORTANTE: NO commitear passwords reales a Git
# Mejor práctica: usar variable de entorno
#   export TF_VAR_db_password="MiPasswordSeguro123!"
db_password = "ChangeMe-QA-Pass123!"

db_instance_class    = "db.t3.micro"  # Free tier eligible
db_allocated_storage = 20             # Free tier: hasta 20 GB