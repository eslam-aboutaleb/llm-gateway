generate_hcl "versions.tf" {
  content {
    terraform {
      required_version = ">= 1.12.0"
      required_providers {
        oci = {
          source  = "oracle/oci"
          version = ">= 5.0.0"
        }
        random = {
          source  = "hashicorp/random"
          version = ">= 3.0.0"
        }
        time = {
          source  = "hashicorp/time"
          version = ">= 0.9.0"
        }
        tls = {
          source  = "hashicorp/tls"
          version = ">= 4.0.0"
        }
      }
    }
  }
}

generate_hcl "providers.tf" {
  content {
    provider "oci" {
      region = var.oci_region
    }
    provider "tls" {
    }
    provider "random" {
    }
    provider "time" {
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
