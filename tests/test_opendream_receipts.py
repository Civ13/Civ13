"""Durable lifecycle boundaries with injected effects and isolated storage."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('receipt_control', Path(__file__).resolve().parents[1] / 'scripts/opendream/control.py')
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)


class Receipts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.store = control.OperationStore(self.temp.name, 'a' * 64)
        self.request = {'id': 'operation-1', 'action': 'restart', 'map': None}
        self.effects = 0

    def tearDown(self):
        self.temp.cleanup()

    def effect(self):
        self.effects += 1
        self.assertEqual('pending', self.store.inspect('operation-1')['outcome'])
        return {'ok': True, 'running': True}

    def test_pending_before_effect_and_immutable_terminal_replay(self):
        first = self.store.perform(self.request, 'cli', self.effect)
        second = self.store.perform(self.request, 'cli', self.effect)
        self.assertEqual(first, second)
        self.assertEqual(1, self.effects)
        self.assertEqual('committed', first['receipt']['outcome'])
        for field, value in [('action', 'stop'), ('profile_digest', 'b' * 64)]:
            with self.assertRaises(ValueError):
                self.store.perform(dict(self.request, **{field: value}), 'cli', self.effect)
        with self.assertRaises(ValueError):
            self.store.perform(self.request, 'game', self.effect)
        self.assertEqual(1, self.effects)

    def test_crash_boundaries_never_reexecute_uncertain_effect(self):
        for phase, expected_effects in [('pending_published', 0), ('effect_completed', 1)]:
            with self.subTest(phase=phase):
                with tempfile.TemporaryDirectory() as directory:
                    def crash(actual):
                        if actual == phase:
                            raise KeyboardInterrupt('injected crash')
                    store = control.OperationStore(directory, 'a' * 64, crash)
                    effects = []
                    with self.assertRaises(KeyboardInterrupt):
                        store.perform(self.request, 'cli', lambda: effects.append('effect') or {'ok': True})
                    recovered = control.OperationStore(directory, 'a' * 64)
                    reply = recovered.perform(self.request, 'cli', lambda: self.fail('uncertain effect replayed'))
                    self.assertEqual('operation_pending', reply['error'])
                    self.assertEqual(expected_effects, len(effects))

    def test_crash_after_terminal_recovers_original_result(self):
        def crash(phase):
            if phase == 'terminal_published':
                raise KeyboardInterrupt('before transport publication')
        self.store.checkpoint = crash
        with self.assertRaises(KeyboardInterrupt):
            self.store.perform(self.request, 'cli', self.effect)
        recovered = control.OperationStore(self.temp.name, 'a' * 64)
        reply = recovered.perform(self.request, 'cli', lambda: self.fail('terminal effect replayed'))
        self.assertTrue(reply['ok'])
        self.assertEqual(1, self.effects)

    def test_writer_exclusion_partial_receipt_and_path_rejection(self):
        lock = self.store.path('operation-1').with_suffix('.lock')
        lock.write_text('owned writer', encoding='ascii')
        with self.assertRaises(FileExistsError):
            self.store.perform(self.request, 'cli', self.effect)
        self.assertEqual('owned writer', lock.read_text())
        lock.unlink()
        self.store.path('operation-1').write_text('{', encoding='ascii')
        with self.assertRaises(ValueError):
            self.store.perform(self.request, 'cli', self.effect)
        self.assertEqual(0, self.effects)
        for identity in ['../escape', '', 'x' * 81]:
            with self.assertRaises(ValueError):
                self.store.path(identity)

    def test_full_history_retains_pending_barrier(self):
        from unittest.mock import patch
        self.store.checkpoint = lambda phase: (_ for _ in ()).throw(KeyboardInterrupt())
        with self.assertRaises(KeyboardInterrupt):
            self.store.perform(self.request, 'cli', self.effect)
        with patch.object(control, 'MAX_OPERATIONS', 1):
            with self.assertRaisesRegex(ValueError, 'history full'):
                self.store.perform(dict(self.request, id='operation-2'), 'cli', self.effect)
        self.assertEqual('pending', self.store.inspect('operation-1')['outcome'])



class TransportAndStages(unittest.TestCase):
    def setUp(self):
        import json
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / 'maps').mkdir()
        (self.root / 'maps/a.dmm').write_text('a')
        (self.root / 'maps/b.dmm').write_text('b')
        (self.root / 'civ13.dme').write_text('#include "maps/a.dmm"\n')
        (self.root / 'civ13.json').write_text('{"old":true}')
        self.profile_path = self.root / 'profile.json'
        self.profile_path.write_text(json.dumps({'engine':'opendream', 'runtime_dir':str(self.root),
            'game_port':18452, 'topic_port':18462, 'server_command':[__import__('sys').executable],
            'compiler':__import__('sys').executable, 'maps':{'B':'maps/b.dmm'}}))
        self.supervisor = control.Supervisor(self.profile_path)

    def tearDown(self):
        self.temp.cleanup()

    def stage(self):
        from unittest.mock import patch
        def compile_output(*args, **kwargs):
            (self.root / 'opendream-staged.json').write_text('{"new":true}')
        with patch.object(control.subprocess, 'run', side_effect=compile_output):
            self.supervisor.mapswap('B', defer=True)

    def test_stage_survives_controller_reconstruction_and_commits_after_validation(self):
        from unittest.mock import patch
        self.stage()
        recovered = control.Supervisor(self.profile_path)
        self.assertEqual('B', recovered.pending_map[2])
        with patch.object(recovered, 'stop') as stop, patch.object(recovered, 'start') as start:
            recovered.dispatch({'action':'restart'})
            stop.assert_called_once()
            start.assert_called_once()
        self.assertEqual('{"new":true}', (self.root / 'civ13.json').read_text())
        self.assertFalse((recovered.control / 'staged-map.json').exists())
        self.assertEqual('B', control.Supervisor(self.profile_path).map_id)

    def test_changed_stage_and_interrupted_replacement_fail_closed(self):
        from unittest.mock import patch
        self.stage()
        (self.root / 'opendream-staged.json').write_text('{"tampered":true}')
        with patch.object(self.supervisor, 'stop') as stop:
            with self.assertRaises(ValueError):
                self.supervisor.commit_map_stage()
            stop.assert_not_called()
        (self.root / 'opendream-staged.json').write_text('{"new":true}')
        original_replace = control.os.replace
        def interrupt(source, destination):
            if Path(destination).name == 'civ13.dme':
                raise OSError('injected interrupted second replacement')
            return original_replace(source, destination)
        with patch.object(self.supervisor, 'stop'), patch.object(control.os, 'replace', side_effect=interrupt):
            with self.assertRaises(OSError):
                self.supervisor.commit_map_stage()
        with self.assertRaisesRegex(ValueError, 'uncertain'):
            control.Supervisor(self.profile_path)
        inspector = control.Supervisor(self.profile_path, inspect_receipts_only=True)
        self.assertIsNone(inspector.operations.inspect('missing'))
        for effect in (inspector.start, inspector.stop, inspector.run, lambda: inspector.mapswap('B'), lambda: inspector.operate({'id': 'read-only', 'action': 'restart'})):
            with self.assertRaises(ValueError): effect()
        self.assertIsNone(inspector.operations.inspect('read-only'))

    def test_timeout_and_cancellation_preserve_exact_request(self):
        from unittest.mock import patch
        with self.assertRaises(TimeoutError):
            control.request(self.supervisor, 'restart', timeout=0, operation_id='timeout-1')
        request_path = self.supervisor.control / 'request.json'
        original = request_path.read_bytes()
        with self.assertRaises(ValueError):
            control.request(self.supervisor, 'restart', timeout=0, operation_id='timeout-2')
        self.assertEqual(original, request_path.read_bytes())
        request_path.unlink()
        with patch.object(control.time, 'sleep', side_effect=KeyboardInterrupt('cancel')):
            with self.assertRaises(KeyboardInterrupt):
                control.request(self.supervisor, 'restart', timeout=1, operation_id='cancel-1')
        self.assertEqual('cancel-1', control.read_json(request_path)['id'])
        self.assertFalse((self.supervisor.control / 'request.lock').exists())

    def test_cached_start_never_launches_and_changed_profile_rejects(self):
        from unittest.mock import Mock
        request = {'id':'cached-start', 'action':'start', 'map':None}
        self.supervisor.operations.perform(request, 'cli', lambda: {'ok':True})
        hook = Mock()
        self.assertTrue(control.request(self.supervisor, 'start', operation_id='cached-start', start_hook=hook)['ok'])
        hook.assert_not_called()
        other = control.OperationStore(self.supervisor.control, 'b' * 64)
        with self.assertRaises(ValueError):
            other.inspect('cached-start')

    def test_corruption_and_recomputed_unknown_fields_reject(self):
        import hashlib, json
        store = self.supervisor.operations
        request = {'id':'corrupt-1', 'action':'restart', 'map':None}
        reply = store.perform(request, 'cli', lambda: {'ok':True})
        original = reply['receipt']
        for mutation in ('extra', 'origin', 'pending_result'):
            record = json.loads(json.dumps(original))
            if mutation == 'extra': record['extra'] = True
            elif mutation == 'origin':
                record['request']['origin'] = 'untrusted'
                record['binding_digest'] = hashlib.sha256(json.dumps(record['request'], sort_keys=True, separators=(',', ':')).encode()).hexdigest()
            else:
                record.pop('launch_identity')
                record['outcome'] = 'pending'
            control.atomic_json(store.path('corrupt-1'), record)
            with self.assertRaises(ValueError): store.inspect('corrupt-1')

    def test_terminal_transport_failure_retains_request_and_recovers_without_effect(self):
        from unittest.mock import patch
        request_path = self.supervisor.control / 'request.json'
        control.atomic_json(request_path, {'id':'transport-stop', 'action':'stop', 'map':None})
        real_atomic = control.atomic_json
        def fail_transport(path, value):
            if Path(path).name == 'result.json':
                self.assertEqual('committed', self.supervisor.operations.inspect('transport-stop')['outcome'])
                self.assertTrue(request_path.exists())
                raise OSError('injected reply failure')
            real_atomic(path, value)
        with patch.object(self.supervisor, 'dispatch', return_value={'ok':True}) as effect, patch.object(self.supervisor, 'stop'), patch.object(control, 'atomic_json', side_effect=fail_transport):
            with self.assertRaises(OSError): self.supervisor.run()
            effect.assert_called_once()
        self.assertTrue(request_path.exists())
        recovered = control.Supervisor(self.profile_path)
        def verify_order(path, value):
            if Path(path).name == 'result.json':
                self.assertTrue(request_path.exists())
                self.assertEqual('committed', recovered.operations.inspect('transport-stop')['outcome'])
            real_atomic(path, value)
        with patch.object(recovered, 'dispatch') as effect, patch.object(recovered, 'stop'), patch.object(control, 'atomic_json', side_effect=verify_order):
            recovered.run()
            effect.assert_not_called()
        self.assertFalse(request_path.exists())
        self.assertTrue(control.read_json(recovered.control / 'result.json')['ok'])

    def test_pending_history_blocks_new_supervisor_before_any_effect(self):
        from unittest.mock import patch
        self.supervisor.operations.checkpoint = lambda phase: (_ for _ in ()).throw(KeyboardInterrupt())
        with self.assertRaises(KeyboardInterrupt):
            self.supervisor.operations.perform({'id':'uncertain-start', 'action':'start'}, 'cli', lambda: self.fail('effect'))
        with patch.object(self.supervisor, 'operate') as effect, patch.object(self.supervisor, 'stop'):
            with self.assertRaisesRegex(ValueError, 'Uncertain'):
                self.supervisor.run()
            effect.assert_not_called()

    def test_real_synthetic_worker_exclusion_and_replay(self):
        import subprocess, sys, time
        gate = self.root / 'gate'
        effect_path = self.root / 'effect'
        worker = r'''
import importlib.util, pathlib, sys, time
spec=importlib.util.spec_from_file_location('worker_control',sys.argv[1]); m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
root=pathlib.Path(sys.argv[2]); store=m.OperationStore(root,'a'*64)
def effect():
    (root/'effect').write_text('one')
    deadline=time.monotonic()+10
    while not (root/'gate').exists():
        if time.monotonic()>deadline: raise TimeoutError('synthetic gate timeout')
        time.sleep(.02)
    return {'ok':True}
print(store.perform({'id':'worker-1','action':'restart'},'cli',effect)['ok'])
'''
        child = subprocess.Popen([sys.executable, '-c', worker, str(Path(control.__file__)), str(self.root)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            deadline = time.monotonic() + 5
            while not effect_path.exists():
                if child.poll() is not None or time.monotonic() > deadline:
                    self.fail('synthetic worker failed to enter effect')
                time.sleep(.02)
            competing = control.OperationStore(self.root, 'a' * 64)
            with self.assertRaises(FileExistsError):
                competing.perform({'id':'worker-1','action':'restart'}, 'cli', lambda: self.fail('second effect'))
            gate.write_text('release')
            stdout, stderr = child.communicate(timeout=5)
            self.assertEqual(0, child.returncode, stderr.decode())
            self.assertEqual(b'True', stdout.strip())
            self.assertTrue(competing.perform({'id':'worker-1','action':'restart'}, 'cli', lambda: self.fail('replayed'))['ok'])
            self.assertEqual('one', effect_path.read_text())
        finally:
            if child.poll() is None:
                child.kill()
                child.communicate(timeout=5)


    def test_non_scalar_action_and_origin_reject_before_effect(self):
        for field, value in [('action', []), ('action', {}), ('map', []), ('profile_digest', [])]:
            request = dict(id='invalid-shape', action='restart', **{})
            request[field] = value
            with self.assertRaises(ValueError):
                self.supervisor.operations.perform(request, 'cli', lambda: self.fail('invalid effect'))
        with self.assertRaises(ValueError):
            self.supervisor.operations.perform({'id':'bad-origin','action':'restart'}, [], lambda: self.fail('effect'))

    def test_uncertain_effect_quarantines_running_writer(self):
        from unittest.mock import patch
        request_path = self.supervisor.control / 'request.json'
        control.atomic_json(request_path, {'id':'uncertain-stop','action':'stop','map':None})
        with patch.object(self.supervisor, 'dispatch', side_effect=ValueError('uncertain effect')) as effect, patch.object(self.supervisor, 'stop'):
            self.supervisor.run()
            effect.assert_called_once()
        reply = control.read_json(self.supervisor.control / 'result.json')
        self.assertEqual('operation_pending', reply['error'])
        self.assertFalse((self.supervisor.control / 'supervisor.lock').exists())
        with patch.object(self.supervisor, 'operate') as effect, patch.object(self.supervisor, 'stop'):
            with self.assertRaises(ValueError): self.supervisor.run()
            effect.assert_not_called()


if __name__ == '__main__':
    unittest.main()
