# ==============================================================================
# NAT GATEWAY MODULE - Managed NAT for private subnets
# ==============================================================================

resource "aws_eip" "this" {
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id     = var.public_subnet_id

  tags = {
    Name = "${var.name_prefix}-nat-gw"
  }
}

resource "aws_route" "private_default" {
  # Usa un mapa con claves estables (indices) para evitar que for_each
  # dependa de valores desconocidos en plan. Los IDs pueden ser unknown
  # en plan, pero las claves (indices) quedan fijas.
  for_each = { for idx, rt_id in var.private_route_table_ids : tostring(idx) => rt_id }

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}
