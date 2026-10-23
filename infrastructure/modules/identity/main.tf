# Identity module for llm-gateway (Dynamic Groups, Policies, OIDC)

# ===========================================
# Dynamic Group for Instance Principal
# ===========================================
resource "oci_identity_dynamic_group" "instance_principal" {
  compartment_id = var.compartment_id
  name           = "${var.tags["Project"]}-instance-principal"
  description    = "Dynamic group for gateway instance principal"
  matching_rule  = "ALL {instance.id = '${var.instance_id}'}"

  freeform_tags = var.tags
}

# ===========================================
# Policy for Instance Principal -> Object Storage
# ===========================================
resource "oci_identity_policy" "instance_object_storage" {
  count = var.allow_tfstate_bucket_access || var.allow_backup_bucket_access || var.allow_release_bucket_access ? 1 : 0

  compartment_id = var.compartment_id
  name           = "${var.tags["Project"]}-instance-object-storage"
  description    = "Allow instance principal to manage Object Storage buckets"

  statements = [
    # Allow reading tfstate bucket (for drift detection)
    "Allow dynamic-group ${oci_identity_dynamic_group.instance_principal.name} to read buckets in compartment ${var.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.instance_principal.name} to read objects in compartment ${var.compartment_id}",
    # Allow writing backups
    "Allow dynamic-group ${oci_identity_dynamic_group.instance_principal.name} to manage objects in compartment ${var.compartment_id} where target.bucket.name='${var.tags["Project"]}-backups'",
    # Allow reading releases (for deployment)
    "Allow dynamic-group ${oci_identity_dynamic_group.instance_principal.name} to read objects in compartment ${var.compartment_id} where target.bucket.name='${var.tags["Project"]}-releases'"
  ]

  freeform_tags = var.tags
}

# ===========================================
# Policy for Instance Principal -> Vault/Secrets (if used)
# ===========================================
resource "oci_identity_policy" "instance_secrets" {
  compartment_id = var.compartment_id
  name           = "${var.tags["Project"]}-instance-secrets"
  description    = "Allow instance principal to read secrets from Vault"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.instance_principal.name} to read secret-family in compartment ${var.compartment_id}"
  ]

  freeform_tags = var.tags
}

# ===========================================
# OIDC Identity Provider for GitHub Actions
# ===========================================
resource "oci_identity_identity_provider" "github" {
  count = var.oci_oidc_provider_url != "" ? 1 : 0

  compartment_id = var.compartment_id
  name           = "${var.tags["Project"]}-github-oidc"
  description    = "GitHub Actions OIDC Identity Provider"
  product_type   = "OIDC"
  provider_url   = var.oci_oidc_provider_url

  freeform_tags = var.tags
}

# ===========================================
# OIDC Group Mapping (GitHub repo -> OCI Group)
# ===========================================
resource "oci_identity_group" "github_actions" {
  count = var.oci_oidc_provider_url != "" ? 1 : 0

  compartment_id = var.compartment_id
  name           = "${var.tags["Project"]}-github-actions"
  description    = "Group for GitHub Actions runners"

  freeform_tags = var.tags
}

# ===========================================
# Policy for GitHub Actions -> Infrastructure (Plan)
# ===========================================
resource "oci_identity_policy" "github_plan" {
  count = var.oci_oidc_provider_url != "" ? 1 : 0

  compartment_id = var.compartment_id
  name           = "${var.tags["Project"]}-github-plan"
  description    = "Allow GitHub Actions to plan infrastructure"

  statements = [
    "Allow group ${oci_identity_group.github_actions[0].name} to read compartments in tenancy",
    "Allow group ${oci_identity_group.github_actions[0].name} to read vcns in compartment ${var.compartment_id}",
    "Allow group ${oci_identity_group.github_actions[0].name} to read subnets in compartment ${var.compartment_id}",
    "Allow group ${oci_identity_group.github_actions[0].name} to read instances in compartment ${var.compartment_id}",
    "Allow group ${oci_identity_group.github_actions[0].name} to read buckets in compartment ${var.compartment_id}",
    "Allow group ${oci_identity_group.github_actions[0].name} to read objects in compartment ${var.compartment_id}",
    "Allow group ${oci_identity_group.github_actions[0].name} to use dynamic-groups in compartment ${var.compartment_id}"
  ]

  freeform_tags = var.tags
}

# ===========================================
# Policy for GitHub Actions -> Infrastructure (Apply - restricted)
# ===========================================
resource "oci_identity_policy" "github_apply" {
  count = var.oci_oidc_provider_url != "" ? 1 : 0

  compartment_id = var.compartment_id
  name           = "${var.tags["Project"]}-github-apply"
  description    = "Allow GitHub Actions to apply infrastructure (protected env only)"

  statements = [
    "Allow group ${oci_identity_group.github_actions[0].name} to manage vcns in compartment ${var.compartment_id}",
    "Allow group ${oci_identity_group.github_actions[0].name} to manage subnets in compartment ${var.compartment_id}",
    "Allow group ${oci_identity_group.github_actions[0].name} to manage instances in compartment ${var.compartment_id}",
    "Allow group ${oci_identity_group.github_actions[0].name} to manage buckets in compartment ${var.compartment_id}",
    "Allow group ${oci_identity_group.github_actions[0].name} to manage objects in compartment ${var.compartment_id}",
    "Allow group ${oci_identity_group.github_actions[0].name} to manage dynamic-groups in compartment ${var.compartment_id}",
    "Allow group ${oci_identity_group.github_actions[0].name} to manage policies in compartment ${var.compartment_id}"
  ]

  freeform_tags = var.tags
}

# ===========================================
# Policy for GitHub Actions -> Release Bucket (Write)
# ===========================================
resource "oci_identity_policy" "github_releases" {
  count = var.oci_oidc_provider_url != "" ? 1 : 0

  compartment_id = var.compartment_id
  name           = "${var.tags["Project"]}-github-releases"
  description    = "Allow GitHub Actions to upload release artifacts"

  statements = [
    "Allow group ${oci_identity_group.github_actions[0].name} to manage objects in compartment ${var.compartment_id} where target.bucket.name='${var.tags["Project"]}-releases'"
  ]

  freeform_tags = var.tags
}

# ===========================================
# Outputs
# ===========================================
output "instance_principal_dynamic_group_name" {
  description = "Name of the instance principal dynamic group"
  value       = oci_identity_dynamic_group.instance_principal.name
}

output "instance_principal_arn" {
  description = "ARN of the instance principal (for OIDC trust)"
  value       = "instance/${var.instance_id}"
}

output "github_actions_group_name" {
  description = "Name of the GitHub Actions group"
  value       = try(oci_identity_group.github_actions[0].name, "")
}

output "github_oidc_provider_name" {
  description = "Name of the GitHub OIDC provider"
  value       = try(oci_identity_identity_provider.github[0].name, "")
}