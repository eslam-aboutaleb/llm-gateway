# Terramate Guide

## Overview

Terramate orchestrates Terraform stacks for the llm-gateway project. It provides:
- Stack management (multiple environments)
- Code generation (provider, backend configs)
- DRY configuration via globals
- Ordered execution across stacks

## Installation

```bash
# macOS
brew install terramate

# Linux
curl -fsSL https://get.terramate.io | bash

# Verify
terramate version
```

## Project Structure

```
llm-gateway/
├── terramate.tm.hcl          # Global configuration
├── infrastructure/
│   ├── stacks/
│   │   └── oci/
│   │       └── production/   # Production stack
│   │           ├── stack.tm.hcl
│   │           ├── main.tf
│   │           ├── variables.tf
│   │           └── outputs.tf
│   └── modules/              # Reusable modules
│       ├── network/
│       ├── compute/
│       ├── storage/
│       ├── identity/
│       └── alarms/
└── cloud-init/
    └── init.yaml.tftpl       # Cloud-init template
```

## Key Concepts

### Globals (`terramate.tm.hcl`)

Shared configuration across all stacks:
- OCI region, tenancy, compartment
- Network CIDR blocks
- Instance shape/size
- Bucket names
- Default tags

### Stacks

Each stack is an independently manageable Terraform workspace:
- `oci-production` - Production gateway on OCI
- Future: `oci-staging`, `aws-production`, etc.

### Code Generation

Terramate generates common files in each stack:
- `providers.tf` - Provider configurations
- `backend.tf` - Backend configuration (OCI native)

### Templates

Cloud-init template rendered with stack-specific values.

## Common Commands

### List Stacks

```bash
terramate list
terramate list --changed  # Only stacks with changes
```

### Format Code

```bash
terramate fmt           # Format all
terramate fmt --check   # Check formatting
```

### Validate Configuration

```bash
terramate validate      # Validate all stacks
terramate validate --stack oci-production
```

### Generate Code

```bash
terramate generate      # Generate providers.tf, backend.tf in each stack
terramate generate --stack oci-production
```

### Run Terraform Commands

```bash
# Run in all stacks
terramate run -- terraform init
terramate run -- terraform validate
terramate run -- terraform plan

# Run in specific stack
terramate run --stack oci-production -- terraform plan

# With arguments
terramate run -- terraform plan -out=tfplan.out
```

### Experimental: Plan All

```bash
terramate run --changed -- terraform plan
```

## Stack Configuration (`stack.tm.hcl`)

```hcl
stack {
  name        = "production"
  description = "Production llm-gateway stack on OCI Always Free"
  id          = "oci-production"
  tags        = ["production", "oci", "arm64", "always-free"]
  # Dependencies on other stacks (future)
  # depends_on = ["oci-network"]
}
```

## Globals Usage

In stack files, access globals via `globals.<name>`:

```hcl
# In main.tf
module "network" {
  vcn_cidr_block = globals.vcn_cidr_block
  # ...
}

# In variables.tf (for validation)
variable "oci_region" {
  default = globals.oci_region
}
```

## Generated Files

After `terramate generate`, each stack gets:

### `providers.tf`
```hcl
terraform {
  required_providers {
    oci = { source = "oracle/oci", version = ">= 5.0.0" }
    tls = { source = "hashicorp/tls", version = ">= 4.0.0" }
    # ...
  }
  required_version = ">= 1.12.0"
}

provider "oci" { region = var.oci_region }
provider "tls" {}
# ...
```

### `backend.tf`
```hcl
terraform {
  backend "oci" {
    bucket     = "tfstate-<tenancy>"
    key        = "oci-production/terraform.tfstate"
    region     = "us-ashburn-1"
    namespace  = "<namespace>"
  }
}
```

## CI/CD Integration

### GitHub Actions

```yaml
- name: Setup Terramate
  uses: terramate-io/terramate-action@v1

- name: Terramate Generate
  run: terramate generate

- name: Terraform Plan (per stack)
  run: |
    terramate run --changed -- terraform plan -out=tfplan.out
```

### Drift Detection

```bash
# Full refresh and plan (not changed-only)
terramate run -- terraform refresh
terramate run -- terraform plan -detailed-exitcode
```

## Best Practices

1. **Keep globals minimal** - Only truly shared values
2. **One stack per environment** - Independent state
3. **Pin provider versions** - In globals and lockfile
4. **Generate, don't duplicate** - Use code generation
5. **Validate before plan** - `terramate validate` in CI
6. **Format consistently** - `terramate fmt` in CI
7. **Check generated files** - Commit generated files or verify in CI
8. **Use stack dependencies** - When stacks must order

## Troubleshooting

### Generation Not Updating
```bash
terramate generate --force
```

### Stack Not Detected
Ensure `stack.tm.hcl` exists in stack directory with valid `stack` block.

### Backend Errors
- Verify OCI Object Storage namespace
- Check bucket exists and versioning enabled
- Ensure instance principal/CI has permissions

### Provider Errors
- Run `terraform init -upgrade` in stack
- Check `.terraform.lock.hcl` committed
- Verify OCI provider version compatibility

## Migration from Plain Terraform

1. Create `terramate.tm.hcl` with globals
2. Move each environment to `infrastructure/stacks/<provider>/<env>/`
3. Add `stack.tm.hcl` to each
4. Move shared modules to `infrastructure/modules/`
5. Extract common provider/backend to globals generation
6. Run `terramate generate` and verify
7. Update CI to use `terramate run`