#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["ruamel.yaml"]
# ///
"""Push/pull xfconf settings between linux/xfconf-settings.yaml and live xfconf."""

import argparse
import json
import re
import subprocess
import sys
import urllib.request
from io import StringIO
from pathlib import Path
from xml.etree import ElementTree as ET

from ruamel.yaml import YAML as _YAML

SETTINGS_FILE = Path(__file__).resolve().parent / "xfconf-settings.yaml"

_SETTINGS_HEADER = """\
# xfconf owned settings — managed by linux/xfconf.py
# Push: xubu-push reads from live xfconf and updates this file
# Pull: xubu-pull reads this file and applies settings via xfconf-query
# See docs/superpowers/xfconf-design.md for ownership decisions
"""

# Logical plugin name → xfconf plugin type string
PLUGIN_TYPE_MAP = {
    "whiskermenu": "whiskermenu",
    "separator": "separator",
    "systemload": "systemload",
    "tasklist": "tasklist",
    "spring": "separator",
    "systray": "systray",
    "notification-plugin": "notification-plugin",
    "indicator": "indicator",
    "power-manager-plugin": "power-manager-plugin",
    "pulseaudio": "pulseaudio",
    "clock-local": "clock",
    "xkb": "xkb",
    "clock-vilnius": "clock",
    "weather": "weather",
}

# Properties owned per logical plugin name ([] = presence only)
PLUGIN_OWNED_PROPS = {
    "whiskermenu": None,  # handled specially (favorites array)
    "separator": ["style", "expand"],
    "systemload": None,  # handled specially (nested labels)
    "tasklist": ["show-handle", "flat-buttons", "sort-order"],
    "spring": ["style", "expand"],
    "systray": ["menu-is-primary", "show-frame", "square-icons", "size-max", "symbolic-icons", "icon-size"],
    "notification-plugin": [],
    "indicator": ["square-icons"],
    "power-manager-plugin": [],
    "pulseaudio": [],
    "clock-local": ["digital-format", "digital-time-format", "digital-layout", "tooltip-format", "digital-time-font"],
    "xkb": [],
    "clock-vilnius": ["timezone", "digital-date-format", "digital-layout", "digital-time-format", "digital-time-font"],
    "weather": ["msl", "cache-max-age", "power-saving", "round", "single-row",
                "tooltip-style", "theme-dir"],
}

_PANEL_CHANNEL = "xfce4-panel"
_PLUGIN_IDS_PROP = "/panels/panel-1/plugin-ids"

_SHORTCUTS_SECTIONS = [
    ("/commands/custom", ("commands", "custom")),
    ("/xfwm4/custom", ("xfwm4", "custom")),
]


_XFCONF_XML_DIR = Path.home() / ".config/xfce4/xfconf/xfce-perchannel-xml"

STATE_FILE = Path.home() / ".local/state/df-power-profile"


def read_active_profile():
    """Return active profile name ('docked' or 'mobile'), prompting if state file is absent."""
    if STATE_FILE.exists():
        profile = STATE_FILE.read_text().strip()
        if profile in ("docked", "mobile"):
            return profile
        print(f"Warning: {STATE_FILE} contains unrecognised value '{profile}', prompting.")
    while True:
        answer = input("Power profile not set. Choose [docked/mobile]: ").strip().lower()
        if answer in ("docked", "mobile"):
            STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
            STATE_FILE.write_text(answer)
            return answer


def run_xfconf_query(*args):
    return subprocess.run(["xfconf-query"] + list(args), capture_output=True, text=True)


def _xfconf_type_from_xml(channel, prop):
    """Look up a property's type from the xfconf XML file."""
    xml_file = _XFCONF_XML_DIR / f"{channel}.xml"
    if not xml_file.exists():
        return None
    try:
        node = ET.parse(xml_file).getroot()
        for part in (p for p in prop.strip("/").split("/") if p):
            node = next((c for c in node if c.get("name") == part), None)
            if node is None:
                return None
        return node.get("type") or None
    except Exception:
        return None


