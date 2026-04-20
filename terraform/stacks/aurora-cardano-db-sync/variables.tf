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

variable "cluster_name" {
  description = "Name for the Aurora cluster"
  type        = string
  default     = "midnight-test-aurora-cardano-db-sync"
}

variable "engine" {
  description = "Aurora database engine"
  type        = string
  default     = "aurora-postgresql"
}

variable "engine_version" {
  description = "Aurora engine version"
  type        = string
  default     = "17.4"
}

variable "database_name" {
  description = "Initial database name created in the cluster"
  type        = string
  default     = "app"
}

variable "master_username" {
  description = "Master username for the cluster"
  type        = string
  default     = "dbadmin"
}

variable "serverless_min_capacity" {
  description = "Minimum ACU for Aurora Serverless v2"
  type        = number
  default     = 0.5
}

variable "serverless_max_capacity" {
  description = "Maximum ACU for Aurora Serverless v2"
  type        = number
  default     = 8
}

variable "instance_count" {
  description = "Number of Aurora instances to create"
  type        = number
  default     = 1
}

variable "port" {
  description = "Database port used by Aurora"
  type        = number
  default     = 5432
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the Aurora cluster"
  type        = list(string)
  default     = ["10.100.0.0/16"]
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Enable deletion protection for the cluster"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on cluster deletion"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags applied to resources"
  type        = map(string)
  default = {
    Terraform = "true"
    Stack     = "aurora"
  }
}
