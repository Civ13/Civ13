"""Obsidian: source contract checks.

Every obsidian item has a sprite state, gated items have a research node, the
old jungle mining rule is gone and the mining roll is wired in, and the hooks
fall through to the parent behaviour.

    python3 tests/obsidian/test_source.py
"""
import re
import sys
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/obsidian.dm'
DMI = ROOT / 'icons/obj/obsidian.dmi'

STATES = {
    'obsidian_outcrop1': 1, 'obsidian_outcrop2': 1, 'obsidian_outcrop3': 1,
    'obsidian_nodule': 1, 'obsidian_flake': 1, 'obsidian_core': 1, 'obsidian_blades': 1,
    'obsidian_arrowheads': 1, 'obsidian_spearhead': 1, 'obsidian_spear': 1,
    'obsidian_knife': 1, 'obsidian_scraper': 1, 'arrow_obsidian': 1, 'arrow_obsidian_flight': 4,
    'macuahuitl_bare': 1, 'tepoztopilli': 1, 'tepoztopilli_bare': 1,
    'obsidian_hand_mirror': 1, 'obsidian_polished': 1,
}
RESEARCH = {
    '/obj/item/ammo_casing/arrow/obsidian': 'archery',
    '/obj/item/ammo_casing/atlatl_dart/obsidian': 'archery',
    '/obj/item/weapon/material/hide_scraper/obsidian': 'basic_tools',
    '/obj/item/weapon/obsidian_core': 'stone_arms',
    '/obj/item/weapon/macuahuitl/unedged': 'stone_arms',
    '/obj/item/weapon/macuahuitl/tepoztopilli/unedged': 'stone_arms',
    '/obj/item/mirror/obsidian': 'basic_furniture',
}
OVERRIDES = [
    '/turf/floor/lava/New()', '/turf/floor/lava/dryproc()', '/turf/floor/dirt/dry_lava/New()',
    '/turf/floor/dirt/dry_lava/after_load()', '/turf/floor/dirt/dry_lava/attack_hand(mob/user)',
    '/turf/floor/dirt/dry_lava/persistence_runtime_var(key)',
    '/obj/item/stack/ore/obsidian/attackby(obj/item/W, mob/user)',
    '/obj/item/ammo_casing/atlatl_dart/attackby(obj/item/W, mob/user)',
    '/obj/item/weapon/branch/attackby(obj/item/weapon/W as obj, mob/user as mob)',
    '/mob/living/simple_animal/harvest_wait(mob/user, delay)',
    '/obj/item/weapon/macuahuitl/New()', '/obj/item/weapon/macuahuitl/after_load()',
    '/obj/item/weapon/macuahuitl/attack(mob/living/M, mob/living/user, target_zone)',
    '/obj/item/weapon/macuahuitl/attackby(obj/item/W, mob/user)',
    '/obj/item/weapon/obsidian_nodule/attackby(obj/item/W, mob/user)',
    '/obj/item/mirror/obsidian/attackby(obj/item/H as obj, mob/user as mob)',
    '/obj/structure/mirror/obsidian/attackby(obj/item/I as obj, mob/user as mob)',
]


def dmi_description(path):
    data = path.read_bytes()
    i = data.find(b'zTXtDescription')
    if i > 0:
        length = int.from_bytes(data[i - 4:i], 'big')
        chunk = data[i + 4:i + 4 + length]
        return zlib.decompress(chunk[len(b'Description') + 2:]).decode('latin1')
    i = data.find(b'tEXtDescription')
    length = int.from_bytes(data[i - 4:i], 'big')
    return data[i + 4 + len(b'Description') + 1:i + 4 + length].decode('latin1')


def dmi_states(path):
    return {name: int(dirs) for name, dirs in re.findall(r'state = "([^"]*)"\s*\n\s*dirs = (\d+)', dmi_description(path))}


def proc_body(text, header):
    start = text.index(header + '\n')
    rest = text[start + len(header) + 1:]
    end = re.search(r'^\S', rest, re.M)
    return rest[:end.start()] if end else rest


class ObsidianSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')
        cls.research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        cls.mining = (ROOT / 'code/game/turfs/floor_attackby.dm').read_text(encoding='utf-8')

    def test_included_after_its_parents(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        index = {line: i for i, line in enumerate(dme)}
        mine = index['#include "code\\modules\\1713\\obsidian.dm"']
        for parent in ('flint_mining.dm', 'gemstones.dm', 'stone_age_arms.dm', 'natural_disasters.dm', 'ores.dm'):
            self.assertLess(index['#include "code\\modules\\1713\\%s"' % parent], mine, parent)
        for parent in ('code\\game\\turfs\\floor_attackby.dm', 'code\\modules\\1713\\trench.dm'):
            self.assertLess(index['#include "%s"' % parent], mine, parent)

    def test_sprite_states(self):
        self.assertEqual(dmi_states(DMI), STATES)
        used = set(re.findall(r'(?:icon_state|bare_icon_state) = "([a-z_0-9]+)"', self.text)) - {'macuahuitl'}
        used.add('obsidian_outcrop1')
        self.assertTrue(used <= set(STATES), used - set(STATES))

    def test_research_nodes(self):
        for path, node in RESEARCH.items():
            self.assertIn('"%s" = "%s",' % (path, node), self.research)

    def test_mining_rule(self):
        self.assertIn('mining_obsidian(H)', self.mining)
        self.assertNotIn('area_above.climate == "jungle") && map.ordinal_age >=1 && map.ordinal_age <= 3', self.mining)
        body = proc_body(self.text, '/turf/proc/mining_obsidian(mob/living/human/H)')
        self.assertNotIn('ordinal_age', body)
        self.assertIn('near_volcano(src)', body)

    def test_overrides_fall_through(self):
        for header in OVERRIDES:
            body = proc_body(self.text, header)
            self.assertIn('..(', body, header)

    def test_runtime_turf_state(self):
        decl = {'obsidian_overlay': 'var/tmp/image/obsidian_overlay', 'obsidian_stock': 'var/tmp/datum/resource_stock/obsidian_stock'}
        for key in ('obsidian_outcrop', 'obsidian_stock', 'obsidian_overlay'):
            self.assertIn(decl.get(key, 'var/tmp/%s' % key), self.text)
            self.assertIn('key == "%s"' % key, self.text)

    def test_glass_is_brittle(self):
        glass = proc_body(self.text, '/material/volcanic_glass')
        self.assertIn('hardness = 70', glass)
        self.assertIn('integrity = 60', glass)
        self.assertIn('display_name = "obsidian"', glass)

    def test_no_bolts(self):
        body = proc_body(self.text, '/obj/item/ammo_casing/proc/attach_obsidian_arrowhead(obj/item/W, mob/user, shaft_path)')
        casing = (ROOT / 'code/modules/projectiles/_ammo_casing.dm').read_text(encoding='utf-8')
        self.assertIn('if (istype(W, /obj/item/stack/arrowhead/obsidian))\n\t\treturn attach_obsidian_arrowhead(W, user, shaft_path)', casing)
        self.assertIn('"/obj/item/ammo_casing/arrow"', body)
        self.assertIn('"/obj/item/ammo_casing/atlatl_dart"', body)
        self.assertNotIn('bolt', body)


    def test_bladed_clubs(self):
        for name in ('global', 'carib', 'gorilla', 'battle_ships'):
            rows = (ROOT / ('config/crafting/material_recipes_%s.txt' % name)).read_text(encoding='utf-8')
            self.assertIn(',macuahuitl,/obj/item/weapon/macuahuitl/unedged,', rows)
            self.assertIn(',tepoztopilli,/obj/item/weapon/macuahuitl/tepoztopilli/unedged,', rows)
            self.assertNotIn(',/obj/item/weapon/macuahuitl,', rows)
        stack = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text(encoding='utf-8')
        self.assertNotIn('findtext(recipe.title, "macuahuitl")', stack)
        self.assertIn('/obj/item/weapon/macuahuitl/unedged\n\tblades = 0', self.text)
        self.assertIn('/obj/item/weapon/macuahuitl/tepoztopilli/unedged\n\tblades = 0', self.text)


    def test_mirror_and_polished_stone(self):
        rows = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        self.assertIn('RECIPE: /material/obsidian/,obsidian hand mirror,/obj/item/mirror/obsidian,2,', rows)
        self.assertIn('/obj/item/stack/gemstone/obsidian\n', self.text)
        fasten = proc_body(self.text, '/obj/item/mirror/obsidian/attackby(obj/item/H as obj, mob/user as mob)')
        self.assertIn('new /obj/structure/mirror/obsidian(', fasten)
        self.assertIn('can_fasten(user, H)', fasten)
        unfasten = proc_body(self.text, '/obj/structure/mirror/obsidian/attackby(obj/item/I as obj, mob/user as mob)')
        self.assertIn('new /obj/item/mirror/obsidian(', unfasten)


if __name__ == '__main__':
    sys.exit(0 if unittest.main(exit=False).result.wasSuccessful() else 1)
