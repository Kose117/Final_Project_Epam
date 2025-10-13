# Región AWS
region = "us-east-1"

# Zonas de disponibilidad
azs = ["us-east-1a", "us-east-1b"]

# Redes (ajusta según tu diseño)
vpc_cidr             = "10.10.0.0/16"
public_subnet_cidrs  = ["10.10.1.0/24", "10.10.2.0/24"]
private_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24"]

# Instancias EC2
instance_type = "t3.micro"
ssh_key_name  = "TU-KEYPAIR-AQUI"  # Cambia esto

# Seguridad SSH (¡pon tu IP!)
allowed_ssh_cidrs = ["1.2.3.4/32"]  # Cambia esto por tu IP

# Base de datos RDS
db_name              = "appdb"
db_username          = "appuser"
db_password          = "CAMBIAR-POR-PASSWORD-SEGURO"  # Cambia esto
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20