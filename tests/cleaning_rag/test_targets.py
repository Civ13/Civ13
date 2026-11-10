"""Project rag waits and completions with fake movement and reagent boundaries."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('rag_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/game/objects/items/weapons/detective.dm').read_text()


def exercise(kind, movement='stationary', floor=False):
    calls = []
    target = SimpleNamespace(nearby=True, deleted=False, clean_blood=lambda: calls.append('clean'))
    target.is_open_container = lambda: True
    turf = object()
    user = SimpleNamespace(loc=turf, visible_message=lambda *args: None)
    user.Adjacent = lambda obj: obj.nearby
    reagents = SimpleNamespace(total_volume=10, splash=lambda obj, amount: calls.append('splash'),
                               trans_to=lambda obj, amount: calls.append('transfer'))
    def wait(actor, delay, monitored=None, **kwargs):
        if movement != 'stationary':
            target.nearby = False
        # do_after cancels if the monitored atom changes loc. An obstruction
        # can also make the target unreachable without changing its loc.
        return not (movement == 'moved' and monitored is target)
    env = {'do_after': wait, 'get_turf': lambda actor: turf,
           'QDELETED': lambda obj: obj is None or obj.deleted,
           'update_name': lambda: None, 'to_chat': lambda *args: None,
           'effect': lambda: calls.append('attack')}
    if kind == 'attack':
        body = adapter.extract(SOURCE, '/obj/item/weapon/reagent_containers/glass/rag/attack')
        lines = body.splitlines()
        start = next(i for i, line in enumerate(lines) if 'if (do_after(user, 20,' in line)
        end = next(i for i in range(start + 1, len(lines)) if 'var/mob/living/M = target' in lines[i])
        segment = [line[1:] for line in lines[start:end]] + ['\t\teffect()']
        args = 'user, target'
    else:
        declaration = '/obj/item/weapon/reagent_containers/glass/rag/proc/' + ('wipe_down' if kind == 'wipe' else 'remove_contents')
        segment = adapter.extract(SOURCE, declaration).splitlines()
        # Message interpolation is outside this behavior test.
        segment = ['\t\tvar/target_text = "target"' if 'var/target_text =' in line else line for line in segment]
        args = 'A, user, reagents' if kind == 'wipe' else 'user, trans_dest, reagents'
    proc = adapter.project('/test/proc/run()\n' + '\n'.join(segment) + '\n', '/test/proc/run', args, env)
    if kind == 'attack': proc(user, target)
    elif kind == 'wipe': proc(target, user, reagents)
    else: proc(user, None if floor else target, reagents)
    return calls


class RagTargetTest(unittest.TestCase):
    def test_moved_target_does_not_receive_completion(self):
        for kind, effect in [('attack', 'attack'), ('wipe', 'clean'), ('wring', 'transfer')]:
            for movement in ('moved', 'reach_changed'):
                with self.subTest(kind=kind, movement=movement):
                    self.assertNotIn(effect, exercise(kind, movement))

    def test_stationary_targets_and_floor_still_work(self):
        for kind, effect in [('attack', 'attack'), ('wipe', 'clean'), ('wring', 'transfer')]:
            with self.subTest(kind=kind):
                self.assertIn(effect, exercise(kind))
        self.assertIn('splash', exercise('wring', floor=True))


if __name__ == '__main__':
    unittest.main()