def xfconf_get(channel, prop):
    """Return (value_str, type_str) for a scalar property, or (None, None) on error."""
    result = run_xfconf_query("-c", channel, "-p", prop, "--verbose")
    if result.returncode != 0:
        return None, None
    line = result.stdout.strip()
    m = re.match(r"Value is an? (\w+): (.*)", line, re.DOTALL)
    if m:
        return m.group(2).strip(), m.group(1)
    # Newer xfconf-query --verbose omits the type prefix; fall back to XML for type
    type_str = _xfconf_type_from_xml(channel, prop) or "string"
    return line, type_str


def xfconf_get_array(channel, prop):
    """Return list of string values for an array property."""
    result = run_xfconf_query("-c", channel, "-p", prop)
    if result.returncode != 0:
        return []
    return [l for l in result.stdout.strip().splitlines() if l and not l.startswith("Value is")]


def xfconf_set(channel, prop, value, type_str, create=False):
    args = ["-c", channel, "-p", prop, "-t", type_str, "-s",
            str(value).lower() if isinstance(value, bool) else str(value)]
    if create:
        args.append("--create")
    run_xfconf_query(*args)


def xfconf_set_array(channel, prop, type_str, values, create=False):
    args = ["-c", channel, "-p", prop, "-a"]
    for v in values:
        args += ["-t", type_str, "-s", str(v)]
    if create:
        args.append("--create")
    run_xfconf_query(*args)


def xfconf_list(channel):
    result = run_xfconf_query("-c", channel, "-l")
    if result.returncode != 0:
        return []
    return [l.strip() for l in result.stdout.strip().splitlines() if l.strip()]


def xfconf_reset_prefix(channel, prefix):
    for prop in xfconf_list(channel):
        if prop.startswith(prefix + "/"):
            run_xfconf_query("-c", channel, "-p", prop, "-r")


def coerce_value(raw, type_str):
    """Convert raw xfconf-query string output to a Python value."""
    if type_str in ("bool",):
        return raw.lower() == "true"
    if type_str in ("int", "uint"):
        return int(raw)
    if type_str in ("double",):
        return float(raw)
    return raw


def yaml_type_to_xfconf(value):
    """Infer xfconf type string from a Python/YAML value."""
    if isinstance(value, bool):
        return "bool"
    if isinstance(value, int):
        return "int"
    if isinstance(value, float):
        return "double"
    return "string"


def load_settings():
    ryaml = _YAML(typ="safe")
    with open(SETTINGS_FILE) as f:
        return ryaml.load(f) or {}


def save_settings(settings):
    ryaml = _YAML()
    ryaml.indent(mapping=2, sequence=4, offset=2)
    ryaml.default_flow_style = False
    buf = StringIO()
    ryaml.dump(settings, buf)
    # ruamel.yaml uses single-quote style; prettier expects double-quote
    yaml_str = re.sub(r"'([^']*)'", r'"\1"', buf.getvalue())
    with open(SETTINGS_FILE, "w") as f:
        f.write(_SETTINGS_HEADER)
        f.write(yaml_str)


def main():
    parser = argparse.ArgumentParser(description="Push/pull xfconf settings")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("push", help="Read owned settings from xfconf and write to YAML")
    sub.add_parser("pull", help="Read YAML and apply owned settings to xfconf")
    sub.add_parser("set-location", help="Detect location via IP and apply to clock, weather, redshift")
    args = parser.parse_args()

    if args.command == "push":
        cmd_push()
    elif args.command == "pull":
        cmd_pull()
    else:
        cmd_set_location()


def cmd_push():
    settings = load_settings()
    print("Pushing keyboard-layout...")
    push_keyboard_layout(settings)
    print("Pushing keyboard-shortcuts...")
    push_keyboard_shortcuts(settings)
    print("Pushing panel...")
    push_panel(settings)
    print("Pushing power-profile...")
    push_power_profile(settings)
    save_settings(settings)
    print(f"Saved to {SETTINGS_FILE}")


