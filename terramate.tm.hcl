# Terramate global configuration for llm-gateway

terramate {
  required_version = ">= 0.10.0"
}

globals {
  project_name        = "llm-gateway"
  project_description = "Administrator-managed LiteLLM Proxy on OCI Always Free ARM64"

  # Network
  vcn_cidr_block     = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"

  # Compute
  instance_shape      = "VM.Standard.A1.Flex"
  instance_ocpu       = 2
  instance_memory_gb  = 12
  boot_volume_size_gb = 100

  # Tags
  default_tags = {
    Project     = "llm-gateway"
    Environment = "production"
    ManagedBy   = "terramate"
    Owner       = "eslam-aboutaleb"
  }
}

generate_hcl "providers.tf" {
  content {
    provider "oci" {
      region = var.oci_region
    }

    provider "tls" {}

    provider "random" {}

    provider "time" {}
  }
}

generate_hcl "versions.tf" {
  content {
    terraform {
      required_version = ">= 1.12.0"

      required_providers {
        oci = {
          source  = "oracle/oci"
          version = ">= 5.0.0"
        }
        tls = {
          source  = "hashicorp/tls"
          version = ">= 4.0.0"
        }
        random = {
          source  = "hashicorp/random"
          version = ">= 3.0.0"
        }
        time = {
          source  = "hashicorp/time"
          version = ">= 0.9.0"
        }
      }
    }
  }
}

generate_hcl "backend.tf" {
  content {
    terraform {
      backend "oci" {
        key = "${terramate.stack.id}/terraform.tfstate"
      }
    }
  }
}
