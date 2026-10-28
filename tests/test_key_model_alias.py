"""Verify targeted alias changes without a live admin credential or model call."""

import importlib.util
import io
import sys
import unittest
from contextlib import redirect_stdout
from copy import deepcopy
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "key_alias", Path(__file__).resolve().parents[1] / "scripts/set-key-model-alias.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ModelAliasTests(unittest.TestCase):
    def test_merges_existing_aliases(self):
        info = {"models": ["general-fast"], "aliases": {"legacy": "general-fast"}}
        self.assertEqual(module.alias_update(info, "gpt-4o-mini", "general-fast"), {
            "legacy": "general-fast", "gpt-4o-mini": "general-fast",
        })
        self.assertEqual(info["aliases"], {"legacy": "general-fast"})

    def test_serialized_aliases_are_supported(self):
        self.assertEqual(module.aliases_of({"aliases": '{"old":"general-fast"}'}), {
            "old": "general-fast",
        })

    def test_cannot_grant_new_upstream_access(self):
        with self.assertRaisesRegex(RuntimeError, "not already allowed"):
            module.alias_update({"models": ["general-fast"]}, "new", "other")

    def test_conflicting_alias_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "different deployment"):
            module.alias_update({"models": ["general-fast"], "aliases": {"new": "other"}},
                                "new", "general-fast")

    def run_operation(self, *, persist=True, count=1):
        state = {
            "key_alias": "polymarket-key", "user_id": "POLYMARKET",
            "models": ["general-fast", "rag-embedding"], "aliases": {},
            "max_budget": 50, "expires": "2027-01-25", "rpm_limit": 60,
            "tpm_limit": 50000,
        }
        payloads = []

        def api(_credential, path, payload=None):
            if path.startswith("/key/list?"):
                return {"total_count": count, "keys": ["synthetic-hash"] * count}
            if path.startswith("/key/info?"):
                return {"info": deepcopy(state)}
            self.assertEqual(path, "/key/update")
            self.assertEqual(set(payload), {"key", "aliases"})
            payloads.append(deepcopy(payload))
            if persist:
                state["aliases"] = deepcopy(payload["aliases"])
            return {}

        args = ["script", "polymarket-key", "POLYMARKET", "gpt-4o-mini", "general-fast"]
        with patch.object(sys, "argv", args), patch.object(module, "master_key", return_value="secret"), \
                patch.object(module, "api", side_effect=api), redirect_stdout(io.StringIO()) as output:
            module.main()
            module.main()
        self.assertNotIn("secret", output.getvalue())
        self.assertNotIn("synthetic-hash", output.getvalue())
        return state, payloads

    def test_only_aliases_change_and_second_run_is_idempotent(self):
        state, payloads = self.run_operation()
        self.assertEqual(len(payloads), 1)
        self.assertEqual(state["aliases"], {"gpt-4o-mini": "general-fast"})
        self.assertEqual(state["max_budget"], 50)
        self.assertEqual(state["models"], ["general-fast", "rag-embedding"])

    def test_failed_persistence_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "did not persist"):
            self.run_operation(persist=False)

    def test_ambiguous_key_match_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "exactly one"):
            self.run_operation(count=2)


if __name__ == "__main__":
    unittest.main()
