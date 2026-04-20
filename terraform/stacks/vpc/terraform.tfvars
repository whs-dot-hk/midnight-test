aws_region = "us-east-1"
vpc_name   = "midnight-test-vpc"
vpc_cidr   = "10.100.0.0/16"

azs = ["us-east-1a", "us-east-1b", "us-east-1c"]

public_subnets = [
  # Intentionally spaced to leave room for future subnet growth.
  "10.100.0.0/23",
  "10.100.10.0/23",
  "10.100.20.0/23"
]

private_subnets = [
  "10.100.100.0/23",
  "10.100.110.0/23",
  "10.100.120.0/23",
]

database_subnets = [
  "10.100.200.0/23",
  "10.100.210.0/23",
  "10.100.220.0/23"
]

enable_nat_gateway = true
single_nat_gateway = true
enable_vpc_endpoints = true

interface_vpc_endpoints = [
  "ssm",
  "ssmmessages",
  "ec2messages",
  "logs",
]

gateway_vpc_endpoints = [
  "s3",
]

tags = {
  Environment = "test"
  Project     = "midnight-test"
  Terraform   = "true"
}
