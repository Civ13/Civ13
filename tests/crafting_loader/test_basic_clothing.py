"""Factionless players can always clothe themselves for the cold. Source text only.

Factionless players cannot use research benches, so only Main-tree nodes (granted
by the era baseline in is_node_done) and legacy research thresholds reach them.
This models generate_recipes_civs() for a factionless player in every era and checks
that a warm coat, headwear, footwear and gloves stay craftable.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
# Legacy research given to factionless players per era (civ_recipes.dm).
FACTIONLESS_RESEARCH = (0, 35, 60, 85, 105, 125, 152, 185, 210)
WARM_COATS = ('/obj/item/clothing/suit/prehistoricfurcoat', '/obj/item/clothing/suit/storage/coat/fur')
SLOTS = {'headwear': '/obj/item/clothing/head/', 'footwear': '/obj/item/clothing/shoes/',
         'gloves': '/obj/item/clothing/gloves/'}
NODE = re.compile(r'new /datum/research_node\("(\w+)", "[^"]+", "[^"]+", \d+, \d+, \w+, '
                  r'(?:null|list\([^)]*\)), (\d+)(?:, [^,)]+)?(?:, "(\w+)")?\)')


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def research():
    source = read('code/modules/research_tree/research_node.dm')
    nodes = {m.group(1): (int(m.group(2)), m.group(3) or 'Main') for m in NODE.finditer(source)}
    requirements = dict(re.findall(r'^\t\t"(/obj/[^"]+)" = "(\w+)",?$', source, re.M))
    return nodes, requirements


def factionless_recipes(era, nodes, requirements):
    """Result paths a factionless player can craft from the global list in this era."""
    craftable = set()
    for line in read('config/crafting/material_recipes_global.txt').splitlines():
        if not line.startswith('RECIPE: ') or '//' in line:
            continue
        fields = line[len('RECIPE: '):].split(',')
        if len(fields) != 13 or era > int(fields[11]):
            continue
        node = requirements.get(fields[2])
        if node:
            node_era, tree = nodes[node]
            allowed = tree == 'Main' and node_era <= era
        else:
            allowed = all(FACTIONLESS_RESEARCH[era] >= float(value) for value in fields[8:11])
        if allowed:
            craftable.add(fields[2])
    return craftable


class FactionlessClothing(unittest.TestCase):
    def test_furriery_is_era_granted_survival_clothing(self):
        nodes, requirements = research()
        self.assertEqual(nodes['furriery'], (1, 'Main'))
        self.assertEqual(requirements['/obj/item/clothing/suit/storage/coat/fur'], 'furriery')

    def test_every_era_has_a_warm_coat_and_basic_clothes(self):
        nodes, requirements = research()
        for era in range(len(FACTIONLESS_RESEARCH)):
            craftable = factionless_recipes(era, nodes, requirements)
            with self.subTest(era=era, slot='warm coat'):
                self.assertTrue(any(path.startswith(WARM_COATS) for path in craftable))
            for slot, prefix in SLOTS.items():
                with self.subTest(era=era, slot=slot):
                    self.assertTrue(any(path.startswith(prefix) for path in craftable))

    def test_model_sees_specialist_tree_locks(self):
        nodes, requirements = research()
        craftable = factionless_recipes(7, nodes, requirements)
        self.assertEqual(nodes['tailoring'][1], 'Tailoring')
        self.assertNotIn('/obj/item/clothing/head/turban', craftable)


if __name__ == '__main__':
    unittest.main()
