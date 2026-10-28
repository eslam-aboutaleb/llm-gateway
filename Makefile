SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c

.PHONY: ci-install ci-quality ci-docs ci-docs-links ci-generated

REQUIRED_DOCS := \
	README.md \
	docs/USER_README.md \
	docs/KEY_POLICY.md \
	docs/ADMIN_KEY_RUNBOOK.md \
	docs/ARCHITECTURE.md \
	docs/DEPLOYMENT.md \
	docs/MONITORING.md \
	docs/BACKUP_RESTORE.md \
	docs/TROUBLESHOOTING.md \
	docs/CONFIGURATION.md \
	docs/UPGRADE.md \
	docs/ROLLBACK.md \
	docs/THREAT_MODEL.md \
	docs/OCI_BOOTSTRAP.md \
	docs/TERRAMATE.md

ci-install:
	@command -v jq >/dev/null 2>&1 || (sudo apt-get update && sudo apt-get install -y jq)
	@if ! command -v yq >/dev/null 2>&1; then \
		sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64 && \
		sudo chmod +x /usr/local/bin/yq; \
	fi
	@command -v shellcheck >/dev/null 2>&1 || (sudo apt-get update && sudo apt-get install -y shellcheck)
	@if [[ "$${CI:-false}" == "true" ]] && ! command -v terraform >/dev/null 2>&1; then \
		curl -fsSL https://releases.hashicorp.com/terraform/1.12.2/terraform_1.12.2_linux_amd64.zip -o /tmp/terraform.zip && \
		sudo unzip -q -o /tmp/terraform.zip -d /usr/local/bin && rm -f /tmp/terraform.zip; \
	fi
	@if [[ "$${CI:-false}" == "true" ]] && ! command -v terramate >/dev/null 2>&1; then \
		curl -fsSL https://github.com/terramate-io/terramate/releases/download/v0.11.6/terramate_0.11.6_linux_x86_64.tar.gz | sudo tar -xz -C /usr/local/bin terramate; \
	fi

