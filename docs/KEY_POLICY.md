# Proposed API Key and Acceptable-Use Policy

**Status:** policy proposal; not yet enforced. This file must be reviewed and adopted by the gateway administrator before access is issued.

## Access model

- The gateway is private to approved people/services despite having a public HTTPS inference endpoint.
- Every application/environment has a dedicated LiteLLM virtual key; keys must not be shared across projects or with browser clients.
- Only the administrator can grant key, team or model-management capabilities. Consumer keys are limited to `llm_api_routes` and explicitly allowed model aliases.
- Every grant must record a responsible GitHub identity, team/application, environment, nonsecret issue/request reference, approved models, permitted purposes, start/expiry, rate, concurrency and spend limits.
- The master key is for administrators exclusively and must never be used in consumer code or handed to requesters.

## Proposed default allowances (adjust after measured usage)

| Use | Initial suggested policy |
|---|---|
| Development | Up to 10 RPM / 2,000 TPM, 2 concurrent, USD 5/30d, expiry 30 days |
| Production | Individually approved per measured demand; **no default unlimited** key |
| Embeddings | Explicit approved alias and model/dimension contract |
| Reasoning / higher-cost models | Separate cost review and smaller initial budgets |

These are **proposals**, not promises of access. Actual LiteLLM virtual-key budget enforcement and provider costs can lag; configure upstream-provider account billing limits/alerts as a second control. A 30-day `budget_duration` and a 30-day credential `duration` are separate settings.

## Handling requests

Open the GitHub **Request Gateway Access** issue form; publish no secrets or sensitive documents. If even project metadata is sensitive, ask the administrator to supply a private intake option before submitting. Do not assume email or a ticketing service exists until an actual administrator contact is configured.

Administrator decides approve/reject/request-change based on ownership, purpose, provider capability, data sensitivity and budget. Issue comments may show approved *nonsecret* limits and alias but never key material. Keys are delivered only via an approved one-time secret exchange.

## Expiration, rotation and revocation

- Expire each key by default, and review unneeded/unused keys at least monthly.
- Rotate using a new key, test and switch applications, then revoke old key; shorten overlap when possible.
- Compromised keys are immediately disabled/revoked, irrespective of availability impact. Investigate suspicious usage before reissuing.
- Keep audit records of request, approver, issuance date, changes and revocation time **without exposing the raw key**.

## Request data and privacy

Never log raw keys, prompt/response bodies or unredacted sensitive headers to ordinary application logs. Do not send personally identifying or regulated content until the administrator approves the data handling and upstream-provider policy. A gateway does not automatically make third-party model usage private or free.

## Questions

Start with [USER_README.md](USER_README.md). The administrator's monitored support/security contact must be filled in the root README when the repository is published.
