"""Add a key-specific model name over an existing allowed gateway deployment.

Run on the gateway host through the private SSH administration channel.
Only the alias map changes; credentials and existing entitlements stay intact.
"""

import json
import re
import shlex
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

BASE_URL = "http://127.0.0.1:4000"
PROTECTED_FIELDS = (
    "user_id", "team_id", "models", "max_budget", "budget_duration", "expires",
    "rpm_limit", "tpm_limit", "max_parallel_requests", "permissions",
)


def master_key():
    for line in Path("/etc/llm-gateway/gateway.env").read_text().splitlines():
        name, separator, value = line.partition("=")
        if separator and name.strip() == "LITELLM_MASTER_KEY":
            parts = shlex.split(value, comments=False)
            if len(parts) == 1 and parts[0]:
                return parts[0]
    raise RuntimeError("Gateway administrator credential is unavailable")


def api(credential, path, payload=None):
    request = urllib.request.Request(
        BASE_URL + path,
        data=None if payload is None else json.dumps(payload).encode(),
        headers={"Authorization": "Bearer " + credential, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"Private gateway API returned HTTP {exc.code}") from None
    except (urllib.error.URLError, ValueError):
        raise RuntimeError("Private gateway API request failed") from None


def aliases_of(info):
    aliases = info.get("aliases") or {}
    if isinstance(aliases, str):
        aliases = json.loads(aliases)
    if not isinstance(aliases, dict):
        raise RuntimeError("Existing model aliases have an invalid format")
    return aliases


def alias_update(info, model_name, target):
    if target not in info.get("models", []):
        raise RuntimeError("Target deployment is not already allowed for this key")
    aliases = aliases_of(info)
    if model_name in aliases and aliases[model_name] != target:
        raise RuntimeError("Requested model name already maps to a different deployment")
    return {**aliases, model_name: target}


def main():
    if len(sys.argv) != 5 or any(
        not re.fullmatch(r"[A-Za-z0-9_.:/-]{1,128}", value) for value in sys.argv[1:]
    ):
        raise RuntimeError("Expected key alias, user ID, model name and target deployment")
    key_alias, user_id, model_name, target = sys.argv[1:]
    credential = master_key()
    query = urllib.parse.urlencode({"key_alias": key_alias, "user_id": user_id, "size": 100})
    matches = api(credential, "/key/list?" + query)
    if matches.get("total_count") != 1 or len(matches.get("keys", [])) != 1:
        raise RuntimeError("Expected exactly one key for the supplied alias and owner")
    token = matches["keys"][0]
    query = urllib.parse.urlencode({"key": token})
    before = api(credential, "/key/info?" + query)["info"]
    if before.get("key_alias") != key_alias or before.get("user_id") != user_id:
        raise RuntimeError("Key ownership did not match the requested operation")
    aliases = alias_update(before, model_name, target)
    if aliases != aliases_of(before):
        api(credential, "/key/update", {"key": token, "aliases": aliases})
    after = api(credential, "/key/info?" + query)["info"]
    if aliases_of(after) != aliases:
        raise RuntimeError("Model alias update did not persist")
    if any(before.get(field) != after.get(field) for field in PROTECTED_FIELDS):
        raise RuntimeError("Key policy changed unexpectedly; review the private administration API")
    print(f"Enabled {model_name} -> {target} for {key_alias} ({user_id}).")
    print("Existing model permissions, budget, expiry and rate limits verified unchanged.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        # Never expose the API response, request headers, key token or env file.
        message = str(exc) if isinstance(exc, RuntimeError) else "Gateway alias operation failed"
        print(message, file=sys.stderr)
        raise SystemExit(1) from None