def cmd_pull():
    settings = load_settings()
    print("Pulling keyboard-layout...")
    pull_keyboard_layout(settings)
    print("Pulling keyboard-shortcuts...")
    pull_keyboard_shortcuts(settings)
    print("Pulling panel...")
    pull_panel(settings)
    print("Pulling power-profile...")
    pull_power_profile(settings)
    print("Done.")


def push_keyboard_layout(settings):
    channel = "keyboard-layout"
    props = xfconf_list(channel)
    kl = {}
    for prop in props:
        val, type_str = xfconf_get(channel, prop)
        if val is None:
            continue
        coerced = coerce_value(val, type_str)
        # Strip "/Default/" prefix, split remaining path
        parts = prop.strip("/").split("/")[1:]  # drop "Default"
        d = kl
        for part in parts[:-1]:
            d = d.setdefault(part, {})
        d[parts[-1]] = coerced
    settings["keyboard-layout"] = kl


def pull_keyboard_layout(settings):
    channel = "keyboard-layout"
    kl = settings.get("keyboard-layout", {})

    def write_props(d, path_prefix):
        for key, val in d.items():
            path = f"{path_prefix}/{key}"
            if isinstance(val, dict):
                write_props(val, path)
            else:
                type_str = yaml_type_to_xfconf(val)
                str_val = str(val).lower() if isinstance(val, bool) else str(val)
                xfconf_set(channel, path, str_val, type_str, create=True)

    write_props(kl, "/Default")


def push_keyboard_shortcuts(settings):
    channel = "xfce4-keyboard-shortcuts"
    all_props = xfconf_list(channel)
    ks = {"commands": {"custom": {}}, "xfwm4": {"custom": {}}}

    for prop_path, (section, subsection) in _SHORTCUTS_SECTIONS:
        prefix = prop_path + "/"
        for prop in all_props:
            if not prop.startswith(prefix):
                continue
            key = prop[len(prefix):]
            if "/" in key:
                continue  # skip sub-properties like startup-notify
            val, type_str = xfconf_get(channel, prop)
            if val is not None:
                ks[section][subsection][key] = coerce_value(val, type_str)

    settings["keyboard-shortcuts"] = ks


def pull_keyboard_shortcuts(settings):
    channel = "xfce4-keyboard-shortcuts"
    ks = settings.get("keyboard-shortcuts", {})

    for prop_path, (section, subsection) in _SHORTCUTS_SECTIONS:
        xfconf_reset_prefix(channel, prop_path)
        custom = ks.get(section, {}).get(subsection, {})
        for key, val in custom.items():
            prop = f"{prop_path}/{key}"
            type_str = yaml_type_to_xfconf(val)
            xfconf_set(channel, prop, val, type_str, create=True)


def push_panel(settings):
    panel = settings.get("panel", {"order": [], "plugins": {}})
    plugin_ids = get_plugin_ids()

    order = []
    plugins = {}

    for pid in plugin_ids:
        ptype = get_plugin_type(pid)
        if ptype is None:
            continue
        logical = plugin_logical_name(pid, ptype)
        order.append(logical)

        if logical == "whiskermenu":
            favorites = xfconf_get_array(_PANEL_CHANNEL, f"/plugins/plugin-{pid}/favorites")
            plugins[logical] = {"favorites": favorites}
        elif logical == "systemload":
            props = {}
            for sub in ("uptime", "cpu", "memory", "swap", "network"):
                val, _ = get_plugin_prop(pid, f"{sub}/enabled" if sub == "uptime" else f"{sub}/label")
                if val is not None:
                    key = f"{sub}-{'enabled' if sub == 'uptime' else 'label'}"
                    props[key] = val
            plugins[logical] = props
        elif logical == "weather":
            owned = PLUGIN_OWNED_PROPS.get(logical, [])
            props = {}
            all_props_raw = get_plugin_props(pid)
            for k in owned:
                if k in all_props_raw:
                    props[k] = all_props_raw[k]
            all_panel_props = xfconf_list(_PANEL_CHANNEL)
            for section in ("units", "forecast", "scrollbox"):
                section_props = {}
                prefix = f"/plugins/plugin-{pid}/{section}/"
                for prop in all_panel_props:
                    if prop.startswith(prefix):
                        key = prop[len(prefix):]
                        val, type_str = xfconf_get(_PANEL_CHANNEL, prop)
                        if val is not None:
                            section_props[key] = coerce_value(val, type_str)
                if section_props:
                    props[section] = section_props
            plugins[logical] = props
        else:
            owned = PLUGIN_OWNED_PROPS.get(logical, [])
            if owned:
                all_props_raw = get_plugin_props(pid)
                plugins[logical] = {k: all_props_raw[k] for k in owned if k in all_props_raw}
            else:
                plugins[logical] = {}

    panel["order"] = order
    panel["plugins"] = plugins
    settings["panel"] = panel


