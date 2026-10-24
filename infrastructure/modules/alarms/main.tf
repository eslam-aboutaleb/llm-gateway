# Alarms module for llm-gateway (OCI Monitoring)

# ===========================================
# Notification Topic
# ===========================================
resource "oci_ons_notification_topic" "alarms" {
  compartment_id = var.compartment_id
  name           = "${var.tags["Project"]}-alarms"
  description    = "Notification topic for gateway alarms"

  freeform_tags = var.tags
}

resource "oci_ons_subscription" "webhook" {
  count = var.alert_webhook_url != "" ? 1 : 0

  compartment_id = var.compartment_id
  topic_id       = oci_ons_notification_topic.alarms.id
  protocol       = "HTTPS"
  endpoint       = var.alert_webhook_url
}

# ===========================================
# CPU Utilization Alarm
# ===========================================
resource "oci_monitoring_alarm" "cpu_high" {
  compartment_id = var.compartment_id
  display_name   = "${var.tags["Project"]}-cpu-high"
  is_enabled     = true
  severity       = "CRITICAL"

  metric_compartment_id            = var.compartment_id
  namespace                        = "oci_computeagent"
  query                            = "CpuUtilization[1m]{resourceId=\"${var.instance_id}\"}.mean() > ${var.cpu_utilization_threshold}"
  pending_duration                 = "PT5M"
  metric_compartment_id_in_subtree = false

  destinations = [oci_ons_notification_topic.alarms.id]

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

  metric_compartment_id            = var.compartment_id
  namespace                        = "oci_computeagent"
  query                            = "MemoryUtilization[1m]{resourceId=\"${var.instance_id}\"}.mean() > ${var.memory_utilization_threshold}"
  pending_duration                 = "PT5M"
  metric_compartment_id_in_subtree = false

  destinations = [oci_ons_notification_topic.alarms.id]

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

  metric_compartment_id            = var.compartment_id
  namespace                        = "oci_computeagent"
  query                            = "DiskUtilization[1m]{resourceId=\"${var.instance_id}\"}.mean() > ${var.disk_utilization_warning}"
  pending_duration                 = "PT5M"
  metric_compartment_id_in_subtree = false

  destinations = [oci_ons_notification_topic.alarms.id]

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

  metric_compartment_id            = var.compartment_id
  namespace                        = "oci_computeagent"
  query                            = "DiskUtilization[1m]{resourceId=\"${var.instance_id}\"}.mean() > ${var.disk_utilization_critical}"
  pending_duration                 = "PT5M"
  metric_compartment_id_in_subtree = false

  destinations = [oci_ons_notification_topic.alarms.id]

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

  metric_compartment_id            = var.compartment_id
  namespace                        = "oci_computeinstance"
  query                            = "InstanceStatus[1m]{resourceId=\"${var.instance_id}\"}.mean() == 0"
  pending_duration                 = "PT5M"
  metric_compartment_id_in_subtree = false

  destinations = [oci_ons_notification_topic.alarms.id]

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

  metric_compartment_id            = var.compartment_id
  namespace                        = "oci_computeagent"
  query                            = "NetworkPacketsDropped[1m]{resourceId=\"${var.instance_id}\"}.sum() > 1000"
  pending_duration                 = "PT5M"
  metric_compartment_id_in_subtree = false

  destinations = [oci_ons_notification_topic.alarms.id]

  freeform_tags = var.tags
}

# ===========================================
# Outputs
# ===========================================
output "notification_topic_id" {
  description = "OCID of the notification topic"
  value       = oci_ons_notification_topic.alarms.id
}

output "alarm_names" {
  description = "Names of created alarms"
  value = [
    oci_monitoring_alarm.cpu_high.display_name,
    oci_monitoring_alarm.memory_high.display_name,
    oci_monitoring_alarm.disk_warning.display_name,
    oci_monitoring_alarm.disk_critical.display_name,
    oci_monitoring_alarm.instance_status.display_name,
    oci_monitoring_alarm.network_dropped.display_name
  ]
}
