#!/usr/bin/env python3
"""Validate the public GitHub-handle membership manifest."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

TEAMS = ("core", "pipeline-maintainers", "view")
HANDLE = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,37}[a-z0-9])?$")


def validate(data: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict) or set(data) != {"teams"}:
        return ['top-level object must contain exactly the "teams" key']
    teams = data["teams"]
    if not isinstance(teams, dict) or set(teams) != set(TEAMS):
        return [f'"teams" must contain exactly: {", ".join(TEAMS)}']

    for team in TEAMS:
        handles = teams[team]
        if not isinstance(handles, list):
            errors.append(f'team "{team}" must be an array')
            continue
        seen_in_team: set[str] = set()
        for index, handle in enumerate(handles):
            label = f"teams.{team}[{index}]"
            if not isinstance(handle, str) or not HANDLE.fullmatch(handle):
                errors.append(f"{label} must be a lowercase GitHub username")
                continue
            if handle in seen_in_team:
                errors.append(f'{label} duplicates handle "{handle}" in team "{team}"')
            else:
                seen_in_team.add(handle)
    return errors


def main() -> int:
    path = (
        Path(sys.argv[1])
        if len(sys.argv) > 1
        else Path(__file__).parents[1] / "members.json"
    )
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"Invalid manifest: {exc}", file=sys.stderr)
        return 1
    errors = validate(data)
    if errors:
        print("Invalid membership manifest:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(
        f"Validated manifest: {sum(len(data['teams'][team]) for team in TEAMS)} unique handles across {len(TEAMS)} teams"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
