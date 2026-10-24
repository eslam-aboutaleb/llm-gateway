# Storage module variables

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "namespace" {
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