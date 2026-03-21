variable "vpc_id" {
  type = string
}

variable "igw_id" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_cidrs" {
  type = list(string)
}

variable "app_private_cidrs" {
  type = list(string)
}

variable "db_private_cidrs" {
  type = list(string)
}

variable "name_prefix" {
  type = string
}

variable "env" {
  type = string
}

resource "aws_subnet" "public" {
  for_each = { for idx, cidr in var.public_cidrs : idx => cidr }

  vpc_id                  = var.vpc_id
  cidr_block              = each.value
  availability_zone       = var.azs[tonumber(each.key)]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.name_prefix}-public-${each.key}"
    Environment = var.env
    Tier        = "public"
  }
}

resource "aws_subnet" "app" {
  for_each = { for idx, cidr in var.app_private_cidrs : idx => cidr }

  vpc_id            = var.vpc_id
  cidr_block        = each.value
  availability_zone = var.azs[tonumber(each.key)]

  tags = {
    Name        = "${var.name_prefix}-app-${each.key}"
    Environment = var.env
    Tier        = "app"
  }
}

resource "aws_subnet" "db" {
  for_each = { for idx, cidr in var.db_private_cidrs : idx => cidr }

  vpc_id            = var.vpc_id
  cidr_block        = each.value
  availability_zone = var.azs[tonumber(each.key)]

  tags = {
    Name        = "${var.name_prefix}-db-${each.key}"
    Environment = var.env
    Tier        = "db"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.name_prefix}-nat-eip"
    Environment = var.env
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["0"].id  # Fix: NAT Gateway must be in public subnet

  tags = {
    Name        = "${var.name_prefix}-nat-gw"
    Environment = var.env
  }
}

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw_id
  }

  tags = {
    Name        = "${var.name_prefix}-public-rt"
    Environment = var.env
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "app" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name        = "${var.name_prefix}-app-rt"
    Environment = var.env
  }
}

resource "aws_route_table_association" "app" {
  for_each = aws_subnet.app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.app.id
}

resource "aws_route_table" "db" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id  # Fix: Add NAT route for DB subnet
  }

  tags = {
    Name        = "${var.name_prefix}-db-rt"
    Environment = var.env
  }
}

resource "aws_route_table_association" "db" {
  for_each = aws_subnet.db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.db.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "app_subnet_ids" {
  value = [for s in aws_subnet.app : s.id]
}

output "db_subnet_ids" {
  value = [for s in aws_subnet.db : s.id]
}

