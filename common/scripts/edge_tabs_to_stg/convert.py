#!/usr/bin/env python3
"""Convert TabExporter markdown export -> Simple Tab Groups (STG) backup JSON.  # noqa: D213

  Input : markdown produced by the TabExporter Edge/Chrome extension
          (https://github.com/johngibbs/TabExporter)
  Output: JSON consumable by STG's "Restore from JSON file" import.

Usage:
  python3 convert.py tabs-export_2026-05-04_M080000.md -o stg-import.json
  python3 convert.py tabs-export_*.md > stg-import.json

See README.md (alongside this file) for the end-to-end migration workflow.
"""

import argparse
import json
import re
import sys

# TabExporter renders each Chromium tabGroups API color through this display
# map (see TabExporter/popup.js). To round-trip back to STG we have to invert
# it.  STG accepts CSS color strings; the inverted (API) names work fine.
DISPLAY_TO_API = {
    "blue": "blue",
    "pink": "pink",
    "violet": "red",
    "purple": "purple",
    "royal blue": "green",
    "teal": "cyan",
    "orange": "orange",
    "yellow": "yellow",
    "gray": "grey",
    "grey": "grey",
}

GROUP_RE = re.compile(r"^##\s+Group\s+\[([^\]]+)\]:\s*(.*)$")
UNGROUPED_RE = re.compile(r"^##\s+Ungrouped(?:\s+(?:Tabs|#\d+))?\s*$")
TAB_RE = re.compile(r"^\s*-\s+\[(.*)\]\((.+?)\)\s*$")


def parse_markdown(text):
    """
    Yield {color, title, tabs} dicts in encounter order.

    Ungrouped sections become a synthetic group with title 'Ungrouped' and
    color 'grey'; multiple `Ungrouped #N` sections are folded together into
    that single group (preserves all tabs without inventing many groups).
    """
    groups = []
    current = None
    ungrouped = None  # lazily created on first ungrouped section

    for line in text.splitlines():
        m = GROUP_RE.match(line)
        if m:
            display = m.group(1).strip().lower()
            api_color = DISPLAY_TO_API.get(display, "grey")
            current = {"color": api_color, "title": m.group(2).strip(), "tabs": []}
            groups.append(current)
            continue

        if UNGROUPED_RE.match(line):
            if ungrouped is None:
                ungrouped = {"color": "grey", "title": "Ungrouped", "tabs": []}
                groups.append(ungrouped)
            current = ungrouped
            continue

        m = TAB_RE.match(line)
        if m and current is not None:
            current["tabs"].append({"title": m.group(1), "url": m.group(2)})

    return groups


def to_stg_backup(groups, version):
    """
    Build a minimal STG backup.

    Targets STG v5.3.x (the AMO-published stable). Two version-specific things:

    - v5.3.x's import validator requires top-level ``lastCreatedGroupPosition``
      to be a safe integer. Master HEAD (v5.5) dropped this field, but
      including it does not break v5.5 — master's validator only checks
      ``version`` and ``Array.isArray(groups)``.
    - v5.3.x uses *integer* group IDs (1, 2, 3 ...). Master HEAD switched to
      UUIDs. We emit integers for v5.3.x compatibility; if STG ever ships a
      master-style release that requires UUIDs, swap this for ``uuid.uuid4()``.
    """
    stg_groups = [
        {
            "id": i,
            "title": g["title"] or "Untitled",
            "iconColor": g["color"],
            "iconUrl": None,
            "iconViewType": "main-squares",
            "isArchive": False,
            "tabs": [{"url": t["url"], "title": t["title"]} for t in g["tabs"]],
        }
        for i, g in enumerate(groups, start=1)
    ]
    return {
        "version": version,
        "groups": stg_groups,
        "lastCreatedGroupPosition": len(stg_groups),
    }


def main():
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("input", help="TabExporter markdown file")
    ap.add_argument("-o", "--output", help="output JSON path (default: stdout)")
    ap.add_argument(
        "--drop-ungrouped",
        action="store_true",
        help="discard tabs not in any group instead of bundling them into 'Ungrouped'",
    )
    ap.add_argument(
        "--stg-version",
        default="5.3.2",
        help="version string written to the backup file (default: %(default)s; matches the AMO-published STG release)",
    )
    args = ap.parse_args()

    with open(args.input, encoding="utf-8") as f:
        text = f.read()

    groups = parse_markdown(text)
    if args.drop_ungrouped:
        groups = [g for g in groups if g["title"] != "Ungrouped"]

    backup = to_stg_backup(groups, version=args.stg_version)

    payload = json.dumps(backup, indent=2, ensure_ascii=False)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(payload)
        n_tabs = sum(len(g["tabs"]) for g in backup["groups"])
        print(
            f"Wrote {len(backup['groups'])} group(s), {n_tabs} tab(s) -> {args.output}",
            file=sys.stderr,
        )
    else:
        print(payload)


if __name__ == "__main__":
    main()
