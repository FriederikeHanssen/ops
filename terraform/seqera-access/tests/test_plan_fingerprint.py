import importlib.util
import unittest
from copy import deepcopy
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "scripts/plan_fingerprint.py"
SPEC = importlib.util.spec_from_file_location("plan_fingerprint", SCRIPT)
assert SPEC and SPEC.loader
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


class PlanFingerprintTests(unittest.TestCase):
    def setUp(self):
        self.plan = {
            "format_version": "1.2",
            "terraform_version": "1.10.5",
            "timestamp": "2026-10-15T10:00:00Z",
            "variables": {
                "identity_map": {"value": {"alice": "123456"}},
                "workspace_id": {"value": "98765"},
            },
            "planned_values": {
                "root_module": {
                    "resources": [
                        {
                            "address": "seqera_custom_role.view",
                            "values": {"permissions": ["pipeline:read"]},
                        }
                    ]
                }
            },
            "resource_changes": [
                {
                    "address": "seqera_custom_role.view",
                    "change": {
                        "before": {"permissions": ["pipeline:read"]},
                        "after": {"permissions": ["pipeline:read", "workflow:read"]},
                        "actions": ["update"],
                    },
                }
            ],
            "prior_state": {"values": {"root_module": {"resources": []}}},
            "unknown_metadata": {"timestamp": "nested timestamps are significant"},
        }

    def test_only_top_level_timestamp_is_excluded(self):
        updated = deepcopy(self.plan)
        updated["timestamp"] = "2026-10-15T10:05:00Z"
        self.assertEqual(module.fingerprint(self.plan), module.fingerprint(updated))

    def test_identity_before_after_permissions_state_and_inputs_affect_fingerprint(
        self,
    ):
        mutations = [
            (("variables", "identity_map", "value"), {"alice": "654321"}),
            (
                ("resource_changes", 0, "change", "before", "permissions"),
                ["pipeline:write"],
            ),
            (
                ("resource_changes", 0, "change", "after", "permissions"),
                ["pipeline:read"],
            ),
            (
                ("prior_state", "values", "root_module", "resources"),
                [{"address": "sentinel"}],
            ),
            (("variables", "workspace_id", "value"), "11111"),
        ]
        for path, replacement in mutations:
            changed = deepcopy(self.plan)
            target = changed
            for key in path[:-1]:
                target = target[key]
            target[path[-1]] = replacement
            with self.subTest(path=path):
                self.assertNotEqual(
                    module.fingerprint(self.plan), module.fingerprint(changed)
                )

    def test_dictionary_key_order_does_not_change_fingerprint(self):
        reversed_plan = {key: self.plan[key] for key in reversed(list(self.plan))}
        self.assertEqual(
            module.fingerprint(self.plan), module.fingerprint(reversed_plan)
        )

    def test_nested_timestamp_is_not_ignored(self):
        updated = deepcopy(self.plan)
        updated["unknown_metadata"]["timestamp"] = "changed nested value"
        self.assertNotEqual(module.fingerprint(self.plan), module.fingerprint(updated))

    def test_rejects_non_object_and_non_json_values(self):
        with self.assertRaises(ValueError):
            module.fingerprint([])
        with self.assertRaises(ValueError):
            module.fingerprint({"value": float("nan")})


if __name__ == "__main__":
    unittest.main()
