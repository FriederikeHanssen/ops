#!/usr/bin/env python3
"""Hash canonical Terraform plan JSON, ignoring only its top-level timestamp."""

from __future__ import annotations

import hashlib
import json
import sys
from typing import Any


def fingerprint(plan: Any) -> str:
    if not isinstance(plan, dict):
        raise ValueError("plan must be a JSON object")
    canonical_plan = {key: value for key, value in plan.items() if key != "timestamp"}
    canonical = json.dumps(
        canonical_plan,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")
    return hashlib.sha256(canonical).hexdigest()


def main() -> int:
    try:
        print(fingerprint(json.load(sys.stdin)))
    except (json.JSONDecodeError, ValueError, TypeError):
        print("Could not fingerprint Terraform plan JSON.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
