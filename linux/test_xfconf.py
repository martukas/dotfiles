import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import xfconf


def make_result(stdout="", returncode=0):
    r = MagicMock()
    r.stdout = stdout
    r.returncode = returncode
    return r


class TestXfconfGet:
    def test_parses_string_value(self):
        with patch("xfconf.subprocess.run", return_value=make_result("Value is a string: us,lt")):
            val, type_str = xfconf.xfconf_get("keyboard-layout", "/Default/XkbLayout")
        assert val == "us,lt"
        assert type_str == "string"

    def test_parses_bool_value(self):
        with patch("xfconf.subprocess.run", return_value=make_result("Value is a bool: false")):
            val, type_str = xfconf.xfconf_get("keyboard-layout", "/Default/XkbDisable")
        assert val == "false"
        assert type_str == "bool"

    def test_returns_none_on_error(self):
        with patch("xfconf.subprocess.run", return_value=make_result("", returncode=1)):
            val, type_str = xfconf.xfconf_get("keyboard-layout", "/Missing")
        assert val is None
        assert type_str is None

    def test_falls_back_to_xml_type_when_no_prefix(self):
        with patch("xfconf.subprocess.run", return_value=make_result("true")), \
             patch("xfconf._xfconf_type_from_xml", return_value="bool"):
            val, type_str = xfconf.xfconf_get("xfce4-panel", "/plugins/plugin-5/square-icons")
        assert val == "true"
        assert type_str == "bool"

    def test_falls_back_to_string_when_xml_returns_none(self):
        with patch("xfconf.subprocess.run", return_value=make_result("foo")), \
             patch("xfconf._xfconf_type_from_xml", return_value=None):
            val, type_str = xfconf.xfconf_get("some-channel", "/some/prop")
        assert val == "foo"
        assert type_str == "string"


class TestXfconfGetArray:
    def test_parses_array(self):
        output = "Value is an array with 3 items:\n\n1\n2\n3\n"
        with patch("xfconf.subprocess.run", return_value=make_result(output)):
            vals = xfconf.xfconf_get_array("xfce4-panel", "/panels/panel-1/plugin-ids")
        assert vals == ["1", "2", "3"]

    def test_returns_empty_on_error(self):
        with patch("xfconf.subprocess.run", return_value=make_result("", returncode=1)):
            vals = xfconf.xfconf_get_array("xfce4-panel", "/panels/panel-1/plugin-ids")
        assert vals == []


class TestCoerceValue:
    def test_bool_true(self):
        assert xfconf.coerce_value("true", "bool") is True

    def test_bool_false(self):
        assert xfconf.coerce_value("false", "bool") is False

    def test_int(self):
        assert xfconf.coerce_value("42", "int") == 42

    def test_uint(self):
        assert xfconf.coerce_value("22", "uint") == 22

    def test_string(self):
        assert xfconf.coerce_value("us,lt", "string") == "us,lt"


class TestYamlTypeToXfconf:
    def test_bool(self):
        assert xfconf.yaml_type_to_xfconf(True) == "bool"

    def test_int(self):
        assert xfconf.yaml_type_to_xfconf(42) == "int"

    def test_string(self):
        assert xfconf.yaml_type_to_xfconf("hello") == "string"

    def test_float(self):
        assert xfconf.yaml_type_to_xfconf(1.5) == "double"


class TestPushKeyboardLayout:
    def test_reads_all_props_and_builds_nested_dict(self):
        props = [
            "/Default/XkbDisable",
            "/Default/XkbLayout",
            "/Default/XkbOptions/Compose",
            "/Default/XkbOptions/Group",
            "/Default/XkbVariant",
        ]
        get_returns = {
            "/Default/XkbDisable": ("false", "bool"),
            "/Default/XkbLayout": ("us,lt", "string"),
            "/Default/XkbOptions/Compose": ("compose:ralt", "string"),
            "/Default/XkbOptions/Group": ("grp:lalt_lshift_toggle", "string"),
            "/Default/XkbVariant": (",", "string"),
        }

        with patch("xfconf.xfconf_list", return_value=props), \
             patch("xfconf.xfconf_get", side_effect=lambda c, p: get_returns[p]):
            settings = {}
            xfconf.push_keyboard_layout(settings)

        kl = settings["keyboard-layout"]
        assert kl["XkbDisable"] is False
        assert kl["XkbLayout"] == "us,lt"
        assert kl["XkbOptions"]["Compose"] == "compose:ralt"
        assert kl["XkbOptions"]["Group"] == "grp:lalt_lshift_toggle"
        assert kl["XkbVariant"] == ","


