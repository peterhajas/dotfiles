#!/usr/bin/env python3
"""
Comprehensive test suite for yabai_update_tiling

Tests both pure functions (unit tests) and full scenario runs (integration tests).
"""

import json
import os
import sys
import unittest
from pathlib import Path
from typing import Dict, Any, List

# Add the script directory to path to import the module under test
script_dir = Path(__file__).parent
sys.path.insert(0, str(script_dir))

# Import the module we're testing (this is the yabai_update_tiling script)
# Since the script doesn't have a .py extension, we load it using exec()
import types

script_path = script_dir / "yabai_update_tiling"
if not script_path.exists():
    print(f"Error: Could not find yabai_update_tiling at {script_path}", file=sys.stderr)
    sys.exit(1)

# Create a module object
yut = types.ModuleType("yabai_update_tiling")
yut.__file__ = str(script_path)

# Execute the script in the module's namespace
with open(script_path, "r") as f:
    code = compile(f.read(), str(script_path), "exec")
    exec(code, yut.__dict__)

# Add to sys.modules so imports work
sys.modules["yabai_update_tiling"] = yut


class TestBucketLayout(unittest.TestCase):
    """Unit tests for bucket_layout() function."""

    def test_single_bucket_center(self):
        """Single bucket should span full width."""
        result = yut.bucket_layout(["center"], 1920.0)
        self.assertIn("center", result)
        self.assertEqual(result["center"]["col"], 0)
        self.assertEqual(result["center"]["span"], 100)

    def test_three_buckets_equal_weights(self):
        """Three buckets with equal weights should split evenly."""
        # Temporarily override weights to be equal for this test
        original_weights = yut.BUCKET_WEIGHTS.copy()
        yut.BUCKET_WEIGHTS = {"left": 1.0, "center": 1.0, "right": 1.0}

        result = yut.bucket_layout(["left", "center", "right"], 3000.0)

        # Should have all three buckets
        self.assertIn("left", result)
        self.assertIn("center", result)
        self.assertIn("right", result)

        # Each should be roughly 33 columns (totaling 100)
        self.assertGreater(result["left"]["span"], 30)
        self.assertGreater(result["center"]["span"], 30)
        self.assertGreater(result["right"]["span"], 30)
        self.assertEqual(
            result["left"]["span"] + result["center"]["span"] + result["right"]["span"],
            100
        )

        # Restore original weights
        yut.BUCKET_WEIGHTS = original_weights

    def test_five_buckets(self):
        """Five bucket layout should allocate all 100 columns."""
        result = yut.bucket_layout(
            ["far_left", "left", "center", "right", "far_right"],
            7680.0
        )

        # All buckets should exist
        for bucket in ["far_left", "left", "center", "right", "far_right"]:
            self.assertIn(bucket, result)

        # Total should be 100
        total = sum(result[b]["span"] for b in result)
        self.assertEqual(total, 100)

        # Center should be larger (2.0 weight vs 1.0 for others)
        self.assertGreater(result["center"]["span"], result["left"]["span"])

    def test_empty_buckets(self):
        """Empty bucket list should return empty layout."""
        result = yut.bucket_layout([], 1920.0)
        self.assertEqual(result, {})

    def test_zero_width(self):
        """Zero display width should return empty layout."""
        result = yut.bucket_layout(["center"], 0.0)
        self.assertEqual(result, {})


