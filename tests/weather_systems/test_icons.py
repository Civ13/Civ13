"""The weather system icons are the existing weather sheet, tiled. Stdlib and
Pillow only; no BYOND runtime."""
import importlib.util
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("make_chunks", ROOT / "tools/weather/make_chunks.py")
TOOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOL)


class WeatherIconTests(unittest.TestCase):
    def test_committed_icons_match_the_generator(self):
        chunks, roof = TOOL.build()
        self.assertTrue(TOOL.same_icon(TOOL.CHUNKS, chunks), "run python3 tools/weather/make_chunks.py")
        self.assertTrue(TOOL.same_icon(TOOL.ROOF, roof), "run python3 tools/weather/make_chunks.py")

    def test_a_changed_pixel_or_state_is_noticed(self):
        chunks, roof = TOOL.build()
        self.assertFalse(TOOL.same_icon(TOOL.ROOF, chunks))
        self.assertFalse(TOOL.same_icon(TOOL.CHUNKS, roof))

    def test_every_look_the_climate_table_can_give_has_a_chunk_state(self):
        source = (ROOT / "code/modules/1713/weather.dm").read_text(encoding="utf-8")
        start = source.index("/proc/climate_weather_state(climate, weather, weather_intensity)")
        table = source[start:source.index("/proc/apply_area_weather", start)]
        looks = set(re.findall(r'look = "([^"]+)"', table))
        self.assertTrue(looks)
        found, width, height = TOOL.states(TOOL.CHUNKS)
        self.assertEqual((width, height), (128, 128))
        self.assertEqual(looks - {name for name, _, _, _ in found}, set())

    def test_chunk_frames_and_delays_follow_the_source_sheet(self):
        source = {name: (frames, delays) for name, _, frames, delays in TOOL.states(TOOL.SOURCE)[0] if name in TOOL.STATES}
        for name, _, frames, delays in TOOL.states(TOOL.CHUNKS)[0]:
            self.assertEqual((frames, delays), source[name], name)


STORM_SPEC = importlib.util.spec_from_file_location("make_storm_art", ROOT / "tools/weather/make_storm_art.py")
STORM = importlib.util.module_from_spec(STORM_SPEC)
STORM_SPEC.loader.exec_module(STORM)


