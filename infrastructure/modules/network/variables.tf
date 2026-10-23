# Network module variables

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "vcn_cidr_block" {
  description = "VCN CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "public_subnet_dns_label" {
  description = "DNS label for public subnet"
  type        = string
  default     = "public"
}

variable "allow_ssh_from_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "allow_http_acme" {
  description = "Allow HTTP for ACME validation"
  type        = bool
  default     = true
}

variable "allow_https" {
  description = "Allow HTTPS ingress"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}