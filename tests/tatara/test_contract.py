"""Tamahagane and the tatara: source contract checks.

Iron sand is panned or sifted from beach sand from the Classical age, Asia
yields more, and the bloomery (not the blast furnace) smelts it two to one.
The tatara takes charcoal and iron sand by turns, fires for ten minutes,
and breaks open on kera and pig iron; kera sorts into tamahagane and wrought
iron, and tamahagane folds into steel, all behind Tatara Smelting.

    python3 tests/tatara/test_contract.py
"""
import json
import re
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/tatara.dm').read_text(encoding='utf-8')
SIFTING = (ROOT / 'code/modules/1713/resource_sifting.dm').read_text(encoding='utf-8')
ASIA = (ROOT / 'code/game/objects/map_metadata/nomads/nomads_asia.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
DMI = ROOT / 'icons/obj/tatara.dmi'
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
ANVIL = (ROOT / 'code/game/objects/structures/blacksmithing/blacksmithing.dm').read_text(encoding='utf-8')
GATES = (ROOT / 'code/modules/research_tree/recipe_gates.dm').read_text(encoding='utf-8')
ATLAS = json.loads((ROOT / 'scripts/atlas/resource-sources.json').read_text(encoding='utf-8'))
SAND = '/obj/item/stack/ore/iron_sand'


def define(name):
    return int(re.search(r'#define %s (\d+)' % name, SOURCE).group(1))


def proc_body(text, header):
    start = text.index(header)
    end = text.find('\n/', start + 1)
    return text[start:end if end != -1 else len(text)]


def dmi_states():
    data = DMI.read_bytes()
    at = data.index(b'zTXtDescription\x00\x00') + len(b'zTXtDescription\x00\x00')
    text = zlib.decompressobj().decompress(data[at:]).decode()
    return set(re.findall(r'state = "([^"]+)"', text))


class IronSand(unittest.TestCase):
    def test_included_after_the_furnaces(self):
        self.assertEqual(DME.count('code\\modules\\1713\\tatara.dm'), 1)
        self.assertLess(DME.index('blacksmithing\\refining.dm'), DME.index('code\\modules\\1713\\tatara.dm'))

    def test_item_sprites(self):
        states = dmi_states()
        for suffix in ('', '_2', '_3', '_4'):
            self.assertIn('iron_sand' + suffix, states)

    def test_panning_and_beach_sifting_from_age_one(self):
        pan = proc_body(SIFTING, '/mob/living/human/proc/panning_choices(')
        self.assertIn('map.ordinal_age >= 1', pan)
        self.assertIn('choices["Iron sand"] = ' + SAND, pan)
        sift = proc_body(SIFTING, '/mob/living/human/proc/sifting_choices(')
        beach = sift[sift.index('map.ordinal_age >= 1'):sift.index('map.ordinal_age >= 2')]
        self.assertIn('istype(T, /turf/floor/beach/sand)', beach)
        self.assertIn('choices["Iron sand"] = ' + SAND, beach)
        self.assertEqual(SIFTING.count('panning ? panning_choices() : sifting_choices(T)'), 2)

    def test_yields_fit_one_deposit(self):
        pan, sift, bonus = define('IRON_SAND_PAN_UNITS'), define('IRON_SAND_SIFT_UNITS'), define('IRON_SAND_RICH_BONUS')
        self.assertEqual((pan, sift, bonus), (3, 2, 2))
        self.assertLessEqual(pan + bonus, 5)  # deposit_small_resource() refuses more than 5
        self.assertIn('iron_sand_yield(panning) : 1', SIFTING)
        self.assertIn('iron_sand_rich = TRUE', ASIA)

    def test_bloomery_only_two_to_one(self):
        self.assertEqual(define('IRON_SAND_PER_SPONGE'), 2)
        accept = proc_body(SOURCE, '/obj/structure/furnace/accept_manual_stack(')
        self.assertIn('type != /obj/structure/furnace', accept)
        self.assertIn('return ..()', accept)
        smelt = proc_body(SOURCE, '/obj/structure/furnace/process(')
        self.assertLess(smelt.index('iron_sand -= sponge * IRON_SAND_PER_SPONGE'), smelt.index('spawn_stack'))
        self.assertIn('return ..()', smelt)
        self.assertIn('spawn_stack(' + SAND, proc_body(SOURCE, '/obj/structure/furnace/empty('))

    def test_atlas_routes(self):
        routes = {r['name']: r for r in ATLAS['mechanisms']}
        for name in ('Pan iron sand', 'Sift iron sand from beach sand', 'Smelt iron sand in a bloomery'):
            self.assertIn(name, routes)
        self.assertIn(SAND, routes['Pan iron sand']['outputs'])
        self.assertEqual(routes['Smelt iron sand in a bloomery']['inputs'], [SAND])


class Tatara(unittest.TestCase):
    def test_node_and_recipe(self):
        self.assertIn('register_research_node(new /datum/research_node("tatara_smelting", "Tatara Smelting", "Industrial", 165, 1, '
                      'RESEARCH_MODE_ANALYSIS, list("iron_smithing"), 2))', NODES)
        self.assertIn('"/obj/structure/tatara" = "tatara_smelting"', NODES)
        rows = [l for l in RECIPES.splitlines() if l.startswith('RECIPE: ') and ',/obj/structure/tatara,' in l]
        self.assertEqual(rows, ['RECIPE: /material/clay/,clay tatara furnace,/obj/structure/tatara,20,200,1,1,none,26,0,0,8,null'])
        self.assertIn('anvil_steel_face_nodes = list("steelmaking", "tatara_smelting", "crucible_steel")', ANVIL)

    def test_steel_face_warning_names_both_chapters(self):
        # The warning used to name only Steelmaking; it must offer Tatara Smelting too.
        self.assertIn('crafting_nodes_allowed_or_warn(H, anvil_steel_face_nodes)', ANVIL)
        self.assertNotIn('anvil_steel_face_nodes[1]', ANVIL)
        self.assertIn('english_list(names, and_text = " or ")', GATES)
        self.assertIn('Study the [joined] chapter first.', GATES)
        # Repeated clicks within the delay do not repeat the same warning.
        self.assertIn('#define RESEARCH_WALL_REPEAT_DELAY (3 SECONDS)', GATES)
        self.assertIn('last[1] == text && world.time < last[2] + RESEARCH_WALL_REPEAT_DELAY', GATES)

    def test_sprites(self):
        states = dmi_states()
        for state in re.findall(r'icon_state = "(tatara[\w]*|kera|tamahagane)"', SOURCE):
            self.assertIn(state, states)
        for base in ('kera', 'tamahagane'):
            for suffix in ('', '_2', '_3', '_4'):
                self.assertIn(base + suffix, states)

    def test_numbers(self):
        expected = {'TATARA_LIMIT': 30, 'TATARA_MIN_SAND': 3, 'TATARA_MIN_CHARGES': 3, 'TATARA_SAND_PER_KERA': 3,
                    'TATARA_SAND_PER_ZUKU': 10, 'TATARA_BURN_TIME': 6000, 'TATARA_TICK': 100, 'TATARA_CLAY_BACK': 5,
                    'KERA_TAMAHAGANE_PERCENT': 50, 'KERA_WROUGHT_PERCENT': 30, 'FOLD_TAMAHAGANE': 3, 'FOLD_STEEL': 2}
        for name, value in expected.items():
            self.assertEqual(define(name), value, name)

    def test_charging_counts_sand_on_charcoal_and_closes_halfway(self):
        charge = proc_body(SOURCE, '/obj/structure/tatara/proc/charge(')
        self.assertIn('burn_left < TATARA_BURN_TIME / 2', charge)
        self.assertLess(charge.index('if (last_charcoal)'), charge.index('charges++'))
        self.assertIn('S.use(moved)', charge)

    def test_yield_and_break_open(self):
        kera = proc_body(SOURCE, '/obj/structure/tatara/proc/kera_yield(')
        self.assertIn('min(iron_sand, charcoal)', kera)
        self.assertIn('(0.5 + 0.5 * blown)', kera)
        self.assertIn('charges < TATARA_MIN_CHARGES', kera)
        finish = proc_body(SOURCE, '/obj/structure/tatara/proc/finish_burn(')
        self.assertLess(finish.index('kera_yield()'), finish.index('iron_sand = 0'))
        broken = proc_body(SOURCE, '/obj/structure/tatara/proc/break_open(')
        for path in ('/obj/item/stack/ore/kera', '/obj/item/stack/ore/iron_pig', '/obj/item/stack/material/clay'):
            self.assertIn('spawn_stack(' + path, broken)
        self.assertIn('qdel(src)', broken)

    def test_burn_survives_a_load(self):
        self.assertIn('key == "burn_epoch"', SOURCE)
        load = proc_body(SOURCE, '/obj/structure/tatara/after_load(')
        self.assertIn('start_burn_loop()', load)
        self.assertNotIn('spawn(', SOURCE)

    def test_anvil_sorts_and_folds_behind_the_node(self):
        anvil = proc_body(SOURCE, '/obj/structure/anvil/attackby(')
        self.assertIn('return ..()', anvil.split('\n')[1] + anvil.split('\n')[2])
        self.assertIn('crafting_node_allowed_or_warn(H, "tatara_smelting")', anvil)
        self.assertIn('S.amount != initial_amount', anvil)
        self.assertIn('spawn_stack(/obj/item/stack/material/steel/fine, loc, batches * FOLD_STEEL)', anvil)

    def test_atlas_routes(self):
        routes = {r['name'] for r in ATLAS['mechanisms']}
        for name in ('Fire a tatara', 'Sort kera on an anvil', 'Fold tamahagane into steel'):
            self.assertIn(name, routes)


class Washing(unittest.TestCase):
    def test_numbers(self):
        expected = {'KANNA_WASH_UNITS': 2, 'KANNA_STOCK': 20, 'KANNA_REGROW': 600, 'KANNA_WASH_TIME': 300,
                    'SAND_PER_WASH': 5, 'SAND_WASH_TIME': 50}
        for name, value in expected.items():
            self.assertEqual(define(name), value, name)
        self.assertLessEqual(define('KANNA_WASH_UNITS') + 2, 5)

    def test_channel_recipe_node_and_sprites(self):
        rows = [l for l in RECIPES.splitlines() if l.startswith('RECIPE: ') and ',/obj/structure/kanna_channel,' in l]
        self.assertEqual(rows, ['RECIPE: /material/wood/,washing channel,/obj/structure/kanna_channel,6,120,1,1,economy & production,0,0,0,8,null'])
        self.assertIn('"/obj/structure/kanna_channel" = "tatara_smelting"', NODES)
        states = dmi_states()
        self.assertIn('kanna_channel', states)
        self.assertIn('kanna_channel_working', states)

    def test_channel_needs_water_and_a_shared_stock(self):
        self.assertIn('T.panning_water()', proc_body(SOURCE, '/obj/structure/kanna_channel/proc/water_beside('))
        stock = proc_body(SOURCE, '/obj/structure/kanna_channel/proc/stock(')
        self.assertIn('kanna_channel_stock[key]', stock)
        hand = proc_body(SOURCE, '/obj/structure/kanna_channel/attack_hand(')
        self.assertLess(hand.index('do_after'), hand.index('S.take(1)'))
        self.assertIn('map.iron_sand_rich', hand)

    def test_sand_washing(self):
        wash = proc_body(SOURCE, '/proc/wash_sand(')
        self.assertIn('round(S.amount / SAND_PER_WASH)', wash)
        self.assertIn('S.amount != initial_amount', wash)
        self.assertLess(wash.index('do_after'), wash.index('S.use(batches * SAND_PER_WASH)'))
        bowl = proc_body(SOURCE, '/obj/item/kitchen/wood_bowl/attackby(')
        self.assertIn('T.panning_water()', bowl)
        self.assertIn('map.ordinal_age < 1', bowl)
        routes = {r['name'] for r in ATLAS['mechanisms']}
        self.assertIn('Wash hillside soil in a washing channel', routes)
        self.assertIn('Wash ordinary sand into iron sand', routes)


class JapaneseBlades(unittest.TestCase):
    BLADES = ('/obj/item/weapon/material/sword/katana', '/obj/item/weapon/material/sword/wakazashi',
              '/obj/item/weapon/material/sword/tachi', '/obj/item/weapon/material/kitchen/utensil/knife/tanto',
              '/obj/item/weapon/material/naginata', '/obj/item/weapon/material/spear/naginata')

    def test_node_and_tachi(self):
        self.assertIn('register_research_node(new /datum/research_node("japanese_swordsmithing", "Japanese Swordsmithing", "Military", 165, 1, '
                      'RESEARCH_MODE_ANALYSIS, list("steel_blades","tatara_smelting"), 2))', NODES)
        self.assertIn('"/obj/item/weapon/material/sword/tachi" = "japanese_swordsmithing"', NODES)
        recipes = (ROOT / 'code/game/objects/structures/blacksmithing/blacksmithing_recipes.dm').read_text(encoding='utf-8')
        self.assertIn('"Tachi" = list("Tachi","swords",2,3,16,16,0,0,/obj/item/weapon/material/sword/tachi)', recipes)
        for sheet in ('icons/obj/weapons.dmi', 'icons/mob/items/lefthand_weapons.dmi', 'icons/mob/items/righthand_weapons.dmi',
                      'icons/mob/belt.dmi', 'icons/mob/back.dmi'):
            data = (ROOT / sheet).read_bytes()
            at = data.index(b'zTXtDescription\x00\x00') + len(b'zTXtDescription\x00\x00')
            self.assertIn('state = "tachi"', zlib.decompressobj().decompress(data[at:]).decode(), sheet)

    def test_japanese_blades(self):
        body = proc_body(SOURCE, '/proc/is_japanese_blade(')
        for path in self.BLADES:
            self.assertIn('istype(W, %s)' % path, body)

    def test_clay_hardening(self):
        self.assertEqual(float(re.search(r'#define CLAY_HARDENED_QUALITY ([\d.]+)', SOURCE).group(1)), 1.35)
        harden = proc_body(SOURCE, '/obj/structure/anvil/proc/clay_harden(')
        self.assertIn('W.get_material_name() != "steel"', harden)
        self.assertIn('crafting_node_allowed(H, "japanese_swordsmithing")', harden)
        self.assertLess(harden.index('Q.station_take_water(null)'), harden.index('C.use(1)'))
        self.assertIn('W.hamon = TRUE', harden)
        self.assertIn('W.update_force()', harden)
        forge = proc_body(SOURCE, '/obj/structure/anvil/forge_stack_recipe(')
        self.assertIn('material_name != "steel"', forge)
        self.assertLess(forge.index('before += W'), forge.index('. = ..()'))
        self.assertIn('clay_harden(W, H)', forge)


if __name__ == '__main__':
    unittest.main()
