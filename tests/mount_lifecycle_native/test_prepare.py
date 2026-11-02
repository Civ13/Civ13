"""Selectors, receipts and projected fixture clock; no native process/game model."""
from copy import deepcopy
import importlib.util
import json
import struct
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('mount_acceptance_prepare', HERE / 'prepare.py')
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


def receipt(variant='none'):
    labels = probe.labels()
    failure = probe.VARIANTS[variant][1]
    if failure:
        labels = labels[:labels.index(failure) + 1]
    checks = [dict(label=label, passed=int(label != failure)) for label in labels]
    observations = []
    for case in dict.fromkeys(label.rsplit('.', 1)[0] for label in labels if not label.startswith('startup.')):
        operation = case.split('.')[0]
        phase = ('native_forceMove_return' if operation in ('death', 'separation') else
                 'native_mount_Destroy_entry' if operation == 'mount_qdel' else 'native_human_Destroy_entry')
        observations.append(dict(case=case, phase=phase, values=dict(modern=-2)))
        if operation in ('mount_qdel', 'rider_qdel'):
            observations.append(dict(case=case, phase='native_destroyed_event', values=dict(modern=-2)))
        if operation == 'rider_qdel' or (case.endswith('.retiring') and operation in ('death', 'mount_qdel')):
            observations.append(dict(case=case, phase='native_teardown_forceMove_return', values=dict()))
    return dict(head='a'*40, variant=variant, byond_version=516, byond_build=1688,
                port=0, checks=checks, observations=observations, error=failure, cleanup_error=None)


clock_spec = importlib.util.spec_from_file_location(
    'mount_fixture_clock_adapter', ROOT/'tests/save_movement/source_adapter.py')
clock_adapter = importlib.util.module_from_spec(clock_spec)
clock_spec.loader.exec_module(clock_adapter)


class ClockExpired(RuntimeError):
    pass


class ClockFloat(float):
    """Documented DM float32 arithmetic; only the fixture clock is modeled."""
    def __new__(cls, value):
        return super().__new__(cls, struct.unpack('<f', struct.pack('<f', value))[0])

    def __add__(self, other):
        return ClockFloat(float(self) + other)

    def __sub__(self, other):
        return ClockFloat(float(self) - other)

    def __mod__(self, other):
        return ClockFloat(float(self) % other)


class ClockReadings:
    def __init__(self, start, now):
        assert 0 <= start < 864000 and 0 <= now < 864000
        self.values = iter((start, now))

    @property
    def timeofday(self):
        return ClockFloat(next(self.values))

    @property
    def realtime(self):
        # Precision stress value for the failed fixture's epoch-clock mutant.
        # The actual native world.realtime value was not captured in run41368187879.
        return ClockFloat(8468928000 + next(self.values))


