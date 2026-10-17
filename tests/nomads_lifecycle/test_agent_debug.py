"""Offline injected-transport tests. No server, token disclosure or native launch."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/nomads-lifecycle'))
import agent_debug as m


class AgentTools(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        (self.root / 'config').mkdir()
        self.token, self.revision = 'a' * 32, 'b' * 40
        (self.root / 'supervisor.json').write_text(json.dumps(dict(port=1714, config_directory=str(self.root / 'config'))))
        (self.root / 'config/lifecycle-token.txt').write_text(self.token)
        (self.root / 'config/host.txt').write_text('Own Host')
        self.status = dict(ok=1, revision=self.revision, session='c' * 32,
                           ready=0, busy=1, restart_hold=1, restart_import_complete=0,
                           restart_intent=1, error='Intended generation import failed: owner mismatch at 1,2,1 private-path')

    def query(self, values):
        self.assertEqual(values['action'], 'status')
        self.assertEqual(set(values), {'nomads_lifecycle', 'token', 'action'})
        return self.status.copy()

    def test_discovery_offline_and_invalid_tool_has_no_transport(self):
        def forbidden(_):
            self.fail('unexpected query')
        self.assertTrue(m.run('discover', transport=forbidden)['read_only'])
        for tool, revision in [('repair', self.revision), ('recovery', None), ('vision', '../bad'),
                               ([], self.revision), ({}, self.revision), (None, self.revision)]:
            self.assertEqual(m.run(tool, self.root, revision, transport=forbidden)['error_code'], 'invalid_input')

    def test_offline_discovery_input_schemas_match_command_cardinality_and_required_pairs(self):
        commands = {item['name']: item for item in m.discover()['offline_commands']}
        for name, bounds in (('pair', (1, 1)), ('trace', (2, 8)), ('bundle', (1, 8))):
            command = commands[name]
            self.assertFalse(command['runtime_required'])
            self.assertEqual((command['min_inputs'], command['max_inputs']), bounds)
            schema = command['input_schema']
            self.assertFalse(schema['additionalProperties'])
            inputs = schema['properties']['input']
            self.assertEqual((inputs['minItems'], inputs['maxItems']), bounds)
            self.assertEqual(schema['properties']['command']['const'], name)
            self.assertIn('input', schema['required'])
        self.assertEqual(commands['pair']['input_schema']['required'],
                         ['command', 'input', 'black_slot', 'visible_slot'])
        self.assertNotIn('black_slot', commands['trace']['input_schema']['properties'])
        bundle = commands['bundle']['input_schema']
        self.assertEqual(bundle['dependentRequired']['screenshot_sha256'], ['screenshot_utc'])
        self.assertEqual(bundle['dependentRequired']['black_slot'], ['visible_slot'])

    def test_held_world_classification_without_client_and_trace_redaction(self):
        result = m.run('recovery', self.root, self.revision, transport=self.query)
        self.assertTrue(result['ok'])
        self.assertEqual(result['data']['error_code'], 'lighting_owner_mismatch')
        self.assertTrue(result['data']['restart_hold'])
        self.assertFalse(result['data']['debug']['available'])
        for secret in (self.token, 'private-path', 'at 1,2,1'):
            self.assertNotIn(secret, json.dumps(result))

    def test_reject_wrong_revision_malformed_limits_and_credentials(self):
        for key, value in [('revision', 'd' * 40), ('session', 'bad'), ('ready', 2),
                           ('error', ['bad']), ('extra', 'x' * 32769), ('extra', self.token)]:
            before = self.status.copy()
            self.status[key] = value
            self.assertEqual(m.run('recovery', self.root, self.revision, transport=self.query)['error_code'], 'snapshot_rejected')
            self.status = before
        (self.root / 'config/lifecycle-token.txt').write_text('')
        self.assertEqual(m.run('recovery', self.root, self.revision, transport=self.query)['error_code'], 'snapshot_rejected')

    def test_transport_errors_are_structured_and_sanitized(self):
        def unavailable(_):
            raise OSError('secret path and token ' + self.token)
        self.assertEqual(m.run('recovery', self.root, self.revision, transport=unavailable),
                         dict(schema=1, ok=False, tool='recovery', error_code='transport_unavailable'))

    def test_failure_classes(self):
        for text, code in [('non-turf location', 'lighting_non_turf_location'),
                           ('duplicate registry entry', 'lighting_duplicate_registry'),
                           ('Invalid imported lighting overlay registration', 'lighting_registration_invalid'),
                           ('Intended generation import failed', 'generation_import_failed'),
                           ('raw traceback', 'runtime_error_details_withheld')]:
            self.assertEqual(m.classify(text), code)

    def debug(self):
        return dict(schema=1, tick=10, progress=dict(active=1, kind='load', saving_z=None, loading_z=2,
                    backend_started=1, contents_started=1, mutation_started=1, restoring_players=0, percent_available=0),
                    runtime=dict(total=2, skipped=0, cache_available=1, source_total=1, prefix_limit=8,
                    sources=[dict(file='code/modules/lighting/lighting_system.dm', line=119, logged=2, skipped=0, retired=0)],
                    stack_available=0, proc_available=0))

    def test_cached_progress_and_redacted_source_metadata(self):
        self.status['debug'] = self.debug()
        result = m.run('recovery', self.root, self.revision, transport=self.query)
        self.assertTrue(result['ok'])
        self.assertEqual(result['data']['debug']['progress']['loading_z'], 2)
        self.assertEqual(result['data']['debug']['runtime']['sources'][0]['line'], 119)

    def test_metadata_rejects_paths_unbounded_sources_unknown_schema_and_malformed(self):
        import copy
        valid = self.debug()
        for section, key, bad in [('runtime', 'sources', [{}] * 9), ('runtime', 'prefix_limit', 999),
                                 ('runtime', 'stack_available', 1), ('runtime', 'total', float('nan')),
                                 ('progress', 'kind', 'eval'), ('progress', 'percent_available', 1),
                                 ('progress', 'active', 0), ('progress', 'loading_z', 'secret')]:
            value = copy.deepcopy(valid)
            value[section][key] = bad
            self.status['debug'] = value
            self.assertEqual(m.run('recovery', self.root, self.revision, transport=self.query)['error_code'], 'snapshot_rejected')
        for path in ('C:/private/file.dm', 'code/../secret.dm', 'code/player secret.dm'):
            value = copy.deepcopy(valid)
            value['runtime']['sources'][0]['file'] = path
            with self.assertRaises(ValueError):
                m.debug_state(value)
        for malformed in ([], 'text', dict(schema=2), dict(schema=1, progress=[], runtime={})):
            self.status['debug'] = malformed
            self.assertEqual(m.run('recovery', self.root, self.revision, transport=self.query)['error_code'], 'snapshot_rejected')

    def test_own_host_tiles_and_vision_use_existing_reader_admission(self):
        nonce = 'd' * 32
        calls = []
        def transport(values):
            calls.append(values)
            if values['action'] == 'status':
                return self.status.copy()
            self.assertEqual(values['target'], 'ownhost')
            return dict(ok=1, schema=1, revision=self.revision, session='c' * 32, request=nonce,
                        target=dict(ckey='ownhost', client_ref='[0x1]', mob_ref='[0x2]'),
                        partial=0, same_target=1, tick_start=1, tick_end=1,
                        utc_start='test', utc_end='test', game_id='fixture',
                        sample=dict(lighting_3x3=[dict(present=True)] * 9, client=dict(eye_relation='own mob')))
        for tool in ('tiles', 'vision'):
            result = m.run(tool, self.root, self.revision, transport=transport, nonce=nonce)
            self.assertTrue(result['ok'])
            self.assertNotIn('target', result['data'])
        self.assertEqual([call['action'] for call in calls], ['status', 'diagnose'] * 2)
        from unittest.mock import patch
        with patch.object(m.reader, 'collect', return_value=dict(sample=dict(lighting_3x3=[{}] * 10),
             **{key: 1 for key in ('revision', 'session', 'request', 'partial', 'same_target', 'tick_start', 'tick_end')})):
            self.assertEqual(m.run('tiles', self.root, self.revision)['error_code'], 'snapshot_rejected')


if __name__ == '__main__':
    unittest.main()
