// ============================================
// Syslog Proxy Infrastructure
// ============================================

// Rendered user_data for verification (same template used by the EC2 instance)
locals {
  syslog_proxy_user_data = var.deploy_syslog_proxy ? templatefile("${path.module}/syslog-proxy-userdata.sh.tpl", {
    s3_bucket_name       = var.syslog_s3_bucket_name
    s3_bucket_region     = var.syslog_s3_bucket_region
    target_account_id    = var.syslog_target_account_id
    cross_account_role   = var.syslog_cross_account_role_name
    cron_schedule        = var.syslog_upload_cron_schedule
  }) : ""
}

// AMI for Amazon Linux 2023 (x86_64)
data "aws_ami" "amazon_linux_x86" {
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

// Dedicated public subnet for syslog proxy (routed to IGW for outbound internet access)
// No inbound internet access — security group only allows FortiGate syslog and SSH from VPC
resource "aws_subnet" "syslog_subnet" {
  count             = var.deploy_syslog_proxy ? 1 : 0
  vpc_id            = aws_vpc.fgtvm-vpc.id
  cidr_block        = var.syslog_subnet_cidr
  availability_zone = var.az1

  tags = {
    Name = "syslog-proxy-subnet"
  }
}

// Use existing public route table (already has 0.0.0.0/0 → IGW)
resource "aws_route_table_association" "syslog_rt_assoc" {
  count          = var.deploy_syslog_proxy ? 1 : 0
  subnet_id      = aws_subnet.syslog_subnet[0].id
  route_table_id = aws_route_table.fgtvmpublicrt.id
}

// IAM role for syslog proxy
resource "aws_iam_role" "syslog_proxy_role" {
  count = var.deploy_syslog_proxy ? 1 : 0
  name  = "syslog-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "syslog-proxy-role"
  }
}

// IAM policy: allow assuming cross-account role for S3 access
resource "aws_iam_role_policy" "syslog_proxy_assume_role" {
  count = var.deploy_syslog_proxy ? 1 : 0
  name  = "syslog-proxy-assume-role"
  role  = aws_iam_role.syslog_proxy_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = "arn:aws:iam::${var.syslog_target_account_id}:role/${var.syslog_cross_account_role_name}"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "syslog_proxy_profile" {
  count = var.deploy_syslog_proxy ? 1 : 0
  name  = "syslog-proxy-profile"
  role  = aws_iam_role.syslog_proxy_role[0].name
}

// Security group for syslog proxy
resource "aws_security_group" "syslog_proxy_sg" {
  count       = var.deploy_syslog_proxy ? 1 : 0
  name        = "syslog-proxy-sg"
  description = "Security group for syslog proxy"
  vpc_id      = aws_vpc.fgtvm-vpc.id

  // Syslog UDP from FortiGate private subnets
  ingress {
    from_port   = 514
    to_port     = 514
    protocol    = "udp"
    cidr_blocks = [
      var.privatecidraz1,
      var.privatecidraz2,
      var.privatecidraz3,
    ]
    description = "Syslog UDP from FortiGate VMs"
  }

  // Syslog TCP from FortiGate private subnets
  ingress {
    from_port   = 514
    to_port     = 514
    protocol    = "tcp"
    cidr_blocks = [
      var.privatecidraz1,
      var.privatecidraz2,
      var.privatecidraz3,
    ]
    description = "Syslog TCP from FortiGate VMs"
  }

  // SSH from Security VPC only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpccidr]
    description = "SSH from Security VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "syslog-proxy-sg"
  }
}

// Syslog proxy EC2 instance
resource "aws_instance" "syslog_proxy" {
  count                  = var.deploy_syslog_proxy ? 1 : 0
  ami                    = data.aws_ami.amazon_linux_x86.id
  instance_type          = var.syslog_instance_type
  key_name               = var.keyname
  subnet_id              = aws_subnet.syslog_subnet[0].id
  vpc_security_group_ids = [aws_security_group.syslog_proxy_sg[0].id]
  iam_instance_profile   = aws_iam_instance_profile.syslog_proxy_profile[0].name

  associate_public_ip_address = true

  user_data = local.syslog_proxy_user_data

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
  }

  tags = {
    Name = "SyslogProxy"
  }
}
