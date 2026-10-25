## Description

<!-- Provide a brief description of the changes introduced by this PR. -->

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Performance improvement
- [ ] CI/CD or tooling enhancement

## Behavior and Compatibility

<!-- For runtime changes, describe the observable contract and the path through
callers, adapters, storage, and readers. Include a concrete before/after example
where useful, plus any API or adapter migration requirements.
For documentation or cosmetic changes, mark runtime sections N/A. -->

## Verification Evidence

<!-- Map changed contracts to behavioral tests. Name the real internal components
exercised and relevant failure, retry, denied-scope, or boundary scenarios.
For bug fixes, state whether the regression failed before the fix.
List commands and results, plus skipped checks and unverified assumptions. -->

## Independent Review

<!-- For authorization, concurrency, or recovery changes, identify the independent
reviewer and outcome before merging. Otherwise mark N/A. -->

## Checklist

- [ ] My code adheres to the project's coding style guidelines (`ruff check .` and `ruff format --check .`)
- [ ] Changed runtime contracts and compatibility requirements are documented above (or N/A explained)
- [ ] Behavioral tests exercise the changed component boundaries and relevant failure scenarios (or N/A explained)
- [ ] Verification commands, results, and skipped checks are recorded above
- [ ] I have updated documentation where appropriate

## Repository-specific checks

### Testing

- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] ARM64 compatibility verified (if Docker images changed)
- [ ] Terraform plan/apply validated (if infrastructure changed)
- [ ] Security scans pass (gitleaks, IaC policy)
- [ ] Manual verification steps completed (describe below)

#### Manual Verification Steps

1.
2.
3.

### Checklist

- [ ] No secrets, credentials, or sensitive data in commits, diffs, or CI logs
- [ ] Code follows project style guidelines (run linters)
- [ ] Self-review of the code completed
- [ ] Comments added for complex logic
- [ ] Documentation updated (README, docs/, inline comments)
- [ ] CHANGELOG.md updated (if applicable)
- [ ] Dependencies pinned by digest/SHA where applicable
- [ ] Branch protection rules respected (no force push to protected branches)

### Related Issues

Closes #<issue-number>

### Screenshots / Logs (if applicable)

<!-- Add screenshots or relevant log output here -->

### Deployment Notes

<!-- Any special deployment considerations, migration steps, or rollback procedures -->

---

**Reviewer Notes:**
- Infrastructure changes require `@eslam-aboutaleb` review
- Security-sensitive changes (IAM, secrets, network) require explicit approval
- ARM64 image changes must pass native compatibility workflow