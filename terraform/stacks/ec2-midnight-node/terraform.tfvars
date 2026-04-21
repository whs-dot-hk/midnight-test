aws_region = "us-east-1"

vpc_remote_state_bucket = "midnight-test-tf-state"
vpc_remote_state_key    = "stacks/vpc/terraform.tfstate"

instance_name = "midnight-test-ec2-midnight-node"
instance_type = "c7i.2xlarge"
subnet_index  = 0
key_name      = null

root_volume_size            = 500
enable_ssh                  = false
associate_public_ip_address = false

ingress_cidr_blocks = [
  "10.100.0.0/16",
]

tags = {
  Environment = "test"
  Project     = "midnight-test"
  Terraform   = "true"
}