def push_power_profile(settings):
    profile_name = read_active_profile()
    print(f"  active profile: {profile_name}")
    profiles = settings.get("power-profiles", {})
    active = profiles.get(profile_name, {})

    for channel, keys in active.items():
        prop_prefix = f"/{channel}/" if channel == "xfce4-power-manager" else "/"
        for key, current_val in keys.items():
            prop = f"{prop_prefix}{key.lstrip('/')}"
            if isinstance(current_val, list):
                val = xfconf_get_array(channel, prop)
                if val:
                    active[channel][key] = val
                else:
                    print(f"  WARNING: {channel} {prop} not found in xfconf, keeping YAML value")
            else:
                val, type_str = xfconf_get(channel, prop)
                if val is not None:
                    effective_type = type_str if type_str and type_str != "empty" else yaml_type_to_xfconf(current_val)
                    active[channel][key] = coerce_value(val, effective_type)
                else:
                    print(f"  WARNING: {channel} {prop} not found in xfconf, keeping YAML value")

    profiles[profile_name] = active
    settings["power-profiles"] = profiles


def pull_power_profile(settings):
    profile_name = read_active_profile()
    print(f"  active profile: {profile_name}")
    profiles = settings.get("power-profiles", {})
    active = profiles.get(profile_name, {})

    for channel, keys in active.items():
        prop_prefix = f"/{channel}/" if channel == "xfce4-power-manager" else "/"
        for key, value in keys.items():
            prop = f"{prop_prefix}{key.lstrip('/')}"
            if isinstance(value, list):
                xfconf_set_array(channel, prop, "string", value, create=True)
            else:
                xml_type = _xfconf_type_from_xml(channel, prop)
                type_str = xml_type if xml_type and xml_type != "empty" else yaml_type_to_xfconf(value)
                xfconf_set(channel, prop, value, type_str, create=True)


