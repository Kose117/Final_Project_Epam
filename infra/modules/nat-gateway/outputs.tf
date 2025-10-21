output "nat_gateway_id" {
  value       = aws_nat_gateway.this.id
  description = "ID of the created NAT Gateway"
}

output "eip_allocation_id" {
  value       = aws_eip.this.id
  description = "Allocation ID of the Elastic IP associated to the NAT Gateway"
}

