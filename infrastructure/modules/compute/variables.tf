# Compute module variables

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet OCID for the instance"
  type        = string
}

variable "nsg_ids" {
  description = "List of NSG OCIDs to attach"
  type        = list(string)
  default     = []
}

variable "instance_shape" {
  description = "Instance shape (A1 Flex for Always Free)"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "instance_ocpu" {
  description = "Number of OCPUs"
  type        = number
  default     = 2
  validation {
    condition     = var.instance_ocpu >= 1 && var.instance_ocpu <= 4
    error_message = "A1 Flex supports 1-4 OCPUs."
  }
}

variable "instance_memory_gb" {
  description = "Memory in GB"
  type        = number
  default     = 12
  validation {
    condition     = var.instance_memory_gb >= 6 && var.instance_memory_gb <= 24
    error_message = "A1 Flex supports 6-24 GB per OCPU (max 24 GB total)."
  }
}

variable "boot_volume_size_gb" {
  description = "Boot volume size in GB"
  type        = number
  default     = 100
  validation {
    condition     = var.boot_volume_size_gb >= 50 && var.boot_volume_size_gb <= 200
    error_message = "Boot volume must be 50-200 GB for Always Free."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for the instance"
  type        = string
}

variable "cloud_init_template" {
  description = "Rendered cloud-init user data"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}