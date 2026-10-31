"""Offline contracts for cloud smoke admission and distinct native receipts."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import tempfile
import tarfile

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('cloud_npc_smoke', HERE / 'cloud_npc_smoke.py')
cloud = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cloud)


class CloudEnvelope(unittest.TestCase):
    def setUp(self):
        self.good = dict(uid=1000, interfaces=['lo'], memory=str(3 * 1024**3), swap='0', pids='64',
                         cpu='200000 100000', disk_bytes=1024**3, scratch_mount=True,
                         scratch_empty=True, source_readonly=True, bin_readonly=True,
                         archive_readonly=True, cgroup_pids=[123], own_pid=123,
                         effective_caps='0000000000000000', no_new_privs='1', cgroup_writable=False)

    def test_admits_bounded_envelope_and_rejects_each_missing_control(self):
        cloud.validate_envelope(**self.good)
        changes = dict(uid=0, interfaces=['lo', 'eth0'], memory='max', swap='max', pids='65',
                       cpu='max 100000', disk_bytes=1024**3+1, scratch_mount=False,
                       scratch_empty=False, source_readonly=False, bin_readonly=False,
                       archive_readonly=False, cgroup_pids=[123, 124], effective_caps='1',
                       no_new_privs='0', cgroup_writable=True)
        for key, value in changes.items():
            with self.subTest(control=key):
                trial = dict(self.good, **{key: value})
                with self.assertRaises(RuntimeError):
                    cloud.validate_envelope(**trial)
        with self.assertRaises(RuntimeError):
            cloud.validate_envelope(**dict(self.good, cpu='200001 100000'))

    def test_owned_process_cleanup_census_runs_even_on_failure(self):
        legacy = SimpleNamespace(run_process=lambda *args: (_ for _ in ()).throw(ValueError('native failed')))
        with patch.object(cloud, 'require_only_supervisor') as census:
            with self.assertRaises(ValueError):
                cloud.run_owned_phase(legacy, object(), [], Path('.'), 'daemon', 90)
            census.assert_called_once()
        with patch.object(cloud, 'require_only_supervisor', side_effect=RuntimeError('escaped')):
            with self.assertRaisesRegex(RuntimeError, 'escaped'):
                cloud.run_owned_phase(SimpleNamespace(run_process=lambda *args: None), object(), [], Path('.'), 'daemon', 90)

    def test_wildlife_receipt_rejects_wrong_engine_scope_or_incomplete_cases(self):
        row = dict(head='abc', error=None, port=0, byond_version=516, byond_build=1688,
                   cloud_wildlife_checks=9, npc_checks=0)
        cloud.validate_wildlife_receipt(row, 'abc')
        for key, value in (('head','other'), ('error','failed'), ('port',1), ('byond_build',1681),
                           ('cloud_wildlife_checks',8), ('npc_checks',46)):
            with self.subTest(field=key):
                with self.assertRaises(RuntimeError):
                    cloud.validate_wildlife_receipt(dict(row, **{key: value}), 'abc')

    def test_fixture_and_runner_scope_are_distinct(self):
        fixture = (HERE / 'cloud_wildlife.dm').read_text(encoding='utf-8')
        runner = (HERE / 'cloud_npc_smoke.py').read_text(encoding='utf-8')
        self.assertEqual(fixture.count('cloud_wildlife_assert('), 10)  # definition plus nine cases
        for key in ('wildlife_partial_contact_denied', 'wildlife_waits_for_contact_tick',
                    'wildlife_resumes_after_contact_tick', 'wildlife_changed_semantics_not_requeued'):
            self.assertIn(key, fixture)
        self.assertNotIn('prob(', fixture)
        self.assertIn('npc.validate_npc_receipt(receipt, args.head)', runner)
        self.assertIn('validate_wildlife_receipt(receipt, args.head)', runner)
        self.assertIn('if label == \'vendor\':', runner)
        self.assertIn("require(not any(work.rglob('*.sav'))", runner)
        self.assertIn('runtime.verify_linux(binary, archive)', runner)
        self.assertIn('run_owned_phase', runner)

    def test_staging_adaptation_anchors_match_committed_fixture(self):
        probe = (HERE / 'probe.dm').read_text(encoding='utf-8')
        self.assertEqual(probe.count('\t\t\thuman_subtile_fixture_headless()'), 1)
        self.assertEqual(probe.count('"checks" = human_subtile_fixture_checks,'), 1)
        adapted = probe.replace('\t\t\thuman_subtile_fixture_headless()', '\t\t\tnpc_subtile_fixture()')
        adapted = adapted.replace('"checks" = human_subtile_fixture_checks,',
                                  '"checks" = human_subtile_fixture_checks, "npc_checks" = npc_subtile_checks,')
        self.assertEqual(adapted.count('\t\t\tnpc_subtile_fixture()'), 1)
        self.assertEqual(adapted.count('"npc_checks" = npc_subtile_checks,'), 1)
        self.assertEqual(adapted.count('"scope" = "actual human/codec; headless authority adapter"'), 1)

    def test_top_level_failures_are_reported_and_rethrown(self):
        with patch.object(cloud, 'main', side_effect=TimeoutError('bounded timeout')), \
             patch.object(cloud, 'checkpoint') as record, \
             patch.object(cloud.signal, 'alarm', create=True), \
             patch.object(cloud, 'RUN_ROOT', None), patch.object(cloud, 'RUN_STARTED', None):
            with self.assertRaises(TimeoutError):
                cloud.guarded_entry()
            self.assertEqual(record.call_args.kwargs['outcome'], 'failed')
            self.assertEqual(record.call_args.kwargs['error_type'], 'TimeoutError')

    def test_runtime_scopes_are_bound_to_the_selected_fixture(self):
        source = (HERE / 'cloud_npc_smoke.py').read_text(encoding='utf-8')
        self.assertIn('vendor AI pulses and owned-offset codec; no wildlife acceptance', source)
        self.assertIn('wildlife owner/contact helper only; no Life/bite acceptance', source)
        self.assertIn("checkpoint('fixture-compile')", source)
        self.assertIn("fixture_dme_only=True", source)

    def test_bounded_package_uses_only_named_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            (root/'harness-status.json').write_text('{}')
            (root/'not-evidence.txt').write_text('excluded')
            result=cloud.package_evidence(root)
            self.assertGreater(result['bytes'],0)
            with tarfile.open(root/'harness-evidence.tar') as archive:
                self.assertEqual(archive.getnames(),['harness-status.json'])

    def test_compiled_fixture_is_shared_and_rechecked(self):
        source = (HERE / 'cloud_npc_smoke.py').read_text(encoding='utf-8')
        self.assertIn('os.link(source, target)', source)
        self.assertIn('os.chmod(source, 0o444)', source)
        self.assertEqual(source.split('def main():', 1)[1].count('verify_linked_runtime(work, artifacts)'), 2)

    def test_loader_inventory_rejects_missing_dependencies(self):
        row='libc.so.6 => /lib/i386-linux-gnu/libc.so.6 (0xf0000000)\n/lib/ld-linux.so.2 (0xf1230000)\n'
        self.assertEqual(cloud.parse_ldd(row), ['/lib/i386-linux-gnu/libc.so.6', '/lib/ld-linux.so.2'])
        with self.assertRaises(RuntimeError):
            cloud.parse_ldd('libcurl.so.4 => not found')
        with self.assertRaises(RuntimeError):
            cloud.parse_ldd('linux-gate.so.1 (0xf0000000)')

    def test_scratch_peak_is_an_observation_not_a_replacement_for_quota(self):
        meter=cloud.ScratchMeter(Path('.'))
        states=[SimpleNamespace(f_blocks=100, f_bfree=80, f_frsize=4096),
                SimpleNamespace(f_blocks=100, f_bfree=70, f_frsize=4096),
                SimpleNamespace(f_blocks=100, f_bfree=90, f_frsize=4096)]
        with patch.object(cloud.os,'statvfs',side_effect=states,create=True):
            meter.sample();meter.sample();meter.sample()
        self.assertEqual(meter.peak,30*4096)
        self.assertEqual(meter.samples,3)


if __name__ == '__main__':
    unittest.main()
