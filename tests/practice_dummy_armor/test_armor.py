"""Exercise the armor branch projected from DM with fake engine effects."""
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'save_movement'))
import source_adapter


class PracticeDummyArmorTests(unittest.TestCase):
    def test_armor_is_installed_once(self):
        source = (ROOT / 'code/game/objects/structures/target_stake.dm').read_text()
        branch = source.split('/obj/structure/practice_dummy/attackby(', 1)[1]
        branch = branch.split('\n\t//Flavor text', 1)[0].split('\n', 1)[1]
        branch = branch.replace('/obj/item/weapon/dummy_armor', 'ARMOR')
        removed, messages = [], []
        env = {'ARMOR': object(), 'istype': lambda item, kind: item is kind,
               'visible_message': lambda *args: None, 'qdel': removed.append,
               'to_chat': lambda *args: messages.append(args)}
        run = source_adapter.project('proc/install()\n' + branch + '\n',
                                     'proc/install', 'src, W, user', env, method=True)
        dummy = SimpleNamespace(humanoid=True, icon_state='target_dummy', health=100)
        run(dummy, env['ARMOR'], object())
        self.assertEqual((dummy.icon_state, dummy.health, len(removed)),
                         ('target_dummy_armor', 300, 1))
        run(dummy, env['ARMOR'], object())
        self.assertEqual((dummy.icon_state, dummy.health, len(removed)),
                         ('target_dummy_armor', 300, 1))
        self.assertEqual(len(messages), 1)
        target = SimpleNamespace(humanoid=False, icon_state='target_dummy_target', health=100)
        run(target, env['ARMOR'], object())
        self.assertEqual((target.icon_state, target.health, len(removed)),
                         ('target_dummy_target', 100, 1))


if __name__ == '__main__':
    unittest.main()
