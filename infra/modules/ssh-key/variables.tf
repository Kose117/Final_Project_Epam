variable "key_name" {
  description = "Nombre del key pair en AWS EC2"
  type        = string
}

variable "private_key_path" {
  description = "Ruta absoluta donde guardar la llave privada generada"
  type        = string
  default     = null
}

variable "tags" {
  description = "Etiquetas a aplicar al key pair"
  type        = map(string)
  default     = {}
}

variable "create" {
  description = "Si es true, Terraform genera el par de llaves. Si es false, solo expone el nombre para un key pair existente"
  type        = bool
  default     = true
}
