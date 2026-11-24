"""Offline projections of the shipped skill/reward logic; not BYOND gameplay."""
import importlib.util
import math
import re
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/research_tree/science_investigations.dm'
spec = importlib.util.spec_from_file_location(
    'source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
HUMAN = '/mob/living/human/proc/'


class DmList(list):
    len = property(len)

    def __iadd__(self, value):
        self.append(value)
        return self


class Investigation:
    def __init__(self, source, level):
        self.state = SimpleNamespace(
            science_investigations=DmList(), scholarship={'natural_science': level, 'mathematics': 15},
            next_science_investigation=0)
        self.messages = []
        env = dict(
            re.findall(r'^#define (SCIENCE_\w+) (\d+)$', source, re.M))
        env = {key: int(value) for key, value in env.items()}
        env.update(
            SCIENCE_INVESTIGATION_COOLDOWN=30, world=SimpleNamespace(time=100),
            src=self.state, min=min, max=max, list=DmList, round=math.floor,
            islist=lambda x: isinstance(x, (list, dict)), length=len, istext=lambda x: isinstance(x, str),
            copytext=lambda s, first, stop: s[first-1:stop-1],
            findtext=lambda s, part: s.lower().find(part.lower()) + 1,
            findtextEx=lambda s, part: s.find(part) + 1,
            scholar_level=lambda discipline: self.state.scholarship.get(discipline, 0),
            to_chat=lambda _, message: self.messages.append(message),
            SPAN_NOTICE=lambda message: message)
        key = adapter.extract(source, '/proc/science_investigation_key_valid')
        key = key.replace('for (var/i=colon+1, i<=length(key), i++)',
                          'for (i in range(colon+1, length(key)+1))')
        key = key.replace(' in list(', ' in dm_values(')
        env.update(range=range, dm_values=lambda *values: values)
        self.valid = adapter.project('/proc/selected()\n' + key, '/proc/selected', 'key', env)
        env['science_investigation_key_valid'] = self.valid
        self.room = adapter.project(source, HUMAN + 'science_investigation_room', 'advanced', env)
        env['science_investigation_room'] = self.room
        # Convert references to actor state and the display-only interpolation.
        # All execution branches of the production payout are projected.
        body = adapter.extract(source, HUMAN + 'science_investigation_credit')
        body = re.sub(r'\b(science_investigations|scholarship|next_science_investigation)\b', r'src.\1', body)
        body = body.replace(' in list(', ' in dm_values(')
        body = body.replace(
            '"You finish the [novel ? "new" : "repeated"] investigation and gain [round(points * 100 + 0.5) / 100] Natural Science."',
            'str(points)')
        self.credit = adapter.project('/proc/selected()\n' + body, '/proc/selected', 'key, advanced', env)


class ScienceInvestigations(unittest.TestCase):
    source = SOURCE.read_text(encoding='utf-8-sig')

    def test_thresholds_and_cross_band_rejection(self):
        for level, early, advanced in [(23, 0, 0), (24, 12, 0), (35, 1, 0), (36, 0, 24), (59, 0, 1), (60, 0, 0), (81, 0, 0)]:
            result = Investigation(self.source, level)
            self.assertEqual((result.room(False), result.room(True)), (early, advanced))
        early = Investigation(self.source, 24)
        late = Investigation(self.source, 36)
        self.assertEqual(early.credit('glass:sand+sheet', False), 0)
        self.assertEqual(late.credit('ores:copper+tin', True), 0)
        self.assertEqual((early.messages, late.messages), ([], []))

    def test_diminishing_repeat_and_unchanged_mathematics(self):
        human = Investigation(self.source, 24)
        self.assertAlmostEqual(human.credit('ores:copper+tin', False), 1.8)
        self.assertAlmostEqual(human.credit('waters:fresh+salty', False), 1.8)
        self.assertAlmostEqual(human.credit('ores:copper+tin', False), 0.6)
        self.assertEqual(human.state.scholarship, {'natural_science': 28.2, 'mathematics': 15})
        self.assertEqual(human.state.next_science_investigation, 130)
        self.assertEqual(len(human.state.science_investigations), 2)

    def test_variety_progression_hits_both_caps_in_21_payments(self):
        human = Investigation(self.source, 24)
        early = ('ores:copper+iron', 'ores:copper+tin', 'ores:iron+tin',
                 'waters:fresh+salty', 'waters:dirty+fresh', 'waters:dirty+salty',
                 'firing:/obj/item/weapon/clay/claypot')
        late = ('glass:sand+sheet', 'smelt:iron+bloom', 'smelt:iron+steely_bloom',
                'smelt:iron+pig', 'smelt:iron_sand+kera', 'smelt:bloom+wrought',
                *(f'smelt:{ore}+ingot' for ore in ('copper', 'tin', 'zinc', 'lead', 'silver', 'gold')),
                'reaction:calcium_chloride', 'reaction:gluconic_acid')
        for keys, advanced in ((early, False), (late, True)):
            for key in keys:
                self.assertGreater(human.credit(key, advanced), 0, key)
            self.assertEqual(human.state.scholarship['natural_science'], 60 if advanced else 36)
        self.assertEqual(len(human.messages), 21)
        self.assertEqual(human.credit('reaction:polyethylene', True), 0)
        self.assertEqual(human.state.scholarship['natural_science'], 60)

    def test_key_validation_and_bounded_storage(self):
        human = Investigation(self.source, 36)
        for invalid in ('custom:alcohol', 'reaction:', 'REACTION:UPPER', 'reaction:a:b', 'reaction:<text>', 'reaction:' + 'a'*129, None):
            self.assertFalse(human.valid(invalid))
            self.assertEqual(human.credit(invalid, True), 0)
        human.state.science_investigations.extend(f'reaction:key{i}' for i in range(128))
        self.assertAlmostEqual(human.credit('reaction:calcium_chloride', True), 0.6)
        self.assertEqual(len(human.state.science_investigations), 128)

    def test_effects_follow_revalidation_and_real_completion(self):
        sample = adapter.extract(self.source, '/mob/living/human/verb/investigate_science_samples')
        reaction = adapter.extract(self.source, '/obj/structure/reaction_bench/verb/investigate_science_reaction')
        ordered = [sample.index(part) for part in (
            'if (!do_after', 'persistence_admission_changed(admission)',
            'var/list/current = science_sample_comparison(A, B)',
            'if (!current', 'left.reagents.remove_reagent', 'raw.loose_pile_use', 'left.use',
            'science_investigation_credit(current[2], advanced)')]
        self.assertEqual(ordered, sorted(ordered))
        self.assertRegex(reaction, r'if \(!synthesize\(reaction_id\)\)\n\t\tto_chat[^\n]+\n\t\treturn\n\tH\.science_investigation_credit')
        self.assertGreater(reaction.rindex('science_reaction_actor_valid'), reaction.index('do_after'))
        self.assertNotIn('note_field_work(', self.source)
        travel = (ROOT / 'code/modules/persistence/region_travel.dm').read_text(encoding='utf-8-sig')
        for surface in ('P["science_investigations"] = investigated',
                        'science_investigations_valid(P["science_investigations"])',
                        'H.science_investigations = clean_science_investigations'):
            self.assertIn(surface, travel)


if __name__ == '__main__':
    unittest.main()