class TestPullKeyboardLayout:
    def test_writes_all_props_to_xfconf(self):
        settings = {
            "keyboard-layout": {
                "XkbDisable": False,
                "XkbLayout": "us,lt",
                "XkbVariant": ",",
                "XkbOptions": {
                    "Group": "grp:lalt_lshift_toggle",
                    "Compose": "compose:ralt",
                },
            }
        }
        calls = []
        with patch("xfconf.xfconf_set", side_effect=lambda *a, **kw: calls.append((a, kw))):
            xfconf.pull_keyboard_layout(settings)

        paths = [c[0][1] for c in calls]
        assert "/Default/XkbDisable" in paths
        assert "/Default/XkbLayout" in paths
        assert "/Default/XkbOptions/Group" in paths
        assert "/Default/XkbOptions/Compose" in paths
        assert "/Default/XkbVariant" in paths

        bool_call = next(c for c in calls if c[0][1] == "/Default/XkbDisable")
        assert bool_call[0][3] == "bool"
        assert bool_call[0][2] == "false"


class TestPushKeyboardShortcuts:
    def test_reads_commands_custom_and_xfwm4_custom(self):
        commands_props = [
            "/commands/custom/<Primary>Escape",
            "/commands/custom/Print",
            "/commands/custom/<Alt>F3",
            "/commands/custom/<Alt>F3/startup-notify",  # sub-property, should be skipped
        ]
        xfwm4_props = [
            "/xfwm4/custom/<Alt>F11",
            "/xfwm4/custom/override",
        ]

        def mock_list(channel):
            return commands_props + xfwm4_props

        def mock_get(channel, prop):
            mapping = {
                "/commands/custom/<Primary>Escape": ("xfce4-popup-whiskermenu", "string"),
                "/commands/custom/Print": ("flameshot gui", "string"),
                "/commands/custom/<Alt>F3": ("xfce4-appfinder", "string"),
                "/xfwm4/custom/<Alt>F11": ("fullscreen_key", "string"),
                "/xfwm4/custom/override": ("true", "bool"),
            }
            return mapping.get(prop, (None, None))

        with patch("xfconf.xfconf_list", side_effect=mock_list), \
             patch("xfconf.xfconf_get", side_effect=mock_get):
            settings = {}
            xfconf.push_keyboard_shortcuts(settings)

        ks = settings["keyboard-shortcuts"]
        assert ks["commands"]["custom"]["<Primary>Escape"] == "xfce4-popup-whiskermenu"
        assert ks["commands"]["custom"]["Print"] == "flameshot gui"
        assert ks["commands"]["custom"]["<Alt>F3"] == "xfce4-appfinder"
        assert "<Alt>F3/startup-notify" not in ks["commands"]["custom"]
        assert ks["xfwm4"]["custom"]["<Alt>F11"] == "fullscreen_key"
        assert ks["xfwm4"]["custom"]["override"] is True


class TestPullKeyboardShortcuts:
    def test_writes_custom_sections(self):
        settings = {
            "keyboard-shortcuts": {
                "commands": {
                    "custom": {
                        "<Primary>Escape": "xfce4-popup-whiskermenu",
                        "Print": "flameshot gui",
                    }
                },
                "xfwm4": {
                    "custom": {
                        "<Alt>F11": "fullscreen_key",
                    }
                },
            }
        }
        calls = []
        with patch("xfconf.xfconf_set", side_effect=lambda *a, **kw: calls.append(a)):
            xfconf.pull_keyboard_shortcuts(settings)

        written = {c[1]: c[2] for c in calls}
        assert written["/commands/custom/<Primary>Escape"] == "xfce4-popup-whiskermenu"
        assert written["/commands/custom/Print"] == "flameshot gui"
        assert written["/xfwm4/custom/<Alt>F11"] == "fullscreen_key"


