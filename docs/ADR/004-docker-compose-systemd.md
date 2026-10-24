# ADR-004: Docker Compose with systemd for Service Orchestration

## Status
Accepted

## Date
2026-10-23

## Context
Need to orchestrate multiple containers (LiteLLM, PostgreSQL, Redis, Caddy, Node Exporter) on a single VM with:
- Health-gated startup ordering
- Resource limits (CPU, memory, PIDs)
- Security hardening (non-root, read-only, no-new-privileges)
- Automatic restart on failure
- Reboot recovery
- Log rotation
- Backup as scheduled job

## Decision
Use **Docker Compose** managed by **systemd** service units.

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Docker Compose + systemd** | Simple, native, health checks, resource limits, reboot recovery | Single-node only | **Selected** |
| Kubernetes (k3s/k0s) | HA, scaling, ecosystem | Overhead, complexity, not Always Free friendly | Rejected |
| Nomad | Lightweight scheduler | Extra binary, learning curve | Rejected |
| systemd only (no Compose) | No Docker dependency | No health-gated deps, harder multi-container | Rejected |
| Podman + Quadlet | Rootless, systemd native | Less mature, Compose compatibility | Rejected |
| Supervisord | Process management | No container isolation, no health checks | Rejected |

## Consequences

### Positive
- Compose defines multi-container app declaratively
- systemd provides service management (start/stop/restart/enable)
- Health checks gate startup (`depends_on: condition: service_healthy`)
- Resource limits at container level (CPU, memory, PIDs)
- Security hardening via Compose + systemd directives
- Reboot recovery via `systemctl enable`
- Backup as separate systemd timer
- Log rotation via logrotate + Docker JSON logging

### Negative
- Single node only (no HA)
- No rolling updates (recreate strategy)
- Manual scaling (change compose, restart)
- Network namespace per Compose project

## Implementation Notes

### Compose Files
- `compose.yaml` - Base configuration (all environments)
- `compose.prod.yaml` - Production overrides (resources, logging)
- `compose.dev.yaml` - Development overrides (if needed)

### Systemd Units
- `llm-gateway.service` - Main Compose stack (Type=oneshot, RemainAfterExit=yes)
- `llm-gateway-backup.timer` + `.service` - Daily backup

### Security Hardening
- All containers: `user`, `read_only`, `no-new-privileges`, `tmpfs`
- Network: internal bridge for DB/Redis, separate for Caddy→LiteLLM
- LiteLLM binds `127.0.0.1:4000` only
- PostgreSQL/Redis no exposed ports

### Resource Limits (12 GB VM)
| Service | CPU Limit | Memory Limit |
|---------|-----------|--------------|
| LiteLLM | 1.5 | 6 GB |
| PostgreSQL | 1.0 | 2 GB |
| Redis | 0.5 | 1 GB |
| Caddy | 0.25 | 512 MB |
| Node Exporter | 0.1 | 128 MB |
| **Total** | **3.35** | **~9.6 GB** |
| **Headroom** | **~2.65** | **~2.4 GB** |

## References
- Docker Compose Spec: https://github.com/compose-spec/compose-spec
- systemd Service: https://www.freedesktop.org/software/systemd/man/systemd.service.html
- Docker Security: https://docs.docker.com/engine/security/