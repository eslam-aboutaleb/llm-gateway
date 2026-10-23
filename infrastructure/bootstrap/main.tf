# Bootstrap module for llm-gateway (one-time state bucket + IAM trust setup)
# Run this ONCE before the main stack, then import the bucket into the main stack state

# ===========================================
# Terraform State Bucket (created once, then imported)
# ===========================================
resource "oci_objectstorage_bucket" "tfstate" {
  compartment_id = var.oci_compartment_ocid
  namespace      = var.oci_object_storage_namespace
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

  freeform_tags = merge(var.tags, { Purpose = "tfstate", Bootstrap = "true" })
}

# ===========================================
# Backup Bucket (created once, then imported)
# ===========================================
resource "oci_objectstorage_bucket" "backups" {
  compartment_id = var.oci_compartment_ocid
  namespace      = var.oci_object_storage_namespace
  name           = var.backup_bucket_name
  storage_tier   = "Standard"
  versioning     = "Enabled"
  public_access_type = "NoPublicAccess"

  # Lifecycle policy: retain for 30 days
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

  freeform_tags = merge(var.tags, { Purpose = "backups", Bootstrap = "true" })
}

# ===========================================
# Outputs
# ===========================================
output "tfstate_bucket_name" {
  description = "Terraform state bucket name"
  value       = oci_objectstorage_bucket.tfstate.name
}

output "backup_bucket_name" {
  description = "Backup bucket name"
  value       = oci_objectstorage_bucket.backups.name
}

# After running this bootstrap, import into main stack:
# terraform import oci_objectstorage_bucket.tfstate <namespace>/<bucket-name>
# terraform import oci_objectstorage_bucket.backups <namespace>/<bucket-name>