# Terramate stack variables for production

variable "oci_region" {
  description = "OCI region (home region for Always Free)"
  type        = string
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+-[0-9]+$", var.oci_region))
    error_message = "OCI region must be in format like 'us-ashburn-1'."
  }
}

variable "oci_tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
  validation {
    condition     = can(regex("^ocid1\\.tenancy\\.oc1\\..+", var.oci_tenancy_ocid))
    error_message = "Must be a valid OCI Tenancy OCID."
  }
}

variable "oci_user_ocid" {
  description = "OCI User OCID (for bootstrap only)"
  type        = string
  validation {
    condition     = can(regex("^ocid1\\.user\\.oc1\\..+", var.oci_user_ocid))
    error_message = "Must be a valid OCI User OCID."
  }
}

variable "oci_compartment_ocid" {
  description = "OCI Compartment OCID for resources"
  type        = string
  validation {
    condition     = can(regex("^ocid1\\.compartment\\.oc1\\..+", var.oci_compartment_ocid))
    error_message = "Must be a valid OCI Compartment OCID."
  }
}

variable "oci_object_storage_namespace" {
  description = "OCI Object Storage namespace"
  type        = string
}

variable "oci_ssh_public_key" {
  description = "SSH public key for VM access (OpenSSH format)"
  type        = string
  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)\\s+\\S+", var.oci_ssh_public_key))
    error_message = "Must be a valid OpenSSH public key."
  }
}

variable "gateway_dns_domain" {
  description = "DNS domain for gateway (e.g., llm.example.com)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.gateway_dns_domain))
    error_message = "Must be a valid DNS domain name."
  }
}

variable "acme_email" {
  description = "Email for ACME certificate registration"
  type        = string
  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.acme_email))
    error_message = "Must be a valid email address."
  }
}

# LiteLLM Configuration (injected at runtime, not stored in Terraform)
variable "litellm_master_key" {
  description = "LiteLLM master key (admin only, injected via secrets)"
  type        = string
  sensitive   = true
}

variable "litellm_salt_key" {
  description = "LiteLLM salt key for DB encryption (injected via secrets)"
  type        = string
  sensitive   = true
}

variable "database_url" {
  description = "PostgreSQL connection URL (injected via secrets)"
  type        = string
  sensitive   = true
}

variable "redis_url" {
  description = "Redis connection URL (injected via secrets)"
  type        = string
  sensitive   = true
}

# Upstream Provider Credentials (injected at runtime)
variable "openai_api_key" {
  description = "OpenAI API key (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "anthropic_api_key" {
  description = "Anthropic API key (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "azure_api_key" {
  description = "Azure OpenAI API key (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "azure_api_base" {
  description = "Azure OpenAI API base URL (optional)"
  type        = string
  default     = ""
}

variable "azure_api_version" {
  description = "Azure OpenAI API version (optional)"
  type        = string
  default     = ""
}

# Monitoring
variable "alert_webhook_url" {
  description = "Webhook URL for alerts (Slack, PagerDuty, etc.)"
  type        = string
  sensitive   = true
  default     = ""
}

# Backup
variable "backup_age_public_key" {
  description = "Age encryption public key for backups"
  type        = string
  validation {
    condition     = can(regex("^age1[a-z0-9]+$", var.backup_age_public_key))
    error_message = "Must be a valid age public key (starts with age1)."
  }
}

variable "oci_backup_bucket" {
  description = "OCI Object Storage bucket for backups"
  type        = string
  default     = ""
}

# GitHub Actions OIDC
variable "github_repository" {
  description = "GitHub repository (owner/repo) for OIDC trust"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$", var.github_repository))
    error_message = "Must be in format 'owner/repo'."
  }
}

variable "oci_oidc_provider_url" {
  description = "OCI OIDC provider URL for workload identity federation"
  type        = string
  default     = ""
}

variable "default_tags" {
  description = "Default freeform tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "llm-gateway"
    Environment = "production"
    ManagedBy   = "terramate"
  }
}