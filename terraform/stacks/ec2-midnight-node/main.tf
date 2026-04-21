data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.vpc_remote_state_bucket
    key    = var.vpc_remote_state_key
    region = var.aws_region
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = [var.ubuntu_ami_name_pattern]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  common_tags = merge(
    var.tags,
    {
      Name = var.instance_name
    }
  )

  ingress_rules = concat(
    [
      {
        from_port   = var.rpc_http_port
        to_port     = var.rpc_http_port
        protocol    = "tcp"
        description = "Midnight JSON-RPC (HTTP)"
        cidr_blocks = join(",", var.ingress_cidr_blocks)
      },
      {
        from_port   = var.rpc_ws_port
        to_port     = var.rpc_ws_port
        protocol    = "tcp"
        description = "Midnight JSON-RPC (WebSocket)"
        cidr_blocks = join(",", var.ingress_cidr_blocks)
      },
      {
        from_port   = var.prometheus_metrics_port
        to_port     = var.prometheus_metrics_port
        protocol    = "tcp"
        description = "Prometheus metrics"
        cidr_blocks = join(",", var.ingress_cidr_blocks)
      },
      {
        from_port   = var.node_exporter_port
        to_port     = var.node_exporter_port
        protocol    = "tcp"
        description = "Node exporter"
        cidr_blocks = join(",", var.ingress_cidr_blocks)
      },
      {
        from_port   = var.p2p_port
        to_port     = var.p2p_port
        protocol    = "tcp"
        description = "Substrate libp2p"
        cidr_blocks = join(",", var.ingress_cidr_blocks)
      },
    ],
    var.enable_ssh ? [
      {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        description = "SSH access"
        cidr_blocks = join(",", var.ingress_cidr_blocks)
      }
    ] : []
  )
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.3"

  name        = "${var.instance_name}-sg"
  description = "Security group for Midnight node EC2"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_with_cidr_blocks = local.ingress_rules

  egress_rules = ["all-all"]

  tags = local.common_tags
}

module "midnight_node_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.0"

  name          = var.instance_name
  ami           = coalesce(var.ami_id, data.aws_ami.ubuntu.id)
  instance_type = var.instance_type
  key_name      = var.key_name

  disable_api_termination = true

  create_iam_instance_profile = true
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  subnet_id = data.terraform_remote_state.vpc.outputs.private_subnets[var.subnet_index]

  vpc_security_group_ids      = [module.security_group.security_group_id]
  associate_public_ip_address = var.associate_public_ip_address

  root_block_device = {
    encrypted = true
    type      = "gp3"
    size      = var.root_volume_size
  }

  tags = local.common_tags
}