def pull_panel(settings):
    panel = settings.get("panel", {})
    desired_order = panel.get("order", [])
    plugins_config = panel.get("plugins", {})

    # Build map of logical_name → existing plugin ID
    existing_ids = get_plugin_ids()
    logical_to_id = {}
    for pid in existing_ids:
        ptype = get_plugin_type(pid)
        if ptype is None:
            continue
        logical = plugin_logical_name(pid, ptype)
        logical_to_id[logical] = pid

    # Ensure all desired plugins exist; create missing ones
    final_order_ids = []
    for logical in desired_order:
        if logical not in logical_to_id:
            new_id = create_plugin(logical)
            logical_to_id[logical] = new_id
        final_order_ids.append(logical_to_id[logical])

    # Write per-plugin properties
    for logical in desired_order:
        pid = logical_to_id[logical]
        config = plugins_config.get(logical, {})

        if logical == "whiskermenu":
            favorites = config.get("favorites", [])
            xfconf_set_array(_PANEL_CHANNEL, f"/plugins/plugin-{pid}/favorites",
                             "string", favorites, create=True)
        elif logical == "systemload":
            if config.get("uptime-enabled") is not None:
                xfconf_set(_PANEL_CHANNEL, f"/plugins/plugin-{pid}/uptime/enabled",
                           config["uptime-enabled"], "bool", create=True)
            for sub in ("cpu", "memory", "swap", "network"):
                key = f"{sub}-label"
                if key in config:
                    xfconf_set(_PANEL_CHANNEL, f"/plugins/plugin-{pid}/{sub}/label",
                               config[key], "string", create=True)
        elif logical == "weather":
            owned = PLUGIN_OWNED_PROPS.get(logical, [])
            for k in owned:
                if k in config:
                    type_str = yaml_type_to_xfconf(config[k])
                    xfconf_set(_PANEL_CHANNEL, f"/plugins/plugin-{pid}/{k}",
                               config[k], type_str, create=True)
            for section in ("units", "forecast", "scrollbox"):
                if section in config:
                    for k, v in config[section].items():
                        type_str = yaml_type_to_xfconf(v)
                        xfconf_set(_PANEL_CHANNEL, f"/plugins/plugin-{pid}/{section}/{k}",
                                   v, type_str, create=True)
        else:
            owned = PLUGIN_OWNED_PROPS.get(logical, [])
            for k in owned:
                if k in config:
                    type_str = yaml_type_to_xfconf(config[k])
                    xfconf_set(_PANEL_CHANNEL, f"/plugins/plugin-{pid}/{k}",
                               config[k], type_str, create=True)

    # Rebuild plugin-ids array in desired order
    xfconf_set_array(_PANEL_CHANNEL, _PLUGIN_IDS_PROP, "int",
                     [str(i) for i in final_order_ids], create=True)


def get_plugin_ids():
    return [int(v) for v in xfconf_get_array(_PANEL_CHANNEL, _PLUGIN_IDS_PROP)]


def get_plugin_type(plugin_id):
    val, _ = xfconf_get(_PANEL_CHANNEL, f"/plugins/plugin-{plugin_id}")
    return val


def get_plugin_prop(plugin_id, prop_name):
    val, type_str = xfconf_get(_PANEL_CHANNEL, f"/plugins/plugin-{plugin_id}/{prop_name}")
    if val is None:
        return None, None
    return coerce_value(val, type_str), type_str


def get_plugin_props(plugin_id):
    """Return dict of all scalar properties for a plugin (no nested paths)."""
    all_props = xfconf_list(_PANEL_CHANNEL)
    prefix = f"/plugins/plugin-{plugin_id}/"
    result = {}
    for prop in all_props:
        if not prop.startswith(prefix):
            continue
        key = prop[len(prefix):]
        if "/" in key:
            continue
        val, type_str = xfconf_get(_PANEL_CHANNEL, prop)
        if val is not None:
            result[key] = coerce_value(val, type_str)
    return result


def plugin_logical_name(plugin_id, plugin_type):
    """Map a plugin's xfconf type to its logical name, disambiguating multi-instance types."""
    if plugin_type == "separator":
        props = get_plugin_props(plugin_id)
        return "spring" if props.get("expand") else "separator"
    if plugin_type == "clock":
        props = get_plugin_props(plugin_id)
        return "clock-vilnius" if props.get("timezone") == "Europe/Vilnius" else "clock-local"
    return plugin_type


def next_plugin_id():
    """Return the next unused plugin ID."""
    all_props = xfconf_list(_PANEL_CHANNEL)
    used = set()
    for prop in all_props:
        m = re.match(r"/plugins/plugin-(\d+)", prop)
        if m:
            used.add(int(m.group(1)))
    return max(used, default=0) + 1


def create_plugin(logical_name):
    """Create a new panel plugin of the given logical type. Returns new plugin ID."""
    xfconf_type = PLUGIN_TYPE_MAP[logical_name]
    new_id = next_plugin_id()
    run_xfconf_query("-c", _PANEL_CHANNEL, "-p", f"/plugins/plugin-{new_id}",
                     "-t", "string", "-s", xfconf_type, "--create")
    return new_id


