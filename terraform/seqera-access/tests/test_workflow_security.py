import unittest
from pathlib import Path


WORKFLOW = Path(__file__).parents[3] / ".github/workflows/seqera-access.yml"
SOURCE = WORKFLOW.read_text(encoding="utf-8")


class WorkflowTrustBoundaryTests(unittest.TestCase):
    def test_untrusted_pull_request_job_has_no_credentials_or_cloud_permissions(self):
        validation = SOURCE.split("  protected-plan:", 1)[0]
        self.assertIn("  pull_request:", validation)
        self.assertNotIn("secrets.", validation)
        self.assertNotIn("id-token: write", validation)
        self.assertNotIn("pull_request_target:", SOURCE)
        self.assertIn("persist-credentials: false", validation)

    def test_protected_plan_is_disabled_unless_explicitly_enabled(self):
        self.assertIn("default: false", SOURCE)
        self.assertIn("vars.SEQERA_ACCESS_ENABLED", SOURCE)
        self.assertIn('test "$SEQERA_ACCESS_ENABLED" = "true"', SOURCE)
        self.assertIn("vars.SEQERA_ACCESS_ENABLED == 'true'", SOURCE)
        self.assertIn("if: github.event_name == 'push'", SOURCE)
        self.assertIn("environment: seqera-access", SOURCE)
        self.assertIn("environment: seqera-access-apply", SOURCE)
        self.assertIn("seqera-access-state", SOURCE)
        self.assertIn("terraform_wrapper: false", SOURCE)
        self.assertIn("ref: ${{ github.sha }}", SOURCE)
        self.assertIn("terraform test -no-color", SOURCE)
        self.assertIn("seqera-access-pr-{0}", SOURCE)
        self.assertIn(
            "SEQERA_ACCESS_ENABLED: ${{ vars.SEQERA_ACCESS_ENABLED }}", SOURCE
        )
        self.assertNotIn("actions: read", SOURCE)
        self.assertNotIn("actions/variables/SEQERA_ACCESS_ENABLED", SOURCE)

    def test_dispatch_checks_pr_manifest_only_and_never_checks_out_pr_code(self):
        self.assertIn("ref: ${{ github.sha }}", SOURCE)
        self.assertIn('"terraform/seqera-access/members.json"', SOURCE)
        self.assertIn("head_repo", SOURCE)
        self.assertIn("ref={head}", SOURCE)
        self.assertNotIn("ref: ${{ inputs", SOURCE)
        self.assertNotIn("ref: ${{ github.event.pull_request", SOURCE)
        self.assertNotIn("actions/upload-artifact", SOURCE)

    def test_apply_replans_and_applies_only_when_canonical_fingerprint_matches(self):
        apply = SOURCE.split("  apply-reviewed-plan:", 1)[1]
        self.assertIn(
            'terraform plan -input=false -no-color -out="$work/plan.tfplan"', apply
        )
        self.assertIn(
            'terraform apply -input=false -no-color "$work/plan.tfplan"', apply
        )
        self.assertIn('>"$work/plan.log" 2>&1', apply)
        self.assertIn('>"$work/apply.log" 2>&1', apply)
        self.assertIn('actual_fingerprint" != "$EXPECTED_PLAN_FINGERPRINT"', apply)
        self.assertIn('if [ "$SEQERA_ACCESS_ENABLED" != "true" ]', apply)
        self.assertLess(
            apply.index('if [ "$SEQERA_ACCESS_ENABLED" != "true" ]'),
            apply.index("terraform apply -input=false"),
        )
        self.assertIn("python scripts/summarize_plan.py --emit-github-output", SOURCE)
        self.assertIn("Validate merged membership manifest", apply)
        self.assertNotIn("upload-artifact", SOURCE)


if __name__ == "__main__":
    unittest.main()
