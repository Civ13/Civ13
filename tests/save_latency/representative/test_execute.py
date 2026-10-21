"""Actual executor sequencing with exclusively injected effects and temp files."""
from copy import deepcopy
from datetime import datetime, timezone
import hashlib
import io
import json
from pathlib import Path
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from urllib.parse import parse_qs
import zipfile

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import execute
import files
import helpers
import source
import test_offline as offline
from test_offline import status


class FakeProcess:
    pid = 600
    def __init__(self, stubborn=False, fail_cleanup=False):
        self.alive, self.stubborn, self.fail_cleanup = True, stubborn, fail_cleanup
        self.events = []
    def poll(self):
        return None if self.alive else 0
    def terminate(self):
        self.events.append('terminate')
        if self.fail_cleanup:
            raise OSError('injected cleanup failure')
        if not self.stubborn:
            self.alive = False
    def wait(self, timeout):
        self.events.append(('wait', timeout))
        if self.alive:
            raise subprocess.TimeoutExpired('owned fake', timeout)
        return 0
    def kill(self):
        self.events.append('kill')
        self.alive = False


def allocation(root):
    tools = root / 'tools'
    tools.mkdir()
    for name in ('dm.exe', 'dd.exe'):
        (tools / name).write_bytes(('nonexecutable fake ' + name).encode())
    return {'schema': 1, 'authorized': True, 'allocation_id': 'offline injection only',
            'expires_utc': '2026-10-22T12:00:00Z', 'commits': [source.REFERENCE, source.CANDIDATE],
            'output': str(root / 'run'), 'port': 18563, 'setup_seconds': 600,
            'core_seconds': execute.CORE_SECONDS, 'minimum_free_bytes': 1,
            'maximum_output_bytes': 1000000000, 'maximum_private_bytes': 1000000000,
            'sampler_cadence_seconds': .1, 'query_timeout_seconds': 1,
            'resource_cadence_seconds': 10, 'no_save_seconds': 1,
            'listener_addresses': ['127.0.0.1'], 'byond_bin': str(tools),
            'toolchain_sha256': {name: files.file_sha(tools / name) for name in ('dm.exe', 'dd.exe')}}


class FakeHost:
    def __init__(self, game, commit, session, role):
        self.game, self.commit, self.session, self.role = game, commit, session, role
        self.phase, self.marker = 'idle', 0
        self.identity = None
        if (game / 'map_saves/restart_intent.json').exists():
            self.identity = json.loads((game / 'map_saves/restart_intent.json').read_text())
            (game / 'map_saves/restart_intent.json').unlink()
            self.marker = json.loads((game / 'map_saves/1.sav').read_text())['marker']
        self.imported = self.identity is not None
    def status(self):
        result = status(self.phase, self.marker, self.identity['generation'] if self.identity else '', self.session)
        result['source'] = self.commit
        result['import_complete'] = int(self.imported)
        result.update(season='SPRING', time_of_day='DAY', research_clock=1)
        result['representative']['receipt']['identity'] = self.identity
        return result
    def query(self, action, session):
        if session != self.session:
            raise ValueError('stale fake boot')
        if action == 'start':
            (self.game / 'full-map-fixture.json').write_text('{"crate":"actual crate"}')
            return self.status()
        if action == 'census':
            (self.game / 'representative-census.json').write_text(json.dumps({'source': self.commit, 'session': self.session, 'counts': {'/obj/test/public': 1}, 'total': 1, 'maxx': 375, 'maxy': 447, 'maxz': 2}))
            self.phase = 'census_complete'
            return self.status()
        if action not in ('first', 'second'):
            raise AssertionError('unsupported fake action')
        directory = self.game / 'map_saves'
        if action == 'first' and (directory / 'save_complete.txt').exists():
            raise AssertionError('common seed was not retained outside empty first output')
        if action == 'second':
            shutil.copytree(directory, self.game / 'map_backups')
        directory.mkdir(exist_ok=True)
        self.marker = (0 if self.role == 'seed' else 1) if action == 'first' else 2
        self.identity = {'version': 1, 'generation': 'round-v2:' + hashlib.md5((self.session+action).encode()).hexdigest()}
        (directory / 'map.txt').write_text('PUBLIC EUROPE\n')
        (directory / 'round.json').write_text(json.dumps({'generation': self.identity['generation'],
                                                       'world_state': {'environment': {'season': 'SPRING', 'time_of_day': 'DAY', 'research_clock': 1}}}))
        (directory / 'save_complete.txt').write_text(self.identity['generation'] + '\n')
        (directory / '1.sav').write_text(json.dumps({'marker': self.marker}))
        for key, name in (('metadata', 'map.txt'), ('round', 'round.json')):
            self.identity[key] = hashlib.md5((directory / name).read_bytes().replace(b'\r\n', b'\n')).hexdigest()
        self.phase = action + '_complete'
        return self.status()
    def until(self, predicate):
        current = self.status()
        if not predicate(current):
            raise AssertionError('fake predicate not reached; no fabricated wait success')
        return current
    def poll(self, phase, session, deadline):
        if phase != self.phase or session != self.session:
            raise AssertionError('fake phase mismatch')
        return self.status()
    def baseline(self):
        pass


