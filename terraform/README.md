# Estuary Terraform Deployment
## AWS EC2 + RDS 

This Directory describes a development deployment Environment and Architecture for an Estuary node. It is intended to be used as a reference for a production deployment.
Hopefully this will be useful for anyone who wants to deploy Estuary on AWS EC2 and RDS or use it as a reference for their own deployment.
The goal is to implement a robust CD pipeline for Estuary.

## Contents
This directory contains the Terraform configuration for deploying Estuary on AWS EC2 and RDS.

`secret.tfvars.example` is a template for the variables that need to be set in order to deploy Estuary.  Copy this file to `secret.tfvars` and fill in the values.

`vars.tf` contains our default configuration for the components described in `main.tf`."

`main.tf` contains the Terraform configuration for deploying Estuary on AWS EC2 and RDS.
It describes the following components implemented in AWS:

- ECR Repository
  - This is where the Estuary Docker image will be stored.
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
      - HTTP TODO: CHECK IF THIS IS NEEDED
      - HTTPS TODO: CHECK IF THIS IS NEEDED
      - RDS (Postgres)
      - Estuary API (TCP 3004) TODO: CHECK IF THIS IS NEEDED
    - Egress:
      - The Internet TODO: Narrow down to Deployed Estuary Domain
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
  - Implements a Role for Reading from the ECR Repository
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

`outputs.tf` describes the outputs of the Terraform configuration.
It returns:
- The Elastic IP of the Estuary node.
- The RDS Endpoint.

## Deployment
1. Deploy our infrastructure with Terraform:
```bash
$ terraform init
$ terraform plan -var-file=secret.tfvars
$ terraform apply -var-file=secret.tfvars
```
2. Push our Docker image to ECR:
```bash
$ aws ecr get-login-password --region <AWS_REGION> | docker login --username AWS --password-stdin <AWS_ACCT_NUMBER>.dkr.ecr.<AWS_REGION>.amazonaws.com
$ docker build -t <PROJECT-NAME>-ecr .
$ docker tag <PROJECT-NAME>-ecr:latest <AWS_ACCT_NUMBER>.dkr.ecr.<AWS_REGION>.amazonaws.com/<PROJECT-NAME>-ecr:latest
$ docker push <AWS_ACCT_NUMBER>.dkr.ecr.<AWS_REGION>.amazonaws.com/<PROJECT-NAME>-ecr:latest
```

### Prerequisites

