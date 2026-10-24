# Production stack main configuration

# Local values for naming consistency
locals {
  resource_prefix = "llm-gw"
  compartment_id  = var.oci_compartment_ocid
}

# ===========================================
# Network Module
# ===========================================
module "network" {
  source = "../../../modules/network"

  compartment_id = local.compartment_id
  vcn_cidr_block = "10.0.0.0/16"

  public_subnet_cidrs     = ["10.0.1.0/24"]
  public_subnet_dns_label = "public"

  # NSG rules
  allow_ssh_from_cidr = "0.0.0.0/0" # Restrict in production!
  allow_http_acme     = true
  allow_https         = true

  tags = merge(var.default_tags, {
    Layer = "network"
  })
}

# ===========================================
# Compute Module
# ===========================================
module "compute" {
  source = "../../../modules/compute"

  compartment_id = local.compartment_id
  subnet_id      = module.network.public_subnet_id
  nsg_ids        = [module.network.instance_nsg_id]

  instance_shape      = "VM.Standard.A1.Flex"
  instance_ocpu       = 2
  instance_memory_gb  = 12
  boot_volume_size_gb = 100

  ssh_public_key = var.oci_ssh_public_key

  # Cloud-init template rendered with instance variables
  cloud_init_template = templatefile("${path.module}/../../../../cloud-init/init.yaml.tftpl", {
    oci_ssh_public_key = var.oci_ssh_public_key
    distro_id          = "$${distro_id}"
    distro_codename    = "$${distro_codename}"
  })

  tags = merge(var.default_tags, {
    Layer = "compute"
  })
}

# ===========================================
# Storage Module
# ===========================================
module "storage" {
  source = "../../../modules/storage"

  compartment_id = local.compartment_id
  namespace      = var.oci_object_storage_namespace

  tfstate_bucket_name = "tfstate-${var.oci_object_storage_namespace}"
  backup_bucket_name  = "backups-${var.oci_object_storage_namespace}"

  tags = merge(var.default_tags, {
    Layer = "storage"
  })
}

# ===========================================
# Identity Module (Dynamic Groups, Policies)
# ===========================================
module "identity" {
  source = "../../../modules/identity"

  compartment_id = local.compartment_id
  instance_id    = module.compute.instance_id

  # Instance principal permissions
  allow_tfstate_bucket_access = true
  allow_backup_bucket_access  = true
  allow_release_bucket_access = true

  # GitHub Actions OIDC
  github_repository     = var.github_repository
  oci_oidc_provider_url = var.oci_oidc_provider_url

  tags = merge(var.default_tags, {
    Layer = "identity"
  })
}

# ===========================================
# Alarms Module
# ===========================================
module "alarms" {
  source = "../../../modules/alarms"

  compartment_id = local.compartment_id
  instance_id    = module.compute.instance_id

  # Alarm thresholds
  cpu_utilization_threshold    = 80
  memory_utilization_threshold = 80
  disk_utilization_warning     = 75
  disk_utilization_critical    = 85

  # Notification topic (create if webhook provided)
  alert_webhook_url = var.alert_webhook_url

  tags = merge(var.default_tags, {
    Layer = "monitoring"
  })
}