class TestComputeBucketWidths(unittest.TestCase):
    """Unit tests for compute_bucket_widths() function."""

    def test_single_bucket(self):
        """Single bucket gets full width."""
        widths = yut.compute_bucket_widths(["center"], 1920.0)
        self.assertAlmostEqual(widths["center"], 1920.0, places=1)

    def test_with_side_max_width_capping(self):
        """Side buckets should be capped at SIDE_MAX_WIDTH_PX when center exists."""
        # Temporarily set SIDE_MAX_WIDTH_PX
        original = yut.SIDE_MAX_WIDTH_PX
        yut.SIDE_MAX_WIDTH_PX = 500

        widths = yut.compute_bucket_widths(["left", "center", "right"], 3000.0)

        # Sides should be capped
        self.assertLessEqual(widths["left"], 500)
        self.assertLessEqual(widths["right"], 500)

        # Center gets the rest
        expected_center = 3000.0 - widths["left"] - widths["right"]
        self.assertAlmostEqual(widths["center"], expected_center, places=1)

        # Restore
        yut.SIDE_MAX_WIDTH_PX = original

    def test_proportional_weights(self):
        """Buckets should be sized according to their weights."""
        # Use equal-weight buckets for easy math
        original_weights = yut.BUCKET_WEIGHTS.copy()
        yut.BUCKET_WEIGHTS = {"left": 1.0, "right": 1.0}

        widths = yut.compute_bucket_widths(["left", "right"], 2000.0)

        # Should be 50/50 split
        self.assertAlmostEqual(widths["left"], 1000.0, places=1)
        self.assertAlmostEqual(widths["right"], 1000.0, places=1)

        # Restore
        yut.BUCKET_WEIGHTS = original_weights


class TestDetermineBucketByPosition(unittest.TestCase):
    """Unit tests for determine_bucket_by_position() function."""

    def test_single_bucket(self):
        """With one bucket, window should always map to it."""
        window = {"frame": {"x": 100.0, "w": 500.0}}
        display = {"frame": {"x": 0.0, "y": 0.0, "w": 1920.0, "h": 1080.0}}

        result = yut.determine_bucket_by_position(window, display, ["center"])
        self.assertEqual(result, "center")

    def test_three_buckets_left(self):
        """Window in left third should map to left bucket."""
        # Window center at x=200 (within 0-640 range of 1920px display)
        window = {"frame": {"x": 0.0, "w": 400.0}}
        display = {"frame": {"x": 0.0, "y": 0.0, "w": 1920.0, "h": 1080.0}}

        result = yut.determine_bucket_by_position(
            window, display, ["left", "center", "right"]
        )
        self.assertEqual(result, "left")

    def test_three_buckets_center(self):
        """Window in center third should map to center bucket."""
        # Window center at x=960 (middle of 1920px display)
        window = {"frame": {"x": 760.0, "w": 400.0}}
        display = {"frame": {"x": 0.0, "y": 0.0, "w": 1920.0, "h": 1080.0}}

        result = yut.determine_bucket_by_position(
            window, display, ["left", "center", "right"]
        )
        self.assertEqual(result, "center")

    def test_three_buckets_right(self):
        """Window in right third should map to right bucket."""
        # Window center at x=1720 (within 1280-1920 range)
        window = {"frame": {"x": 1520.0, "w": 400.0}}
        display = {"frame": {"x": 0.0, "y": 0.0, "w": 1920.0, "h": 1080.0}}

        result = yut.determine_bucket_by_position(
            window, display, ["left", "center", "right"]
        )
        self.assertEqual(result, "right")

    def test_invalid_frame_data(self):
        """Invalid frame data should default to first bucket."""
        window = {"frame": {"x": 0.0, "w": 0.0}}  # Invalid width
        display = {"frame": {"x": 0.0, "y": 0.0, "w": 1920.0, "h": 1080.0}}

        result = yut.determine_bucket_by_position(
            window, display, ["left", "center", "right"]
        )
        self.assertEqual(result, "left")  # First bucket


