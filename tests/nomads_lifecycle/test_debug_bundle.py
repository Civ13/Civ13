"""Synthetic-only offline pair, observed lifecycle trace and redaction controls."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/nomads-lifecycle'))
import debug_bundle as m


def sample(tick=10):
    return dict(schema=1, ok=True, tool='tiles', data=dict(revision='b' * 40, session='c' * 32,
        target_fingerprint='e' * 64, request='d' * 32, partial=False, same_target=True,
        tick_start=tick, tick_end=tick, sample=dict(
            lighting_lifecycle=dict(startup_in_progress=0, overlays_created=1,
                daylight_worker_available=1, daylight_updating=1, daylight_setup=0,
                daylight_revision=2, overlay_queue=3),
            lighting_3x3=[dict(present=True, x=30 + i // 3, y=40 + i % 3, z=1,
                dynamic=1, luminosity=0, overlay_luminosity=1,
                overlay=dict(present=True, invisibility=100, alpha=255, plane=15, layer=1),
                overlay_owner=dict(loc_is_sample_turf=True, registry_membership='unknown beyond prefix'))
                for i in range(9)])))


class BundleTests(unittest.TestCase):
    def test_pair_uses_distinct_existing_local_slots_and_keeps_operator_label_caveat(self):
        result = m.pair(sample(), 4, 5)
        self.assertEqual(result['black']['slot'], 4)
        self.assertEqual(result['visible']['slot'], 5)
        self.assertIn('rendering unverified', result['labels'])
        for pair in ((4, 4), (-1, 5), (4, 9), (None, 4), (True, 4)):
            with self.subTest(pair=pair), self.assertRaises(ValueError):
                m.pair(sample(), *pair)
        missing = sample()
        missing['data']['sample']['lighting_3x3'][4] = dict(present=False)
        with self.assertRaises(ValueError):
            m.pair(missing, 4, 5)

    def test_trace_observes_cached_stage_transition_without_claiming_intervening_events(self):
        first, last = sample(), sample(20)
        last['data']['sample']['lighting_lifecycle'].update(daylight_updating=0, daylight_setup=1, overlay_queue=0)
        result = m.trace([first, last])
        self.assertEqual(len(result['observations']), 2)
        self.assertTrue(result['observations'][0]['lifecycle']['daylight_updating'])
        self.assertFalse(result['observations'][1]['lifecycle']['daylight_updating'])
        self.assertIn('events between samples unavailable', result['scope'])

    def test_trace_rejects_mixed_build_session_body_neighborhood_partial_stale_and_bounds(self):
        for key, value in (('revision', 'f' * 40), ('session', 'f' * 32),
                           ('target_fingerprint', 'f' * 64), ('partial', True),
                           ('same_target', False), ('tick_start', 10), ('tick_end', 21)):
            last = sample(20)
            last['data'][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                m.trace([sample(), last])
        moved = sample(20)
        moved['data']['sample']['lighting_3x3'][0]['x'] += 1
        for values in ([sample()], [sample()] * 9, [sample(), moved]):
            with self.assertRaises(ValueError):
                m.trace(values)

    def test_public_bundle_allowlist_discards_nested_private_fields_and_external_capture_is_honest(self):
        value = sample()
        secret = 'private secret C:/Users/Someone/incident.log'
        value['secret'] = secret
        data = value['data']
        data['target'] = dict(ckey=secret, client_ref='[0x123]')
        data['sample']['lighting_3x3'][4]['secret'] = secret
        data['sample']['lighting_3x3'][4]['overlay']['rawmessage'] = secret
        data['sample']['lighting_lifecycle']['secret'] = secret
        result = m.bundle([value], screenshot_sha256='a' * 64, screenshot_utc='2026-10-17T12:00:00Z', black_slot=4, visible_slot=5)
        encoded = json.dumps(result)
        for private in (secret, 'session', 'request', 'target_fingerprint', 'client_ref', '"x"', '"y"', '"z"'):
            self.assertNotIn(private, encoded)
        self.assertFalse(result['screenshot']['pixels_captured_by_tool'])
        self.assertFalse(result['screenshot']['correlation_verified'])
        self.assertEqual(result['screenshot']['sha256'], 'a' * 64)

    def test_bundle_rejects_injected_enum_numeric_text_bad_hash_nonfinite_and_unknown_schema(self):
        for path, value in ((('schema',), 2), (('data', 'partial'), True),
                            (('data', 'sample', 'lighting_lifecycle', 'overlay_queue'), 'private'),
                            (('data', 'sample', 'lighting_lifecycle', 'overlay_queue'), float('nan'))):
            bad = sample()
            at = bad
            for key in path[:-1]:
                at = at[key]
            at[path[-1]] = value
            with self.subTest(path=path), self.assertRaises(ValueError):
                m.bundle([bad])
        for bad in ('C:/private.png', '', 'f' * 63, ['bad']):
            with self.assertRaises(ValueError):
                m.bundle([sample()], screenshot_sha256=bad)
        bad = sample()
        bad['data']['sample']['lighting_3x3'][0]['overlay_owner']['registry_membership'] = 'private'
        with self.assertRaises(ValueError):
            m.bundle([bad])

    def test_recovery_stage_is_allowlisted_old_schema_explicit_and_vision_omits_health(self):
        value = dict(schema=1, ok=True, tool='recovery', data=dict(revision='b' * 40,
            ready=0, busy=1, restart_hold=1, restart_import_complete=0, restart_intent=1,
            error_code='private', debug=dict(available=False)))
        result = m.bundle([value])
        self.assertFalse(result['snapshots'][0]['debug_available'])
        self.assertNotIn('private', json.dumps(result))
        value['data']['debug'] = dict(available=True, progress=dict(kind='load', saving_z=None,
            loading_z=2, active=True, backend_started=True, contents_started=True,
            mutation_started=False, restoring_players=False, percent_available=False))
        self.assertFalse(m.bundle([value])['snapshots'][0]['progress']['percent_available'])
        vision = sample()
        vision['tool'] = 'vision'
        vision['data']['sample'] = dict(client=dict(eye_relation='own mob'),
            mob=dict(sight=0, blinded=0, health='private'), living=dict(health=20), human=dict(saved_return_x=55))
        self.assertNotIn('health', json.dumps(m.bundle([vision])))
        self.assertTrue(m.bundle([vision])['snapshots'][0]['camera_on_own_mob'])

    def test_file_load_and_cli_failures_never_echo_private_path_or_traceback(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'synthetic.json'
            path.write_text(json.dumps(sample()))
            self.assertEqual(m.load(path)['schema'], 1)
            for text in ('x' * (m.LIMIT + 1), '{"x":NaN}', '{bad'):
                path.write_text(text)
                with self.assertRaises(ValueError):
                    m.load(path)
        import io
        with patch.object(sys, 'argv', ['debug_bundle.py', 'bundle', '--input', 'private-missing.json']), patch('sys.stdout', new_callable=io.StringIO) as output:
            self.assertEqual(m.main(), 1)
            self.assertEqual(json.loads(output.getvalue()), dict(schema=1, ok=False, error_code='input_rejected'))


if __name__ == '__main__':
    unittest.main()
