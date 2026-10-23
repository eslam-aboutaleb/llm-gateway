# Troubleshooting Guide

## Quick Diagnosis

```bash
# System overview via GitHub Actions
gh workflow run smoke-test.yml -f test_type=network

# Service status
docker compose -f /opt/llm-gateway/compose/compose.yaml -f /opt/llm-gateway/compose/compose.prod.yaml ps

# Recent logs
docker compose -f /opt/llm-gateway/compose/compose.yaml -f /opt/llm-gateway/compose/compose.prod.yaml logs --tail=100 --since=1h

# Resource usage
docker stats --no-stream
free -h
df -h /opt/llm-gateway
```

## Common Issues

### High CPU

**Symptoms**: CPU > 80% sustained, slow responses, timeouts

**Diagnosis**:
```bash
# Check which process
top -bn1 | head -20

# Check LiteLLM workers
docker compose exec litellm ps aux

# Check for runaway requests
docker compose logs litellm | grep -i "timeout\|error\|cancel"
```

**Causes & Fixes**:
| Cause | Fix |
|-------|-----|
| Too many concurrent requests | Reduce `max_parallel_requests` per key/team |
| Heavy model (reasoning) | Route to faster alias, add timeout |
| Provider slow, retries piling | Reduce `num_retries`, add circuit breaker |
| No rate limiting | Enable/enforce RPM/TPM limits |
| Memory pressure → GC | Check memory, consider more RAM |

### High Memory

**Symptoms**: Memory > 80%, OOM kills, slow GC

**Diagnosis**:
```bash
# Container memory
docker stats --no-stream

# LiteLLM memory profile
docker compose exec litellm python -c "import tracemalloc; tracemalloc.start(); ..."

# Check for leaks
docker compose logs litellm | grep -i "memory\|oom\|alloc"
```

**Causes & Fixes**:
| Cause | Fix |
|-------|-----|
| Too many workers | Set `NUM_WORKERS=1`, `UVICORN_WORKERS=1` |
| Large context windows | Limit `max_tokens` per request |
| Embedding batch size | Reduce batch size in client |
| Memory leak in version | Upgrade LiteLLM, check release notes |
| Redis memory | Check `maxmemory` policy, reduce cache TTL |

### Disk Full

**Symptoms**: Disk > 85%, writes fail, containers crash

**Diagnosis**:
```bash
df -h
du -sh /opt/llm-gateway/* /var/lib/docker

# Docker disk usage
docker system df
```

**Causes & Fixes**:
| Cause | Fix |
|-------|-----|
| Docker logs unbounded | Check log rotation (10MB×3 default) |
| Old images | `docker image prune -a` |
| Backup accumulation | Check retention, cleanup local `/opt/llm-gateway/backups` |
| PostgreSQL WAL | Check `wal_keep_segments`, replication slots |
| Caddy certificates | Normal, small |
| APT cache | `apt clean` |

### Instance Down

**Symptoms**: No response on 443, SSH fails, OCI Console shows "Stopped"

**Diagnosis**:
```bash
# Check OCI Console
# Instance state: Running/Stopped/Terminated
# Check serial console output

# If Running but unreachable:
# - NSG rules changed?
# - OS firewall (UFW)?
# - Docker/network down?
# - Kernel panic?
```

**Causes & Fixes**:
| Cause | Fix |
|-------|-----|
| OCI Reclaim (Always Free) | Re-provision via Terraform, restore DB |
| OCI Maintenance | Wait, or failover to paid instance |
| Kernel panic/OOM | Check serial console, reboot via Console |
| Network misconfig | Verify NSG, route table, IGW |
| Boot volume full | Resize volume, cleanup |
| Cloud-init failed | Check serial console, re-run |

### API Errors (5xx)

**Symptoms**: Clients receive 500/502/503/504

**Diagnosis**:
```bash
# Check LiteLLM logs
docker compose logs litellm --tail=100 | grep -E "ERROR|500|502|503|504"

# Check upstream provider status
curl -s https://status.openai.com/api/v2/status.json

# Test direct to LiteLLM (via tunnel)
curl -H "Authorization: Bearer $MASTER_KEY" http://localhost:4000/health/readiness
```

