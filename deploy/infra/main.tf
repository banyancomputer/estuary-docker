# PROTOTYPE TERRAFORM DEPLOYMENT

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
# Who's launching all this Infra
data "aws_caller_identity" "current" {}
# Get the Available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

/* VPC */
resource "aws_vpc" "vpc" {
  # Set the CIDR block (the address space) for the VPC
  cidr_block           = var.vpc_cidr_block
  # Allow DNS hostnames to be created in the VPC (i.e. allow instances to have hostnames)
  enable_dns_hostnames = true
  tags                 = {
    project = var.app.name
    Name    = join("-", [var.app.name, "vpc"])
  }
}

/* Internet Gateway */
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags   = {
    project = var.app.name
    Name    = join("-", [var.app.name, "igw"])
  }
}

/* Subnets: */
# Public Subnet(s)
resource "aws_subnet" "public" {
  count             = var.subnet_count.public
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = {
    project = var.app.name
    Name    = join("-", [var.app.name, "public-subnet", count.index])
  }
}
# Private Subnet(s)
resource "aws_subnet" "private" {
  count             = var.subnet_count.private
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = {
    project = var.app.name
    Name    = join("-", [var.app.name, "private-subnet", count.index])
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
    project = var.app.name
    Name    = join("-", [var.app.name, "rt"])
  }
}
# Public Subnet Association
resource "aws_route_table_association" "public" {
  count          = var.subnet_count.public
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.rt.id
}
# Private Subnet Association
resource "aws_route_table_association" "private" {
  count          = var.subnet_count.private
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.rt.id
}

/* Security Groups */
# Ec2 Security Group
resource "aws_security_group" "ec2" {
  name        = "ec2_sg"
  description = "Allow inbound traffic from the Internet to our Estuary EC2 instance(s)"
  vpc_id      = aws_vpc.vpc.id

  # RDS
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [
      aws_security_group.rds.id
    ]
  }
  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    description = "ssh"
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
    project = var.app.name
    Name    = join("-", [var.app.name, "ec2-sg"])
  }
}
# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "rds_sg"
  description = "Security Group for our RDS instance"
  vpc_id      = aws_vpc.vpc.id

  # Allow inbound traffic from the EC2 instance
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    description = "PostgreSQL"
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
    project = var.app.name
    Name    = join("-", [var.app.name, "rds-sg"])
  }
}
# Declare a Subnet group for our RDS instance
resource "aws_db_subnet_group" "rds" {
  name        = join("-", [var.app.name, "rds-subnet-group"])
  description = "Subnet group for our RDS instance"
  subnet_ids  = aws_subnet.private[*].id # Neato!
  tags        = {
    project = var.app.name
    Name    = join("-", [var.app.name, "rds-subnet-group"])
  }
}

/* Now to our Stack ! */

/* RDS Instances */
resource "aws_db_instance" "rds" {
  identifier             = join("-", [var.app.name, "rds"])
  allocated_storage      = tonumber(var.settings.rds.allocated_storage)
  engine                 = var.settings.rds.engine
  engine_version         = var.settings.rds.engine_version
  instance_class         = var.settings.rds.instance_class
  db_name                = var.settings.rds.db_name
  username               = var.rds_username
  password               = var.rds_password
  db_subnet_group_name   = aws_db_subnet_group.rds.id # Should this be id or name?
  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]
  skip_final_snapshot = tobool(var.settings.rds.skip_final_snapshot)
  tags                = {
    project = var.app.name
    Name    = join("-", [var.app.name, "rds"])
  }
}

