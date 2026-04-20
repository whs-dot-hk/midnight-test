output "instance_id" {
  description = "ID of the Cardano DB Sync EC2 instance"
  value       = module.cardano_db_sync_instance.id
}

output "private_ip" {
  description = "Private IP of the Cardano DB Sync EC2 instance"
  value       = module.cardano_db_sync_instance.private_ip
}

output "public_ip" {
  description = "Public IP of the Cardano DB Sync EC2 instance"
  value       = module.cardano_db_sync_instance.public_ip
}

output "security_group_id" {
  description = "Security group ID attached to the instance"
  value       = module.security_group.security_group_id
}
