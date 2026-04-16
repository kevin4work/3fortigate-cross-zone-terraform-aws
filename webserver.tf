# Apache Web Server in Customer VPC for testing
# Wait for FortiGate VMs to be fully ready before creating Apache server

# Null resource to wait for FortiGate VMs to initialize
resource "null_resource" "fgtvm_ready" {
  depends_on = [
    aws_instance.fgtvm,
    aws_instance.fgtvm2,
    aws_instance.fgtvm3
  ]

  provisioner "local-exec" {
    command = "sleep 180"  # Wait 3 minutes for FortiGate VMs to fully boot and configure
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_instance" "apache_server" {
  count         = var.deploy_customer_vpc ? 1 : 0
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = var.keyname

  depends_on    = [null_resource.fgtvm_ready]

  subnet_id              = aws_subnet.csprivatesubnetaz1[0].id
  vpc_security_group_ids = [aws_security_group.apache_sg[0].id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Apache Server - Customer VPC</h1><p>Traffic routed through FortiGate GWLB</p><p>Server: $(hostname)</p><p>Date: $(date)</p>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "Apache-WebServer"
  }
}

resource "aws_security_group" "apache_sg" {
  count       = var.deploy_customer_vpc ? 1 : 0
  name        = "apache-sg"
  description = "Security group for Apache server"
  vpc_id      = aws_vpc.customer-vpc[0].id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Apache-SG"
  }
}

resource "aws_eip" "apache_eip" {
  count    = var.deploy_customer_vpc ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.apache_server[0].id

  tags = {
    Name = "Apache-EIP"
  }
}

output "ApacheServerPublicIP" {
  value       = var.deploy_customer_vpc ? aws_eip.apache_eip[0].public_ip : null
  description = "Public IP of Apache server"
}

output "ApacheServerPrivateIP" {
  value       = var.deploy_customer_vpc ? aws_instance.apache_server[0].private_ip : null
  description = "Private IP of Apache server"
}
