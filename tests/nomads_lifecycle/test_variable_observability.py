"""Offline synthetic reader and production-source controls. Never starts BYOND."""
import copy
import importlib.util
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/nomads-lifecycle'))
import variable_observability as m

NOW = datetime(2026, 10, 23, 4, 0, 0, tzinfo=timezone.utc)
REVISION, SESSION, ROUND = 'b' * 40, 'c' * 32, 'abc-DE12'


def envelope():
    return dict(schema=1, revision=REVISION, session=SESSION, round_id=ROUND,
                tick=100, realtime=1000, utc='2026-10-23 04:00:00')


def identity(present=True, z=1):
    ref = '[0x1]' if z == 1 else '[0x2]'
    return dict(present=present, lookup_ref=ref if present else None,
                type='/obj/item/stack/material/marble' if present else None,
                validity='capture_only', generation='unavailable',
                gc_destroyed=None, gcDestroyed=0 if present else None,
                location_state='found' if present else 'not_atom',
                location_chain=[dict(lookup_ref=ref, type='/turf/floor')] if present else [],
                **(dict(turf=dict(x=1, y=2, z=z, lookup_ref=ref), native=dict(x=1, y=2, z=z)) if present else {}))


def registry(present=False):
    return dict(total=int(present), scanned=int(present), matches_in_prefix=int(present),
                complete=True, membership='present' if present else 'absent')


def obj(z=1, frame=False):
    value = identity(z=z)
    value.update(thrown_list=registry(), processing_objects=registry(),
                 throw=dict(throwing=False, throwmode=0, speed=0, range=7, dist_travelled=0,
                            throw_speed=2, throw_range=7, original_target=identity(z=2),
                            thrower=identity(False), throw_source=identity(False)))
    if frame:
        value.update(field='original_target', entry=3)
    return value


def operation(active=True):
    value = dict(id='operation-1', kind='save', started_tick=90, stage='contents',
                 backend_started=True, contents_started=True, mutation_started=False,
                 restoring_players=False, owns_storage=True, active=active)
    value.update(skip_counts_available=True, runtime_field_skip_decisions=5,
                 runtime_reference_skip_decisions=2, legacy_runtime_field_skip_decisions=0,
                 skip_count_limit=1000000000)
    if not active:
        value.update(success=False, finished_tick=100)
    return value


def failure():
    source = obj(frame=True)
    target = obj(z=2)
    target['type'] = '/obj/item/weapon/roofbuilder/glass'
    return envelope() | dict(snapshot_id='failure-1', partial=False, operation=operation(),
        historical=True, live_resolution='unsupported', kind='cross_level_object',
        policy_classification='rejected_by_persistence_guard', saved_z=1, current_entry=0, first_z=0, first_entry=0,
        source=source, target=target, owner_chain=[copy.deepcopy(source)], owner_chain_truncated=False)


def status():
    return envelope() | dict(enabled=True, operation=None, last_operation=operation(False), failure=failure())


