# ==============================================================================
# VPC MODULE - Red Virtual Privada
# ==============================================================================
# Crea una VPC con subnets publicas y privadas distribuidas en multiples AZs
# para alta disponibilidad.
# ==============================================================================

# ------------------------------------------------------------------------------
# VPC - Red principal
# ------------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true  // Permite resolucion DNS dentro de la VPC
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
# PUBLIC SUBNETS - Subredes publicas
# ------------------------------------------------------------------------------
# Instancias aqui reciben IPs publicas automaticamente (ALB, Bastion, NAT).
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
# FRONTEND SUBNETS - Capa de presentacion
# ------------------------------------------------------------------------------
# Instancias del frontend residen en estas subnets privadas.
# ------------------------------------------------------------------------------
resource "aws_subnet" "frontend" {
  for_each = { for idx, cidr in var.frontend_subnet_cidrs : idx => cidr }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = var.azs[tonumber(each.key)]
  map_public_ip_on_launch = false

  tags = { Name = "${var.name_prefix}-frontend-${each.key}" }
}

# ------------------------------------------------------------------------------
# BACKEND SUBNETS - Capa de aplicacion
# ------------------------------------------------------------------------------
# Subredes privadas exclusivas para servicios backend y ALB interno.
# ------------------------------------------------------------------------------
resource "aws_subnet" "backend" {
  for_each = { for idx, cidr in var.backend_subnet_cidrs : idx => cidr }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = var.azs[tonumber(each.key)]
  map_public_ip_on_launch = false

  tags = { Name = "${var.name_prefix}-backend-${each.key}" }
}

# ------------------------------------------------------------------------------
# DB SUBNETS - Capa de datos
# ------------------------------------------------------------------------------
# Subredes aisladas utilizadas exclusivamente por RDS.
# ------------------------------------------------------------------------------
resource "aws_subnet" "db" {
  for_each = { for idx, cidr in var.db_subnet_cidrs : idx => cidr }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = var.azs[tonumber(each.key)]
  map_public_ip_on_launch = false

  tags = { Name = "${var.name_prefix}-db-${each.key}" }
}

# ------------------------------------------------------------------------------
# PUBLIC ROUTE TABLE - Tabla de rutas publica
# ------------------------------------------------------------------------------
# Redirige todo el trafico externo (0.0.0.0/0) al Internet Gateway.
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
# FRONTEND ROUTE TABLES - Tablas de rutas para la capa de frontend
# ------------------------------------------------------------------------------
# Una por subnet privada de frontend. La ruta a Internet (0.0.0.0/0)
# la inyecta el modulo de NAT (NAT Gateway) en el root.
# ------------------------------------------------------------------------------
resource "aws_route_table" "frontend" {
  for_each = aws_subnet.frontend
  vpc_id   = aws_vpc.this.id
  tags     = { Name = "${var.name_prefix}-frontend-rt-${each.key}" }
}

resource "aws_route_table_association" "frontend_assoc" {
  for_each       = aws_subnet.frontend
  subnet_id      = each.value.id
  route_table_id = aws_route_table.frontend[each.key].id
}

# ------------------------------------------------------------------------------
# BACKEND ROUTE TABLES - Tablas de rutas para la capa de backend
# ------------------------------------------------------------------------------
# Una por subnet privada de backend. La ruta default se inyecta desde el modulo NAT.
# ------------------------------------------------------------------------------
resource "aws_route_table" "backend" {
  for_each = aws_subnet.backend
  vpc_id   = aws_vpc.this.id
  tags     = { Name = "${var.name_prefix}-backend-rt-${each.key}" }
}

resource "aws_route_table_association" "backend_assoc" {
  for_each       = aws_subnet.backend
  subnet_id      = each.value.id
  route_table_id = aws_route_table.backend[each.key].id
}

# ------------------------------------------------------------------------------
# DB ROUTE TABLES - Tablas de rutas para la capa de datos
# ------------------------------------------------------------------------------
# Sin ruta por defecto a Internet; solo la ruta local.
# ------------------------------------------------------------------------------
resource "aws_route_table" "db" {
  for_each = aws_subnet.db
  vpc_id   = aws_vpc.this.id
  tags     = { Name = "${var.name_prefix}-db-rt-${each.key}" }
}

resource "aws_route_table_association" "db_assoc" {
  for_each       = aws_subnet.db
  subnet_id      = each.value.id
  route_table_id = aws_route_table.db[each.key].id
}
