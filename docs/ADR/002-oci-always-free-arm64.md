# ADR-002: OCI Always Free ARM64 for Infrastructure

## Status
Accepted

## Date
2026-10-23

## Context
Need cloud infrastructure for the gateway with:
- Always Free eligible (no recurring cost)
- ARM64 support (LiteLLM ARM64 images)
- Sufficient compute for LiteLLM + PostgreSQL + Redis + Caddy
- Terraform provider support
- Object Storage for backups/state
- DNS and TLS certificate management

## Decision
Use **Oracle Cloud Infrastructure (OCI) Always Free** with:
- `VM.Standard.A1.Flex` (2 OCPU, 12 GB RAM, ARM64)
- 100 GB boot volume
- 20 GB Object Storage (state + backups)
- Single VCN with public subnet
- Caddy for TLS termination (Let's Encrypt)

## Alternatives Considered

| Option | Compute | Storage | Cost | ARM64 | Verdict |
|--------|---------|---------|------|-------|---------|
| **OCI Always Free A1** | 2 OCPU, 12 GB | 200 GB block + 20 GB obj | $0 | Yes | **Selected** |
| AWS Free Tier | t2/t3.micro (1 vCPU, 1 GB) | 30 GB EBS | $0 (12 mo) | Yes (t4g) | Too small |
| Azure Free Tier | B1s (1 vCPU, 1 GB) | 64 GB disk | $0 (12 mo) | No | Too small, no ARM |
| GCP Free Tier | e2-micro (2 vCPU, 1 GB) | 30 GB disk | $0 | No | Too small |
| Oracle Paid A1 | Flexible | Pay per use | ~$10-20/mo | Yes | Future upgrade |
| Self-hosted | Own hardware | Own storage | Power/colo | Yes | Not cloud |

## Consequences

### Positive
- Zero recurring cost for baseline operation
- 2 OCPU / 12 GB fits memory envelope (with headroom)
- ARM64 native (no emulation)
- Generous Object Storage (20 GB) for backups + state
- Terraform provider mature (OCI native backend)
- OIDC federation for GitHub Actions
- No NAT Gateway needed (public subnet + IGW)
- Instance principal for VM permissions

### Negative
- **Reclaim risk**: A1 instances can be reclaimed when idle
- **No SLA**: Always Free has no uptime guarantee
- **Quota limits**: Regional, account-dependent availability
- **Single instance**: No HA without paid upgrade
- **No Load Balancer**: Always Free LB not available
- **Shared quotas**: Block volume + Object Storage shared

## Mitigations

| Risk | Mitigation |
|------|------------|
| Reclaim | Keep instance active (health checks), have paid fallback plan |
| No HA | Off-VM backups, RTO 4h target, Terraform re-provision |
| Quota exhaustion | Monitor usage, alert at 75/85%, lifecycle policies |
| Single AZ | Document paid multi-AD upgrade path |

## Implementation Notes

- Use `VM.Standard.A1.Flex` with 2 OCPU / 12 GB (max free)
- Pin Ubuntu 24.04 ARM64 image by OCID
- 100 GB boot volume (within 200 GB free block quota)
- NSG: only 80/443 public, 22 from admin CIDR
- Terraform state in Object Storage (OCI native backend, versioned)
- Backups in separate bucket prefix (lifecycle 30 days)
- Instance principal for Object Storage access (no keys on VM)
- GitHub Actions OIDC → OCI (no long-lived API keys)

## References
- OCI Always Free: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- Terraform OCI Backend: https://developer.hashicorp.com/terraform/language/backend/oci
- OCI GitHub OIDC: https://docs.oracle.com/en-us/iaas/releasenotes/identity/jwt_to_rpst_token_exchange_for_workload_identity_federation.htm