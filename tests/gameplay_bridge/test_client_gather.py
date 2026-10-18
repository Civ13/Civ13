"""Inert source/packet/result controls. No compiler, game, client or HTTP call."""
import copy
import hashlib
import io
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/gameplay_bridge'))
from client_gather_profile import IDENTITIES, MAP, ORACLE, normal_dme, verify_dme, verify_map, verify_oracle
from prepare_client_gather import prepare
from check_client_gather import read_json, verify_packet, verify_result
import compile_client_gather

HEAD = 'a' * 40


def synthetic_result():
    rows = []
    for i in range(1201):
        first = 100 <= i < 130
        second = 181 <= i < 187
        rows.append(dict(sequence=i + 1, tick=1000 + i, life_tick=10 + i // 20,
                         same_tool=1, cuttings=0 if i < 130 else 2,
                         left_grass=int(i < 130), right_grass=1, left_lit=1, right_lit=1,
                         left_advertised=int(i < 100), right_advertised=int(i < 181),
                         may_do_after=int(not (first or second)), survival_actions=int(first or second),
                         worker=int(first or second), claimed=int(first or second),
                         cancelled=int(185 <= i < 187), request_index=0 if i < 100 else (1 if i < 181 else 2)))
    result = dict(schema=1, kind='ordinary_client_gather', commit=HEAD, run_id='synthetic_only',
                  final=1, cleaned_refs=1, phase='observation_complete', failure='', dimensions=[9, 9, 1],
                  samples=rows, sequence=1201, tick=2201, bound_tick=1000,
                  request_ids=['gather_one', 'gather_two'], cancel_tick=1185, returned_tick=1187,
                  receipts={'gather_one': {'status': 'completed', 'reason': 'none'},
                            'gather_two': {'status': 'cancelled', 'reason': 'cancelled'}})
    witness = dict(commit=HEAD, run_id='synthetic_only', request_id='gather_two',
                   received_after_cancel_ack=True, sequence=301, tick=1300)
    return result, witness


