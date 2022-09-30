# Our AWS region
variable "aws_region" {
  default = "us-east-2"
}
# What defines access to our application
variable "app" {
  type    = map(string)
  default = {
    name         = "estuary"
    docker_dir = "/home/alex/estuary-docker/estuary-main"
  }
}