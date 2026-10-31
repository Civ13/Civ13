"""Default-off canonical-only owner; never adopts a persisted process."""
import argparse
import json
import os
import re
import signal
import stat
import sys
import time
import uuid
from pathlib import Path

import canonical_update as canonical
import supervisor as core


def expected_binding(config):
    if (config.get('canonical_owner_enabled') is not True or
            config.get('canonical_update_enabled') is not True or
            config.get('canonical_bot_enabled') is not False or
            config.get('canonical_initial_start_enabled') is not True):
        raise RuntimeError('Canonical-only owner is disabled or bot control is not disabled')
    fields = (('canonical_owner_revision', r'[0-9a-f]{40}'),
              ('canonical_owner_dmb_sha256', r'[0-9a-f]{64}'),
              ('canonical_owner_rsc_sha256', r'[0-9a-f]{64}'),
              ('canonical_initial_generation', r'round-v2:[0-9a-f]{32}'))
    for key, pattern in fields:
        if not isinstance(config.get(key), str) or re.fullmatch(pattern, config[key]) is None:
            raise RuntimeError('Canonical-only owner requires exact reviewed pins')
    return {'revision': config['canonical_owner_revision'], 'map': config['map'],
            'generation': config['canonical_initial_generation'],
            'dmb_sha256': config['canonical_owner_dmb_sha256'],
            'rsc_sha256': config['canonical_owner_rsc_sha256']}


def require_empty_history(root):
    """A new owner must never reinterpret persisted ownership or receipts."""
    files = ('state.json', 'HALTED.json', 'update-state.json')
    directories = ('admin-maintenance', 'bot-control', 'updates', 'backups')
    for name in files + directories:
        path = root / name
        try:
            metadata = path.lstat()
        except FileNotFoundError:
            continue
        except OSError as error:
            raise RuntimeError('Cannot inspect existing owner records') from error
        reparse = bool(getattr(metadata, 'st_file_attributes', 0) &
                       getattr(stat, 'FILE_ATTRIBUTE_REPARSE_POINT', 0x400))
        if name in files or reparse or not stat.S_ISDIR(metadata.st_mode):
            raise RuntimeError('Existing records require reconciliation')
        try:
            with os.scandir(path) as entries:
                if next(entries, None) is not None:
                    raise RuntimeError('Existing records require reconciliation')
        except OSError as error:
            raise RuntimeError('Cannot inspect existing owner records') from error


def retain_until_exit(supervisor, sleep):
    """Do not release the lease while the retained child may still be alive."""
    child = supervisor.child
    if child is None:
        return
    while True:
        try:
            if child.poll() is not None:
                return
        except Exception:
            # An unreadable handle is not evidence of exit.
            pass
        try:
            sleep(1)
        except Exception:
            # A failed wait is not evidence that the child exited either.
            pass


def report(message):
    try:
        print(message, file=sys.stderr, flush=True)
    except Exception:
        # A closed log must not release ownership of a possibly running child.
        pass


def run(config, *, cancelled, sleep=time.sleep, supervisor_factory=core.Supervisor,
        updater_factory=canonical.CanonicalUpdater, coordinator_factory=canonical.CanonicalCoordinator):
    expected = expected_binding(config)
    _, root = canonical.configuration(config)
    with core.exclusive_lock(root / 'supervisor.lock') as lease:
        require_empty_history(root)
        if cancelled():
            return
        supervisor = supervisor_factory(config)
        try:
            updater = updater_factory(config, supervisor=supervisor)
            def before_spawn():
                lease.require(root / 'supervisor.lock')
                if cancelled():
                    raise RuntimeError('Canonical owner cancelled before spawn')
            updater.start_initial(operation=uuid.uuid4().hex, expected=expected, held_lock=lease,
                                  before_effect=before_spawn, authority='owner')
            coordinator = coordinator_factory(config, supervisor, lease)
            def before_update():
                lease.require(root / 'supervisor.lock')
                if cancelled():
                    raise RuntimeError('Canonical owner cancelled before maintenance admission')
            while not cancelled():
                lease.require(root / 'supervisor.lock')
                coordinator.poll_admin(before_update=before_update)
                if not cancelled():
                    sleep(1)
        except Exception:
            report('Canonical owner stopped polling; retaining any owned child until exit.')
            retain_until_exit(supervisor, sleep)
            raise
        if supervisor.child is not None:
            report('Canonical owner cancelled; retaining the owned child until exit.')
        retain_until_exit(supervisor, sleep)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True, type=Path)
    args = parser.parse_args()
    config = json.loads(args.config.read_text(encoding='utf-8-sig'))
    cancelled = False
    def request_stop(_signum, _frame):
        nonlocal cancelled
        cancelled = True
    previous = {}
    try:
        for sig in (signal.SIGINT, signal.SIGTERM):
            previous[sig] = signal.signal(sig, request_stop)
        run(config, cancelled=lambda: cancelled)
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


if __name__ == '__main__':
    main()
