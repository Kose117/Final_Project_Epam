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
# Networking - Prod usa rangos 10.20.x.x (2 públicas, 2 privadas App, 2 privadas DB)
# ------------------------------------------------------------------------------
vpc_cidr            = "10.20.0.0/16"
public_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24"]
app_subnet_cidrs    = ["10.20.11.0/24", "10.20.12.0/24"]
db_subnet_cidrs     = ["10.20.21.0/24", "10.20.22.0/24"]

# ------------------------------------------------------------------------------
# Compute - EC2 Instances
# ------------------------------------------------------------------------------
instance_type = "t3.micro"  # Considerar t3.small o t3.medium para producción real
backend_instance_count = 2

# ⚠️ TODO: CAMBIAR POR TU KEY PAIR
ssh_key_name = "devops-keypair"

# ⚠️ TODO: CAMBIAR POR IP DE OFICINA O VPN
# Para producción, restringir acceso SSH a IPs conocidas
allowed_ssh_cidrs = ["0.0.0.0/0"]  # ⚠️ CAMBIAR: Muy inseguro para producción

# ------------------------------------------------------------------------------
# Database - RDS MySQL
# ------------------------------------------------------------------------------
db_name     = "appdb"
db_username = "appuser"

# ⚠️ TODO: USAR VARIABLE DE ENTORNO EN PRODUCCIÓN
# NUNCA commitear passwords de producción a Git
# Usar: export TF_VAR_db_password="PasswordSuperSeguro-Prod-2024!"
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