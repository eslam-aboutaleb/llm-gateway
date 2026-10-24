# OCI Bootstrap Guide

## Prerequisites

- Oracle Cloud account with Always Free eligibility
- OCI CLI configured with admin credentials
- Domain name for gateway (e.g., `llm.example.com`)
- GitHub repository for this project

## One-Time Bootstrap Procedure

### 1. Verify Region and Quotas

```bash
# Check Always Free availability in home region
oci iam region-subscription list --profile DEFAULT

# Verify A1 shape quota
oci compute shape list --compartment-id $COMPARTMENT_OCID --profile DEFAULT | grep VM.Standard.A1.Flex

# Check block volume quota (100 GB for boot)
oci limits limit-definition get --service-name block-storage --limit-name totalBootVolumeSizeGB --compartment-id $COMPARTMENT_OCID
```

### 2. Create Compartment (Optional)

```bash
oci iam compartment create \
  --name llm-gateway \
  --description "Compartment for llm-gateway resources" \
  --compartment-id $TENANCY_OCID
```

### 3. Create Object Storage Buckets

```bash
NAMESPACE=$(oci os ns get --profile DEFAULT --query "data" --raw)

# Terraform state bucket
oci os bucket create --namespace $NAMESPACE --name tfstate-$TENANCY_OCID \
  --compartment-id $COMPARTMENT_OCID --versioning Enabled --public-access-type NoPublicAccess

# Backup bucket
oci os bucket create --namespace $NAMESPACE --name backups-$TENANCY_OCID \
  --compartment-id $COMPARTMENT_OCID --versioning Enabled --public-access-type NoPublicAccess

# Release bucket
oci os bucket create --namespace $NAMESPACE --name releases-$NAMESPACE \
  --compartment-id $COMPARTMENT_OCID --versioning Enabled --public-access-type NoPublicAccess
```

### 4. Configure Terraform Backend

```bash
# The backend is configured in terramate.tm.hcl
# Uses OCI native backend (Terraform 1.12+)
```

### 5. Set Up GitHub OIDC Federation

```bash
# Create OIDC Identity Provider for GitHub
oci iam identity-provider create \
  --compartment-id $COMPARTMENT_OCID \
  --name github-oidc \
  --description "GitHub Actions OIDC" \
  --product-type OIDC \
  --provider-url "https://token.actions.githubusercontent.com"

# Get the provider OCID
PROVIDER_OCID=$(oci iam identity-provider list --compartment-id $COMPARTMENT_OCID --query "data[?name=='github-oidc'].id" --raw)

# Create mapping for this repository
oci iam identity-provider-group create \
  --identity-provider-id $PROVIDER_OCID \
  --group-name llm-gateway-github-actions \
  --condition "claims.repository == 'eslam-aboutaleb/llm-gateway' && claims.ref == 'refs/heads/main'"

# Create policy for GitHub Actions
oci iam policy create \
  --compartment-id $COMPARTMENT_OCID \
  --name github-actions-policy \
  --description "Allow GitHub Actions to manage llm-gateway infrastructure" \
  --statements '[
    "Allow group llm-gateway-github-actions to read compartments in tenancy",
    "Allow group llm-gateway-github-actions to manage vcns in compartment id '$COMPARTMENT_OCID'",
    "Allow group llm-gateway-github-actions to manage subnets in compartment id '$COMPARTMENT_OCID'",
    "Allow group llm-gateway-github-actions to manage instances in compartment id '$COMPARTMENT_OCID'",
    "Allow group llm-gateway-github-actions to manage buckets in compartment id '$COMPARTMENT_OCID'",
    "Allow group llm-gateway-github-actions to manage objects in compartment id '$COMPARTMENT_OCID'",
    "Allow group llm-gateway-github-actions to manage dynamic-groups in compartment id '$COMPARTMENT_OCID'",
    "Allow group llm-gateway-github-actions to manage policies in compartment id '$COMPARTMENT_OCID'"
  ]'
```

### 6. Run Bootstrap Stack

```bash
cd infrastructure/bootstrap
terraform init
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
```

### 7. Import Bootstrap Resources into Main Stack

```bash
cd ../stacks/oci/production
terraform init

# Import state bucket
terraform import oci_objectstorage_bucket.tfstate $NAMESPACE/tfstate-$TENANCY_OCID

# Import backup bucket
terraform import oci_objectstorage_bucket.backups $NAMESPACE/backups-$TENANCY_OCID
```

### 8. Configure DNS

Create A record for your gateway domain pointing to the instance public IP (after first apply).

### 9. Configure Secrets & First Deployment

Configure required repository variables and secrets in GitHub Secrets or OCI Vault (`LITELLM_MASTER_KEY`, `LITELLM_SALT_KEY`, `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `LITELLM_UI_PASSWORD`, `BACKUP_AGE_PUBLIC_KEY`).

### 10. First Deployment

Trigger the infrastructure plan and apply via GitHub Actions (`infra-plan.yml` and `infra-apply.yml`).

## Recovery Procedures

### State Recovery

```bash
# List state versions
oci os object list --namespace $NAMESPACE --bucket-name tfstate-$TENANCY_OCID --prefix production/

# Restore previous state
oci os object get --namespace $NAMESPACE --bucket-name tfstate-$TENANCY_OCID --name production/terraform.tfstate --version-id <version-id> --file terraform.tfstate
```

### Identity Recovery

If OIDC federation breaks:
1. Use admin OCI CLI credentials to recreate identity provider
2. Update GitHub Actions workflow with new provider URL
3. Re-run bootstrap federation steps

## Verification Checklist

- [ ] Terraform state bucket exists, versioned, encrypted
- [ ] Backup bucket exists, versioned, lifecycle configured
- [ ] Release bucket exists, versioned, lifecycle configured
- [ ] GitHub OIDC provider created and mapped to repository
- [ ] GitHub Actions can authenticate and plan
- [ ] State locking works (concurrent plans blocked)
- [ ] Budget alerts configured in OCI Console
- [ ] DNS domain registered and controllable