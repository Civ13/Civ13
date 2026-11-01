"""Selector, mutation and receipt contracts only. No DM process or game models."""
from copy import deepcopy
import importlib.util
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
    return dict(head='a'*40, variant=variant, byond_version=516, byond_build=1688,
                port=0, checks=checks, observations=observations, error=failure)


class PrepareTests(unittest.TestCase):
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
