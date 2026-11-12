"""Stone Age weapons and tools: source contract checks.

Every new item has a sprite state, a research node and (where crafted from a
stack) a recipe row limited to the Stone and Bronze Ages; knapping offers the
flint tools; the hooks keep falling through to the parent behaviour.

    python3 tests/stone_age_arms/test_source.py
"""
import re
import sys
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/stone_age_arms.dm'
DMI = ROOT / 'icons/obj/stone_age_arms.dmi'

RECIPES = {
    '/obj/item/weapon/gun/projectile/bow/sling/atlatl': ('archery', ['wood']),
    '/obj/item/ammo_casing/atlatl_dart': ('archery', ['wood']),
    '/obj/item/weapon/gun/projectile/bow/sling/staff': ('archery', ['leather']),
    '/obj/item/weapon/legcuffs/bola': ('stone_arms', ['leather', 'rope']),
    '/obj/item/weapon/material/javelin': ('stone_arms', ['wood']),
    '/obj/item/weapon/melee/classic_baton/club/stone': ('stone_arms', ['stone']),
    '/obj/item/weapon/material/harpoon/bone': ('stone_arms', ['bone']),
    '/obj/item/weapon/plough/digging_stick': ('basic_tools', ['wood']),
    '/obj/item/weapon/bone_needle': ('basic_tools', ['bone']),
    '/obj/item/weapon/material/hatchet/tribal/adze': ('basic_tools', ['stone']),
}
KNAPPED = {
    '/obj/item/weapon/material/hatchet/tribal/hand_axe': 'basic_tools',
    '/obj/item/weapon/material/hide_scraper': 'basic_tools',
}
STATES = {'atlatl', 'atlatl_loaded', 'atlatl_dart', 'bola', 'javelin', 'stone_club',
          'digging_stick', 'hand_axe', 'hide_scraper', 'bone_needle', 'stone_adze'}


def dmi_states(path):
    data = path.read_bytes()
    i = data.find(b'zTXtDescription')
    if i > 0:
        length = int.from_bytes(data[i - 4:i], 'big')
        chunk = data[i + 4:i + 4 + length]
        text = zlib.decompress(chunk[len(b'Description') + 2:]).decode('latin1')
    else:
        i = data.find(b'tEXtDescription')
        length = int.from_bytes(data[i - 4:i], 'big')
        text = data[i + 4 + len(b'Description') + 1:i + 4 + length].decode('latin1')
    return set(re.findall(r'state = "([^"]*)"', text))


def strip_comments(text):
    return '\n'.join(line for line in text.splitlines() if not line.strip().startswith('//'))


