#!/usr/bin/env python3
"""Enforce the durable Claude Code settings in common/claude/settings.json on ~/.claude/settings.json.

  apply-settings.py check   exit 0 if every durable key already has its value, else list the drift and exit 1
  apply-settings.py apply   merge the durable keys in; every other key (model, effortLevel, anything Claude Code
                            writes itself) is left as it is

Nested objects merge key by key, so e.g. other entries in enabledPlugins survive.
"""

import json
import os
import sys
import tempfile
from pathlib import Path

DURABLE = Path(__file__).resolve().parent / "settings.json"
TARGET = Path.home() / ".claude" / "settings.json"


def drift(want: dict, have: dict, prefix: str = "") -> list[str]:
    out = []
    for key, value in want.items():
        path = f"{prefix}{key}"
        if isinstance(value, dict) and isinstance(have.get(key), dict):
            out += drift(value, have[key], f"{path}.")
        elif have.get(key, object()) != value:
            out.append(f"{path}: {json.dumps(have.get(key))} -> {json.dumps(value)}")
    return out


def merge(want: dict, have: dict) -> dict:
    for key, value in want.items():
        if isinstance(value, dict) and isinstance(have.get(key), dict):
            merge(value, have[key])
        else:
            have[key] = value
    return have


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in ("check", "apply"):
        print(__doc__, file=sys.stderr)
        return 2
    want = json.loads(DURABLE.read_text())
    have = json.loads(TARGET.read_text()) if TARGET.exists() else {}
    diffs = drift(want, have)

    if sys.argv[1] == "check":
        for d in diffs:
            print(f"drift: {d}", file=sys.stderr)
        return 1 if diffs else 0

    if not diffs:
        print(f"{TARGET}: durable settings already applied")
        return 0
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=TARGET.parent, prefix=".settings.", suffix=".json")
    with os.fdopen(fd, "w") as f:
        json.dump(merge(want, have), f, indent=2)
        f.write("\n")
    os.replace(tmp, TARGET)
    for d in diffs:
        print(f"set {d}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
