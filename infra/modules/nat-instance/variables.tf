# infra/modules/nat-instance/variables.tf - CORREGIR:
variable "name_prefix"            { type = string }
variable "vpc_id"                 { type = string }
variable "public_subnet_id"       { type = string }

# ✅ CAMBIAR ESTOS NOMBRES:
variable "app_route_table_ids" {  # antes: private_route_table_ids
  type        = list(string)
  description = "Route tables de las capas de aplicación (frontend + backend)"
}

variable "app_subnet_cidrs" {     # antes: private_subnet_cidrs
  type        = list(string)
  description = "CIDRs de subnets de aplicación (frontend + backend)"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "key_name"          { type = string }
variable "allowed_ssh_cidrs" { type = list(string) }