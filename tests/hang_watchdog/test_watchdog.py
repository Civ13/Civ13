"""Offline proc/output fixtures; Linux controls launch only temporary test observers.

Windows bypasses flock acquisition in portable fixtures. Actual locking, copied
CLI execution and killed-observer recovery are verified only on Linux.
"""
import ast
from dataclasses import replace
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'scripts/hang-watchdog/watchdog.py'
spec = importlib.util.spec_from_file_location('hang_watchdog', SOURCE)
w = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = w
spec.loader.exec_module(w)


def imported_modules(source):
    modules = set()
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, ast.Import):
            modules.update(alias.name.split('.')[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            modules.add(node.module.split('.')[0])
    return modules


def proc_line(pid=321, start=98765):
    fields = ['0'] * 40
    fields[0], fields[11], fields[12], fields[19] = 'S', '10', '2', str(start)
    return f'{pid} (DreamDaemon) ' + ' '.join(fields)


class Fixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='civ13-watchdog-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.assertTrue(self.root.is_relative_to(Path(tempfile.gettempdir()).resolve()))
        self.game, self.proc, self.output = self.root / 'game', self.root / 'proc', self.root / 'evidence'
        self.game.mkdir()
        self.config = w.Config(game_root=self.game, output_dir=self.output,
                               daemon=str(self.root / 'DreamDaemon'), pid=321, start_ticks=98765,
                               port=1715, stale_seconds=30, startup_grace_seconds=30,
                               cooldown_seconds=30, max_bundle_bytes=8192, max_total_bytes=32768)
        self.write(self.proc / '321/stat', proc_line())
        argv = [self.config.daemon, str(self.game), 'civ13.dmb', '1715', '-trusted']
        self.write(self.proc / '321/cmdline', b'\0'.join(os.fsencode(a) for a in argv) + b'\0')
        self.write(self.proc / '321/status', 'Name:\tDreamDaemon\nVmRSS:\t12345 kB\nThreads:\t3\nPrivate:\tCANARY\n')
        self.write(self.proc / '321/task/321/stat', proc_line())
        self.write(self.proc / '321/task/321/wchan', 'futex_wait_queue_me\n')
        (self.proc / '321/fd').mkdir()
        self.write(self.proc / 'net/tcp', 'header\n0: 00000000:06B3 00000000:0000 0A 00000000:00000081 00:0 0 1000 0 12345\n')
        self.write(self.proc / 'net/tcp6', 'header\n')
        self.write(self.proc / 'meminfo', 'MemTotal: 4000 kB\nMemAvailable: 1600 kB\nSwapTotal: 0 kB\n')
        self.write(self.proc / 'sys/kernel/random/boot_id', '12345678-1234-1234-1234-123456789abc')
        self.write(self.game / 'civ13.dmb', b'compiled fixture')
        self.write(self.game / 'civ13.rsc', b'resource fixture')
        self.write(self.game / 'config/lifecycle-revision.txt', 'a' * 40)
        self.write(self.game / 'config/lifecycle-token.txt', 'CANARY secret token')
        self.write(self.game / 'civ13.log', 'password=CANARY\nBUG: Sequence number 418D expected but 2 received CANARY\n')
        self.write(self.game / 'data/logs/runtime/2026-10-20-(01-04-57)-runtime.txt',
                   'runtime error: Cannot read null.burn_dam\nCANARY private chat\n')
        self.write(self.game / 'ooc.log', 'CANARY PRIVATE PLAYER TEXT')
        self.write(self.game / 'map_saves/1.sav', b'CANARY DO NOT OPEN OR CHANGE SAVE')
        self.write(self.game / 'map_saves/save_complete.txt', 'round-v2:' + 'b' * 32)
        self.write(self.game / 'map_saves/restart_intent.json', 'CANARY PRIVATE INTENT')
        self.counter = 0
        self.advance()
        self.observer = w.Observer(self.config, self.proc)
        if sys.platform != 'linux':
            # These tests exercise portable detection/storage, not POSIX locking.
            enter = patch.object(w.Store, '__enter__', lambda store: store)
            leave = patch.object(w.Store, '__exit__', lambda *args: None)
            enter.start()
            leave.start()
            self.addCleanup(enter.stop)
            self.addCleanup(leave.stop)

    @staticmethod
    def write(path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(value if isinstance(value, bytes) else value.encode())

    def advance(self):
        self.counter += 1
        path = self.game / 'serverdata.txt'
        path.write_text('CANARY PLAYER STATUS', encoding='utf-8')
        stamp = 1700000000000000000 + self.counter * 1000000
        os.utime(path, ns=(stamp, stamp))

    def monitor(self, config=None):
        config = config or self.config
        store = w.Store(config)
        return w.Monitor(config, w.Observer(config, self.proc), store), store

    def bundle_names(self):
        return sorted(self.output.glob('incident-*.json'))

    def copied_module(self, destination):
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(SOURCE, destination)
        name = 'copied_watchdog_' + hashlib.sha256(os.fsencode(destination)).hexdigest()
        spec = importlib.util.spec_from_file_location(name, destination)
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        self.addCleanup(sys.modules.pop, name, None)
        spec.loader.exec_module(module)
        return module


class DetectionTests(Fixture):
    def test_initial_file_is_unconfirmed_then_stale_while_listener_is_open(self):
        monitor, store = self.monitor()
        with store:
            self.assertEqual(monitor.step(0, 1700000000)['state'], 'starting')
            result = monitor.step(31, 1700000031)
            self.assertEqual(result['state'], 'heartbeat_stale')
            bundle = json.loads((self.output / result['bundle']).read_text())
            self.assertTrue(bundle['observation']['listener']['listening'])
            self.assertEqual(bundle['observation']['listener']['queued_unaccepted'], 129)
            self.assertIsNone(bundle['observation']['listener']['maximum_backlog'])
            self.assertFalse(bundle['observation']['automatic_recovery'])

    def test_progress_recovery_and_new_incident(self):
        monitor, store = self.monitor()
        with store:
            monitor.step(0, 1700000000)
            monitor.step(31, 1700000031)
            self.advance()
            self.assertEqual(monitor.step(32, 1700000032)['state'], 'healthy')
            self.assertFalse(json.loads((self.output / 'watchdog-state.json').read_text())['active'])
            self.assertIsNotNone(monitor.step(63, 1700000063)['bundle'])
        self.assertEqual(len(self.bundle_names()), 2)

    def test_dedup_survives_observer_restart(self):
        monitor, store = self.monitor()
        with store:
            monitor.step(0, 1700000000)
            monitor.step(31, 1700000031)
            for now in (32, 100, 10000):
                self.assertIsNone(monitor.step(now, 1700000000 + now)['bundle'])
        monitor, store = self.monitor()
        with store:
            monitor.step(10001, 1700010001)
            self.assertIsNone(monitor.step(10040, 1700010040)['bundle'])
        self.assertEqual(len(self.bundle_names()), 1)

    def test_new_incidents_wait_for_monotonic_cooldown(self):
        config = replace(self.config, cooldown_seconds=90)
        monitor, store = self.monitor(config)
        with store:
            monitor.step(0, 1700000000)
            monitor.step(31, 1700000031)
            self.advance()
            monitor.step(32, 1700000032)
            self.assertIsNone(monitor.step(63, 1700000063)['bundle'])
            self.assertIsNone(monitor.step(120, 1700000120)['bundle'])
            self.assertIsNotNone(monitor.step(121, 1700000121)['bundle'])

    def test_missing_heartbeat_and_permission_failure_are_distinct(self):
        (self.game / 'serverdata.txt').unlink()
        tracker = w.Heartbeat(self.config)
        self.assertEqual(tracker.evaluate(self.observer.sample(), 0)['state'], 'starting')
        self.assertEqual(tracker.evaluate(self.observer.sample(), 31)['state'], 'heartbeat_missing')
        self.advance()
        with patch.object(self.observer, 'heartbeat', return_value=dict(status='permission_denied')):
            self.assertEqual(tracker.evaluate(self.observer.sample(), 32)['state'], 'heartbeat_permission_denied')

    def test_first_heartbeat_after_missing_rearms_progress_without_claiming_health(self):
        (self.game / 'serverdata.txt').unlink()
        tracker = w.Heartbeat(self.config)
        tracker.evaluate(self.observer.sample(), 0)
        self.assertEqual(tracker.evaluate(self.observer.sample(), 31)['state'], 'heartbeat_missing')
        self.advance()
        self.assertEqual(tracker.evaluate(self.observer.sample(), 32)['state'], 'starting')
        self.advance()
        self.assertEqual(tracker.evaluate(self.observer.sample(), 33)['state'], 'healthy')

    def test_wall_clock_changes_and_future_mtime_do_not_control_expiry(self):
        monitor, store = self.monitor()
        with store:
            monitor.step(0, 1700000000)
            self.advance()
            os.utime(self.game / 'serverdata.txt', (2100000000, 2100000000))
            self.assertEqual(monitor.step(5, 1500000000)['state'], 'healthy')
            self.assertEqual(monitor.step(20, 2000000000)['state'], 'healthy')
            self.assertEqual(monitor.step(36, 1000000000)['state'], 'heartbeat_stale')

    def test_monotonic_reset_rearms_grace_without_duplicate_incident(self):
        monitor, store = self.monitor()
        with store:
            monitor.step(50, 1700000000)
            monitor.step(81, 1700000031)
            self.assertEqual(monitor.step(1, 1700000032)['state'], 'starting')
            self.assertIsNone(monitor.step(32, 1700000063)['bundle'])
        self.assertEqual(len(self.bundle_names()), 1)

    def test_recycled_pid_refused_and_foreign_threads_not_collected(self):
        self.write(self.proc / '321/stat', proc_line(start=98766))
        monitor, store = self.monitor()
        with store:
            result = monitor.step(0, 1700000000)
        self.assertEqual(result['state'], 'process_identity_mismatch')
        bundle = json.loads((self.output / result['bundle']).read_text())
        self.assertEqual(bundle['diagnostics']['threads'], [])

    def test_wrong_directory_or_port_is_not_adopted(self):
        self.write(self.proc / '321/cmdline', b'/different\0CANARY\0')
        self.assertEqual(self.observer.identity(), dict(status='identity_mismatch'))

    def test_missing_process_is_not_reported_as_stale_game(self):
        (self.proc / '321/stat').unlink()
        monitor, store = self.monitor()
        with store:
            self.assertEqual(monitor.step(0, 1700000000)['state'], 'process_missing')

    def test_wrong_pid_is_never_discovered_or_adopted(self):
        monitor, store = self.monitor(replace(self.config, pid=999))
        with store:
            self.assertEqual(monitor.step(0, 1700000000)['state'], 'process_missing')

    def test_progressing_game_with_no_listener_is_distinguished(self):
        self.write(self.proc / 'net/tcp', 'header\n')
        monitor, store = self.monitor()
        with store:
            monitor.step(0, 1700000000)
            self.advance()
            self.assertEqual(monitor.step(5, 1700000005)['state'], 'listener_missing')
        status = json.loads((self.output / 'watchdog-status.json').read_text())
        self.assertEqual(status['heartbeat_state'], 'healthy')

    def test_recovery_cooldown_and_rollback_do_not_emit_early(self):
        monitor, store = self.monitor(replace(self.config, cooldown_seconds=90))
        with store:
            monitor.step(0, 1700000000)
            monitor.step(31, 1700000031)
            self.advance()
            monitor.step(32, 1700000032)
            self.assertIsNone(monitor.step(63, 1600000000)['bundle'])
            self.assertIsNone(monitor.step(1, 1500000000)['bundle'])
            self.assertIsNone(monitor.step(32, 1400000000)['bundle'])
            self.assertIsNotNone(monitor.step(91, 1300000000)['bundle'])


class CollectionTests(Fixture):
    def test_privacy_allowlist_and_game_files_never_mutated(self):
        before = {str(p.relative_to(self.game)): p.read_bytes() for p in self.game.rglob('*') if p.is_file()}
        original = w.bounded_read
        def guarded(path, *args, **kwargs):
            path = Path(path)
            self.assertNotEqual(path.name, 'serverdata.txt', 'heartbeat contents must not be read')
            self.assertFalse(path.is_relative_to(self.game / 'map_saves'), 'save contents must not be opened')
            self.assertNotIn(path.name, ('ooc.log', 'lifecycle-token.txt', 'environ', '.bash_history'))
            return original(path, *args, **kwargs)
        monitor, store = self.monitor()
        with store, patch.object(w, 'bounded_read', side_effect=guarded), patch('os.kill', side_effect=AssertionError('signal')):
            monitor.step(0, 1700000000)
            monitor.step(31, 1700000031)
        after = {str(p.relative_to(self.game)): p.read_bytes() for p in self.game.rglob('*') if p.is_file()}
        self.assertEqual(before, after)
        output = ''.join(p.read_text() for p in self.output.glob('*.json'))
        self.assertNotIn('CANARY', output)
        bundle = json.loads(self.bundle_names()[0].read_text())
        self.assertEqual(bundle['diagnostics']['logs'][0]['classifications'], {'engine_sequence_warning': 1})
        self.assertEqual(bundle['diagnostics']['process_counters'], {'Threads': 3, 'VmRSS': 12345})
        self.assertEqual(bundle['diagnostics']['artifacts']['civ13.dmb']['sha256'], hashlib.sha256(b'compiled fixture').hexdigest())
        self.assertFalse(bundle['diagnostics']['revision_binding_verified'])

    def test_denied_collection_is_partial_without_retry_or_raw_error(self):
        original = w.bounded_read
        def denied(path, *args, **kwargs):
            if Path(path).name == 'wchan':
                raise PermissionError('CANARY confidential path')
            return original(path, *args, **kwargs)
        with patch.object(w, 'bounded_read', side_effect=denied):
            diagnostics = self.observer.diagnostics(self.observer.sample())
        self.assertEqual(diagnostics['threads'][0]['error'], 'permission_denied')
        self.assertNotIn('CANARY', json.dumps(diagnostics))

    def test_socket_table_failure_is_unknown_not_no_listener_proof(self):
        (self.proc / 'net/tcp').unlink()
        result = self.observer.listener(True)
        self.assertEqual(result['status'], 'partial')
        self.assertIn('missing', result['errors'])

    def test_thread_and_directory_bounds(self):
        for tid in range(322, 360):
            self.write(self.proc / f'321/task/{tid}/stat', proc_line(pid=tid))
            self.write(self.proc / f'321/task/{tid}/wchan', 'hrtimer_nanosleep')
        result = self.observer.diagnostics(self.observer.sample())
        self.assertEqual(len(result['threads']), 32)
        with patch.object(w, 'ENTRY_LIMIT', 1), self.assertRaises(ValueError):
            w.list_bounded(self.proc / '321/task')

    def test_changed_process_during_collection_is_marked_unverified(self):
        observation = self.observer.sample()
        self.write(self.proc / '321/stat', proc_line(start=99999))
        self.assertFalse(self.observer.diagnostics(observation)['process_identity_still_verified'])

    def test_special_or_oversized_input_refused(self):
        path = self.root / 'large'
        path.write_bytes(b'x' * 129)
        with self.assertRaises(ValueError):
            w.bounded_read(path, 128)
        if os.name != 'nt':
            fifo = self.root / 'fifo'
            os.mkfifo(fifo)
            with self.assertRaises(ValueError):
                w.bounded_read(fifo)

    def test_symlink_heartbeat_or_log_never_reads_target(self):
        secret = self.root / 'private'
        secret.write_text('CANARY')
        link = self.game / 'serverdata.txt'
        link.unlink()
        try:
            link.symlink_to(secret)
        except OSError:
            self.skipTest('symlink creation unavailable on this Windows account')
        self.assertEqual(self.observer.heartbeat()['status'], 'unavailable')
        with self.assertRaises(ValueError):
            w.bounded_read(link)

    def test_no_process_or_network_execution_capabilities(self):
        tree = ast.parse(SOURCE.read_text())
        imports = imported_modules(SOURCE.read_text())
        self.assertTrue(imports.isdisjoint({'subprocess', 'socket', 'ctypes', 'signal'}))
        # Exercise collection above with os.kill denied; also reject executable
        # escape paths, rather than only checking a disabled configuration flag.
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
                self.assertNotIn(node.func.attr, ('system', 'popen', 'kill', 'killpg', 'execve', 'spawnv'))

    def test_import_guard_detects_multi_alias_and_from_import_controls(self):
        for source, module in (('import os, subprocess as child', 'subprocess'),
                               ('from ctypes import CDLL', 'ctypes'),
                               ('import socket.server as server', 'socket'),
                               ('from signal import SIGTERM', 'signal')):
            with self.subTest(source=source):
                self.assertIn(module, imported_modules(source))


class StorageTests(Fixture):
    def test_copied_installation_accepts_output_outside_game(self):
        # A generic ancestor Git marker must not turn an installation into the
        # Civ13 checkout (some developer machines version their whole home).
        (self.root / '.git').mkdir()
        installed = self.copied_module(self.root / 'opt/civ13-watchdog/watchdog.py')
        config = installed.Config(**self.config.__dict__)
        self.assertEqual(config.output_dir, self.output)
        self.assertFalse(self.output.exists())
        with self.assertRaises(ValueError):
            replace(config, output_dir=self.game / 'evidence')

    def test_shallow_script_path_does_not_index_missing_parents(self):
        installed = self.copied_module(self.root / 'watchdog.py')
        with patch.object(installed, '__file__', str(Path(self.root.anchor) / 'watchdog.py')):
            self.assertEqual(installed.Config(**self.config.__dict__).output_dir, self.output)

    def test_checkout_output_refused_for_git_directory_and_worktree_marker(self):
        for kind in ('directory', 'file'):
            checkout = self.root / kind
            marker = checkout / '.git'
            checkout.mkdir()
            marker.mkdir() if kind == 'directory' else marker.write_text('gitdir: elsewhere\n')
            (checkout / 'civ13.dme').write_text('// source entry-point fixture\n')
            module = self.copied_module(checkout / 'scripts/hang-watchdog/watchdog.py')
            with self.subTest(marker=kind), self.assertRaises(ValueError):
                module.Config(**{**self.config.__dict__, 'output_dir': checkout / 'evidence'})
            self.assertEqual(module.Config(**self.config.__dict__).output_dir, self.output)

    @unittest.skipUnless(sys.platform == 'linux', 'Copied Linux CLI acceptance runs on Linux CI')
    def test_copied_installation_runs_once_with_real_cli(self):
        script = self.root / 'opt/civ13-watchdog/watchdog.py'
        self.copied_module(script)
        config = {**self.config.__dict__, 'pid': 2**31 - 1}
        path = self.root / 'config.json'
        path.write_text(json.dumps(config, default=str))
        result = subprocess.run([sys.executable, '-B', str(script), '--config', str(path), '--once'],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        status = json.loads((self.output / 'watchdog-status.json').read_text())
        self.assertEqual(status['process']['status'], 'missing')
        self.assertFalse(status['automatic_recovery'])

    def test_root_cli_is_refused_before_reading_configuration(self):
        with patch.object(w.sys, 'platform', 'linux'), patch.object(w.os, 'geteuid', return_value=0, create=True):
            with patch.object(w, 'bounded_read', side_effect=AssertionError('configuration read before guard')):
                with self.assertRaises(SystemExit) as result:
                    w.main(['--config', 'never-read'])
                self.assertEqual(result.exception.code, 2)

    def test_history_count_and_total_bytes_are_capped(self):
        config = replace(self.config, max_bundles=2)
        store = w.Store(config)
        with store:
            for index in range(1, 10):
                store.write(f'incident-{index:020d}.json', {'data': 'x' * 6000}, config.max_bundle_bytes)
                self.assertLessEqual(store.inventory()[0], config.max_total_bytes)
        self.assertEqual([p.name for p in self.bundle_names()], ['incident-00000000000000000008.json', 'incident-00000000000000000009.json'])

    def test_byte_quota_prunes_history_before_exceeding_cap(self):
        store = w.Store(self.config)
        with store:
            for index in range(1, 12):
                store.write(f'incident-{index:020d}.json', {'data': 'x' * 8000}, self.config.max_bundle_bytes)
                self.assertLessEqual(store.inventory()[0], self.config.max_total_bytes)
        self.assertLess(len(self.bundle_names()), self.config.max_bundles)

    def test_unknown_files_preserved_when_quota_exhausted(self):
        store = w.Store(self.config)
        unknown = self.output / 'operator-note'
        unknown.write_bytes(b'x' * self.config.max_total_bytes)
        with store, self.assertRaises(ValueError):
            store.write('watchdog-status.json', {'state': 'healthy'})
        self.assertEqual(unknown.stat().st_size, self.config.max_total_bytes)

    def test_oversized_output_refused_before_write(self):
        store = w.Store(self.config)
        with store, self.assertRaises(ValueError):
            store.write('incident-00000000000000000001.json', {'data': 'x' * 9000}, 8192)
        self.assertEqual(self.bundle_names(), [])

    def test_output_must_be_dedicated_and_not_game_directory(self):
        with self.assertRaises(ValueError):
            replace(self.config, output_dir=self.game / 'diagnostics')
        self.output.mkdir()
        (self.output / 'unrelated').write_text('preserve')
        with self.assertRaises(ValueError):
            w.Store(self.config)
        self.assertEqual((self.output / 'unrelated').read_text(), 'preserve')

    def test_path_traversal_and_symlink_parent_refused(self):
        with self.assertRaises(ValueError):
            w.beneath(self.game, '../private')
        link = self.root / 'alias'
        outside = self.root / 'outside'
        outside.mkdir()
        try:
            link.symlink_to(outside, target_is_directory=True)
        except OSError:
            self.skipTest('symlink creation unavailable')
        with self.assertRaises(ValueError):
            replace(self.config, output_dir=link / 'evidence')

    @unittest.skipIf(os.name == 'nt', 'POSIX private-mode acceptance runs on Linux CI')
    def test_public_output_permissions_refused_without_chmod(self):
        self.output.mkdir(mode=0o700)
        self.output.chmod(0o755)
        with self.assertRaises(ValueError):
            w.Store(self.config)
        self.assertEqual(self.output.stat().st_mode & 0o777, 0o755)

    @unittest.skipUnless(sys.platform == 'linux', 'Kernel flock acceptance runs on Linux CI')
    def test_singleton_rejects_live_holder_and_reuses_unlocked_file(self):
        store = w.Store(self.config)
        with store:
            inode = (self.output / 'watchdog.lock').stat().st_ino
            with self.assertRaises(FileExistsError):
                with w.Store(self.config):
                    self.fail('second observer acquired lock')
            with self.assertRaises(FileExistsError):
                store.__enter__()
        self.assertIsNone(store.lock_fd)
        (self.output / 'watchdog.lock').write_text('old diagnostic PID; never ownership proof')
        with store:
            self.assertEqual((self.output / 'watchdog.lock').stat().st_ino, inode)
        self.assertEqual((self.output / 'watchdog.lock').read_text(), 'old diagnostic PID; never ownership proof')

    @unittest.skipUnless(sys.platform == 'linux', 'Killed observer recovery runs on Linux CI')
    def test_killed_observer_releases_lock_and_retains_incident_dedup(self):
        # This child owns only a temporary offline observer, never a game process.
        config = self.root / 'config.json'
        config.write_text(json.dumps(self.config.__dict__, default=str))
        ready = self.root / 'ready'
        program = '''
import importlib.util, json, pathlib, sys, time
spec = importlib.util.spec_from_file_location('crash_observer', sys.argv[1])
w = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = w
spec.loader.exec_module(w)
config = w.Config(**json.loads(pathlib.Path(sys.argv[2]).read_text()))
with w.Store(config) as store:
    monitor = w.Monitor(config, w.Observer(config, pathlib.Path(sys.argv[3])), store)
    monitor.step(0, 1700000000)
    monitor.step(31, 1700000031)
    pathlib.Path(sys.argv[4]).write_text('ready')
    time.sleep(15)
'''
        child = subprocess.Popen([sys.executable, '-B', '-c', program, str(SOURCE),
                                  str(config), str(self.proc), str(ready)],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 10
            while not ready.exists() and child.poll() is None and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(ready.exists(), 'temporary observer did not reach the crash checkpoint')
            inode = (self.output / 'watchdog.lock').stat().st_ino
            contender = w.Store(self.config)
            with self.assertRaises(FileExistsError):
                contender.__enter__()
            self.assertIsNone(contender.lock_fd)
            self.assertEqual(len(self.bundle_names()), 1)
            child.kill()
            child.wait(timeout=5)
            monitor, store = self.monitor()
            with store:
                self.assertEqual((self.output / 'watchdog.lock').stat().st_ino, inode)
                self.assertIsNone(monitor.step(32, 1700000032)['bundle'])
                self.assertIsNone(monitor.step(63, 1700000063)['bundle'])
                self.advance()
                self.assertEqual(monitor.step(64, 1700000064)['state'], 'healthy')
                self.assertIsNotNone(monitor.step(95, 1700000095)['bundle'])
            self.assertEqual(len(self.bundle_names()), 2)
        finally:
            if child.poll() is None:
                child.kill()
            child.communicate(timeout=5)

    @unittest.skipUnless(sys.platform == 'linux', 'Kernel lock path acceptance runs on Linux CI')
    def test_lock_symlink_special_hardlink_and_public_mode_refused(self):
        store = w.Store(self.config)
        target = self.root / 'private'
        target.write_text('CANARY')
        target.chmod(0o600)
        lock = self.output / 'watchdog.lock'
        for kind in ('symlink', 'fifo', 'hardlink', 'public'):
            if kind == 'symlink':
                lock.symlink_to(target)
            elif kind == 'fifo':
                os.mkfifo(lock)
            elif kind == 'hardlink':
                os.link(target, lock)
            else:
                lock.write_text('public')
                lock.chmod(0o644)
            try:
                with self.subTest(kind=kind), self.assertRaises((OSError, ValueError)):
                    store.__enter__()
                self.assertIsNone(store.lock_fd)
                self.assertEqual(target.read_text(), 'CANARY')
            finally:
                lock.unlink()

    def test_interrupted_atomic_write_is_preserved_and_requires_reconciliation(self):
        store = w.Store(self.config)
        pending = self.output / '.watchdog.tmp'
        pending.write_text('interrupted evidence')
        with store, self.assertRaises(FileExistsError):
            store.write('watchdog-status.json', {'state': 'healthy'})
        self.assertEqual(pending.read_text(), 'interrupted evidence')

    def test_corrupt_or_other_target_state_refused(self):
        store = w.Store(self.config)
        store.write('watchdog-state.json', {'CANARY': 'bad state'})
        with self.assertRaises(ValueError):
            store.load_state()

    def test_existing_incident_is_never_overwritten(self):
        store = w.Store(replace(self.config, max_bundles=1))
        with store:
            store.write('incident-00000000000000000001.json', {'original': True}, 8192)
            with self.assertRaises(ValueError):
                store.write('incident-00000000000000000001.json', {'original': False}, 8192)

    def test_output_symlink_does_not_modify_external_file(self):
        store = w.Store(self.config)
        external = self.root / 'private'
        external.write_text('CANARY')
        try:
            (self.output / 'incident-00000000000000000001.json').symlink_to(external)
        except OSError:
            self.skipTest('symlink creation unavailable')
        with store, self.assertRaises(ValueError):
            store.write('watchdog-status.json', {'state': 'healthy'})
        self.assertEqual(external.read_text(), 'CANARY')

    def test_invalid_configuration_and_unbounded_values_refused(self):
        for values in ({'poll_seconds': 0}, {'stale_seconds': float('nan')}, {'pid': True},
                       {'max_bundles': 1000}, {'max_total_bytes': 1024}, {'expected_revision': 'secret'},
                       {'expected_byond': 'CANARY'}, {'daemon': 'DreamDaemon'}):
            with self.subTest(values=values), self.assertRaises(ValueError):
                replace(self.config, **values)


if __name__ == '__main__':
    unittest.main()
