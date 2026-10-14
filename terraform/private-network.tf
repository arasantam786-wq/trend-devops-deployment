resource "aws_subnet" "private" {
  count = 2

  vpc_id                  = aws_vpc.trend.id
  cidr_block              = cidrsubnet(aws_vpc.trend.cidr_block, 8, count.index + 10)
  availability_zone       = aws_subnet.public[count.index].availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name                              = "trend-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = {
    Name = "trend-nat-ip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "trend" {
  count = 2

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "trend-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.trend]
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.trend.id

  tags = {
    Name = "trend-private-routes-${count.index + 1}"
  }
}

resource "aws_route" "private_internet" {
  count = 2

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.trend[count.index].id
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}
