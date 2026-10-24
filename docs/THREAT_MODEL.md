# Threat Model

## Assets

| Asset | Classification | Location |
|-------|----------------|----------|
| LiteLLM Master Key | Critical (Secret) | Operator secret store, VM memory |
| LiteLLM Salt Key | Critical (Secret) | Operator secret store, VM memory |
| PostgreSQL Credentials | High (Secret) | Docker secret, VM memory |
| Redis Password | High (Secret) | Docker secret, VM memory |
| Upstream Provider API Keys | High (Secret) | Encrypted in PostgreSQL, VM memory |
| Virtual API Keys | Medium (Secret) | Encrypted in PostgreSQL |
| User/Team Metadata | Medium (PII) | PostgreSQL |
| Spend/Usage Logs | Medium (Business) | PostgreSQL |
| TLS Certificates | Medium | Caddy data volume |
| Terraform State | Medium | OCI Object Storage (versioned, encrypted) |

## Trust Boundaries

```
┌─────────────────────────────────────────────────────────────┐
│                      INTERNET                                │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTPS 443 (Allowlist)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                     CADDY (TLS Termination)                  │
│  - Route allowlist: /v1/chat/completions, /v1/embeddings,   │
│    /v1/models, /health, /status                             │
│  - Deny: /ui, /key/*, /team/*, /config/*, /spend/*, etc.   │
└──────────────────────────┬──────────────────────────────────┘
                           │ Private Compose Network
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    LITELLM PROXY (127.0.0.1:4000)            │
│  - Virtual key authentication                                │
│  - Rate limiting (Redis)                                     │
│  - Budget enforcement (PostgreSQL)                           │
│  - Provider credential decryption (Salt Key)                 │
└──────────────────────────┬──────────────────────────────────┘
          ┌──────────────────┴──────────────────┐
          ▼                                     ▼
┌─────────────────────────┐         ┌─────────────────────────┐
│    POSTGRESQL           │         │        REDIS            │
│  (Keys, Teams, Budgets, │         │ (Rate Counters, Cache,  │
│   Spend Logs, Audit)    │         │  Router State)          │
└─────────────────────────┘         └─────────────────────────┘
```

## Threat Scenarios

### T1: Unauthorized API Access
**Threat**: Attacker obtains or guesses a virtual key
**Impact**: Unauthorized model usage, budget exhaustion
**Mitigations**:
- Keys are 256-bit random, unguessable
- Rate limits per key (RPM/TPM/concurrent)
- Budget limits per key/team
- Key expiry enforced
- Audit logging of all requests

### T2: Management API Exposure
**Threat**: Public access to `/key/generate`, `/ui`, `/team/*`, etc.
**Impact**: Attacker creates keys, modifies budgets, extracts credentials
**Mitigations**:
- Caddy blocks ALL management routes at public ingress (404)
- Management only via SSH tunnel to localhost:4000
- Admin UI requires separate UI_PASSWORD (not master key)
- No Basic Auth on same routes (interferes with Bearer tokens)

### T3: Secret Leakage
**Threat**: Secrets exposed in Git, logs, Terraform state, CI
**Impact**: Full system compromise
**Mitigations**:
- No secrets in Git (`.gitignore`, `.env.example` only)
- Terraform state in OCI backend (encrypted, versioned)
- Cloud-init has NO secrets
- CI uses OIDC, no long-lived keys
- Docker secrets for runtime credentials
- gitleaks in CI pipeline

### T4: Salt Key Compromise
**Threat**: LITELLM_SALT_KEY exposed
**Impact**: All stored provider credentials decryptable
**Mitigations**:
- Salt key stored ONLY in operator secret store
- Never in Git, Terraform, cloud-init, CI
- Separate backup/escrow procedure
- Rotation requires re-entering ALL provider credentials

