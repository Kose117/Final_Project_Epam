variable "name_prefix"      { type = string }
variable "vpc_id"           { type = string }
variable "public_subnet_id" { type = string }
variable "app_subnet_cidrs" { type = list(string) }

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name"          { type = string }
variable "allowed_ssh_cidrs" { type = list(string) }

# Nueva variable para auto-configuración
variable "enable_ansible_setup" {
  type        = bool
  default     = true
  description = "Si es true, instala Ansible automáticamente"
}

variable "ssh_private_key_content" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Contenido de la clave SSH privada (opcional para auto-config)"
}