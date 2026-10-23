# Storage module for llm-gateway (OCI Object Storage)

# ===========================================
# Terraform State Bucket
# ===========================================
resource "oci_objectstorage_bucket" "tfstate" {
  compartment_id = var.compartment_id
  namespace      = var.namespace
  name           = var.tfstate_bucket_name
  storage_tier   = "Standard"
  versioning     = "Enabled"
  public_access_type = "NoPublicAccess"

  # Lifecycle policy: retain versions for 90 days
  object_lifecycle_policy = {
    rule = [
      {
        name        = "retain-versions-90d"
        action      = "DELETE"
        time_amount = 90
        time_unit   = "DAYS"
        is_enabled  = true
        filters = {
          name_prefix = ""
        }
      }
    ]
  }

  freeform_tags = merge(var.tags, { Purpose = "tfstate" })
}

# ===========================================
# Backup Bucket
# ===========================================
resource "oci_objectstorage_bucket" "backups" {
  compartment_id = var.compartment_id
  namespace      = var.namespace
  name           = var.backup_bucket_name
  storage_tier   = "Standard"
  versioning     = "Enabled"
  public_access_type = "NoPublicAccess"

  # Lifecycle policy: retain for 30 days, max 20 GB total
  object_lifecycle_policy = {
    rule = [
      {
        name        = "retain-backups-30d"
        action      = "DELETE"
        time_amount = 30
        time_unit   = "DAYS"
        is_enabled  = true
        filters = {
          name_prefix = ""
        }
      }
    ]
  }

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
  public_access_type = "NoPublicAccess"

  # Retain releases for 180 days
  object_lifecycle_policy = {
    rule = [
      {
        name        = "retain-releases-180d"
        action      = "DELETE"
        time_amount = 180
        time_unit   = "DAYS"
        is_enabled  = true
        filters = {
          name_prefix = ""
        }
      }
    ]
  }

  freeform_tags = merge(var.tags, { Purpose = "releases" })
}

# ===========================================
# Outputs
# ===========================================
output "tfstate_bucket_name" {
  description = "Terraform state bucket name"
  value       = oci_objectstorage_bucket.tfstate.name
}

output "tfstate_bucket_namespace" {
  description = "Object Storage namespace"
  value       = oci_objectstorage_bucket.tfstate.namespace
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