class Reader(unittest.TestCase):
    def inspect(self, value, **kwargs):
        return m.inspect(value, REVISION, SESSION, ROUND, now=NOW, **kwargs)

    def test_original_target_exact_source_field_target_and_physical_levels(self):
        value = self.inspect(status())['failure']
        self.assertEqual(value['source']['field'], 'original_target')
        self.assertEqual(value['source']['turf']['z'], 1)
        self.assertEqual(value['target']['turf']['z'], 2)
        self.assertEqual(value['source']['throw']['original_target']['lookup_ref'], value['target']['lookup_ref'])
        self.assertEqual(value['operation']['id'], 'operation-1')
        self.assertEqual(value['identity_validity'], 'capture_only')
        self.assertEqual(value['live_resolution'], 'unsupported')

    def test_active_inactive_and_unknown_throw_membership_remain_distinct(self):
        for throwing, member in ((False, False), (False, True), (True, True), (True, False)):
            value = status()
            for row in (value['failure']['source'], value['failure']['owner_chain'][0]):
                row['throw']['throwing'] = throwing
                row['thrown_list'] = registry(member)
            result = self.inspect(value)['failure']['source']
            self.assertEqual(result['throw']['throwing'], throwing)
            self.assertEqual(result['thrown_list']['membership'], 'present' if member else 'absent')
        value = status()
        for row in (value['failure']['source'], value['failure']['owner_chain'][0]):
            row['thrown_list'] = dict(total=300, scanned=256, matches_in_prefix=0,
                                      complete=False, membership='unknown')
        self.assertEqual(self.inspect(value)['failure']['source']['thrown_list']['membership'], 'unknown')

    def test_missing_deleted_cycle_and_depth_limit_do_not_become_live_objects(self):
        for state in ('cycle', 'depth_limit', 'no_turf'):
            value = status()
            target = value['failure']['target']
            target.pop('turf')
            target['location_state'] = state
            target['gc_destroyed'] = -2
            target['gcDestroyed'] = 100
            observed = self.inspect(value)['failure']['target']
            self.assertEqual(observed['location_state'], state)
            self.assertEqual(observed['generation'], 'unavailable')
            self.assertNotIn('turf', observed)
        value['failure']['target'] = identity(False) | dict(thrown_list=registry(), processing_objects=registry())
        self.assertFalse(self.inspect(value)['failure']['target']['present'])
        # A reused native ref cannot refresh an old capture. It is never located.
        value['failure']['utc'] = '2026-10-23 03:58:59'
        with self.assertRaisesRegex(m.Rejected, 'stale_snapshot'):
            self.inspect(value)

    def test_build_boot_round_operation_and_clock_changes_reject(self):
        for field, change in (('revision', 'd' * 40), ('session', 'd' * 32), ('round_id', 'new-round')):
            for where in ('status', 'failure'):
                value = status()
                (value if where == 'status' else value['failure'])[field] = change
                with self.subTest(field=field, where=where), self.assertRaisesRegex(m.Rejected, 'correlation_mismatch'):
                    self.inspect(value)
        for change in ('operation', 'tick', 'realtime', 'future'):
            value = status()
            if change == 'operation': value['last_operation']['id'] = 'operation-2'
            elif change == 'future': value['utc'] = '2026-10-23 04:00:01'
            else: value[change] += 601
            with self.subTest(change=change), self.assertRaises(m.Rejected):
                self.inspect(value)

    def test_failed_save_load_without_reference_context(self):
        for kind in ('save', 'load'):
            value = envelope() | dict(snapshot_id='failure-2', partial=False, historical=True,
                live_resolution='unsupported', kind='operation_failed', operation=operation(False))
            value['policy_classification'] = 'operation_failed_without_reference_context'
            value['operation']['kind'] = kind
            self.assertEqual(self.inspect(value, status=False)['operation']['success'], False)
            value['operation']['success'] = True
            with self.assertRaisesRegex(m.Rejected, 'correlation_mismatch'):
                self.inspect(value, status=False)

    def test_policy_counts_are_decisions_with_saturation_not_cleanup_claims(self):
        result = self.inspect(status())['failure']
        self.assertEqual(result['policy_classification'], 'rejected_by_persistence_guard')
        self.assertEqual(result['operation']['runtime_reference_skip_decisions'], 2)
        for key in ('runtime_field_skip_decisions', 'legacy_runtime_field_skip_decisions'):
            value = operation(False); value[key] = 1000000000
            self.assertEqual(m.operation(value)[key], 1000000000)
            value[key] += 1
            with self.assertRaises(m.Rejected): m.operation(value)

    def test_identity_discovery_copies_header_only(self):
        value = status()
        result = m.identity_header(value, REVISION, SESSION, now=NOW)
        self.assertEqual(result['round_id'], ROUND)
        self.assertNotIn('failure', result)
        self.assertNotIn('operation', result)
        self.assertEqual(m.identity_header(None, REVISION, SESSION)['reason'], 'unavailable')

    def test_historical_offline_inspection_is_explicit_never_current_or_future(self):
        value = failure()
        value['utc'] = '2026-10-22 04:00:00'
        with self.assertRaisesRegex(m.Rejected, 'stale_snapshot'):
            self.inspect(value, status=False)
        observed = self.inspect(value, status=False, historical=True)
        self.assertEqual(observed['freshness'], 'historical_only')
        self.assertEqual(observed['age_seconds'], 86400)
        self.assertEqual(observed['identity_validity'], 'capture_only')
        with self.assertRaisesRegex(m.Rejected, 'invalid_input'):
            self.inspect(status(), historical=True)
        value['utc'] = '2026-10-23 04:00:01'
        with self.assertRaisesRegex(m.Rejected, 'stale_snapshot'):
            self.inspect(value, status=False, historical=True)

    def test_historical_live_query_refused_before_transport(self):
        result = m.run(root='unused', revision=REVISION, session=SESSION, round_id=ROUND,
            historical=True, transport=lambda _: self.fail('historical mode queried runtime'))
        self.assertEqual(result['error_code'], 'invalid_input')

    def test_strips_unknown_fields_at_each_copied_level(self):
        value = status()
        for row in (value, value['failure'], value['failure']['source'], value['failure']['target'],
                    value['failure']['source']['throw'], value['failure']['owner_chain'][0],
                    value['failure']['target']['turf'], value['last_operation']):
            row['credential'] = 'SECRET-NAME-TOKEN-ERROR'
        encoded = json.dumps(self.inspect(value))
        self.assertNotIn('SECRET', encoded)
        self.assertNotIn('credential', encoded)

    def test_bounds_partial_and_malformed_evidence_reject(self):
        variants = []
        value = status(); value['failure']['partial'] = True; variants.append(value)
        value = status(); value['failure']['owner_chain'] *= 9; variants.append(value)
        value = status(); value['failure']['target']['location_chain'] *= 9; variants.append(value)
        value = status(); value['failure']['target']['type'] = '/' + 'x' * 160; variants.append(value)
        value = status(); value['failure']['target']['gc_destroyed'] = float('nan'); variants.append(value)
        value = status(); value['failure']['source']['field'] = 'secret bad field'; variants.append(value)
        value = status(); value['failure']['target']['thrown_list']['scanned'] = 257; variants.append(value)
        for value in variants:
            with self.assertRaises(m.Rejected): self.inspect(value)

    def test_one_existing_status_query_offline_file_and_sanitized_errors(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'supervisor.json').write_text(json.dumps(dict(port=1714, config_directory=str(root))))
            credential = 'a' * 32
            (root / 'lifecycle-token.txt').write_text(credential)
            calls = []
            response = dict(ok=1, revision=REVISION, session=SESSION, debug=dict(variables=status()))
            def transport(values):
                calls.append(values)
                self.assertEqual(values, dict(nomads_lifecycle='1', token=credential, action='status'))
                return copy.deepcopy(response)
            args = dict(revision=REVISION, session=SESSION, round_id=ROUND, now=NOW)
            self.assertTrue(m.run(root=root, transport=transport, **args)['ok'])
            self.assertEqual(len(calls), 1)
            path = root / 'failure.json'
            path.write_text(json.dumps(failure()))
            self.assertTrue(m.run(input_path=path, **args)['ok'])
            historical = failure()
            historical['utc'] = '2026-10-22 04:00:00'
            path.write_text(json.dumps(historical))
            self.assertEqual(m.run(input_path=path, **args)['error_code'], 'stale_snapshot')
            self.assertEqual(m.run(input_path=path, historical=True, **args)['data']['freshness'], 'historical_only')
            path.write_text('x' * 32769)
            self.assertEqual(m.run(input_path=path, **args)['error_code'], 'schema_rejected')
            response['secret'] = credential
            self.assertEqual(m.run(root=root, transport=transport, **args)['error_code'], 'schema_rejected')
            response.pop('secret')
            response['debug']['variables'] = dict(schema=1, enabled=False)
            self.assertEqual(m.run(root=root, transport=transport, **args)['error_code'], 'disabled')
            response['debug'] = {}
            self.assertEqual(m.run(root=root, transport=transport, **args)['error_code'], 'unavailable')

    def test_recursive_or_oversized_injected_packet_is_bounded(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'supervisor.json').write_text(json.dumps(dict(port=1714, config_directory=str(root))))
            (root / 'lifecycle-token.txt').write_text('a' * 32)
            recursive = {}; recursive['self'] = recursive
            for response in (recursive, dict(extra='x' * 32769)):
                self.assertEqual(m.run(root=root, revision=REVISION, session=SESSION, round_id=ROUND,
                    transport=lambda _: response, now=NOW)['error_code'], 'schema_rejected')


