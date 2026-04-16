// Creating Internet Gateway
resource "aws_internet_gateway" "fgtvmigw" {
  vpc_id = aws_vpc.fgtvm-vpc.id
  tags = {
    Name = "fgtvm-igw"
  }
}

// Route Table
resource "aws_route_table" "fgtvmpublicrt" {
  vpc_id = aws_vpc.fgtvm-vpc.id

  tags = {
    Name = "fgtvm-public-rt"
  }
}


resource "aws_route_table" "fgtvmprivatert" {
  vpc_id = aws_vpc.fgtvm-vpc.id

  tags = {
    Name = "fgtvm-private-rt"
  }
}

resource "aws_route_table" "fgtvmprivatert2" {
  vpc_id = aws_vpc.fgtvm-vpc.id

  tags = {
    Name = "fgtvm-private-rt2"
  }
}

resource "aws_route_table" "fgtvmprivatert3" {
  vpc_id = aws_vpc.fgtvm-vpc.id

  tags = {
    Name = "fgtvm-private-rt3"
  }
}

resource "aws_route" "externalroute" {
  route_table_id         = aws_route_table.fgtvmpublicrt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.fgtvmigw.id
}

resource "aws_route" "internalroute" {
  depends_on             = [aws_instance.fgtvm]
  route_table_id         = aws_route_table.fgtvmprivatert.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.eth1.id
}

resource "aws_route" "internalroute2" {
  depends_on             = [aws_instance.fgtvm]
  route_table_id         = aws_route_table.fgtvmprivatert2.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.eth1-1.id
}

resource "aws_route" "internalroute3" {
  depends_on             = [aws_instance.fgtvm]
  route_table_id         = aws_route_table.fgtvmprivatert3.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.eth1-2.id
}

resource "aws_route_table_association" "public1associate" {
  subnet_id      = aws_subnet.publicsubnetaz1.id
  route_table_id = aws_route_table.fgtvmpublicrt.id
}

resource "aws_route_table_association" "public2associate" {
  subnet_id      = aws_subnet.publicsubnetaz2.id
  route_table_id = aws_route_table.fgtvmpublicrt.id
}

resource "aws_route_table_association" "public3associate" {
  subnet_id      = aws_subnet.publicsubnetaz3.id
  route_table_id = aws_route_table.fgtvmpublicrt.id
}


resource "aws_route_table_association" "internalassociate" {
  subnet_id      = aws_subnet.privatesubnetaz1.id
  route_table_id = aws_route_table.fgtvmprivatert.id
}

resource "aws_route_table_association" "internal2associate" {
  subnet_id      = aws_subnet.privatesubnetaz2.id
  route_table_id = aws_route_table.fgtvmprivatert2.id
}

resource "aws_route_table_association" "internal3associate" {
  subnet_id      = aws_subnet.privatesubnetaz3.id
  route_table_id = aws_route_table.fgtvmprivatert3.id
}

resource "aws_eip" "FGTPublicIP" {
  depends_on        = [aws_instance.fgtvm]
  domain            = "vpc"
  network_interface = aws_network_interface.eth0.id
}

resource "aws_eip" "FGTPublicIP2" {
  depends_on        = [aws_instance.fgtvm2]
  domain            = "vpc"
  network_interface = aws_network_interface.eth0-1.id
}

resource "aws_eip" "FGTPublicIP3" {
  depends_on        = [aws_instance.fgtvm3]
  domain            = "vpc"
  network_interface = aws_network_interface.eth0-2.id
}



// Security Group

resource "aws_security_group" "public_allow" {
  name        = "Public Allow"
  description = "Public Allow traffic"
  vpc_id      = aws_vpc.fgtvm-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "6"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "6"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "6"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Public Allow"
  }
}

resource "aws_security_group" "allow_all" {
  name        = "Allow All"
  description = "Allow all traffic"
  vpc_id      = aws_vpc.fgtvm-vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Public Allow"
  }
}

//  Gateway Load Balancer on FGT VPC to three FGTs
resource "aws_lb" "gateway_lb" {
  name                             = "gatewaylb${random_string.random_name_post.result}"
  load_balancer_type               = "gateway"
  enable_cross_zone_load_balancing = "true"

  subnet_mapping {
    subnet_id = aws_subnet.privatesubnetaz1.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.privatesubnetaz2.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.privatesubnetaz3.id
  }

  tags = {
    Environment = "terraform sample"
  }
}


resource "aws_lb_target_group" "fgt_target" {
  name        = "fgttarget${random_string.random_name_post.result}"
  port        = 6081
  protocol    = "GENEVE"
  target_type = "ip"
  vpc_id      = aws_vpc.fgtvm-vpc.id

  health_check {
    port                = 8008
    protocol            = "TCP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 5
  }
}

resource "aws_lb_listener" "fgt_listener" {
  load_balancer_arn = aws_lb.gateway_lb.id

  default_action {
    target_group_arn = aws_lb_target_group.fgt_target.id
    type             = "forward"
  }
}

resource "aws_lb_target_group_attachment" "fgtattach" {
  depends_on       = [aws_instance.fgtvm]
  target_group_arn = aws_lb_target_group.fgt_target.arn
  target_id        = data.aws_network_interface.eth1.private_ip
  port             = 6081
}
resource "aws_lb_target_group_attachment" "fgtattach2" {
  depends_on       = [aws_instance.fgtvm2]
  target_group_arn = aws_lb_target_group.fgt_target.arn
  target_id        = data.aws_network_interface.eth1-1.private_ip
  port             = 6081
}

resource "aws_lb_target_group_attachment" "fgtattach3" {
  depends_on       = [aws_instance.fgtvm3]
  target_group_arn = aws_lb_target_group.fgt_target.arn
  target_id        = data.aws_network_interface.eth1-2.private_ip
  port             = 6081
}



resource "aws_vpc_endpoint_service" "fgtgwlbservice" {
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.gateway_lb.arn]
}
