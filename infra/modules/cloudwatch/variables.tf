variable "name_prefix"         { type = string }
variable "region"              { type = string }
variable "alb_arn_suffix"      { type = string }
variable "frontend_instance"   { type = string }
variable "backend_instance"    { type = string }
variable "rds_instance"        { type = string }
variable "tg_frontend_arn"     { type = string }
variable "tg_backend_arn"      { type = string }