# ADR-001: Use LiteLLM Proxy as Gateway

## Status
Accepted

## Date
2026-10-23

## Context
We need an OpenAI-compatible API gateway that:
- Centralizes upstream LLM provider credentials
- Enforces per-key/team budgets and rate limits
- Provides model alias abstraction
- Supports multiple providers (OpenAI, Anthropic, Azure, Vertex)
- Runs on ARM64 (OCI Always Free A1)
- Has admin UI for key management
- Supports virtual keys (not raw provider keys)

## Decision
Use **LiteLLM Proxy** (official Docker image, pinned by digest) as the gateway component.

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **LiteLLM Proxy** | OpenAI-compatible, multi-provider, virtual keys, budgets, admin UI, ARM64 images, active development | Python-based (memory), single-process scaling | **Selected** |
| Custom FastAPI + Providers | Full control, optimized | Reinventing auth, routing, budgets, fallbacks | Rejected |
| Kong + Plugins | Mature gateway | No LLM-specific features, complex setup | Rejected |
| AWS API Gateway + Lambda | Managed | Not portable, vendor lock-in, cost | Rejected |
| NGINX + Lua | Lightweight | No LLM logic, custom development needed | Rejected |

## Consequences

### Positive
- Standard OpenAI API compatibility for consumers
- Virtual keys provide secure, scoped access
- Built-in budget/rate limiting with Redis/PostgreSQL
- Admin UI for day-to-day operations
- Model aliases abstract provider changes
- Active community and enterprise support
- ARM64 images available officially

### Negative
- Python memory footprint (~5 GB) limits headroom on 12 GB VM
- Single worker initially (no horizontal scaling on single VM)
- Schema migrations require careful deployment coordination
- Master key and salt key are critical secrets
- Admin UI exposes management APIs (must be protected)

## Implementation Notes

- Pin image by SHA256 digest (not tag)
- Run migrations as separate one-off job (`DISABLE_SCHEMA_UPDATE=true`)
- Protect admin UI/API via SSH tunnel only
- Use `LITELLM_SALT_KEY` for DB encryption (escrow offline)
- Configure fail-closed rate limiting on Redis failure
- Model catalog source of truth = Git (reconcile UI changes)

## References
- LiteLLM Proxy Docs: https://docs.litellm.ai/docs/proxy/deploy
- LiteLLM Virtual Keys: https://docs.litellm.ai/docs/proxy/virtual_keys
- LiteLLM Budgets: https://docs.litellm.ai/docs/proxy/users
- LiteLLM Docker Security: https://docs.litellm.ai/docs/proxy/docker_image_security