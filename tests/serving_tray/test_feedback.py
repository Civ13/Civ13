"""Exercise tray-hit feedback with injected sound, random, and viewer boundaries."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('tray_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/game/objects/items/weapons/trays.dm').read_text(encoding='utf-8-sig')


class Viewer:
    def __init__(self, events, name):
        self.events, self.name = events, name

    def show_message(self, message, audible):
        self.events.append(('message', self.name, message, audible))


class TrayFeedbackTest(unittest.TestCase):
    def test_sound_and_viewers_for_both_rolls_and_hit_locations(self):
        for roll in (True, False):
            for face in (True, False):
                with self.subTest(roll=roll, face=face):
                    events = []
                    viewers = [Viewer(events, 'one'), Viewer(events, 'two')]
                    env = {
                        'prob': lambda chance: events.append(('roll', chance)) or roll,
                        'playsound': lambda *args: events.append(('sound',) + args),
                        'viewers': lambda target, radius: events.append(('viewers', target, radius)) or viewers,
                        'typed_iter': lambda values, kind: values,
                        'text': lambda template, user, target: template.replace('__BANG__', '!').replace('[]', user, 1).replace('[]', target, 1),
                    }
                    # The adapter rewrites ! even inside strings; protect punctuation at this boundary.
                    source = SOURCE.replace('tray!</span>', 'tray__BANG__</span>')
                    feedback = adapter.project(source, '/obj/item/weapon/tray/proc/play_hit_feedback',
                                               'target, user, face_hit', env)
                    feedback('victim', 'attacker', face)
                    sound = 'sound/items/trayhit1.ogg' if roll else 'sound/items/trayhit2.ogg'
                    detail = ' in the face' if face else ''
                    message = f"<span class='danger'>attacker slams victim{detail} with the tray!</span>"
                    self.assertEqual(events, [('roll', 50), ('sound', 'victim', sound, 50, True),
                                              ('viewers', 'victim', None),
                                              ('message', 'one', message, True),
                                              ('message', 'two', message, True)])

    def test_attack_keeps_feedback_in_each_damage_branch(self):
        attack = adapter.extract(SOURCE, '/obj/item/weapon/tray/attack')
        body, face = attack.split('\n\tvar/protected = FALSE', 1)
        protected, unprotected = face.split('\n\telse //No eye or head protection', 1)
        self.assertLess(body.index('M.take_organ_damage(5)'), body.index('play_hit_feedback(M, user)'))
        self.assertLess(protected.index('play_hit_feedback(M, user)'), protected.index('if (prob(10))'))
        self.assertLess(unprotected.index('play_hit_feedback(M, user, TRUE)'), unprotected.index('if (prob(30))'))


if __name__ == '__main__':
    unittest.main()
