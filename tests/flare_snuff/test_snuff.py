"""Project flare snuff control flow with injected waiting and engine effects."""
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'save_movement'))
import source_adapter

PATH = 'code/game/objects/items/devices/flashlight.dm'
FLARE = '/obj/item/flashlight/flare'


def run(source, variant, *, wait_ok=True, extinguish_during_wait=False):
    events = []
    flare = SimpleNamespace(on=True, fuel=1, in_throw_mode=True, turn_on_sound='sound')
    user = SimpleNamespace(in_throw_mode=True)
    user.visible_message = lambda *args: events.append('message')
    user.adjustBurnLoss = lambda amount: events.append(('burn', amount))
    user.throw_mode_on = lambda: events.append('throw')
    flare.burn_out = lambda: events.append('burn_out')
    flare.turn_on = lambda: events.append('activate')
    flare.activate_signal = lambda: events.append('signal')

    def do_after(actor, delay, target):
        events.append(('wait', actor is user, delay, target is flare))
        if extinguish_during_wait:
            flare.on = False
        return wait_ok

    env = {'do_after': do_after, 'SPAN_WARNING': lambda text: text,
           'SPAN_NOTICE': lambda text: text, 'ishuman': lambda actor: True,
           'istype': lambda actor: True, 'to_chat': lambda *args: events.append('chat'),
           'playsound': lambda *args: events.append('sound'),
           'rand': lambda *args: 0, 'sleep': lambda *args: events.append('sleep')}
    helper_body = source_adapter.extract(source, FLARE + '/proc/snuff_out')
    assert helper_body.count('2 SECONDS') == 1
    helper_source = FLARE + '/proc/snuff_out(mob/living/user)\n' + helper_body.replace('2 SECONDS', '20')
    old_fields = source_adapter.FIELDS
    try:
        source_adapter.FIELDS += ('on', 'fuel', 'turn_on_sound', 'burn_out', 'turn_on',
                                  'snuff_out', 'callers', 'call_in_time', 'activate_signal')
        helper = source_adapter.project(helper_source, FLARE + '/proc/snuff_out', 'src, user', dict(env), method=True)
        flare.snuff_out = lambda actor: helper(flare, actor)
        flare.call_in_time = 100
        suffix = '/signal' if variant == 'signal' else ''
        attack = source_adapter.project(source, FLARE + suffix + '/attack_self', 'src, user', dict(env), method=True)
        attack(flare, user)
    finally:
        source_adapter.FIELDS = old_fields
    return events


class FlareSnuff(unittest.TestCase):
    def test_interrupted_wait_does_not_activate_or_burn(self):
        for variant in ('regular', 'signal'):
            with self.subTest(variant=variant):
                self.assertEqual(run(source_adapter.read(PATH), variant, wait_ok=False),
                                 [('wait', True, 20, True)])

    def test_already_extinguished_after_wait_does_not_burn(self):
        for variant in ('regular', 'signal'):
            with self.subTest(variant=variant):
                self.assertEqual(run(source_adapter.read(PATH), variant, extinguish_during_wait=True),
                                 [('wait', True, 20, True)])

    def test_completed_wait_burns_once_and_invokes_burn_out(self):
        for variant in ('regular', 'signal'):
            with self.subTest(variant=variant):
                self.assertEqual(run(source_adapter.read(PATH), variant),
                                 [('wait', True, 20, True), 'message', ('burn', 7), 'burn_out'])

    def test_controls_detect_missing_recheck_and_caller_return(self):
        source = source_adapter.read(PATH)
        without_recheck = source.replace('\tif(!on)\n\t\treturn\n\tuser.visible_message',
                                         '\tuser.visible_message', 1)
        self.assertNotEqual(source, without_recheck)
        self.assertIn(('burn', 7), run(without_recheck, 'regular', extinguish_during_wait=True))
        for variant in ('regular', 'signal'):
            with self.subTest(variant=variant):
                prefix, suffix = source.split(FLARE + ('/signal' if variant == 'signal' else '') + '/attack_self', 1)
                changed = suffix.replace('\t\tsnuff_out(user)\n\t\treturn', '\t\tsnuff_out(user)', 1)
                self.assertNotEqual(suffix, changed)
                without_return = prefix + FLARE + ('/signal' if variant == 'signal' else '') + '/attack_self' + changed
                self.assertIn('activate', run(without_return, variant, wait_ok=False))
                if variant == 'signal':
                    self.assertIn('signal', run(without_return, variant, wait_ok=False))


if __name__ == '__main__':
    unittest.main()
