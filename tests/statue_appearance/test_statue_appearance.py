"""Project statue initialization with the deferred callback run immediately."""
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'save_movement'))
import source_adapter


class TotemFavourTests(unittest.TestCase):
    def setUp(self):
        source = (ROOT / 'code/game/objects/structures/religious.dm').read_text()
        self.events = []
        self.jobs = []
        self.clients = SimpleNamespace(len=0)
        env = {
            'deferred': lambda delay: self.events.append(('timer', delay)) or True,
            'job_master': SimpleNamespace(faction_organized_occupations=self.jobs),
            'human_clients_mob_list': self.clients,
            'typed_iter': lambda jobs, kind: (job for job in jobs if job.kind == kind),
        }
        old_fields = source_adapter.FIELDS
        try:
            source_adapter.FIELDS += ('power', 'reltype', 'tribe', 'current_tribesmen',
                                      'desc', 'check_power', 'favour_mood')
            prefix = '/obj/structure/religious/totem/offerings/proc/'
            # The adapter rewrites ! even inside strings; preserve punctuation in its Python projection.
            mood_source = source.replace('"very angry!"', '"very angry\\x21"').replace(
                '"very pleased!"', '"very pleased\\x21"')
            self.mood = source_adapter.project(mood_source, prefix + 'favour_mood', 'src', env, method=True)
            self.check = source_adapter.project(source, prefix + 'check_power', 'src', env, method=True)
        finally:
            source_adapter.FIELDS = old_fields

    def test_favour_threshold_boundaries(self):
        for power, expected in ((-1, 'very angry!'), (0, 'very angry!'),
                                (49, 'very angry!'), (50, 'somewhat angry.'),
                                (99, 'somewhat angry.'), (100, 'neutral.'),
                                (149, 'neutral.'), (150, 'somewhat pleased.'),
                                (249, 'somewhat pleased.'), (250, 'very pleased!')):
            with self.subTest(power=power):
                self.assertEqual(self.mood(SimpleNamespace(power=power)), expected)

    def test_tribal_and_cross_deduct_before_selecting_mood(self):
        self.jobs.extend((SimpleNamespace(kind='/datum/job/indians/tribes/red', current_positions=2),
                          SimpleNamespace(kind='/datum/job/indians/tribes/blue', current_positions=99)))
        self.clients.len = 3
        for reltype, expected_power, expected_count, expected_desc in (
                ('tribal', 49, 2, 'A [icon_state] stone totem. The gods seem to be [pleasedval]'),
                ('other', 45, 3, 'A big stone cross. God seem to be [pleasedval]')):
            with self.subTest(reltype=reltype):
                self.events.clear()
                obj = SimpleNamespace(reltype=reltype, tribe='goose', power=51,
                                      current_tribesmen=0, icon_state='goose', desc='')
                obj.favour_mood = lambda: self.events.append(('mood', obj.power)) or self.mood(obj)
                obj.check_power = lambda: self.events.append(('repeat', obj.power))
                self.check(obj)
                self.assertEqual((obj.power, obj.current_tribesmen), (expected_power, expected_count))
                self.assertEqual(self.events, [('timer', 600), ('mood', expected_power),
                                               ('repeat', expected_power)])
                # The adapter leaves DM interpolation as literal text.
                self.assertEqual(obj.desc, expected_desc)

    def test_nonpositive_power_is_not_deducted(self):
        self.clients.len = 3
        for power in (0, -1):
            with self.subTest(power=power):
                obj = SimpleNamespace(reltype='other', tribe='', power=power,
                                      current_tribesmen=0, icon_state='cross', desc='')
                obj.favour_mood = lambda: self.mood(obj)
                obj.check_power = lambda: None
                self.check(obj)
                self.assertEqual(obj.power, power)


class StatueAppearanceTests(unittest.TestCase):
    def test_named_and_default_statues_initialize_appearance(self):
        source = (ROOT / 'code/game/objects/structures/religious.dm').read_text()
        declaration = '/obj/structure/religious/statue\n'
        body = source.split(declaration, 1)[1].split('\n/obj/structure/religious/statue/update_icon()', 1)[0]
        body = body.split('\n\tNew()\n', 1)[1]
        body = '\n'.join(line[1:] for line in body.splitlines())
        body = body.replace('..()', 'parent_new()')
        env = {'parent_new': lambda: None, 'deferred': lambda delay: True}
        old_fields = source_adapter.FIELDS
        try:
            source_adapter.FIELDS += ('name', 'statue_material', 'update_icon')
            start = source_adapter.project('proc/start()\n' + body + '\n',
                                           'proc/start', 'src', env, method=True)
        finally:
            source_adapter.FIELDS = old_fields
        for name in ('The King', 'statue'):
            calls = []
            statue = SimpleNamespace(name=name, statue_material='sandstone',
                                     update_icon=lambda: calls.append(True))
            start(statue)
            self.assertEqual(calls, [True], name)
            if name == 'The King':
                self.assertEqual(statue.name, name)


if __name__ == '__main__':
    unittest.main()
