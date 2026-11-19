"""Tool work speed by head material (docs/material-roles.md, "Tool speeds").

code/modules/materials/tool_speeds.dm lists, per tool family, the speed each
hand-made material always had, and places any other material between its
neighbours by ROLE_WORK_HEAD performance.

- Every listed speed equals the hand-set speed of the named variant in that
  material, so tools that exist today keep their numbers.
- The plain family tool's own speed is the one the overrides test for.
- FROZEN pins the in-between values (cast copper and bronze heads).
- Unlisted materials never leave the listed range.
- set_material() calls the hook and assembled tools read the same table.
"""
from pathlib import Path
import importlib.util
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEEDS = ROOT / 'code/modules/materials/tool_speeds.dm'
WEAPONS = ROOT / 'code/game/objects/items/weapons/material/material_weapons.dm'
SOURCES = [ROOT / 'code/modules/1713/tools.dm', ROOT / 'code/game/objects/items/weapons/material/misc.dm']
PLAIN_TOOLS = [ROOT / 'code/modules/1713/tools.dm', ROOT / 'code/game/objects/items/weapons/tools.dm']

spec = importlib.util.spec_from_file_location('material_roles', ROOT / 'tests/material_roles/test_material_roles.py')
roles = importlib.util.module_from_spec(spec)
spec.loader.exec_module(roles)

# family -> (speed var, {material: named variant holding that hand-set speed})
VARIANTS = {
    '/obj/item/weapon/material/pickaxe': ('usespeed', {
        'bone': '/obj/item/weapon/material/pickaxe/bone', 'stone': '/obj/item/weapon/material/pickaxe/stone',
        'iron': '/obj/item/weapon/material/pickaxe', 'steel': '/obj/item/weapon/material/pickaxe/steel'}),
    '/obj/item/weapon/material/shovel': ('usespeed', {
        'bone': '/obj/item/weapon/material/shovel/bone', 'iron': '/obj/item/weapon/material/shovel',
        'steel': '/obj/item/weapon/material/shovel/steel'}),
    '/obj/item/weapon/material/hatchet': ('chopping_speed', {
        'bone': '/obj/item/weapon/material/hatchet/tribal/bone', 'flint': '/obj/item/weapon/material/hatchet/tribal/flint',
        'stone': '/obj/item/weapon/material/hatchet/tribal', 'bronze': '/obj/item/weapon/material/hatchet/bronze',
        'iron': '/obj/item/weapon/material/hatchet', 'steel': '/obj/item/weapon/material/hatchet/steel'}),
}

# (family, material) -> speed to two places.
FROZEN = {
    ('pickaxe', 'copper'): 1.66,
    ('pickaxe', 'bronze'): 1.87,
    ('pickaxe', 'brass'): 1.8,
    ('pickaxe', 'flint'): 1.0,
    ('pickaxe', 'gold'): 1.0,
    ('shovel', 'copper'): 0.92,
    ('shovel', 'bronze'): 1.28,
    ('shovel', 'stone'): 0.64,
    ('hatchet', 'copper'): 2.7,
    ('hatchet', 'brass'): 2.18,
    ('hatchet', 'gold'): 3.5,
}

# Plain tools that must name their material.
TOOL_MATERIALS = {
    '/obj/item/weapon/plough': 'wood', '/obj/item/weapon/plough/iron': 'iron',
    '/obj/item/weapon/chisel': 'stone', '/obj/item/weapon/chisel/metal': 'iron',
    '/obj/item/weapon/hammer': 'iron', '/obj/item/weapon/hammer/tribalhammer': 'wood',
    '/obj/item/weapon/hammer/modern': 'steel', '/obj/item/weapon/wrench': 'iron',
    '/obj/item/weapon/screwdriver': 'iron', '/obj/item/weapon/wirecutters': 'steel',
    '/obj/item/weapon/crowbar': 'iron', '/obj/item/weapon/saw': 'iron', '/obj/item/weapon/shears': 'iron',
}


def families():
    text = roles.strip_comments(SPEEDS.read_text(encoding='utf-8'))
    table = text[text.index('tool_speed_families'):text.index('/proc/tool_material_speed')]
    found = {}
    for path, body in re.findall(r'(/obj/item/weapon/material/\w+) = list\(([^)]*)\)', table):
        found[path] = {name: float(value) for name, value in re.findall(r'"([^"]+)" = ([\d.]+)', body)}
    return found


def item_blocks():
    blocks = {}
    for source in SOURCES + PLAIN_TOOLS:
        for path, body in roles.type_blocks(source.read_text(encoding='utf-8', errors='ignore'), '/obj/item/weapon').items():
            blocks.setdefault(path, {}).update(body)
    return blocks


