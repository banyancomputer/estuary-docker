# PROTOTYPE TERRAFORM DEPLOYMENT
# TODO: Parameterize this and Stick into Modules

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  required_version = "~> 1.3.0"
}
# Provider Configuration
provider "aws" {
  region = var.aws_region
}
# Get the Available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

/* ECR Repository */
resource "aws_ecr_repository" "ecr" {
  name                 = join("-", [var.project, "ecr"])
  image_tag_mutability = "MUTABLE"

  tags = {
    project = var.project
    Name    = join("-", [var.project, "ecr"])
  }
}

/* VPC */
resource "aws_vpc" "vpc" {
  # Set the CIDR block (the address space) for the VPC
  cidr_block           = var.vpc_cidr_block
  # Allow DNS hostnames to be created in the VPC (i.e. allow instances to have hostnames)
  enable_dns_hostnames = true
  tags                 = {
    project = var.project
    Name    = join("-", [var.project, "vpc"])
  }
}

/* Internet Gateway */
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags   = {
    project = var.project
    Name    = join("-", [var.project, "igw"])
  }
}

/* Subnets: */
# Public Subnet(s)
resource "aws_subnet" "public_subnet" {
  count             = var.subnet_count.public
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = {
    project = var.project
    Name    = join("-", [var.project, "public-subnet", count.index])
  }
}
# Private Subnet(s)
resource "aws_subnet" "private_subnet" {
  count             = var.subnet_count.private
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = {
    project = var.project
    Name    = join("-", [var.project, "private-subnet", count.index])
  }
}

/* Routing Table */
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id
  # Declare a route for the Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    project = var.project
    Name    = join("-", [var.project, "rt"])
  }
}
# Public Subnet Association
resource "aws_route_table_association" "public" {
  count          = var.subnet_count.public
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.rt.id
}
# Private Subnet Association
resource "aws_route_table_association" "private" {
  count          = var.subnet_count.private
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.rt.id
}

/* Security Groups */
# Ec2 Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow inbound traffic from the Internet to our Estuary EC2 instance(s)"
  vpc_id      = aws_vpc.vpc.id

  # Estuary API
  ingress {
    description = "Allow inbound traffic from the Internet to our Estuary EC2 instance(s)"
    from_port   = 3004
    to_port     = 3004 # TODO (amiller68) : Is this right?
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # RDS
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [
      aws_security_group.rds_sg.id
    ]
  }
  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    description = "Telnet"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    description = "HTTPS"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    project = var.project
    Name    =  join("-", [var.project, "ec2-sg"])
  }
}
# RDS Security Group
resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Security Group for our RDS instance"
  vpc_id      = aws_vpc.vpc.id

  # Allow inbound traffic from the EC2 instance
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    description     = "PostgreSQL"
    cidr_blocks = [
      aws_vpc.vpc.cidr_block
    ]
  }

  # Allow all outbound traffic.
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
  }

  tags = {
    project = var.project
    Name    = join("-", [var.project, "rds-sg"])
  }
}
# Declare a Subnet group for our RDS instance
resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = join("-", [var.project, "rds-subnet-group"])
  description = "Subnet group for our RDS instance"
  subnet_ids  = aws_subnet.private_subnet[*].id # Neato!
  tags         = {
    project = var.project
    Name    = join("-", [var.project, "rds-subnet-group"])
  }
}

/* Now to our Stack ! */

/* RDS Instances */
resource "aws_db_instance" "rds" {
  identifier             = join("-", [var.project, "rds"])
  allocated_storage      = tonumber(var.settings.rds.allocated_storage)
  engine                 = var.settings.rds.engine
  engine_version         = var.settings.rds.engine_version
  instance_class         = var.settings.rds.instance_class
  db_name                = var.settings.rds.db_name
  username               = var.rds_username
  password               = var.rds_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.id # Should this be id or name?
  vpc_security_group_ids = [
    aws_security_group.rds_sg.id
  ]
  skip_final_snapshot = tobool(var.settings.rds.skip_final_snapshot)
  tags                = {
    project = var.project
    Name    = join("-", [var.project, "rds"])
  }
}

/* EC2 Instances */
# TLS Key pair
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "ec2_key" {
  key_name   = join("-", [var.project, "ec2-key"])
  public_key = tls_private_key.ec2_key.public_key_openssh
}
# IAM Role
resource "aws_iam_role" "ec2_role" {
  name               = join("-", [var.project, "ec2-role"])
  # TODO (amiller68) - Is this the right policy?
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Sid = ""
      }
    ]
  })
  tags               = {
    project = var.project
    Name    = join("-", [var.project, "ec2-role"])
  }
}
resource "aws_iam_instance_profile" "ec2_profile" {
  name = join("-", [var.project, "ec2-profile"])
  role = aws_iam_role.ec2_role.name
  tags = {
    project = var.project
    Name    = join("-", [var.project, "ec2-profile"])
  }
}
resource "aws_iam_role_policy" "ec2_policy" {
  name   = join("-", [var.project, "ec2-policy"])
  role = aws_iam_role.ec2_role.id
  # TODO (amiller68): Narrow down this policy to just the ECR image we need
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "ecr:GetAuthorizationToken",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ],
        Resource : "*"
      }
    ]
  })
}
# AMI
data "aws_ami" "ec2-ami" {
  # TODO (amiller68): Figure out which ami to use. I followed this guide: https://klotzandrew.com/blog/deploy-an-ec2-to-run-docker-with-terraform for this part
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
# (Finally) The EC2 Instance
resource "aws_instance" "ec2" {
  # Configure the instance
  count         = tonumber(var.settings.ec2.count)
  instance_type = var.settings.ec2.instance_type
  root_block_device {
    volume_size = tonumber(var.settings.ec2.rbs_volume_size)
    volume_type = var.settings.ec2.rbs_volume_type
  }
  monitoring = tobool(var.settings.ec2.monitoring)
  # Link our Dependencies
  ami                    = data.aws_ami.ec2-ami.id
  key_name               = aws_key_pair.ec2_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id              = aws_subnet.public_subnet[count.index].id
  # Install Docker
  user_data              = <<-EOF
    #!/bin/bash
    set -ex
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    sudo service docker start
    sudo usermod -a -G docker ec2-user
    sudo curl -L https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  EOF
  tags = {
    project = var.project
    Name    = join("-", [var.project, "ec2", count.index])
  }
}
# Elastic IP
resource "aws_eip" "ec2_eip" {
  count    = tonumber(var.settings.ec2.count)
  instance = aws_instance.ec2[count.index].id
  vpc      = true
  tags     = {
    Name = join("-", [var.project, "ec2-eip", count.index])
  }
}