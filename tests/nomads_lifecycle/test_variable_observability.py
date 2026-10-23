"""Offline synthetic reader and production-source controls. Never starts BYOND."""
import copy
import importlib.util
from datetime import datetime, timedelta, timezone
import json
import math
from pathlib import Path
import struct
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


THROW_SCALARS = ('throwmode', 'speed', 'range', 'dist_travelled', 'throw_speed', 'throw_range')


def production_throw_defaults():
    source = (ROOT / 'code/game/atoms_movable.dm').read_text()
    block = source.split('/atom/movable\n', 1)[1].split('/atom/movable/New()', 1)[0]
    defaults = {}
    for line in block.splitlines():
        line = line.split('//', 1)[0].strip()
        if not line.startswith('var/'):
            continue
        declaration, assignment, expression = line.partition('=')
        key = declaration.strip().rsplit('/', 1)[-1]
        if key not in (*THROW_SCALARS, 'throwing'):
            continue
        expression = expression.strip() if assignment else 'null'
        defaults[key] = {'TRUE': 1, 'FALSE': 0}[expression] if expression in ('TRUE', 'FALSE') else json.loads(expression)
    if set(defaults) != {*THROW_SCALARS, 'throwing'}:
        raise AssertionError('Production throw field declarations changed')
    return defaults


