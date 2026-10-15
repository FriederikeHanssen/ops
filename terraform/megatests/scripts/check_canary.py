#!/usr/bin/env python3
"""Require successful results for both nf-canary launches, not just submission."""

import argparse
from pathlib import Path


def validate_summary(summary, run_id):
    expected = {f"cpu-fusion-{kind}-{run_id}" for kind in ("spot", "ondemand")}
    rows = [
        line.split() for line in summary.splitlines() if line.startswith(("🟢", "🔴"))
    ]
    observed = []
    for row in rows:
        matches = expected.intersection(row)
        if len(matches) != 1 or len(row) < 2 or row[1] != "SUCCEEDED":
            raise ValueError("nf-canary did not succeed on both CPU Fusion CEs")
        observed.extend(matches)
    if len(observed) != 2 or set(observed) != expected:
        raise ValueError("Missing or duplicate CPU Fusion canary results")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work-dir", required=True, type=Path)
    parser.add_argument("--run-id", required=True)
    args = parser.parse_args()
    summaries = {
        path.read_text() for path in args.work_dir.rglob("seqerakit_launch_summary.txt")
    }
    if len(summaries) != 1:
        raise SystemExit("Expected one unambiguous nf-seqerakit launch summary")
    validate_summary(summaries.pop(), args.run_id)
    print("nf-canary succeeded on the Spot and On-Demand CPU Fusion CEs.")
