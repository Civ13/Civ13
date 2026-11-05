"""Source checks for razor grooming and the razor's crafting route; no native world."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
KITCHEN = ROOT / 'code/game/objects/items/weapons/material/kitchen.dm'
GLOBAL = ROOT / 'config/crafting/material_recipes_global.txt'
RESEARCH = ROOT / 'code/modules/research_tree/research_node.dm'
RAZOR = '/obj/item/weapon/material/kitchen/utensil/knife/razorblade'


def proc_body(source, header):
    start = source.index(header)
    lines = source[start:].splitlines()[1:]
    body = []
    for line in lines:
        if line and not line[0].isspace():
            break
        body.append(line)
    return '\n'.join(body)


class RazorGrooming(unittest.TestCase):
    def setUp(self):
        self.source = KITCHEN.read_text(encoding='utf-8-sig')

    def test_any_non_harm_intent_on_head_or_face_grooms(self):
        attack = proc_body(self.source, RAZOR + '/attack(')
        guard = attack.splitlines()[0]
        self.assertIn('user.a_intent != I_HARM', guard)
        self.assertNotIn('I_DISARM', guard)
        for zone in ('"head"', '"eyes"', '"mouth"'):
            self.assertIn(zone, guard)
        self.assertIn('groom(M, user)', attack)

    def test_cancel_is_never_applied_as_a_style(self):
        groom = proc_body(self.source, RAZOR + '/proc/groom(')
        self.assertIn('(new_hstyle in hairlist)', groom)
        self.assertIn('(new_fstyle in fhairlist)', groom)
        self.assertNotIn('usr', re.sub(r'"[^"]*"', '', groom))


class RazorCrafting(unittest.TestCase):
    def test_global_crafting_has_hygiene_gated_razors(self):
        rows = [line[len('RECIPE: '):].split(',') for line in GLOBAL.read_text(encoding='utf-8-sig').splitlines()
                if line.startswith('RECIPE: ') and '//' not in line]
        razors = [row for row in rows if len(row) > 2 and row[2] == RAZOR]
        self.assertTrue(razors, 'no global crafting recipe makes a razor blade')
        materials = set()
        for row in razors:
            self.assertEqual(len(row), 13)
            self.assertEqual(row[7], 'hygiene')
            self.assertEqual(row[12], row[0].split('/')[2])
            materials.add(row[12])
        self.assertIn('copper', materials)

    def test_razor_maps_to_a_root_hygiene_node(self):
        research = RESEARCH.read_text(encoding='utf-8-sig')
        self.assertIn('"%s" = "hygiene"' % RAZOR, research)
        self.assertRegex(research, r'new /datum/research_node\("hygiene", "Hygiene", "Health", \d+, 0, RESEARCH_MODE_ANALYSIS, null,')


if __name__ == '__main__':
    unittest.main()
