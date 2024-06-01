# Estuary Terraform Deployment
## Image Repository 

This Directory describes a development deployment Environment and Architecture for an Estuary node.
Hopefully this will be useful for anyone who wants to deploy Estuary on AWS EC2 and RDS or use it as a reference for their own deployment.
The goal is to implement a robust CD pipeline for Estuary.

## Contents

### `ecr/`
This directory contains the Terraform configuration for building and pushing the Estuary Docker image to ECR.

`vars.tf` contains the default configuration for the components described in `main.tf`."

`main.tf` contains the Terraform configuration for deploying an ECR, and building and pushing the Estuary Docker image to ECR.
It references the `image-build.yml` playbook for building the image and pushing it to ECR.

### `infra/`
This directory contains the Terraform configuration for deploying Estuary on AWS EC2 and RDS.

`secret.tfvars.example` is a template for the variables that need to be set in order to deploy Estuary.  Copy this file to `secret.tfvars` and fill in the values.

`vars.tf` contains our default configuration for the components described in `main.tf`."

`main.tf` contains the Terraform configuration for deploying Estuary on AWS EC2 and RDS.
It describes the following components implemented in AWS:

- VPC
  - This is the Virtual Private Cloud that the Estuary node will be deployed in.
- Internet Gateway
  - This is the gateway that allows the Estuary node to communicate with the internet.
- Subnets
  - Public Subnet(s)
    - Ec2 Subnet
      - This is the subnet that the Estuary node will be deployed in.
      - See `vars.tf` for its Default CIDR Block.
      - It deployed accross one Availability Zone.
  - Private Subnet(s)
    - RDS Subnet Group
      - RDS requires at least 2 subnets in different availability zones.
      - See `vars.tf` for their Default CIDR Blocks.
      - They are deployed accross two Availability Zones.
      - The RDS Subnet Group is used to deploy the RDS instance.
- Routing Table
  - This routing table has a route to the internet gateway.
  - Associated w/ Public Subnet(s):
  - Associated w/ Private Subnet(s):
- Security Groups
  - TODO: Audit Security Groups
  - EC2
    - Associated w/ VPC
    - Ingress:
      - SSH
      - HTTP TODO: is this needed?
      - HTTPS
      - RDS (Postgres)
    - Egress:
      - The Internet
  - RDS
    - Associated w/ VPC
    - Ingress:
      - RDS (Postgres) from EC2 Security Group
    - Egress:
      - The Internet
- EC2 Instance
  - This Describes the Environment for the Estuary node.
  - Implements TLS Private Key: RSA / 4096 | Public Key pair
    - TODO: Integrate with AWS KMS
    - Outputs the private key to terraform.tfstate as an unencrypted output
  - Implements a Role for 
    - Reading from the ECR Repository (should be deployed in the same account)
    - Managing EBS Volumes
  - Configures an AMI
    - This AMI is based on the latest Amazon Linux 2 AMI.
  - Declares an Ec2 instance
    - From AMI
    - Associated w/ Ec2 Security Group
    - Associated w/ TLS KEY
    - Associated w/ ECR Role
    - Associated w/ Public Subnet
    - Installs Docker
  - Elastic IP
    - This is the Elastic IP that the Estuary node will be deployed in.
    - Associated w/ EC2 Instance
- RDS Instance
  - Postgres
  - See `vars.tf` for its Default Configuration.
  - Associated w/ RDS Subnet Group
It references the `ec2-setup.yml` playbook for deploying the image to EC2. This script is run as a `remote-exec` provisioner in `main.tf`.
Keep in mind that it creates an EBS volume that is NOT managed by Terraform. 
This volume is meant to be used as a persistent storage for the Estuary node between deployments.
If you want to remove the volume, you will need to do so manually.

`outputs.tf` describes the outputs of the Terraform configuration.
It returns:
- The Elastic IP of the Estuary node.
- The RDS Endpoint.

## Deployment
1. Initialize and Push our Docker Image to ECR
```bash
$ cd ecr
$ terraform init
$ terraform apply
```
This will build and push the Estuary Docker image to ECR ... so it may take a while ... like a while a while.

2. Deploy our infrastructure with Terraform:
First configure `secret.tfvars` and `vars.tf` to your liking.
```bash
$ cd infra
$ terraform init
$ terraform apply -var-file=secret.tfvars
```


### Prerequisites

- Terraform
- Ansible
  - With the `community.docker` collection installed  
- AWS Account with IAM User with Admin Access

