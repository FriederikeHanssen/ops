#!/usr/bin/env python3
"""Generate CPU Fusion canary launches from Terraform output (JSON is YAML)."""

import argparse
import json
from pathlib import Path


def launches(deployment, run_id):
    return {
        "launch": [
            {
                "name": f"cpu-fusion-{kind}-{run_id}",
                "workspace": deployment["workspace_id"],
                "compute-env": deployment[f"{kind}_ce_name"],
                "work-dir": deployment["work_dir"],
                "pipeline": deployment["pipeline_name"],
                "params": {
                    "outdir": f"{deployment['work_dir']}/canary/{run_id}/{kind}/results",
                    "remoteFile": "https://raw.githubusercontent.com/seqeralabs/nf-canary/0.2.0/README.md",
                },
            }
            for kind in ("spot", "ondemand")
        ]
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--run-id", required=True)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(launches(json.loads(args.input.read_text()), args.run_id), indent=2)
        + "\n"
    )
