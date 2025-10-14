variable "region"               { type = string }
variable "azs"                  { type = list(string) }
variable "vpc_cidr"             { type = string }
variable "public_subnet_cidrs"  { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }

variable "instance_type"        { type = string }     # ej: t3.micro
variable "ssh_key_name"         { type = string }     # TODO
variable "allowed_ssh_cidrs"    { type = list(string) }  # limita tu IP

variable "db_name"              { type = string }
variable "db_username"          { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "db_instance_class"    { type = string }    # db.t3.micro
variable "db_allocated_storage" { type = number }    # 20
