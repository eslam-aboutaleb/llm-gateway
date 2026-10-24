# Production Stack Outputs

output "instance_public_ip" {
  description = "Public IP of the gateway instance"
  value       = module.compute.instance_public_ip
}

output "instance_private_ip" {
  description = "Private IP of the gateway instance"
  value       = module.compute.instance_private_ip
}

output "instance_ocid" {
  description = "OCID of the gateway instance"
  value       = module.compute.instance_id
}

output "vcn_id" {
  description = "OCID of the VCN"
  value       = module.network.vcn_id
}

output "public_subnet_id" {
  description = "OCID of the public subnet"
  value       = module.network.public_subnet_id
}

output "tfstate_bucket_name" {
  description = "Terraform state bucket name"
  value       = module.storage.tfstate_bucket_name
}

output "backup_bucket_name" {
  description = "Backup bucket name"
  value       = module.storage.backup_bucket_name
}

output "releases_bucket_name" {
  description = "Release artifacts bucket name"
  value       = module.storage.releases_bucket_name
}

output "instance_principal_arn" {
  description = "Instance principal ARN for OIDC"
  value       = module.identity.instance_principal_arn
}

output "notification_topic_id" {
  description = "OCID of the notification topic"
  value       = module.alarms.notification_topic_id
}