"""Anvil and furnace outputs go through spawn_stack, not new stack(loc) then amount =."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
FILES = ['code/game/objects/structures/blacksmithing/blacksmithing.dm',
         'code/game/objects/structures/blacksmithing/refining.dm']
# A stack made on a tile merges its default single item before the caller sets amount.
LOSSY = re.compile(r'(\w+) = new ?/obj/item/stack/[\w/]+\([^,()]*\)\n\s*\1\.amount = ')


class StackSpawnSource(unittest.TestCase):
    def test_no_lossy_stack_outputs(self):
        for path in FILES:
            with self.subTest(path=path):
                self.assertIsNone(LOSSY.search((ROOT / path).read_text(encoding='utf-8')))

    def test_outputs_use_helper(self):
        anvil = (ROOT / FILES[0]).read_text(encoding='utf-8')
        for metal in ('copper', 'bronze', 'tin', 'brass', 'zinc', 'gold', 'silver', 'lead', 'iron', 'steel'):
            self.assertIn(f'spawn_stack(/obj/item/stack/material/{metal}, loc, tamt)', anvil)
        for metal in ('copper', 'iron', 'steel', 'bronze'):
            self.assertIn(f'spawn_stack(/obj/item/stack/arrowhead/{metal}, loc, tamt*3)', anvil)
        refining = (ROOT / FILES[1]).read_text(encoding='utf-8')
        self.assertEqual(refining.count('spawn_stack(/obj/item/stack/ore/'), 4)

    def test_helper_is_compiled(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\game\\objects\\items\\stacks\\stack_spawn.dm"', dme)

    def test_control_pattern_is_detected(self):
        old = '\tvar/obj/item/stack/material/copper/NM = new/obj/item/stack/material/copper(loc)\n\tNM.amount = tamt\n'
        self.assertIsNotNone(LOSSY.search(old))


if __name__ == '__main__':
    unittest.main()