def recipe_rows():
    rows = []
    for line in (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8').splitlines():
        if line.startswith('RECIPE: ') and '//' not in line:
            rows.append(line[len('RECIPE: '):].strip().split(','))
    return rows


class StoneAgeArms(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')
        self.nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')

    def test_included_after_its_bases(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        own = dme.index('#include "code\\modules\\1713\\stone_age_arms.dm"')
        for earlier in ('flint_mining.dm', 'animal_harvest.dm', 'primitive_woodworking.dm', 'farm_animals.dm', 'static.dm', 'material_sheets.dm'):
            index = next(i for i, line in enumerate(dme) if line.endswith('\\' + earlier + '"'))
            self.assertLess(index, own, earlier)

    def test_sprites_exist_for_every_state_used(self):
        states = dmi_states(DMI)
        self.assertEqual(STATES, states)
        self.assertIn('atlatl', states)
        self.assertIn('atlatl_loaded', states)
        used = set(re.findall(r'icon_state = "([^"]+)"', self.source))
        used |= set(re.findall(r'"(atlatl(?:_loaded)?)"', self.source))
        icon_items = re.findall(r'\n(/[^\n]+)\n((?:\t[^\n]*\n)+)', self.source)
        for path, body in icon_items:
            if 'icon = STONE_AGE_ICON' in body:
                state = re.search(r'icon_state = "([^"]+)"', body).group(1)
                self.assertIn(state, states, path)
        self.assertTrue(used)

    def test_recipes_are_stone_and_bronze_age_only(self):
        rows = recipe_rows()
        for path, (node, materials) in RECIPES.items():
            found = sorted(row[0].split('/')[2] for row in rows if row[2] == path)
            self.assertEqual(sorted(materials), found, path)
            for row in rows:
                if row[2] == path:
                    self.assertEqual(13, len(row), path)
                    self.assertEqual('1', row[11], path)
                    self.assertEqual(['0', '0', '0'], row[8:11], path)

    def test_every_item_has_a_research_node(self):
        for path, node in [(p, n) for p, (n, _) in RECIPES.items()] + list(KNAPPED.items()):
            self.assertIn(f'"{path}" = "{node}",', self.nodes, path)
        for dart in ('flint', 'stone'):
            self.assertIn(f'"/obj/item/ammo_casing/atlatl_dart/{dart}" = "archery",', self.nodes)

    def test_knapping_offers_gated_flint_tools(self):
        flint = strip_comments((ROOT / 'code/modules/1713/flint_mining.dm').read_text(encoding='utf-8'))
        self.assertIn('options += stone_age_knap_options(H)', flint)
        self.assertIn('result = stone_age_knap_result(choice, T, H)', flint)
        for path in KNAPPED:
            self.assertIn(f'crafting_recipe_allowed(H, "{path}")', self.source)
        self.assertIn('if (!path || !crafting_recipe_allowed(H, "[path]"))', self.source)

    def test_refused_knap_keeps_the_flint(self):
        flint = strip_comments((ROOT / 'code/modules/1713/flint_mining.dm').read_text(encoding='utf-8'))
        tail = flint[flint.index('result = stone_age_knap_result(choice, T, H)'):]
        guard = tail.index('if (!result)')
        self.assertLess(guard, tail.index('qdel(src)'))
        self.assertIn('return', tail[guard:tail.index('qdel(src)')])

    def test_digging_stick_is_half_plough_speed(self):
        tools = (ROOT / 'code/modules/1713/tools.dm').read_text(encoding='utf-8')
        plough = tools[tools.index('/obj/item/weapon/plough\n'):]
        base = float(re.search(r'var/usespeed = ([0-9.]+)', plough[:plough.index('\n/', 1)]).group(1))
        stick = float(re.search(r'#define DIGGING_STICK_SPEED ([0-9.]+)', self.source).group(1))
        self.assertAlmostEqual(base / 2, stick)

    def test_scraper_bonus_is_scoped_to_the_accepted_harvest(self):
        harvest = self.source[self.source.index('/mob/living/simple_animal/harvest_animal('):]
        harvest = harvest[:harvest.index('\n\n')]
        self.assertIn('if (!harvesting)', harvest)
        products = self.source[self.source.index('/mob/living/simple_animal/harvest_products('):]
        products = products[:products.index('\n\n')]
        self.assertLess(products.index('hide_stack_amounts(site)'), products.index('..()'))
        self.assertIn('holds_hide_scraper(scraper_user, null)', products)
        self.assertIn('S.amount <= before[S]', products)

    def test_atlatl_darts_only_take_flint_or_stone_points(self):
        self.assertIn('/obj/item/ammo_casing/atlatl_dart/flint\n', self.source)
        self.assertIn('/obj/item/ammo_casing/atlatl_dart/stone\n', self.source)
        helper = self.source[self.source.index('/proc/atlatl_dart_point('):]
        helper = helper[:helper.index('\n\n')]
        self.assertIn('arrowhead/flint', helper)
        self.assertIn('arrowhead/stone', helper)
        self.assertNotIn('copper', helper)

    def test_hooks_fall_through_to_parent(self):
        for header in ('/obj/structure/fish/attackby(', '/obj/item/stack/material/wood/attackby(',
                       '/mob/living/simple_animal/cattle/attackby(', '/obj/item/ammo_casing/atlatl_dart/attackby(',
                       '/obj/item/weapon/bone_needle/afterattack('):
            body = self.source[self.source.index(header):]
            body = body[:body.index('\n\n')]
            self.assertIn('..()', body, header)
        harvest = self.source[self.source.index('/mob/living/simple_animal/harvest_products('):]
        harvest = harvest[:harvest.index('\n\n')]
        self.assertIn('\n\t..()\n', harvest)

    def test_digging_stick_cannot_be_hitched(self):
        self.assertIn('/obj/item/weapon/plough/digging_stick\n', self.source)
        self.assertIn('if (istype(O, /obj/item/weapon/plough/digging_stick) && user.a_intent == I_HELP)', self.source)

    def test_no_forbidden_patterns(self):
        code = '\n'.join(line for line in self.source.splitlines() if not line.strip().startswith('//'))
        self.assertNotRegex(code, r'\bspawn\(')
        self.assertNotRegex(code, r'\binput\(')


if __name__ == '__main__':
    sys.exit(0 if unittest.main(exit=False).result.wasSuccessful() else 1)
