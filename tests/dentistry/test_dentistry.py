"""Offline source contracts for dentistry (code/modules/1713/dentistry.dm)."""
import json
import re
import struct
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = (ROOT / "code/modules/1713/dentistry.dm").read_text()
DMI = ROOT / "icons/obj/dentistry.dmi"


def dmi_states(path):
    data = path.read_bytes()
    pos = 8
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        if kind == b"zTXt":
            text = zlib.decompress(chunk[chunk.index(0) + 2:]).decode()
            return set(re.findall(r'state = "([^"]*)"', text))
        pos += 12 + length
    return set()


class DentistryTests(unittest.TestCase):
    def test_included_once(self):
        dme = (ROOT / "civ13.dme").read_text()
        self.assertEqual(dme.count('code\\modules\\1713\\dentistry.dm'), 1)

    def test_every_icon_state_is_drawn(self):
        states = dmi_states(DMI)
        used = set(re.findall(r'icon_state = "([^"]+)"', SRC))
        self.assertTrue(used)
        self.assertEqual(used - states, set())

    def test_defines_are_file_local(self):
        defined = set(re.findall(r"(?m)^#define (\w+)", SRC))
        undefined = set(re.findall(r"(?m)^#undef (\w+)", SRC))
        self.assertEqual(defined, undefined)
        self.assertNotIn("return SURGERY_FAILURE", SRC)

    def test_no_object_refs_saved_on_head(self):
        block = SRC[SRC.index("/obj/item/organ/external/head\n"):SRC.index("/obj/item/organ/external/head/proc/reset_dental_state")]
        self.assertNotRegex(block, r"var/(obj|mob|datum)/")
        self.assertIn("var/denture_type = null", block)

    def test_freshness_is_not_saved(self):
        self.assertIn("var/tmp/knocked_out_at", SRC)
        self.assertIn("var/tmp/tooth_owner", SRC)

    def test_hooks(self):
        def has(path, text):
            self.assertIn(text, (ROOT / path).read_text(), path)
        has("code/game/mob/living/carbon/human/human_life.dm", "handle_teeth()")
        has("code/game/objects/structures/kitchen/cooked_meals.dm", "amount = H.dental_bite(src, amount)")
        has("code/game/mob/living/say.dm", "message = dental_speech(message)")
        has("code/game/mob/living/carbon/human/examine.dm", "dental_examine_text(T)")
        has("code/game/mob/living/carbon/human/human_attackhand.dm", "take_out_dentures()")
        organ = (ROOT / "code/modules/organs/organ_external.dm").read_text()
        self.assertIn("knock_out_prosthetics()", organ)
        self.assertIn("T.mark_fresh(owner)", organ)
        self.assertIn("lose_dental_teeth(", organ)
        human = (ROOT / "code/game/mob/living/carbon/human/human.dm").read_text()
        self.assertEqual(human.count("U.reset_dental_state()"), 2)

    def test_recipes_are_mapped_to_research(self):
        recipes = (ROOT / "config/crafting/material_recipes_global.txt").read_text()
        nodes = (ROOT / "code/modules/research_tree/research_node.dm").read_text()
        expected = {
            "/obj/item/weapon/surgery/dental_forceps": "field_surgery",
            "/obj/item/weapon/surgery/dental_forceps/bronze": "field_surgery",
            "/obj/item/dental_bridge": "field_surgery",
            "/obj/item/weapon/tooth_cleaner/chewing_stick": "hygiene",
            "/obj/item/weapon/tooth_cleaner/toothbrush": "sanitation",
            "/obj/item/weapon/surgery/dental_pick": "surgical_theory",
            "/obj/item/dentures/bone": "surgical_theory",
            "/obj/item/dentures/human": "surgical_theory",
            "/obj/item/weapon/clay/porcelain_dentures": "anesthetic_surgery",
            "/obj/item/dentures/vulcanite": "anesthetic_surgery",
            "/obj/item/dentures/acrylic": "modern_medicine",
        }
        for path, node in expected.items():
            self.assertIn(f",{path},", recipes, path)
            self.assertIn(f'"{path}" = "{node}"', nodes, path)

    def test_craft_needs(self):
        needs = json.loads((ROOT / "config/craft_needs.json").read_text())
        self.assertEqual(needs["/obj/item/dental_bridge"]["inputs"], {"/obj/item/stack/teeth": 3})
        self.assertEqual(needs["/obj/item/dentures/human"]["inputs"], {"/obj/item/stack/teeth": 16})
        self.assertIn("knife", needs["/obj/item/dentures/bone"]["tools"])

    def test_era_gates_on_steps(self):
        self.assertIn('known_or_warn(user, "surgical_theory")', SRC)
        self.assertIn('"anesthetic_surgery" : "surgical_theory"', SRC)

    def test_no_spawn_or_sleep(self):
        self.assertNotRegex(SRC, r"\bspawn\(|\bsleep\(")


if __name__ == "__main__":
    unittest.main()
