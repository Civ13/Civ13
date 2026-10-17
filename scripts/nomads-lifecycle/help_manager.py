"""Optional help worker observer. Never controls, queries or restarts the game."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import signal
import subprocess
import time
import uuid

from supervisor import exclusive_lock, process_identity


class HelpManager:
    """Fail closed on uncertain ownership; all process effects are injectable."""

    def __init__(self, root, python, bridge, config, *, identity=process_identity,
                 spawn=subprocess.Popen, clock=time.monotonic):
        self.root = Path(root).resolve(strict=True)
        self.python, self.bridge, self.config = map(Path, (python, bridge, config))
        self.identity, self.spawn, self.clock = identity, spawn, clock
        self.receipt = self.root / 'help-manager.json'
        self.child = None
        self.record = None
        self.stopping = None
        self.log = None
        self.attempts = 0
        self.next_attempt = 0
        self.run_key = None
        self.external = None
        # Never adopt across manager restarts. A pre-spawn intent also blocks
        # restart after a crash between Popen and recording process identity.
        self.uncertain = False
        if self.receipt.exists():
            saved = json.loads(self.receipt.read_text(encoding='utf-8'))
            self.uncertain = saved.get('worker') is not None
            self.run_key = saved.get('run')
            self.attempts = saved.get('attempts', 0)
            self.external = saved.get('external')

    def report(self, status, worker=None):
        value = {'version': 1, 'status': status, 'run': self.run_key,
                 'attempts': self.attempts, 'worker': worker, 'external': self.external}
        temporary = self.receipt.with_suffix('.tmp')
        temporary.write_text(json.dumps(value, indent=2), encoding='utf-8')
        temporary.replace(self.receipt)
        return status

    def target(self):
        state = json.loads((self.root / 'state.json').read_text(encoding='utf-8-sig'))
        if state.get('phase') != 'ready':
            return None
        host = state['host']
        if type(host['pid']) is not int or type(host['creation_filetime']) is not int:
            raise ValueError('Invalid host identity')
        run = Path(host['workdir']).resolve(strict=True)
        if run.parent != (self.root / 'runs').resolve(strict=True):
            raise ValueError('Run outside runtime root')
        if self.identity(host['pid']) != host['creation_filetime']:
            return None
        return {'path': str(run), 'pid': host['pid'], 'creation': host['creation_filetime']}

    def stop(self):
        if self.child is not None and self.stopping is None:
            Path(self.record['stop_file']).touch(exist_ok=True)
            self.stopping = self.clock()

    def tick(self):
        if self.uncertain:
            # Preserve the original ownership record for operator reconciliation.
            return 'ownership_uncertain'
        try:
            target = self.target()
        except (OSError, ValueError, KeyError):
            target = None
        if self.child is not None:
            if self.child.poll() is not None:
                self.log.close()
                self.child, self.log = None, None
                self.record, self.stopping = None, None
                # A stale worker.lock always needs operator inspection.
                self.next_attempt = self.clock() + (10, 30, 90)[min(self.attempts, 3) - 1]
                return self.report('worker_exited')
            if self.identity(self.child.pid) != self.record['creation']:
                self.uncertain = True
                return self.report('ownership_uncertain', self.record)
            if target != self.run_key:
                self.stop()
            if self.stopping is not None:
                status = 'stop_timeout' if self.clock() - self.stopping >= 150 else 'stopping'
                # Never force-kill a parent with an in-flight model child.
                return self.report(status, self.record)
            return self.report('running', self.record)
        if target is None:
            return self.report('waiting_for_ready_game')
        if self.external is not None:
            # An external worker in an older run must also block a new run.
            # Unknown/recycled identities require explicit reconciliation.
            if (Path(self.external['lock']).exists() or
                    self.external.get('pid') is None or
                    self.identity(self.external['pid']) is not None):
                return self.report('external_worker')
            self.external = None
        if target != self.run_key:
            self.run_key, self.attempts, self.next_attempt = target, 0, 0
        lock = Path(target['path']) / 'SQL/player-help/worker.lock'
        if lock.exists():
            self.external = {'lock': str(lock), 'pid': None}
            try:
                pid = int((lock / 'pid').read_text(encoding='ascii'))
                created = self.identity(pid)
                if pid > 0 and created is not None:
                    self.external.update(pid=pid, creation=created)
            except (OSError, ValueError):
                pass
            return self.report('external_worker')
        if self.attempts >= 3:
            return self.report('attempts_exhausted')
        if self.clock() < self.next_attempt:
            return self.report('backoff')
        if not all(path.is_file() for path in (self.python, self.bridge, self.config)):
            return self.report('optional_files_unavailable')
        self.attempts += 1
        stop_file = self.root / ('help-stop-' + uuid.uuid4().hex)
        self.record = {'intent': uuid.uuid4().hex, 'stop_file': str(stop_file)}
        self.report('starting', self.record)
        self.log = (self.root / 'help-worker.log').open('ab')
        try:
            self.child = self.spawn([str(self.python), str(self.bridge),
                '--game-root', target['path'], '--config', str(self.config),
                '--stop-file', str(stop_file)], cwd=target['path'],
                stdin=subprocess.DEVNULL, stdout=self.log, stderr=self.log,
                creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        except OSError:
            self.log.close()
            self.log, self.record = None, None
            self.next_attempt = self.clock() + (10, 30, 90)[self.attempts - 1]
            return self.report('spawn_failed')
        # Failure retains the starting receipt. Do not launch another worker.
        created = self.identity(self.child.pid)
        if created is None:
            self.stop()
            self.uncertain = True
            return self.report('ownership_uncertain', self.record)
        self.record.update(pid=self.child.pid, creation=created)
        return self.report('running', self.record)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for argument in ('root', 'python', 'bridge', 'config'):
        parser.add_argument('--' + argument, type=Path, required=True)
    parser.add_argument('--stop-file', type=Path,
                        help='Graceful observer shutdown marker; default ROOT/help-manager.stop')
    args = parser.parse_args()
    stop_file = args.stop_file or args.root / 'help-manager.stop'
    stopping = False

    def request_stop(*_):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGINT, request_stop)
    signal.signal(signal.SIGTERM, request_stop)
    with exclusive_lock(args.root / 'help-manager.lock'):
        manager = HelpManager(args.root, args.python.resolve(strict=True),
                              args.bridge.resolve(), args.config.resolve())
        while True:
            if stop_file.exists():
                stopping = True
            if stopping:
                manager.stop()
                if manager.child is None:
                    break
            status = manager.tick()
            if status in ('stop_timeout', 'ownership_uncertain'):
                break
            time.sleep(5)


if __name__ == '__main__':
    main()
