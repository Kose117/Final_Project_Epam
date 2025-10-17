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
# Networking - QA usa rangos 10.10.x.x (2 públicas, 2 frontend, 2 backend, 2 DB)
# ------------------------------------------------------------------------------
vpc_cidr              = "10.10.0.0/16"
public_subnet_cidrs   = ["10.10.1.0/24", "10.10.2.0/24"]
frontend_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24"]
backend_subnet_cidrs  = ["10.10.13.0/24", "10.10.14.0/24"]
db_subnet_cidrs       = ["10.10.21.0/24", "10.10.22.0/24"]

# ------------------------------------------------------------------------------
# Compute - EC2 Instances
# ------------------------------------------------------------------------------
instance_type = "t3.micro"  # Free tier eligible
backend_instance_count = 2

# Nombre del key pair. Terraform lo generará automáticamente si generate_ssh_key = true
ssh_key_name = "movie-analyst-wsl"

# Deja generate_ssh_key = true para crear la llave desde Terraform la primera vez.
# Ponlo en false solo si quieres reutilizar un key pair ya existente en AWS.
generate_ssh_key = true

# Opcional: personaliza la ruta local del archivo PEM.
# ssh_private_key_path = "~/.ssh/movie-analyst-wsl.pem"

# Lista de CIDRs permitidos para SSH al bastion.
# Obtén tu IP con: curl ifconfig.me  → convierte a formato /32 (Paso 3 del README)
# Usa direcciones documentales (203.0.113.0/24) como ejemplo únicamente.
allowed_ssh_cidrs = ["203.0.113.25/32"]

# ------------------------------------------------------------------------------
# Database - RDS MySQL
# ------------------------------------------------------------------------------
db_name     = "appdb"
db_username = "appuser"

# Password del usuario master (Paso 4 del README).
# Genera el valor con: export TF_VAR_db_password="$(openssl rand -base64 24)"
# Reemplaza esta cadena sólo si decides guardarlo temporalmente en el tfvars.
db_password = "ChangeMe-QA-Pass123!"

db_instance_class    = "db.t3.micro"  # Free tier eligible
db_allocated_storage = 20             # Free tier: hasta 20 GB
