"""Offline controls for the hosted collector wrapper; never starts a process."""
from datetime import datetime, timedelta, timezone
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import types
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location('variable_linux', Path(__file__).with_name('run_variable_probe_linux.py'))
m = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(m)


class LinuxCollector(unittest.TestCase):
    def test_native_gate_refuses_desktop_before_output_or_spawn(self):
        with tempfile.TemporaryDirectory() as folder, mock.patch.dict(os.environ, {}, clear=True), \
                mock.patch.object(m.subprocess, 'Popen') as launch:
            output = Path(folder) / 'new'
            with self.assertRaisesRegex(RuntimeError, 'isolated Linux PR CI'):
                m.native_gate(output, Path(folder), 'a' * 40)
            self.assertFalse(output.exists())
            launch.assert_not_called()

    def test_gate_rejects_manual_event_and_unscoped_output(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); workspace = root / 'workspace'; workspace.mkdir()
            temp = root / 'temporary'; temp.mkdir()
            byond = workspace / 'BYOND/byond/bin'; byond.mkdir(parents=True)
            env = dict(GITHUB_ACTIONS='true', RUNNER_OS='Linux', GITHUB_EVENT_NAME='pull_request',
                       GITHUB_REPOSITORY='Civ13/Civ13', GITHUB_WORKSPACE=str(workspace), RUNNER_TEMP=str(temp),
                       BYOND_MAJOR='516', BYOND_MINOR='1681')
            with mock.patch.object(m.sys, 'platform', 'linux'), mock.patch.object(m, 'ROOT', workspace), \
                    mock.patch.dict(os.environ, env, clear=True):
                m.native_gate(temp / 'new', byond, 'a' * 40)
                for changed in ({'GITHUB_EVENT_NAME': 'workflow_dispatch'}, {'BYOND_MINOR': '0'},
                                {'GITHUB_REPOSITORY': 'unrelated/repository'}):
                    with mock.patch.dict(os.environ, changed), self.assertRaises(RuntimeError):
                        m.native_gate(temp / 'new', byond, 'a' * 40)
                with self.assertRaises(RuntimeError):
                    m.native_gate(workspace / 'output', byond, 'a' * 40)
                with self.assertRaises(RuntimeError):
                    m.native_gate(temp / 'new', byond, 'not-a-commit')

    def test_proc_birth_and_group_identity_parser(self):
        values = ['S', '11', '123', '123'] + ['0'] * 18
        values[11], values[12], values[19], values[21] = '4', '5', '999', '2'
        row = m.parse_stat('123 (name with spaces) ' + ' '.join(values))
        self.assertEqual((row['pid'], row['pgrp'], row['session'], row['start_ticks']), (123, 123, 123, 999))
        self.assertEqual(row['cpu_ticks'], 9)
        with self.assertRaises((RuntimeError, ValueError)):
            m.parse_stat('truncated')

    def test_all_socket_families_and_foreign_inode_filter(self):
        tables = {'tcp': 'header\n0: 0100007F:E852 00000000:0000 0A 0 0 0 0 0 44\n',
                  'tcp6': 'header\n', 'udp': 'header\n', 'udp6': 'header\n'}
        rows = m.socket_rows({'44'}, tables)
        m.validate_sockets(rows, runtime=True, closed=False)
        self.assertEqual(rows[0]['port'], 59474)
        self.assertEqual(m.socket_rows({'foreign'}, tables), [])
        for table, state, address in (('udp', '07', '0100007F'), ('tcp', '01', '0100007F'),
                                      ('tcp', '0A', '00000000')):
            altered = tables | {table: f'header\n0: {address}:E852 00000000:0000 {state} 0 0 0 0 0 44\n'}
            with self.assertRaises(RuntimeError):
                m.validate_sockets(m.socket_rows({'44'}, altered), runtime=True, closed=False)

    def test_marker_without_external_socket_closure_never_gets_ack(self):
        with tempfile.TemporaryDirectory() as folder:
            case = Path(folder); (case / 'probe-port-closed.txt').write_text('closed\n')
            row = dict(protocol='tcp', address='127.0.0.1', port=59474, state='listen')
            with self.assertRaises(RuntimeError):
                m.acknowledge(case, [row])
            self.assertFalse((case / 'probe-port-closed.ack').exists())
            m.acknowledge(case, [])
            self.assertEqual((case / 'probe-port-closed.ack').read_bytes(), b'closed\n')

    def test_artifact_budget_includes_environment_and_rejects_unexpected(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); env = root / 'environment'; env.mkdir()
            (env / 'large').write_bytes(b'x' * (m.CAPS['evidence_bytes'] + 1))
            with self.assertRaises(RuntimeError):
                m.artifacts(root, {})
            (env / 'large').unlink()
            (root / 'surprise.bin').write_text('unlisted')
            with self.assertRaises(RuntimeError):
                m.artifacts(root, {})

    def test_group_cleanup_precedes_reap_and_birth_mismatch_never_signals(self):
        events = []; process = mock.Mock(pid=123, returncode=0)
        process.wait.side_effect = lambda **kwargs: events.append('reap')
        identity = dict(pid=123, pgrp=123, session=123, start_ticks=99, state='Z', cpu_ticks=0)
        with mock.patch.object(m, 'identity', return_value=identity), \
                mock.patch.object(m, 'group_members', return_value=[]), \
                mock.patch.object(m.os, 'killpg', create=True, side_effect=lambda *a: events.append('kill-group')), \
                mock.patch.object(m.signal, 'SIGKILL', 9, create=True):
            receipt = m.cleanup(process, identity, m.time.monotonic() + 1)
            self.assertTrue(receipt['group_empty'])
            self.assertEqual(events, ['kill-group', 'reap'])
            events.clear()
            with mock.patch.object(m, 'identity', return_value=identity | {'start_ticks': 100}):
                receipt = m.cleanup(process, identity, m.time.monotonic() + 1)
            self.assertFalse(receipt['group_empty'])
            self.assertEqual(events, [])

    def test_resource_limits_are_child_only_and_core_dump_is_disabled(self):
        fake = mock.Mock(RLIMIT_AS=1, RLIMIT_CPU=2, RLIMIT_FSIZE=3, RLIMIT_CORE=4)
        with mock.patch.dict('sys.modules', resource=fake):
            m.child_limits()
        self.assertEqual(fake.setrlimit.call_args_list, [
            mock.call(1, (536870912, 536870912)), mock.call(2, (15, 15)),
            mock.call(3, (1048576, 1048576)), mock.call(4, (0, 0))])

    def test_actual_child_path_cleans_up_on_deadline_and_never_polls_reaping(self):
        process = mock.Mock(pid=123, returncode=0)
        birth = dict(pid=123, start_ticks=99, pgrp=123, session=123)
        usage = types.SimpleNamespace(ru_utime=0, ru_stime=0)
        fake_resource = types.SimpleNamespace(RUSAGE_CHILDREN=1, getrusage=lambda _: usage)
        budget = types.SimpleNamespace(start=m.time.monotonic(), check=mock.Mock(side_effect=[None, RuntimeError('deadline')]))
        with tempfile.TemporaryDirectory() as folder, mock.patch.dict('sys.modules', resource=fake_resource), \
                mock.patch.object(m, 'sha', return_value='a'), mock.patch.object(m, 'identity', return_value=birth), \
                mock.patch.object(m.subprocess, 'Popen', return_value=process) as spawn, \
                mock.patch.object(m, 'exited_unreaped', return_value=False), \
                mock.patch.object(m, 'cleanup', return_value=dict(exit_code=0, group_empty=True, errors=[])) as cleanup:
            root = Path(folder); receipt = dict(children=[])
            with self.assertRaisesRegex(RuntimeError, 'deadline'):
                m.run_child(['DreamMaker'], root, 'compile', root, {}, {'DreamMaker': 'a'}, receipt, budget, mock.Mock())
            cleanup.assert_called_once()
            self.assertEqual(cleanup.call_args.args[:2], (process, birth))
            self.assertTrue(spawn.call_args.kwargs['start_new_session'])
            self.assertNotIn('GITHUB_TOKEN', spawn.call_args.kwargs['env'])
            process.poll.assert_not_called()
            self.assertTrue(receipt['children'][0]['cleanup']['group_empty'])

    def test_exit_race_never_replaces_required_socket_acknowledgement(self):
        process = mock.Mock(pid=123, returncode=0)
        birth = dict(pid=123, start_ticks=99, pgrp=123, session=123)
        usage = types.SimpleNamespace(ru_utime=0, ru_stime=0)
        fake_resource = types.SimpleNamespace(RUSAGE_CHILDREN=1, getrusage=lambda _: usage)
        budget = types.SimpleNamespace(start=m.time.monotonic(), check=mock.Mock())
        with tempfile.TemporaryDirectory() as folder, mock.patch.dict('sys.modules', resource=fake_resource), \
                mock.patch.object(m, 'sha', return_value='a'), mock.patch.object(m, 'identity', return_value=birth), \
                mock.patch.object(m.subprocess, 'Popen', return_value=process), \
                mock.patch.object(m, 'exited_unreaped', side_effect=[False, True]), \
                mock.patch.object(m, 'group_members', return_value=[birth]), \
                mock.patch.object(m, 'owned_sockets', side_effect=FileNotFoundError), \
                mock.patch.object(m, 'cleanup', return_value=dict(exit_code=0, group_empty=True, errors=[])) as cleanup:
            root = Path(folder)
            with self.assertRaisesRegex(RuntimeError, 'socket acknowledgement'):
                m.run_child(['DreamDaemon'], root, 'writable', root, {}, {'DreamDaemon': 'a'},
                            dict(children=[]), budget, mock.Mock())
            cleanup.assert_called_once()

    def test_reader_failure_is_retained_and_freshness_not_overridden(self):
        reader = mock.Mock(); reader.run.return_value = dict(ok=False, error='stale_snapshot')
        receipt = {}; budget = mock.Mock()
        with mock.patch.object(m, 'load_reader', return_value=reader), tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(RuntimeError):
                m.read_captures(Path(folder), receipt, budget)
        self.assertFalse(receipt['reader']['native-reference.json']['ok'])
        self.assertNotIn('historical', reader.run.call_args.kwargs)

    def test_workflow_runs_only_introduced_tests_without_security_changes(self):
        source = (m.ROOT / '.github/workflows/test.yml').read_text()
        block = source.split('      - name: Verify private collector native publication', 1)[1].split('      - name: Verify bounded lighting startup ordering', 1)[0]
        self.assertIn("if: contains(fromJSON(needs.changes.outputs.new_tests), 'tests/nomads_lifecycle')", block)
        for needed in ('timeout-minutes: 3', '--expected-head "$COLLECTOR_HEAD"', 'retention-days: 7',
                       'if: always() && steps.collector_native.outputs.started == \'true\''):
            self.assertIn(needed, block)
        for forbidden in ('secrets.', 'workflow_dispatch', 'sudo ', 'continue-on-error', '1714', 'D:/'):
            self.assertNotIn(forbidden, block)


if __name__ == '__main__':
    unittest.main()
