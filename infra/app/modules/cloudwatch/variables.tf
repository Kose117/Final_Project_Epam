variable "name_prefix"              { type = string }
variable "region"                   { type = string }
variable "public_alb_arn_suffix"    { type = string }
variable "internal_alb_arn_suffix"  { type = string }
variable "frontend_instance"        { type = string }

variable "backend_instances" {
  description = "Lista de instancias backend a monitorear"
  type        = list(string)
  validation {
    condition     = length(var.backend_instances) >= 1
    error_message = "Debe existir al menos una instancia backend para monitorear"
  }
}

variable "rds_instance"    { type = string }
variable "tg_frontend_arn_suffix" { type = string }
variable "tg_backend_arn_suffix"  { type = string }