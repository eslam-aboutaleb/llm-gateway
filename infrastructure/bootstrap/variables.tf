# Bootstrap module variables

variable "oci_region" {
  description = "OCI region"
  type        = string
}

variable "oci_tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
}

variable "oci_compartment_ocid" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "oci_object_storage_namespace" {
  description = "OCI Object Storage namespace"
  type        = string
}

variable "tfstate_bucket_name" {
  description = "Terraform state bucket name"
  type        = string
}

variable "backup_bucket_name" {
  description = "Backup bucket name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}