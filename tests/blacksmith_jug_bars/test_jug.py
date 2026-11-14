"""Clay blacksmith pots and jugs accept bronze and brass bars (issue #5143).

Offline structural checks on current source. No BYOND, network or saves.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MOLDS = ROOT / 'code/game/objects/structures/blacksmithing/molds.dm'
KILN = ROOT / 'code/game/objects/structures/blacksmithing/refining.dm'


def proc_body(text, header):
    lines = text.splitlines()
    start = lines.index(header)
    body = []
    for line in lines[start + 1:]:
        if line and not line.startswith('\t'):
            break
        body.append(line)
    return '\n'.join(body)


def material_chain(body):
    """The ore/bar branch of the vessel's attackby, up to its final else."""
    start = body.index('istype(I, /obj/item/stack/ore) || istype(I, /obj/item/stack/material)')
    return body[start:]


class JugBarTests(unittest.TestCase):
    def setUp(self):
        self.body = material_chain(proc_body(MOLDS.read_text(encoding='utf-8'),
                                             '/obj/item/weapon/clay/mold/attackby(obj/item/I as obj, mob/user as mob)'))

    def test_bronze_and_brass_bars_have_a_branch_before_the_refusal(self):
        refusal = self.body.index("You can't melt that in")
        for metal in ('bronze', 'brass'):
            with self.subTest(metal=metal):
                branch = self.body.index(f'istype(O, /obj/item/stack/material/{metal})')
                self.assertLess(branch, refusal)

    def test_alloy_bars_only_join_an_empty_vessel_or_the_same_alloy(self):
        branch = self.body[self.body.index('istype(O, /obj/item/stack/material/bronze)'):]
        branch = branch[:branch.index("You can't melt that in")]
        self.assertIn('contents_materials.len == 0 || (contents_materials.len == 1 && contents_materials[alloy])', branch)
        self.assertIn('contents_materials[alloy] += cap_to_add', branch)
        self.assertIn('O.amount -= cap_to_add', branch)
        self.assertIn('already holds a different metal', branch)

    def test_old_kiln_message_is_gone(self):
        self.assertNotIn('You cannot use this material on a kiln.', MOLDS.read_text(encoding='utf-8'))

    def test_kiln_melts_a_single_metal_under_its_own_name(self):
        process = proc_body(KILN.read_text(encoding='utf-8'), '/obj/structure/furnace/kiln/process()')
        self.assertIn('MCC.current_material = i', process)


if __name__ == '__main__':
    unittest.main()
