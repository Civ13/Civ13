"""Water quality by kind, washing fixes and rarer flea typhus (source checks)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def proc_body(source, header):
    rest = source.split(header, 1)[1]
    lines = []
    for line in rest.splitlines()[1:]:
        if line and not line.startswith(("\t", " ")):
            break
        lines.append(line)
    return "\n".join(lines)


QUALITY = read("code/modules/1713/water_quality.dm")
NEEDS = read("code/game/mob/living/carbon/human/human_needs.dm")
DEFINES = read("code/__defines/mobs.dm")


def define(name, text=None):
    m = re.search(r"#define %s ([0-9.]+)" % name, text or DEFINES)
    assert m, name
    return float(m.group(1))


def germ_level(sickness, kind="fresh", current=False, salty=False, temp=20):
    """Mirror of water_kind_germs(); kept equal by the source checks below."""
    if sickness <= 0:
        return 0
    if kind in ("swamp", "flooded"):
        return sickness
    if current:
        return sickness * 0.5
    if not salty and sickness == 1 and temp >= define("WATER_STAGNANT_HEAT", QUALITY):
        return define("WATER_STAGNANT_GERMS", QUALITY)
    return sickness


class WaterQualityTest(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\modules\\1713\\water_quality.dm"', read("civ13.dme"))

    def test_proc_shape_matches_model(self):
        outer = proc_body(QUALITY, "/turf/floor/beach/water/proc/water_germ_level()")
        self.assertIn(". = water_kind_germs()", outer)
        self.assertIn("if (!salty)", outer)
        self.assertIn(". += river_foul_germs(src)", outer)
        body = proc_body(QUALITY, "/turf/floor/beach/water/proc/water_kind_germs()")
        order = ["sickness <= 0", "/turf/floor/beach/water/swamp", "river_current_direction(src)",
                 "sickness * 0.5", "get_temp(src) >= WATER_STAGNANT_HEAT"]
        positions = [body.index(part) for part in order]
        self.assertEqual(positions, sorted(positions))
        self.assertTrue(body.rstrip().endswith("return sickness"))

    def test_table(self):
        self.assertEqual(germ_level(1, current=True), 0.5)
        self.assertEqual(germ_level(2, kind="jungle", current=True), 1)
        self.assertEqual(germ_level(1), 1)
        self.assertEqual(germ_level(1, temp=30), 1.5)
        self.assertEqual(germ_level(1, salty=True, temp=30), 1)
        self.assertEqual(germ_level(2, kind="flooded", current=True), 2)
        self.assertEqual(germ_level(3, kind="swamp", current=True), 3)

    def test_every_open_water_user_asks_the_proc(self):
        for rel in ("code/game/turfs/floor_attackby.dm", "code/modules/1713/factory_pipes.dm",
                    "code/modules/agent_control/agent_characters.dm"):
            text = read(rel)
            self.assertIsNone(re.search(r"\b(WT|W)\.sickness\b", text), rel)
            self.assertIn("water_germ_level()", text, rel)
        self.assertIn("catch_dirty_water_illness(water_germ_level()*15)", read("code/game/turfs/floor_attackby.dm"))

    def test_soap_cleans_only_after_the_wash(self):
        soap = read("code/game/objects/items/soap.dm")
        start = soap.index("S.washing = TRUE")
        wash = soap.index("var/finished = do_after(user, 40, src)", start)
        guard = soap.index("if (!finished || !soap_wash_available(user)", wash)
        self.assertGreater(soap.index("hygiene = HYGIENE_LEVEL_CLEAN", start), guard)

    def test_tubs_never_lower_hygiene(self):
        shower = read("code/game/objects/structures/watercloset.dm")
        self.assertIn("H.raise_hygiene(HYGIENE_LEVEL_NORMAL)", shower)
        self.assertNotIn("H.set_hygiene(src.cleanliness)", shower)
        body = proc_body(NEEDS, "/mob/living/human/proc/raise_hygiene(amount)")
        self.assertIn("if (amount > hygiene)", body)

    def test_fleas_are_slow_and_rarely_carry_typhus(self):
        infest = define("FLEA_INFEST_CHANCE")
        share = define("FLEA_TYPHUS_SHARE")
        rate = define("FLEA_TYPHUS_RATE")
        # On average an hour or more of filthy clothes before fleas arrive.
        self.assertGreaterEqual(100 / infest, 3000)
        self.assertLessEqual(share, 15)
        # At most about one in three over an hour even with typhus fleas.
        self.assertLessEqual(1 - (1 - rate / 100) ** 3600, 0.35)
        start = NEEDS.index("/mob/living/human/proc/handle_hygiene()")
        body = NEEDS[start:NEEDS.index("/mob/living/human/proc/adjust_hygiene(", start)]
        self.assertIn("prob(FLEA_INFEST_CHANCE)", body)
        self.assertIn("C.flea_typhus = prob(FLEA_TYPHUS_SHARE)", body)
        self.assertIn("typhus_fleas ? FLEA_TYPHUS_RATE", body)
        self.assertIn('infection_chance_scale("typhus")', body)
        self.assertNotIn("0.2 * infection_chance_scale", body)


class RiverFoulTest(unittest.TestCase):
    FOUL = read("code/modules/1713/river_foul.dm")

    def test_included_before_river_flow(self):
        dme = read("civ13.dme")
        self.assertLess(dme.index("river_foul.dm"), dme.index("river_flow.dm"))

    def test_load_steps_with_the_water(self):
        self.assertIn("F.step_foul()", read("code/modules/1713/river_flood.dm"))
        body = proc_body(self.FOUL, "/datum/river_flood/proc/step_foul()")
        self.assertIn("RIVER_FLOOD_RELEASE", body)
        self.assertIn("incoming[down[i]]", body)

    def test_users_of_foul_water(self):
        self.assertIn("river_fouled_at(W)", read("code/modules/1713/aqueducts.dm"))
        self.assertIn("P.fouls_toward(A)", read("code/modules/1713/sewers.dm"))
        self.assertIn("river_foul_fish_factor(", read("code/modules/1713/fishing_grounds.dm"))
        self.assertIn("scum_refresh_view()", read("code/modules/1713/flood_effects.dm"))
        self.assertTrue((ROOT / "icons/effects/water_scum.dmi").exists())


if __name__ == "__main__":
    unittest.main()
