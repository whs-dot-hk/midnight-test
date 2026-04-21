output "instance_id" {
  description = "ID of the Midnight node EC2 instance"
  value       = module.midnight_node_instance.id
}

output "private_ip" {
  description = "Private IP of the Midnight node EC2 instance"
  value       = module.midnight_node_instance.private_ip
}

output "public_ip" {
  description = "Public IP of the Midnight node EC2 instance"
  value       = module.midnight_node_instance.public_ip
}

output "security_group_id" {
  description = "Security group ID attached to the instance"
  value       = module.security_group.security_group_id
}
