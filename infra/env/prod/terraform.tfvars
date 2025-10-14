# Región AWS
region = "us-east-1"

# Zonas de disponibilidad
azs = ["us-east-1a", "us-east-1b"]

# Redes - PROD usa rangos diferentes a QA
vpc_cidr             = "10.20.0.0/16"
public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24"]
private_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]

# Instancias EC2
instance_type = "t3.micro"
ssh_key_name  = "TU-KEYPAIR-AQUI"  # TODO: Cambiar por tu keypair

# Seguridad SSH - Limita acceso a tu IP
allowed_ssh_cidrs = ["1.2.3.4/32"]  # TODO: Cambiar por tu IP pública

# Base de datos RDS
db_name              = "appdb"
db_username          = "appuser"
db_password          = "CAMBIAR-POR-PASSWORD-SEGURO"  # TODO: Usar variable de entorno
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20