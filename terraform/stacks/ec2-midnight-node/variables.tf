variable "aws_region" {
  description = "AWS region for this stack"
  type        = string
  default     = "us-east-1"
}

variable "vpc_remote_state_bucket" {
  description = "S3 bucket containing the VPC remote state"
  type        = string
  default     = "midnight-test-tf-state"
}

variable "vpc_remote_state_key" {
  description = "S3 object key for the VPC remote state file"
  type        = string
  default     = "stacks/vpc/terraform.tfstate"
}

variable "instance_name" {
  description = "Name tag for the Midnight node instance"
  type        = string
  default     = "midnight-test-ec2-midnight-node"
}

variable "ami_id" {
  description = "Optional AMI ID override for the Midnight node instance"
  type        = string
  default     = null
}

variable "ubuntu_ami_name_pattern" {
  description = "AMI name pattern used to discover the latest Ubuntu image"
  type        = string
  default     = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
}

variable "instance_type" {
  description = "EC2 instance type for the Midnight node"
  type        = string
  default     = "c7i.2xlarge"
}

variable "subnet_index" {
  description = "Index of the private subnet from VPC remote state"
  type        = number
  default     = 0
}

variable "key_name" {
  description = "Optional EC2 key pair name for SSH access"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 500
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach RPC, metrics, P2P, and optional SSH"
  type        = list(string)
  default     = ["10.100.0.0/16"]
}

variable "rpc_http_port" {
  description = "JSON-RPC HTTP port (README default 9944)"
  type        = number
  default     = 9944
}

variable "rpc_ws_port" {
  description = "JSON-RPC WebSocket port (common Substrate default 9933)"
  type        = number
  default     = 9933
}

variable "prometheus_metrics_port" {
  description = "Prometheus metrics port (README default 9615)"
  type        = number
  default     = 9615
}

variable "node_exporter_port" {
  description = "Host metrics exporter port (README default 9100)"
  type        = number
  default     = 9100
}

variable "p2p_port" {
  description = "Libp2p listening port (common Substrate default 30333)"
  type        = number
  default     = 30333
}

variable "enable_ssh" {
  description = "Whether to allow SSH access to the instance"
  type        = bool
  default     = false
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP address to the instance"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags applied to resources"
  type        = map(string)
  default = {
    Terraform = "true"
    Stack     = "ec2-midnight-node"
  }
}
