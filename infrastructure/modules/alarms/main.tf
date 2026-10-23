# Alarms module for llm-gateway (OCI Monitoring)

# ===========================================
# Notification Topic (if webhook provided)
# ===========================================
resource "oci_ons_notification_topic" "alarms" {
  count = var.alert_webhook_url != "" ? 1 : 0

  compartment_id = var.compartment_id
  name           = "${var.tags["Project"]}-alarms"
  description    = "Notification topic for gateway alarms"

  freeform_tags = var.tags
}

resource "oci_ons_subscription" "webhook" {
  count = var.alert_webhook_url != "" ? 1 : 0

  compartment_id = var.compartment_id
  topic_id       = oci_ons_notification_topic.alarms[0].id
  protocol       = "HTTPS"
  endpoint       = var.alert_webhook_url
  description    = "Webhook subscription for alarms"
}

# ===========================================
# CPU Utilization Alarm
# ===========================================
resource "oci_monitoring_alarm" "cpu_high" {
  compartment_id = var.compartment_id
  display_name   = "${var.tags["Project"]}-cpu-high"
  is_enabled     = true
  severity       = "CRITICAL"

  metric_compartment_id = var.compartment_id
  namespace             = "oci_computeagent"
  query                 = "CpuUtilization[1m]{resourceId=\"${var.instance_id}\"}.mean() > ${var.cpu_utilization_threshold}"

  destinations = var.alert_webhook_url != "" ? [oci_ons_notification_topic.alarms[0].id] : []

  freeform_tags = var.tags
}

# ===========================================
# Memory Utilization Alarm
# ===========================================
resource "oci_monitoring_alarm" "memory_high" {
  compartment_id = var.compartment_id
  display_name   = "${var.tags["Project"]}-memory-high"
  is_enabled     = true
  severity       = "CRITICAL"

  metric_compartment_id = var.compartment_id
  namespace             = "oci_computeagent"
  query                 = "MemoryUtilization[1m]{resourceId=\"${var.instance_id}\"}.mean() > ${var.memory_utilization_threshold}"

  destinations = var.alert_webhook_url != "" ? [oci_ons_notification_topic.alarms[0].id] : []

  freeform_tags = var.tags
}

# ===========================================
# Disk Utilization Warning Alarm
# ===========================================
resource "oci_monitoring_alarm" "disk_warning" {
  compartment_id = var.compartment_id
  display_name   = "${var.tags["Project"]}-disk-warning"
  is_enabled     = true
  severity       = "WARNING"

  metric_compartment_id = var.compartment_id
  namespace             = "oci_computeagent"
  query                 = "DiskUtilization[1m]{resourceId=\"${var.instance_id}\"}.mean() > ${var.disk_utilization_warning}"

  destinations = var.alert_webhook_url != "" ? [oci_ons_notification_topic.alarms[0].id] : []

  freeform_tags = var.tags
}

# ===========================================
# Disk Utilization Critical Alarm
# ===========================================
resource "oci_monitoring_alarm" "disk_critical" {
  compartment_id = var.compartment_id
  display_name   = "${var.tags["Project"]}-disk-critical"
  is_enabled     = true
  severity       = "CRITICAL"

  metric_compartment_id = var.compartment_id
  namespace             = "oci_computeagent"
  query                 = "DiskUtilization[1m]{resourceId=\"${var.instance_id}\"}.mean() > ${var.disk_utilization_critical}"

  destinations = var.alert_webhook_url != "" ? [oci_ons_notification_topic.alarms[0].id] : []

  freeform_tags = var.tags
}

# ===========================================
# Instance Status Alarm
# ===========================================
resource "oci_monitoring_alarm" "instance_status" {
  compartment_id = var.compartment_id
  display_name   = "${var.tags["Project"]}-instance-status"
  is_enabled     = true
  severity       = "CRITICAL"

  metric_compartment_id = var.compartment_id
  namespace             = "oci_computeinstance"
  query                 = "InstanceStatus[1m]{resourceId=\"${var.instance_id}\"}.mean() == 0"

  destinations = var.alert_webhook_url != "" ? [oci_ons_notification_topic.alarms[0].id] : []

  freeform_tags = var.tags
}

# ===========================================
# Network Packets Dropped Alarm (potential attack)
# ===========================================
resource "oci_monitoring_alarm" "network_dropped" {
  compartment_id = var.compartment_id
  display_name   = "${var.tags["Project"]}-network-dropped"
  is_enabled     = true
  severity       = "WARNING"

  metric_compartment_id = var.compartment_id
  namespace             = "oci_computeagent"
  query                 = "NetworkPacketsDropped[1m]{resourceId=\"${var.instance_id}\"}.sum() > 1000"

  destinations = var.alert_webhook_url != "" ? [oci_ons_notification_topic.alarms[0].id] : []

  freeform_tags = var.tags
}

# ===========================================
# Outputs
# ===========================================
output "notification_topic_id" {
  description = "OCID of the notification topic"
  value       = try(oci_ons_notification_topic.alarms[0].id, "")
}

output "alarm_names" {
  description = "Names of created alarms"
  value       = [
    oci_monitoring_alarm.cpu_high.display_name,
    oci_monitoring_alarm.memory_high.display_name,
    oci_monitoring_alarm.disk_warning.display_name,
    oci_monitoring_alarm.disk_critical.display_name,
    oci_monitoring_alarm.instance_status.display_name,
    oci_monitoring_alarm.network_dropped.display_name
  ]
}