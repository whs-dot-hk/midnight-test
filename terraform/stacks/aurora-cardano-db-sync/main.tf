data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.vpc_remote_state_bucket
    key    = var.vpc_remote_state_key
    region = var.aws_region
  }
}

locals {
  instances = {
    for i in range(var.instance_count) :
    "instance-${i + 1}" => {
      instance_class = "db.serverless"
    }
  }
}

module "aurora" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 9.0"

  name           = var.cluster_name
  engine         = var.engine
  engine_mode    = "provisioned"
  engine_version = var.engine_version

  database_name = var.database_name
  master_username = var.master_username

  manage_master_user_password = true
  storage_encrypted           = true

  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot

  vpc_id                 = data.terraform_remote_state.vpc.outputs.vpc_id
  create_db_subnet_group = false
  db_subnet_group_name   = data.terraform_remote_state.vpc.outputs.database_subnet_group

  instances = local.instances

  serverlessv2_scaling_configuration = {
    min_capacity = var.serverless_min_capacity
    max_capacity = var.serverless_max_capacity
  }

  create_security_group = true
  security_group_rules = {
    ingress_app = {
      type        = "ingress"
      from_port   = var.port
      to_port     = var.port
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
      description = "Allow app network access to Aurora"
    }
  }

  tags = var.tags
}
