import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).parents[1]
SPEC = importlib.util.spec_from_file_location(
    "validate_manifest", ROOT / "scripts/validate_manifest.py"
)
assert SPEC and SPEC.loader
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


class ManifestValidationTests(unittest.TestCase):
    def test_accepts_exact_team_schema_and_empty_teams(self):
        self.assertEqual(
            module.validate(
                {"teams": {"core": [], "pipeline-maintainers": [], "view": []}}
            ),
            [],
        )

    def test_accepts_valid_lowercase_handles(self):
        value = {
            "teams": {
                "core": ["alice", "a-9"],
                "pipeline-maintainers": ["pipeline-maintainer"],
                "view": ["viewer"],
            }
        }
        self.assertEqual(module.validate(value), [])

    def test_rejects_extra_or_missing_team_names(self):
        self.assertTrue(module.validate({"teams": {"core": [], "view": []}}))
        self.assertTrue(
            module.validate(
                {
                    "teams": {
                        "core": [],
                        "pipeline-maintainers": [],
                        "view": [],
                        "admin": [],
                    }
                }
            )
        )

    def test_rejects_non_arrays_and_invalid_or_mixed_case_handles(self):
        value = {
            "teams": {
                "core": "alice",
                "pipeline-maintainers": ["Alice", "bad_name", "-alice", "alice-"],
                "view": [],
            }
        }
        errors = module.validate(value)
        self.assertEqual(len(errors), 5)

    def test_allows_membership_in_multiple_teams(self):
        value = {
            "teams": {"core": ["alice"], "pipeline-maintainers": [], "view": ["alice"]}
        }
        self.assertEqual(module.validate(value), [])

    def test_rejects_duplicate_handle_within_one_team(self):
        value = {
            "teams": {
                "core": ["alice", "alice"],
                "pipeline-maintainers": [],
                "view": [],
            }
        }
        self.assertIn("duplicates handle", " ".join(module.validate(value)))

    def test_rejects_non_object_and_unexpected_fields(self):
        self.assertTrue(module.validate([]))
        self.assertTrue(
            module.validate(
                {
                    "teams": {"core": [], "pipeline-maintainers": [], "view": []},
                    "users": [],
                }
            )
        )


if __name__ == "__main__":
    unittest.main()
