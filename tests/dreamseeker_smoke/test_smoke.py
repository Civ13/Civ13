"""Synthetic oracle tests, never native renderer evidence."""
import unittest
import ast
import copy
import fnmatch
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import tempfile
import time
import uuid
from types import SimpleNamespace
from unittest.mock import Mock, patch
from PIL import Image
import run


class SmokeContracts(unittest.TestCase):
    def test_daemon_uses_trusted_loopback_arguments(self):
        arguments = run.server_arguments(1234)
        self.assertEqual(arguments, ['fixture.dmb', '1234', '-ip', '127.0.0.1',
                                     '-invisible', '-trusted', '-nowebclient'])
        source = (run.ROOT/'run.py').read_text()
        launches = [node for node in ast.walk(ast.parse(source))
                    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                    and node.func.id == 'launch' and node.args
                    and isinstance(node.args[0], ast.Constant) and node.args[0].value == 'dd.exe']
        self.assertEqual(len(launches), 1)
        self.assertEqual(ast.unparse(launches[0].args[1]), 'server_arguments(port)')

    def test_safe_flag_negative_control_is_detected(self):
        arguments = run.server_arguments(1234)
        arguments[arguments.index('-trusted')] = '-safe'
        with patch.object(run, 'server_arguments', return_value=arguments):
            with self.assertRaises(AssertionError):
                self.test_daemon_uses_trusted_loopback_arguments()

    def test_pixels_require_phase_and_actor(self):
        for phase, color in [('red', 'red'), ('blue', 'blue')]:
            image = Image.new('RGB', (224, 224), color)
            self.assertFalse(run.pixel_contract(image, phase))
            image.paste((0, 255, 0), (96, 96, 128, 128))
            self.assertTrue(run.pixel_contract(image, phase))
            self.assertFalse(run.pixel_contract(image, 'blue' if phase == 'red' else 'red'))
            image.putpixel((0, 0), (0, 0, 255) if phase == 'red' else (255, 0, 0))
            self.assertFalse(run.pixel_contract(image, phase))

    def test_socket_policy(self):
        row = dict(protocol='tcp', address='127.0.0.1', remote='0.0.0.0', port=1234, state='listen')
        run.socket_contract([row], True, 1234)
        for changed in ({'address': '0.0.0.0'}, {'address': '::'}, {'remote': '8.8.8.8'},
                        {'protocol': 'udp'}, {'port': 4321}):
            with self.assertRaises(RuntimeError):
                run.socket_contract([dict(row, **changed)], True, 1234)
        with self.assertRaises(RuntimeError):
            run.socket_contract([row])
        run.socket_contract([dict(row, state='5', remote='127.0.0.1')])

    def test_source_scope(self):
        fixture = (run.ROOT/'fixture.dm').read_text()
        self.assertIn('copytext(key, 1, 7) == "Guest-"', fixture)
        self.assertIn('address != "127.0.0.1"', fixture)
        self.assertIn('spawn(600)', fixture)
        self.assertNotIn('civ13.dme', (run.ROOT/'fixture.dme').read_text())
        adapter = (run.ROOT/'windows.py').read_text()
        self.assertIn('limits.basic.active = 1', adapter)
        self.assertIn('startup.startup.show = 1 if visible else 0', adapter)
        self.assertIn('AssignProcessToJobObject', adapter)
        self.assertLess(adapter.index('AssignProcessToJobObject(self.job'), adapter.index('ResumeThread(process.thread)'))