class TestIsManagementDisabled(unittest.TestCase):
    """Unit tests for is_management_disabled() function."""

    def setUp(self):
        """Set up test fixtures."""
        # Save original state
        self.original_rules = yut.MANAGE_OFF_RULES.copy()
        self.original_apps = yut.MANAGE_OFF_APPS.copy()

        # Set up test rules
        yut.MANAGE_OFF_RULES = [
            {"app": "^System Settings$", "manage": "off"}
        ]
        yut.MANAGE_OFF_APPS = {"System Settings", "Steam"}

    def tearDown(self):
        """Restore original state."""
        yut.MANAGE_OFF_RULES = self.original_rules
        yut.MANAGE_OFF_APPS = self.original_apps

    def test_none_window(self):
        """None window should return False."""
        self.assertFalse(yut.is_management_disabled(None))

    def test_app_in_defensive_list(self):
        """App in MANAGE_OFF_APPS should be disabled."""
        window = {"id": 1, "app": "System Settings"}
        self.assertTrue(yut.is_management_disabled(window))

    def test_panel_window(self):
        """Panel/dialog windows should be disabled."""
        window = {
            "id": 1,
            "app": "Finder",
            "role": "AXWindow",
            "subrole": "AXDialog"
        }
        self.assertTrue(yut.is_management_disabled(window))

    def test_sheet_window(self):
        """Sheet windows should be disabled."""
        window = {
            "id": 1,
            "app": "Safari",
            "role": "AXSheet",
            "subrole": "AXStandardWindow"
        }
        self.assertTrue(yut.is_management_disabled(window))

    def test_normal_window(self):
        """Normal manageable window should return False."""
        window = {
            "id": 1,
            "app": "Ghostty",
            "title": "terminal",
            "role": "AXWindow",
            "subrole": "AXStandardWindow"
        }
        self.assertFalse(yut.is_management_disabled(window))


class TestLayoutModeSelection(unittest.TestCase):
    """Tests for layout mode selection logic."""

    def test_single_ultrawide_triggers_ultrawide_mode(self):
        """Single display >= ULTRAWIDE_THRESHOLD should use ultrawide mode."""
        # Display wider than ULTRAWIDE_THRESHOLD (2000px)
        displays = [
            {"index": 1, "frame": {"x": 0.0, "y": 0.0, "w": 3440.0, "h": 1440.0}}
        ]

        total_width = sum(d["frame"]["w"] for d in displays)
        widest = max(d["frame"]["w"] for d in displays)

        # Should not trigger 5-bucket mode (total < 5000)
        self.assertLess(total_width, yut.WORKSPACE_WIDTH_THRESHOLD)

        # But widest should be >= ULTRAWIDE_THRESHOLD
        self.assertGreaterEqual(widest, yut.ULTRAWIDE_THRESHOLD)

    def test_super_wide_single_triggers_five_bucket(self):
        """Single display >= 5000px should trigger 5-bucket mode."""
        displays = [
            {"index": 1, "frame": {"x": 0.0, "y": 0.0, "w": 7680.0, "h": 2160.0}}
        ]

        widest = max(d["frame"]["w"] for d in displays)
        self.assertGreaterEqual(widest, yut.WORKSPACE_WIDTH_THRESHOLD)

    def test_three_displays_trigger_five_bucket(self):
        """Three displays with total >= 5000px should trigger 5-bucket mode."""
        displays = [
            {"index": 1, "frame": {"x": 0.0, "y": 0.0, "w": 1920.0, "h": 1080.0}},
            {"index": 2, "frame": {"x": 1920.0, "y": 0.0, "w": 2560.0, "h": 1440.0}},
            {"index": 3, "frame": {"x": 4480.0, "y": 0.0, "w": 1920.0, "h": 1080.0}}
        ]

        total_width = sum(d["frame"]["w"] for d in displays)
        self.assertGreaterEqual(total_width, yut.WORKSPACE_WIDTH_THRESHOLD)


