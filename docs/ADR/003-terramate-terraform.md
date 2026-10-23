# ADR-003: Terramate + Terraform for IaC Orchestration

## Status
Accepted

## Date
2026-10-23

## Context
Need Infrastructure as Code tooling for OCI with:
- Multi-environment support (production, future staging)
- DRY configuration across environments
- Code generation for boilerplate (providers, backends)
- Stack ordering and dependencies
- GitOps-friendly (plan/apply separation)
- Terraform 1.12+ OCI native backend support

## Decision
Use **Terramate** to orchestrate **Terraform** stacks.

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Terramate + Terraform** | Stacks, generation, ordering, native TF | Extra tool to learn | **Selected** |
| Terraform Workspaces | Built-in, simple | Single state file, no code gen, no ordering | Rejected |
| Terragrunt | Mature, widely used | HCL-only, no generation, complex | Rejected |
| Pulumi | Real languages, testing | New language, state backend | Rejected |
| Crossplane | K8s-native, GitOps | Requires cluster, overkill | Rejected |
| Raw Terraform | No extra tools | DRY violations, manual backend config | Rejected |

## Consequences

### Positive
- Stacks = independent state (production, staging, etc.)
- Globals = single source of truth for shared config
- Code generation = consistent providers/backends
- `terramate run` = ordered execution across stacks
- Change detection = only plan changed stacks
- GitOps-friendly (PR shows plan per stack)
- Terraform native (no abstraction leak)

### Negative
- Additional tool dependency
- Learning curve for team
- Generated files must be committed or verified in CI
- Stack dependencies not yet needed (single stack)

## Implementation Notes

- One `terramate.tm.hcl` at root with globals
- Each stack in `infrastructure/stacks/<provider>/<env>/`
- `stack.tm.hcl` defines stack metadata
- Generation creates `providers.tf` and `backend.tf` per stack
- Shared modules in `infrastructure/modules/`
- CI runs `terramate generate` → `terramate run -- terraform plan`
- Apply only via protected workflow with approved plan

## References
- Terramate Docs: https://terramate.io/docs/cli/getting-started
- Terramate GitHub Actions: https://terramate.io/docs/cli/automation/github-actions/preview-workflow
- Terraform OCI Backend: https://developer.hashicorp.com/terraform/language/backend/oci