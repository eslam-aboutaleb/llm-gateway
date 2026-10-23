# Upgrade Guide

## Upgrade Types

| Type | Description | Risk | Downtime |
|------|-------------|------|----------|
| **Patch** | LiteLLM point release (v1.46.1 → v1.46.2) | Low | < 2 min |
| **Minor** | LiteLLM minor release (v1.46.x → v1.47.x) | Medium | < 5 min |
| **Major** | LiteLLM major release (v1.x → v2.x) | High | Planned |
| **Config** | Model catalog, limits, aliases | Low | None |
| **Infra** | Terraform changes (instance size, network) | Varies | Planned |

## Pre-Upgrade Checklist

- [ ] Review upstream release notes and breaking changes
- [ ] Verify ARM64 image availability for new version
- [ ] Test migration in staging/isolated environment
- [ ] Confirm backup < 24 hours old
- [ ] Schedule maintenance window (if major)
- [ ] Notify stakeholders of planned changes
- [ ] Prepare rollback plan

## Upgrade Procedure

### 1. Create Release Branch

```bash
git checkout -b upgrade/litellm-v1.47.0
```

### 2. Update Image Digest

```bash
# Get new digest
docker buildx imagetools inspect ghcr.io/berriai/litellm:main-v1.47.0

# Update compose.prod.yaml
sed -i 's/main-v1.46.1@sha256:OLD/main-v1.47.0@sha256:NEW/' gateway/compose.prod.yaml
```

### 3. Update Configuration (if needed)

- Check `litellm.yaml` for new settings
- Update `model-catalog.yaml` for new aliases
- Run `make ci-quality`

### 4. Test ARM64 Compatibility

Compatibility is validated automatically in PRs or manual dispatch via the GitHub Actions workflow:

```bash
gh workflow run arm64-compatibility.yml
```

### 5. Create PR and Validate

```bash
git commit -am "Upgrade LiteLLM to v1.47.0"
git push origin upgrade/litellm-v1.47.0
# Create PR - CI runs arm64-compatibility.yml
```

### 6. Tag Release

```bash
# After PR merged
git tag v1.0.1
git push origin v1.0.1
# Triggers release.yml workflow
```

### 7. Deploy

```bash
# Via GitHub Actions
gh workflow run deploy.yml -f release_tag=v1.0.1 -f confirm=DEPLOY
```

## Migration Handling

### Automatic Migrations (Disabled in Compose)

```yaml
# In compose.yaml
environment:
  - DISABLE_SCHEMA_UPDATE=true
```

### Manual Migration Step

```bash
# Run as one-off job BEFORE deploying new version
docker run --rm --network llm-gateway-internal \
  -e DATABASE_URL=$DATABASE_URL \
  -e LITELLM_SALT_KEY=$LITELLM_SALT_KEY \
  ghcr.io/berriai/litellm:main-v1.47.0@sha256:NEW \
  litellm --migrate
```

### Migration Verification

```bash
# Check migration status
docker run --rm --network llm-gateway-internal \
  -e DATABASE_URL=$DATABASE_URL \
  ghcr.io/berriai/litellm:main-v1.47.0@sha256:NEW \
  litellm --migrate-status
```

## Version Pinning Policy

### LiteLLM

- Pin to specific version tag: `main-v1.46.1`
- Pin by SHA256 digest in compose.prod.yaml
- Record digest in release manifest
- Never use `latest` or unpinned tags

### PostgreSQL/Redis/Caddy

- Pin by digest in compose.yaml
- Update when security patches released
- Test ARM64 compatibility before updating

### Terraform Providers

- Pin in `.terraform.lock.hcl`
- Update via Dependabot PRs
- Test plan before merging

## Rollback Procedure

If upgrade causes issues:

```bash
# Immediate rollback via Deploy workflow
gh workflow run deploy.yml -f operation=rollback -f release_tag=v1.0.0 -f confirm=ROLLBACK

# If schema migrated, restore database via Backup & Restore workflow
gh workflow run backup-restore.yml -f operation=restore -f backup_object=litellm-20261023-120000.dump.age
```

**Critical**: Rolling back image does NOT revert database schema. If migration ran, you MUST restore database from pre-migration backup.

## Post-Upgrade Validation

- [ ] All services healthy
- [ ] Smoke tests pass
- [ ] Key authentication works
- [ ] Model aliases functional
- [ ] Budget/rate limits enforced
- [ ] Metrics reporting
- [ ] Backup job runs successfully
- [ ] No error spikes in logs

## Emergency Hotfix

For critical security patches:

1. Create hotfix branch from current release tag
2. Apply minimal change
3. Tag as `v1.0.1-hotfix.1`
4. Deploy with `--skip-backup` if time-critical
5. Run backup immediately after