class FakeEffects:
    def __init__(self, cache, timeout_role=None, stale_reader=False, wrong_generation=False):
        self.cache, self.timeout_role, self.stale_reader = cache, timeout_role, stale_reader
        self.calls, self.active, self.now = [], False, 0
        self.wrong_generation = wrong_generation
    def clock(self):
        return self.now
    def utcnow(self):
        return datetime(2026, 10, 21, 12, tzinfo=timezone.utc)
    def source(self, repository, commit, path):
        return self.cache[(commit, path)]
    def free_bytes(self, parent):
        return 10000000000
    def available(self, port):
        self.calls.append(('allocated_port_only', port))
    def export(self, repository, commit, destination, deadline, maximum_bytes):
        game = destination / 'game'
        game.mkdir(parents=True)
        for (current, name), data in self.cache.items():
            if current == commit:
                path = game / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
        (game / 'config').mkdir(exist_ok=True)
        (game / 'config/config.txt').write_text('HUB forbidden\nWEBHOOK_KEY forbidden\n#public\n')
        self.calls.append(('export', commit))
        return game
    def run(self, command, cwd, timeout):
        self.calls.append(('compile', str(cwd)))
        for suffix in ('dmb', 'rsc'):
            (cwd / ('representative.' + suffix)).write_bytes(('fake ' + str(cwd) + suffix).encode())
        return b'516.1681\n0 errors, 0 warnings\n'
    def phase(self, game, commit, packet, helper_data, deadline, body, role):
        if self.active:
            raise AssertionError('overlapping fake daemons')
        self.active = True
        number = len([call for call in self.calls if call[0] == 'phase']) + 1
        session = 'boot-' + str(number)
        owned = {'pid': 600+number, 'started_utc': session, 'binary_sha256': files.file_sha(game / 'representative.dmb')}
        host = FakeHost(game, commit, session, role)
        host.deadline = deadline
        self.calls.append(('phase', role, commit, owned))
        try:
            if self.timeout_role == role:
                raise TimeoutError('injected incomplete phase')
            if self.stale_reader and role == 'reader':
                host.session = 'boot-2'
            if self.wrong_generation and role == 'reader':
                host.identity['generation'] = 'round-v2:' + 'f'*32
            return body(host, host.status(), owned)
        finally:
            self.active = False
            execute.write(game / 'exit.json', {'pid': owned['pid'], 'owned_exit': True, 'injected': True})


class ExecutorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        offline.SourceTests.setUpClass()
        cls.cache = offline.SourceTests.cache
        cls.repo = offline.SourceTests.repo

    def setUp(self):
        self.enterContext(patch.object(subprocess, 'Popen', side_effect=AssertionError('native process forbidden')))
        self.enterContext(patch.object(socket, 'socket', side_effect=AssertionError('socket forbidden')))

    def test_actual_executor_all_seven_owned_phases_without_native_effects(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            packet = allocation(root)
            effect = FakeEffects(self.cache)
            with patch.object(subprocess, 'Popen', side_effect=AssertionError('native process forbidden')), patch.object(socket, 'socket', side_effect=AssertionError('socket forbidden')):
                result = execute.execute(self.repo, packet, effect)
            phases = [item for item in effect.calls if item[0] == 'phase']
            self.assertEqual([item[1] for item in phases], ['seed', 'writer', 'reader', 'reader', 'writer', 'reader', 'reader'])
            self.assertEqual(len({item[3]['pid'] for item in phases}), 7)
            self.assertFalse(result['correctness_phases_completed'])
            self.assertFalse(result['representative_acceptance'])
            self.assertEqual(result['execution_mode'], 'injected')
            output = Path(packet['output'])
            self.assertTrue((output / 'seed-generation/1.sav').exists())
            self.assertTrue((output / 'A-writer/imported-seed/1.sav').exists())
            self.assertTrue((output / 'B-writer/imported-seed/1.sav').exists())
            self.assertNotEqual(result['binaries']['A'], result['binaries']['B'])
            self.assertEqual(files.inventory(output / 'seed-generation'), json.loads((output / 'seed-receipt.json').read_text())['files_sha256'])
            for label in ('A', 'B'):
                config = (output / label / 'game/config/config.txt').read_text()
                self.assertNotIn('forbidden', config)

    def test_expired_phase_and_slow_admission_do_not_launch(self):
        with tempfile.TemporaryDirectory() as temporary:
            game = Path(temporary)
            calls = []
            effect = SimpleNamespace(clock=lambda: 10, launch=lambda *args: calls.append('launch'))
            for deadline in (9, 160):
                with self.assertRaises(TimeoutError):
                    execute.run_phase(effect, game, source.CANDIDATE, {}, {}, deadline, lambda *args: None, 'writer')
            self.assertEqual(calls, [])
            now = [0]
            effect.clock = lambda: now[0]
            def slow_admit():
                now[0] = 31
            with self.assertRaises(TimeoutError):
                with execute.owned_process(effect, ['inert'], game, deadline=60, admit=slow_admit):
                    self.fail('expired admission reached body')
            self.assertEqual(calls, [])

    def test_cleanup_waits_consume_only_remaining_shared_budget(self):
        with tempfile.TemporaryDirectory() as temporary:
            now, waits = [0], []
            process = FakeProcess(stubborn=True)
            def terminate():
                now[0] = 95
            def wait(timeout):
                waits.append(timeout)
                if process.alive:
                    now[0] = 100
                    raise subprocess.TimeoutExpired('injected', timeout)
                return 0
            process.terminate, process.wait = terminate, wait
            effect = SimpleNamespace(clock=lambda: now[0], launch=lambda *args: process)
            with execute.owned_process(effect, ['inert'], Path(temporary), deadline=100):
                pass
            self.assertEqual(waits, [5, 0])
            self.assertFalse(process.alive)

    def test_utc_expiry_at_export_prepare_create_and_final_write_refuses(self):
        class WallEffects(FakeEffects):
            wall = datetime(2026, 10, 21, 12, tzinfo=timezone.utc)
            def utcnow(self):
                return self.wall
            def expire(self):
                self.wall = datetime(2026, 10, 23, 12, tzinfo=timezone.utc)
        for boundary in ('export', 'prepare', 'create', 'final'):
            with self.subTest(boundary=boundary), tempfile.TemporaryDirectory() as temporary:
                packet = allocation(Path(temporary))
                effect = WallEffects(self.cache)
                original_export, original_prepare = effect.export, source.prepare
                original_mkdir, original_write = Path.mkdir, execute.write
                def export(*args):
                    value = original_export(*args)
                    if boundary == 'export':
                        effect.expire()
                    return value
                def prepare(*args, **kwargs):
                    value = original_prepare(*args, **kwargs)
                    if boundary == 'prepare':
                        effect.expire()
                    return value
                def mkdir(path, *args, **kwargs):
                    value = original_mkdir(path, *args, **kwargs)
                    if boundary == 'create' and path == Path(packet['output']):
                        effect.expire()
                    return value
                def write(path, value):
                    original_write(path, value)
                    if boundary == 'final' and path.name == 'result.json':
                        effect.expire()
                effect.export = export
                with patch.object(source, 'prepare', side_effect=prepare), patch.object(Path, 'mkdir', mkdir), patch.object(execute, 'write', side_effect=write):
                    with self.assertRaises(TimeoutError):
                        execute.execute(self.repo, packet, effect)
                output = Path(packet['output'])
                self.assertTrue(json.loads((output / 'failure.json').read_text())['preserve'])
                phases = [call for call in effect.calls if call[0] == 'phase']
                self.assertEqual(len(phases), 7 if boundary == 'final' else 0)
                if boundary == 'final':
                    self.assertFalse(json.loads((output / 'result.json').read_text())['envelope_valid'])
                else:
                    self.assertFalse(any(call[0] == 'compile' for call in effect.calls))

    def test_clock_jumps_cannot_extend_frozen_budget(self):
        with tempfile.TemporaryDirectory() as temporary:
            packet = allocation(Path(temporary))
            effect = FakeEffects(self.cache)
            wall = [effect.utcnow()]
            effect.utcnow = lambda: wall[0]
            bounded = execute.AllocatedEffects(effect, packet, effect.clock(), wall[0])
            deadline = bounded.deadline
            wall[0] += execute.timedelta(seconds=31)
            self.assertEqual(bounded.clock(), 31)
            wall[0] -= execute.timedelta(seconds=40)
            effect.now = -1
            self.assertEqual(bounded.clock(), 31)
            self.assertEqual(bounded.deadline, deadline)

    def test_post_seed_artifact_tool_config_and_coherent_manifest_mutations_refuse(self):
        for changed in ('dmb', 'rsc', 'dm.exe', 'dd.exe', 'config/config.txt',
                        'config/full-map-probe-token.txt', 'representative/probe.dm', 'coherent'):
            with self.subTest(changed=changed), tempfile.TemporaryDirectory() as temporary:
                class Mutated(FakeEffects):
                    def phase(self, game, commit, packet, helper, deadline, body, role):
                        value = super().phase(game, commit, packet, helper, deadline, body, role)
                        if role == 'seed':
                            for label in ('A', 'B'):
                                template = Path(packet['output']) / label / 'game'
                                names = ('representative.dmb', 'representative.rsc') if changed == 'coherent' else (
                                    'representative.'+changed if changed in ('dmb', 'rsc') else changed,)
                                for name in names:
                                    path = Path(packet['byond_bin']) / name if name.endswith('.exe') else template / name
                                    path.write_bytes(path.read_bytes()+b' injected coherent change')
                                (Path(packet['output']) / (label+'-manifest.json')).write_text(json.dumps(
                                    {'rewritten_expected_hashes': {name: files.file_sha(template/name) for name in names
                                                                  if not name.endswith('.exe')}}))
                            if changed == 'coherent':
                                path = Path(packet['byond_bin']) / 'dd.exe'
                                path.write_bytes(path.read_bytes()+b' changed daemon')
                        return value
                packet = allocation(Path(temporary))
                effect = Mutated(self.cache)
                with self.assertRaisesRegex(ValueError, 'Independent input seal'):
                    execute.execute(self.repo, packet, effect)
                self.assertEqual(len([call for call in effect.calls if call[0] == 'phase']), 1)
                self.assertTrue((Path(packet['output']) / 'seed-generation/1.sav').is_file())
                self.assertFalse((Path(packet['output']) / 'result.json').exists())

    def test_slow_or_mutated_copy_never_starts_next_phase(self):
        for change in ('expired', 'artifact'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as temporary:
                packet = allocation(Path(temporary))
                effect = FakeEffects(self.cache)
                original = execute.copy_tree
                def copy(*args):
                    original(*args)
                    if change == 'expired':
                        effect.now = packet['setup_seconds']+execute.CORE_SECONDS+1
                    else:
                        path = args[1] / 'representative.rsc'
                        path.write_bytes(path.read_bytes()+b' changed during copy')
                with patch.object(execute, 'copy_tree', side_effect=copy):
                    with self.assertRaises((TimeoutError, ValueError)):
                        execute.execute(self.repo, packet, effect)
                self.assertFalse(any(call[0] == 'phase' for call in effect.calls))
                self.assertTrue((Path(packet['output']) / 'seed/game/representative.dmb').exists())

    def test_timeout_preserves_seed_and_all_partial_outputs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            packet = allocation(root)
            effect = FakeEffects(self.cache, timeout_role='reader')
            with self.assertRaises(TimeoutError):
                execute.execute(self.repo, packet, effect)
            output = Path(packet['output'])
            self.assertTrue((output / 'seed-generation/1.sav').exists())
            self.assertTrue((output / 'A-active/1.sav').exists())
            self.assertTrue(json.loads((output / 'failure.json').read_text())['preserve'])
            self.assertFalse(effect.active)
            self.assertFalse((output / 'result.json').exists())

    def test_actual_compile_failure_retains_both_streams_and_partial_outputs(self):
        class FailedCompiler(FakeEffects):
            def run(self, command, cwd, timeout):
                (cwd / 'representative.dmb').write_bytes(b'partial compiler output')
                return execute.SystemEffects.run(command, cwd, timeout)
        with tempfile.TemporaryDirectory() as temporary:
            packet = allocation(Path(temporary))
            effect = FailedCompiler(self.cache)
            failed = subprocess.CompletedProcess(['injected compiler'], 7,
                                                  stdout=b'compiler stdout\n', stderr=b'compiler stderr\n')
            with patch.object(subprocess, 'run', return_value=failed) as run, patch.object(subprocess, 'Popen', side_effect=AssertionError('native process forbidden')), patch.object(socket, 'socket', side_effect=AssertionError('socket forbidden')):
                with self.assertRaises(subprocess.CalledProcessError) as raised:
                    execute.execute(self.repo, packet, effect)
            self.assertEqual(raised.exception.returncode, 7)
            self.assertEqual(raised.exception.output, failed.stdout)
            self.assertEqual(raised.exception.stderr, failed.stderr)
            output = Path(packet['output'])
            self.assertEqual((output / 'A/game/compile.log').read_bytes(), failed.stdout + failed.stderr)
            self.assertEqual((output / 'A/game/representative.dmb').read_bytes(), b'partial compiler output')
            self.assertTrue((output / 'B/game/representative.dme').is_file())
            self.assertTrue(json.loads((output / 'failure.json').read_text())['preserve'])
            self.assertFalse((output / 'result.json').exists())
            self.assertFalse(any(call[0] == 'phase' for call in effect.calls))
            self.assertTrue(run.call_args.kwargs['capture_output'])

    def test_actual_run_phase_admission_transport_body_owned_exit_and_diagnostics(self):
        helper_data = {name: self.cache[(source.HELPERS, 'tests/world_save/full_map_lifecycle/' + name)]
                       for name in ('query.py', 'run.py')}
        for refusal in (None, 'listener', 'token', 'session', 'diagnostic', 'exitartifact'):
            with self.subTest(refusal=refusal), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                packet = allocation(root)
                game = Path(packet['output']) / 'phase/game'
                (game / 'config').mkdir(parents=True)
                (game / 'config/full-map-probe-token.txt').write_text('f'*64)
                (game / 'representative.dmb').write_bytes(b'nonexecutable owned binary')
                expected = execute.MappingProxyType({name: files.file_sha(game / name) for name in
                    ('representative.dmb', 'config/full-map-probe-token.txt')})
                process, calls = FakeProcess(), []
                sampled, body_done = threading.Event(), threading.Event()
                state = {'phase': 'idle'}

                class Wire:
                    def settimeout(self, seconds):
                        self.timeout = seconds
                    def close(self):
                        calls.append('connection_closed')
                    def sendall(self, data):
                        request = {key: value[0] for key, value in parse_qs(data[9:-1].decode('ascii')).items()}
                        calls.append(request)
                        invalid_token = request['token'] != 'f'*64
                        stale_session = request['action'] != 'status' and request['session'] != 'writer'
                        if (invalid_token and refusal != 'token') or (stale_session and refusal != 'session'):
                            text = 'rejected'
                        else:
                            if request['action'] == 'first' and not stale_session:
                                state['phase'] = 'first_complete'
                            result = status(state['phase'])
                            result['world_time'] = 10
                            text = json.dumps(result)
                        body = b'\x06' + text.encode() + b'\0'
                        self.remaining = b'\0\x83' + struct.pack('>H', len(body)) + body
                    def recv(self, count):
                        data, self.remaining = self.remaining[:count], self.remaining[count:]
                        return data

                class NativeBoundary:
                    clock = staticmethod(time.monotonic)
                    sleep = staticmethod(time.sleep)
                    def launch(self, command, cwd, stdout, stderr):
                        calls.append(('launch', command, cwd))
                        if refusal == 'diagnostic':
                            stdout.write(b'runtime error: injected strict failure\n')
                        return process
                    def listener(self, port, pid, selected):
                        calls.append(('listener', port, pid))
                        return {'owners': [pid+1 if refusal == 'listener' else pid],
                                'addresses': ['127.0.0.1'], 'process_start_utc': 'created'}
                    def connect(self, address, timeout):
                        if address != ('127.0.0.1', packet['port']):
                            raise AssertionError('unallocated connection')
                        return Wire()
                    def resources(self, pid):
                        calls.append(('resources', pid))
                        return {'started_utc': 'created', 'private_bytes': 1,
                                'working_bytes': 1, 'cpu_seconds': 0}

                def sample(request, clock, wait, **kwargs):
                    observed = request(1)
                    row = dict(observed, latency_seconds=.01)
                    kwargs['record'](row)
                    sampled.set()
                    if not body_done.wait(2):
                        raise AssertionError('injected body failed to finish')
                    return [row]

                def body(host, initial, owned):
                    calls.append('body')
                    try:
                        self.assertTrue(sampled.wait(2), 'actual observer did not query transport')
                        self.assertEqual(owned['pid'], process.pid)
                        host.query('first', initial['session'])
                        result = host.poll('first_complete', initial['session'], host.deadline)
                        if refusal == 'exitartifact':
                            (game / 'representative.dmb').write_bytes(b'changed while owned process ran')
                        return result
                    finally:
                        body_done.set()

                with patch.object(execute.sampler, 'sample', side_effect=sample), patch.object(subprocess, 'Popen', side_effect=AssertionError('native process forbidden')), patch.object(socket, 'socket', side_effect=AssertionError('socket forbidden')):
                    if refusal:
                        message = {'listener': 'Listener ownership', 'token': 'refusal control',
                                   'session': 'refusal control', 'diagnostic': 'Strict native diagnostics',
                                   'exitartifact': 'Independent input seal'}[refusal]
                        with self.assertRaisesRegex((ValueError, RuntimeError), message):
                            execute.run_phase(NativeBoundary(), game, source.CANDIDATE, packet,
                                              helper_data, time.monotonic()+1000, body, 'writer', expected)
                    else:
                        result = execute.run_phase(NativeBoundary(), game, source.CANDIDATE, packet,
                                                   helper_data, time.monotonic()+1000, body, 'writer', expected)
                        self.assertEqual(result['representative']['phase'], 'first_complete')
                self.assertTrue(json.loads((game / 'exit.json').read_text())['owned_exit'])
                self.assertEqual(process.events[0], 'terminate')
                self.assertFalse(process.alive)
                launch = next(call for call in calls if isinstance(call, tuple) and call[0] == 'launch')
                self.assertEqual(launch[1][launch[1].index('-ip')+1], '127.0.0.1')
                self.assertEqual(calls.count('body'), int(refusal in (None, 'diagnostic', 'exitartifact')))
                if refusal in (None, 'diagnostic', 'exitartifact'):
                    requests = [call for call in calls if isinstance(call, dict)]
                    self.assertTrue(any(call['token'] == '0'*64 for call in requests))
                    self.assertTrue(any(call['session'] == 'stale-session' for call in requests))
                    self.assertTrue((game / 'latency.jsonl').is_file())
                    self.assertTrue((game / 'resources.jsonl').is_file())
                    self.assertTrue((game / 'first_complete-receipt.json').is_file())
                if refusal == 'diagnostic':
                    self.assertIn('injected strict failure', (game / 'diagnostics.json').read_text())

    def test_stale_boot_reader_rejects_instead_of_claiming_import(self):
        with tempfile.TemporaryDirectory() as temporary:
            packet = allocation(Path(temporary))
            with self.assertRaisesRegex(ValueError, 'writer boot'):
                execute.execute(self.repo, packet, FakeEffects(self.cache, stale_reader=True))
            self.assertFalse((Path(packet['output']) / 'result.json').exists())

    def test_wrong_native_reader_generation_refuses_with_seed_preserved(self):
        with tempfile.TemporaryDirectory() as temporary:
            packet = allocation(Path(temporary))
            with self.assertRaisesRegex(ValueError, 'completed import'):
                execute.execute(self.repo, packet, FakeEffects(self.cache, wrong_generation=True))
            self.assertTrue((Path(packet['output']) / 'seed-generation/1.sav').exists())
            self.assertFalse((Path(packet['output']) / 'result.json').exists())

    def test_allocation_expiry_relative_existing_and_protected_port(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            packet = allocation(root)
            now = FakeEffects(self.cache).utcnow()
            for change in ({'expires_utc': '2026-10-21T12:01:00Z'}, {'output': 'relative'},
                           {'output': str(root)}, {'port': 1714}, {'authorized': False},
                           {'listener_addresses': ['0.0.0.0']}, {'toolchain_sha256': {}},
                           {'commits': [source.CANDIDATE, source.REFERENCE]}):
                with self.assertRaises(ValueError):
                    execute.resource_packet(dict(packet, **change), now)
            self.assertFalse(Path(packet['output']).exists())

    def test_default_cli_does_not_even_inspect_resources(self):
        with patch.object(execute, 'execute', side_effect=AssertionError('execution forbidden')), patch.object(socket, 'socket', side_effect=AssertionError('socket forbidden')), patch('sys.stdout', new_callable=io.StringIO) as out:
            execute.main([])
        self.assertTrue(json.loads(out.getvalue())['plan_only'])

    def test_owned_timeout_escalates_only_the_returned_handle(self):
        for fail_cleanup in (False, True):
            with tempfile.TemporaryDirectory() as temporary:
                game = Path(temporary)
                process = FakeProcess(stubborn=True, fail_cleanup=fail_cleanup)
                class Owner:
                    def launch(self, *args):
                        return process
                with self.assertRaises((TimeoutError, OSError)):
                    with execute.owned_process(Owner(), ['fake owned'], game):
                        raise TimeoutError('injected writer timeout')
                report = json.loads((game / 'exit.json').read_text())
                self.assertEqual(report['owned_exit'], not fail_cleanup)
                self.assertEqual(process.events[0], 'terminate')
                if not fail_cleanup:
                    self.assertIn('kill', process.events)

    def test_export_rejects_traversal_before_any_source_file(self):
        with tempfile.TemporaryDirectory() as temporary:
            class ArchiveEffect:
                clock = staticmethod(lambda: 0)
                def run(self, command, cwd, timeout):
                    archive = Path(next(item.split('=', 1)[1] for item in command if item.startswith('--output=')))
                    with zipfile.ZipFile(archive, 'w') as zipped:
                        zipped.writestr('../escape.txt', 'must not escape')
            root = Path(temporary)
            with self.assertRaisesRegex(ValueError, 'Unsafe'):
                execute.export(self.repo, source.CANDIDATE, root / 'packet', ArchiveEffect(), 10, 100000)
            self.assertFalse((root / 'escape.txt').exists())
            self.assertTrue((root / 'packet/source.zip').exists())

    def test_actual_archive_overlay_keeps_serializer_and_rejects_changed_input(self):
        outer = self
        class ArchiveEffect:
            clock = staticmethod(lambda: 0)
            def run(self, command, cwd, timeout):
                archive = Path(next(item.split('=', 1)[1] for item in command if item.startswith('--output=')))
                commit = command[-1]
                with zipfile.ZipFile(archive, 'w') as zipped:
                    for (current, name), data in outer.cache.items():
                        if current == commit:
                            zipped.writestr(name, data)
                    zipped.writestr('config/config.txt', 'HUB excluded\n#public\n')
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            game = execute.export(self.repo, source.CANDIDATE, root / 'export', ArchiveEffect(), 10, 1000000000)
            packet = source.prepare(self.repo, source.CANDIDATE, root / 'overlay',
                                    lambda repo, commit, path: self.cache[(commit, path)])
            token = execute.overlay(game, root / 'overlay', packet)
            self.assertEqual(len(token), 64)
            self.assertEqual(packet['isolated_config_sha256'], files.file_sha(game / 'config/config.txt'))
            for path in source.PRODUCTION:
                self.assertEqual((game / path).read_bytes(), self.cache[(source.CANDIDATE, path)])
            with self.assertRaises(ValueError):
                execute.copy_tree(game, game / 'recurse', lambda: 0, 1)
            self.assertFalse((game / 'recurse').exists())
            (game / source.PRODUCTION[0]).write_bytes(b'changed serializer')
            with self.assertRaisesRegex(ValueError, 'Archive source differs'):
                execute.overlay(game, root / 'overlay', packet)

    def test_resource_control_rejects_stale_pid_and_unavailable_or_exceeded_metric(self):
        owned = {'started_utc': 'current'}
        packet = {'maximum_private_bytes': 100, 'maximum_output_bytes': 100}
        valid = {'started_utc': 'current', 'private_bytes': 10, 'working_bytes': 10, 'cpu_seconds': 1, 'output_bytes': 10}
        execute.validate_resource(valid, owned, packet)
        for change in ({'started_utc': 'replaced'}, {'private_bytes': 101}, {'cpu_seconds': None}, {'output_bytes': 101}):
            with self.assertRaises((ValueError, RuntimeError)):
                execute.validate_resource(dict(valid, **change), owned, packet)

    def test_frozen_transport_uses_total_deadline_including_fragmented_read(self):
        query_source = self.cache[(source.HELPERS, 'tests/world_save/full_map_lifecycle/query.py')]
        body = b'\x06' + json.dumps({'source': source.CANDIDATE}).encode() + b'\0'
        wire = b'\0\x83' + struct.pack('>H', len(body)) + body
        class Connection:
            def __init__(self):
                self.position, self.now, self.closed = 0, 0., False
            def close(self):
                self.closed = True
            def settimeout(self, seconds):
                self.timeout = seconds
            def sendall(self, data):
                self.now += .01
            def recv(self, count):
                self.now += .06
                result = wire[self.position:self.position+1]
                self.position += len(result)
                return result
        connection = Connection()
        with self.assertRaises(TimeoutError):
            helpers.query(query_source, lambda *args: connection, lambda: connection.now, 18563, 'f'*64, 'status', 'observe', .1)
        self.assertTrue(connection.closed)


if __name__ == '__main__':
    unittest.main()
