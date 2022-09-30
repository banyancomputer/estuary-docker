# Our AWS region
variable "aws_region" {
  default = "us-east-2"
}
# The Size of the blockstore volume
variable "blockstore_size" {
  default = "20"
}
# What defines access to our application
variable "app" {
  type    = map(string)
  default = {
    name         = "estuary"
    www_hostname = "banyan.computer"
    api_hostname = "banyan.computer"
    api_port     = "3004"
    fullnode_api = "ws://api.chain.love"
  }
}
# The settings for our Instances
variable "settings" {
  description = "Configuration Settings"
  type        = map(map(string))
  # Note (al): For some reason, map(map(any)) doesn't work here.
  # Set config values as strings and convert to the appropriate type.
  default     = {
    # Configuration for RDS
    rds = {
      allocated_storage   = "5" # in GB TODO: Make this a variable/bigger
      engine              = "postgres"
      engine_version      = "14"
      instance_class      = "db.t3.micro" # TODO: Research what instance is appropriate
      db_name             = "estuary"
      skip_final_snapshot = "true" # Don't create a final snapshot (backup)
    },
    # Configuration for our EC2 instance
    ec2 = {
      count         = "1" # We only want one instance
      instance_type = "t3.medium" # Estuary team has been using this
      monitoring    = "true"
      volume_type   = "gp3"
      volume_size   = "20" # in GB. The Size needed for the AMI
    },
    # Configuration for our EBS volume and attachment. Created by Ansible
    ebs = {
      volume_type = "gp3"
      volume_size = "20" # in GB.
      mount_dir   = "/mnt"
    },
  }
}
# Our VPC CIDR
variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
# Our public subnet counts
variable "subnet_count" {
  description = "A mapping for the number of subnets for each type"
  type        = map(number)
  default     = {
    public  = 1 # One public for our EC2 instance
    private = 2 # Two private for our RDS instance
  }
}
# Our public subnet CIDRs
variable "public_subnet_cidrs" {
  description = "A list of available public subnet CIDRs"
  type        = list(string)
  default     = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
    "10.0.4.0/24",
  ]
}
# Our private subnet CIDRs
variable "private_subnet_cidrs" {
  description = "A list of available private subnet CIDRs"
  type        = list(string)
  default     = [
    "10.0.101.0/24",
    "10.0.102.0/24",
    "10.0.103.0/24",
    "10.0.104.0/24",
  ]
}
# The username for our RDS instance
variable "rds_username" {
  description = "The username for our RDS instance"
  type        = string
  sensitive   = true
}
# The password for our RDS instance
variable "rds_password" {
  description = "The password for the RDS instance"
  type        = string
  sensitive   = true
}