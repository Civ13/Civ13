"""The flow line icon matches its generator and closes its loop. Stdlib and
Pillow only; no BYOND runtime."""
import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/weather"))
SPEC = importlib.util.spec_from_file_location("make_flow", ROOT / "tools/weather/make_flow.py")
TOOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOL)
from make_chunks import same_icon, states  # noqa: E402


class FlowIconTests(unittest.TestCase):
    def test_committed_icon_matches_the_generator(self):
        self.assertTrue(same_icon(TOOL.FLOW, TOOL.build()), "run python3 tools/weather/make_flow.py")

    def test_every_direction_has_both_variants(self):
        names = {name for name, _, _, _ in states(TOOL.FLOW)[0]}
        wanted = {f"flow_{d}{v}" for d, _, _ in TOOL.DIRECTIONS for v in ("", "2")}
        self.assertEqual(names, wanted)

    def test_streaks_slide_the_way_the_water_runs_and_the_loop_closes(self):
        step = TOOL.SIZE // TOOL.FRAMES
        by_name = {name: frames for name, frames, _ in TOOL.states()}
        for name, dx, dy in TOOL.DIRECTIONS:
            frames = by_name[f"flow_{name}"]
            self.assertEqual(len(frames), TOOL.FRAMES)
            first, second = frames[0], frames[1]
            for x in range(TOOL.SIZE):
                for y in range(TOOL.SIZE):
                    # Image y runs down, the map's y runs up.
                    moved = second.getpixel(((x + dx * step) % TOOL.SIZE, (y - dy * step) % TOOL.SIZE))
                    self.assertEqual(first.getpixel((x, y)), moved, name)

    def test_streaks_are_faint(self):
        for name, frames, _ in TOOL.states():
            self.assertLessEqual(frames[0].getchannel("A").getextrema()[1], 100, name)


if __name__ == "__main__":
    unittest.main()
