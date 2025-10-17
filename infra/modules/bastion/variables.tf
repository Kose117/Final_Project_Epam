# infra/modules/bastion/variables.tf - CORREGIR:
variable "name_prefix"        { type = string }
variable "vpc_id"             { type = string }
variable "public_subnet_id"   { type = string }

# ✅ CAMBIAR ESTE NOMBRE:
variable "app_subnet_cidrs" {  # antes: private_subnet_cidrs
  type        = list(string)
  description = "CIDRs de subnets de aplicación para SSH egress"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "key_name"          { type = string }
variable "allowed_ssh_cidrs" { type = list(string) }