def obj(z=1, frame=False):
    value = identity(z=z)
    value.update(thrown_list=registry(), processing_objects=registry(),
                 throw=dict(**production_throw_defaults(), original_target=identity(z=2),
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

    def test_reader_accepts_actual_production_base_throw_defaults(self):
        defaults = production_throw_defaults()
        self.assertEqual(defaults, dict(throwing=0, throwmode=0, speed=0, range=0,
                                       dist_travelled=0, throw_speed=2, throw_range=7))
        observed = self.inspect(status())['failure']['source']['throw']
        self.assertEqual({key: observed[key] for key in defaults}, defaults)

    def test_nullable_raw_throw_fields_preserve_unknown_separately_from_zero(self):
        producer = (ROOT / 'code/modules/persistence/variable_observability.dm').read_text()
        loader = (ROOT / 'code/modules/persistence/loading.dm').read_text()
        self.assertIn('object.vars[v] = null', loader)
        for key in THROW_SCALARS:
            self.assertIn(f'"{key}" = M.{key}', producer)
            with self.subTest(field=key):
                value = obj()
                value['throw'][key] = None
                self.assertIsNone(m.object_state(value)['throw'][key])
                value['throw'][key] = 0
                self.assertEqual(m.object_state(value)['throw'][key], 0)
                for invalid in ('null', {}, [], True, float('inf')):
                    value['throw'][key] = invalid
                    with self.assertRaises(m.Rejected): m.object_state(value)

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
        self.assertEqual(self.inspect(value)['failure_error'], 'stale_snapshot')
        with self.assertRaisesRegex(m.Rejected, 'stale_snapshot'):
            self.inspect(value['failure'], status=False)

    def test_build_boot_round_operation_and_clock_changes_reject(self):
        for field, change in (('revision', 'd' * 40), ('session', 'd' * 32), ('round_id', 'new-round')):
            for where in ('status', 'failure'):
                value = status()
                (value if where == 'status' else value['failure'])[field] = change
                with self.subTest(field=field, where=where):
                    if where == 'status':
                        with self.assertRaisesRegex(m.Rejected, 'correlation_mismatch'):
                            self.inspect(value)
                    else:
                        self.assertEqual(self.inspect(value)['failure_error'], 'correlation_mismatch')
        for change in ('operation', 'tick', 'realtime_reversal', 'future'):
            value = status()
            if change == 'operation': value['last_operation']['id'] = 'operation-2'
            elif change == 'future': value['utc'] = '2026-10-23 04:00:01'
            elif change == 'realtime_reversal': value['realtime'] -= 1
            else: value[change] += 601
            with self.subTest(change=change):
                if change == 'future':
                    with self.assertRaisesRegex(m.Rejected, 'stale_snapshot'):
                        self.inspect(value)
                else:
                    self.assertIn(self.inspect(value)['failure_error'], ('stale_snapshot', 'correlation_mismatch'))

    def test_epoch_float_rounding_explains_preserved_future_stamp(self):
        epoch = datetime(2000, 1, 1, tzinfo=timezone.utc)
        rounded = []
        for text in ('2026-10-23T04:38:01.034802+00:00', '2026-10-23T04:38:06.876286+00:00'):
            actual = datetime.fromisoformat(text)
            ticks = (actual - epoch).total_seconds() * 10
            native_float = struct.unpack('f', struct.pack('f', ticks))[0]
            self.assertEqual(2 ** (math.floor(math.log2(ticks)) - 23), 512)
            stamp = epoch + timedelta(seconds=native_float / 10)
            self.assertGreater(stamp, actual)
            self.assertEqual(stamp.strftime('%Y-%m-%d %H:%M:%S'), '2026-10-23 04:38:11')
            rounded.append(native_float)
        self.assertEqual(rounded, [8460454912, 8460454912])

    def test_coarse_realtime_step_is_not_a_freshness_clock(self):
        value = status()
        value['failure']['realtime'] = 8460450000
        value['realtime'] = 8460460000
        self.assertIsNotNone(self.inspect(value)['failure'])
        # UTC expiry and future rejection remain strict, regardless of realtime.
        value['failure']['utc'] = '2026-10-23 03:58:59'
        self.assertEqual(self.inspect(value)['failure_error'], 'stale_snapshot')
        value['utc'] = '2026-10-23 04:00:01'
        with self.assertRaisesRegex(m.Rejected, 'stale_snapshot'):
            self.inspect(value)

    def test_rejected_retained_failure_does_not_hide_current_ownership(self):
        for rejected, expected in (('utc', 'stale_snapshot'), ('tick', 'stale_snapshot'),
                                   ('operation', 'correlation_mismatch'), ('partial', 'partial_snapshot'),
                                   ('malformed', 'schema_rejected')):
            value = status()
            value['operation'] = operation()
            value['operation']['kind'] = 'load'
            value['operation']['id'] = 'operation-2'
            if rejected == 'utc': value['failure']['utc'] = '2026-10-22 04:00:00'
            elif rejected == 'tick': value['tick'] += 601
            elif rejected == 'partial': value['failure']['partial'] = True
            elif rejected == 'malformed': value['failure'] = dict(partial=False)
            original = copy.deepcopy(value)
            with self.subTest(rejected=rejected):
                result = self.inspect(value)
                self.assertEqual(result['operation'], m.operation(original['operation']))
                self.assertEqual(result['last_operation'], m.operation(original['last_operation']))
                self.assertEqual(result['failure_error'], expected)
                self.assertIsNone(result['failure'])
                self.assertEqual(value, original, 'inspection refreshed or changed retained evidence')
        self.assertIsNone(self.inspect(status())['failure_error'])
        invalid_current = status()
        invalid_current['operation'] = operation()
        invalid_current['operation']['id'] = 'invalid-current-owner'
        invalid_current['failure']['utc'] = '2026-10-22 04:00:00'
        with self.assertRaisesRegex(m.Rejected, 'schema_rejected'):
            self.inspect(invalid_current)

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
            result = self.inspect(value)
            self.assertIn(result['failure_error'], ('partial_snapshot', 'schema_rejected', 'correlation_mismatch'))
            self.assertIsNone(result['failure'])
            with self.assertRaises(m.Rejected): self.inspect(value['failure'], status=False)

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
            response['debug']['variables']['failure']['utc'] = '2026-10-22 04:00:00'
            observed = m.run(root=root, transport=transport, **args)
            self.assertTrue(observed['ok'])
            self.assertEqual(observed['data']['failure_error'], 'stale_snapshot')
            self.assertIsNone(observed['data']['failure'])
            self.assertEqual(observed['data']['last_operation']['id'], 'operation-1')
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

    def test_precise_utc_source_and_midnight_fail_closed(self):
        helper = self.source.split('/proc/variable_observability_utc()\n', 1)[1].split('\n/proc/', 1)[0]
        self.assertIn('var/before = world.timeofday', helper)
        self.assertIn('time2text(before, "YYYY-MM-DD hh:mm:ss", 0)', helper)
        self.assertIn('if(world.timeofday < before) return null', helper)
        self.assertNotIn('time2text(world.realtime', self.source)
        self.assertNotIn('world.timeofday =', self.source)
        self.assertNotIn('world.realtime =', self.source)

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
            defaults = (output / 'movable_defaults.dm').read_text()
            self.assertIn('\tvar/range = 0', defaults)
            self.assertIn('code\\game\\atoms_movable.dm' if sys.platform == 'win32' else 'code/game/atoms_movable.dm', receipt['source_sha256'])
            for key in (*THROW_SCALARS, 'throwing'):
                self.assertIn(f'\tvar/{key} = ', defaults)
            self.assertIn('OpenPort("none")', (output / 'probe.dm').read_text())
            self.assertIn('return FALSE', (output / 'probe.dm').read_text())


if __name__ == '__main__':
    unittest.main()
