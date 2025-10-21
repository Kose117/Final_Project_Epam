variable "name_prefix"            { type = string }
variable "cidr_block"             { type = string }
variable "azs"                    { type = list(string) }
variable "public_subnet_cidrs"    { type = list(string) }
variable "frontend_subnet_cidrs"  { type = list(string) }
variable "backend_subnet_cidrs"   { type = list(string) }
variable "db_subnet_cidrs"        { type = list(string) }
