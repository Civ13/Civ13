"""Source contracts for realistic steelmaking (docs/steelmaking.md).

Offline: reads the DM sources, never compiles or runs the game.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def proc(source, header):
    start = source.index(header)
    rest = source[start + len(header):]
    end = re.search(r'\n(?=[^\t\n/#]|/(?!/))', rest)
    return rest[:end.start()] if end else rest


GRADES = read('code/modules/1713/steel_grades.dm')
REFINING = read('code/game/objects/structures/blacksmithing/refining.dm')
ANVIL = read('code/game/objects/structures/blacksmithing/blacksmithing.dm')
FUEL = read('code/modules/1713/solid_fuel.dm')
FACTORY = read('code/modules/1713/factory_machines.dm')
QUENCH = read('code/modules/1713/quench_tub.dm')
TATARA = read('code/modules/1713/tatara.dm')
DME = read('civ13.dme')
CARBURIZING = read('code/modules/1713/carburizing.dm')
CRUCIBLE = read('code/modules/1713/crucible_steel.dm')
NODES = read('code/modules/research_tree/research_node.dm')
RECIPES = read('config/crafting/material_recipes_global.txt')


class SteelGrades(unittest.TestCase):
    def test_compiled(self):
        self.assertIn('#include "code\\modules\\1713\\steel_grades.dm"', DME)

    def test_grades_are_steel_subtypes_with_their_own_stacks(self):
        self.assertIn('/obj/item/stack/material/var/stock_grade = 1', GRADES)
        for grade, factor in (('blister', '0.9'), ('fine', '1.1')):
            with self.subTest(grade=grade):
                block = proc(GRADES, f'/obj/item/stack/material/steel/{grade}\n')
                self.assertIn(f'stock_grade = {factor}', block)
                self.assertIn('stacktype = type', proc(GRADES, f'/obj/item/stack/material/steel/{grade}/New()'))

    def test_forging_applies_grade_before_the_quench(self):
        self.assertIn('apply_stock_grade(new rtype (loc,material_name), P)', ANVIL)
        apply = proc(GRADES, '/obj/structure/anvil/proc/apply_stock_grade(')
        self.assertIn('W.crafting_quality *= stock.stock_grade', apply)
        self.assertIn('W.forged_grade = stock.stock_grade', apply)
        quench = proc(QUENCH, '/obj/structure/quench_tub/proc/quench(')
        self.assertIn('var/hardened = QUENCHED_QUALITY * W.forged_grade', quench)
        self.assertIn('W.crafting_quality = hardened', quench)
        self.assertLess(quench.index('if (!istype(W))'), quench.index('W.forged_grade'))

    def test_tamahagane_folds_into_fine_steel(self):
        self.assertIn('spawn_stack(/obj/item/stack/material/steel/fine, loc, batches * FOLD_STEEL)', TATARA)


class BloomeryFuel(unittest.TestCase):
    def rates(self):
        body = re.search(r'bloomery_fuel_rates = list\((.*?)\)\n', FUEL, re.S)[1]
        return {k: float(v) for k, v in re.findall(r'"(\w+)" = ([\d.]+)', body)}

    def test_charcoal_or_wood_only(self):
        rates = self.rates()
        self.assertEqual(rates['charcoal'], 2)
        self.assertEqual(rates['wood'], 1)
        for refused in ('coal', 'leaf', 'dung'):
            self.assertNotIn(refused, rates)
        self.assertIn('istype(I, /obj/item/stack/ore/coal)', proc(GRADES, '/obj/structure/furnace/proc/fuel_refusal('))
        manual = proc(REFINING, '/obj/structure/furnace/proc/accept_manual_stack(')
        self.assertLess(manual.index('fuel_refusal(I)'), manual.index('solid_fuel_value(I, fuel_rates())'))
        self.assertEqual(FACTORY.count('solid_fuel_unit_value(S, fuel_rates())'), 2)

    def test_firing_cost_scales_with_ore(self):
        self.assertIn('#define BLOOMERY_FIRING_BASE 2', GRADES)
        self.assertIn('#define BLOOMERY_FUEL_PER_ORE 1', GRADES)
        start = proc(REFINING, '/obj/structure/furnace/proc/start_smelt()')
        self.assertIn('burn_structure_fuel(firing_fuel_cost())', start)
        self.assertIn('blown_firing = bellows_blowing()', start)
        self.assertIn('if (!on && has_firing_fuel())', REFINING)
        self.assertIn('if (!on && iron > 0 && has_firing_fuel())', FACTORY)
        # Kilns keep their old flat firing.
        self.assertIn('return 2', proc(GRADES, '/obj/structure/furnace/kiln/firing_fuel_cost()'))


class SteelyBloom(unittest.TestCase):
    def test_blown_firing_leaves_steely_bloom(self):
        process = proc(REFINING, '/obj/structure/furnace/process()')
        self.assertIn('blown_firing ? steely_bloom_count(iron) : 0', process)
        self.assertIn('spawn_stack(/obj/item/stack/ore/iron_sponge/steely, src.loc, steely)', process)
        self.assertIn('#define STEELY_BLOOM_CHANCE 10', GRADES)

    def test_anvil_sorts_steely_bloom_before_sponge(self):
        self.assertLess(ANVIL.index('istype(P, /obj/item/stack/ore/iron_sponge/steely)'),
                        ANVIL.index('else if (istype(P, /obj/item/stack/ore/iron_sponge))'))
        sort = proc(GRADES, '/obj/structure/anvil/proc/sort_steely_bloom(')
        self.assertIn('spawn_stack(/obj/item/stack/material/steel/blister, loc, initial_amount)', sort)
        self.assertIn('stacktype = type', proc(GRADES, '/obj/item/stack/ore/iron_sponge/steely/New()'))


class Carburizing(unittest.TestCase):
    def test_built_from_clay_with_iron_smithing(self):
        self.assertIn('#include "code\\modules\\1713\\carburizing.dm"', DME)
        self.assertIn('RECIPE: /material/clay/,carburizing pot,/obj/structure/carburizing_pot,8,', RECIPES)
        self.assertIn('"/obj/structure/carburizing_pot" = "iron_smithing"', NODES)

    def test_firing_makes_blister_steel_and_case_hardens(self):
        finish = proc(CARBURIZING, '/obj/structure/carburizing_pot/proc/finish_burn()')
        self.assertIn('spawn_stack(/obj/item/stack/material/steel/blister, T, bars - uneven)', finish)
        self.assertIn('spawn_stack(/obj/item/stack/material/iron, T, uneven)', finish)
        self.assertIn('case_harden(W)', finish)
        harden = proc(CARBURIZING, '/proc/case_harden(')
        self.assertIn('W.get_material_name() != "iron"', harden)
        self.assertIn('min(CASE_HARDEN_MAX, W.crafting_quality * CASE_HARDEN_FACTOR)', harden)

    def test_burn_resumes_after_load_without_spawn(self):
        self.assertNotIn('spawn(', CARBURIZING)
        self.assertIn('start_burn_loop()', proc(CARBURIZING, '/obj/structure/carburizing_pot/after_load()'))
        self.assertIn('key == "burn_epoch"', CARBURIZING)

    def test_anvil_folds_blister_steel(self):
        self.assertIn('istype(P, /obj/item/stack/material/steel/blister) && fold_blister_steel(P, H)', ANVIL)
        fold = proc(CARBURIZING, '/obj/structure/anvil/proc/fold_blister_steel(')
        self.assertIn('spawn_stack(/obj/item/stack/material/steel, loc, batches)', fold)
        self.assertIn('#define BLISTER_PER_FOLD 2', CARBURIZING)


class CrucibleSteel(unittest.TestCase):
    def test_node_recipe_and_anvil_face(self):
        self.assertIn('#include "code\\modules\\1713\\crucible_steel.dm"', DME)
        self.assertIn('register_research_node(new /datum/research_node("crucible_steel", "Crucible Steel", "Industrial", 165, 1, '
                      'RESEARCH_MODE_ANALYSIS, list("iron_smithing"), 2))', NODES)
        self.assertIn('"/obj/item/weapon/clay/crucible" = "crucible_steel"', NODES)
        self.assertIn('RECIPE: /material/clay/,unfired crucible,/obj/item/weapon/clay/crucible,1,', RECIPES)
        self.assertIn('anvil_steel_face_nodes = list("steelmaking", "tatara_smelting", "crucible_steel")', ANVIL)

    def test_kiln_hooks(self):
        self.assertIn('if (accept_crucible(I, H))', proc(REFINING, '/obj/structure/furnace/kiln/attackby('))
        self.assertIn('fire_crucibles()', proc(REFINING, '/obj/structure/furnace/kiln/process()'))
        self.assertIn('return 2 + crucible_fuel()', proc(GRADES, '/obj/structure/furnace/kiln/firing_fuel_cost()'))

    def test_only_blown_firings_melt_and_crucibles_can_crack(self):
        fired = proc(CRUCIBLE, '/obj/item/weapon/steel_crucible/proc/kiln_fired(')
        self.assertLess(fired.index('if (!blown)'), fired.index('heat++'))
        self.assertIn('prob(crack_chance())', fired)
        self.assertIn('spawn_stack(/obj/item/stack/material/steel/fine, T, 1)', fired)
        self.assertIn('#define CRUCIBLE_FIRINGS 3', CRUCIBLE)
        self.assertIn('blown_firing', proc(CRUCIBLE, '/obj/structure/furnace/kiln/proc/fire_crucibles()'))


if __name__ == '__main__':
    unittest.main()
