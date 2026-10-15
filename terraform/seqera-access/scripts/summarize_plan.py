#!/usr/bin/env python3
"""Render a deliberately small, non-sensitive Terraform plan summary."""

from __future__ import annotations

import json
import os
import sys
from typing import Any


def summarize(plan: Any) -> tuple[str, bool]:
    if not isinstance(plan, dict):
        raise ValueError("plan must be an object")
    changes = plan.get("resource_changes") or []
    if not isinstance(changes, list):
        raise ValueError("resource_changes must be an array")
    if not changes:
        return "No resource changes.", False

    output: list[str] = []
    has_deletions = False
    for resource in changes:
        if not isinstance(resource, dict) or not isinstance(
            resource.get("address"), str
        ):
            raise ValueError("resource change has no valid address")
        change = resource.get("change")
        if not isinstance(change, dict):
            raise ValueError("resource change has no valid change object")
        actions = change.get("actions")
        if not isinstance(actions, list) or any(
            not isinstance(action, str) for action in actions
        ):
            raise ValueError("resource actions must be an array of strings")

        has_deletions |= "delete" in actions
        output.append(f"{','.join(actions)}: {resource['address']}")

        if resource.get("type") == "seqera_custom_role":
            before = change.get("before") or {}
            after = change.get("after") or {}
            if not isinstance(before, dict) or not isinstance(after, dict):
                raise ValueError("custom role values must be objects")
            old_name = before.get("name")
            new_name = after.get("name")
            if any(
                name is not None and not isinstance(name, str)
                for name in (old_name, new_name)
            ):
                raise ValueError("custom role name must be a string")
            if old_name is not None or new_name is not None:
                output.append(
                    f"  role name: {old_name or '(absent)'} -> {new_name or '(absent)'}"
                )
            old_permissions = before.get("permissions") or []
            new_permissions = after.get("permissions") or []
            if not isinstance(old_permissions, list) or not isinstance(
                new_permissions, list
            ):
                raise ValueError("custom role permissions must be arrays")
            if any(
                not isinstance(permission, str)
                for permission in old_permissions + new_permissions
            ):
                raise ValueError("custom role permissions must be strings")
            output.append(
                f"  permissions before: {', '.join(sorted(old_permissions)) or '(none)'}"
            )
            output.append(
                f"  permissions after: {', '.join(sorted(new_permissions)) or '(none)'}"
            )
            added = sorted(set(new_permissions) - set(old_permissions))
            removed = sorted(set(old_permissions) - set(new_permissions))
            if added:
                output.append(f"  permissions added: {', '.join(added)}")
            if removed:
                output.append(f"  permissions removed: {', '.join(removed)}")
    return "\n".join(output), has_deletions


def main() -> int:
    try:
        plan = json.load(sys.stdin)
        summary, has_deletions = summarize(plan)
    except (json.JSONDecodeError, ValueError, TypeError):
        print("Could not safely summarize Terraform plan JSON.", file=sys.stderr)
        return 1

    print(summary)
    if "--emit-github-output" in sys.argv:
        output_path = os.environ.get("GITHUB_OUTPUT")
        if not output_path:
            print("GitHub output path is unavailable.", file=sys.stderr)
            return 1
        with open(output_path, "a", encoding="utf-8") as output:
            print(f"has_deletions={str(has_deletions).lower()}", file=output)
    if (
        "--enforce-deletion-gate" in sys.argv
        and has_deletions
        and os.environ.get("ALLOW_DELETIONS", "").lower() != "true"
    ):
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