class TestGetPluginIds:
    def test_returns_list_of_ints(self):
        with patch("xfconf.xfconf_get_array", return_value=["1", "2", "3"]):
            ids = xfconf.get_plugin_ids()
        assert ids == [1, 2, 3]

    def test_returns_empty_list_when_none(self):
        with patch("xfconf.xfconf_get_array", return_value=[]):
            ids = xfconf.get_plugin_ids()
        assert ids == []


class TestGetPluginType:
    def test_returns_type_string(self):
        with patch("xfconf.xfconf_get", return_value=("whiskermenu", "string")):
            t = xfconf.get_plugin_type(1)
        assert t == "whiskermenu"

    def test_returns_none_on_missing(self):
        with patch("xfconf.xfconf_get", return_value=(None, None)):
            t = xfconf.get_plugin_type(99)
        assert t is None


class TestPluginLogicalName:
    def test_separator_with_expand_false(self):
        props = {"expand": False, "style": 0}
        with patch("xfconf.get_plugin_props", return_value=props):
            name = xfconf.plugin_logical_name(2, "separator")
        assert name == "separator"

    def test_separator_with_expand_true(self):
        props = {"expand": True, "style": 0}
        with patch("xfconf.get_plugin_props", return_value=props):
            name = xfconf.plugin_logical_name(4, "separator")
        assert name == "spring"

    def test_clock_vilnius(self):
        props = {"timezone": "Europe/Vilnius", "digital-time-format": "VNO %R"}
        with patch("xfconf.get_plugin_props", return_value=props):
            name = xfconf.plugin_logical_name(12, "clock")
        assert name == "clock-vilnius"

    def test_clock_local(self):
        props = {"digital-format": " %d %b, %H:%M "}
        with patch("xfconf.get_plugin_props", return_value=props):
            name = xfconf.plugin_logical_name(10, "clock")
        assert name == "clock-local"

    def test_other_type_returns_type(self):
        props = {}
        with patch("xfconf.get_plugin_props", return_value=props):
            name = xfconf.plugin_logical_name(1, "whiskermenu")
        assert name == "whiskermenu"


