# Alarms module variables

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "instance_id" {
  description = "Instance OCID"
  type        = string
}

variable "cpu_utilization_threshold" {
  description = "CPU utilization alarm threshold (%)"
  type        = number
  default     = 80
}

variable "memory_utilization_threshold" {
  description = "Memory utilization alarm threshold (%)"
  type        = number
  default     = 80
}

variable "disk_utilization_warning" {
  description = "Disk utilization warning threshold (%)"
  type        = number
  default     = 75
}

variable "disk_utilization_critical" {
  description = "Disk utilization critical threshold (%)"
  type        = number
  default     = 85
}

variable "alert_webhook_url" {
  description = "Webhook URL for alerts (optional)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}