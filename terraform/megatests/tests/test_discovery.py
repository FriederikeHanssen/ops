import importlib.util
import unittest
from pathlib import Path


def load(name):
    path = Path(__file__).parents[1] / "scripts" / f"{name}.py"
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


discovery = load("discover_queues")


class DiscoveryTests(unittest.TestCase):
    def setUp(self):
        self.deployment = {
            "workspace_id": "123",
            "credentials_id": "credential-id",
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
                "cliPath": "/actual/forge/bin/aws",
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

    def test_workload_survives_discovery_for_runtime_configuration(self):
        for workload in ["cpu-fusion", "cpu-s3", "gpu-fusion"]:
            self.deployment["workload"] = workload
            with self.subTest(workload=workload):
                result = discovery.discover(
                    self.deployment,
                    lambda ce_id: self.ce("spot" if ce_id == "spot-id" else "ondemand"),
                )["deployment"]
                self.assertEqual(result["workload"], workload)

    def test_s3_discovery_carries_actual_cli_path(self):
        self.deployment["workload"] = "cpu-s3"
        result = discovery.discover(
            self.deployment,
            lambda ce_id: self.ce("spot" if ce_id == "spot-id" else "ondemand"),
        )["deployment"]
        self.assertEqual(result["spot"]["cli_path"], "/actual/forge/bin/aws")

    def test_s3_discovery_rejects_missing_or_mismatched_cli_path(self):
        self.deployment["workload"] = "cpu-s3"
        ce = self.ce("spot")
        del ce["config"]["cliPath"]
        with self.assertRaisesRegex(ValueError, "AWS CLI path"):
            discovery.extract(self.deployment, "spot", ce)

        def read(ce_id):
            ce = self.ce("spot" if ce_id == "spot-id" else "ondemand")
            if ce_id == "od-id":
                ce["config"]["cliPath"] = "/different/bin/aws"
            return ce

        with self.assertRaisesRegex(ValueError, "same AWS CLI path"):
            discovery.discover(self.deployment, read)

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

    def test_rejects_wrong_resource_identity(self):
        for field, value in [
            ("id", "other-id"),
            ("name", "other-name"),
            ("workspaceId", 456),
            ("credentialsId", "other"),
        ]:
            ce = self.ce("spot")
            ce[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                discovery.extract(self.deployment, "spot", ce)

    def test_requires_queue_head_and_execution_role(self):
        for field in ["computeQueue", "headQueue", "executionRole"]:
            for value in [None, "", 123]:
                ce = self.ce("spot")
                ce["config"][field] = value
                with (
                    self.subTest(field=field, value=value),
                    self.assertRaises(ValueError),
                ):
                    discovery.extract(self.deployment, "spot", ce)

    def test_rejects_same_spot_and_ondemand_queue(self):
        def read(ce_id):
            ce = self.ce("spot" if ce_id == "spot-id" else "ondemand")
            ce["config"]["computeQueue"] = "same-queue"
            return ce

        with self.assertRaisesRegex(ValueError, "must differ"):
            discovery.discover(self.deployment, read)


if __name__ == "__main__":
    unittest.main()
