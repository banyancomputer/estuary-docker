variable "project" {
  default = "estuary"
}
# Our AWS region
variable "aws_region" {
  default = "us-east-2"
}
# Our Deployment Settings
variable "settings" {
  description = "Configuration Settings"
  type        = map(any)
  default     = tomap({
    # Configuration for RDS
    rds = tomap({
      allocated_storage   = 20 # in GB TODO: Make this a variable/bigger
      engine              = "postgres"
      engine_version      = "14.0" # TODO: Figure out which version we want
      instance_class      = "db.t3.micro" # TODO: Research what instance is appropriate
      db_name             = "estuary-db"
      skip_final_snapshot = true # Don't create a final snapshot (backup)
    }),
    # Configuration for our EC2 instance
    ec2 = tomap({
      count             = 1 # We only want one instance
      instance_type     = "t3.medium" # TODO: Research what instance is appropriate
      monitoring        = true
      root_block_device = tomap({
        volume_type = "gp3"
        volume_size = 20 # in GB TODO: Make this a variable/bigger
      })
    }),
  })
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
# The local IP address of the machine running Terraform. This is used to control access to the EC2 security group.
#variable "local_ip" {
#  description = "The local IP address of the machine running Terraform"
#  type        = string
#  sensitive   = true
#}
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