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
  description = "Name tag for the Cardano DB Sync instance"
  type        = string
  default     = "midnight-test-ec2-cardano-db-sync"
}

variable "ami_id" {
  description = "Optional AMI ID override for the Cardano DB Sync instance"
  type        = string
  default     = null
}

variable "ubuntu_ami_name_pattern" {
  description = "AMI name pattern used to discover the latest Ubuntu image"
  type        = string
  default     = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
}

variable "instance_type" {
  description = "EC2 instance type for Cardano DB Sync"
  type        = string
  default     = "m7i.2xlarge"
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
  default     = 200
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access the instance"
  type        = list(string)
  default     = ["10.100.0.0/16"]
}

variable "db_sync_port" {
  description = "Cardano DB Sync API/metrics port"
  type        = number
  default     = 3001
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
    Stack     = "ec2-cardano-db-sync"
  }
}