class ToolMaterialSpeeds(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.families = families()
        cls.blocks = item_blocks()
        cls.materials = roles.load_materials()
        cls.roles, cls.consts = roles.load_roles()

    def performance(self, name):
        rating = roles.rate(self.roles['work_head'], self.materials[name], self.materials, self.consts)
        return rating[0] if rating else 0

    def speed(self, family, name):
        """Mirror of /proc/tool_material_speed()."""
        anchors = self.families[family]
        if name in anchors:
            return anchors[name]
        performance = self.performance(name)
        if not performance:
            return 0
        low = high = None
        for anchor, value in anchors.items():
            at = self.performance(anchor)
            if at <= performance and (low is None or at > low[0]):
                low = (at, value)
            if at >= performance and (high is None or at < high[0]):
                high = (at, value)
        if low is None:
            return high[1]
        if high is None or high[0] == low[0]:
            return low[1]
        return low[1] + (high[1] - low[1]) * (performance - low[0]) / (high[0] - low[0])

    def test_families_cover_the_three_tools(self):
        self.assertEqual(set(self.families), set(VARIANTS))
        for family, (_, variants) in VARIANTS.items():
            self.assertEqual(set(self.families[family]), set(variants), family)

    def test_listed_speeds_are_the_hand_set_ones(self):
        for family, (var, variants) in VARIANTS.items():
            for material, path in variants.items():
                raw = roles.inherited(self.blocks, path, var)
                self.assertIsNotNone(raw, path)
                self.assertEqual(float(raw), self.families[family][material], f'{path} {var}')

    def test_named_variants_are_made_of_their_listed_material(self):
        # The bone tribal hatchet is deliberately a stone-material item.
        skip = {'/obj/item/weapon/material/hatchet/tribal/bone', '/obj/item/weapon/material/hatchet/tribal/flint'}
        for family, (_, variants) in VARIANTS.items():
            for material, path in variants.items():
                if path in skip:
                    continue
                self.assertEqual(roles.inherited(self.blocks, path, 'default_material'), f'"{material}"', path)

    def test_overrides_only_touch_the_plain_family_tool(self):
        text = SPEEDS.read_text(encoding='utf-8')
        for family, (var, variants) in VARIANTS.items():
            plain = float(roles.inherited(self.blocks, family, var))
            self.assertEqual(plain, self.families[family]['iron'])
            override = re.search(re.escape(family) + r'/apply_tool_material_speed\(\)\n\tif \(!material \|\| initial\((\w+)\) != ([\d.]+)\)', text)
            self.assertIsNotNone(override, family)
            self.assertEqual((override[1], float(override[2])), (var, plain))

    def test_frozen_in_between_speeds(self):
        for (tool, material), expected in FROZEN.items():
            self.assertEqual(round(self.speed('/obj/item/weapon/material/' + tool, material), 2), expected, f'{tool} {material}')

    def test_every_material_stays_in_the_listed_range(self):
        for family, anchors in self.families.items():
            for name in self.materials:
                speed = self.speed(family, name)
                if speed:
                    self.assertGreaterEqual(speed, min(anchors.values()), f'{family} {name}')
                    self.assertLessEqual(speed, max(anchors.values()), f'{family} {name}')

    def test_better_heads_are_never_slower_between_metals(self):
        pick = '/obj/item/weapon/material/pickaxe'
        order = ['bone', 'stone', 'copper', 'brass', 'bronze', 'iron', 'steel']
        speeds = [self.speed(pick, name) for name in order]
        self.assertEqual(speeds, sorted(speeds))

    def test_material_items_and_assembled_tools_use_the_table(self):
        weapons = WEAPONS.read_text(encoding='utf-8', errors='ignore')
        setter = weapons[weapons.index('/obj/item/weapon/material/proc/set_material'):]
        self.assertIn('apply_tool_material_speed()', setter[:setter.index('\n/obj/')])
        self.assertIn('tool_material_speed(/obj/item/weapon/material/pickaxe, head_name)', weapons)
        self.assertIn('tool_material_speed(/obj/item/weapon/material/shovel, head_name)', weapons)
        self.assertNotIn('head_part.material.hardness / iron.hardness', weapons)

    def test_plain_tools_name_their_material(self):
        for path, material in TOOL_MATERIALS.items():
            self.assertEqual(roles.inherited(self.blocks, path, 'tool_material'), f'"{material}"', path)
            self.assertIn(material, self.materials)


if __name__ == '__main__':
    unittest.main()
