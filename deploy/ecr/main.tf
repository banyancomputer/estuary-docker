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

/* ECR Repository */
resource "aws_ecr_repository" "ecr" {
  name                 = join("-", [var.app.name, "ecr"])
  image_tag_mutability = "MUTABLE"

  provisioner "local-exec" {
    command = <<-EOT
      ansible-playbook \
        -e aws_region=${var.aws_region} \
        -e aws_account_id=${data.aws_caller_identity.current.account_id} \
        -e docker_dir=docker \
        image-build.yml \
    EOT
  }

  tags = {
    project = var.app.name
    Name    = join("-", [var.app.name, "ecr"])
  }
}