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
        for metal in ('copper', 'iron', 'steel', 'bronze'):
            self.assertIn(f'spawn_stack(/obj/item/stack/arrowhead/{metal}, loc, tamt*3)', anvil)
        refining = (ROOT / FILES[1]).read_text(encoding='utf-8')
        self.assertEqual(refining.count('spawn_stack(/obj/item/stack/ore/'), 4)

    def test_ingot_mold_keeps_its_materials_and_shared_stack_output(self):
        anvil = (ROOT / FILES[0]).read_text(encoding='utf-8')
        ingots = anvil.split('if ("ingots")', 1)[1].split('if ("parts")', 1)[0]
        outputs = re.findall(r'if \("(\w+)"\)\s+stack_path = /obj/item/stack/material/(\w+)', ingots)
        self.assertCountEqual(outputs, [(metal, metal) for metal in
                                       ('copper', 'bronze', 'tin', 'brass', 'zinc',
                                        'gold', 'silver', 'lead', 'iron', 'steel')])
        self.assertEqual(ingots.count('spawn_stack('), 1)
        self.assertRegex(ingots, r'do_after\(user,10\*ML.capacity,src,can_move=FALSE\)\)\s+'
                                 r'if \(ML && ML.capacity\)\s+var/stack_path\s+switch\(ML.current_material\)')
        self.assertRegex(ingots, r'if \(stack_path\)\s+var/tamt = ML.capacity\s+ML.capacity = 0\s+'
                                 r'ML.current_material = null\s+spawn_stack\(stack_path, loc, tamt\)')
        self.assertRegex(ingots, r'if \(stack_path == /obj/item/stack/material/steel\)\s+'
                                 r'to_chat\(user, "You finish crafting the steel sheet\."\)\s+'
                                 r'else\s+to_chat\(user, "You finish crafting the ingot\."\)')
        self.assertIn('\n' + '\t' * 8 + 'ML.update_icon()', ingots)

    def test_helper_is_compiled(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\game\\objects\\items\\stacks\\stack_spawn.dm"', dme)

    def test_control_pattern_is_detected(self):
        old = '\tvar/obj/item/stack/material/copper/NM = new/obj/item/stack/material/copper(loc)\n\tNM.amount = tamt\n'
        self.assertIsNotNone(LOSSY.search(old))


if __name__ == '__main__':
    unittest.main()
