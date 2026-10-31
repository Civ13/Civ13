"""Owned native operations behind the bot consumer's fixed protocol.

Imports do not read tokens, contact a world, or launch a process. The live
Windows adapter needs psutil for actual executable/cwd/listener inspection.
"""
from pathlib import Path
import json
import os

import supervisor as core
from master_guard import verified_master


def require_unique_loopback_listener(pid, port, process_rows, system_rows, listen_status):
    return core.require_unique_listener(pid, port, '127.0.0.1', process_rows, system_rows, listen_status)


def windows_observation(host, daemon, run, port):
    return core.windows_listener_observation(host, daemon, run, port, '127.0.0.1')


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
        if supervisor is None:
            raise RuntimeError('A same-process supervisor owner is required')
        self.supervisor = supervisor

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
        # The listener observation must agree with the boot session retained by
        # this exact owner, not merely with a same-map/revision responder.
        sup.require_owned_session(core.startup_session(status))
        sup.accept_ready(status, None)
        if status.get('restart_intent') or status.get('clients'):
            raise RuntimeError('World has clients or an unconsumed restart intent; no lifecycle action')
        return observed | {'dmb_sha256': self.binding['expected']['dmb_sha256'],
                           'rsc_sha256': self.binding['expected']['rsc_sha256']}

    def start(self, operation, generation, *, before_effect):
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
        def bind_startup(status):
            self.observe_process(sup.state['host'], self.daemon, self.run, self.config['port'])
            if not sup.alive():
                raise RuntimeError('Owned process exited during listener binding')
            confirmed = sup.status()
            if core.startup_session(confirmed) != core.startup_session(status):
                raise RuntimeError('Startup listener session changed during binding')
            return confirmed
        sup.launch_prepared(self.run, self.manifest(), generation, operation, sup.state.get('backup'),
                            readiness_check=bind_startup, before_spawn=before_effect)
        after = self.observe()
        if after is None:
            raise RuntimeError('Native startup did not establish an owned ready process')
        return after

    def stop(self, operation, before, *, before_effect):
        if self.observe() != before:
            raise RuntimeError('Native stop ownership changed before save')
        backup, generation = self.supervisor.stop_saved(operation, before_mutation=before_effect)
        # stop_saved already verified identity-bound exit, intent and copied raw bytes.
        self.assert_closed(self.config['port'])
        state = dict(self.supervisor.state)
        state.update(phase='stopped', host=None, stopped_host=state['host'],
                     generation=generation, backup=str(backup), operation=operation)
        core.write_json(self.supervisor.state_path, state)
        self.supervisor.state = state
        return generation, core.digest(Path(backup) / 'receipt.json')

    def execute(self, action, operation, before, *, before_effect):
        if action not in ('start', 'save-stop', 'restart'):
            raise ValueError('Unsupported native action')
        if not callable(before_effect):
            raise RuntimeError('Native effect admission is required')
        self.master()
        if self.observe() != before:
            raise RuntimeError('Native ownership changed since the advertised capability')
        result = {}
        generation = self.binding['expected']['generation']
        if action in ('save-stop', 'restart'):
            generation, receipt = self.stop(operation, before, before_effect=before_effect)
            result.update(exit_acknowledged=True, save_complete=True,
                          saved_generation=generation, save_receipt_sha256=receipt)
        if action in ('start', 'restart'):
            self.master()  # A failed/offline changed master after stop prevents startup.
            # A restart remains one admitted transaction after its save begins.
            start_admission = before_effect if action == 'start' else lambda: None
            result.update(after=self.start(operation, generation, before_effect=start_admission), ready=True,
                          restored_generation=generation)
        else:
            result.update(after=None, ready=False)
        return result
