# Compute module for llm-gateway (OCI Always Free A1 ARM64)

# ===========================================
# Data Source: Ubuntu ARM64 Image
# ===========================================
data "oci_core_images" "ubuntu_arm64" {
  compartment_id = var.compartment_id
  operating_system = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape = var.instance_shape

  # Filter for ARM64
  filter {
    name   = "architecture"
    values = ["aarch64"]
  }

  # Sort by most recent
  sort_by = "TIMECREATED"
  sort_order = "DESC"
}

# ===========================================
# Instance
# ===========================================
resource "oci_core_instance" "gateway" {
  compartment_id = var.compartment_id
  display_name   = "${var.tags["Project"]}-gateway"
  shape          = var.instance_shape
  shape_config {
    ocpus       = var.instance_ocpu
    memory_in_gbs = var.instance_memory_gb
  }

  # Use the latest Ubuntu 24.04 ARM64 image
  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu_arm64.images[0].id
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    nsg_ids          = var.nsg_ids
    assign_public_ip = true
    hostname_label   = "llm-gw"
  }

  # Cloud-init user data
  metadata = {
    user_data = base64encode(var.cloud_init_template)
    ssh_authorized_keys = var.ssh_public_key
  }

  # Agent configuration
  agent_config {
    is_monitoring_disabled = false
    is_management_disabled = false
    plugins_config = {
      name = "Vulnerability Scanning"
      desired_state = "DISABLED"
    }
  }

  # Free tier eligible
  freeform_tags = merge(var.tags, {
    "AlwaysFreeEligible" = "true"
  })

  # Ensure instance is always free eligible
  availability_config {
    recovery_action = "RESTORE_INSTANCE"
  }
}

# ===========================================
# Boot Volume (separate for clarity)
# ===========================================
resource "oci_core_boot_volume" "gateway" {
  compartment_id = var.compartment_id
  display_name   = "${var.tags["Project"]}-boot"
  size_in_gbs    = var.boot_volume_size_gb
  vpus_per_gb    = 20  # Balanced performance

  freeform_tags = var.tags
}

# Note: Boot volume is attached automatically by instance creation
# The above resource documents the desired size; actual attachment
# is managed by the instance's source_details

# ===========================================
# Outputs
# ===========================================
output "instance_id" {
  description = "OCID of the instance"
  value       = oci_core_instance.gateway.id
}

output "instance_public_ip" {
  description = "Public IP of the instance"
  value       = oci_core_instance.gateway.public_ip
}

output "instance_private_ip" {
  description = "Private IP of the instance"
  value       = oci_core_instance.gateway.private_ip
}

output "instance_shape" {
  description = "Instance shape"
  value       = oci_core_instance.gateway.shape
}

output "image_id_used" {
  description = "Image OCID used for the instance"
  value       = data.oci_core_images.ubuntu_arm64.images[0].id
}

output "boot_volume_id" {
  description = "OCID of the boot volume"
  value       = oci_core_boot_volume.gateway.id
}