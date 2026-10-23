# Identity module variables

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "instance_id" {
  description = "Instance OCID"
  type        = string
}

variable "allow_tfstate_bucket_access" {
  description = "Allow instance to access tfstate bucket"
  type        = bool
  default     = true
}

variable "allow_backup_bucket_access" {
  description = "Allow instance to access backup bucket"
  type        = bool
  default     = true
}

variable "allow_release_bucket_access" {
  description = "Allow instance to access release bucket"
  type        = bool
  default     = true
}

variable "github_repository" {
  description = "GitHub repository (owner/repo) for OIDC trust"
  type        = string
}

variable "oci_oidc_provider_url" {
  description = "OCI OIDC provider URL"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}