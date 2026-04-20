output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "database_subnets" {
  description = "Database subnet IDs"
  value       = module.vpc.database_subnets
}

output "database_subnet_group" {
  description = "Database subnet group name"
  value       = module.vpc.database_subnet_group_name
}

output "vpc_endpoints" {
  description = "VPC endpoints created in this VPC"
  value       = module.vpc_endpoints.endpoints
}

output "vpc_endpoint_security_group_id" {
  description = "Security group ID used by interface VPC endpoints"
  value       = module.vpc_endpoints.security_group_id
}
