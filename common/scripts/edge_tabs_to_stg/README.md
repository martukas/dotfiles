# Edge -> Firefox tab group migration

One-off migration tool: ports tab groups from Microsoft Edge (or any Chromium browser) into Firefox + the
[Simple Tab Groups (STG)](https://addons.mozilla.org/en-US/firefox/addon/simple-tab-groups/) extension, preserving group
titles, group colors, and tab titles/URLs.

## TL;DR for a Claude session on the destination machine

1. Look for a markdown file matching `tabs-export_*.md` either in the migration bundle, alongside this script, or
   wherever the user dropped it. **If no such file exists, this tool has nothing to do** — exit cleanly and tell the
   user.
1. If found, run `python3 convert.py <md-file> -o stg-import.json`.
1. Tell the user to install Simple Tab Groups in Firefox (138+) and use _Settings -> Backup -> Restore from JSON file_
   on `stg-import.json`.

That is the whole job. Do not install the extension for the user, do not open Firefox automatically, do not delete the
markdown after conversion.

## Why this exists

Source machine: Edge with a "work" profile holding a meticulously curated set of tab groups. Target machine: Firefox 150
with STG. Edge stores its session in Chromium SNSS format (binary, fragile to parse). Firefox / STG expect their own
JSON. There is no built-in cross-browser path that preserves tab groups, so the migration is two-stage:

1. **Edge side, manual** — the user runs the [TabExporter](https://github.com/johngibbs/TabExporter) extension, which
   dumps the current window's tabs (with groups) to a structured markdown file.
1. **Firefox side, automated by this script** — `convert.py` parses that markdown into a STG-compatible backup JSON.

## Workflow (full)

### On the source machine, before migrating

1. Install [TabExporter](https://microsoftedge.microsoft.com/addons/detail/nnmgfhilifplgjoefmahapjabedaggep) from the
   Edge Add-ons store into the profile whose tabs you want to migrate.
1. Switch to the target window. Click the TabExporter toolbar icon.
1. Click **Export Current Window Tabs**. Save the file (default name is `tabs-export_YYYY-MM-DD_AHHMMSS.md`).
1. Move that markdown file to the new machine — manually, via the Claude migration bundle, or any other way.

### On the destination machine

```bash
python3 ~/dev/dotfiles/common/scripts/edge_tabs_to_stg/convert.py \
    /path/to/tabs-export_*.md \
    -o stg-import.json
```

Then in Firefox:

1. Install **Simple Tab Groups** from addons.mozilla.org.
1. Open the STG popup -> gear icon -> **Backup** tab.
1. Click **Restore from JSON file** and pick `stg-import.json`.
1. Confirm the restore. STG will create the groups with their original titles, colors, and tabs (placeholders until each
   tab is clicked, same behavior as Edge's lazy-load).

## What's preserved

- Group title
- Group color (Chromium palette: grey/blue/red/yellow/green/pink/purple/cyan/orange)
- Tab URL
- Tab title
- Tab order within each group
- Group order

## What's lost

The TabExporter -> markdown -> JSON pipeline is lossy for everything below. None of these are recoverable from the
markdown alone:

- Pinned tab state — TabExporter doesn't capture it.
- Group collapsed state — likewise.
- Cookies, login sessions, history, scroll position, form state.
- Per-tab Firefox container assignments (we have no source data for these).
- Tabs not in any window at export time (closed/hibernated/synced-only).

## Color mapping note

TabExporter renames Chromium API colors through a display map in its `popup.js` (e.g. `red` is rendered as `violet`,
`green` as `royal blue`, `cyan` as `teal`). `convert.py` reverses that map back to API names so the STG restore matches
the original Edge group color rather than TabExporter's display label. If TabExporter changes its color map upstream,
update `DISPLAY_TO_API` in `convert.py`.

## Options

| Flag                | Default | Effect                                                                                                              |
| ------------------- | ------- | ------------------------------------------------------------------------------------------------------------------- |
| `--drop-ungrouped`  | off     | discard tabs not in any group (default: bundle into "Ungrouped")                                                    |
| `--stg-version VER` | `5.3.2` | version string written to backup; matches the AMO-published STG. See "STG version compatibility" below if changing. |

## STG version compatibility

The output schema targets STG **v5.3.x** (the version published on addons.mozilla.org). Two things are version-specific:

- **`lastCreatedGroupPosition`** (safe-integer, top-level): required by v5.3.x's import validator. Master HEAD (v5.5)
  dropped this field, but including it doesn't break v5.5 — its validator only checks `version` and
  `Array.isArray(groups)`.
- **Integer group IDs (1, 2, 3 ...)**: v5.3.x uses sequential integer IDs. Master HEAD switched to UUIDs and would
  TypeError on integer IDs in some code paths.

If a future STG release ever drops v5.3.x compatibility entirely, swap the group-id generator in `to_stg_backup` for
`uuid.uuid4()` and remove `lastCreatedGroupPosition`.

## Files

- `convert.py` — the markdown -> STG JSON converter (this tool)
- `README.md` — this file

The TabExporter markdown export is **not** stored here; it's expected to arrive separately (migration bundle, manual
copy, etc.).
