import contextlib
import importlib.util
import io
import json
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).parents[1] / "scripts/summarize_plan.py"
SPEC = importlib.util.spec_from_file_location("summarize_plan", SCRIPT)
assert SPEC and SPEC.loader
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


class PlanSummaryTests(unittest.TestCase):
    def setUp(self):
        self.plan = {
            "planned_values": {"sensitive": "SHOULD_NEVER_PRINT"},
            "resource_changes": [
                {
                    "address": "seqera_custom_role.view",
                    "type": "seqera_custom_role",
                    "change": {
                        "actions": ["update"],
                        "before": {
                            "name": "nf-core Read Only",
                            "permissions": ["pipeline:read"],
                            "org_id": 846291,
                            "api_token": "DO_NOT_PRINT",
                        },
                        "after": {
                            "name": "nf-core Read Only",
                            "permissions": ["pipeline:read", "workflow:read"],
                            "org_id": 846291,
                            "api_token": "DO_NOT_PRINT",
                        },
                    },
                },
                {
                    "address": 'seqera_team_member.managed["view/alice"]',
                    "type": "seqera_team_member",
                    "change": {
                        "actions": ["delete"],
                        "before": {
                            "member_id": 123456,
                            "email": "private@example.test",
                        },
                        "after": None,
                    },
                },
            ],
        }

    def test_prints_actions_and_custom_role_permission_delta_only(self):
        summary, has_deletions = module.summarize(self.plan)
        self.assertTrue(has_deletions)
        self.assertIn("update: seqera_custom_role.view", summary)
        self.assertIn("role name: nf-core Read Only -> nf-core Read Only", summary)
        self.assertIn("permissions before: pipeline:read", summary)
        self.assertIn("permissions after: pipeline:read, workflow:read", summary)
        self.assertIn("permissions added: workflow:read", summary)
        self.assertIn("delete: seqera_team_member.managed", summary)
        for secret in (
            "SHOULD_NEVER_PRINT",
            "DO_NOT_PRINT",
            "846291",
            "123456",
            "private@example.test",
        ):
            self.assertNotIn(secret, summary)

    def test_rejects_malformed_plan_json_without_echoing_input(self):
        stdout = io.StringIO()
        stderr = io.StringIO()
        with patch.object(sys, "stdin", io.StringIO('{"resource_changes": "secret"}')):
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                status = module.main()
        self.assertEqual(status, 1)
        self.assertEqual(stdout.getvalue(), "")
        self.assertNotIn("secret", stderr.getvalue())

    def test_deletion_gate_blocks_deletes_by_default_and_opens_only_explicitly(self):
        stdout = io.StringIO()
        with (
            patch.object(sys, "stdin", io.StringIO(json.dumps(self.plan))),
            patch.object(sys, "argv", [str(SCRIPT), "--enforce-deletion-gate"]),
            patch.dict(os.environ, {}, clear=True),
        ):
            with contextlib.redirect_stdout(stdout):
                self.assertEqual(module.main(), 2)
        stdout = io.StringIO()
        with (
            patch.object(sys, "stdin", io.StringIO(json.dumps(self.plan))),
            patch.object(sys, "argv", [str(SCRIPT), "--enforce-deletion-gate"]),
            patch.dict(os.environ, {"ALLOW_DELETIONS": "true"}),
        ):
            with contextlib.redirect_stdout(stdout):
                self.assertEqual(module.main(), 0)

    def test_emits_only_a_deletion_boolean_as_job_output(self):
        output_path = Path(__file__).parent / "test-github-output.tmp"
        try:
            with (
                patch.object(sys, "stdin", io.StringIO(json.dumps(self.plan))),
                patch.object(sys, "argv", [str(SCRIPT), "--emit-github-output"]),
                patch.dict(os.environ, {"GITHUB_OUTPUT": str(output_path)}),
            ):
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(module.main(), 0)
            self.assertEqual(
                output_path.read_text(encoding="utf-8").strip(), "has_deletions=true"
            )
        finally:
            output_path.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
