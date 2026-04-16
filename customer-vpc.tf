// AWS VPC - Customer
resource "aws_vpc" "customer-vpc" {
  count                = var.deploy_customer_vpc ? 1 : 0
  cidr_block           = var.csvpccidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags = {
    Name = "terraform customer demo"
  }
}

resource "aws_subnet" "cspublicsubnetaz1" {
  count             = var.deploy_customer_vpc ? 1 : 0
  vpc_id            = aws_vpc.customer-vpc[0].id
  cidr_block        = var.cspubliccidraz1
  availability_zone = var.az1
  tags = {
    Name = "cs public subnet az1"
  }
}

resource "aws_subnet" "csprivatesubnetaz1" {
  count             = var.deploy_customer_vpc ? 1 : 0
  vpc_id            = aws_vpc.customer-vpc[0].id
  cidr_block        = var.csprivatecidraz1
  availability_zone = var.az1
  tags = {
    Name = "cs private subnet az1"
  }
}

resource "aws_subnet" "cspublicsubnetaz2" {
  count             = var.deploy_customer_vpc ? 1 : 0
  vpc_id            = aws_vpc.customer-vpc[0].id
  cidr_block        = var.cspubliccidraz2
  availability_zone = var.az2
  tags = {
    Name = "cs public subnet az2"
  }
}

resource "aws_subnet" "csprivatesubnetaz2" {
  count             = var.deploy_customer_vpc ? 1 : 0
  vpc_id            = aws_vpc.customer-vpc[0].id
  cidr_block        = var.csprivatecidraz2
  availability_zone = var.az2
  tags = {
    Name = "cs private subnet az2"
  }
}

resource "aws_subnet" "cspublicsubnetaz3" {
  count             = var.deploy_customer_vpc ? 1 : 0
  vpc_id            = aws_vpc.customer-vpc[0].id
  cidr_block        = var.cspubliccidraz3
  availability_zone = var.az3
  tags = {
    Name = "cs public subnet az3"
  }
}

resource "aws_subnet" "csprivatesubnetaz3" {
  count             = var.deploy_customer_vpc ? 1 : 0
  vpc_id            = aws_vpc.customer-vpc[0].id
  cidr_block        = var.csprivatecidraz3
  availability_zone = var.az3
  tags = {
    Name = "cs private subnet az3"
  }
}

// Creating Internet Gateway for Customer VPC
resource "aws_internet_gateway" "csigw" {
  count  = var.deploy_customer_vpc ? 1 : 0
  vpc_id = aws_vpc.customer-vpc[0].id
  tags = {
    Name = "cs-igw"
  }
}

// Route Table for Customer VPC
resource "aws_route_table" "cspublicrt" {
  count  = var.deploy_customer_vpc ? 1 : 0
  vpc_id = aws_vpc.customer-vpc[0].id

  tags = {
    Name = "cs-public-edge-rt"
  }
}

resource "aws_route_table" "cspublicrt2" {
  count  = var.deploy_customer_vpc ? 1 : 0
  vpc_id = aws_vpc.customer-vpc[0].id

  tags = {
    Name = "cs-public-egress-rt"
  }
}

resource "aws_route_table" "csprivatert" {
  count    = var.deploy_customer_vpc ? 1 : 0
  depends_on = [aws_vpc_endpoint.gwlbendpoint]
  vpc_id   = aws_vpc.customer-vpc[0].id

  tags = {
    Name = "cs-private-rt"
  }
}

resource "aws_route_table" "csprivatert2" {
  count    = var.deploy_customer_vpc ? 1 : 0
  depends_on = [aws_vpc_endpoint.gwlbendpoint2]
  vpc_id   = aws_vpc.customer-vpc[0].id

  tags = {
    Name = "cs-private-rt2"
  }
}

resource "aws_route_table" "csprivatert3" {
  count    = var.deploy_customer_vpc ? 1 : 0
  depends_on = [aws_vpc_endpoint.gwlbendpoint3]
  vpc_id   = aws_vpc.customer-vpc[0].id

  tags = {
    Name = "cs-private-rt3"
  }
}

resource "aws_route" "cspublicrouteaz1" {
  count      = var.deploy_customer_vpc ? 1 : 0
  depends_on = [aws_route_table.cspublicrt]
  route_table_id         = aws_route_table.cspublicrt[0].id
  destination_cidr_block = var.csprivatecidraz1
  vpc_endpoint_id        = aws_vpc_endpoint.gwlbendpoint[0].id
}

