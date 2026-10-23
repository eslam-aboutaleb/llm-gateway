# Configuration Guide

## Environment Variables

All secrets and configuration are injected via environment variables. See `.env.example` for the complete list.

### Required Variables

| Variable | Description | Source |
|----------|-------------|--------|
| `LITELLM_MASTER_KEY` | Admin API key (32-byte hex) | Operator secret store |
| `LITELLM_SALT_KEY` | DB encryption key (32-byte hex) | Operator secret store |
| `DATABASE_URL` | PostgreSQL connection string | Generated from bootstrap |
| `REDIS_URL` | Redis connection string | Generated from bootstrap |
| `LITELLM_UI_PASSWORD` | Admin UI password | Operator secret store |
| `GATEWAY_DNS_DOMAIN` | Public DNS name | DNS configuration |
| `ACME_EMAIL` | Let's Encrypt registration email | Admin contact |

### Upstream Provider Keys (Optional)

| Variable | Provider |
|----------|----------|
| `OPENAI_API_KEY` | OpenAI |
| `ANTHROPIC_API_KEY` | Anthropic |
| `AZURE_API_KEY` | Azure OpenAI |
| `AZURE_API_BASE` | Azure OpenAI endpoint |
| `AZURE_API_VERSION` | Azure API version |
| `VERTEX_PROJECT` | Google Vertex AI project |
| `VERTEX_LOCATION` | Google Vertex AI location |
| `GOOGLE_APPLICATION_CREDENTIALS` | Optional Google ADC/service-account credentials file |
| `AWS_REGION_NAME` | Amazon Bedrock region |
| `AWS_ACCESS_KEY_ID` | Optional Bedrock access key; prefer instance/workload identity |
| `AWS_SECRET_ACCESS_KEY` | Optional Bedrock secret; prefer instance/workload identity |
| `AWS_SESSION_TOKEN` | Optional temporary Bedrock session token |
| `AWS_ROLE_NAME` | Optional Bedrock role name |

### Backup/Monitoring

| Variable | Description |
|----------|-------------|
| `BACKUP_AGE_PUBLIC_KEY` | Age public key for backup encryption |
| `OCI_OBJECT_STORAGE_NAMESPACE` | OCI Object Storage namespace |
| `OCI_BACKUP_BUCKET` | Backup bucket name |
| `ALERT_WEBHOOK_URL` | Alert notification webhook |

## LiteLLM Configuration (`gateway/config/litellm.yaml`)

### Key Settings

```yaml
general_settings:
  master_key: "os.environ/LITELLM_MASTER_KEY"
  salt_key: "os.environ/LITELLM_SALT_KEY"
  database_url: "os.environ/DATABASE_URL"
  redis_url: "os.environ/REDIS_URL"
  disable_schema_update: true  # Critical: migrations run separately
  ui_username: "admin"
  ui_password: "os.environ/LITELLM_UI_PASSWORD"
  allowed_routes_for_keys: ["/v1/chat/completions", "/v1/embeddings", "/v1/models"]
  log_level: "INFO"
  request_timeout: 600
```

### Model List

Models are exposed through stable aliases. Provider-specific deployment entries
are implementation details and can be replaced without changing client code:

```yaml
model_list:
  - model_name: "general-fast"
    litellm_params:
      model: "openai/gpt-4o-mini"
      api_key: "os.environ/OPENAI_API_KEY"
    model_info:
      description: "Fast general-purpose model"
      max_tokens: 128000
      input_cost_per_token: 0.00000015
      output_cost_per_token: 0.0000006
      mode: "chat"
```

    To switch this deployment to Vertex AI, retain `model_name: "general-fast"` and
    replace the provider-specific parameters with `vertex_ai/gemini-2.0-flash`,
    `VERTEX_PROJECT`, and `VERTEX_LOCATION`. For Bedrock, use a `bedrock/...` model
    ID and `AWS_REGION_NAME`. Keep alternate deployments under the same alias only
    after testing capability parity and cost limits.

### Router Settings

```yaml
router_settings:
  routing_strategy: "latency-based-routing"
  num_retries: 2
  retry_after: 1
  retry_on_status_codes: [429, 500, 502, 503, 504]
  timeout: 600
```

## Model Catalog (`gateway/config/model-catalog.yaml`)

