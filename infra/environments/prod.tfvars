# ==============================================================================
# PRODUCTION ENVIRONMENT CONFIGURATION
# ==============================================================================
# Variables específicas para el ambiente de Producción
# 
# Uso:
#   terraform workspace select prod
#   terraform apply -var-file=../environments/prod.tfvars
# ==============================================================================

# ------------------------------------------------------------------------------
# Project & Environment
# ------------------------------------------------------------------------------
project_name = "movie-analyst"
environment  = "prod"
team         = "devops"
cost_center  = "migration-project"

# ------------------------------------------------------------------------------
# AWS Configuration
# ------------------------------------------------------------------------------
region = "us-east-1"
azs    = ["us-east-1a", "us-east-1b"]

# ------------------------------------------------------------------------------
# Networking - Prod usa rangos 10.20.x.x (2 públicas, 2 frontend, 2 backend, 2 DB)
# ------------------------------------------------------------------------------
vpc_cidr              = "10.20.0.0/16"
public_subnet_cidrs   = ["10.20.1.0/24", "10.20.2.0/24"]
frontend_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]
backend_subnet_cidrs  = ["10.20.13.0/24", "10.20.14.0/24"]
db_subnet_cidrs       = ["10.20.21.0/24", "10.20.22.0/24"]

# ------------------------------------------------------------------------------
# Compute - EC2 Instances
# ------------------------------------------------------------------------------
instance_type = "t3.micro"  # Considerar t3.small o t3.medium para producción real
backend_instance_count = 2

# Nombre del key pair corporativo (ver Paso 2 del README)
ssh_key_name = "movie-analyst-prod"

# Restringe el acceso SSH a la IP de tu oficina/VPN en formato /32 (Paso 3 del README)
allowed_ssh_cidrs = ["198.51.100.42/32"]

# ------------------------------------------------------------------------------
# Database - RDS MySQL
# ------------------------------------------------------------------------------
db_name     = "appdb"
db_username = "appuser"

# Exporta la contraseña con: export TF_VAR_db_password="$(openssl rand -base64 30)"
# Evita guardar contraseñas reales en Git; sustituye este valor antes de aplicar.
db_password = "ChangeMe-PROD-Pass123!"

db_instance_class    = "db.t3.micro"  # Considerar db.t3.small para producción real
db_allocated_storage = 20             # Considerar más GB para producción real

# ------------------------------------------------------------------------------
# NOTAS DE PRODUCCIÓN:
# ------------------------------------------------------------------------------
# 1. Considera Multi-AZ para RDS (mayor costo pero alta disponibilidad)
# 2. Implementar backups automáticos de RDS
# 3. Configurar alertas de CloudWatch más estrictas
# 4. Usar AWS Secrets Manager para credenciales de DB
# 5. Implementar WAF en el ALB para protección adicional
# 6. Considerar NAT Gateway en vez de NAT Instance para mayor disponibilidad
# ==============================================================================
