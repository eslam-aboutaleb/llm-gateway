# Backup and Restore Guide

## Backup Strategy

### What Gets Backed Up

| Asset | Method | Frequency | Retention |
|-------|--------|-----------|-----------|
| PostgreSQL | `pg_dump` custom format + age encryption | Daily (2 AM ±1hr) | 7 daily + 4 weekly |
| Model Config | Included in release manifest | Per release | 180 days (releases bucket) |
| Terraform State | OCI Object Storage versioning | Every apply | 90 days |
| Caddy Certificates | Auto-renewed by Let's Encrypt | N/A | Re-issuable |
| Secrets | **NOT backed up** - escrowed separately | N/A | Offline |

### Backup Flow

```
Daily systemd timer (llm-gateway-backup.timer)
    │
    ▼
backup-postgres.sh (runs in backup container)
    │
    ├─► pg_dump --format=custom --compress=6
    │
    ├─► age -r $BACKUP_AGE_PUBLIC_KEY (encrypt)
    │
    ├─► SHA256 checksum
    │
    ├─► Upload to OCI Object Storage (instance principal)
    │
    ├─► Verify remote object (MD5)
    │
    ├─► Create manifest (JSON with metadata)
    │
    └─► Upload manifest
    │
    ▼
Local cleanup (unencrypted dump removed)
OCI lifecycle policy (retention)
```

### Encryption

- **Algorithm**: age (modern, simple, secure)
- **Public Key**: Stored in VM (`BACKUP_AGE_PUBLIC_KEY` env)
- **Private Key**: **OFFLINE ONLY** - USB drive, password manager, printed QR
- **Key Rotation**: Generate new keypair, re-encrypt recent backups

## Backup Script (`backup-postgres.sh`)

### Environment Variables (from `/opt/llm-gateway/config/backup.env`)

```bash
PGHOST=postgres
PGPORT=5432
PGDATABASE=litellm
PGUSER=litellm
PGPASSWORD_FILE=/run/secrets/postgres_password
BACKUP_AGE_PUBLIC_KEY=age1...
OCI_OBJECT_STORAGE_NAMESPACE=...
OCI_BACKUP_BUCKET=backups-...
```

### Output

- Encrypted dump: `litellm-YYYYMMDD-HHMMSS.dump.age`
- Manifest: `litellm-YYYYMMDD-HHMMSS.manifest.json`

### Manifest Format

```json
{
  "timestamp": "2026-10-23T02:00:00Z",
  "backup_file": "litellm-20261023-020000.dump.age",
  "original_size_bytes": 12345678,
  "original_sha256": "abc123...",
  "encrypted_size_bytes": 12345678,
  "encrypted_sha256": "def456...",
  "encryption": "age",
  "age_public_key": "age1...",
  "database": "litellm",
  "schema_version": "litellm-auto",
  "status": "completed"
}
```

## Verification

### Automated & Scheduled Verification

Verification runs on schedule or via GitHub Actions dispatch:

```bash
gh workflow run backup-restore.yml -f operation=verify
```

Checks:
- Backup object exists in OCI Object Storage (< 26 hours old)
- Remote backup is readable and matches encryption requirements

## Restore Procedure

Restores are orchestrated via the `Backup & Restore` workflow (`.github/workflows/backup-restore.yml`):

```bash
gh workflow run backup-restore.yml \
  -f operation=restore \
  -f backup_object=litellm-20261023-020000.dump.age \
  -f target_db=litellm
```

### What It Does

1. Downloads encrypted backup from OCI Object Storage via instance principal
2. Decrypts with configured age private key (from secret store / OCI Vault)
3. Verifies dump integrity with `pg_restore --list`
4. Restores to target PostgreSQL database
5. Verifies schema and row consistency

## Disaster Recovery Drill

### Quarterly Full Drill

1. **Provision new A1 instance** (or paid fallback)
2. **Restore Terraform state** from Object Storage
3. **Run `terraform apply`** to recreate infrastructure
4. **Retrieve age private key** from offline storage
5. **Download latest backup** from Object Storage
6. **Decrypt and restore PostgreSQL**
7. **Run migrations** if schema version differs
8. **Deploy pinned LiteLLM release**
9. **Verify virtual key authentication**
10. **Test chat/embeddings** with mock provider
11. **Remap DNS** to new instance
12. **Verify end-to-end functionality**
13. **Document RTO/RPO actuals**
14. **Clean up drill resources**

### Targets

| Metric | Target | Notes |
|--------|--------|-------|
| RPO | 24 hours | Daily backups |
| RTO | 4 hours | Best effort, not SLA |

### Drill Checklist

See `.github/workflows/disaster-recovery-test.yml` for automated weekly synthetic test.

## Retention Policy

### OCI Object Storage Lifecycle

```hcl
# Backup bucket: 30 days
rule {
  name        = "retain-backups-30d"
  action      = "DELETE"
  time_amount = 30
  time_unit   = "DAYS"
}

# TF State bucket: 90 days
rule {
  name        = "retain-versions-90d"
  action      = "DELETE"
  time_amount = 90
  time_unit   = "DAYS"
}

# Releases bucket: 180 days
rule {
  name        = "retain-releases-180d"
  action      = "DELETE"
  time_amount = 180
  time_unit   = "DAYS"
}
```

### Quota Management

- **Always Free Object Storage**: 20 GB total (all buckets combined)
- Monitor aggregate usage via OCI Console or CLI
- Alert at 75% (15 GB) and 85% (17 GB)
- Never prune last verified working recovery point

## Secret Escrow

### Critical Secrets (Must Be Recoverable Offline)

| Secret | Storage | Recovery |
|--------|---------|----------|
| `LITELLM_SALT_KEY` | Password manager, printed, USB | Required for DB decryption |
| `LITELLM_MASTER_KEY` | Password manager | Admin API access |
| Age Private Key | **Offline only** (USB, paper) | Backup decryption |
| Provider API Keys | Provider consoles | Re-enter in LiteLLM |

### Escrow Procedure

1. Generate secrets via `bootstrap-secrets.sh`
2. Store in password manager (1Password, Bitwarden, etc.)
3. Export to encrypted USB drive
4. Print QR codes for age private key and salt key
5. Store in physical safe
6. Document location in runbook
7. Test recovery quarterly

## Monitoring Backup Health

### Alerts

| Condition | Severity | Action |
|-----------|----------|--------|
| Backup > 26 hours old | Critical | Investigate backup job |
| Backup upload failed | Critical | Check OCI credentials/quota |
| Backup size < 1 MB | Warning | Verify pg_dump worked |
| Object Storage > 75% | Warning | Clean old versions |
| Object Storage > 85% | Critical | Immediate cleanup |

### Dashboard Queries

```sql
-- Backup freshness (OCI Monitoring)
SELECT timeCreated FROM objects WHERE bucket='backups' AND name LIKE 'litellm-%' ORDER BY timeCreated DESC LIMIT 1

-- Backup size trend
SELECT SUM(size) FROM objects WHERE bucket='backups' GROUP BY DATE(timeCreated)
```

## Troubleshooting

| Issue | Resolution |
|-------|------------|
| `pg_dump` fails | Check PostgreSQL connectivity, credentials, disk space |
| age encryption fails | Verify public key format, check file permissions |
| OCI upload fails | Check instance principal policy, bucket permissions, quota |
| Manifest missing | Re-run backup, check script logs |
| Restore fails | Verify age private key matches, check dump integrity |
| Schema mismatch | Run migrations after restore, or restore compatible backup |