/* EC2 Instances */
# TLS Key pair
resource "tls_private_key" "ec2" {
  algorithm = "RSA"
  rsa_bits  = 4096

  # Save the private key to a file
  provisioner "local-exec" {
    command = "echo '${self.private_key_pem}' > ~/.ssh/${var.app.name}-ec2-key.pem && chmod 600 ~/.ssh/${var.app.name}-ec2-key.pem"
  }
}
resource "aws_key_pair" "ec2" {
  key_name   = join("-", [var.app.name, "ec2-key"])
  public_key = tls_private_key.ec2.public_key_openssh
}
# IAM Role
resource "aws_iam_role" "ec2" {
  name               = join("-", [var.app.name, "ec2-role"])
  # TODO (amiller68) - Is this the right policy?
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Sid = ""
      }
    ]
  })
  tags = {
    project = var.app.name
    Name    = join("-", [var.app.name, "ec2-role"])
  }
}
resource "aws_iam_instance_profile" "ec2" {
  name = join("-", [var.app.name, "ec2-profile"])
  role = aws_iam_role.ec2.name
  tags = {
    project = var.app.name
    Name    = join("-", [var.app.name, "ec2-profile"])
  }
}
resource "aws_iam_role_policy" "ec2" {
  name   = join("-", [var.app.name, "ec2-policy"])
  role   = aws_iam_role.ec2.id
  # TODO (amiller68): Narrow down this policy to just the ECR image we need
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          # For ECR
          "ecr:GetAuthorizationToken",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          # For Provisioning ESB volumes with RexRay
          "ec2:AttachVolume",
          "ec2:CreateVolume",
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:DeleteVolume",
          "ec2:DeleteSnapshot",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumeAttribute",
          "ec2:DescribeVolumeStatus",
          "ec2:DescribeSnapshots",
          "ec2:CopySnapshot",
          "ec2:DescribeSnapshotAttribute",
          "ec2:DetachVolume",
          "ec2:ModifySnapshotAttribute",
          "ec2:ModifyVolumeAttribute",
          "ec2:DescribeTags"
        ],
        Resource : "*"
      }
    ]
  })
}
# AMI
data "aws_ami" "ec2" {
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
    volume_size = tonumber(var.settings.ec2.volume_size)
    volume_type = var.settings.ec2.volume_type
  }
  monitoring             = tobool(var.settings.ec2.monitoring)
  # Link our Dependencies
  ami                    = data.aws_ami.ec2.id
  key_name               = aws_key_pair.ec2.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  vpc_security_group_ids = [aws_security_group.ec2.id]
  subnet_id              = aws_subnet.public[count.index].id

  user_data              = <<-EOF
    #!/bin/bash
    set -ex
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    sudo service docker start
    sudo usermod -a -G docker ec2-user
  EOF

  tags = {
    project = var.app.name
    Name    = join("-", [var.app.name, "ec2", count.index])
  }
}
# Elastic IP
resource "aws_eip" "ec2" {
  count    = tonumber(var.settings.ec2.count)
  instance = aws_instance.ec2[count.index].id
  vpc      = true

  # Provision Our services with Ansible
  provisioner "local-exec" {
    command = <<-EOT
      ansible-playbook \
        -i ${aws_instance.ec2[0].public_dns}, \
        -u ec2-user \
        --private-key ~/.ssh${var.app.name}-ec2-key.pem \
        --extra-vars "app=${var.app.name}" \
        --extra-vars "aws_region=${var.aws_region}" \
        --extra-vars "aws_account_id=${data.aws_caller_identity.current.account_id}" \
        --extra-vars "api_hostname=${var.app.api_hostname}" \
        --extra-vars "api_port=${var.app.api_port}" \
        --extra-vars "www_hostname=${var.app.www_hostname}" \
        --extra-vars "fullnode_api=${var.app.fullnode_api}" \
        --extra-vars "db_type=${var.settings.rds.engine}" \
        --extra-vars "db_endpoint=${aws_db_instance.rds.endpoint}" \
        --extra-vars "db_name=${var.settings.rds.db_name}" \
        --extra-vars "db_username=${var.rds_username}" \
        --extra-vars "db_password=${var.rds_password}" \
        --extra-vars "ebs_mount_dir=${var.settings.ebs.mount_dir}" \
        ec2-setup.yml
    EOT
  }

  tags     = {
    project = var.app.name
    Name    = join("-", [var.app.name, "ec2-eip", count.index])
  }
}
# TODO: (amiller68) - Add a Route53 zone for the domain. We can use this to create a CNAME record for the EC2 instance
#resource "aws_acm_certificate" "ec2" {
#  domain_name       = "example.com"
#  validation_method = "DNS"
#}
#
#resource "aws_route53_zone" "ec2" {
#  name         = "example.com"
#}
#
#resource "aws_route53_record" "ec2" {
#  for_each = {
#    for dvo in aws_acm_certificate.ec2.domain_validation_options : dvo.domain_name => {
#      name   = dvo.resource_record_name
#      record = dvo.resource_record_value
#      type   = dvo.resource_record_type
#    }
#  }
#
#  allow_overwrite = true
#  name            = each.value.name
#  records         = [each.value.record]
#  ttl             = 60
#  type            = each.value.type
#  zone_id         = aws_route53_zone.ec2.zone_id
#}
#
#resource "aws_acm_certificate_validation" "ec2" {
#  certificate_arn         = aws_acm_certificate.ec2.arn
#  validation_record_fqdns = [for record in aws_route53_record.ec2 : record.fqdn]
#}
resource "aws_elb" "ec2" {
  name               = join("-", [var.app.name, "ec2-elb"])
  # TODO (amiller68): Make more robust to handle multiple subnets
  subnets = [
    aws_subnet.public[0].id,
  ]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  # Note (al) - This won't work until we set up a Route53 zone for the domain
  #  listener {
  #    instance_port      = 80
  #    instance_protocol  = "http"
  #    lb_port            = 443
  #    lb_protocol        = "https"
  #    ssl_certificate_id = aws_acm_certificate_validation.ec2.certificate_arn
  #  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8000/"
    interval            = 30
  }

  instances                   = [aws_instance.ec2[0].id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400

  tags = {
    project = var.app.name
    Name    = join("-", [var.app.name, "ec2-elb"])
  }
}