**Causes & Fixes**:
| Cause | Fix |
|-------|-----|
| Provider down | Check status page, enable fallback model |
| Provider rate limit (429) | LiteLLM should retry, check `num_retries` |
| Provider timeout | Increase `request_timeout`, check network |
| DB connection pool exhausted | Check PostgreSQL `max_connections` |
| Redis connection failed | Check Redis health, memory |
| Migration in progress | Wait or check `DISABLE_SCHEMA_UPDATE` |
| Invalid provider credentials | Update in LiteLLM Admin UI |

### API Rate Limited (429)

**Symptoms**: Clients receive 429, `Retry-After` header

**Diagnosis**:
```bash
# Check which limit hit
docker compose logs litellm | grep "rate limit\|429"

# Check Redis counters
docker compose exec redis redis-cli --scan --pattern "ratelimit:*" | head -20
```

**Causes & Fixes**:
| Cause | Fix |
|-------|-----|
| Key RPM/TPM exceeded | Increase limit or optimize client |
| Team budget exceeded | Increase budget or reduce usage |
| Global limit exceeded | Increase global limits in config |
| Provider rate limit | LiteLLM should handle, check upstream |
| Burst traffic | Add client-side backoff, queue requests |

### Backup Failed

**Symptoms**: Alert "Backup Stale > 26h", missing backup objects

**Diagnosis**:
```bash
# Check backup timer
systemctl status llm-gateway-backup.timer
systemctl status llm-gateway-backup.service

# Check last run logs
journalctl -u llm-gateway-backup.service -n 50

# Manual test
systemctl start llm-gateway-backup.service
```

**Causes & Fixes**:
| Cause | Fix |
|-------|-----|
| pg_dump fails | Check PostgreSQL connectivity, credentials, disk space |
| age encryption fails | Verify `BACKUP_AGE_PUBLIC_KEY` format |
| OCI upload fails | Check instance principal policy, bucket permissions, quota |
| Timer not running | `systemctl restart llm-gateway-backup.timer` |
| Network issue | Check OCI service gateway / NAT |

### Cert Renewal Failed

**Symptoms**: Alert "Cert Expires < 7d", browser TLS warning

**Diagnosis**:
```bash
# Check Caddy logs
docker compose logs caddy --tail=50 | grep -i "acme\|cert\|tls"

# Test ACME challenge
curl -v http://$DOMAIN/.well-known/acme-challenge/test

# Check certificate
openssl s_client -connect $DOMAIN:443 -servername $DOMAIN < /dev/null | openssl x509 -noout -dates
```

**Causes & Fixes**:
| Cause | Fix |
|-------|-----|
| Port 80 blocked | Verify NSG allows 80, UFW allows 80 |
| DNS not pointing to VM | Update A record |
| Rate limited by Let's Encrypt | Wait, check Caddy logs for retry |
| Caddy config error | Validate Caddyfile, check `tls` block |

### Budget Exceeded

**Symptoms**: Keys return "budget exceeded", spend logs show limit

**Diagnosis**:
```bash
# Check LiteLLM spend logs
docker compose exec postgres psql -U litellm -d litellm -c "SELECT * FROM spend_logs ORDER BY start_time DESC LIMIT 20;"

# Check key budgets
curl -H "Authorization: Bearer $MASTER_KEY" http://localhost:4000/key/list
```

**Causes & Fixes**:
| Cause | Fix |
|-------|-----|
| Legitimate high usage | Increase budget, request approval |
| Runaway script/loop | Revoke key, investigate client |
| Cost estimation wrong | Check `model_info.cost_per_token`, update |
| Provider price change | Update cost estimates in model catalog |

### Slow Provider

**Symptoms**: High latency (p95 > 30s), client timeouts

**Diagnosis**:
```bash
# Check provider latency in logs
docker compose logs litellm | grep "provider.*latency\|upstream.*latency"

# Test direct to provider
time curl -H "Authorization: Bearer $OPENAI_KEY" https://api.openai.com/v1/models
```

**Causes & Fixes**:
| Cause | Fix |
|-------|-----|
| Provider overloaded | Enable fallback model, increase timeout |
| Network latency | Check region proximity, consider proxy |
| Large requests | Reduce `max_tokens`, stream responses |
| Model complexity | Route to faster alias |

### Network Issues

**Symptoms**: Intermittent connectivity, packet loss

**Diagnosis**:
```bash
# Check dropped packets
oci monitoring metric-data get --namespace oci_computeagent --query "NetworkPacketsDropped[5m]{resourceId='$INSTANCE_OCID'}.sum()"

# Test connectivity
ping -c 10 8.8.8.8
traceroute api.openai.com
```

