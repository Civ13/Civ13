"""Bone armor stays craftable in every era without growing stronger. Source text only.

Field 12 of a recipe row is the last age it can be crafted in; RECIPE_OPEN_ENDED_AGE
and above never retire. The bone set keeps its stone-age protection, so later-era
armor still outclasses it against arrows and guns.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
BONE_SET = ('/obj/item/clothing/head/helmet/bone', '/obj/item/clothing/suit/storage/jacket/bonearmor',
            '/obj/item/clothing/suit/hairbonearmor', '/obj/item/clothing/mask/skullmask',
            '/obj/item/clothing/suit/woodarmor')


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


def open_ended_age():
    match = re.search(r'^#define RECIPE_OPEN_ENDED_AGE (\d+)', read('code/__defines/maps.dm'), re.M)
    return int(match.group(1))


def armor(path):
    source = read('code/modules/1713/apparel_stoneage.dm')
    block = source[source.index('\n' + path + '\n'):].split('\n\n', 1)[0]
    values = re.search(r'armor = list\(([^)]*)\)', block).group(1)
    return {k: (0 if v in ('FALSE', 'null') else int(v))
            for k, v in re.findall(r'(\w+) = (\w+)', values)}


class BoneArmorEras(unittest.TestCase):
    def test_bone_set_never_retires(self):
        limit = open_ended_age()
        seen = set()
        for catalog in sorted((ROOT / 'config/crafting').glob('material_recipes_*.txt')):
            for line in catalog.read_text(encoding='utf-8-sig').splitlines():
                if not line.startswith('RECIPE: ') or '//' in line:
                    continue
                fields = line[len('RECIPE: '):].split(',')
                if len(fields) == 13 and fields[2] in BONE_SET:
                    seen.add(fields[2])
                    self.assertGreaterEqual(int(fields[11]), limit, '%s: %s' % (catalog.name, fields[1]))
        self.assertEqual(seen, set(BONE_SET))

    def test_bone_set_keeps_primitive_protection(self):
        # Bone does not stop bullets; plate and kevlar keep the edge in later eras.
        self.assertEqual(armor('/obj/item/clothing/suit/storage/jacket/bonearmor'),
                         {'melee': 50, 'arrow': 15, 'gun': 0, 'energy': 0, 'bomb': 10, 'bio': 0, 'rad': 0})
        self.assertEqual(armor('/obj/item/clothing/suit/hairbonearmor')['gun'], 0)
        self.assertEqual(armor('/obj/item/clothing/mask/skullmask')['gun'], 0)
        self.assertLessEqual(armor('/obj/item/clothing/head/helmet/bone')['gun'], 10)
        self.assertEqual(armor('/obj/item/clothing/suit/woodarmor')['gun'], 0)

    def test_primitive_armor_maps_to_primitive_armor_node(self):
        # Unmapped recipes fail closed, so every row needs a research node.
        research = read('code/modules/research_tree/research_node.dm')
        for path in BONE_SET:
            if path != '/obj/item/clothing/mask/skullmask':
                self.assertIn('"%s" = "padded_armor"' % path, research)


if __name__ == '__main__':
    unittest.main()
