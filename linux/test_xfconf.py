import sys
from pathlib import Path
from unittest.mock import MagicMock, patch


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
        with (
            patch("xfconf.subprocess.run", return_value=make_result("true")),
            patch("xfconf._xfconf_type_from_xml", return_value="bool"),
        ):
            val, type_str = xfconf.xfconf_get("xfce4-panel", "/plugins/plugin-5/square-icons")
        assert val == "true"
        assert type_str == "bool"

    def test_falls_back_to_string_when_xml_returns_none(self):
        with (
            patch("xfconf.subprocess.run", return_value=make_result("foo")),
            patch("xfconf._xfconf_type_from_xml", return_value=None),
        ):
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

    def test_clock_reference_identified_by_format_prefix(self):
        # Identity comes from the 3-letter prefix, not the timezone: the timezone
        # changes as we travel, and once it matched local the old test broke.
        props = {"timezone": "Europe/Vilnius", "digital-time-format": "VNO %R"}
        with patch("xfconf.get_plugin_props", return_value=props):
            with patch("xfconf.clock_plugin_ids", return_value=[12]):
                name = xfconf.plugin_logical_name(12, "clock")
        assert name == "clock-ref-1"

    def test_clock_local_even_when_it_matches_a_reference_zone(self):
        # The case that broke the old implementation: local clock set to Vilnius.
        props = {"timezone": "Europe/Vilnius", "digital-time-format": "%d %b, %H:%M"}
        with patch("xfconf.get_plugin_props", return_value=props):
            name = xfconf.plugin_logical_name(10, "clock")
        assert name == "clock-local"

    def test_second_reference_clock_numbered_by_panel_order(self):
        props = {
            16: {"digital-time-format": "VNO %R"},
            18: {"digital-time-format": "SFO %R"},
        }
        with patch("xfconf.get_plugin_props", side_effect=lambda pid: props[pid]):
            with patch("xfconf.clock_plugin_ids", return_value=[16, 18]):
                assert xfconf.plugin_logical_name(16, "clock") == "clock-ref-1"
                assert xfconf.plugin_logical_name(18, "clock") == "clock-ref-2"


class TestReferenceZones:
    def test_at_home_shows_hq_and_utc(self):
        assert xfconf.reference_zones("Europe/Vilnius") == ["America/Los_Angeles", "UTC"]

    def test_at_hq_shows_home_and_utc(self):
        assert xfconf.reference_zones("America/Los_Angeles") == ["Europe/Vilnius", "UTC"]

    def test_elsewhere_in_europe_shows_both(self):
        assert xfconf.reference_zones("Europe/Berlin") == ["America/Los_Angeles", "Europe/Vilnius"]


class TestClockLabel:
    def test_known_zone_and_unknown_fallback(self):
        assert xfconf.clock_label("Europe/Vilnius") == "VNO"
        assert xfconf.clock_label("Asia/Tokyo") == "TOK"

    def test_unknown_zone_falls_back_to_city(self):
        assert xfconf.clock_label("Asia/Tokyo") == "TOK"


class TestIsReferenceClock:
    def test_prefixed_format_is_a_reference(self):
        assert xfconf.is_reference_clock({"digital-time-format": "VNO %R"})

    def test_unprefixed_format_is_local(self):
        assert not xfconf.is_reference_clock({"digital-format": " %d %b, %H:%M "})

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