ci-quality:
	@echo "==> Checking YAML syntax"
	@while IFS= read -r f; do \
		yq eval '.' "$$f" > /dev/null || { echo "Invalid YAML: $$f"; exit 1; }; \
	done < <(find . \( -name "*.yaml" -o -name "*.yml" \) -not -path './.git/*')
	@echo "==> Checking JSON syntax"
	@while IFS= read -r f; do \
		jq empty "$$f" || { echo "Invalid JSON: $$f"; exit 1; }; \
	done < <(find . -name "*.json" -not -path './.git/*')
	@echo "==> Validating gateway configuration & Compose files"
	@for required_file in gateway/compose.yaml gateway/compose.prod.yaml gateway/caddy/Caddyfile gateway/config/litellm.yaml gateway/config/model-catalog.yaml; do \
		if [[ ! -f "$$required_file" ]]; then \
			echo "Missing required configuration: $$required_file"; exit 1; \
		fi; \
	done
	@if ! grep -q 'reverse_proxy litellm:4000' gateway/caddy/Caddyfile; then \
		echo "Caddyfile must route to the Compose service litellm:4000"; exit 1; \
	fi
	@if grep -qE 'reverse_proxy localhost:4000|reverse_proxy 127\.0\.0\.1:4000' gateway/caddy/Caddyfile; then \
		echo "Caddyfile contains a container-local LiteLLM upstream"; exit 1; \
	fi
	@if grep -rn "REPLACE_WITH_ACTUAL_DIGEST" gateway/; then \
		echo "Placeholder digests found!"; exit 1; \
	fi
	@echo "==> Validating Compose resource limits and security hardening"
	@COMPOSE_CFG=$$(docker compose -f gateway/compose.yaml -f gateway/compose.prod.yaml config); \
	MISSING_LIMITS=$$(printf '%s\n' "$$COMPOSE_CFG" | yq eval '.services | to_entries[] | select(.value.deploy == null or .value.deploy.resources == null) | .key' -); \
	if [[ -n "$$MISSING_LIMITS" ]]; then \
		echo "Services missing resource limits: $$MISSING_LIMITS"; exit 1; \
	fi; \
	MISSING_SEC=$$(printf '%s\n' "$$COMPOSE_CFG" | yq eval '.services | to_entries[] | select(.value.security_opt == null or (.value.security_opt | contains(["no-new-privileges:true"]) | not)) | .key' -); \
	if [[ -n "$$MISSING_SEC" ]]; then \
		echo "Services missing no-new-privileges:true: $$MISSING_SEC"; exit 1; \
	fi
	@echo "==> Scanning tracked configs for hardcoded secrets"
	@for pattern in 'password.*=.*[^$${]' 'api_key.*=.*[^$${]' 'secret.*=.*[^$${]' 'token.*=.*[^$${]' 'BEGIN.*PRIVATE KEY' 'sk-[a-zA-Z0-9]{32,}'; do \
		if grep -rn -i -E "$$pattern" --include="*.yaml" --include="*.yml" --include="*.tf" --include="*.tfvars" --include="*.json" gateway/ infrastructure/ cloud-init/ 2>/dev/null \
			| grep -v "os.environ" | grep -v "env:" | grep -v "FILE" | grep -v '\$${' | grep -v "example" | grep -v ".example" | grep -v "# "; then \
			echo "Potential hardcoded secret found matching $$pattern"; exit 1; \
		fi; \
	done
	@echo "==> Validating model catalog structure"
	@ALIASES=$$(yq eval '.model_aliases | length' gateway/config/model-catalog.yaml); \
	[[ "$$ALIASES" -gt 0 ]] || { echo "No model aliases defined"; exit 1; }; \
	for i in $$(seq 0 $$((ALIASES - 1))); do \
		for field in alias description capabilities approved_providers default_model max_tokens cost_tier enabled; do \
			val=$$(yq eval ".model_aliases[$$i].$$field" gateway/config/model-catalog.yaml); \
			if [[ -z "$$val" || "$$val" == "null" ]]; then \
				echo "Alias at index $$i missing '$$field'"; exit 1; \
			fi; \
		done; \
	done; \
	PROFILES=$$(yq eval '.provider_profiles | length' gateway/config/model-catalog.yaml); \
	[[ "$$PROFILES" -gt 0 ]] || { echo "No provider profiles defined"; exit 1; }; \
	for profile in $$(yq eval '.provider_profiles | keys | .[]' gateway/config/model-catalog.yaml); do \
		for field in litellm_provider model_prefix auth.env_var; do \
			val=$$(yq eval ".provider_profiles.$$profile.$$field" gateway/config/model-catalog.yaml); \
			if [[ -z "$$val" || "$$val" == "null" ]]; then \
				echo "Provider profile $$profile missing '$$field'"; exit 1; \
			fi; \
		done; \
	done
	@if command -v terraform >/dev/null 2>&1; then \
		echo "==> Validating Terraform formatting and modules"; \
		for dir in infrastructure/modules/*/ infrastructure/stacks/oci/production/ infrastructure/bootstrap/; do \
			if [[ -d "$$dir" ]]; then \
				(cd "$$dir" && terraform fmt -check -diff && terraform init -backend=false -input=false >/dev/null && terraform validate); \
			fi; \
		done; \
	fi
	@echo "==> Testing private key alias operations"
	@python3 -m unittest discover -s tests -v
	@echo "All quality checks passed!"

ci-docs:
	@for doc in $(REQUIRED_DOCS); do \
		if [[ ! -f "$$doc" ]]; then \
			echo "Missing required doc: $$doc"; exit 1; \
		fi; \
	done
	@echo "All required documentation files present ($(words $(REQUIRED_DOCS)) files)"

ci-docs-links:
	@python3 -c 'import pathlib, re, sys; \
	files = [pathlib.Path("README.md"), *sorted(pathlib.Path("docs").rglob("*.md"))]; \
	missing = []; \
	pattern = re.compile(r"\[[^\]]+\]\((?!https?://|mailto:|#)([^)#\s]+)"); \
	[missing.append(f"{f}: {m.group(1)}") for f in files for m in pattern.finditer(f.read_text()) if not (f.parent / m.group(1)).exists()]; \
	print(f"Checked {len(files)} markdown files for relative links."); \
	sys.exit("Broken links:\n" + "\n".join(missing) if missing else 0)'

ci-generated:
	@if command -v terramate >/dev/null 2>&1; then \
		terramate fmt --check && terramate generate; \
	else \
		echo "terramate not installed locally; skipping generation step (drift check still runs)"; \
	fi
