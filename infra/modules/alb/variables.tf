variable "name_prefix"        { type = string }
variable "vpc_id"             { type = string }
variable "public_subnet_ids"  { type = list(string) }

variable "frontend_health_path" {
    type    = string
    default = "/"
}
variable "backend_health_path"  {
    type = string  
    default = "/api/health" 
}
