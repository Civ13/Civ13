"""Crewed airships (code/modules/naval/air_hull.dm): wiring the native probe relies on.

Offline source checks only; building, lifting, flying, turning, firing down and
save/restore run natively in tests/pedal_bicycle/ride.py --probe air_hull_probe.dm.
"""
import hashlib
import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract

SOURCE = (ROOT / 'code/modules/naval/air_hull.dm').read_text()
BUILT = (ROOT / 'code/modules/craft/built_body.dm').read_text()
COMBAT = (ROOT / 'code/game/objects/structures/pedal_airship_combat.dm').read_text()
BODY = '/datum/craft_body/built/air'


class Deck(unittest.TestCase):
    def test_planks_start_at_a_ladder_top_and_grow_edge_to_edge(self):
        lay = extract(SOURCE, '/proc/air_deck_lay_refusal')
        self.assertIn('/obj/structure/multiz', lay)
        self.assertIn('/obj/covers/airship_deck', lay)
        self.assertIn('for (var/d in cardinal)', lay)
        self.assertIn('C && !C.anchored', lay)
        survey = extract(SOURCE, '/proc/air_hull_survey')
        self.assertIn('found.len > AIR_HULL_MAX_TILES', survey)
        self.assertIn('#define AIR_HULL_MAX_TILES 60\n', SOURCE)

    def test_floors_move_before_what_stands_on_them(self):
        move = extract(BUILT, '/datum/craft_body/built/move_to')
        self.assertIn('riders.Insert(1, M)', move)
        self.assertLess(move.index('if (istype(M, /obj/covers))\n\t\t\t\t\triders.Insert(1, M)'), move.index('craft_step_move(M, D'))


class Flight(unittest.TestCase):
    def test_only_open_air_and_enough_lift(self):
        refusal = extract(SOURCE, BODY + '/tile_refusal')
        self.assertIn('air_deck_open(D)', refusal)
        plan = extract(SOURCE, BODY + '/plan')
        self.assertLess(plan.index('lift_refusal()'), plan.index('..()'))
        self.assertIn('#define AIR_HULL_CELL_LIFT 12\n', SOURCE)
        self.assertIn('return 0', extract(SOURCE, BODY + '/upper_z'))

    def test_engines_only_and_no_pixel_creep(self):
        self.assertIn('return FALSE', extract(SOURCE, '/datum/craft/air/offset_sails'))
        drives = extract(SOURCE, '/datum/craft/air/fit_drives')
        self.assertIn('/datum/craft_drive/fitted/engine', drives)

    def test_views_follow_her_and_are_never_saved(self):
        self.assertIn('update_views()', extract(SOURCE, '/datum/craft/air/on_hop'))
        self.assertIn('update_views()', extract(SOURCE, '/datum/craft/air/on_turn'))
        self.assertIn('key == "craft"', extract(SOURCE, '/obj/structure/airship_helm/persistence_runtime_var'))
        load = extract(SOURCE, '/obj/structure/airship_helm/after_load')
        self.assertIn('craft.anchored = TRUE', load)

    def test_deck_crew_fire_down(self):
        under = extract(COMBAT, '/proc/airborne_ground_under')
        self.assertIn('air_hull_under(user)', under)
        for path in ('code/modules/projectiles/projectile.dm', 'code/game/mob/living/carbon/carbon.dm'):
            self.assertIn('(aloft_pedal_airships.len || air_hull_crafts.len)', (ROOT / path).read_text(), path)


class Wiring(unittest.TestCase):
    def test_recipes_research_and_include(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text()
        for line in ('RECIPE: /material/wood/,airship planks,/obj/item/airship_planks,3,40,0,1,vehicle parts,126,0,0,8,null',
                     'RECIPE: /material/cloth/,airship gas cell,/obj/item/airship_gas_cell,20,200,0,1,vehicle parts,126,0,0,8,null',
                     'RECIPE: /material/wood/,airship helm,/obj/item/airship_helm_kit,10,150,0,1,vehicle parts,126,0,0,8,null'):
            self.assertIn(line, recipes)
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text()
        for path in ('airship_planks', 'airship_gas_cell', 'airship_helm_kit'):
            self.assertIn('"/obj/item/' + path + '" = "powered_flight"', research)
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8-sig')
        self.assertLess(dme.index('naval\\built_hull.dm"'), dme.index('naval\\air_hull.dm"'))

    def test_sprites_are_current(self):
        hashes = {'icons/obj/vehicles/airship_hull.dmi': HULL_SHA, 'icons/obj/vehicles/airship_gas_cell.dmi': CELL_SHA}
        for path, digest in hashes.items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest, path)
        if importlib.util.find_spec('PIL'):
            subprocess.run([sys.executable, str(ROOT / 'tests/airship_hull/airship_hull_sprites.py'), '--check'], check=True)


HULL_SHA = '5ea80a55a08e75bc4f6a0d84742d00d7dae686e748a2120c9f858d8679f41704'
CELL_SHA = 'b4c94b9e3cc32b146c4fa9bd4eb9ddc3200948336dd8aa8a38ba8acb494c0df5'

if __name__ == '__main__':
    unittest.main()
