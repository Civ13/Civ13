"""Project barbed-wire crossing with fake engine effects, not native gameplay."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
import source_adapter

SOURCE = ROOT / 'code/modules/1713/barbwire.dm'
DECLARATION = '/obj/structure/barbwire/Crossed'
MESSAGE = '"Your [affecting.name] gets [cut_description] by \\the [src]!"'


class Wire:
    loc = 'tile'

    def __str__(self):
        return 'barbwire'


class Organ:
    name = 'left foot'

    def __init__(self, events, damaged=True):
        self.events, self.damaged = events, damaged

    def take_damage(self, *args):
        self.events.append(('damage', args))
        return self.damaged


class Human:
    def __init__(self, events, organ):
        self.events, self.organ = events, organ

    def get_organ(self, name):
        self.events.append(('organ', name))
        return self.organ

    def UpdateDamageIcon(self):
        self.events.append(('icon',))

    def updatehealth(self):
        self.events.append(('health',))


def run_crossing(source, rolls, *, has_organ=True, damaged=True, human=True, mob=True, wire=True, location='tile'):
    body = source_adapter.extract(source, DECLARATION)
    assert body.count(MESSAGE) == 1
    assert body.count('return ..()') == 1
    source = source.replace(MESSAGE, 'render_message(affecting, cut_description, src)', 1)
    source = source.replace('return ..()', 'return parent_call()', 1)
    events = []
    choices = iter(rolls)

    def prob(percent):
        result = next(choices)
        events.append(('prob', percent, result))
        return result

    def pick(*options):
        events.append(('pick', options))
        return options[0]

    def sound(*args):
        events.append(('sound', args))

    actor = Human(events, Organ(events, damaged) if has_organ else None) if human else object()
    env = {'prob': prob, 'pick': pick, 'playsound': sound,
           'ismob': lambda value: mob, 'ishuman': lambda value: human,
           'SPAN_DANGER': lambda value: value,
           'render_message': lambda organ, desc, src: f'Your {organ.name} gets {desc} by the {src}!',
           'to_chat': lambda target, message: events.append(('chat', target, message)),
           'parent_call': lambda: events.append(('parent',)) or 'parent result'}
    action = source_adapter.project(source, DECLARATION, 'src, AM', env, method=True)
    target = Wire() if wire else None
    if target:
        target.loc = location
    result = action(target, actor)
    return events, result, actor


class BarbedWireCrossingTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_three_outcomes_keep_roll_and_effect_order(self):
        for rolls, damage, description in (((True,), 5, 'slightly cut'),
                                           ((False, True), 10, 'cut'),
                                           ((False, False), 15, 'deeply cut')):
            with self.subTest(rolls=rolls):
                events, result, actor = run_crossing(self.source, rolls)
                self.assertEqual(events[:len(rolls)], [('prob', 33, value) for value in rolls])
                tail = events[len(rolls):]
                self.assertEqual([event[0] for event in tail],
                                 ['pick', 'sound', 'pick', 'organ', 'damage', 'icon', 'health', 'chat', 'parent'])
                self.assertEqual(tail[0][1], ('sound/effects/barbwire1.ogg', 'sound/effects/barbwire2.ogg', 'sound/effects/barbwire3.ogg'))
                self.assertEqual(tail[1][1], ('tile', 'sound/effects/barbwire1.ogg', 50, True))
                self.assertEqual(tail[2][1], ('l_foot', 'r_foot', 'l_leg', 'r_leg'))
                self.assertEqual(tail[3], ('organ', 'l_foot'))
                self.assertEqual(tail[4], ('damage', (damage, 0, True, True)))
                self.assertEqual(tail[7], ('chat', actor, f'Your left foot gets {description} by the barbwire!'))
                self.assertEqual(result, 'parent result')

    def test_missing_organ_and_damage_failure_preserve_updates(self):
        events, _, _ = run_crossing(self.source, (True,), has_organ=False)
        self.assertEqual([event[0] for event in events], ['prob', 'pick', 'sound', 'pick', 'organ', 'health', 'parent'])
        events, _, _ = run_crossing(self.source, (True,), damaged=False)
        self.assertEqual([event[0] for event in events], ['prob', 'pick', 'sound', 'pick', 'organ', 'damage', 'health', 'chat', 'parent'])

    def test_nonhuman_and_missing_wire(self):
        for options in ({'human': False}, {'mob': False}):
            events, result, _ = run_crossing(self.source, (), **options)
            self.assertEqual((events, result), ([('parent',)], 'parent result'))
        for options in ({'wire': False}, {'location': None}):
            events, result, _ = run_crossing(self.source, (), **options)
            self.assertEqual((events, result), ([], None))

    def test_negative_control_detects_changed_second_probability(self):
        faulty = self.source.replace('else if (prob(33))', 'else if (prob(34))', 1)
        self.assertNotEqual(faulty, self.source)
        events, _, _ = run_crossing(faulty, (False, True))
        self.assertNotEqual(events[:2], [('prob', 33, False), ('prob', 33, True)])


if __name__ == '__main__':
    unittest.main()
