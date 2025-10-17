# Iniciar el state-bucket-init
El módulo habilita versioning, encriptado AES256 y bloqueo público para el bucket.
Ubícate en la carpeta del módulo
cd /mnt/c/Users/Jose/Documents/Final_Project_Epam/infra/state-bucket-init

terraform init
terraform plan  -out=plan.tfplan
terraform apply -auto-approve plan.tfplan
