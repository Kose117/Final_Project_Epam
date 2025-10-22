variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_id" {
  description = "Public subnet where the NAT Gateway will live"
  type        = string
}

variable "private_route_table_ids" {
  description = "List of private route table IDs that must send 0.0.0.0/0 to the NAT Gateway"
  type        = list(string)
}