resource "aws_route" "cspublicrouteaz2" {
  count      = var.deploy_customer_vpc ? 1 : 0
  depends_on = [aws_route_table.cspublicrt]
  route_table_id         = aws_route_table.cspublicrt[0].id
  destination_cidr_block = var.csprivatecidraz2
  vpc_endpoint_id        = aws_vpc_endpoint.gwlbendpoint2[0].id
}

resource "aws_route" "csinternalroute" {
  count      = var.deploy_customer_vpc ? 1 : 0
  depends_on = [aws_route_table.csprivatert]
  route_table_id         = aws_route_table.csprivatert[0].id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = aws_vpc_endpoint.gwlbendpoint[0].id
}

resource "aws_route" "csinternalroute2" {
  count      = var.deploy_customer_vpc ? 1 : 0
  depends_on = [aws_route_table.csprivatert2]
  route_table_id         = aws_route_table.csprivatert2[0].id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = aws_vpc_endpoint.gwlbendpoint2[0].id
}

resource "aws_route" "csinternalroute3" {
  count      = var.deploy_customer_vpc ? 1 : 0
  depends_on = [aws_route_table.csprivatert3]
  route_table_id         = aws_route_table.csprivatert3[0].id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = aws_vpc_endpoint.gwlbendpoint3[0].id
}

resource "aws_route" "csexternalroute" {
  count      = var.deploy_customer_vpc ? 1 : 0
  depends_on = [aws_route_table.cspublicrt2]
  route_table_id         = aws_route_table.cspublicrt2[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.csigw[0].id
}

resource "aws_route_table_association" "cspublicassociate" {
  count        = var.deploy_customer_vpc ? 1 : 0
  route_table_id = aws_route_table.cspublicrt[0].id
  gateway_id     = aws_internet_gateway.csigw[0].id
}

resource "aws_route_table_association" "csinternalassociateaz1" {
  count        = var.deploy_customer_vpc ? 1 : 0
  subnet_id      = aws_subnet.csprivatesubnetaz1[0].id
  route_table_id = aws_route_table.csprivatert[0].id
}

resource "aws_route_table_association" "csinternalassociateaz2" {
  count        = var.deploy_customer_vpc ? 1 : 0
  subnet_id      = aws_subnet.csprivatesubnetaz2[0].id
  route_table_id = aws_route_table.csprivatert2[0].id
}

resource "aws_route_table_association" "csinternalassociateaz3" {
  count        = var.deploy_customer_vpc ? 1 : 0
  subnet_id      = aws_subnet.csprivatesubnetaz3[0].id
  route_table_id = aws_route_table.csprivatert3[0].id
}

resource "aws_route_table_association" "csexternalassociateaz1" {
  count        = var.deploy_customer_vpc ? 1 : 0
  subnet_id      = aws_subnet.cspublicsubnetaz1[0].id
  route_table_id = aws_route_table.cspublicrt2[0].id
}

resource "aws_route_table_association" "csexternalassociateaz2" {
  count        = var.deploy_customer_vpc ? 1 : 0
  subnet_id      = aws_subnet.cspublicsubnetaz2[0].id
  route_table_id = aws_route_table.cspublicrt2[0].id
}

// VPC Endpoints for GWLB in Customer VPC
resource "aws_vpc_endpoint" "gwlbendpoint" {
  count             = var.deploy_customer_vpc ? 1 : 0
  service_name      = aws_vpc_endpoint_service.fgtgwlbservice.service_name
  subnet_ids        = [aws_subnet.cspublicsubnetaz1[0].id]
  vpc_endpoint_type = aws_vpc_endpoint_service.fgtgwlbservice.service_type
  vpc_id            = aws_vpc.customer-vpc[0].id
}

resource "aws_vpc_endpoint" "gwlbendpoint2" {
  count             = var.deploy_customer_vpc ? 1 : 0
  service_name      = aws_vpc_endpoint_service.fgtgwlbservice.service_name
  subnet_ids        = [aws_subnet.cspublicsubnetaz2[0].id]
  vpc_endpoint_type = aws_vpc_endpoint_service.fgtgwlbservice.service_type
  vpc_id            = aws_vpc.customer-vpc[0].id
}

resource "aws_vpc_endpoint" "gwlbendpoint3" {
  count             = var.deploy_customer_vpc ? 1 : 0
  service_name      = aws_vpc_endpoint_service.fgtgwlbservice.service_name
  subnet_ids        = [aws_subnet.cspublicsubnetaz3[0].id]
  vpc_endpoint_type = aws_vpc_endpoint_service.fgtgwlbservice.service_type
  vpc_id            = aws_vpc.customer-vpc[0].id
}
