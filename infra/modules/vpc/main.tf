# ==============================================================================
# VPC MODULE - Red Virtual Privada
# ==============================================================================
# Crea una VPC con subnets públicas y privadas distribuidas en múltiples AZs
# para alta disponibilidad.
# ==============================================================================

# ------------------------------------------------------------------------------
# VPC - Red principal
# ------------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true  // Permite resolución DNS dentro de la VPC
  enable_dns_hostnames = true  // Asigna nombres DNS a las instancias
  tags = { Name = "${var.name_prefix}-vpc" }
}

# ------------------------------------------------------------------------------
# INTERNET GATEWAY - Conectividad a Internet
# ------------------------------------------------------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-igw" }
}

# ------------------------------------------------------------------------------
# PUBLIC SUBNETS - Subredes públicas
# ------------------------------------------------------------------------------
# Instancias aquí reciben IPs públicas automáticamente (ALB, Bastion, NAT).
# ------------------------------------------------------------------------------
resource "aws_subnet" "public" {
  for_each = { for idx, cidr in var.public_subnet_cidrs : idx => cidr }
  
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value //Cuantas IPs contiene la subred
  availability_zone       = var.azs[tonumber(each.key)]  // Distribuye entre AZs
  map_public_ip_on_launch = true
  
  tags = { Name = "${var.name_prefix}-public-${each.key}" }
}

# ------------------------------------------------------------------------------
# PRIVATE SUBNETS - Subredes privadas
# ------------------------------------------------------------------------------
# Instancias aquí NO tienen acceso directo a Internet (Frontend, Backend, RDS).
# ------------------------------------------------------------------------------
resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnet_cidrs : idx => cidr }
  
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = var.azs[tonumber(each.key)]
  map_public_ip_on_launch = false
  
  tags = { Name = "${var.name_prefix}-private-${each.key}" }
}

# ------------------------------------------------------------------------------
# PUBLIC ROUTE TABLE - Tabla de rutas pública
# ------------------------------------------------------------------------------
# Redirige todo el tráfico externo (0.0.0.0/0) al Internet Gateway.
# ------------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-public-rt" }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id // salida por el Internet Gateway
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# PRIVATE ROUTE TABLES - Tablas de rutas privadas
# ------------------------------------------------------------------------------
# Una por subnet privada. La ruta a Internet (0.0.0.0/0 -> NAT instance)
# se agrega desde el módulo nat-instance.
# ------------------------------------------------------------------------------
resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.this.id
  tags     = { Name = "${var.name_prefix}-private-rt-${each.key}" }
}

resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}