class ClientGatherSourceTests(unittest.TestCase):
    def setUp(self):
        self.dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8-sig')
        self.oracle = (ROOT / ORACLE).read_text(encoding='utf-8-sig')
        self.map = (ROOT / MAP).read_text(encoding='utf-8-sig')

    def test_normal_dme_projection_preserves_every_original_include_and_function(self):
        generated = normal_dme(self.dme)
        verify_dme(self.dme, generated)
        self.assertIn('code\\world.dm', generated)
        self.assertNotIn('compile_generated', generated)
        self.assertNotIn('gather_probe.dm', generated)
        for text in (generated.replace('code\\world.dm', 'replacement.dm'),
                     generated + '/world/New()\n\treturn\n',
                     generated.replace('code\\_helpers\\mobs.dm', 'custom_mobs.dm')):
            with self.assertRaises(ValueError): verify_dme(self.dme, text)

    def test_production_stays_disabled_and_normal_entrypoints_are_present(self):
        self.assertNotIn('CIV13_GAMEPLAY_BRIDGE', self.dme)
        for path in IDENTITIES:
            self.assertTrue((ROOT / path).is_file(), path)
        self.assertIn('/world/New()', (ROOT / 'code/world.dm').read_text(encoding='utf-8-sig'))
        self.assertIn('/mob/Login()', (ROOT / 'code/game/mob/login.dm').read_text(encoding='utf-8-sig'))
        self.assertIn('life_tick++', (ROOT / 'code/game/mob/living/carbon/human/human_life.dm').read_text(encoding='utf-8-sig'))

    def test_activated_duplicate_or_missing_map_refused(self):
        for source in ('#define CIV13_GAMEPLAY_BRIDGE\n' + self.dme,
                       self.dme + '\n#include "extra.dmm"\n', self.dme.replace('.dmm"', '.txt"')):
            with self.assertRaises(ValueError): normal_dme(source)

    def test_fixed_map_real_landmarks_lamp_and_supplied_ground_resource(self):
        verify_map(self.map)
        for old, new in [('aaagsgaaa', 'aaagssaaa'), ('maaaaaaaa', 'maaaaaaa'),
                         ('(1,1,1)', '(1,1,2)'), ('/obj/map_metadata/testing', '/obj/map_metadata/nomads'),
                         ('/obj/structure/lamp/lamp_small/alwayson/white', '/obj/fixture_light')]:
            with self.assertRaises(ValueError): verify_map(self.map.replace(old, new))
        with self.assertRaises(ValueError): verify_map(self.map + '\n(1,1,2) = {"a"}\n')

    def test_oracle_no_production_overrides_no_foreign_mutation(self):
        verify_oracle(self.oracle)
        for unsafe in ('/world/New()\n\treturn\n', '/client/New()\n\treturn\n',
                       '/mob/living/human/Life()\n\treturn\n',
                       '/datum/gameplay_bridge/proc/execute()\n\treturn\n'):
            with self.assertRaises(ValueError): verify_oracle(self.oracle + unsafe)
        for unsafe in ('body.health = 100', 'body.life_tick++', 'session.eye = body',
                       'B.assign(session, list())', 'B.execute(list())', 'B.observe()',
                       'body.Life()', 'do_after(body, 30)', 'new /mob/living/human', 'del(world)',
                       'for (var/client/C in clients)\n\t\treturn'):
            with self.assertRaises(ValueError): verify_oracle(self.oracle.replace('sequence++', unsafe, 1))

    def test_omitted_bounded_ownership_lighting_horizon_and_cleanup_guards_refuse(self):
        for anchor in ('world.maxx != 9 || world.maxy != 9 || world.maxz != 1',
                       '!config.skip_persistence_saving', 'session.holder',
                       'session.gameplay_bridge_consent_mob != body', 'body.life_tick < 1',
                       'if (++visited > 64)', 'if (++visited > 128)',
                       'left.get_lumcount() >= 0.5', 'world.time - returned_tick < 35',
                       'world.time <= observation_deadline', 'body = null', 'captured = null'):
            with self.subTest(anchor=anchor), self.assertRaises(ValueError):
                verify_oracle(self.oracle.replace(anchor, 'OMITTED'))

    def test_exact_clean_head_required_before_output(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / 'root'; root.mkdir()
            out = Path(temp) / 'packet'
            for replies in ([b'b' * 40], [HEAD.encode(), b' M code/world.dm']):
                with patch('prepare_client_gather.git', side_effect=replies), self.assertRaises(ValueError):
                    prepare(root, out, HEAD)
                self.assertFalse(out.exists())
            with self.assertRaises(ValueError): prepare(root, root / 'packet', HEAD)

    def prepare_mock_packet(self, out, archive_extra=None, drift=False):
        files = {p: (ROOT / p).read_bytes() for p in IDENTITIES}
        files.update({MAP: self.map.encode(), ORACLE: self.oracle.encode()})
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode='w') as tar:
            for path, data in files.items():
                info = tarfile.TarInfo(path); info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
            if archive_extra:
                info = tarfile.TarInfo(archive_extra); info.size = 1
                tar.addfile(info, io.BytesIO(b'x'))
        heads = 0
        def git(_root, *args):
            nonlocal heads
            if args[:2] == ('rev-parse', 'HEAD'):
                heads += 1
                return ('b' * 40 if drift and heads > 1 else HEAD).encode()
            if args[0] == 'status': return b''
            if args[0] == 'ls-files': return '\0'.join(files).encode()
            if args[0] == 'show': return files[args[1].split(':', 1)[1]]
            if args[0] == 'archive': return archive.getvalue()
            raise AssertionError(args)
        with patch('prepare_client_gather.git', side_effect=git), patch('prepare_client_gather.selected_files', return_value=sorted(files)):
            return prepare(ROOT, out, HEAD)

    def test_self_contained_archive_manifest_no_config_and_all_hashes(self):
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp) / 'packet'
            source = self.prepare_mock_packet(out)
            manifest = verify_packet(out, HEAD)
            self.assertFalse(manifest['runtime_ready'])
            self.assertIsNone(manifest['actual_native_geometry'])
            self.assertFalse((out / 'runtime').exists())
            self.assertFalse((source / 'config').exists())
            self.assertEqual(manifest['normal_source_sha256']['code/world.dm'],
                             hashlib.sha256((ROOT / 'code/world.dm').read_bytes()).hexdigest())
            with self.assertRaises(ValueError): self.prepare_mock_packet(out)

    def test_tampered_or_extra_source_denied(self):
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp) / 'packet'; source = self.prepare_mock_packet(out)
            path = source / 'code/world.dm'; original = path.read_bytes()
            path.write_bytes(original + b'// altered')
            with self.assertRaisesRegex(ValueError, 'hash mismatch'): verify_packet(out, HEAD)
            path.write_bytes(original)
            (source / 'extra.dm').write_text('unsafe')
            with self.assertRaisesRegex(ValueError, 'extra/missing'): verify_packet(out, HEAD)

    def test_archive_escape_unselected_input_and_source_race_deny_before_write(self):
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp) / 'packet'
            for extra in ('../escape', '/absolute', 'config/host.txt', 'unselected.dm'):
                with self.subTest(extra=extra), self.assertRaises(ValueError):
                    self.prepare_mock_packet(out, archive_extra=extra)
                self.assertFalse(out.exists())
            with self.assertRaisesRegex(ValueError, 'frozen HEAD'):
                self.prepare_mock_packet(out, drift=True)
            self.assertFalse(out.exists())

    def test_packet_cannot_claim_runtime_or_geometry_acceptance(self):
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp) / 'packet'; self.prepare_mock_packet(out)
            path = out / 'manifest.json'; original = json.loads(path.read_text())
            for key, value in [('runtime_ready', True), ('runtime', 'passed'),
                               ('actual_native_geometry', [9, 9, 1]), ('native_grant', 'invented')]:
                manifest = copy.deepcopy(original); manifest[key] = value
                path.write_text(json.dumps(manifest))
                with self.subTest(key=key), self.assertRaises(ValueError): verify_packet(out, HEAD)

    def test_duplicate_and_nonfinite_json_denied(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'result.json'
            for text in ('{"a":1,"a":2}', '{"a":NaN}'):
                path.write_text(text)
                with self.assertRaises(ValueError): read_json(path)

    def test_compile_only_workflow_and_pinned_compiler_binding(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        step = workflow.split('      - name: Compile normal-startup ordinary-client gather fixture only\n', 1)[1].split('      - name:', 1)[0]
        for anchor in ("timeout-minutes: 8", "tests/gameplay_bridge", 'github.event.pull_request.head.sha || github.sha',
                       'compile_client_gather.py', 'git -C "$compile_source" rev-parse HEAD',
                       '--expected-commit "$CIV13_EXPECTED_COMMIT"', 'BYOND/byond/bin/byondsetup'):
            self.assertIn(anchor, step)
        self.assertNotIn('DreamDaemon', step)
        self.assertNotIn('deterministic_client.py', step)
        self.assertIn('gameplay-client-gather-compile/compiler.log', workflow)
        source = (ROOT / 'scripts/gameplay_bridge/compile_client_gather.py').read_text()
        self.assertIn('timeout=180', source)
        self.assertIn('verify_log(', source)
        self.assertNotIn('dd.exe', source)

    def test_mocked_compile_invocation_cannot_run_daemon_or_bootstrap(self):
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp); source = out / 'source'; source.mkdir()
            compiler = out / 'DreamMaker'; compiler.write_text('inert')
            def compile_only(argv, **kwargs):
                self.assertEqual(argv, [str(compiler.resolve()), '-max_errors', '0', 'client_gather.dme'])
                self.assertEqual(kwargs['cwd'], source)
                self.assertEqual(kwargs['timeout'], 180)
                kwargs['stdout'].write(b'DM compiler version 516.1681\n0 errors, 0 warnings\n')
                return type('Result', (), {'returncode': 0})()
            with patch('compile_client_gather.prepare', return_value=source), patch('compile_client_gather.subprocess.run', side_effect=compile_only) as run:
                report = compile_client_gather.run(ROOT, out, HEAD, out)
            self.assertEqual(run.call_count, 1)
            self.assertEqual(report['runtime'], 'not_run')


class ClientGatherResultTests(unittest.TestCase):
    def setUp(self):
        self.result, self.witness = synthetic_result()

    def validate(self):
        return verify_result(self.result, HEAD, 'synthetic_only', self.witness)

    def test_synthetic_complete_trace_only_accepts_fixture_oracles(self):
        report = self.validate()
        self.assertTrue(report['fixture_oracles_valid'])
        self.assertEqual(report['sampled_paid_interval_ticks'], 29)
        self.assertEqual(report['ui_native_assignment_and_os_cleanup'], 'separate evidence required')

    def test_wrong_identity_failed_geometry_or_cleanup_denied(self):
        for key, value in [('commit', 'b' * 40), ('run_id', 'other'), ('failure', 'blocked'),
                           ('dimensions', [9, 9, 2]), ('cleaned_refs', 0), ('final', 0)]:
            result = copy.deepcopy(self.result); result[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                verify_result(result, HEAD, 'synthetic_only', self.witness)

    def test_receipt_alone_unknown_or_ack_does_not_prove_quiescence(self):
        for status in ('unknown', 'cancel_requested', 'completed'):
            self.result['receipts']['gather_two']['status'] = status
            with self.assertRaises(ValueError): self.validate()
        self.result, self.witness = synthetic_result()
        self.witness['received_after_cancel_ack'] = False
        with self.assertRaises(ValueError): self.validate()
        with self.assertRaises(ValueError): verify_result(self.result, HEAD, 'synthetic_only', None)

    def test_late_ack_witness_needs_full_physical_horizon(self):
        for sequence in (1190, 1, 9999):
            self.witness['sequence'] = sequence
            self.witness['tick'] = 999 + sequence
            with self.assertRaises(ValueError): self.validate()

    def test_late_effect_worker_or_callback_leak_denied(self):
        for key, value in [('cuttings', 4), ('right_grass', 0), ('worker', 1),
                           ('survival_actions', 1), ('may_do_after', 0), ('same_tool', 0)]:
            result = copy.deepcopy(self.result); result['samples'][800][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                verify_result(result, HEAD, 'synthetic_only', self.witness)

    def test_no_natural_life_or_cancel_tail_life_denied(self):
        for start in (0, 187):
            result = copy.deepcopy(self.result)
            value = result['samples'][start]['life_tick']
            for row in result['samples'][start:]: row['life_tick'] = value
            with self.assertRaises(ValueError): verify_result(result, HEAD, 'synthetic_only', self.witness)

    def test_short_wait_missing_advertisement_output_or_revocation_denied(self):
        for mutation in ('paid', 'advertised', 'output', 'cancelled'):
            result = copy.deepcopy(self.result)
            for i, row in enumerate(result['samples']):
                if mutation == 'paid' and i < 125: row['claimed'] = 0
                if mutation == 'advertised': row['left_advertised'] = 0
                if mutation == 'output' and i >= 130: row['cuttings'] = 0
                if mutation == 'cancelled': row['cancelled'] = 0
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                verify_result(result, HEAD, 'synthetic_only', self.witness)

    def test_retained_original_cancel_visible_after_worker_return_is_valid(self):
        # Cooperative scheduling can retire the worker before the observer wakes.
        for row in self.result['samples']:
            row['cancelled'] = int(row['tick'] >= 1187)
        self.result['cancel_tick'] = 1187
        self.assertTrue(self.validate()['fixture_oracles_valid'])

    def test_fractional_world_clock_is_valid_but_counters_stay_integral(self):
        for row in self.result['samples']:
            row['tick'] += 0.25
        for key in ('tick', 'bound_tick', 'cancel_tick', 'returned_tick'):
            self.result[key] += 0.25
        self.witness['tick'] += 0.25
        self.assertTrue(self.validate()['fixture_oracles_valid'])
        self.result['samples'][10]['sequence'] = 11.25
        with self.assertRaises(ValueError): self.validate()

    def test_nonfinite_negative_or_missing_final_clocks_deny(self):
        for value in (float('inf'), float('nan'), -1, '1000', None, True):
            result = copy.deepcopy(self.result); result['bound_tick'] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                verify_result(result, HEAD, 'synthetic_only', self.witness)

    def test_sampling_gap_shortened_deadline_and_noninteger_fail_closed(self):
        for mutation in ('gap', 'short', 'nan'):
            result = copy.deepcopy(self.result)
            if mutation == 'gap': result['samples'][200]['tick'] += 10
            if mutation == 'short': result['bound_tick'] += 100
            if mutation == 'nan': result['samples'][200]['tick'] = float('nan')
            with self.assertRaises(ValueError): verify_result(result, HEAD, 'synthetic_only', self.witness)


if __name__ == '__main__':
    unittest.main()
