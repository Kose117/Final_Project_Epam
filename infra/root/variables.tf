# ==============================================================================
# VARIABLES - Root Module
# ==============================================================================
# Define todas las variables que pueden cambiar entre ambientes.
# Los valores reales están en environments/qa.tfvars y environments/prod.tfvars
# ==============================================================================

# ------------------------------------------------------------------------------
# Project & Environment
# ------------------------------------------------------------------------------
variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "movie-analyst"
}

variable "environment" {
  description = "Ambiente (qa, prod, dev)"
  type        = string
  validation {
    condition     = contains(["qa", "prod", "dev"], var.environment)
    error_message = "Environment debe ser: qa, prod, o dev"
  }
}

variable "team" {
  description = "Equipo responsable"
  type        = string
  default     = "devops"
}

variable "cost_center" {
  description = "Centro de costos"
  type        = string
  default     = "migration-project"
}

# ------------------------------------------------------------------------------
# AWS Configuration
# ------------------------------------------------------------------------------
variable "region" {
  description = "Región AWS donde desplegar"
  type        = string
}

variable "azs" {
  description = "Lista de Availability Zones a usar"
  type        = list(string)
  validation {
    condition     = length(var.azs) >= 2
    error_message = "Debe especificar al menos 2 AZs para alta disponibilidad"
  }
}

# ------------------------------------------------------------------------------
# Networking
# ------------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block de la VPC"
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr debe ser un CIDR válido (ej: 10.10.0.0/16)"
  }
}

variable "public_subnet_cidrs" {
  description = "Lista de CIDRs para subnets públicas"
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "Debe especificar al menos 2 subnets públicas"
  }
}

variable "frontend_subnet_cidrs" {
  description = "Lista de CIDRs para la capa de frontend (subnets privadas)"
  type        = list(string)
  validation {
    condition     = length(var.frontend_subnet_cidrs) >= 2
    error_message = "Debe especificar al menos 2 subnets privadas para el frontend"
  }
}

variable "backend_subnet_cidrs" {
  description = "Lista de CIDRs para la capa de backend (subnets privadas)"
  type        = list(string)
  validation {
    condition     = length(var.backend_subnet_cidrs) >= 2
    error_message = "Debe especificar al menos 2 subnets privadas para el backend"
  }
}

variable "db_subnet_cidrs" {
  description = "Lista de CIDRs para la capa de datos (subnets privadas exclusivas de RDS)"
  type        = list(string)
  validation {
    condition     = length(var.db_subnet_cidrs) >= 2
    error_message = "Debe especificar al menos 2 subnets privadas para la capa de datos"
  }
}

# ------------------------------------------------------------------------------
# Compute
# ------------------------------------------------------------------------------
variable "instance_type" {
  description = "Tipo de instancia EC2 (t3.micro para free tier)"
  type        = string
  default     = "t3.micro"
}

variable "backend_instance_count" {
  description = "Número de instancias EC2 para el backend"
  type        = number
  default     = 1
  validation {
    condition     = var.backend_instance_count >= 1
    error_message = "backend_instance_count debe ser al menos 1"
  }
}

variable "ssh_key_name" {
  description = "Nombre del key pair SSH en AWS"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "Lista de CIDRs permitidos para SSH al Bastion (tu IP pública)"
  type        = list(string)
}

# ------------------------------------------------------------------------------
# Database
# ------------------------------------------------------------------------------
variable "db_name" {
  description = "Nombre de la base de datos MySQL"
  type        = string
}

variable "db_username" {
  description = "Usuario master de la base de datos"
  type        = string
}

variable "db_password" {
  description = "Password del usuario master"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "Clase de instancia RDS (db.t3.micro para free tier)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Almacenamiento de la DB en GB (20 GB gratis en free tier)"
  type        = number
  default     = 20
  validation {
    condition     = var.db_allocated_storage >= 20
    error_message = "RDS MySQL requiere mínimo 20 GB"
  }
}