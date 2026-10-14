terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "trend"
      ManagedBy = "Terraform"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "trend" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "trend-vpc"
  }
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.trend.id
  cidr_block              = cidrsubnet(aws_vpc.trend.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "trend-public-${count.index + 1}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_internet_gateway" "trend" {
  vpc_id = aws_vpc.trend.id

  tags = {
    Name = "trend-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.trend.id

  tags = {
    Name = "trend-public-routes"
  }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.trend.id
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

output "vpc_id" {
  value = aws_vpc.trend.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
