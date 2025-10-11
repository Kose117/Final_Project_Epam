region    = "us-east-1"

azs       = ["us-east-1a", "us-east-1b"]

# CIDRs de ejemplo (¡ajusta a tu plan!)
vpc_cidr             = "10.10.0.0/16"
public_subnet_cidrs  = ["10.10.1.0/24", "10.10.2.0/24"]
private_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24"]

instance_type  = "t3.micro"
ssh_key_name   = "mi-keypair"         # TODO

allowed_ssh_cidrs = ["203.0.113.0/24"] # TODO: pon tu IP (no 0.0.0.0/0)

db_name              = "appdb"
db_username          = "appuser"
db_password          = "ChangeMe123!"   # TODO: usa TF_VAR o Vault
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
