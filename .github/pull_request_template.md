# Pull Request Template

## Description

Brief description of the changes and the problem they solve.

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Infrastructure change (Terraform/Terramate)
- [ ] CI/CD workflow change
- [ ] Security improvement

## Testing

- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] ARM64 compatibility verified (if Docker images changed)
- [ ] Terraform plan/apply validated (if infrastructure changed)
- [ ] Security scans pass (gitleaks, IaC policy)
- [ ] Manual verification steps completed (describe below)

### Manual Verification Steps

1.
2.
3.

## Checklist

- [ ] No secrets, credentials, or sensitive data in commits, diffs, or CI logs
- [ ] Code follows project style guidelines (run linters)
- [ ] Self-review of the code completed
- [ ] Comments added for complex logic
- [ ] Documentation updated (README, docs/, inline comments)
- [ ] CHANGELOG.md updated (if applicable)
- [ ] Dependencies pinned by digest/SHA where applicable
- [ ] Branch protection rules respected (no force push to protected branches)

## Related Issues

Closes #<issue-number>

## Screenshots / Logs (if applicable)

<!-- Add screenshots or relevant log output here -->

## Deployment Notes

<!-- Any special deployment considerations, migration steps, or rollback procedures -->

---

**Reviewer Notes:**
- Infrastructure changes require `@eslam-aboutaleb` review
- Security-sensitive changes (IAM, secrets, network) require explicit approval
- ARM64 image changes must pass native compatibility workflow