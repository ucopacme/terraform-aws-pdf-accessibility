# ═══════════════════════════════════════════════════════════════════════════
# VPC with Public and Private Subnets
# ═══════════════════════════════════════════════════════════════════════════

resource "aws_vpc" "pdf_processing" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "pdf-accessibility-${var.environment}-vpc"
  }
}

# ─── Internet Gateway ──────────────────────────────────────────────────────

resource "aws_internet_gateway" "pdf_processing" {
  vpc_id = aws_vpc.pdf_processing.id

  tags = {
    Name = "pdf-accessibility-${var.environment}-igw"
  }
}

# ─── Public Subnets ────────────────────────────────────────────────────────

resource "aws_subnet" "public" {
  count                   = var.max_azs
  vpc_id                  = aws_vpc.pdf_processing.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "pdf-accessibility-${var.environment}-public-${local.azs[count.index]}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.pdf_processing.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.pdf_processing.id
  }

  tags = {
    Name = "pdf-accessibility-${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.max_azs
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ─── NAT Gateway ──────────────────────────────────────────────────────────

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "pdf-accessibility-${var.environment}-nat-eip"
  }
}

resource "aws_nat_gateway" "pdf_processing" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "pdf-accessibility-${var.environment}-nat-gw"
  }

  depends_on = [aws_internet_gateway.pdf_processing]
}

# ─── Private Subnets ──────────────────────────────────────────────────────

resource "aws_subnet" "private" {
  count             = var.max_azs
  vpc_id            = aws_vpc.pdf_processing.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + var.max_azs)
  availability_zone = local.azs[count.index]

  tags = {
    Name = "pdf-accessibility-${var.environment}-private-${local.azs[count.index]}"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.pdf_processing.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.pdf_processing.id
  }

  tags = {
    Name = "pdf-accessibility-${var.environment}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = var.max_azs
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ─── VPC Endpoints (faster ECR pulls, reduces cold start) ─────────────────

resource "aws_security_group" "vpc_endpoints" {
  name        = "pdf-accessibility-${var.environment}-vpce-sg"
  description = "Security group for VPC endpoints - allows HTTPS from VPC CIDR"
  vpc_id      = aws_vpc.pdf_processing.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pdf-accessibility-${var.environment}-vpce-sg"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.pdf_processing.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "pdf-accessibility-${var.environment}-ecr-api-vpce"
  }
}

resource "aws_vpc_endpoint" "ecr_docker" {
  vpc_id              = aws_vpc.pdf_processing.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "pdf-accessibility-${var.environment}-ecr-docker-vpce"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.pdf_processing.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "pdf-accessibility-${var.environment}-s3-vpce"
  }
}
