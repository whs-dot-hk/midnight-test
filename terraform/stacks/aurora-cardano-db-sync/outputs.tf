output "cluster_id" {
  description = "Aurora cluster identifier"
  value       = module.aurora.cluster_id
}

output "cluster_arn" {
  description = "Aurora cluster ARN"
  value       = module.aurora.cluster_arn
}

output "cluster_endpoint" {
  description = "Writer endpoint for the Aurora cluster"
  value       = module.aurora.cluster_endpoint
}

output "cluster_reader_endpoint" {
  description = "Reader endpoint for the Aurora cluster"
  value       = module.aurora.cluster_reader_endpoint
}

output "master_user_secret_arn" {
  description = "ARN of Secrets Manager secret for the master user"
  value       = try(module.aurora.cluster_master_user_secret[0].secret_arn, null)
}
