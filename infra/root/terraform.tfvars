# ==============================================================================
# TERRAFORM VARIABLES TEMPLATE
# ==============================================================================
# Este es un archivo de ejemplo. NO usar directamente.
# Copiar a ../environments/AMBIENTE.tfvars y editar con valores reales.
# ==============================================================================

# Project & Environment
project_name = "movie-analyst"
environment  = "qa"  # qa | prod | dev
team         = "devops"
cost_center  = "migration-project"

# AWS Configuration
region = "us-east-1"
azs    = ["us-east-1a", "us-east-1b"]

# Networking
vpc_cidr            = "10.10.0.0/16"
public_subnet_cidrs = ["10.10.1.0/24", "10.10.2.0/24"]
app_subnet_cidrs    = ["10.10.11.0/24", "10.10.12.0/24"]
db_subnet_cidrs     = ["10.10.21.0/24", "10.10.22.0/24"]

# Compute
instance_type     = "t3.micro"
ssh_key_name      = "TU-KEYPAIR-AQUI"        # ⚠️ CAMBIAR
allowed_ssh_cidrs = ["123.45.67.89/32"]      # ⚠️ CAMBIAR por tu IP

# Database
db_name              = "appdb"
db_username          = "appuser"
db_password          = "CAMBIAR-PASSWORD"     # ⚠️ CAMBIAR
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20