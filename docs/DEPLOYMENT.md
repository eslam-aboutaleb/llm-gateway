# Deployment Guide

## Overview

Deployment follows a GitOps-inspired model:
1. **Release** - CI builds signed release manifest + artifacts → OCI Object Storage
2. **Deploy** - VM pulls release via instance principal → applies via Compose
3. **Verify** - Smoke tests confirm health

## Prerequisites

- Infrastructure deployed (`infra-apply` workflow complete)
- VM running with cloud-init complete
- Secrets delivered to VM
- Release published (`release` workflow complete)

## Deployment Methods

### GitHub Actions (Standard GitOps Flow)

Every deployment and rollback is orchestrated via GitHub Actions and Terramate. No local scripts are needed:

```bash
# Trigger via GitHub CLI or Actions UI
gh workflow run deploy.yml -f release_tag=v1.0.0
```

This automated workflow:
1. Authenticates securely to OCI via Workload Identity / OIDC (no static cloud credentials in CI).
2. Sends the signed release deployment commands directly to the Gateway VM via OCI Instance Agent.
3. Downloads the signed release manifest and configuration files from OCI Object Storage using instance principal authentication.
4. Atomically stages the release under `/opt/llm-gateway/releases/<tag>`, updates the `/opt/llm-gateway/current` pointer, pulls pinned images, and reloads `llm-gateway.service`.
5. Executes automated health checks and end-to-end smoke tests directly from GitHub Actions runner.

## Release Artifacts Structure

In OCI Object Storage: `releases-<namespace>/<tag>/`

```
v1.0.0/
├── manifest.json          # Release metadata + digests
├── manifest.json.sig      # Cosign signature
├── compose.yaml           # Base Compose configuration
├── compose.prod.yaml      # Production override
├── caddy/Caddyfile        # Caddy reverse proxy configuration
├── config/litellm.yaml    # LiteLLM routing configuration
└── config/model-catalog.yaml # Abstract model catalog
```

### Manifest Format

```json
{
  "version": "v1.0.0",
  "timestamp": "2026-10-23T12:00:00Z",
  "commit": "abc123...",
  "litellm_image": "ghcr.io/berriai/litellm",
  "litellm_tag": "main-v1.46.1",
  "litellm_digest": "sha256:...",
  "compose_files": ["compose.yaml", "compose.prod.yaml"],
  "config_files": ["config/litellm.yaml", "config/model-catalog.yaml"],
  "caddy_file": "caddy/Caddyfile",
  "scripts": [...]
}
```

## Pre-Deployment Checklist

- [ ] Release tag exists and is signed
- [ ] Manifest signature verified
- [ ] Image digests match manifest
- [ ] Current backup < 24 hours old
- [ ] Sufficient disk space (>2 GB free)
- [ ] No active maintenance windows
- [ ] Rollback plan reviewed

## Deployment Steps Detail

### 1. Download & Verify

```bash
# Download manifest
oci os object get --namespace $NS --bucket-name $BUCKET --name "$TAG/manifest.json" --file manifest.json

# Verify signature
cosign verify-blob --key $PUB_KEY --signature manifest.json.sig manifest.json

# Verify digest
jq -r '.litellm_digest' manifest.json
```

### 2. Backup & Verification

Pre-deployment backup is automatically triggered, or can be run via the `Backup & Restore` workflow (`.github/workflows/backup-restore.yml`).

### 3. Deploy & Health Wait

The GitHub Actions workflow pulls pinned container images, applies Compose overrides, and waits for container health.

### 4. Smoke Test

The GitHub Actions workflow runs the automated smoke test suite verifying:
- Public endpoints (health `/health`, status `/status`)
- Authenticated endpoints (models, chat completions, embeddings)
- Blocked management paths (admin UI and Prometheus paths return 404 from external networks)

## Rollback

If deployment fails verification, roll back instantly using GitHub Actions:

```bash
gh workflow run deploy.yml -f operation=rollback -f release_tag=v0.9.0 -f confirm=ROLLBACK
```

See [ROLLBACK.md](ROLLBACK.md) for details.