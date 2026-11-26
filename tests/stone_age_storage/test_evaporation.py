"""Offline checks for the actual zeer-pot sample ordering and lifecycle."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "code/modules/1713/stone_age_storage.dm"
POT = "/obj/structure/storage_container/storage_jar/zeer_pot"


class ZeerEvaporationTest(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding="utf-8")

    def block(self, suffix):
        start = self.source.index(POT + suffix)
        end = self.source.find("\n/", start + 1)
        return self.source[start:end if end != -1 else None]

    def test_previous_rate_is_charged_before_sampling_the_new_temperature(self):
        settle = self.block("/proc/settle_water()")
        charge = settle.index("water - minutes * water_sample_rate")
        next_rate = settle.index("water_sample_rate = evaporation_rate()")
        self.assertLess(charge, next_rate)
        self.assertNotIn("minutes * evaporation_rate()", settle)

    def test_wet_pots_are_sampled_without_food_or_an_interaction(self):
        process = self.block("/process_interval(")
        self.assertIn("world.time - water_tick >= ZEER_SAMPLE_INTERVAL", process)
        self.assertIn("settle_water()", process)
        self.assertIn("processing_objects |= src", self.block("/proc/pour_water("))
        self.assertIn("processing_objects -= src", self.block("/proc/settle_water()"))
        self.assertNotIn("storage", "\n".join(process.splitlines()[1:]))

    def test_loading_wet_pots_discards_offline_elapsed_time(self):
        load = self.block("/after_load()")
        self.assertIn("water_tick = null", load)
        self.assertIn("water_sample_rate = 0", load)
        self.assertIn("if (water > 0)\n\t\tprocessing_objects |= src", load)
        self.assertIn('key == "water_sample_rate"', self.block("/persistence_runtime_var("))
        self.assertIn("if (!isnull(water_tick) && water_tick <= now)", self.block("/proc/settle_water()"))
