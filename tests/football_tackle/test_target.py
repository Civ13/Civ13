"""Project the production tackle target search with isolated spatial fixtures."""
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('tackle_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


def select_target(people):
    source = adapter.read('code/modules/1713/football.dm')
    body = adapter.extract(source, '/mob/living/human/proc/football_tackle')
    search = re.search(r'^\t\t(for \(var/mob/living/human/HM in [^\n]+\))\n'
                       r'\t\t\t(if \(HM\.civilization != src\.civilization\))', body, re.M)
    if not search:
        raise AssertionError('Could not project the tackle target search')
    projection = ('/proc/target()\n\t' + search[1] + '\n\t\t' + search[2] +
                  '\n\t\t\treturn HM\n\treturn null\n')
    src = SimpleNamespace(civilization='blue', dir='north')
    env = {'typed_iter': lambda values, kind: values,
           'range': lambda distance, actor: people,
           'get_step': lambda actor, direction: [p for p in people if p.position == direction]}
    return adapter.project(projection, '/proc/target', 'src', env)(src)


class TackleTargetTest(unittest.TestCase):
    def test_only_enemy_in_front_is_selected(self):
        behind = SimpleNamespace(civilization='red', position='south')
        side = SimpleNamespace(civilization='red', position='west')
        front = SimpleNamespace(civilization='red', position='north')
        self.assertIsNone(select_target([behind, side]))
        self.assertIs(select_target([behind, side, front]), front)

    def test_teammates_in_front_are_not_selected(self):
        teammate = SimpleNamespace(civilization='blue', position='north')
        behind = SimpleNamespace(civilization='red', position='south')
        self.assertIsNone(select_target([teammate, behind]))


if __name__ == '__main__':
    unittest.main()
