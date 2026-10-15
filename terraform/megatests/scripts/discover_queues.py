#!/usr/bin/env python3
"""Wait for Forge and export its actual AWS identifiers for the runtime root."""

import argparse
import json
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


def fetch(endpoint, workspace_id, ce_id, token):
    path = f"/compute-envs/{urllib.parse.quote(ce_id, safe='')}"
    query = urllib.parse.urlencode({"workspaceId": workspace_id})
    request = urllib.request.Request(
        f"{endpoint.rstrip('/')}{path}?{query}",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)["computeEnv"]


def extract(deployment, kind, ce):
    expected = deployment["carriers"][kind]
    config = ce["config"]
    if (
        ce["id"] != expected["id"]
        or ce["name"] != expected["name"]
        or str(ce["workspaceId"]) != deployment["workspace_id"]
        or ce["credentialsId"] != deployment["credentials_id"]
        or config["region"] != deployment["region"]
    ):
        raise ValueError(f"Unexpected Forge identity for {kind}")
    queue_name = config.get("computeQueue")
    if not isinstance(queue_name, str) or not re.fullmatch(
        r"[A-Za-z0-9_-]{1,128}", queue_name
    ):
        raise ValueError("Forge did not return a usable compute queue name")
    if kind == "ondemand":
        return {
            "queue_name": queue_name,
            "ce_id": ce["id"],
            "ce_name": ce["name"],
        }
    head_queue = config.get("headQueue")
    if not isinstance(head_queue, str) or not re.fullmatch(
        r"[A-Za-z0-9_-]{1,128}", head_queue
    ):
        raise ValueError("Forge did not return a usable EC2 head queue")
    execution_role = config.get("executionRole")
    if not isinstance(execution_role, str) or not execution_role.strip():
        raise ValueError("Forge did not return an execution role")
    head_job_role = config.get("headJobRole")
    if head_job_role is not None and (
        not isinstance(head_job_role, str) or not head_job_role.strip()
    ):
        raise ValueError("Forge returned an unusable head job role")
    return {
        "queue_name": queue_name,
        "head_queue": head_queue,
        "execution_role": execution_role,
        "head_job_role": head_job_role,
    }


def wait_available(read, deadline, pause=time.sleep, clock=time.monotonic):
    while True:
        ce = read()
        status = ce.get("status")
        if status == "AVAILABLE":
            return ce
        if status in {"ERROR", "INVALID", "DELETED"}:
            raise ValueError(
                f"Compute environment is {status}; inspect its Platform creation log"
            )
        if clock() >= deadline:
            raise TimeoutError("Timed out waiting for the compute environment")
        pause(15)


def discover(deployment, read, timeout=1800, pause=time.sleep, clock=time.monotonic):
    deadline = clock() + timeout
    result = {key: value for key, value in deployment.items() if key != "carriers"}
    for kind in ("spot", "ondemand"):
        ce = wait_available(
            lambda: read(deployment["carriers"][kind]["id"]), deadline, pause, clock
        )
        result[kind] = extract(deployment, kind, ce)
    if result["spot"]["queue_name"] == result["ondemand"]["queue_name"]:
        raise ValueError("Spot and On-Demand queues must differ")
    return {"deployment": result}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--runtime", action="store_true")
    args = parser.parse_args()
    deployment = json.loads(args.input.read_text())
    endpoint = os.environ.get("TOWER_API_ENDPOINT", "https://api.cloud.seqera.io")
    if urllib.parse.urlsplit(endpoint).scheme != "https":
        raise ValueError("Platform endpoint must use HTTPS")
    token = os.environ["TOWER_ACCESS_TOKEN"]
    if args.runtime:
        wait_available(
            lambda: fetch(
                endpoint, deployment["workspace_id"], deployment["spot_ce_id"], token
            ),
            time.monotonic() + 900,
        )
        print("Manual CPU Fusion CE is ready.")
        return
    if args.output is None:
        parser.error("--output is required for Forge discovery")
    payload = discover(
        deployment,
        lambda ce_id: fetch(endpoint, deployment["workspace_id"], ce_id, token),
    )
    args.output.write_text(json.dumps(payload, indent=2) + "\n")
    args.output.chmod(0o600)
    print("Forge CPU Fusion queues are ready; runtime inputs written.")


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as error:
        # Do not dump API bodies/headers, which may contain private metadata.
        raise SystemExit(f"Platform discovery failed with HTTP {error.code}") from None
