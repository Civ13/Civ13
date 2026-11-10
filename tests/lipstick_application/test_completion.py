"""Exercise the production lipstick completion branch across both waits."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('lipstick_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
adapter.FIELDS += ("open",)


def apply_during_wait(change):
    source = (ROOT / 'code/game/objects/items/weapons/cosmetics.dm').read_text()
    body = adapter.extract(source, '/obj/item/weapon/lipstick/attack')
    tail = body[body.index('\t\t\tif (do_after(user, 20, H)'):]
    lines = [line[2:] for line in tail.splitlines()]
    # Messages are an inert engine boundary, not part of the behavior under test.
    start = next(i for i, line in enumerate(lines) if 'user.visible_message(' in line)
    end = start
    while not lines[end].rstrip().endswith(')'):
        end += 1
    lines[start:end + 1] = ['\t\tpass']
    lipstick = SimpleNamespace(open=True, deleted=False)
    target = SimpleNamespace(lip_style=None, update_body=lambda: None, deleted=False)
    actor = SimpleNamespace(deleted=False, nearby=True, unable=False, held=lipstick)
    actor.Adjacent = lambda other: actor.nearby
    actor.incapacitated = lambda: actor.unable
    actor.get_active_hand = lambda: actor.held
    calls = []
    messages = []
    def wait(who, delay, target_arg):
        calls.append(who)
        change(len(calls), actor, target, lipstick)
        return True
    env = {'do_after': wait, 'QDELETED': lambda obj: obj is None or obj.deleted,
           'to_chat': lambda who, text: messages.append(text)}
    projected = adapter.project('/test/proc/apply()\n' + '\n'.join(lines) + '\n',
                                '/test/proc/apply', 'user, H, src, colour', env, method=True)
    projected(actor, target, lipstick, 'red')
    return target.lip_style, messages


class LipstickApplicationTest(unittest.TestCase):
    def test_existing_lipstick_is_not_overwritten_after_wait(self):
        def change(n, actor, target, lipstick):
            if n == 1:
                target.lip_style = 'blue'
        self.assertEqual(apply_during_wait(change)[0], 'blue')

    def test_invalidated_applicator_does_not_apply(self):
        for invalid in ('nearby', 'unable', 'held', 'open'):
            with self.subTest(invalid=invalid):
                def change(n, actor, target, lipstick):
                    if n == 2:
                        if invalid == 'nearby': actor.nearby = False
                        if invalid == 'unable': actor.unable = True
                        if invalid == 'held': actor.held = None
                        if invalid == 'open': lipstick.open = False
                self.assertIsNone(apply_during_wait(change)[0])

    def test_valid_application_still_succeeds(self):
        self.assertEqual(apply_during_wait(lambda *args: None)[0], 'red')


if __name__ == '__main__':
    unittest.main()
