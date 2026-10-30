"""Closed injury evidence schema and real prompt assembly with an offline transport."""
import json
import math
import unittest
import test_bridge

bridge = test_bridge.bridge


def event(**overrides):
    row = {'kind': 'animal_limb_loss', 'certainty': 'observed', 'age_seconds': 4,
           'source': 'alligator', 'body_part': 'l_hand'}
    row.update(overrides)
    return row


def project(**player):
    return bridge.public_game_context({'game_context': {'player': player}})['player']


class AnimalEvidenceTests(unittest.TestCase):
    setUp = test_bridge.BridgeTests.setUp
    tearDown = test_bridge.BridgeTests.tearDown
    make = test_bridge.BridgeTests.make

    def test_prompt_has_actual_limb_loss_not_private_variables(self):
        calls = []
        worker = self.make(lambda _, payload, *args: calls.append(payload) or
                           {'message': {'content': 'Injected offline response'}})
        request = {'id': '1-2-3', 'account': 'a' * 32, 'question': 'What hit me and removed my limb?',
                   'game_context': {'player': {
                       'recent_injuries': [event(attacker='PRIVATE NAME', ref='SECRET REF', raw_log='ADMIN LOG')],
                       'body_damage': [{'body_part': 'l_hand', 'missing': 1, 'brute': 12, 'burn': 0,
                                        'owner': 'PRIVATE OWNER'}],
                       'vars': {'tokens': 'SECRET TOKEN'}, 'attack_log': ['ADMIN LOG']}}}
        self.assertEqual(worker.answer(request)['status'], 'ok')
        prompt = calls[0]['messages'][0]['content']
        for value in ('"kind": "animal_limb_loss"', '"source": "alligator"', '"body_part": "l_hand"',
                      '"missing": true', 'confirms that attack removed', 'explicitly say the cause is unknown',
                      'neither the guide nor the server snapshot'):
            self.assertIn(value, prompt)
        for value in ('PRIVATE', 'SECRET', 'ADMIN LOG', 'attack_log', 'tokens'):
            self.assertNotIn(value, prompt)

    def test_events_reject_unreviewed_sources_body_parts_ages_and_certainty(self):
        invalid = [event(source=value) for value in ('human', 'SECRET ACTOR', None, [], {})]
        invalid += [event(body_part=value) for value in ('brain', 'admin_notes', None, [], {})]
        invalid += [event(age_seconds=value) for value in (-1, 600, 10000, True, 1.5, math.nan)]
        invalid += [event(certainty='inferred'), event(kind='unseen_attack')]
        for row in invalid:
            with self.subTest(row=row):
                self.assertEqual(project(recent_injuries=[row])['recent_injuries'], [])
        for field in ('source', 'body_part'):
            row = event()
            del row[field]
            self.assertEqual(project(recent_injuries=[row])['recent_injuries'], [])

    def test_confirmed_damage_without_known_body_part_survives_rerolled_target(self):
        row = event(kind='animal_damage')
        del row['body_part']
        self.assertEqual(project(recent_injuries=[row])['recent_injuries'], [row])
        self.assertEqual(project(recent_injuries=[dict(row, body_part=None)])['recent_injuries'], [row])
        self.assertEqual(project(recent_injuries=[dict(row, body_part='SECRET')])['recent_injuries'], [])
        self.assertEqual(project(recent_injuries=[dict(row, kind='animal_limb_loss')])['recent_injuries'], [])

    def test_event_bound_and_other_injury_sources(self):
        rows = [event(kind='animal_damage', source='animal'),
                {'kind': 'reported_projectile_hit', 'certainty': 'observed', 'age_seconds': 1},
                {'kind': 'self_weapon_hit', 'certainty': 'observed', 'age_seconds': 2}]
        self.assertEqual(project(recent_injuries=rows)['recent_injuries'], rows)
        self.assertEqual(project(recent_injuries=[event()] * 100)['recent_injuries'], [event()] * 6)
        self.assertEqual(project(recent_injuries=[])['recent_injuries'], [])
        self.assertNotIn('recent_injuries', project())

    def test_body_condition_closed_schema_bounds_and_types(self):
        row = {'body_part': 'chest', 'brute': 1234, 'burn': -2, 'missing': 0, 'vars': 'SECRET'}
        expected = {'body_part': 'chest', 'brute': 1000, 'burn': 0, 'missing': False}
        self.assertEqual(project(body_damage=[row])['body_damage'], [expected])
        self.assertEqual(project(body_damage=[row] * 100)['body_damage'], [expected])
        for field, value in [('body_part', []), ('body_part', 'brain'), ('missing', 'false'),
                             ('missing', 2), ('missing', .0), ('brute', True), ('brute', math.nan),
                             ('burn', math.inf), ('burn', '20')]:
            bad = dict(row, **{field: value})
            with self.subTest(field=field, value=value):
                self.assertEqual(project(body_damage=[bad])['body_damage'], [])
        # Bound before inspecting, so a valid 12th row cannot escape the limit.
        self.assertEqual(project(body_damage=[None] * 11 + [row])['body_damage'], [])
        self.assertEqual(project(body_damage=[])['body_damage'], [])
        self.assertNotIn('SECRET', json.dumps(project(body_damage=[row])))

    def test_empty_or_stale_records_leave_cause_unknown_in_real_prompt(self):
        calls = []
        worker = self.make(lambda _, payload, *args: calls.append(payload) or
                           {'message': {'content': 'Injected offline response'}})
        for index, injuries in enumerate(([], [event(age_seconds=600)])):
            calls.clear()
            request = {'id': f'1-2-{index}', 'account': ('a' if index == 0 else 'b') * 32, 'question': 'Why am I hurt?',
                       'game_context': {'player': {'recent_injuries': injuries,
                           'body_damage': [{'body_part': 'l_hand', 'missing': True, 'brute': 0, 'burn': 0}]}}}
            self.assertEqual(worker.answer(request)['status'], 'ok')
            prompt = calls[0]['messages'][0]['content']
            self.assertIn('"recent_injuries": []', prompt)
            self.assertIn('A missing limb or current damage alone cannot identify an attacker', prompt)
            self.assertIn('never infer events from definitions or prior dialogue', prompt)


if __name__ == '__main__':
    unittest.main()