Defines capability aliases and provider profiles (not client-facing provider IDs):

```yaml
model_aliases:
  - alias: "general-fast"
    description: "Fast, cost-effective model for general chat"
    capabilities: ["chat", "streaming", "function_calling"]
    approved_providers: ["openai"]
    default_model: "openai/gpt-4o-mini"
    cost_tier: "low"
    enabled: true
```

## Caddy Configuration (`gateway/caddy/Caddyfile`)

### Route Allowlist

Only these paths are publicly accessible:
- `/v1/chat/completions` - Chat completions (streaming supported)
- `/v1/embeddings` - Embeddings
- `/v1/models` - Model list
- `/health`, `/ready`, `/status` - Health checks

All other paths (including `/ui`, `/key/*`, `/team/*`, `/config/*`, `/spend/*`) return 404.

### Security Headers

- HSTS (1 year, preload)
- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY
- Referrer-Policy: strict-origin-when-cross-origin
- Server header removed

## Docker Compose

### Base (`compose.yaml`)

Defines all services with:
- Explicit image digests (SHA256)
- Resource limits (CPU, memory)
- Health checks
- Read-only root filesystem
- Non-root users
- Internal networks

### Production Override (`compose.prod.yaml`)

- Adjusted resource limits
- Backup service profile
- Production logging

### Networks

- `llm-gateway-internal`: Fully internal (PostgreSQL, Redis, LiteLLM, Node Exporter)
- `llm-gateway-caddy`: Caddy ↔ LiteLLM only

### Volumes

- `postgres_data`: PostgreSQL data
- `redis_data`: Redis data
- `caddy_data`: ACME certificates
- `caddy_config`: Caddy configuration

### Secrets

- `postgres_password`: PostgreSQL password (file-based)

## Cloud-Init Template (`cloud-init/init.yaml.tftpl`)

Rendered by Terramate with:
- SSH public key
- Instance-specific values

Installs:
- Docker Engine (pinned version)
- Caddy
- Age (encryption)
- Monitoring tools
- Security hardening (fail2ban, UFW, unattended-upgrades)

Creates:
- `llm-gateway` service user
- Application directories
- Systemd services for Compose and backup timer
- Logrotate configuration

## Systemd Services

### `llm-gateway.service`

Manages Docker Compose stack:
- Starts after Docker
- Health-gated startup
- Resource limits (MemoryLimit=10G, CPUQuota=180%)
- Security hardening (NoNewPrivileges, ProtectSystem=strict, etc.)

### `llm-gateway-backup.timer`

Daily backup at random hour (0-1 AM):
- Runs `backup-postgres.sh`
- Encrypts with age
- Uploads to OCI Object Storage

## Secret Management

Secrets are managed via OCI Vault or GitHub Secrets:
- `LITELLM_MASTER_KEY`: Admin API authorization (prefixed with `sk-`)
- `LITELLM_SALT_KEY`: Salt for encrypting stored database secrets (CRITICAL - escrow offline)
- `POSTGRES_PASSWORD`: Database credential
- `REDIS_PASSWORD`: In-memory cache credential
- `LITELLM_UI_PASSWORD`: Admin Web UI password
- `BACKUP_AGE_PUBLIC_KEY`: Public encryption key for automated backups

### Rotation

| Secret | Rotation Procedure |
|--------|-------------------|
| Master Key | Admin API → new key → update secret in Vault → reload |
| Salt Key | **Cannot rotate easily** - requires re-entering all provider credentials |
| PostgreSQL Password | Update secret in Vault/Docker secret → restart postgres |
| Redis Password | Update secret in Vault → restart redis |
| UI Password | Admin UI → change password |
| Provider Keys | Admin UI → update credentials → test |
| Age Private Key | Offline only; re-encrypt existing backups if new key generated |

## Validation

All configurations are validated automatically in CI via the centralized quality workflow, or locally via `make ci-quality`:

```bash
make ci-quality
```

# Checks:
# - Required files exist
# - YAML/JSON syntax
# - Caddyfile routing and syntax
# - Docker Compose syntax & sha256 digests
# - No placeholder digests or hardcoded secrets
# - Model catalog structure & schema conformance
# - Terraform/Terramate syntax
# - Shell script syntax
```