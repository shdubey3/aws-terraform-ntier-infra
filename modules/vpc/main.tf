variable "vpc_cidr" {
  type        = string
  description = "CIDR for VPC"
}

variable "azs" {
  type        = list(string)
  description = "Availability zones to use"
}

variable "name" {
  type        = string
  description = "VPC name"
}

variable "env" {
  type        = string
  description = "Environment for tagging"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = var.name
    Environment = var.env
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name        = "${var.name}-igw"
    Environment = var.env
  }
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "igw_id" {
  value = aws_internet_gateway.this.id
}

