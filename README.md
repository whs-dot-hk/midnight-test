# Setup
## Terraform state

| Key | Value |
| --- | --- |
| S3 bucket name | midnight-test-tf-state |
| DynamoDB table name | midnight-test-tf-state-lock |

## Nix shell
```sh
nix-shell
```

## Terraform

## Terraform Stacks

| Stack | Description |
| --- | --- |
| `vpc` | Provisions the core VPC networking resources. |
| `aurora-cardano-db-sync` | Provisions an Aurora Serverless v2 database cluster for Cardano DB Sync. |
| `ec2-cardano-db-sync` | Provisions an EC2 instance and security group for Cardano DB Sync. |
