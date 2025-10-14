variable "name_prefix"       { type = string }
variable "vpc_id"            { type = string }
variable "public_subnet_id"  { type = string }
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "key_name"          { type = string }
variable "allowed_ssh_cidrs" { type = list(string) }