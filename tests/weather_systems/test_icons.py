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

    def test_shadow_slides_one_whole_icon_and_wraps(self):
        for name, frames, delays in STORM.shadow_frames():
            self.assertEqual(len(frames), STORM.FRAMES, name)
            first = frames[0].getchannel("A")
            # Never clear and never black, so pieces of different strength blend.
            low, high = first.getextrema()
            self.assertGreaterEqual(low, 40, name)
            self.assertLessEqual(high, 180, name)
            # Every frame is the first one moved, so the loop closes exactly.
            self.assertEqual(sorted(first.tobytes()), sorted(frames[-1].getchannel("A").tobytes()), name)
        east = dict((n, f) for n, f, _ in STORM.shadow_frames())["shadow_e"]
        step = STORM.SIZE // STORM.FRAMES
        self.assertEqual(east[1].getpixel((step + 5, 9)), east[0].getpixel((5, 9)))

    def test_states_the_game_asks_for_exist(self):
        chunks = (ROOT / "code/modules/1713/weather_chunks.dm").read_text(encoding="utf-8")
        wanted = set(re.findall(r'"(shadow_[a-z]+)"', chunks))
        self.assertEqual(wanted, {"shadow_n", "shadow_e", "shadow_s", "shadow_w"})
        self.assertLessEqual(wanted, {name for name, _, _, _ in TOOL.states(STORM.STORM)[0]})
        bolts = {name for name, _, _, _ in TOOL.states(STORM.BOLT)[0]}
        self.assertEqual(bolts, {"bolt1", "bolt2", "bolt3", "bolt4"})

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