### T5: Master Key Compromise
**Threat**: LITELLM_MASTER_KEY exposed
**Impact**: Full admin API access, key management
**Mitigations**:
- Master key in operator secret store only
- UI_PASSWORD separate for daily admin access
- Master key rotation procedure documented
- Audit log of all admin operations

### T6: Database Compromise
**Threat**: PostgreSQL data accessed/exfiltrated
**Impact**: Virtual keys, budgets, spend logs, metadata exposed
**Mitigations**:
- PostgreSQL on internal network only
- SCRAM-SHA-256 authentication
- Encrypted at rest (volume encryption)
- Backups encrypted with age (offline private key)
- Minimal PII stored

### T7: Provider Credential Theft
**Threat**: Upstream API keys extracted from LiteLLM DB
**Impact**: Unauthorized use of provider accounts, billing fraud
**Mitigations**:
- Credentials encrypted with salt key in DB
- Salt key not on VM (operator only)
- Provider-side billing alerts/limits
- Budget enforcement in proxy

### T8: Denial of Service
**Threat**: High request volume exhausts resources
**Impact**: Service unavailable
**Mitigations**:
- Rate limiting at Caddy (request size, timeouts)
- Rate limiting at LiteLLM (per-key RPM/TPM)
- Budget limits prevent runaway spend
- Caddy request body limit (100 MB)
- Streaming timeouts configured

### T9: Supply Chain Attack
**Threat**: Compromised Docker image or dependency
**Impact**: Arbitrary code execution on gateway
**Mitigations**:
- Official images only, pinned by SHA256 digest
- Cosign signature verification for LiteLLM
- ARM64 manifest verification
- SBOM generation and vulnerability scanning
- No `latest` tags

### T10: Infrastructure Drift/Tampering
**Threat**: Unauthorized changes to OCI resources
**Impact**: Security group changes, instance modification
**Mitigations**:
- Terraform state locked in OCI Object Storage
- Drift detection daily via GitHub Actions
- OIDC for CI with exact repo/ref/environment claims
- Protected environment for apply
- No manual changes (all via PR)

### T11: Backup Tampering/Deletion
**Threat**: Backups deleted or corrupted
**Impact**: Unrecoverable data loss
**Mitigations**:
- Object Storage versioning enabled
- Lifecycle policies prevent premature deletion
- Instance principal has write-only to backup bucket
- Offline age private key required for decryption
- Quarterly restore drills

### T12: OCI Instance Reclaim
**Threat**: Always Free A1 instance reclaimed
**Impact**: Complete service outage
**Mitigations**:
- Terraform recreates instance automatically
- Boot volume backed up (snapshots)
- Database restored from Object Storage
- DNS remapped to new IP
- RTO target: 4 hours

## Attack Surface Summary

| Surface | Exposure | Protection |
|---------|----------|------------|
| HTTPS 443 | Public | Caddy allowlist, TLS 1.2+, rate limits |
| HTTP 80 | Public | ACME challenge only, redirect to HTTPS |
| SSH 22 | Admin CIDR | Key-only, fail2ban, hardened config |
| LiteLLM 4000 | Localhost only | Not exposed to network |
| PostgreSQL 5432 | Compose internal | No external access |
| Redis 6379 | Compose internal | Password protected |
| Caddy Admin 2019 | Disabled | `admin off` in Caddyfile |

## Incident Response

1. **Key Compromise**: Revoke immediately via admin API, audit usage, rotate if needed
2. **Master Key Compromise**: Rotate master key, invalidate all sessions, audit admin actions
3. **Salt Key Compromise**: Follow restore/re-entry plan, re-enter all provider credentials
4. **Instance Compromise**: Re-provision from Terraform, restore DB, rotate all secrets
5. **Provider Breach**: Rotate affected provider credentials, audit proxy usage

## Compliance Notes

- No automatic GDPR/CCPA compliance - upstream provider policies apply
- Audit logs retained 7-14 days (configurable)
- No prompt/response logging by default
- Key metadata (not values) in GitHub issues for access requests