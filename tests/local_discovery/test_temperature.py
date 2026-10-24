"""Source-derived offline get_temp parity with counted synthetic discovery."""
import itertools
import re
import unittest
from source_adapter import ROOT, baseline, compile_proc, entity, execute, procedure, Record

PATH = "code/modules/1713/weather.dm"
SIGNATURE = "/proc/get_temp(var/atom/A)"
BEFORE = baseline(PATH)
AFTER = (ROOT / PATH).read_text(encoding="utf-8")
OLD = procedure(BEFORE, SIGNATURE)
NEW = procedure(AFTER, SIGNATURE)
OLD_CODE = compile_proc(OLD)
NEW_CODE = compile_proc(NEW)
KINDS = ("/obj/structure/oven/big", "/obj/structure/brazier",
         "/obj/structure/heatsource", "/obj/structure/oven/fireplace",
         "/obj/structure/engine")


def tail_code(source):
    # Inject only the input to the unchanged insulation and actual heater tail.
    tail = source[source.index("\t//inside areas"):]
    return compile_proc("/proc/offline_tail()\n\tvar/loc_temp = ambient\n"
                        "\tvar/area/mob_area = get_area(A)\n" + tail)


OLD_TAIL, NEW_TAIL = tail_code(OLD), tail_code(NEW)


def state(*, inside=False, antarctica=False, ambient=0, season="WINTER",
          climate="temperate", time="Evening", weather=0, intensity=1.0,
          icon="", atom=True, area=True, has_map=True):
    return dict(A=entity("/mob/living") if atom else None,
                area=Record(location=int(inside), climate=climate, weather=weather,
                            weather_intensity=intensity, icon_state=icon) if area else None,
                ambient=ambient, season=season, time_of_day=time,
                map=Record(ID="antarctica" if antarctica else "other") if has_map else None)


def run(code, objects=(), **options):
    return execute(code, objects, **state(**options))


def heaters(statuses):
    # 0 absent, 1 present/off, 2 present/on.
    return [entity(kind, on=(status == 2)) for kind, status in zip(KINDS, statuses) if status]


def without_heaters(source):
    matches = list(re.finditer(r"\n\t\tif \((?:loc_temp < 19 && )?map && map.ID == MAP_ANTARCTICA\)", source))
    assert len(matches) == 1
    start = matches[0].start()
    end = source.index("\n\treturn loc_temp", start)
    return source[:start] + source[end:]


