module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.6"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs              = var.azs
  private_subnets  = var.private_subnets
  public_subnets   = var.public_subnets
  database_subnets = var.database_subnets

  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  tags = var.tags
}

locals {
  interface_vpc_endpoints = {
    for service in var.interface_vpc_endpoints : replace(service, ".", "_") => {
      service             = service
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags = {
        Name = "${var.vpc_name}-${replace(service, ".", "-")}-endpoint"
      }
    }
  }

  gateway_vpc_endpoints = {
    for service in var.gateway_vpc_endpoints : replace(service, ".", "_") => {
      service         = service
      service_type    = "Gateway"
      route_table_ids = concat(module.vpc.private_route_table_ids, module.vpc.database_route_table_ids)
      tags = {
        Name = "${var.vpc_name}-${replace(service, ".", "-")}-endpoint"
      }
    }
  }
}

module "vpc_endpoints" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  create = var.enable_vpc_endpoints
  vpc_id = module.vpc.vpc_id

  create_security_group      = length(var.interface_vpc_endpoints) > 0
  security_group_name_prefix = "${var.vpc_name}-vpc-endpoints-"
  security_group_description = "Security group for VPC interface endpoints"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC CIDR"
      cidr_blocks = [var.vpc_cidr]
    }
  }

  endpoints = merge(local.interface_vpc_endpoints, local.gateway_vpc_endpoints)
  tags      = var.tags
}
