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
        self.assertEqual(TOOL.CHUNKS.read_bytes(), chunks, "run python3 tools/weather/make_chunks.py")
        self.assertEqual(TOOL.ROOF.read_bytes(), roof, "run python3 tools/weather/make_chunks.py")

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


if __name__ == "__main__":
    unittest.main()