class StormArtTests(unittest.TestCase):
    def test_committed_storm_art_matches_the_generator(self):
        storm, bolt = STORM.build()
        self.assertTrue(TOOL.same_icon(STORM.STORM, storm), "run python3 tools/weather/make_storm_art.py")
        self.assertTrue(TOOL.same_icon(STORM.BOLT, bolt), "run python3 tools/weather/make_storm_art.py")

    def test_shadow_pieces_join_slide_and_wrap(self):
        states = dict((name, frames) for name, frames, _ in STORM.shadow_frames())
        self.assertEqual(len(states), 16)
        field = STORM.shadow_field()
        low, high = field.getextrema()
        # Never clear and never black, so pieces of different strength blend.
        self.assertGreaterEqual(low, 40)
        self.assertLessEqual(high, 180)
        size = STORM.SIZE
        for wind, dx, dy in STORM.DRIFT:
            for frame in (0, 1, STORM.FRAMES - 1):
                # The four pieces of a frame put together are the whole cloud, moved.
                whole = STORM.Image.new("L", (STORM.FIELD, STORM.FIELD))
                for qx in (0, 1):
                    for qy in (0, 1):
                        piece = states[f"shadow_{wind}_{qx}{qy}"]
                        self.assertEqual(len(piece), STORM.FRAMES)
                        whole.paste(piece[frame].getchannel("A"), (qx * size, (1 - qy) * size))
                self.assertEqual(whole.tobytes(), STORM.shifted_field(field, dx, dy, frame).tobytes(), (wind, frame))
                # A wrapped move loses nothing, so the loop closes exactly.
                self.assertEqual(sorted(whole.tobytes()), sorted(field.tobytes()), (wind, frame))
        step = STORM.FIELD // STORM.FRAMES
        east = states["shadow_e_00"]
        self.assertEqual(east[1].getpixel((step + 5, 9)), east[0].getpixel((5, 9)))
        # It does not repeat from one piece to the next.
        self.assertNotEqual(states["shadow_e_00"][0].tobytes(), states["shadow_e_10"][0].tobytes())

    def test_states_the_game_asks_for_exist(self):
        chunks = (ROOT / "code/modules/1713/weather_chunks.dm").read_text(encoding="utf-8")
        wanted = set(re.findall(r'"(shadow_[a-z]+)"', chunks))
        self.assertEqual(wanted, {"shadow_n", "shadow_e", "shadow_s", "shadow_w"})
        self.assertIn('return "[look]_[cx % 2][cy % 2]"', chunks)
        have = {name for name, _, _, _ in TOOL.states(STORM.STORM)[0]}
        self.assertEqual(have, {f"{look}_{qx}{qy}" for look in wanted for qx in (0, 1) for qy in (0, 1)})
        bolts = {name for name, _, _, _ in TOOL.states(STORM.BOLT)[0]}
        self.assertEqual(bolts, {"bolt1", "bolt2", "bolt3", "bolt4"})

    def test_edge_fades_match_the_generator_and_cover_every_corner_mix(self):
        self.assertTrue(TOOL.same_icon(STORM.EDGE, STORM.build_edge()), "run python3 tools/weather/make_storm_art.py")
        chunks = (ROOT / "code/modules/1713/weather_chunks.dm").read_text(encoding="utf-8")
        self.assertIn(f"#define WEATHER_EDGE_LEVELS {STORM.EDGE_LEVELS} ", chunks)
        self.assertIn('return "m[sw][se][nw][ne]"', chunks)
        have = {name for name, _, _, _ in TOOL.states(STORM.EDGE)[0]}
        levels = range(STORM.EDGE_LEVELS + 1)
        every = {f"m{a}{b}{c}{d}" for a in levels for b in levels for c in levels for d in levels}
        # Nothing at all and the whole piece need no mask.
        self.assertEqual(have, every - {"m0000", "m3333"})

    def test_an_edge_fade_runs_evenly_between_its_corners(self):
        size = STORM.SIZE
        mask = STORM.edge_mask(0, 1, 2, 3).getchannel("A")
        # South-west is the image's lower left; north-east its upper right.
        self.assertLessEqual(mask.getpixel((0, size - 1)), 3)
        self.assertGreaterEqual(mask.getpixel((size - 1, 0)), 252)
        self.assertAlmostEqual(mask.getpixel((size - 1, size - 1)), 85, delta=3)
        self.assertAlmostEqual(mask.getpixel((0, 0)), 170, delta=3)
        # Two pieces side by side meet without a step: the shared edge is the same.
        west = STORM.edge_mask(0, 2, 1, 3).getchannel("A")
        east = STORM.edge_mask(2, 3, 3, 0).getchannel("A")
        for y in range(0, size, 9):
            self.assertLessEqual(abs(west.getpixel((size - 1, y)) - east.getpixel((0, y))), 3, y)

    def test_a_bolt_stands_on_the_middle_of_its_tile(self):
        for name, frames, _ in STORM.bolt_states():
            foot = frames[0].getpixel((STORM.BOLT_W // 2, STORM.BOLT_H - 17))
            self.assertEqual(foot[3], 255, name)

    def test_lightning_starts_no_fire(self):
        source = (ROOT / "code/modules/1713/weather_lightning.dm").read_text(encoding="utf-8")
        for word in ("ignite", "fire_act", "/obj/fire", "adjustFireLoss", "apply_damage", "explosion("):
            self.assertNotIn(word, source)


if __name__ == "__main__":
    unittest.main()
