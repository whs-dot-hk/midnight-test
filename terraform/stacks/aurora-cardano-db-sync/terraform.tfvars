aws_region = "us-east-1"

vpc_remote_state_bucket = "midnight-test-tf-state"
vpc_remote_state_key    = "stacks/vpc/terraform.tfstate"

cluster_name    = "midnight-test-aurora-cardano-db-sync"
engine          = "aurora-postgresql"
engine_version  = "17.4"
database_name   = "app"
master_username = "dbadmin"

serverless_min_capacity = 0.5
serverless_max_capacity = 4
instance_count          = 1

allowed_cidr_blocks = [
  "10.100.0.0/16",
]

backup_retention_period = 7
deletion_protection     = true
skip_final_snapshot     = false

tags = {
  Environment = "test"
  Project     = "midnight-test"
  Terraform   = "true"
}
