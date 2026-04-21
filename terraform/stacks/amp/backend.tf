terraform {
  backend "s3" {
    bucket         = "midnight-test-tf-state"
    key            = "stacks/amp/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "midnight-test-tf-state-lock"
    encrypt        = true
  }
}
