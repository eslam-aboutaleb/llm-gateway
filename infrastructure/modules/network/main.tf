# Network module for llm-gateway

# ===========================================
# VCN
# ===========================================
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_id
  cidr_block     = var.vcn_cidr_block
  dns_label      = "llmgw"
  display_name   = "${var.tags["Project"]}-vcn"

  freeform_tags = var.tags
}

# ===========================================
# Internet Gateway
# ===========================================
resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.tags["Project"]}-igw"
  enabled        = true

  freeform_tags = var.tags
}

# ===========================================
# Route Table
# ===========================================
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.tags["Project"]}-public-rt"

  route_rules {
    network_entity_id = oci_core_internet_gateway.main.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }

  freeform_tags = var.tags
}

# ===========================================
# Security List (backup to NSG)
# ===========================================
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.tags["Project"]}-public-sl"

  # SSH (restricted)
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.allow_ssh_from_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false
    tcp_options {
      min = 22
      max = 22
    }
    description = "SSH from admin CIDR"
  }

  # HTTP for ACME
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    tcp_options {
      min = 80
      max = 80
    }
    description = "HTTP for ACME validation"
  }

  # HTTPS
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    tcp_options {
      min = 443
      max = 443
    }
    description = "HTTPS for inference API"
  }

  # Allow all outbound
  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    stateless        = false
    description      = "Allow all outbound"
  }

  freeform_tags = var.tags
}

# ===========================================
# Public Subnet
# ===========================================
resource "oci_core_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  cidr_block     = var.public_subnet_cidrs[count.index]
  dns_label      = "${var.public_subnet_dns_label}${count.index > 0 ? count.index + 1 : ""}"
  display_name   = "${var.tags["Project"]}-public-subnet${count.index > 0 ? count.index + 1 : ""}"

  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  dhcp_options_id            = oci_core_vcn.main.default_dhcp_options_id
  prohibit_public_ip_on_vnic = false

  freeform_tags = merge(var.tags, { SubnetIndex = count.index })
}

# ===========================================
# Network Security Group for Instance
# ===========================================
resource "oci_core_network_security_group" "instance" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.tags["Project"]}-instance-nsg"

  freeform_tags = var.tags
}

# SSH from admin CIDR
resource "oci_core_network_security_group_security_rule" "ssh" {
  network_security_group_id = oci_core_network_security_group.instance.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.allow_ssh_from_cidr
  source_type               = "CIDR_BLOCK"
  stateless                 = false
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
  description = "SSH from admin CIDR"
}

# HTTP for ACME
resource "oci_core_network_security_group_security_rule" "http" {
  network_security_group_id = oci_core_network_security_group.instance.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  stateless                 = false
  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
  description = "HTTP for ACME validation"
}

# HTTPS
resource "oci_core_network_security_group_security_rule" "https" {
  network_security_group_id = oci_core_network_security_group.instance.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  stateless                 = false
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
  description = "HTTPS for inference API"
}

# Allow all outbound
resource "oci_core_network_security_group_security_rule" "egress" {
  network_security_group_id = oci_core_network_security_group.instance.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  stateless                 = false
  description               = "Allow all outbound"
}

# ===========================================
# Outputs
# ===========================================
output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.main.id
}

output "internet_gateway_id" {
  description = "OCID of the Internet Gateway"
  value       = oci_core_internet_gateway.main.id
}

output "public_subnet_id" {
  description = "OCID of the primary public subnet"
  value       = oci_core_subnet.public[0].id
}

output "public_subnet_ids" {
  description = "OCIDs of all public subnets"
  value       = oci_core_subnet.public[*].id
}

output "public_route_table_id" {
  description = "OCID of the public route table"
  value       = oci_core_route_table.public.id
}

output "instance_nsg_id" {
  description = "OCID of the instance NSG"
  value       = oci_core_network_security_group.instance.id
}

output "security_list_id" {
  description = "OCID of the public security list"
  value       = oci_core_security_list.public.id
}