def cmd_set_location():
    print("Querying location from ipinfo.io...")
    try:
        with urllib.request.urlopen("https://ipinfo.io/json", timeout=10) as resp:
            data = json.loads(resp.read())
    except Exception as e:
        print(f"Error fetching location: {e}", file=sys.stderr)
        sys.exit(1)

    import time
    lat, lon = data["loc"].split(",")
    city = data.get("city", "")
    timezone = data["timezone"]
    print(f"Location: {city}, tz: {timezone}, coords: {lat},{lon}")

    print("Updating redshift config...")
    _set_location_redshift(lat, lon)

    panel_was_running = subprocess.run(["pgrep", "-x", "xfce4-panel"],
                                       capture_output=True).returncode == 0
    if panel_was_running:
        # The weather plugin writes its in-memory state (including stale location) back
        # to xfconf on graceful exit. SIGKILL prevents that write-back.
        print("Stopping panel (SIGKILL to skip stale location write-back)...")
        subprocess.run(["pkill", "-9", "-x", "xfce4-panel"])

    print("Applying XFCE settings...")
    _set_location_xfce(city, lat, lon, timezone)

    if panel_was_running:
        print("Restarting panel...")
        panel_restart_time = time.monotonic()
        subprocess.Popen(["xfce4-panel"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        # Wait for the panel to settle, then bounce the weather wrapper —
        # it sometimes misses its first fetch after an abrupt restart.
        elapsed = time.monotonic() - panel_restart_time
        time.sleep(max(0.0, 4.0 - elapsed))
        subprocess.run(["pkill", "-f", "wrapper.*libweather"], capture_output=True)
        print("Weather plugin bounced.")

    print("Done.")


def _set_location_xfce(city, lat, lon, timezone):
    # clock-local: the clock that isn't the Vilnius one
    for pid in get_plugin_ids():
        if get_plugin_type(pid) == "clock":
            tz = run_xfconf_query("-c", _PANEL_CHANNEL, "-p",
                                  f"/plugins/plugin-{pid}/timezone").stdout.strip()
            if tz != "Europe/Vilnius":
                xfconf_set(_PANEL_CHANNEL, f"/plugins/plugin-{pid}/timezone",
                           timezone, "string", create=True)
                print(f"  clock-local timezone → {timezone}")
                break
    else:
        print("  WARNING: clock-local plugin not found", file=sys.stderr)

    for pid in get_plugin_ids():
        if get_plugin_type(pid) == "weather":
            base = f"/plugins/plugin-{pid}"
            xfconf_set(_PANEL_CHANNEL, f"{base}/timezone", timezone, "string", create=True)
            xfconf_set(_PANEL_CHANNEL, f"{base}/location/name", city, "string", create=True)
            xfconf_set(_PANEL_CHANNEL, f"{base}/location/latitude", lat, "string", create=True)
            xfconf_set(_PANEL_CHANNEL, f"{base}/location/longitude", lon, "string", create=True)
            print(f"  weather location → {city} ({lat}, {lon}), timezone → {timezone}")
            break
    else:
        print("  WARNING: weather plugin not found — skipped", file=sys.stderr)


def _set_location_redshift(lat, lon):
    dest = Path.home() / ".config/redshift.conf"

    current_temp = 4200
    if dest.exists() and not dest.is_symlink():
        m = re.search(r"(?m)^temp-night=(\d+)", dest.read_text())
        if m:
            current_temp = int(m.group(1))

    answer = input(f"  temp-night [{current_temp}]: ").strip()
    temp_night = int(answer) if answer else current_temp

    dest.write_text(
        f"[redshift]\n"
        f"temp-night={temp_night}\n"
        f"location-provider=manual\n"
        f"\n"
        f"[manual]\n"
        f"lat={lat}\n"
        f"lon={lon}\n"
    )
    print(f"  redshift: location → ({lat}, {lon}), temp-night → {temp_night}")


if __name__ == "__main__":
    main()
