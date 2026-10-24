# Monitoring and Alerting Guide

## Monitoring Philosophy

- **Lightweight**: No heavy stacks (Grafana, Prometheus, Tempo) on 12 GB VM
- **Native First**: OCI Monitoring + lightweight host scripts
- **Actionable**: Every alert has a runbook link
- **Privacy**: No PII, prompts, keys, or credentials in metrics/logs

## Metrics Collection

### OCI Native Metrics (No Agent Required)

| Metric | Namespace | Dimensions | Use Case |
|--------|-----------|------------|----------|
| CPU Utilization | `oci_computeagent` | `resourceId` | Capacity, scaling |
| Memory Utilization | `oci_computeagent` | `resourceId` | OOM risk |
| Disk Utilization | `oci_computeagent` | `resourceId` | Disk full |
| Network Packets Dropped | `oci_computeagent` | `resourceId` | Attack detection |
| Instance Status | `oci_computeinstance` | `resourceId` | Reclaim/health |

### Host-Level (Node Exporter)

Port 9100 (internal only):
- `node_cpu_seconds_total`
- `node_memory_MemAvailable_bytes`
- `node_filesystem_avail_bytes`
- `node_network_receive_bytes_total`
- `node_disk_read_bytes_total`

### Application-Level (LiteLLM)

Port 4000 (internal only, `/metrics` if enabled):
- Request rate, latency, errors
- Token usage (prompt/completion)
- Budget utilization
- Key/team spend
- Provider latency/errors
- Cache hit rate

### Infrastructure (Caddy)

Port 2019 (disabled in production):
- Request count, latency, status codes
- TLS certificate expiry

## Alert Rules

### Critical Alerts (Page Immediately)

| Alert | Condition | Runbook |
|-------|-----------|---------|
| `CPU > 80%` sustained 5m | `CpuUtilization[5m].mean() > 80` | [High CPU](TROUBLESHOOTING.md#high-cpu) |
| `Memory > 80%` sustained 5m | `MemoryUtilization[5m].mean() > 80` | [High Memory](TROUBLESHOOTING.md#high-memory) |
| `Disk > 85%` | `DiskUtilization[1m].mean() > 85` | [Disk Full](TROUBLESHOOTING.md#disk-full) |
| `Instance Down` | `InstanceStatus[1m].mean() == 0` | [Instance Down](TROUBLESHOOTING.md#instance-down) |
| `API 5xx > 5%` | `rate(http_requests_total{status=~"5.."}[5m]) > 0.05` | [API Errors](TROUBLESHOOTING.md#api-errors) |
| `Backup Stale > 26h` | Custom check | [Backup Failed](TROUBLESHOOTING.md#backup-failed) |
| `Cert Expires < 7d` | Custom check | [Cert Renewal](TROUBLESHOOTING.md#cert-renewal) |

### Warning Alerts (Ticket During Business Hours)

| Alert | Condition | Runbook |
|-------|-----------|---------|
| `Disk > 75%` | `DiskUtilization[1m].mean() > 75` | [Disk Warning](TROUBLESHOOTING.md#disk-warning) |
| `API 429 Spike` | `rate(http_requests_total{status="429"}[5m]) > 10` | [Rate Limited](TROUBLESHOOTING.md#rate-limited) |
| `Provider Latency p95 > 30s` | Custom | [Slow Provider](TROUBLESHOOTING.md#slow-provider) |
| `Spend > 80% Budget` | Custom (LiteLLM webhook) | [Budget Alert](TROUBLESHOOTING.md#budget-exceeded) |
| `Network Packets Dropped > 1000/m` | `NetworkPacketsDropped[1m].sum() > 1000` | [Network Issues](TROUBLESHOOTING.md#network-issues) |

### Info Alerts (Log Only)

- New deployment detected
- Configuration change
- Key created/revoked
- Certificate renewed

## Alert Channels

### Primary: Webhook (Slack/PagerDuty/Email)

Configured via `ALERT_WEBHOOK_URL` variable.

Payload format:
```json
{
  "alert": "High CPU",
  "severity": "critical",
  "resource": "ocid1.instance...",
  "value": 85,
  "threshold": 80,
  "timestamp": "2026-10-23T12:00:00Z",
  "runbook": "https://github.com/eslam-aboutaleb/llm-gateway/blob/main/docs/TROUBLESHOOTING.md#high-cpu"
}
```

### Secondary: OCI Console

Alarms visible in OCI Monitoring > Alarm Definitions.

## Log Management

### Structured Logging

LiteLLM logs (JSON):
```json
{
  "timestamp": "2026-10-23T12:00:00Z",
  "level": "INFO",
  "request_id": "req_abc123",
  "key_hash": "sha256:abc...",
  "team_id": "team_123",
  "model": "general-fast",
  "provider": "openai",
  "status": 200,
  "latency_ms": 1250,
  "prompt_tokens": 150,
  "completion_tokens": 80,
  "estimated_cost_usd": 0.00045
}
```

### Redacted Fields

NEVER logged:
- `prompt` / `messages` content
- `response` content
- `api_key` values
- `Authorization` headers
- PII (emails, names, IDs)

### Retention

- Docker JSON logs: 10 MB × 3 files per container
- Systemd journal: 7 days
- OCI Logging (if enabled): 30 days

### Access

- Admin only via SSH
- `journalctl -u llm-gateway -f`
- `docker compose logs -f litellm`

## Synthetic Monitoring

### External Health Check

```bash
# Runs every 5 minutes from external location
curl -sf --max-time 10 https://$DOMAIN/health
```

Checks:
- DNS resolves
- TLS valid
- Caddy responds
- LiteLLM readiness endpoint returns 200

### API Contract Tests

```bash
# Runs via GitHub Actions Smoke Test workflow
gh workflow run smoke-test.yml -f test_type=smoke
```

## Dashboards (Future)

When resources allow, deploy off-VM:
- Grafana Cloud (free tier)
- Datadog (if licensed)
- Custom lightweight dashboard

Metrics shipped via:
- OCI Monitoring → Grafana Cloud Prometheus
- Or Prometheus remote write to hosted TSDB

## Cost Monitoring

### Monthly Review

1. OCI Console > Cost Analysis > Always Free usage
2. LiteLLM spend logs vs provider bills
3. Budget alerts vs actuals
4. Adjust limits based on usage patterns

### Provider Bills

- OpenAI: Platform > Usage
- Anthropic: Console > Billing
- Azure: Cost Management
- Set provider-side hard limits as backup

## Runbook Links

Each alert includes link to relevant section in [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Testing Alerts

```bash
# Test webhook
curl -X POST $ALERT_WEBHOOK_URL -H "Content-Type: application/json" -d '{"test": true}'

# Simulate high CPU
stress-ng --cpu 4 --timeout 300

# Simulate disk full
dd if=/dev/zero of=/tmp/fill bs=1G count=10
```

## On-Call Rotation

- Primary: Repository owner
- Secondary: Documented in README
- Escalation: Provider support contacts