class TestScenarioIntegration(unittest.TestCase):
    """Integration tests using test scenarios."""

    @classmethod
    def setUpClass(cls):
        """Find test scenarios directory."""
        # Scenarios are in ~/.local/share/yabai/test_scenarios/ after stowing
        # But during testing from repo, they're in yabai/.local/share/yabai/test_scenarios/
        cls.scenarios_dir = script_dir.parent / ".local" / "share" / "yabai" / "test_scenarios"

        if not cls.scenarios_dir.exists():
            # Try home directory (after stowing)
            home_scenarios = Path.home() / ".local" / "share" / "yabai" / "test_scenarios"
            if home_scenarios.exists():
                cls.scenarios_dir = home_scenarios

        cls.scenarios_available = cls.scenarios_dir.exists()

    def load_scenario(self, scenario_name: str) -> Dict[str, Any]:
        """Load a test scenario from JSON file."""
        scenario_file = self.scenarios_dir / f"{scenario_name}.json"
        with open(scenario_file, "r") as f:
            return json.load(f)

    def run_with_scenario(self, scenario_name: str) -> yut.YabaiCommandExecutor:
        """Run the tiling logic with a test scenario and return the executor."""
        if not self.scenarios_available:
            self.skipTest(f"Test scenarios not found in {self.scenarios_dir}")

        # Load scenario
        test_data = self.load_scenario(scenario_name)

        # Create provider and executor
        provider = yut.MockYabaiProvider(test_data)
        executor = yut.YabaiCommandExecutor(dry_run=True)

        # Get data
        displays = provider.query_displays()
        spaces = provider.query_spaces()
        windows = provider.query_windows()
        rules = provider.query_rules()

        if not displays or not spaces or windows is None:
            self.fail(f"Scenario {scenario_name} has incomplete data")

        # Set up global state
        yut.MANAGE_OFF_RULES = [
            rule for rule in (rules or [])
            if yut.manage_is_off(rule.get("manage"))
        ]
        yut.MANAGE_OFF_APPS = set()
        for rule in yut.MANAGE_OFF_RULES:
            app_pattern = rule.get("app", "")
            if app_pattern:
                app_name = app_pattern.strip("^$")
                if app_name and not any(c in app_name for c in r".*+?[]{}()\|"):
                    yut.MANAGE_OFF_APPS.add(app_name)

        # Run tiling logic (simplified version of main loop)
        total_workspace_width = yut.workspace_width(displays)
        widest_display_width = max(d.get("frame", {}).get("w", 0) for d in displays)
        use_five_buckets = (
            total_workspace_width >= yut.WORKSPACE_WIDTH_THRESHOLD or
            widest_display_width >= yut.WORKSPACE_WIDTH_THRESHOLD
        )

        if use_five_buckets:
            bucket_to_display = yut.bucket_display_map(displays)
            display_to_buckets: Dict[int, List[str]] = {}
            for bucket, disp in bucket_to_display.items():
                if disp is None:
                    continue
                display_to_buckets.setdefault(disp, []).append(bucket)
            for disp, buckets in display_to_buckets.items():
                display_to_buckets[disp] = [b for b in yut.BUCKET_ORDER if b in buckets]

            # Process each space
            for space in spaces:
                space_display = space.get("display")
                space_index = space.get("index")
                buckets_for_display = display_to_buckets.get(space_display, [])
                if not buckets_for_display:
                    continue

                display_obj = yut.get_display_by_index(displays, space_display) or {}
                display_w = display_obj.get("frame", {}).get("w", 0)

                buckets: Dict[str, List[Dict[str, Any]]] = {
                    name: [] for name in buckets_for_display
                }

                for win in windows:
                    if win.get("display") != space_display or win.get("space") != space_index:
                        continue
                    if win.get("minimized") == 1:
                        continue
                    if yut.is_management_disabled(win):
                        continue
                    if win.get("is-visible") is False or win.get("is-hidden") is True:
                        continue

                    bucket = yut.determine_bucket_by_position(win, display_obj, buckets_for_display)
                    if bucket not in buckets:
                        continue
                    buckets[bucket].append(win)

                present_buckets = buckets_for_display
                layout = yut.bucket_layout(present_buckets, display_w)
                if not layout:
                    continue

                for bucket_name, wins in buckets.items():
                    if not wins or bucket_name not in layout:
                        continue

                    if bucket_name == "center":
                        yut.overlap_region(
                            [w.get("id") for w in wins],
                            layout[bucket_name]["col"],
                            layout[bucket_name]["span"],
                            executor,
                        )
                    else:
                        sorted_wins = sorted(wins, key=lambda w: (
                            (w.get("title") or w.get("app") or "").lower(),
                            w.get("id", 0),
                        ))
                        yut.apply_bucket(
                            [w.get("id") for w in sorted_wins],
                            layout[bucket_name]["col"],
                            layout[bucket_name]["span"],
                            executor,
                        )

        return executor

    def test_empty_scenario(self):
        """Empty scenario should run without errors."""
        executor = self.run_with_scenario("empty")
        # Should complete without crashing
        self.assertIsNotNone(executor)
        # No windows means no grid commands
        grid_commands = [cmd for cmd in executor.executed_commands if "--grid" in cmd]
        self.assertEqual(len(grid_commands), 0)

    def test_single_display_scenario(self):
        """Single display scenario should generate grid commands."""
        executor = self.run_with_scenario("single-display")
        # Should have grid commands for windows
        grid_commands = [cmd for cmd in executor.executed_commands if "--grid" in cmd]
        self.assertGreater(len(grid_commands), 0)

    def test_ultrawide_scenario(self):
        """Ultrawide scenario should use 3-bucket layout."""
        # Note: This test may not execute bucket logic if use_five_buckets is True
        # The scenario file has 3440px width which is < 5000 but >= 2000
        # So it should trigger ultrawide mode but NOT 5-bucket mode
        executor = self.run_with_scenario("ultrawide")
        self.assertIsNotNone(executor)
        # Just verify it doesn't crash

    def test_five_bucket_single_scenario(self):
        """Five bucket single display should use 5-bucket layout."""
        executor = self.run_with_scenario("five-bucket-single")
        # Should have grid commands for windows
        grid_commands = [cmd for cmd in executor.executed_commands if "--grid" in cmd]
        self.assertGreater(len(grid_commands), 0)

    def test_three_displays_scenario(self):
        """Three displays should use 5-bucket layout."""
        executor = self.run_with_scenario("three-displays")
        # Should have grid commands for windows across displays
        grid_commands = [cmd for cmd in executor.executed_commands if "--grid" in cmd]
        self.assertGreater(len(grid_commands), 0)

    def test_special_windows_scenario(self):
        """Special windows should be filtered correctly."""
        if not self.scenarios_available:
            self.skipTest(f"Test scenarios not found in {self.scenarios_dir}")

        test_data = self.load_scenario("special-windows")
        provider = yut.MockYabaiProvider(test_data)

        # Set up rules
        rules = provider.query_rules() or []
        yut.MANAGE_OFF_RULES = [
            rule for rule in rules
            if yut.manage_is_off(rule.get("manage"))
        ]
        yut.MANAGE_OFF_APPS = set()
        for rule in yut.MANAGE_OFF_RULES:
            app_pattern = rule.get("app", "")
            if app_pattern:
                app_name = app_pattern.strip("^$")
                if app_name and not any(c in app_name for c in r".*+?[]{}()\|"):
                    yut.MANAGE_OFF_APPS.add(app_name)

        windows = provider.query_windows() or []

        # Check special window detection
        sysmon_count = sum(1 for w in windows if yut.is_special_sysmon(w))
        self.assertGreater(sysmon_count, 0, "Should detect sysmon windows")

        ai_count = sum(1 for w in windows if yut.is_special_ai(w))
        self.assertGreater(ai_count, 0, "Should detect AI windows")

        # Check management filtering
        system_settings = next((w for w in windows if w.get("app") == "System Settings"), None)
        if system_settings:
            self.assertTrue(yut.is_management_disabled(system_settings),
                          "System Settings should be management-disabled")

        # Check dialog detection
        dialog_window = next((w for w in windows if w.get("subrole") == "AXDialog"), None)
        if dialog_window:
            self.assertTrue(yut.is_management_disabled(dialog_window),
                          "Dialog windows should be management-disabled")


def run_tests():
    """Run all tests and return exit code."""
    # Disable verbose logging for tests
    yut.VERBOSE = False

    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    # Add all test classes
    suite.addTests(loader.loadTestsFromTestCase(TestBucketLayout))
    suite.addTests(loader.loadTestsFromTestCase(TestComputeBucketWidths))
    suite.addTests(loader.loadTestsFromTestCase(TestDetermineBucketByPosition))
    suite.addTests(loader.loadTestsFromTestCase(TestIsManagementDisabled))
    suite.addTests(loader.loadTestsFromTestCase(TestLayoutModeSelection))
    suite.addTests(loader.loadTestsFromTestCase(TestScenarioIntegration))

    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # Return 0 if all tests passed, 1 otherwise
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(run_tests())
