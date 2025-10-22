variable "name_prefix" { type = string }
variable "vpc_id"      { type = string }

variable "subnet_ids" {
  description = "Lista de subnets privadas donde desplegar las instancias backend"
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "Debe proveer al menos una subnet privada para el backend"
  }
}

variable "instance_count" {
  description = "Numero de instancias backend a desplegar"
  type        = number
  default     = 1
  validation {
    condition     = var.instance_count >= 1
    error_message = "instance_count debe ser al menos 1"
  }
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name"      { type = string }
variable "alb_sg_id"     { type = string }
variable "bastion_sg_id" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}
