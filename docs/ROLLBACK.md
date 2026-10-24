# Rollback Guide

## When to Rollback

- Deployment fails health checks
- Smoke tests fail
- Critical bug discovered post-deployment
- Performance regression
- Security issue in new release

## Rollback Types

### 1. Application Rollback (Compose & Config)

Reverts Docker images and configuration to a previous release tag using the GitHub Actions Deploy workflow:

```bash
gh workflow run deploy.yml -f operation=rollback -f release_tag=v1.0.0 -f confirm=ROLLBACK
```

**Use when**: Config change, image regression, no Prisma migration ran.  
**Time**: ~1-2 minutes.

### 2. Full Rollback (Application + Database)

Restores the database from pre-upgrade backup AND rolls back the application:

```bash
# 1. Rollback application via Deploy workflow
gh workflow run deploy.yml -f operation=rollback -f release_tag=v1.0.0 -f confirm=ROLLBACK

# 2. Restore database from pre-upgrade backup via Backup & Restore workflow
gh workflow run backup-restore.yml -f operation=restore -f backup_object=litellm-20261023-120000.dump.age
```

**Use when**: Migration ran and caused schema incompatibility or query failure.  
**Time**: ~5-15 minutes.

## Rollback Procedure via GitHub Actions

1. **Trigger Rollback**:
   ```bash
   gh workflow run deploy.yml \
     -f operation=rollback \
     -f release_tag=<previous_tag> \
     -f confirm=ROLLBACK
   ```

2. **Automated Verification**:
   The workflow automatically:
   - Points `/opt/llm-gateway/current` to the target release.
   - Restarts `llm-gateway.service`.
   - Runs `/health` and `/status` checks.
   - Runs the smoke test suite against public and authenticated endpoints.

3. **Database Restore (if required)**:
   ```bash
   gh workflow run backup-restore.yml \
     -f operation=restore \
     -f backup_object=<backup_object_name>
   ```

## Rollback Decision Matrix

| Scenario | Action |
|----------|--------|
| Config error, no migration | Application rollback |
| Image bug, no migration | Application rollback |
| Migration ran, schema broken | Full rollback (app + DB) |
| Migration ran, data corruption | Full rollback + point-in-time recovery |
| Infrastructure change | Terraform rollback (separate) |

## Terraform Rollback

For infrastructure changes:

```bash
# Option 1: Revert Terraform code and apply
git revert <commit>
gh workflow run infra-apply.yml -f plan_sha=<new_plan_sha>

# Option 2: Restore previous state
oci os object get --namespace $NS --bucket-name $TFSTATE_BUCKET \
  --name production/terraform.tfstate --version-id <prev_version> \
  --file terraform.tfstate
terraform apply -refresh-only
```

## Post-Rollback

- [ ] Verify all functionality restored
- [ ] Check error rates return to baseline
- [ ] Verify backup job runs
- [ ] Document incident and root cause
- [ ] Update runbook if new scenario discovered

## Automation

The `deploy-release.sh` script automatically rolls back on:
- Health check timeout
- Smoke test failure
- Configuration validation failure

Manual rollback is needed for:
- Post-deployment issues discovered later
- Database migration issues
- Infrastructure problems