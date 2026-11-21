"""Offline source contract for Warding and Paired stones; does not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


TEXT = read('code/modules/divine/arcane_ward.dm')
ENCHANT = read('code/modules/divine/arcane_enchant.dm')
MATERIALS = read('code/modules/divine/arcane_materials.dm')


def body(text, header):
    return text.split(header, 1)[1].split('\n/', 1)[0]


class ArcaneWardSource(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\modules\\divine\\arcane_ward.dm"', read('civ13.dme'))

    def test_recipes(self):
        self.assertIn('"warding" = list("aspect" = "ward", "count" = 2, "gem" = 0, "charges" = list(10, 20, 30), "vigil" = TRUE)', ENCHANT)
        self.assertIn('"paired" = list("aspect" = "omen", "count" = 2, "gem" = 0, "charges" = list(5, 10, 15))', ENCHANT)

    def test_only_chests_closets_and_doors(self):
        fits = body(TEXT, '/proc/arcane_wardable(')
        self.assertIn('/obj/structure/closet', fits)
        self.assertIn('/obj/structure/simple_door', fits)

    def test_ward_refuses_non_owners_and_spends_a_charge(self):
        refuse = body(TEXT, '/obj/proc/arcane_ward_refuses(')
        self.assertIn('user.ckey in arcane_ward_owners', refuse)
        self.assertIn('arcane_ward_charges--', refuse)
        self.assertIn('ARCANE_WARD_REFUSE_GAP', refuse)
        self.assertIn('log_admin(', refuse)
        self.assertIn('arcane_ward_refuses(user)', read('code/game/objects/structures/crates_lockers/closets.dm'))
        self.assertIn('arcane_ward_refuses(user)', body(read('code/game/objects/structures/door.dm'), '/obj/structure/simple_door/proc/canOpen('))

    def test_ward_needs_a_vigil_and_named_owners(self):
        choose = body(ENCHANT, '/mob/living/human/proc/arcane_imbue_choose()')
        self.assertIn('arcane_ward_pick_owners()', choose)
        self.assertIn('divine_gather_vigil(target)', choose)
        self.assertIn('recipe["vigil"] && !arcane_vigil_holds()', body(ENCHANT, '/mob/living/human/proc/arcane_imbue_problem('))
        self.assertIn('kept >= 3', body(TEXT, '/mob/living/human/proc/arcane_vigil_holds()'))

    def test_wards_count_toward_the_cap_and_reload(self):
        choose = body(ENCHANT, '/mob/living/human/proc/arcane_imbue_choose()')
        self.assertIn('arcane_wards_of(ckey)', choose)
        self.assertIn('arcane_ward_loaded()', body(read('code/modules/divine/repository.dm'), '/obj/after_load()'))
        self.assertIn('arcane_wards_of(H.ckey)', read('code/modules/admin/verbs/divine_patron.dm'))

    def test_imbue_targets_the_structure(self):
        covenant = read('code/modules/divine/covenant.dm')
        self.assertIn('target == caster.arcane_imbue_target()', covenant)
        self.assertIn('target = arcane_imbue_target()', covenant)

    def test_paired_stones(self):
        apply = body(TEXT, '/mob/living/human/proc/arcane_pair_apply(')
        self.assertIn('S.arcane_pair = id', apply)
        whisper = body(TEXT, '/mob/living/human/proc/arcane_whisper_stone()')
        self.assertIn('arcane_magic_user()', whisper)
        self.assertIn('arcane_pair_other()', whisper)
        self.assertIn('arcane_enchant_spend(', whisper)
        self.assertIn('arcane_whisper_stone', read('code/modules/divine/arcane_altars.dm'))
        self.assertIn('A.arcane_enchant || B.arcane_enchant', body(MATERIALS, '/proc/arcane_same_virtue('))

    def test_enchanted_items_are_never_used_as_materials(self):
        materials = body(ENCHANT, '/mob/living/human/proc/arcane_imbue_materials(')
        self.assertEqual(materials.count('!I.arcane_enchant'), 4)

    def test_new_materials(self):
        water = body(MATERIALS, '/mob/living/human/proc/arcane_drew_water(')
        self.assertIn('arcane_attune(RG, "ward", 1, "sea water")', water)
        sand = body(MATERIALS, '/mob/living/human/proc/arcane_dug_sand(')
        self.assertIn('arcane_storm_near(T)', sand)
        self.assertIn('arcane_attune(G, "omen", 2, "storm glass")', sand)
        self.assertIn('H.arcane_dug_sand(T)', read('code/game/turfs/floor_attackby.dm'))


if __name__ == '__main__':
    unittest.main()