class TestPushPanel:
    def test_reads_plugin_order_and_owned_props(self):
        plugin_ids = [1, 2, 3]
        plugin_types = {1: "whiskermenu", 2: "separator", 3: "clock"}
        plugin_logical = {
            (1, "whiskermenu"): "whiskermenu",
            (2, "separator"): "separator",
            (3, "clock"): "clock-vilnius",
        }
        whiskermenu_favorites = ["xfce4-file-manager.desktop", "slack_slack.desktop"]
        separator_props = {"style": 0, "expand": False}
        clock_props = {"timezone": "Europe/Vilnius", "digital-time-format": "VNO %R",
                       "digital-layout": 3, "digital-time-font": "Sans 10",
                       "digital-date-format": "%d %b %Y"}

        def mock_get_props(plugin_id):
            if plugin_id == 1:
                return {}
            if plugin_id == 2:
                return separator_props
            if plugin_id == 3:
                return clock_props

        settings = {
            "panel": {
                "order": ["whiskermenu", "separator", "clock-vilnius"],
                "plugins": {
                    "whiskermenu": {"favorites": whiskermenu_favorites},
                    "separator": {"style": 0, "expand": False},
                    "clock-vilnius": {},
                }
            }
        }

        with patch("xfconf.get_plugin_ids", return_value=plugin_ids), \
             patch("xfconf.get_plugin_type", side_effect=lambda pid: plugin_types[pid]), \
             patch("xfconf.plugin_logical_name", side_effect=lambda pid, t: plugin_logical[(pid, t)]), \
             patch("xfconf.get_plugin_props", side_effect=mock_get_props), \
             patch("xfconf.xfconf_get_array", return_value=["xfce4-file-manager.desktop", "slack_slack.desktop"]):
            xfconf.push_panel(settings)

        plugins = settings["panel"]["plugins"]
        assert plugins["separator"]["expand"] is False
        assert plugins["clock-vilnius"]["timezone"] == "Europe/Vilnius"
        assert "xfce4-file-manager.desktop" in plugins["whiskermenu"]["favorites"]
        assert settings["panel"]["order"] == ["whiskermenu", "separator", "clock-vilnius"]

    def test_reads_systemload_labels(self):
        plugin_ids = [1]
        plugin_types = {1: "systemload"}
        plugin_logical = {(1, "systemload"): "systemload"}

        def mock_get_prop(pid, prop_name):
            mapping = {
                "uptime/enabled": (True, "bool"),
                "cpu/label": ("P", "string"),
                "memory/label": ("M", "string"),
                "swap/label": ("S", "string"),
                "network/label": ("N", "string"),
            }
            return mapping.get(prop_name, (None, None))

        settings = {"panel": {"order": [], "plugins": {}}}

        with patch("xfconf.get_plugin_ids", return_value=plugin_ids), \
             patch("xfconf.get_plugin_type", side_effect=lambda pid: plugin_types[pid]), \
             patch("xfconf.plugin_logical_name", side_effect=lambda pid, t: plugin_logical[(pid, t)]), \
             patch("xfconf.get_plugin_prop", side_effect=lambda pid, p: mock_get_prop(pid, p)):
            xfconf.push_panel(settings)

        plugins = settings["panel"]["plugins"]
        assert plugins["systemload"]["cpu-label"] == "P"
        assert plugins["systemload"]["memory-label"] == "M"
        assert plugins["systemload"]["swap-label"] == "S"
        assert plugins["systemload"]["network-label"] == "N"
        assert plugins["systemload"]["uptime-enabled"] is True

    def test_reads_weather_owned_and_nested_props(self):
        plugin_ids = [1]
        plugin_types = {1: "weather"}
        plugin_logical = {(1, "weather"): "weather"}

        weather_scalar_props = {
            "msl": 18,
            "timezone": "America/Los_Angeles",
            "round": True,
        }

        all_panel_props_list = [
            "/plugins/plugin-1/units/temperature",
            "/plugins/plugin-1/units/windspeed",
            "/plugins/plugin-1/forecast/days",
            "/plugins/plugin-1/scrollbox/show",
        ]

        def mock_xfconf_get(channel, prop):
            mapping = {
                "/plugins/plugin-1/units/temperature": ("0", "int"),
                "/plugins/plugin-1/units/windspeed": ("4", "int"),
                "/plugins/plugin-1/forecast/days": ("5", "int"),
                "/plugins/plugin-1/scrollbox/show": ("true", "bool"),
            }
            return mapping.get(prop, (None, None))

        settings = {"panel": {"order": [], "plugins": {}}}

        with patch("xfconf.get_plugin_ids", return_value=plugin_ids), \
             patch("xfconf.get_plugin_type", side_effect=lambda pid: plugin_types[pid]), \
             patch("xfconf.plugin_logical_name", side_effect=lambda pid, t: plugin_logical[(pid, t)]), \
             patch("xfconf.get_plugin_props", return_value=weather_scalar_props), \
             patch("xfconf.xfconf_list", return_value=all_panel_props_list), \
             patch("xfconf.xfconf_get", side_effect=mock_xfconf_get):
            xfconf.push_panel(settings)

        plugins = settings["panel"]["plugins"]
        assert plugins["weather"]["msl"] == 18
        assert plugins["weather"]["round"] is True
        assert plugins["weather"]["units"]["temperature"] == 0
        assert plugins["weather"]["forecast"]["days"] == 5
        assert plugins["weather"]["scrollbox"]["show"] is True


