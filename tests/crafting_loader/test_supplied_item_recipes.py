"""#3563: supplied-only items get real production routes. Source text only."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
CRAFTED = (
    '/obj/item/weapon/screwdriver', '/obj/item/weapon/lockpick', '/obj/item/weapon/legcuffs',
    '/obj/item/weapon/whistle/tin', '/obj/item/taperoll/police', '/obj/item/bag_valve_mask',
    '/obj/item/weapon/pill_pack', '/obj/item/clothing/accessory/stethoscope', '/obj/item/glass_jar',
    '/obj/item/weapon/attachment/scope/adjustable/binoculars/small', '/obj/item/shamisen',
    '/obj/item/weapon/pen/pencil', '/obj/item/weapon/pen/fancy', '/obj/item/weapon/haircomb',
    '/obj/item/weapon/lipstick/black', '/obj/item/weapon/lipstick/purple', '/obj/item/video_camera',
    '/obj/item/weapon/barstool', *('/obj/item/weapon/barstool/' + colour for colour in
                                   ('green', 'blue', 'yellow', 'black', 'white', 'brown', 'grey')),
)


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def recipe_rows(text):
    rows = {}
    for line in text.splitlines():
        if line.startswith('RECIPE: ') and '//' not in line:
            fields = line[len('RECIPE: '):].split(',')
            rows.setdefault(fields[2], []).append(fields)
    return rows


class SuppliedItemRecipes(unittest.TestCase):
    def test_every_reviewed_item_has_a_well_formed_global_recipe(self):
        rows = recipe_rows(read('config/crafting/material_recipes_global.txt'))
        for path in CRAFTED:
            with self.subTest(path=path):
                self.assertIn(path, rows)
                for fields in rows[path]:
                    self.assertEqual(len(fields), 13)
                    self.assertTrue(fields[0].startswith('/material/'))
                    self.assertTrue(all(fields[i].isdigit() for i in (3, 4, 5, 6, 8, 9, 10, 11)))

    def test_every_reviewed_item_is_gated_by_a_real_research_node(self):
        source = read('code/modules/research_tree/research_node.dm')
        nodes = set(re.findall(r'new /datum/research_node\("([a-z_]+)"', source))
        for path in CRAFTED:
            with self.subTest(path=path):
                match = re.search(r'^\t\t"' + re.escape(path) + r'" = "([a-z_]+)",$', source, re.M)
                self.assertIsNotNone(match)
                self.assertIn(match.group(1), nodes)

    def test_soap_comes_from_oil_and_lye(self):
        source = read('code/modules/reagents/Chemistry-Recipes.dm')
        for reaction, oil, result in (('plain_soap', 'cornoil', '/obj/item/weapon/soap(location)'),
                                      ('deluxe_soap', 'olive_oil', '/obj/item/weapon/soap/deluxe(location)')):
            with self.subTest(reaction=reaction):
                body = source[source.index('/datum/chemical_reaction/' + reaction + '\n'):]
                body = body[:body.index('\treturn\n')]
                self.assertIn('required_reagents = list("' + oil + '" = 20, "lye" = 2)', body)
                self.assertIn('new ' + result, body)

    def test_pill_packs_refill_with_one_kind_of_pill(self):
        source = read('code/modules/1713/medical.dm')
        start = source.index('/obj/item/weapon/pill_pack/attackby(')
        body = source[start:source.index('\n/', start + 1)]
        for required in ('contents.len >= 6', 'pill_type && !istype(W, pill_type)',
                         'W.type != first.type', 'user.drop_from_inventory(W, src)'):
            with self.subTest(check=required):
                self.assertIn(required, body)


if __name__ == '__main__':
    unittest.main()
