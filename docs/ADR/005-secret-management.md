# ADR-005: Secret Management Strategy

## Status
Accepted

## Date
2026-10-23

## Context
Need to manage secrets for:
- LiteLLM Master Key (admin API)
- LiteLLM Salt Key (DB encryption)
- PostgreSQL password
- Redis password
- Upstream provider API keys (OpenAI, Anthropic, etc.)
- Admin UI password
- Age encryption keys (backup)
- TLS certificates (Caddy/Let's Encrypt)

Requirements:
- No secrets in Git, Terraform state, cloud-init, CI logs
- Secrets delivered securely to VM
- Rotation procedures documented
- Backup encryption keys escrowed offline
- Minimal secret surface on VM

## Decision
Multi-layered secret management:

| Secret | Storage | Delivery | Rotation |
|--------|---------|----------|----------|
| Master Key | Operator password manager | Manual (password mgr) | Manual via Admin UI |
| Salt Key | Operator password manager + offline (USB/paper) | Manual | **Avoid** (re-entry required) |
| PostgreSQL Password | Docker secret (file) | `scp` to VM | Generate new, update secret, restart |
| Redis Password | Environment variable | `scp` .env to VM | Generate new, update env, restart |
| Provider Keys | LiteLLM DB (encrypted) | Admin UI | Admin UI |
| UI Password | Operator password manager | Manual | Admin UI |
| Age Private Key | **Offline only** (USB, paper QR) | Never on VM | Regenerate keypair, re-encrypt |
| Age Public Key | VM env / GitOps | Terraform/Config | With keypair rotation |
| TLS Certificates | Caddy data volume | Auto (Let's Encrypt) | Auto |

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Multi-layered (above)** | Defense in depth, offline escrow | Operational complexity | **Selected** |
| HashiCorp Vault | Centralized, dynamic secrets | Extra infrastructure, complexity | Rejected |
| AWS/Azure/GCP Secrets Manager | Cloud-native | Vendor lock-in, not Always Free | Rejected |
| SOPS + Git | GitOps, encrypted | Keys in repo (even encrypted) | Rejected |
| 1Password CLI | Good UX | Requires auth, not automation-friendly | Partial |
| Doppler/Infisical | SaaS secrets | External dependency, cost | Rejected |

## Consequences

### Positive
- No secrets in any repository or state file
- Salt key and age private key never on VM disk
- Clear rotation procedures per secret type
- Offline escrow for catastrophic recovery
- Docker secrets for runtime PostgreSQL password
- Instance principal for OCI access (no keys)

### Negative
- Manual steps for initial delivery and rotation
- Salt key loss = catastrophic (documented)
- Age private key loss = backup unrecoverable
- No automated rotation (by design)

## Implementation Notes

### Secret Storage & Provisioning
Secrets are stored in GitHub Repository Secrets (for CI/CD workflows) and OCI Vault:
- Docker secret file for PostgreSQL (`postgres_password`)
- Environment variables injected into systemd and container runtime
- Public age key for automated off-node backup encryption
- Salt key stored offline in enterprise password manager / secure escrow

# Other secrets via password manager UI/CLI
```

### VM Secret Access
```yaml
# In compose.yaml
secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt

services:
  postgres:
    environment:
      - POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
```

### Backup Encryption
- Age public key in VM env (`BACKUP_AGE_PUBLIC_KEY`)
- Age private key **only offline**
- Backup script encrypts before upload
- Restore script requires private key

## References
- Docker Secrets: https://docs.docker.com/compose/use-secrets/
- Age Encryption: https://github.com/FiloSottile/age
- OCI Instance Principal: https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/callingservicesfrominstances.htm