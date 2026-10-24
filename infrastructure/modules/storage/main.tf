# Storage module for llm-gateway (OCI Object Storage)

# ===========================================
# Backup Bucket
# ===========================================
resource "oci_objectstorage_bucket" "backups" {
  compartment_id = var.compartment_id
  namespace      = var.namespace
  name           = var.backup_bucket_name
  storage_tier   = "Standard"
  versioning     = "Enabled"
  access_type    = "NoPublicAccess"

  freeform_tags = merge(var.tags, { Purpose = "backups" })
}

# ===========================================
# Release Artifacts Bucket (for CI/CD)
# ===========================================
resource "oci_objectstorage_bucket" "releases" {
  compartment_id = var.compartment_id
  namespace      = var.namespace
  name           = "releases-${var.namespace}"
  storage_tier   = "Standard"
  versioning     = "Enabled"
  access_type    = "NoPublicAccess"

  freeform_tags = merge(var.tags, { Purpose = "releases" })
}

# ===========================================
# Outputs
# ===========================================
output "tfstate_bucket_name" {
  description = "Terraform state bucket name"
  value       = var.tfstate_bucket_name
}

output "tfstate_bucket_namespace" {
  description = "Object Storage namespace"
  value       = var.namespace
}

output "backup_bucket_name" {
  description = "Backup bucket name"
  value       = oci_objectstorage_bucket.backups.name
}

output "backup_bucket_namespace" {
  description = "Object Storage namespace"
  value       = oci_objectstorage_bucket.backups.namespace
}

output "releases_bucket_name" {
  description = "Release artifacts bucket name"
  value       = oci_objectstorage_bucket.releases.name
}

output "releases_bucket_namespace" {
  description = "Object Storage namespace"
  value       = oci_objectstorage_bucket.releases.namespace
}