class TemperatureDiscovery(unittest.TestCase):
    def test_only_heater_discovery_changes(self):
        self.assertEqual(without_heaters(BEFORE), without_heaters(AFTER))
        self.assertEqual(OLD.count("range("), 5)
        self.assertEqual(NEW.count("range("), 5)
        # No proc early-return is introduced; future tail adjustments still run.
        self.assertEqual(OLD.count("return loc_temp"), NEW.count("return loc_temp"))

    def test_entire_environment_function(self):
        comparisons = 0
        climates = ("temperate", "sea", "tundra", "taiga", "semiarid", "desert",
                    "jungle", "savanna", "unknown")
        seasons = ("WINTER", "FALL", "SUMMER", "SPRING", "Dry Season", "Wet Season", "unknown")
        times = ("Midday", "Afternoon", "Morning", "Evening", "Early Morning", "Night", "unknown")
        weather_cases = ((0, 1.0, ""), (1, 1.0, "rain"), (1, 2.0, "rain"),
                         (1, 3.0, "monsoon"), (2, 1.0, "snow_storm"),
                         (2, 1.0, "sandstorm"), (2, 1.0, "other"))
        scenarios = ([0, 0, 0, 0, 0], [2, 0, 0, 0, 0], [0, 2, 0, 0, 0],
                     [0, 0, 2, 0, 0], [0, 0, 0, 2, 0], [0, 0, 0, 0, 2], [2, 2, 2, 2, 2])
        for season, climate, time, weather_case, inside, map_case in itertools.product(
                seasons, climates, times, weather_cases, (False, True), ("none", "other", "antarctica")):
            weather, intensity, icon = weather_case
            options = dict(season=season, climate=climate, time=time, weather=weather,
                           intensity=intensity, icon=icon, inside=inside,
                           antarctica=map_case == "antarctica", has_map=map_case != "none")
            objects = heaters(scenarios[comparisons % len(scenarios)])
            self.assertEqual(run(OLD_CODE, objects, **options)[0], run(NEW_CODE, objects, **options)[0])
            comparisons += 1
        for options in ({"atom": False}, {"area": False}):
            self.assertEqual(run(NEW_CODE, **options)[0], 20)
            self.assertEqual(run(NEW_CODE, **options)[-1]["range_calls"], 0)
        print(f"whole get_temp environmental parity comparisons={comparisons}")

    def test_all_heater_states_and_thresholds(self):
        comparisons = 0
        for statuses, ambient, inside, antarctica in itertools.product(
                itertools.product((0, 1, 2), repeat=5),
                (-100, -10, 0, 10, 18, 18.999, 19, 19.001, 21, 21.999, 22, 22.001, 50),
                (False, True), (False, True)):
            options = dict(ambient=ambient, inside=inside, antarctica=antarctica)
            objects = heaters(statuses)
            self.assertEqual(run(OLD_TAIL, objects, **options)[0], run(NEW_TAIL, objects, **options)[0])
            comparisons += 1
        print(f"heater-state/threshold parity comparisons={comparisons}")

    def test_antarctica_oven_does_not_settle_22c_heaters(self):
        oven = entity(KINDS[0], on=True, x=5)
        self.assertEqual(run(NEW_TAIL, [oven], inside=True, antarctica=True, ambient=-10)[0], 19)
        for kind in KINDS[1:]:
            self.assertEqual(run(NEW_TAIL, [oven, entity(kind, on=True)],
                                 inside=True, antarctica=True, ambient=-10)[0], 22)
        self.assertEqual(run(NEW_TAIL, [oven], ambient=-10)[0], -10)
        self.assertEqual(run(NEW_TAIL, [oven], inside=True, ambient=-10)[0], 10)

    def test_radii_z_subtypes_and_source_order(self):
        for kind, radius in zip(KINDS, (5, 3, 3, 1, 1)):
            for on, dx, dy, z in itertools.product((False, True), (0, radius, radius + 1),
                                                   (0, radius, radius + 1), (1, 2)):
                obj = entity(kind + "/subtype", on=on, x=dx, y=dy, z=z)
                options = dict(inside=True, antarctica=True, ambient=-10)
                self.assertEqual(run(OLD_TAIL, [obj], **options)[0], run(NEW_TAIL, [obj], **options)[0])
                for ordered in ([entity(kind, on=False), obj], [obj, entity(kind, on=False)]):
                    self.assertEqual(run(OLD_TAIL, ordered, **options)[0],
                                     run(NEW_TAIL, ordered, **options)[0])

    def test_operation_counts(self):
        cases = (("warm outdoor", 22, False, False, [], 4, 0),
                 ("cold no heater", -10, False, False, [], 4, 4),
                 ("first heater", -10, False, False, heaters([0, 2, 2, 2, 2]), 4, 1),
                 ("second heater", -10, False, False, heaters([0, 0, 2, 2, 2]), 4, 2),
                 ("third heater", -10, False, False, heaters([0, 0, 0, 2, 2]), 4, 3),
                 ("last heater", -10, False, False, heaters([0, 0, 0, 0, 2]), 4, 4),
                 ("Antarctica oven only", -10, True, True, heaters([2, 0, 0, 0, 0]), 5, 5),
                 ("Antarctica oven then brazier", -10, True, True, heaters([2, 2, 2, 2, 2]), 5, 2),
                 ("Antarctica 19C", 19, True, True, [], 5, 4),
                 ("Antarctica 22C", 22, True, True, [], 5, 0))
        for label, ambient, inside, antarctica, objects, old_count, new_count in cases:
            options = dict(ambient=ambient, inside=inside, antarctica=antarctica)
            old, new = run(OLD_TAIL, objects, **options), run(NEW_TAIL, objects, **options)
            self.assertEqual(old[0], new[0])
            self.assertEqual(old[-1]["range_calls"], old_count)
            self.assertEqual(new[-1]["range_calls"], new_count)
            print(f"temperature {label}: range calls {old_count}->{new_count}; result={new[0]}")

    def test_generated_source_negative_controls(self):
        # Two tempting but invalid optimizations must change the observed result.
        bad_oven = NEW.replace("loc_temp = 19", "loc_temp = 22")
        self.assertNotEqual(run(tail_code(bad_oven), heaters([2, 0, 0, 0, 0]),
                                inside=True, antarctica=True, ambient=-10)[0], 19)
        bad_gate = NEW.replace("\tif (loc_temp < 22)", "\tif (loc_temp < 19)")
        self.assertEqual(run(tail_code(bad_gate), heaters([0, 2, 0, 0, 0]), ambient=20)[0], 20)
        self.assertEqual(run(NEW_TAIL, heaters([0, 2, 0, 0, 0]), ambient=20)[0], 22)


if __name__ == "__main__":
    unittest.main(verbosity=2)
