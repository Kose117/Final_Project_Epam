variable "name_prefix" { type = string }
variable "vpc_id"      { type = string }

variable "subnet_ids" {
  description = "Subnets privadas donde residirá el ALB interno"
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "El ALB interno requiere al menos 2 subnets privadas"
  }
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs adicionales autorizados a consumir el ALB interno"
  type        = list(string)
  default     = []
}

variable "allowed_client_sg_ids" {
  description = "Security groups que pueden invocar el ALB interno"
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.allowed_client_sg_ids) + length(var.allowed_ingress_cidrs) > 0
    error_message = "Debes especificar al menos un security group o CIDR permitido para el ALB interno"
  }
}

variable "backend_health_path" {
  description = "Ruta de health check para las instancias backend"
  type        = string
  default     = "/api/health"
}

