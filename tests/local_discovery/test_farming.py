"""Source-derived offline parity; run with unittest discovery in this directory."""
import itertools
import unittest
from source_adapter import ROOT, baseline, compile_proc, entity, execute, procedure, Record

PATH = "code/game/objects/farming.dm"
SIGNATURE = "/obj/structure/farming/plant/proc/water_proc()"
BEFORE = baseline(PATH)
AFTER = (ROOT / PATH).read_text(encoding="utf-8")
OLD = procedure(BEFORE, SIGNATURE)
NEW = procedure(AFTER, SIGNATURE)
OLD_CODE = compile_proc(OLD, water=True)
NEW_CODE = compile_proc(NEW, water=True)
SOURCE_START = "\tfor (var/turf/floor/"
SOURCE_END = "\t// Decrease water level"


def without_discovery(source):
    start = source.index(SOURCE_START, source.index(SIGNATURE))
    end = source.index(SOURCE_END, start)
    return source[:start] + source[end:]


def state(*, climate="temperate", weather="", water=60, max_water=60,
          mushroom="", heat=False, area=True):
    plant = entity("/obj/structure/farming/plant" + mushroom)
    return dict(src=plant, loc=plant, area=Record(icon_state=weather, climate=climate)
                if area else None, water=water, max_water=max_water,
                map=Record(heat_wave=heat), stage=4, death=None)


def run(code, objects=(), **options):
    return execute(code, objects, **state(**options))


class FarmingDiscovery(unittest.TestCase):
    def test_only_discovery_changes(self):
        # Pin the audited water helper outside its discovery loop. Other farming
        # features (such as timber seedlings) may evolve independently.
        self.assertEqual(without_discovery(OLD), without_discovery(NEW))
        self.assertEqual(OLD.count("range(2, src)"), 3)
        self.assertEqual(NEW.count("range(2, src)"), 1)

    def test_sources_and_boundaries(self):
        comparisons = 0
        kinds = ("/turf/floor/beach/water", "/turf/floor/beach/water/deep",
                 "/turf/floor/trench/flooded", "/turf/floor/trench/flooded/subtype",
                 "/turf/floor/trench", "/turf/floor/dirt", "/turf/wall",
                 "/obj/structure")
        for kind, salty, flooded, irrigation, position in itertools.product(
                kinds, (False, True), (False, True), (False, True),
                ((0, 0, 1), (2, 2, 1), (3, 0, 1), (0, 0, 2))):
            obj = entity(kind, salty=salty, flooded=flooded, irrigation=irrigation,
                         x=position[0], y=position[1], z=position[2])
            for climate, heat, water in itertools.product(
                    ("temperate", "desert", "savanna", "semiarid"),
                    (False, True), (0, 15, 25, 60, 100)):
                self.assertEqual(run(OLD_CODE, [obj], climate=climate, heat=heat, water=water)[:4],
                                 run(NEW_CODE, [obj], climate=climate, heat=heat, water=water)[:4])
                comparisons += 1
        print(f"farming source/boundary parity comparisons={comparisons}")

    def test_weather_mushroom_and_missing_area_precedence(self):
        for weather, mushroom, area in itertools.product(
                ("", "rain", "monsoon", "snow_storm", "sandstorm",
                 "rain_snow_storm", "snow_storm_sandstorm"),
                ("", "/mushroom", "/mushroom/subtype", "/mushroompsy"), (False, True)):
            options = dict(weather=weather, mushroom=mushroom, area=area, water=55)
            old, new = run(OLD_CODE, **options), run(NEW_CODE, **options)
            self.assertEqual(old[:4], new[:4])
            if weather or mushroom or not area:
                self.assertEqual(new[-1]["range_calls"], 0)
        self.assertEqual(run(NEW_CODE, weather="rain", water=100)[1], 60)
        self.assertEqual(run(NEW_CODE, weather="snow_storm")[3], "frozen")
        self.assertEqual(run(NEW_CODE, weather="sandstorm")[3], "destroyed")
        self.assertEqual(run(NEW_CODE, water=15)[3], "dry")

    def test_mixed_source_order_and_counts(self):
        fresh = entity("/turf/floor/beach/water", salty=False, flooded=False, irrigation=False)
        trench = entity("/turf/floor/trench/flooded", salty=False, flooded=True, irrigation=False)
        irrigation = entity("/turf/floor/dirt", salty=False, flooded=True, irrigation=True)
        salt = entity("/turf/floor/beach/water", salty=True, flooded=True, irrigation=True)
        for objects in itertools.permutations((fresh, trench, irrigation, salt)):
            self.assertEqual(run(OLD_CODE, objects)[:4], run(NEW_CODE, objects)[:4])
        for label, objects, expected_old in (
                ("dry", [], 3), ("salt only", [salt], 3),
                ("freshwater", [fresh], 1), ("trench", [trench], 2),
                ("irrigation", [irrigation], 3)):
            old, new = run(OLD_CODE, objects), run(NEW_CODE, objects)
            self.assertEqual(old[-1]["range_calls"], expected_old)
            self.assertEqual(new[-1]["range_calls"], 1)
            print(f"farming {label}: range calls {expected_old}->1")

    def test_independent_semantic_oracles(self):
        for kind, flooded, irrigation, expected in (
                ("/turf/floor/beach/water", False, False, 60),
                ("/turf/floor/trench/flooded", False, False, 45),
                ("/turf/floor/trench/flooded", True, False, 60),
                ("/turf/floor/dirt", True, False, 45),
                ("/turf/floor/dirt", False, True, 45),
                ("/turf/floor/dirt", True, True, 60)):
            obj = entity(kind, salty=False, flooded=flooded, irrigation=irrigation)
            self.assertEqual(run(NEW_CODE, [obj])[1], expected)
            obj.salty = True
            self.assertEqual(run(NEW_CODE, [obj])[1], 45)

    def test_generated_source_negative_controls(self):
        salt = entity("/turf/floor/beach/water", salty=True, flooded=True, irrigation=True)
        dry_channel = entity("/turf/floor/dirt", salty=False, flooded=False, irrigation=True)
        for target, replacement, objects, options in (
                ("if (WT.salty)", "if (FALSE)", [salt], {}),
                ("WT.flooded &&", "TRUE &&", [dry_channel], {}),
                ("min(water + 15, max_water)", "water + 15", [], {"weather": "rain"})):
            self.assertEqual(NEW.count(target), 1)
            mutant = compile_proc(NEW.replace(target, replacement), water=True)
            self.assertNotEqual(run(mutant, objects, **options)[:4],
                                run(OLD_CODE, objects, **options)[:4])


if __name__ == "__main__":
    unittest.main(verbosity=2)
