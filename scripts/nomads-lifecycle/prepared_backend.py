"""Owned native operations behind the bot consumer's fixed protocol.

Imports do not read tokens, contact a world, or launch a process. The live
Windows adapter needs psutil for actual executable/cwd/listener inspection.
"""
from pathlib import Path
import json
import os

import supervisor as core
from master_guard import verified_master


def windows_observation(host, daemon, run, port):
    if os.name != 'nt':
        raise RuntimeError('Native consumer execution supports Windows only')
    import psutil  # Explicit runtime prerequisite, never installed automatically.
    pid, created = host['pid'], host['creation_filetime']
    if core.process_identity(pid) != created:
        raise RuntimeError('Owned process exited or PID was reused')
    process = psutil.Process(pid)
    if Path(process.exe()).resolve(strict=True) != daemon or Path(process.cwd()).resolve(strict=True) != run:
        raise RuntimeError('Actual native executable or working directory differs')
    listeners = [item for item in process.net_connections(kind='tcp')
                 if item.status == psutil.CONN_LISTEN and item.laddr.port == port]
    if not listeners or any(item.laddr.ip != '127.0.0.1' for item in listeners):
        raise RuntimeError('Owned native listener is absent or not loopback-only')
    if core.process_identity(pid) != created:
        raise RuntimeError('Process identity changed during native inspection')
    return {'pid': pid, 'creation_filetime': str(created),
            'executable': str(daemon), 'working_directory': str(run)}


def closed_port(port):
    if os.name != 'nt':
        raise RuntimeError('Native consumer execution supports Windows only')
    import psutil
    if any(item.status == psutil.CONN_LISTEN and item.laddr.port == port
           for item in psutil.net_connections(kind='tcp')):
        raise RuntimeError('Conflicting local listener; no process action permitted')


class PreparedBackend:
    """Called only under the shared supervisor.lock; never resets or builds."""
    def __init__(self, config, binding, *, observe=windows_observation,
                 assert_closed=closed_port, guard=verified_master, supervisor=None):
        self.config, self.binding = config, binding
        self.run = Path(binding['runtime_directory'])
        self.daemon = Path(binding['daemon'])
        self.observe_process, self.assert_closed, self.guard = observe, assert_closed, guard
        self.supervisor = supervisor or core.Supervisor(config)

    def master(self):
        result = self.guard(self.binding['repository'], self.config['git'])
        if result['commit'] != self.binding['expected']['revision']:
            raise RuntimeError('Fresh master differs from the pinned prepared build; rebuild/review required')

    def manifest(self):
        expected = self.binding['expected']
        manifest = {'revision': expected['revision'], 'map': expected['map'],
                    'binaries': {'civ13.dmb': expected['dmb_sha256'], 'civ13.rsc': expected['rsc_sha256']}}
        core.verify_binaries(self.run, manifest, expected['revision'], expected['map'])
        revision = (self.run / 'config/lifecycle-revision.txt').read_text().strip()
        if revision != expected['revision']:
            raise RuntimeError('Prepared runtime lifecycle revision is not the compiled master identity')
        return manifest

    def observe(self):
        self.manifest()
        sup = self.supervisor
        if not sup.state or sup.state.get('phase') == 'stopped':
            if sup.state.get('host'):
                raise RuntimeError('Stopped state retains an ambiguous host identity')
            self.assert_closed(self.config['port'])
            return None
        if sup.state.get('phase') != 'ready' or not sup.alive():
            raise RuntimeError('Previous owned host is not ready or exited unexpectedly')
        if sup.state['revision'] != self.binding['expected']['revision'] or sup.state.get('map') != self.binding['expected']['map']:
            raise RuntimeError('Owned state revision or map differs')
        if Path(sup.state['host']['workdir']).resolve(strict=True) != self.run:
            raise RuntimeError('Owned state points to another runtime directory')
        observed = self.observe_process(sup.state['host'], self.daemon, self.run, self.config['port'])
        status = sup.status()
        sup.accept_ready(status, None)
        if status.get('restart_intent') or status.get('clients'):
            raise RuntimeError('World has clients or an unconsumed restart intent; no lifecycle action')
        return observed | {'dmb_sha256': self.binding['expected']['dmb_sha256'],
                           'rsc_sha256': self.binding['expected']['rsc_sha256']}

    def start(self, operation, generation):
        if self.observe() is not None:
            raise RuntimeError('Start refuses an existing owned process')
        state, _ = core.validate_generation(self.run / 'map_saves', expected_map=self.binding['expected']['map'])
        if state['generation'] != generation:
            raise RuntimeError('Prepared save generation differs; no fallback or fresh round')
        sup = self.supervisor
        # Current saved files must still match any retained acknowledged backup.
        if sup.state.get('backup'):
            receipt = json.loads((Path(sup.state['backup']) / 'receipt.json').read_text())
            if receipt['generation'] != generation or any(core.digest(self.run / 'map_saves' / name) != digest
                    for name, digest in receipt['files'].items()):
                raise RuntimeError('Prepared save does not match the acknowledged backup')
        self.assert_closed(self.config['port'])
        sup.launch_prepared(self.run, self.manifest(), generation, operation, sup.state.get('backup'))
        after = self.observe()
        if after is None:
            raise RuntimeError('Native startup did not establish an owned ready process')
        return after

    def stop(self, operation, before):
        if self.observe() != before:
            raise RuntimeError('Native stop ownership changed before save')
        backup, generation = self.supervisor.stop_saved(operation)
        # stop_saved already verified identity-bound exit, intent and copied raw bytes.
        self.assert_closed(self.config['port'])
        state = dict(self.supervisor.state)
        state.update(phase='stopped', host=None, stopped_host=state['host'],
                     generation=generation, backup=str(backup), operation=operation)
        core.write_json(self.supervisor.state_path, state)
        self.supervisor.state = state
        return generation, core.digest(Path(backup) / 'receipt.json')

    def execute(self, action, operation, before):
        if action not in ('start', 'save-stop', 'restart'):
            raise ValueError('Unsupported native action')
        self.master()
        if self.observe() != before:
            raise RuntimeError('Native ownership changed since the advertised capability')
        result = {}
        generation = self.binding['expected']['generation']
        if action in ('save-stop', 'restart'):
            generation, receipt = self.stop(operation, before)
            result.update(exit_acknowledged=True, save_complete=True,
                          saved_generation=generation, save_receipt_sha256=receipt)
        if action in ('start', 'restart'):
            self.master()  # A failed/offline changed master after stop prevents startup.
            result.update(after=self.start(operation, generation), ready=True,
                          restored_generation=generation)
        else:
            result.update(after=None, ready=False)
        return result
