"""Project the real closet confirmation branch across an interrupted prompt."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/game/objects/structures/crates_lockers/closets.dm').read_text(encoding='utf-8')


def resume(choice='Yes', assigned=0, opened=False, held=True, adjacent=True, deleted=False, key_code=7):
    effects = []
    user = SimpleNamespace(deleted=False)
    user.Adjacent = lambda target: adjacent
    key = SimpleNamespace(code=key_code, loc=user if held else None, deleted=False)
    closet = SimpleNamespace(deleted=deleted)
    lines = adapter.extract(SOURCE, '/obj/structure/closet/attackby').splitlines()
    prompt = next(i for i, line in enumerate(lines) if 'var/choice = WWinput(' in line)
    mutation = next(i for i in range(prompt + 1, len(lines)) if 'locked = TRUE' in lines[i])
    segment = [line[3:] for line in lines[prompt + 1:mutation]] + ['\t\teffect()']
    env = {'QDELETED': lambda item: item is None or item.deleted,
           'effect': lambda: effects.append('assigned')}
    action = adapter.project('/test/proc/run()\n' + '\n'.join(segment) + '\n',
                             '/test/proc/run', 'src, user, K, choice, custom_code, opened', env)
    action(closet, user, key, choice, assigned, opened)
    return effects


class ClosetKeyAssignment(unittest.TestCase):
    def test_yes_assigns_a_live_unassigned_closed_closet(self):
        self.assertEqual(resume(), ['assigned'])

    def test_stale_or_cancelled_confirmation_does_not_assign(self):
        for changes in ({'choice': 'No'}, {'choice': None}, {'assigned': 19},
                        {'opened': True}, {'held': False}, {'adjacent': False},
                        {'deleted': True}, {'key_code': 0}):
            with self.subTest(changes=changes):
                self.assertEqual(resume(**changes), [])


if __name__ == '__main__':
    unittest.main()