**Causes & Fixes**:
| Cause | Fix |
|-------|-----|
| NSG misconfig | Verify egress rules allow HTTPS, DNS |
| Service Gateway missing | Add service gateway for OCI services |
| DNS issues | Check `/etc/resolv.conf`, use 169.254.169.254 |
| MTU issues | Check VPN/tunnel MTU, set Docker MTU |

### Database Issues

**Symptoms**: Connection errors, migration failures, lock contention

**Diagnosis**:
```bash
# Check PostgreSQL
docker compose exec postgres pg_isready -U litellm

# Check connections
docker compose exec postgres psql -U litellm -d litellm -c "SELECT count(*) FROM pg_stat_activity;"

# Check locks
docker compose exec postgres psql -U litellm -d litellm -c "SELECT * FROM pg_locks WHERE NOT granted;"
```

**Causes & Fixes**:
| Cause | Fix |
|-------|-----|
| Too many connections | Increase `max_connections`, use PgBouncer |
| Long-running query | Check `pg_stat_activity`, kill if needed |
| Migration locked | Wait or cancel, restore from backup |
| Corruption | Restore from backup |

### Redis Issues

**Symptoms**: Rate limiting not working, cache misses, connection errors

**Diagnosis**:
```bash
# Check Redis
docker compose exec redis redis-cli ping

# Check memory
docker compose exec redis redis-cli INFO memory

# Check keys
docker compose exec redis redis-cli --scan --pattern "*" | head -20
```

**Causes & Fixes**:
| Cause | Fix |
|-------|-----|
| Memory full | Increase `maxmemory`, check `maxmemory-policy` |
| Connection refused | Check Redis health, restart container |
| Auth failed | Verify `REDIS_PASSWORD` in env |
| Persistence issues | Check AOF/RDB, disk space |

## Emergency Procedures

### Complete Service Recovery

```bash
# 1. Trigger database restore via GitHub Actions
gh workflow run backup-restore.yml -f operation=restore -f backup_object=litellm-20261023-020000.dump.age

# 2. Restart services via Deploy workflow
gh workflow run deploy.yml -f operation=deploy -f release_tag=v1.0.0

# 3. Verify health and connectivity
gh workflow run smoke-test.yml -f test_type=full
```

### Key Compromise

```bash
# 1. Revoke immediately via Admin Operations workflow
gh workflow run admin-operations.yml -f operation=revoke-key -f key_alias=compromised-key-alias

# 2. Audit usage in PostgreSQL
docker compose exec postgres psql -U litellm -d litellm -c "SELECT * FROM spend_logs WHERE api_key='...' ORDER BY start_time DESC;"

# 3. Issue replacement via Admin Operations workflow
gh workflow run admin-operations.yml -f operation=issue-key -f key_alias=new-key-alias -f team_alias=team_id

### Salt Key Loss (Catastrophic)

**CANNOT RECOVER** - must re-enter all provider credentials:
1. Provision new VM
2. Restore DB from backup (won't help - credentials encrypted)
3. Manually re-enter all provider API keys via Admin UI
4. Rotate master key

**Prevention**: Escrow salt key offline, test recovery quarterly.

## Log Locations

| Component | Location |
|-----------|----------|
| LiteLLM | `docker compose logs litellm` |
| PostgreSQL | `docker compose logs postgres` |
| Redis | `docker compose logs redis` |
| Caddy | `docker compose logs caddy` |
| Node Exporter | `docker compose logs node-exporter` |
| Backup | `journalctl -u llm-gateway-backup.service` |
| System | `journalctl -u llm-gateway.service` |
| Cloud-init | `/var/log/cloud-init-output.log` |

## Useful Commands

```bash
# Restart single service
docker compose restart litellm

# View live logs
docker compose logs -f litellm

# Exec into container
docker compose exec litellm bash
docker compose exec postgres psql -U litellm -d litellm
docker compose exec redis redis-cli

# Check config
docker compose config

# Pull latest images
docker compose pull

# Prune unused
docker system prune -a --volumes

# Check disk
df -h /opt/llm-gateway
docker system df
```

## Escalation Contacts

| Issue | Contact |
|-------|---------|
| Infrastructure | OCI Support (if paid) / Community |
| LiteLLM Bugs | GitHub Issues: berriai/litellm |
| Provider Issues | Provider Support |
| Security | security@domain.com (configure in README) |