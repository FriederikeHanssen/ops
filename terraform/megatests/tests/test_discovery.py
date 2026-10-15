import importlib.util
import unittest
from copy import deepcopy
from pathlib import Path


def load(name):
    path = Path(__file__).parents[1] / "scripts" / f"{name}.py"
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


discovery = load("discover_queues")
canary = load("prepare_canary")
canary_check = load("check_canary")


class DiscoveryTests(unittest.TestCase):
    def setUp(self):
        self.deployment = {
            "workspace_id": "123",
            "credentials_id": "credential-id",
            "account_id": "123456789012",
            "region": "eu-west-1",
            "work_dir": "s3://test/work",
            "name_prefix": "test",
            "carriers": {
                "spot": {"id": "spot-id", "name": "spot-ce"},
                "ondemand": {"id": "od-id", "name": "od-ce"},
            },
        }

    def ce(self, kind):
        # Names deliberately do not resemble Forge's naming convention.
        name = f"unpredictable-{kind}-queue"
        return {
            **self.deployment["carriers"][kind],
            "workspaceId": 123,
            "credentialsId": "credential-id",
            "status": "AVAILABLE",
            "config": {
                "region": "eu-west-1",
                "workDir": "s3://test/work",
                "computeQueue": name,
                "headQueue": "actual-head",
                "executionRole": "arn:aws:iam::123456789012:role/execution",
                "waveEnabled": True,
                "fusion2Enabled": True,
                "nvnmeStorageEnabled": True,
                "forge": {
                    "type": {"spot": "SPOT", "ondemand": "EC2"}[kind],
                    "fargateHeadEnabled": False,
                    "instanceTypes": ["c6id", "m6id", "r6id"],
                },
                "forgedResources": [
                    {
                        "BatchQueue": f"arn:aws:batch:eu-west-1:123456789012:job-queue/{name}"
                    }
                ],
            },
        }

    def test_uses_returned_names_not_ce_id_convention(self):
        result = discovery.discover(
            self.deployment,
            lambda ce_id: self.ce("spot" if ce_id == "spot-id" else "ondemand"),
        )["deployment"]
        self.assertEqual(result["spot"]["queue_name"], "unpredictable-spot-queue")
        self.assertEqual(
            result["ondemand"]["queue_name"], "unpredictable-ondemand-queue"
        )
        self.assertIsNone(result["spot"]["head_job_role"])
        self.assertNotIn("carriers", result)

    def test_waits_for_forge_instead_of_exporting_empty_queues(self):
        responses = iter([{"status": "CREATING"}, self.ce("spot"), self.ce("ondemand")])
        pauses = []
        discovery.discover(
            self.deployment, lambda _: next(responses), pause=pauses.append
        )
        self.assertEqual(pauses, [15])

    def test_creation_failure_stops_runtime(self):
        with self.assertRaisesRegex(ValueError, "ERROR"):
            discovery.discover(self.deployment, lambda _: {"status": "ERROR"})

    def test_creation_timeout_is_bounded(self):
        times = iter([0, 31])
        with self.assertRaises(TimeoutError):
            discovery.discover(
                self.deployment,
                lambda _: {"status": "CREATING"},
                timeout=30,
                clock=lambda: next(times),
            )

    def test_rejects_fargate_head_and_wrong_workspace(self):
        for field, value in [("workspaceId", 456), ("credentialsId", "other")]:
            ce = self.ce("spot")
            ce[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                discovery.extract(self.deployment, "spot", ce)
        ce = self.ce("spot")
        ce["config"]["forge"]["fargateHeadEnabled"] = True
        with self.assertRaises(ValueError):
            discovery.extract(self.deployment, "spot", ce)

    def test_rejects_wrong_aws_account(self):
        ce = self.ce("spot")
        ce["config"]["forgedResources"][0]["BatchQueue"] = (
            "arn:aws:batch:eu-west-1:999999999999:job-queue/unpredictable-spot-queue"
        )
        with self.assertRaises(ValueError):
            discovery.extract(self.deployment, "spot", ce)

    def test_canary_checks_both_ces_with_run_scoped_outputs(self):
        deployment = deepcopy(self.deployment)
        deployment.update(
            pipeline_name="test-canary",
            spot_ce_name="manual-spot",
            ondemand_ce_name="forge-ondemand",
        )
        launches = canary.launches(deployment, "1234-2")["launch"]
        self.assertEqual(
            [launch["compute-env"] for launch in launches],
            ["manual-spot", "forge-ondemand"],
        )
        self.assertNotEqual(
            launches[0]["params"]["outdir"], launches[1]["params"]["outdir"]
        )
        self.assertTrue(
            all("1234-2" in launch["params"]["outdir"] for launch in launches)
        )


class CanaryResultTests(unittest.TestCase):
    def test_both_runs_must_succeed(self):
        canary_check.validate_summary(
            "✅ status runName\n"
            "🟢 SUCCEEDED cpu-fusion-spot-123-1\n"
            "🟢 SUCCEEDED cpu-fusion-ondemand-123-1\n",
            "123-1",
        )

    def test_failure_or_timeout_makes_the_action_fail(self):
        for status in ["FAILED", "RUNNING", "UNKNOWN"]:
            with self.subTest(status=status), self.assertRaises(ValueError):
                canary_check.validate_summary(
                    "🟢 SUCCEEDED cpu-fusion-spot-123-1\n"
                    f"🔴 {status} cpu-fusion-ondemand-123-1\n",
                    "123-1",
                )

    def test_missing_launch_makes_the_action_fail(self):
        with self.assertRaises(ValueError):
            canary_check.validate_summary(
                "🟢 SUCCEEDED cpu-fusion-spot-123-1\n", "123-1"
            )


if __name__ == "__main__":
    unittest.main()