class LocalAdmissionContracts(unittest.TestCase):
    """Invented admission data is used only with files/mocks, never Win32/native."""

    def setUp(self):
        self.runtime_check = self.enterContext(patch('local_runtime.verify_runtime'))
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.binary = self.root / 'installed'
        self.binary.mkdir()
        self.ledger = self.root / 'ledger'
        self.ledger.mkdir()
        self.output = self.root / 'evidence'
        self.admission = self.root / 'admission.json'
        self.manifest = self.root / 'manifest.json'
        names = [*run.VENDOR['binaries'], *run.LOCAL_RUNTIME_DLLS,
                 'ByondStub.dll', 'npbyond.dll', 'trace.bat']
        rows = []
        for name in names:
            data = ('offline mock file: ' + name).encode()
            (self.binary / name).write_bytes(data)
            rows.append(dict(name=name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
        # Preserve the known record's count/size contract without real binaries.
        padding = 20678208 - sum(row['bytes'] for row in rows)
        path = self.binary / 'trace.bat'
        with path.open('ab') as stream:
            stream.write(b'0' * padding)
        rows[-1].update(bytes=path.stat().st_size, sha256=run.digest(path))
        self.manifest.write_text(json.dumps(dict(bin=str(self.binary), files=rows)))
        hashes = {row['name']: row['sha256'] for row in rows}
        now = time.time()
        self.packet = dict(
            runtime={}, schema=1, scope='dreamseeker-smoke-local-installed', one_use_id=str(uuid.uuid4()),
            output=str(self.output), task_root=str(self.root), ledger=str(self.ledger),
            host='offline-test-host', account='offline-test-domain\\offline-test-user',
            source_sha256=run.source_identity(),
            python={'path': str(Path(run.sys.executable).resolve()), 'sha256': run.digest(run.sys.executable)},
            pillow_version=run.PIL.__version__, pillow_sha256=run.pillow_identity(),
            limits={'run_seconds': 150, 'cleanup_seconds_per_job': 5,
                    'cpu_seconds_per_process': 60, **run.LIMITS},
            review=dict(reference='OFFLINE MOCK ONLY', reviewer='test', resource_owner='test', executor='test',
                        desktop_owner='test', native_execution_approved=True,
                        exclusive_desktop_approved=True, socket_polling_limitation_accepted=True),
            profile=dict(decision='shared_effects_explicitly_accepted',
                         accepted_effects=run.SHARED_EFFECTS.copy(), evidence_reference='OFFLINE MOCK ONLY'),
            installed_manifest=str(self.manifest), issued_unix=now - 1, expires_unix=now + 120,
            resources=dict(measured_unix=now, free_ram_bytes=4 * 1024**3,
                           free_disk_bytes=2 * 1024**3, cpu_headroom_accepted=True))
        self.enterContext(patch.object(run, 'INSTALLED_MANIFEST_SHA256', run.digest(self.manifest)))
        self.enterContext(patch.object(run, 'INSTALLED_MANIFEST_SHAPE', (18, 20678208)))
        self.enterContext(patch.object(run, 'graphics_prerequisites', return_value={'offline': True}))
        self.enterContext(patch.object(run, 'VENDOR', {'binaries': {n: hashes[n] for n in run.VENDOR['binaries']}}))
        self.enterContext(patch.object(run.sys, 'platform', 'win32'))
        self.enterContext(patch.dict(run.os.environ, COMPUTERNAME='offline-test-host',
                                    USERDOMAIN='offline-test-domain', USERNAME='offline-test-user'))
        self.download = self.enterContext(patch.object(run, 'install', side_effect=AssertionError('download forbidden')))
        self.win32 = self.enterContext(patch.dict(run.sys.modules, windows=Mock(
            Adapter=Mock(side_effect=AssertionError('native adapter construction forbidden')))))

    def write_packet(self):
        self.admission.write_text(json.dumps(self.packet))
        return run.digest(self.admission)

    def load(self):
        return run.load_local(self.admission, self.write_packet(), self.output)

    def test_1688_local_runtime_requires_new_review_before_consumption(self):
        with patch.object(run, 'INSTALLED_MANIFEST_SHA256', None), \
                patch.object(run, 'INSTALLED_MANIFEST_SHAPE', None):
            with self.assertRaisesRegex(RuntimeError, '1688 installed runtime has not been reviewed'):
                self.load()
        self.assertEqual(list(self.ledger.iterdir()), [])
        self.download.assert_not_called()

    def stage(self):
        context = self.load()
        work = self.root / 'private-work'
        work.mkdir()
        return context, run.stage_local(context, work)

    def admit(self, context, binary):
        self.output.mkdir(exist_ok=True)
        adapter = Mock()
        adapter.free.return_value = 4 * 1024**3
        with patch.object(run.shutil, 'disk_usage', return_value=Mock(free=2 * 1024**3)):
            run.admit_local_launch(context, binary, adapter, self.output)

    def test_runtime_identity_scanned_once_at_admission_and_each_launch(self):
        context = self.load()
        self.assertEqual(self.runtime_check.call_count, 1)
        for expected in range(2, 5):
            run.local_fresh(context)
            self.assertEqual(self.runtime_check.call_count, expected)

    def test_explicit_admission_required_before_adapter_or_download(self):
        self.write_packet()
        with patch.dict(run.os.environ, GITHUB_ACTIONS='false'):
            with self.assertRaises(RuntimeError):
                run.run(self.output)
        with self.assertRaises(RuntimeError):
            run.run(self.output, reviewed_admission_sha256='0' * 64)
        for digest in (None, '0' * 64):
            with self.assertRaises(RuntimeError):
                run.run(self.output, self.admission, digest)
        with patch.object(run.sys, 'platform', 'linux'):
            with self.assertRaises(RuntimeError):
                run.run(self.output, self.admission, run.digest(self.admission))
        self.assertFalse(self.output.exists())
        self.download.assert_not_called()

    def test_missing_review_and_unresolved_profile_are_denied(self):
        original = copy.deepcopy(self.packet)
        mutations = [lambda p: p['review'].update(native_execution_approved=False),
                     lambda p: p['review'].update(desktop_owner=''),
                     lambda p: p['review'].update(socket_polling_limitation_accepted=False),
                     lambda p: p['profile'].update(decision='unresolved'),
                     lambda p: p['profile'].update(accepted_effects=[]),
                     lambda p: p['profile'].update(evidence_reference='')]
        for mutation in mutations:
            self.packet = copy.deepcopy(original)
            mutation(self.packet)
            with self.assertRaises(RuntimeError):
                self.load()

    def test_both_explicit_profile_choices_supported_without_native(self):
        self.load()
        self.packet['profile'].update(decision='isolated_verified', accepted_effects=[])
        self.load()
        self.download.assert_not_called()

    def test_bindings_expiry_and_fresh_resources_fail_closed(self):
        original = copy.deepcopy(self.packet)
        mutations = [lambda p: p.update(expires_unix=time.time() - 1),
                     lambda p: p.update(issued_unix=time.time() + 10),
                     lambda p: p.update(expires_unix=time.time() + 400),
                     lambda p: p.update(source_sha256={}),
                     lambda p: p.update(python={}),
                     lambda p: p.update(pillow_version='wrong'),
                     lambda p: p.update(pillow_sha256={}),
                     lambda p: p.update(host='wrong'),
                     lambda p: p.update(account='wrong'),
                     lambda p: p.update(output=str(self.root / 'other')),
                     lambda p: p.update(task_root=str(self.binary)),
                     lambda p: p['resources'].update(measured_unix=time.time() - 61),
                     lambda p: p['resources'].update(free_ram_bytes=1),
                     lambda p: p['resources'].update(free_disk_bytes=1),
                     lambda p: p['resources'].update(cpu_headroom_accepted=False)]
        for mutation in mutations:
            self.packet = copy.deepcopy(original)
            mutation(self.packet)
            with self.assertRaises(RuntimeError):
                self.load()

    def test_unknown_manifest_and_changed_or_extra_installed_bytes_denied(self):
        with patch.object(run, 'INSTALLED_MANIFEST_SHA256', '0' * 64):
            with self.assertRaises(RuntimeError):
                self.load()
        extra = self.binary / 'unexpected.dll'
        extra.write_bytes(b'extra')
        with self.assertRaises(RuntimeError):
            self.load()
        extra.unlink()
        (self.binary / 'dreamseeker.exe').write_bytes(b'changed')
        with self.assertRaises(RuntimeError):
            self.load()

    def test_stages_only_allowlisted_existing_bytes_without_download(self):
        context, binary = self.stage()
        self.assertEqual(set(p.name for p in binary.iterdir()), set(context['hashes']))
        self.assertEqual(len(context['hashes']), 15)
        self.assertNotIn('trace.bat', context['hashes'])
        self.download.assert_not_called()
        for name, expected in context['hashes'].items():
            self.assertEqual(run.digest(binary / name), expected)

    def test_exclusive_receipt_consumed_before_launch_and_not_reusable(self):
        context, binary = self.stage()
        self.assertFalse(context['receipt'].exists())
        self.admit(context, binary)
        receipt = run.read_json(context['receipt'])
        self.assertEqual(receipt['admission_sha256'], context['packet_sha256'])
        self.assertEqual(receipt['one_use_id'], self.packet['one_use_id'])
        # A competing admitted context cannot consume the same durable name.
        other = dict(context, consumed=False)
        with self.assertRaises(FileExistsError):
            self.admit(other, binary)
        self.admit(context, binary)  # same invocation may progress to next phase
        context['receipt'].write_text('{}')
        with self.assertRaises(RuntimeError):
            self.admit(context, binary)
        self.download.assert_not_called()

    def test_duplicate_packet_keys_and_ledger_escape_are_denied(self):
        self.admission.write_text('{"schema": 1, "schema": 1}')
        with self.assertRaises(RuntimeError):
            run.load_local(self.admission, run.digest(self.admission), self.output)
        self.packet['ledger'] = str(self.root.parent)
        with self.assertRaises(RuntimeError):
            self.load()

    def test_changed_installed_file_after_admission_and_existing_work_denied(self):
        context = self.load()
        (self.binary / 'dreammaker.exe').write_bytes(b'changed after admission')
        work = self.root / 'private-work'
        work.mkdir()
        with self.assertRaises(RuntimeError):
            run.stage_local(context, work)
        with self.assertRaises(FileExistsError):
            run.stage_local(context, work)

    def test_freshness_source_and_staged_bytes_rechecked_before_each_phase(self):
        context, binary = self.stage()
        with patch.object(run.time, 'monotonic', return_value=context['monotonic_expiry'] + 1):
            with self.assertRaises(RuntimeError):
                self.admit(context, binary)
        with patch.object(run, 'source_identity', return_value={}):
            with self.assertRaises(RuntimeError):
                self.admit(context, binary)
        (binary / 'unexpected.dll').write_bytes(b'bad')
        with self.assertRaises(RuntimeError):
            self.admit(context, binary)
        (binary / 'unexpected.dll').unlink()
        (binary / 'dreamdaemon.exe').write_bytes(b'bad')
        with self.assertRaises(RuntimeError):
            self.admit(context, binary)
        self.assertFalse(context['receipt'].exists())

    def test_real_headroom_checks_precede_consumption(self):
        context, binary = self.stage()
        self.output.mkdir()
        adapter = Mock()
        adapter.free.return_value = 1
        with self.assertRaises(RuntimeError):
            run.admit_local_launch(context, binary, adapter, self.output)
        adapter.free.return_value = 4 * 1024**3
        with patch.object(run.shutil, 'disk_usage', return_value=Mock(free=1)):
            with self.assertRaises(RuntimeError):
                run.admit_local_launch(context, binary, adapter, self.output)
        self.assertFalse(context['receipt'].exists())

    def test_production_local_branch_consumes_before_mock_process_creation(self):
        class MockCreationStopped(Exception):
            pass

        reviewed = self.write_packet()
        adapter = Mock()
        adapter.free.return_value = 4 * 1024**3
        adapter.cleanup.return_value = {'all_exited': True}

        def no_native_creation(*args, **kwargs):
            receipt = self.ledger / (self.packet['one_use_id'] + '.json')
            self.assertTrue(receipt.is_file(), 'production launch attempted before consumption')
            self.assertEqual(run.read_json(receipt)['admission_sha256'], reviewed)
            raise MockCreationStopped()

        adapter.launch.side_effect = no_native_creation
        fake_constructor = self.win32['windows'].Adapter
        fake_constructor.side_effect = None
        fake_constructor.return_value = adapter
        with patch.object(run.shutil, 'disk_usage', return_value=Mock(free=2 * 1024**3)), \
                patch.object(run.subprocess, 'check_output', return_value='offline-test-head'):
            with self.assertRaises(MockCreationStopped):
                run.run(self.output, self.admission, reviewed)
        self.download.assert_not_called()
        adapter.launch.assert_called_once()
        adapter.cleanup.assert_called_once_with(None, 5)
        self.assertTrue((self.output / 'receipt.json').is_file())

    def test_missing_admission_call_negative_control_is_detected(self):
        with patch.object(run, 'admit_local_launch', return_value=None):
            with self.assertRaisesRegex(AssertionError, 'before consumption'):
                self.test_production_local_branch_consumes_before_mock_process_creation()


class LocalRunOrchestrationContracts(unittest.TestCase):
    """Actual run/load/watch/finally paths, with every external effect injected."""
    write_packet = LocalAdmissionContracts.write_packet

    def setUp(self):
        LocalAdmissionContracts.setUp(self)
        self.clock = SimpleNamespace(mono=0.0, utc=time.time())
        self.enterContext(patch.object(run.time, 'monotonic', side_effect=lambda: self.clock.mono))
        self.enterContext(patch.object(run.time, 'time', side_effect=lambda: self.clock.utc))
        self.enterContext(patch.object(run.time, 'sleep', side_effect=lambda seconds: self.advance(seconds)))
        self.packet.update(issued_unix=self.clock.utc - 1, expires_unix=self.clock.utc + 120)
        self.packet['resources']['measured_unix'] = self.clock.utc

    def advance(self, seconds, wall=True):
        self.clock.mono += seconds
        if wall:
            self.clock.utc += seconds

    def invoke(self, hooks=None, module=run, budget=None, exit_phases=()):
        hooks = hooks or {}
        record = {'creations': [], 'argv': [], 'opened': [], 'cleanup': [], 'sockets': [], 'capture': 0}
        reviewed = self.write_packet()

        def hook(name, phase):
            if name in hooks:
                hooks[name](phase)

        def factory():
            index = len(record['opened'])
            phase = ('compile', 'server', 'client')[index]
            adapter = Mock()
            process = SimpleNamespace(pid=index + 1, process=index + 100)

            def opened(**kwargs):
                if 'creation_guard' in kwargs:
                    kwargs['creation_guard']()
                record['opened'].append(phase)
                hook('open', phase)

            def launched(argv, fixture, output, actual_phase, visible=False, **kwargs):
                if 'creation_guard' in kwargs:
                    kwargs['creation_guard']()
                record['argv'].append((actual_phase, list(argv)))
                record['creations'].append((phase, self.clock.mono, self.clock.utc))
                hook('creation', phase)
                if phase == 'compile':
                    (fixture / 'fixture.dmb').write_bytes(b'offline stub, not compiled')
                    (output / 'compile.stdout.log').write_text('DM compiler version 516.1688\n0 errors, 0 warnings')
                if phase == 'server':
                    (fixture / 'ready.txt').write_text('ready')
                return process

            def cleanup(retained, seconds):
                record['cleanup'].append((phase, seconds))
                hook('cleanup', phase)
                return {'all_exited': True}

            def free():
                hook('free', phase)
                return 4 * 1024**3

            def sockets(_):
                record['sockets'].append((phase, self.clock.mono, self.clock.utc))
                hook('sockets', phase)
                return [dict(protocol='tcp', address='127.0.0.1', remote='0.0.0.0',
                             port=1234, state='listen')] if phase == 'server' else []

            adapter.open.side_effect = opened
            adapter.launch.side_effect = launched
            adapter.cleanup.side_effect = cleanup
            adapter.free.side_effect = free
            adapter.exited.side_effect = lambda _: phase == 'compile' or (
                phase in exit_phases and len(record['creations']) == 3)
            def finished(_):
                hook('finish', phase)
                return {'exit_code': 7 if phase == 'server' else 0}
            def identity(_):
                hook('identity', phase)
                return dict(pid=process.pid, creation_filetime=10000 + index,
                            image=phase + '.exe')
            adapter.finish.side_effect = finished
            adapter.identity.side_effect = identity
            adapter.memory.return_value = 1
            adapter.times.return_value = (0, 0)
            adapter.accounting.return_value = SimpleNamespace(total=1)
            adapter.sockets.side_effect = sockets
            return adapter

        def capture(*_):
            record['capture'] += 1
            hook('capture', 'client')
            raise ValueError('primary capture failure')

        fake_socket = Mock()
        fake_socket.return_value.__enter__ = Mock(return_value=Mock(getsockname=Mock(return_value=('127.0.0.1', 1234))))
        fake_socket.return_value.__exit__ = Mock(return_value=False)
        constructor = self.win32['windows'].Adapter
        constructor.side_effect = factory
        load = module.load_local

        def loaded(*args):
            context = load(*args)
            record['context'] = context
            return context

        with patch.object(module, 'ROOT', run.ROOT), patch.object(module, 'VENDOR', run.VENDOR), \
                patch.object(module, 'INSTALLED_MANIFEST_SHA256', run.INSTALLED_MANIFEST_SHA256), \
                patch.object(module, 'INSTALLED_MANIFEST_SHAPE', run.INSTALLED_MANIFEST_SHAPE), \
                patch.object(module, 'graphics_prerequisites', side_effect=lambda: hook('graphics', 'compile') or {'offline': True}), \
                patch.object(module, 'load_local', side_effect=loaded), \
                patch.object(module, 'install', side_effect=AssertionError('download forbidden')), \
                patch.object(module.shutil, 'disk_usage', side_effect=lambda _: self.disk(hook)), \
                patch.object(module.subprocess, 'check_output', return_value='offline-head'), \
                patch.object(module.socket, 'socket', fake_socket), \
                patch.object(module, 'desktop_capture', side_effect=capture):
            try:
                module.run(self.output, self.admission, reviewed, **({'budget': budget} if budget is not None else {}))
            except BaseException as error:
                record['error'] = error
        receipt = self.output / 'receipt.json'
        record['receipt'] = json.loads(receipt.read_text()) if receipt.exists() else None
        return record

    def disk(self, hook):
        hook('disk', 'compile')
        return SimpleNamespace(free=2 * 1024**3)

    def assert_console_compiler(self, module=run):
        record = self.invoke(module=module)
        self.assertEqual(record['argv'][0][0], 'compile')
        argv = record['argv'][0][1]
        self.assertEqual(Path(argv[0]).name, 'dm.exe')
        self.assertEqual(argv[1:], ['-max_errors', '0', 'fixture.dme'])
        self.assertEqual([phase for phase, _ in record['argv']], ['compile', 'server', 'client'])
        self.assertEqual(str(record['error']), 'primary capture failure')

    def test_actual_orchestration_selects_console_compiler(self):
        self.assert_console_compiler()

    def test_gui_compiler_selector_mutant_is_detected(self):
        import types
        module = types.ModuleType('gui_compiler_mutant')
        module.__file__ = str(run.ROOT/'run.py')
        source = (run.ROOT/'run.py').read_text()
        changed = source.replace("launch('dm.exe', ['-max_errors'", "launch('dreammaker.exe', ['-max_errors'")
        self.assertNotEqual(changed, source)
        exec(compile(changed, module.__file__, 'exec'), module.__dict__)
        with self.assertRaisesRegex(AssertionError, 'dm.exe'):
            self.assert_console_compiler(module)

    def assert_console_daemon(self, module=run):
        record = self.invoke(module=module)
        self.assertEqual(record['argv'][1][0], 'server')
        argv = record['argv'][1][1]
        self.assertEqual(Path(argv[0]).name, 'dd.exe')
        self.assertEqual(argv[1:], ['fixture.dmb', '1234', '-ip', '127.0.0.1',
                                    '-invisible', '-trusted', '-nowebclient'])
        self.assertEqual([phase for phase, _ in record['argv']], ['compile', 'server', 'client'])
        self.assertEqual(str(record['error']), 'primary capture failure')

    def test_actual_orchestration_selects_console_daemon(self):
        self.assert_console_daemon()

    def test_gui_daemon_selector_mutant_is_detected(self):
        import types
        module = types.ModuleType('gui_daemon_mutant')
        module.__file__ = str(run.ROOT/'run.py')
        source = (run.ROOT/'run.py').read_text()
        changed = source.replace("launch('dd.exe', server_arguments(port)",
                                 "launch('dreamdaemon.exe', server_arguments(port)")
        self.assertNotEqual(changed, source)
        exec(compile(changed, module.__file__, 'exec'), module.__dict__)
        with self.assertRaisesRegex(AssertionError, 'dd.exe'):
            self.assert_console_daemon(module)

    def assert_original_entry_preserved(self, module=run):
        budget = run.Budget()
        self.advance(117)
        self.packet.update(issued_unix=self.clock.utc - 1, expires_unix=self.clock.utc + 120)
        self.packet['resources']['measured_unix'] = self.clock.utc
        record = self.invoke(module=module, budget=budget)
        self.assertIs(record['context']['budget'], budget)
        self.assertEqual(budget.started_monotonic, 0)
        self.assertLessEqual(budget.remaining(work=True), 32)
        self.assertEqual(str(record['error']), 'primary capture failure')

    def test_actual_run_keeps_wrapper_original_entry(self):
        self.assert_original_entry_preserved()

    def test_actual_run_fresh_clock_mutant_is_detected(self):
        import types
        module = types.ModuleType('reset_budget_mutant')
        module.__file__ = str(run.ROOT/'run.py')
        source = (run.ROOT/'run.py').read_text()
        changed = source.replace('budget = budget if budget is not None else Budget()', 'budget = Budget()')
        self.assertNotEqual(changed, source)
        exec(compile(changed, module.__file__, 'exec'), module.__dict__)
        with self.assertRaises(AssertionError):
            self.assert_original_entry_preserved(module)

    def test_expiry_during_free_prevents_job_and_process_creation(self):
        record = self.invoke({'free': lambda _: self.advance(151, wall=False)})
        self.assertEqual(record['creations'], [])
        self.assertEqual(record['opened'], [])
        self.assertEqual([p for p, _ in record['cleanup']], ['compile'])
        self.assertIn('budget exhausted', str(record['error']))

    def test_expiry_during_disk_prevents_creation(self):
        record = self.invoke({'disk': lambda _: self.advance(151, wall=False)})
        self.assertEqual(record['creations'], [])
        self.assertEqual(record['opened'], [])

    def test_expiry_during_fsync_retains_consumed_receipt_but_never_opens_job(self):
        fsync = run.os.fsync
        def slow_fsync(fd):
            fsync(fd)
            self.advance(151, wall=False)
        with patch.object(run.os, 'fsync', side_effect=slow_fsync):
            record = self.invoke()
        self.assertEqual(record['creations'], [])
        self.assertEqual(record['opened'], [])
        self.assertTrue(list(self.ledger.glob('*.json')))

    def test_expiry_during_staged_hash_after_resource_query_prevents_creation(self):
        admitting = False
        def resource_query(_):
            nonlocal admitting
            admitting = True
        original = run.digest
        def slow_hash(path):
            result = original(path)
            if admitting and 'byond' in Path(path).parts:
                self.advance(151, wall=False)
            return result
        with patch.object(run, 'digest', side_effect=slow_hash):
            record = self.invoke({'free': resource_query})
        self.assertEqual(record['creations'], [])
        self.assertEqual(record['opened'], [])

    def test_expiry_during_job_open_prevents_process_creation_and_cleans_owner(self):
        record = self.invoke({'open': lambda _: self.advance(151, wall=False)})
        self.assertEqual(record['creations'], [])
        self.assertEqual(record['opened'], ['compile'])
        self.assertEqual([p for p, _ in record['cleanup']], ['compile'])

    def test_partial_job_configuration_failure_is_registered_and_cleaned(self):
        def fail(_):
            raise ValueError('partial Job configuration failure')
        record = self.invoke({'open': fail})
        self.assertEqual(record['creations'], [])
        self.assertEqual([p for p, _ in record['cleanup']], ['compile'])
        self.assertIn('partial Job', record['receipt']['error'])

    def test_active_utc_expiry_stops_before_next_socket_or_capture(self):
        def expire(phase):
            if phase == 'client':
                self.clock.utc += 121
        record = self.invoke({'creation': expire})
        self.assertEqual(len(record['creations']), 3)
        self.assertEqual(record['capture'], 0)
        self.assertFalse(any(utc > self.packet['expires_unix'] for _, _, utc in record['sockets']))
        self.assertEqual([p for p, _ in record['cleanup']], ['client', 'server', 'compile'])

    def test_entry_budget_is_not_restarted_after_slow_initial_identity(self):
        self.packet['expires_unix'] = self.clock.utc + 250
        original = run.digest
        advanced = False
        def slow_identity(path):
            nonlocal advanced
            result = original(path)
            if Path(path) == self.manifest and not advanced:
                self.advance(50)
                advanced = True
            return result
        with patch.object(run, 'digest', side_effect=slow_identity):
            record = self.invoke()
        budget = record['context']['budget']
        self.assertEqual(budget.started_monotonic, 0)
        self.assertLessEqual(budget.full_end, 165)
        self.assertEqual(budget.work_end, 150)

    def test_missing_graphics_prerequisite_prevents_every_native_creation(self):
        def refused(_):
            raise RuntimeError('Reviewed x86 DirectX prerequisite missing')
        record = self.invoke({'graphics': refused})
        self.assertEqual(record['creations'], [])
        self.assertEqual(record['opened'], [])
        self.assertEqual(record['cleanup'], [])
        self.assertEqual(list(self.ledger.iterdir()), [])
        self.assertIn('DirectX prerequisite missing', record['receipt']['error'])

    def test_wrong_compiler_version_fails_and_still_cleans_owned_compiler(self):
        original = Path.read_text
        def wrong_banner(path, *args, **kwargs):
            text = original(path, *args, **kwargs)
            return text.replace('516.1688', '516.1681') if path.name == 'compile.stdout.log' else text
        with patch.object(Path, 'read_text', wrong_banner):
            record = self.invoke()
        self.assertEqual([phase for phase, *_ in record['creations']], ['compile'])
        self.assertEqual([phase for phase, _ in record['cleanup']], ['compile'])
        self.assertEqual(record['receipt']['error'], 'Fixture compilation failed')

    def assert_exit_roles(self, exit_phases):
        events = []
        hooks = {name: lambda phase, name=name: events.append((name, phase))
                 for name in ('identity', 'finish', 'cleanup')}
        record = self.invoke(hooks, exit_phases=exit_phases)
        message = 'Client/server exited before capture'
        self.assertIsInstance(record['error'], RuntimeError)
        self.assertEqual(str(record['error']), message)
        self.assertEqual(record['receipt']['error'], message)
        self.assertEqual(record['receipt']['result'], 'FAIL; no native acceptance')
        self.assertEqual(record['capture'], 0)
        rows = record['receipt']['pre_cleanup_exits']
        self.assertEqual([row['phase'] for row in rows], ['client', 'server'])
        first_cleanup = events.index(('cleanup', 'client'))
        for row, index in zip(rows, (2, 1)):
            phase = row['phase']
            self.assertIs(row['exited'], phase in exit_phases)
            self.assertEqual(row['exit_code'], (7 if phase == 'server' else 0)
                             if phase in exit_phases else None)
            self.assertEqual(row['identity'], dict(pid=index + 1, creation_filetime=10000 + index,
                                                   image=phase + '.exe'))
            self.assertGreaterEqual(row['observed_monotonic'], record['creations'][-1][1])
            self.assertLessEqual(row['observed_monotonic'], self.clock.mono)
            self.assertNotIn('diagnostic_errors', row)
            self.assertLess(events.index(('identity', phase)), first_cleanup)
            if phase in exit_phases:
                self.assertLess(events.index(('finish', phase)), first_cleanup)
            else:
                self.assertNotIn(('finish', phase), events)
        self.assertEqual([phase for phase, _ in record['cleanup']], ['client', 'server', 'compile'])

    def test_client_only_exit_observed_before_cleanup(self):
        self.assert_exit_roles(('client',))

    def test_server_only_exit_observed_before_cleanup(self):
        self.assert_exit_roles(('server',))

    def test_both_exits_observed_before_cleanup(self):
        self.assert_exit_roles(('client', 'server'))

    def test_exit_diagnostic_and_cleanup_errors_preserve_original_failure(self):
        def fail(phase):
            if phase == 'client':
                raise OSError('injected diagnostic/cleanup failure')
        record = self.invoke({'identity': fail, 'finish': fail, 'cleanup': fail},
                             exit_phases=('client',))
        self.assertEqual(str(record['error']), 'Client/server exited before capture')
        self.assertEqual(record['receipt']['error'], str(record['error']))
        client, server = record['receipt']['pre_cleanup_exits']
        self.assertIsNone(client['identity'])
        self.assertIsNone(client['exit_code'])
        self.assertEqual(len(client['diagnostic_errors']), 2)
        self.assertEqual(server['identity']['pid'], 2)
        self.assertEqual(len(record['receipt']['secondary_errors']), 1)
        self.assertEqual([phase for phase, _ in record['cleanup']], ['client', 'server', 'compile'])

    def test_cleanup_exception_preserves_primary_and_attempts_every_owner(self):
        def fail(phase):
            if phase == 'client':
                raise RuntimeError('secondary cleanup failure' + 'x' * 2000)
        record = self.invoke({'cleanup': fail})
        self.assertIsInstance(record['error'], ValueError)
        self.assertEqual(str(record['error']), 'primary capture failure')
        self.assertEqual([p for p, _ in record['cleanup']], ['client', 'server', 'compile'])
        self.assertEqual(len(record['receipt']['cleanup']), 3)
        self.assertFalse(record['receipt']['cleanup'][0]['all_exited'])
        self.assertEqual(record['receipt']['error'], 'primary capture failure')
        self.assertEqual(len(record['receipt']['secondary_errors'][0]['error']), 1024)

    def test_cleanup_waits_share_remaining_grant_and_reserve_receipt(self):
        def near_deadline(_):
            self.clock.mono = 117
        def slow_cleanup(_):
            self.advance(1, wall=False)
        record = self.invoke({'capture': near_deadline, 'cleanup': slow_cleanup})
        self.assertEqual([seconds for _, seconds in record['cleanup']], [2, 1, 0])
        self.assertIsInstance(record['error'], ValueError)
        self.assertEqual(record['receipt']['result'], 'FAIL; receipt finalization unconfirmed')

    def test_receipt_write_failures_do_not_replace_primary_or_skip_cleanup(self):
        original = run.terminal_receipt.atomic_write
        attempts = []
        def failed_receipt(path, *args, **kwargs):
            if path.name == 'receipt.json':
                attempts.append(path)
                raise OSError('injected diagnostic receipt write failure')
            return original(path, *args, **kwargs)
        with patch.object(run.terminal_receipt, 'atomic_write', failed_receipt):
            record = self.invoke()
        self.assertEqual(str(record['error']), 'primary capture failure')
        self.assertEqual([p for p, _ in record['cleanup']], ['client', 'server', 'compile'])
        self.assertEqual(len(attempts), 2)
        self.assertTrue(any('receipt write failure' in note for note in record['error'].__notes__))

    def test_terminal_overflow_preserves_primary_cleanup_and_core_witnesses(self):
        with patch.dict(run.VENDOR, oversized_diagnostic='x' * 65536):
            record = self.invoke()
        self.assertEqual(str(record['error']), 'primary capture failure')
        self.assertLess((self.output/'receipt.json').stat().st_size, 65536)
        self.assertEqual(record['receipt']['result'], 'FAIL; receipt finalization unconfirmed')
        self.assertFalse(record['receipt']['terminal_committed'])
        self.assertEqual(record['receipt']['error'], 'primary capture failure')
        self.assertEqual([row['phase'] for row in record['receipt']['cleanup']], ['client','server','compile'])
        self.assertTrue(all(row['all_exited'] for row in record['receipt']['cleanup']))
        for name in ('cleanup-receipt.json','source-receipt.json','capture-receipt.json'):
            self.assertTrue((self.output/name).is_file(), name)
            self.assertLess((self.output/name).stat().st_size, 65536)
        self.assertTrue(any('cap exceeded' in note for note in record['error'].__notes__))


class BudgetContracts(unittest.TestCase):
    def test_forward_utc_contraction_cannot_be_undone_by_rollback(self):
        clock = SimpleNamespace(mono=0, utc=1000)
        with patch.object(run.time, 'monotonic', side_effect=lambda: clock.mono), \
                patch.object(run.time, 'time', side_effect=lambda: clock.utc):
            budget = run.Budget()
            budget.bind(1120)
            clock.mono, clock.utc = 10, 1080
            self.assertEqual(budget.remaining(), 40)
            clock.utc = 1040
            self.assertEqual(budget.remaining(), 40)
            self.assertEqual(budget.remaining(work=True), 24)

    def test_insufficient_grant_for_cleanup_reserves_denies_work(self):
        with patch.object(run.time, 'monotonic', return_value=0), \
                patch.object(run.time, 'time', return_value=1000):
            budget = run.Budget()
            with self.assertRaisesRegex(RuntimeError, 'budget exhausted'):
                budget.bind(1016)
            self.assertEqual(budget.cleanup_wait(), 5)


class StreamingDigestContracts(unittest.TestCase):
    def test_digest_streams_bounded_reads_without_read_bytes(self):
        import guard_config
        import io
        data = bytes(range(256)) * 1025
        class BoundedReader(io.BytesIO):
            def read(self, size=-1):
                self_test.assertGreater(size, 0)
                self_test.assertLessEqual(size, 64 * 1024)
                return super().read(size)
        self_test = self
        for value in (b'', b'abc', data):
            with self.subTest(size=len(value)), \
                    patch.object(Path, 'read_bytes', side_effect=AssertionError('whole-file read forbidden')), \
                    patch.object(Path, 'open', return_value=BoundedReader(value)):
                self.assertEqual(guard_config.digest('synthetic'), hashlib.sha256(value).hexdigest())


class WindowsCreationBoundaryContracts(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('smoke_windows_boundary', run.ROOT / 'windows.py')
        self.windows = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.windows)  # constructor/native APIs are never invoked
        self.adapter = self.windows.Adapter.__new__(self.windows.Adapter)
        self.adapter.k = Mock()
        self.adapter.job = 123
        self.adapter.retained = []
        self.expired = False
        self.clock = SimpleNamespace(mono=0, utc=1000)
        self.enterContext(patch.object(run.time, 'monotonic', side_effect=lambda: self.clock.mono))
        self.enterContext(patch.object(run.time, 'time', side_effect=lambda: self.clock.utc))
        self.budget = run.Budget()

    def test_watcher_limit_reports_actual_bytes_and_preserves_threshold(self):
        cap = 128 * 1024**2
        for measured in (cap - 1, cap, cap + 1):
            with self.subTest(measured=measured), patch.object(self.adapter, 'memory', return_value=measured):
                if measured > cap:
                    with self.assertRaisesRegex(RuntimeError, f'private_bytes={measured}, cap_bytes={cap}'):
                        self.adapter.preflight({'watcher_private_bytes': cap})
                else:
                    self.adapter.preflight({'watcher_private_bytes': cap})
        self.adapter.k.CreateJobObjectW.assert_not_called()
        self.adapter.k.CreateProcessW.assert_not_called()

    def guard(self):
        if self.expired:
            self.clock.mono = 151
        self.budget.check()

    def test_actual_job_method_denies_expired_guard_before_create(self):
        self.expired = True
        with self.assertRaisesRegex(RuntimeError, 'budget exhausted'):
            self.adapter.open(creation_guard=self.guard)
        self.adapter.k.CreateJobObjectW.assert_not_called()

    def test_actual_partial_job_configuration_failure_retains_handle_for_cleanup(self):
        self.adapter.job = None
        self.adapter.k.CreateJobObjectW.return_value = 123
        self.adapter.k.SetInformationJobObject.side_effect = RuntimeError('partial configuration failed')
        with self.assertRaisesRegex(RuntimeError, 'partial configuration'):
            self.adapter.open(creation_guard=self.guard)
        self.assertEqual(self.adapter.job, 123)
        result = self.adapter.cleanup(None, 0)
        self.assertTrue(result['all_exited'])
        self.adapter.k.TerminateJobObject.assert_called_once_with(123, 1)
        self.adapter.k.CloseHandle.assert_called_once_with(123)
        self.assertIsNone(self.adapter.job)

    def launch(self, expire_at):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            def changed(*args):
                if expire_at == 'hash':
                    self.expired = True
                return 'offline-digest'
            def file_opened(*args):
                if expire_at == 'logs':
                    self.expired = True
                return 7
            def attributes_prepared(*args):
                if expire_at == 'environment':
                    self.expired = True
                return 1
            self.adapter.k.CreateFileW.side_effect = file_opened
            self.adapter.k.InitializeProcThreadAttributeList.return_value = 1
            self.adapter.k.UpdateProcThreadAttribute.side_effect = attributes_prepared
            self.adapter.k.CreateProcessW.side_effect = AssertionError('creation boundary reached')
            with patch('guard_config.digest', side_effect=changed), \
                    patch('guard_config.BINARIES', {'dreammaker.exe': 'offline-digest'}), \
                    patch.dict(self.windows.os.environ, SystemRoot='OFFLINE-NO-NATIVE'):
                self.adapter.launch(['dreammaker.exe'], root, root, 'compile', creation_guard=self.guard)

    def test_actual_launch_method_rechecks_after_hash_log_and_environment_work(self):
        for phase in ('hash', 'logs', 'environment'):
            self.expired = False
            self.clock.mono = 0
            self.budget = run.Budget()
            with self.subTest(phase=phase):
                with self.assertRaisesRegex(RuntimeError, 'budget exhausted'):
                    self.launch(phase)
                self.adapter.k.CreateProcessW.assert_not_called()
        self.assertEqual(self.adapter.k.CloseHandle.call_count, 9)

    def test_missing_actual_creation_guard_negative_control_is_detected(self):
        # Suppressing the guard reproduces the old actual-method boundary.
        self.guard = lambda: None
        with self.assertRaisesRegex(AssertionError, 'creation boundary reached'):
            self.launch('hash')


class RetainedIdentityContracts(unittest.TestCase):
    setUp = WindowsCreationBoundaryContracts.setUp
    guard = WindowsCreationBoundaryContracts.guard

    def created_child(self, fail_identity=False, wrong_image=False):
        self.folder = self.enterContext(tempfile.TemporaryDirectory())
        root = Path(self.folder).resolve()
        executable = root/'dreammaker.exe'
        self.events = []
        def created(*args):
            process = args[-1]._obj
            process.process, process.thread, process.pid = 501, 502, 503
            self.events.append('created suspended')
            return 1
        def owned(handle, job, member):
            member._obj.value = 1
            return 1
        def image(handle, flags, value, length):
            self.events.append('image captured')
            if fail_identity:
                raise OSError('injected image31')
            value.value = str(root/'unexpected.exe' if wrong_image else executable)
            return 1
        def times(handle, born, exited, kernel, user):
            born._obj.value = 123456
            kernel._obj.value = 100
            user._obj.value = 200
            return 1
        def resume(handle):
            self.events.append('resumed')
            return 1
        def exit_code(handle, code):
            code._obj.value = 0
            return 1
        self.adapter.k.CreateFileW.return_value = 7
        self.adapter.k.CreateProcessW.side_effect = created
        self.adapter.k.IsProcessInJob.side_effect = owned
        self.adapter.k.QueryFullProcessImageNameW.side_effect = image
        self.adapter.k.GetProcessTimes.side_effect = times
        self.adapter.k.ResumeThread.side_effect = resume
        self.adapter.k.GetExitCodeProcess.side_effect = exit_code
        self.adapter.k.WaitForSingleObject.return_value = 0
        self.enterContext(patch('guard_config.digest', return_value='offline-digest'))
        self.enterContext(patch('guard_config.BINARIES', {'dreammaker.exe': 'offline-digest'}))
        self.enterContext(patch.dict(self.windows.os.environ, SystemRoot='OFFLINE-NO-NATIVE'))
        return self.adapter.launch([str(executable)], root, root, 'compile', creation_guard=self.guard)

    def test_fast_exit_uses_suspended_identity_without_postexit_image_query(self):
        process = self.created_child()
        self.assertEqual(self.events, ['created suspended', 'image captured', 'resumed'])
        self.adapter.k.QueryFullProcessImageNameW.side_effect = OSError('postexit image31')
        self.assertTrue(self.adapter.exited(process))
        self.adapter.accounting = Mock(return_value=SimpleNamespace(active=0, total=1))
        result = self.adapter.finish(process)
        self.assertEqual(result['identity']['creation_filetime'], 123456)
        self.assertEqual(result['identity']['pid'], 503)
        cleanup = self.adapter.cleanup(process, 5)
        self.assertTrue(cleanup['all_exited'])
        self.assertEqual(cleanup['exits'][0]['exit_code'], 0)
        self.assertTrue(cleanup['exits'][0]['wait_signaled'])
        self.adapter.k.QueryFullProcessImageNameW.assert_called_once()

    def test_identity_capture_failure_prevents_resume_and_retains_cleanup_facts(self):
        with self.assertRaisesRegex(OSError, 'image31'):
            self.created_child(fail_identity=True)
        self.adapter.k.ResumeThread.assert_not_called()
        self.assertEqual(len(self.adapter.retained), 1)
        cleanup = self.adapter.cleanup(None, 5)
        self.assertFalse(cleanup['all_exited'])
        row = cleanup['exits'][0]
        self.assertTrue(row['wait_signaled'])
        self.assertEqual(row['exit_code'], 0)
        self.assertTrue(row['thread_handle_closed'] and row['process_handle_closed'])
        self.assertIn('identity binding', row['error'])

    def test_wrong_suspended_image_prevents_resume(self):
        with self.assertRaisesRegex(RuntimeError, 'identity differs'):
            self.created_child(wrong_image=True)
        self.adapter.k.ResumeThread.assert_not_called()
        self.assertFalse(self.adapter.cleanup(None, 5)['all_exited'])

    def test_cleanup_enrichment_error_does_not_erase_exit_facts(self):
        process = self.created_child()
        with patch.object(self.adapter, 'times', side_effect=OSError('CPU detail failed')):
            result = self.adapter.cleanup(process, 5)
        self.assertFalse(result['all_exited'])
        row = result['exits'][0]
        self.assertTrue(row['wait_signaled'] and row['exit_code_read'])
        self.assertEqual(row['exit_code'], 0)
        self.assertEqual(row['identity']['pid'], 503)
        self.assertTrue(row['thread_handle_closed'] and row['process_handle_closed'])
        self.assertIn('CPU detail failed', row['error'])

    def test_changed_handle_binding_fails_without_numeric_pid_lookup(self):
        process = self.created_child()
        process.process = 999
        with self.assertRaisesRegex(RuntimeError, 'identity binding'):
            self.adapter.identity(process)
        self.adapter.k.OpenProcess.assert_not_called()

    def test_cleanup_wait_failure_keeps_job_and_handle_close_results(self):
        process = self.created_child()
        self.adapter.k.WaitForSingleObject.return_value = 258
        result = self.adapter.cleanup(process, 0)
        self.assertFalse(result['all_exited'])
        self.assertFalse(result['exits'][0]['wait_signaled'])
        self.assertTrue(result['primitives']['terminate_job'])
        self.assertTrue(result['primitives']['close_job'])
        self.assertTrue(result['exits'][0]['process_handle_closed'])

    def test_unretained_cached_identity_is_rejected(self):
        process = self.created_child()
        self.adapter.retained = []
        with self.assertRaisesRegex(RuntimeError, 'identity binding'):
            self.adapter.identity(process)


class WorkflowSelectionContracts(unittest.TestCase):
    # Evaluate this workflow's deliberately narrow conjunction, not general YAML
    # or the GitHub expression language. Actual Actions parsing remains CI evidence.
    FULL_PR_PATHS = [
        '.github/workflows/dreamseeker-smoke.yml',
        *('tests/dreamseeker_smoke/' + name for name in
          ('README.md', 'fixture.dm', 'fixture.dme', 'fixture.dmf', 'guard_config.py',
           'run.py', 'test_smoke.py', 'vendor.json', 'windows.py'))]
    SHA = 'a' * 40

    def setUp(self):
        self.workflow = (run.ROOT.parents[1] / '.github/workflows/dreamseeker-smoke.yml').read_text()

    def job(self, name):
        jobs = self.workflow.split('\njobs:\n', 1)[1]
        blocks = dict(re.findall(r'^  ([a-z-]+):\n(.*?)(?=^  [a-z-]+:\n|\Z)',
                                 jobs, re.MULTILINE | re.DOTALL))
        self.assertEqual(set(blocks), {'offline-contracts', 'guest-renderer'})
        return blocks[name]

    def selected(self, event, paths, enabled=False, selected_sha='', head=SHA):
        triggers = self.workflow.split('\npermissions:\n', 1)[0]
        selectors = re.findall(r'^      - (.+)$', triggers, re.MULTILINE)
        self.assertEqual(selectors, ['tests/dreamseeker_smoke/**', '.github/workflows/dreamseeker-smoke.yml'])
        triggered = event == 'workflow_dispatch' or (event == 'pull_request' and
                    any(fnmatch.fnmatchcase(path, pattern) for path in paths for pattern in selectors))
        if not triggered:
            return set()
        block = self.job('guest-renderer')
        conditions = re.findall(r'^    if: \$\{\{ (.+) \}\}$', block, re.MULTILINE)
        self.assertLessEqual(len(conditions), 1)
        context = {'github.event_name': event, 'inputs.run_native': enabled,
                   'inputs.selected_sha': selected_sha, 'github.sha': head}

        def value(token):
            if token in context:
                return context[token]
            if token == 'true':
                return True
            self.assertRegex(token, r"^'[a-z_]+'$")
            return token[1:-1]

        allowed = True  # GitHub jobs lacking an if are selected by default.
        if conditions:
            for clause in conditions[0].split(' && '):
                sides = clause.split(' == ')
                self.assertEqual(len(sides), 2, 'unsupported guard expression')
                allowed = allowed and value(sides[0]) == value(sides[1])
        return {'offline-contracts', 'guest-renderer'} if allowed else {'offline-contracts'}

    def assert_full_pr_never_selects_native(self):
        self.assertEqual(self.selected('pull_request', self.FULL_PR_PATHS, True, self.SHA),
                         {'offline-contracts'})

    def test_full_pr_three_dot_not_last_push_controls_selection(self):
        # A late docs-only push does not remove earlier smoke/workflow changes
        # from the actual full PR 3dot path set frozen in the review packet.
        self.assertEqual(self.selected('pull_request', ['docs/unrelated.md']), set())
        self.assert_full_pr_never_selects_native()
        for path in self.FULL_PR_PATHS:
            self.assertEqual(self.selected('pull_request', [path]), {'offline-contracts'})

    def test_native_requires_dispatch_opt_in_and_exact_selected_sha(self):
        self.assertIn('      run_native:\n', self.workflow)
        input_block = self.workflow.split('      run_native:\n', 1)[1].split('      selected_sha:', 1)[0]
        self.assertIn('        type: boolean\n', input_block)
        self.assertIn('        default: false\n', input_block)
        for enabled, sha in ((False, ''), (False, self.SHA), (True, ''), (True, 'b' * 40)):
            self.assertEqual(self.selected('workflow_dispatch', [], enabled, sha), {'offline-contracts'})
        self.assertEqual(self.selected('workflow_dispatch', [], True, self.SHA),
                         {'offline-contracts', 'guest-renderer'})
        self.assertEqual(self.selected('pull_request_target', self.FULL_PR_PATHS, True, self.SHA), set())

    def test_source_job_has_no_native_step_and_native_needs_offline(self):
        offline = self.job('offline-contracts')
        native = self.job('guest-renderer')
        self.assertIn('    runs-on: windows-2022\n', offline)
        self.assertIn('python -m unittest discover -s tests/dreamseeker_smoke', offline)
        self.assertNotIn('run.py --output', offline)
        self.assertNotIn('workflow_dispatch', offline)
        self.assertIn('    needs: offline-contracts\n', native)
        self.assertIn('run.py --output', native)
        self.assertIn('    runs-on: windows-2022\n', native)

    def test_removed_native_guard_negative_control_is_detected(self):
        self.workflow = re.sub(r'^    if: \$\{\{ .+ \}\}\n', '', self.workflow, flags=re.MULTILINE)
        with self.assertRaises(AssertionError):
            self.assert_full_pr_never_selects_native()

    def test_missing_event_guard_negative_control_is_detected(self):
        self.workflow = self.workflow.replace("github.event_name == 'workflow_dispatch' && ", '')
        with self.assertRaises(AssertionError):
            self.assert_full_pr_never_selects_native()


if __name__ == '__main__':
    unittest.main()
