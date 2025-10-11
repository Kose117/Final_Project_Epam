variable "name_prefix"   { type = string }
variable "vpc_id"        { type = string }
variable "subnet_id"     { type = string }
variable "instance_type" { type = string  default = "t3.micro" }
variable "key_name"      { type = string }   # TODO
variable "alb_sg_id"     { type = string }   # para permitir solo ALB->EC2