class TestPullPanel:
    def test_creates_missing_plugin_and_sets_props(self):
        settings = {
            "panel": {
                "order": ["whiskermenu", "separator"],
                "plugins": {
                    "whiskermenu": {"favorites": ["xfce4-file-manager.desktop"]},
                    "separator": {"style": 0, "expand": False},
                }
            }
        }
        # Only whiskermenu exists; separator must be created
        existing_types = {1: "whiskermenu"}
        logical_names = {(1, "whiskermenu"): "whiskermenu"}

        created = []
        set_calls = []
        set_array_calls = []

        with patch("xfconf.get_plugin_ids", return_value=[1]), \
             patch("xfconf.get_plugin_type", side_effect=lambda pid: existing_types.get(pid)), \
             patch("xfconf.plugin_logical_name", side_effect=lambda pid, t: logical_names.get((pid, t), t)), \
             patch("xfconf.create_plugin", side_effect=lambda name: created.append(name) or 2), \
             patch("xfconf.xfconf_set", side_effect=lambda *a, **kw: set_calls.append(a)), \
             patch("xfconf.xfconf_set_array", side_effect=lambda *a, **kw: set_array_calls.append(a)):
            xfconf.pull_panel(settings)

        assert "separator" in created
        # plugin-ids array should be rebuilt with [1, 2]
        plugin_ids_call = next(c for c in set_array_calls if c[1] == "/panels/panel-1/plugin-ids")
        assert list(map(int, plugin_ids_call[3])) == [1, 2]

    def test_writes_systemload_labels_and_uptime(self):
        settings = {
            "panel": {
                "order": ["systemload"],
                "plugins": {
                    "systemload": {
                        "uptime-enabled": False,
                        "cpu-label": "P",
                        "memory-label": "M",
                        "swap-label": "S",
                        "network-label": "N",
                    },
                }
            }
        }
        existing_types = {1: "systemload"}
        logical_names = {(1, "systemload"): "systemload"}
        set_calls = []
        set_array_calls = []

        with patch("xfconf.get_plugin_ids", return_value=[1]), \
             patch("xfconf.get_plugin_type", side_effect=lambda pid: existing_types.get(pid)), \
             patch("xfconf.plugin_logical_name", side_effect=lambda pid, t: logical_names.get((pid, t), t)), \
             patch("xfconf.create_plugin", side_effect=lambda name: 99), \
             patch("xfconf.xfconf_set", side_effect=lambda *a, **kw: set_calls.append(a)), \
             patch("xfconf.xfconf_set_array", side_effect=lambda *a, **kw: set_array_calls.append(a)):
            xfconf.pull_panel(settings)

        written = {c[1]: c[2] for c in set_calls}
        assert written["/plugins/plugin-1/uptime/enabled"] is False  # Python bool, not string
        assert written["/plugins/plugin-1/cpu/label"] == "P"
        assert written["/plugins/plugin-1/memory/label"] == "M"
        assert written["/plugins/plugin-1/network/label"] == "N"

    def test_writes_weather_owned_and_nested_props(self):
        settings = {
            "panel": {
                "order": ["weather"],
                "plugins": {
                    "weather": {
                        "msl": 18,
                        "round": True,
                        "units": {"temperature": 0, "windspeed": 4},
                        "forecast": {"days": 5},
                    }
                }
            }
        }
        existing_types = {1: "weather"}
        logical_names = {(1, "weather"): "weather"}
        set_calls = []
        set_array_calls = []

        with patch("xfconf.get_plugin_ids", return_value=[1]), \
             patch("xfconf.get_plugin_type", side_effect=lambda pid: existing_types.get(pid)), \
             patch("xfconf.plugin_logical_name", side_effect=lambda pid, t: logical_names.get((pid, t), t)), \
             patch("xfconf.create_plugin", side_effect=lambda name: 99), \
             patch("xfconf.xfconf_set", side_effect=lambda *a, **kw: set_calls.append(a)), \
             patch("xfconf.xfconf_set_array", side_effect=lambda *a, **kw: set_array_calls.append(a)):
            xfconf.pull_panel(settings)

        written = {c[1]: c[2] for c in set_calls}
        assert written["/plugins/plugin-1/msl"] == 18
        assert written["/plugins/plugin-1/round"] is True
        assert written["/plugins/plugin-1/units/temperature"] == 0
        assert written["/plugins/plugin-1/units/windspeed"] == 4
        assert written["/plugins/plugin-1/forecast/days"] == 5

    def test_no_creation_when_all_plugins_exist(self):
        settings = {
            "panel": {
                "order": ["whiskermenu"],
                "plugins": {"whiskermenu": {"favorites": []}}
            }
        }
        existing_types = {1: "whiskermenu"}
        logical_names = {(1, "whiskermenu"): "whiskermenu"}
        created = []

        with patch("xfconf.get_plugin_ids", return_value=[1]), \
             patch("xfconf.get_plugin_type", side_effect=lambda pid: existing_types.get(pid)), \
             patch("xfconf.plugin_logical_name", side_effect=lambda pid, t: logical_names.get((pid, t), t)), \
             patch("xfconf.create_plugin", side_effect=lambda name: created.append(name) or 99), \
             patch("xfconf.xfconf_set_array"):
            xfconf.pull_panel(settings)

        assert created == []  # nothing should have been created
