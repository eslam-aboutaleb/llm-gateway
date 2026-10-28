# Administrator runbook — LiteLLM virtual key lifecycle

**Status:** implementation template. Commands/endpoints must be verified against the pinned LiteLLM version before using them in production.

## Administrative channel

- Connect via a restricted SSH tunnel or approved private administrative network. Management URLs must never be exposed through the public Caddy inference ingress.
- For a local SSH tunnel, the administrator may forward local port 4000 to the proxy's `127.0.0.1:4000` on the server, after verifying host keys and an authorized account. Access the UI at `http://localhost:4000/ui` over the encrypted tunnel.
- Authenticate to LiteLLM Admin UI with a dedicated secure administrator credential. Never hand the master key to a consumer. Configure `UI_USERNAME` and an independent `UI_PASSWORD` rather than relying on the master key for routine UI login.

## Intake and approval

1. Verify requester and project ownership; resolve any sensitive project details via a **private** method.
2. Record approved team, environment, API routes/model aliases, RPM/TPM/concurrent limits, monthly budget, key expiry, whether user-specific ownership or service account is appropriate, and the GitHub issue reference.
3. Verify upstream-provider terms, quota and data handling and check owner/team budgets; compare requested budget with remaining funds.
4. Create/update a team in LiteLLM when shared spend and common permissions make sense; grant no cross-team permissions.
5. Require an approval comment/status from an authorized reviewer distinct from the requester if feasible.

## Issuing an API key

**Preferred:** Admin UI → Virtual Keys → Create New Key. Provide a unique alias, proper `team_id` and `user_id` (or documented service-account identity semantics), model allowlist, budget/renewal window, rate limits, expiration and **LLM inference routes only**. Note LiteLLM does not automatically stamp admin-created keys with the requester's ownership; the owner has to be set deliberately. Verify the generated key's effective permissions.

**Alternative:** Admin API `POST /key/generate`, reachable only over the private management channel. Example **nonsecret request body** (values are policy examples):

```json
{
  "key_alias": "sample-service-dev-2026-10",
  "user_id": "verified-requester-id",
  "team_id": "approved-team-id",
  "models": ["general-fast"],
  "max_budget": 5,
  "budget_duration": "30d",
  "duration": "30d",
  "rpm_limit": 10,
  "tpm_limit": 2000,
  "max_parallel_requests": 2,
  "allowed_routes": ["llm_api_routes"],
  "metadata": {"request_ref": "GW-ACCESS-123", "environment": "dev"}
}
```

This is a payload example, **not** a ready-made permission grant. Use a valid team ID from the deployed proxy; validate key ownership/route semantics in the pinned release, as key inheritance depends on team and role. Any admin API tooling must suppress request/response secret logging and avoid printing the generated key to CI, issue comments or terminal transcripts. Prefer a local secure key-store integration for one-time delivery.

## Provisioning completion

1. Check key alias, model allowlist and effective entitlements through private Admin UI/API.
2. Verify with a synthetic non-sensitive test: allowed inference returns success; disallowed model rejected; public admin route blocked; `key/generate` is denied for that key.
3. Check spend and rate controls with mocked providers, not real-cost stress testing.
4. Share the secret **one time** through approved private secret-sharing tool, preferably expiring after retrieval. Do not post key values or screenshots to GitHub; issue can say `Approved; securely delivered`.
5. Record delivery acknowledgment, owner, expiry, rotation reminders and a nonsecret audit identifier.

## Accepting an additional model name on an existing key

The pinned proxy supports per-key model aliases. The `set-model-alias` operation
in **Admin Operations** maps an additional client model name to a deployment
already allowed for that key. For the Polymarket key, use:

- `operation`: `set-model-alias`
- `key_identifier`: `polymarket-key`
- `user_id`: `POLYMARKET`
- `model_name`: `gpt-4o-mini`
- `model_target`: `general-fast`

`general-fast` currently deploys `openai/gpt-4o-mini` in
[`litellm.yaml`](../gateway/config/litellm.yaml). This permits clients to request
`gpt-4o-mini` without changing the shared capability alias or other keys.
The script verifies a unique key/owner match, merges existing aliases, rejects
a conflicting mapping or an unauthorized target, and verifies that model
permissions, budget, expiry and rate limits remain unchanged. It uses the private
loopback management API over SSH and never prints credentials or API responses.
A gateway restart is not required; `/key/update` invalidates that key's cache.

## Renewal and rotation

- Requester asks for extension/scope change without sharing the key value. Re-approve new budget/models and expiry.
- Issue replacement key with same or narrower model/route scopes, deliver privately, wait for verified switch, then revoke old key.
- On suspected compromise: block/revoke old key immediately; collect *nonsecret* usage signals and audit unauthorized activity; revoke any affected downstream provider credentials if appropriate; issue a replacement after investigation.
- Reconcile issued keys and spend at least monthly; revoke orphaned and expired credentials.

## Emergency actions and guardrails

- Compromise of **master key** is a platform incident: follow LiteLLM's documented master-key rotation sequence, invalidate all suspect sessions and audit management operations.
- Compromise of **salt key** is not equivalent to an API key leak: it is critical to decrypting DB-held provider credentials. Do not rotate it casually; follow a restore/re-entry plan.
- The database is required for budget enforcement; fail deployment readiness if it is missing. If Redis is critical to hard rate controls, set and test LiteLLM's fail-closed rate-limit mode.
- Do not enable unrestricted user self-service key generation by default. If eventually enabled, require per-role upper bounds and review inherited `allowed_routes` and team membership.

**References:** [LiteLLM virtual keys](https://docs.litellm.ai/docs/proxy/virtual_keys), [budgets](https://docs.litellm.ai/docs/proxy/users), [Admin UI](https://docs.litellm.ai/docs/proxy/ui).