class PrepareTests(unittest.TestCase):
    def clock_expired(self, source, start, now):
        body = clock_adapter.extract(source, '/world/New')
        start_at = body.index('var/ack_')
        region = body[start_at:body.index('if (file2text("port-closed.ack")', start_at)]
        lines = [line.strip() for line in region.splitlines()]
        declarations = [line for line in lines if line.startswith('var/ack_')]
        conditions = [line for line in lines if line.startswith('if (')]
        throws = [line for line in lines if line.startswith('throw EXCEPTION(')]
        self.assertEqual((len(declarations), len(conditions), len(throws)), (1, 1, 1))
        # Project the actual declaration, predicate and exception, preserving
        # their expressions. The wait loop/engine file and sleep effects are
        # outside this one-sample clock contract.
        selected = ('/ack_wait_sample()\n\t' + declarations[0] + '\n\t' +
                    conditions[0] + '\n\t\t' + throws[0] + '\n')
        sample = clock_adapter.project(selected, '/ack_wait_sample', '',
            dict(world=ClockReadings(start, now), EXCEPTION=ClockExpired))
        try:
            sample()
        except ClockExpired as error:
            self.assertEqual(str(error), 'startup.external_ack_timeout')
            return True
        return False

    def test_fixture_ack_clock_exact_boundary(self):
        source = (HERE/'probe.dm').read_text()
        for start in (0, 123456, 800000):
            for elapsed in (0, 49, 50, 51):
                with self.subTest(start=start, elapsed=elapsed):
                    self.assertEqual(self.clock_expired(source, start, start+elapsed),
                                     elapsed >= 50)

    def test_fixture_ack_clock_midnight_rollover(self):
        source = (HERE/'probe.dm').read_text()
        for start, now, expired in ((863999, 0, False), (863999, 48, False),
                                    (863999, 49, True), (863990, 39, False),
                                    (863990, 40, True)):
            with self.subTest(start=start, now=now):
                self.assertEqual(self.clock_expired(source, start, now), expired)

    def test_fixture_ack_legacy_epoch_mutation_expires_without_elapsed_time(self):
        source = (HERE/'probe.dm').read_text()
        legacy = source.replace('var/ack_started = world.timeofday',
                                'var/ack_deadline = world.realtime + 50').replace(
            'if (((world.timeofday - ack_started + 864000) % 864000) >= 50)',
            'if (world.realtime >= ack_deadline)')
        self.assertNotEqual(legacy, source)
        self.assertTrue(self.clock_expired(legacy, 123456, 123456))
        self.assertFalse(self.clock_expired(source, 123456, 123456))

    def test_fixture_ack_clock_backward_wallclock_jump_fails_closed(self):
        # timeofday is wallclock, not monotonic; the unchanged supervisor's
        # monotonic startup/phase/attempt bounds remain the safety boundary.
        self.assertTrue(self.clock_expired((HERE/'probe.dm').read_text(),
                                          123456, 123455))

    def test_case_order_and_bounded_protocol(self):
        self.assertEqual(len(probe.cases()), 19)
        self.assertEqual(len(probe.labels()), 79)
        self.assertEqual(probe.labels()[-1], 'rider_qdel.absent.cleanup')
        self.assertEqual(len(set(probe.labels())), 79)

    def test_exact_separation_selector_and_single_conditional_control(self):
        source = (ROOT/'code/game/mob/living/carbon/human/human_life.dm').read_text()
        selected, raw = probe.select_separation(source)
        self.assertIn('\t\t\tforceMove(H.loc)\n', raw)
        self.assertNotIn('handle nutrition', raw)
        self.assertEqual(selected.count('#ifndef MOUNT_OMIT_SEPARATION'), 1)
        self.assertEqual(selected.count('#endif'), 1)
        self.assertIn('old_mount.update_icons()', selected)
        with self.assertRaises(ValueError):
            probe.select_separation(source + '\tif (riding && riding_mob)\n')
        with self.assertRaises(ValueError):
            probe.select_separation(source.replace('old_mount.rider == src', 'TRUE'))

    def test_control_wrappers_preserve_exact_original_blocks(self):
        for relative, (macro, block) in probe.BLOCKS.items():
            with self.subTest(relative=relative):
                source = (ROOT/relative).read_text()
                wrapped = probe.wrap(source, block, macro)
                self.assertEqual(wrapped.replace('#ifndef '+macro+'\n', '').replace('#endif\n', '', 1), source)
                with self.assertRaises(ValueError):
                    probe.wrap(source.replace(block, ''), block, macro)
                with self.assertRaises(ValueError):
                    probe.wrap(source+block, block, macro)

    def test_positive_receipt_and_four_specific_failure_prefixes(self):
        for variant, (_, failure) in probe.VARIANTS.items():
            with self.subTest(variant=variant):
                result = probe.validate_receipt(receipt(variant), 'a'*40, variant)
                self.assertEqual(result['expected_failure'], failure)
                self.assertEqual(result['assertions'], 79 if not failure else probe.labels().index(failure)+1)

    def test_counts_cannot_hide_missing_reordered_or_wrong_results(self):
        for mutate in (lambda row: row['checks'].pop(),
                       lambda row: row['checks'].reverse(),
                       lambda row: row['checks'][4].update(passed=0),
                       lambda row: row.update(error='runtime error'),
                       lambda row: row.update(port=1234),
                       lambda row: row.update(byond_build=1681),
                       lambda row: row.update(head='b'*40),
                       lambda row: row.update(cleanup_error='owned cleanup failed'),
                       lambda row: row.update(observations=[])):
            row = receipt()
            mutate(row)
            with self.assertRaises(ValueError):
                probe.validate_receipt(row, 'a'*40, 'none')

    def test_control_requires_exact_failure_after_passed_prefix(self):
        for variant in list(probe.VARIANTS)[1:]:
            row = receipt(variant)
            for mutate in (lambda value: value.update(error='compiler failure'),
                           lambda value: value['checks'][-1].update(passed=1),
                           lambda value: value['checks'][0].update(passed=0)):
                value = deepcopy(row)
                mutate(value)
                with self.assertRaises(ValueError):
                    probe.validate_receipt(value, 'a'*40, variant)

    def test_native_boundaries_and_destroyed_marker_are_required(self):
        row = receipt()
        row['observations'][0]['phase'] = 'synthetic_forceMove_reassignment'
        with self.assertRaises(ValueError):
            probe.validate_receipt(row, 'a'*40, 'none')
        row = receipt()
        for value in row['observations']:
            if value['phase'] == 'native_destroyed_event':
                value['values']['modern'] = 0
        with self.assertRaises(ValueError):
            probe.validate_receipt(row, 'a'*40, 'none')

    def test_cli_has_no_native_execution_or_compilation_mode(self):
        source = (HERE/'prepare.py').read_text()
        cli = source[source.index("if __name__ == '__main__':"):]
        self.assertNotIn('--compile', cli)
        self.assertNotIn('--execute', cli)
        self.assertNotIn('--byond', cli)
        self.assertNotIn('run_phase', source)
        fixture = (HERE/'probe.dm').read_text()
        self.assertIn('return ..()', fixture)
        self.assertNotIn('/proc/qdel(', fixture)
        self.assertNotIn('gc_destroyed =', fixture)

    def test_staging_composes_one_asset_tree_and_five_pinned_entrypoints(self):
        # Exercise the complete new composer, replacing only the existing large
        # exact-Git archive boundary. This is not a native constructor fixture.
        def fake_git(root, *args):
            if args == ('rev-parse', 'HEAD'):
                return b'a'*40
            if args == ('status', '--porcelain'):
                return b''
            if args[0] == 'show':
                return (ROOT / args[1].split(':', 1)[1]).read_bytes()
            raise AssertionError(args)

        def fake_archive(root, out):
            stage = out/'stage'
            stage.mkdir(parents=True)
            files = list(probe.BLOCKS) + ['code/game/mob/living/carbon/human/human_life.dm',
                                        'tests/human_subtile/probe.dm']
            for relative in files:
                path = stage/relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes((ROOT/relative).read_bytes())
            (stage/'human_subtile.dme').write_text('#include "tests\\human_subtile\\probe.dm"\n')
            return dict(head='a'*40, dme='stage/human_subtile.dme', suite='human')

        with tempfile.TemporaryDirectory(prefix='civ13-mount-prepare-') as temp:
            out = Path(temp)/'packet'
            with patch.object(probe.stager.current.legacy, 'git', side_effect=fake_git), \
                    patch.object(probe.stager, 'prepare_source', side_effect=fake_archive):
                manifest = probe.prepare(ROOT, out, 'a'*40)
            self.assertEqual(manifest['mount_manifest_schema'], 2)
            self.assertEqual(manifest['sequence'], list(probe.VARIANTS))
            self.assertEqual((out/'mount-native-manifest.json').read_bytes(),
                             (json.dumps(manifest, indent=2, sort_keys=True)+'\n').encode('utf-8'))
            self.assertFalse(manifest['native_executed'])
            self.assertFalse(manifest['execution_admitted'])
            self.assertEqual(set(manifest['variants']), set(probe.VARIANTS))
            self.assertEqual(manifest['variants']['none']['dme'], 'stage/human_subtile.dme')
            self.assertEqual(manifest['positive_assertions'], 79)
            stage = out/'stage'
            old_probe = (stage/'tests/human_subtile/probe.dm').read_text()
            self.assertNotIn('/world/New()', old_probe)
            for variant, data in manifest['variants'].items():
                entry = (out/data['dme']).read_text()
                self.assertIn('#define MOUNT_NATIVE_HEAD "'+'a'*40+'"', entry)
                self.assertIn('#define MOUNT_NATIVE_VARIANT "'+variant+'"', entry)
                self.assertIn('mount_lifecycle_native\\probe.dm', entry)
            self.assertEqual(len(list(stage.glob('*.dme'))), 5)

    def test_staging_rejects_wrong_commit_before_archive(self):
        with tempfile.TemporaryDirectory(prefix='civ13-mount-pin-') as temp:
            with patch.object(probe.stager.current.legacy, 'git', return_value=b'b'*40), \
                    patch.object(probe.stager, 'prepare_source') as archive:
                with self.assertRaises(ValueError):
                    probe.prepare(ROOT, Path(temp)/'packet', 'a'*40)
                archive.assert_not_called()


if __name__ == '__main__':
    unittest.main()
