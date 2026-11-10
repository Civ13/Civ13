"""Exercise the mirror's post-prompt check with isolated state changes."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest


ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('mirror_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/game/objects/structures/mirror.dm').read_text(encoding='utf-8-sig')


def resume(*, adjacent=True, held=True, conscious=True, on_turf=True, deleted=False, direction='North'):
    calls = []
    hammer = SimpleNamespace(deleted=False)
    user = SimpleNamespace(stat=0 if conscious else 1, loc='turf' if on_turf else 'container', deleted=False)
    user.get_active_hand = lambda: hammer if held else None
    user.incapacitated = lambda: not conscious
    hammer.loc = user if held else None
    mirror = SimpleNamespace(deleted=deleted)
    env = {'QDELETED': lambda item: item is None or item.deleted,
           'isturf': lambda place: place == 'turf', 'Adjacent': lambda actor: adjacent,
           'effect': lambda: calls.append('fastened')}
    helper = '/obj/item/mirror/proc/can_fasten'
    if helper in SOURCE:
        check = adapter.project(SOURCE, helper, 'src, user, H', env)
        env['can_fasten'] = lambda actor, tool: check(mirror, actor, tool)
    else:
        env['can_fasten'] = lambda *args: True
    lines = adapter.extract(SOURCE, '/obj/item/mirror/attackby').splitlines()
    prompt = next(i for i, line in enumerate(lines) if 'WWinput(' in line)
    creation = next(i for i in range(prompt + 1, len(lines)) if 'var/obj/structure/mirror/S = new' in lines[i])
    segment = [line[1:] for line in lines[prompt + 1:creation]] + ['\t\teffect()']
    action = adapter.project('/test/proc/run()\n' + '\n'.join(segment) + '\n', '/test/proc/run',
                             'src, user, H, direction', env)
    action(mirror, user, hammer, direction)
    return calls


class MirrorFasteningPrompt(unittest.TestCase):
    def test_valid_answer_fastens(self):
        self.assertEqual(resume(), ['fastened'])
        self.assertEqual(resume(direction=None), [])

    def test_changed_state_cancels(self):
        for change in ({'adjacent': False}, {'held': False}, {'conscious': False},
                       {'on_turf': False}, {'deleted': True}):
            with self.subTest(change=change):
                self.assertEqual(resume(**change), [])


if __name__ == '__main__':
    unittest.main()