class ProducerSource(unittest.TestCase):
    """Actual-source invariants and omission controls, not execution of DM."""
    def setUp(self):
        self.source = (ROOT / 'code/modules/persistence/variable_observability.dm').read_text()
        self.functions = (ROOT / 'code/modules/persistence/functions.dm').read_text()

    def test_default_off_auth_fixed_paths_and_no_generic_access(self):
        for text in ('config/variable-observability.txt', '!= "enabled"', 'nomads_lifecycle_hex(nomads_lifecycle.read_token(), 32)',
                     'nomads_lifecycle_hex(nomads_lifecycle.read_revision(), 40)',
                     'data/variable-observability-last-failure.json'):
            self.assertIn(text, self.source)
        for forbidden in ('.vars', 'call(', 'locate(', 'for(var/atom/A in world)', 'world.Export', 'shell(', 'world.log', '.name', '.ckey'):
            self.assertNotIn(forbidden, self.source)
        self.assertNotIn('variable-observability.txt', '\n'.join(path.name for path in (ROOT / 'config').glob('*')))

    def assert_bounds(self, source):
        for text in ('for(var/i = 1 to 8)', 'if(A in seen)', 'min(registry.len, 256)',
                     'saving_export_stack.len - 7', 'saving_export_stack.len > 8',
                     'length(encoded) > VARIABLE_OBSERVABILITY_LIMIT', '#define VARIABLE_OBSERVABILITY_LIMIT 32768'):
            self.assertIn(text, source)

    def test_production_bounds_and_each_omission_control(self):
        self.assert_bounds(self.source)
        for removed in ('for(var/i = 1 to 8)', 'if(A in seen)', 'min(registry.len, 256)',
                        'saving_export_stack.len - 7', 'length(encoded) > VARIABLE_OBSERVABILITY_LIMIT'):
            with self.subTest(removed=removed), self.assertRaises(AssertionError):
                self.assert_bounds(self.source.replace(removed, 'REMOVED'))

    def test_serializer_hooks_preserve_rejection_ownership_and_runtime_exclusion(self):
        self.assertIn('variable_observability_capture(target)', self.functions)
        self.assertIn('catch\n\t\tlast_variable_failure = list', self.functions)
        self.assertIn('storage.variable_observability_finish(src, success)', self.functions)
        self.assertLess(self.functions.index('if(persistence_active_operation != src) return FALSE'),
                        self.functions.index('storage.variable_observability_finish(src, success)'))
        self.assertIn('if(key in list("last_variable_failure", "last_variable_operation")) return TRUE', self.functions)
        self.assertLess(self.functions.index('!operation.enter_backend(src, kind)'),
                        self.functions.index('if(kind == "save") last_variable_failure = null'))
        self.assertIn('#include "code\\modules\\persistence\\variable_observability.dm"', (ROOT / 'civ13.dme').read_text())

    def test_policy_is_observed_once_and_never_reimplemented(self):
        start = self.functions.index('if (persistence_runtime_var(key))')
        skip = self.functions.index('variable_observability_skipped(src.vars[key])', start)
        continuation = self.functions.index('continue', start)
        self.assertLess(start, skip)
        self.assertLess(skip, continuation)
        self.assertNotIn('persistence_runtime_var(', self.source)
        self.assertIn('variable_observability_skipped(null, TRUE)', (ROOT / 'code/modules/persistence/loading.dm').read_text())

    def test_native_packet_preparation_has_actual_collector_and_no_execution(self):
        spec = importlib.util.spec_from_file_location('prepare_variable_probe', Path(__file__).with_name('prepare_variable_probe.py'))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / 'packet'
            receipt = module.prepare(output)
            self.assertTrue(receipt['prepared_only'])
            self.assertFalse(receipt['native_verified'])
            self.assertEqual((output / 'variable_observability.dm').read_bytes(),
                             (ROOT / 'code/modules/persistence/variable_observability.dm').read_bytes())
            self.assertIn('/proc/trim(text)', (output / 'trim.dm').read_text())
            self.assertIn('OpenPort("none")', (output / 'probe.dm').read_text())
            self.assertIn('return FALSE', (output / 'probe.dm').read_text())


if __name__ == '__main__':
    unittest.main()
