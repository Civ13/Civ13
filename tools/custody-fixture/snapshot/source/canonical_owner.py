"""Default-off canonical-only owner; never adopts a persisted process."""
import argparse
import json
import os
import re
import signal
import stat
import sys
import time
import threading
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
    directories = ('admin-maintenance', 'bot-control', 'updates', 'backups', 'fixed-cycle')
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


def _fallback_pause():
    """Trusted one-second pacing; a second primitive handles wait failures."""
    try:
        threading.Event().wait(1)
    except BaseException as first:
        try:
            time.sleep(1)
        except BaseException as second:
            if not isinstance(first, Exception):
                first.add_note("Secondary pacing failed: " + type(second).__name__)
                raise first
            if not isinstance(second, Exception):
                second.add_note("Primary pacing failed: " + type(first).__name__)
                raise second
            raise first
        if not isinstance(first, Exception):
            raise first


def retain_command_until_quiescent(supervisor, sleep=time.sleep):
    """Retain registered command custody; never infer exit from an error."""
    import subprocess
    from windows_owned_job import peek_inflight,release_inflight
    pending=None;extra=0;last=None
    while getattr(supervisor,'_fixed_command_active',False):
        try:
            registered=getattr(supervisor,'_fixed_command_job',None)
            inflight=peek_inflight()
            if registered is not None and inflight is not None and registered is not inflight:
                raise RuntimeError('command_job_identity_mismatch')
            job=registered or inflight
            if job is not None:
                if not job.closed:
                    job.wait(timeout=0.5)
                    job.close_command_pipes()
                    job.close()
                current=peek_inflight()
                if current is not None and current is not job:
                    raise RuntimeError('command_job_identity_mismatch')
                if current is job:release_inflight(job)
                supervisor._fixed_command_job=None
                supervisor._fixed_command_active=False
                break
        except subprocess.TimeoutExpired:
            pass
        except BaseException as error:
            if not isinstance(error,Exception):
                if pending is None:pending=error
                else:extra+=1;last=type(error).__name__
        try:
            sleep(0.25)
        except BaseException as error:
            if not isinstance(error,Exception):
                if pending is None:pending=error
                else:extra+=1;last=type(error).__name__
            try:_fallback_pause()
            except BaseException as fallback:
                if not isinstance(fallback,Exception):
                    if pending is None:pending=fallback
                    else:extra+=1;last=type(fallback).__name__
    if pending is not None:
        if extra:pending.add_note('Additional command-retention interruptions: '+str(extra)+'; last: '+last)
        raise pending


def retain_command_preserving_interruption(supervisor, sleep=time.sleep, original=None):
    """Return a deferred error only after registered command custody is settled."""
    pending=original
    while getattr(supervisor,'_fixed_command_active',False):
        try:retain_command_until_quiescent(supervisor,sleep)
        except BaseException as error:
            if pending is None:pending=error
            else:pending.add_note('Additional command-retention interruption: '+type(error).__name__)
            if getattr(supervisor,'_fixed_command_active',False):
                try:_fallback_pause()
                except BaseException as pacing_error:
                    if pending is None:pending=pacing_error
                    else:pending.add_note('Command retention pacing failed: '+type(pacing_error).__name__)
    return pending


def retain_until_exit(supervisor, sleep):
    """Keep the lease until the owned child exits, then propagate cancellation."""
    retain_command_until_quiescent(supervisor, sleep)
    child = supervisor.child
    if child is None:
        return
    pending = None
    extra_interruptions = 0
    while True:
        try:
            if child.poll() is not None:
                break
        except Exception:
            # An unreadable handle is not evidence of exit.
            pass
        except BaseException as interruption:
            if pending is None: pending = interruption
            else: extra_interruptions += 1
        failed_wait = False
        try:
            sleep(1)
        except Exception:
            # An error is not exit; use a separate trusted pacing primitive.
            failed_wait = True
        except BaseException as interruption:
            failed_wait = True
            if pending is None: pending = interruption
            else: extra_interruptions += 1
        if failed_wait:
            try:
                _fallback_pause()
            except Exception:
                # If all pacing primitives fail, custody remains held.
                pass
            except BaseException as interruption:
                if pending is None: pending = interruption
                else: extra_interruptions += 1
    if pending is not None:
        if extra_interruptions:
            pending.add_note("Additional interruptions while retaining the child: " + str(extra_interruptions))
        raise pending


def retain_preserving_interruption(supervisor, sleep, original=None):
    """Recheck custody after any unexpected wait error; never release early."""
    pending=original
    additional=0
    last_type=None
    while True:
        try:
            retain_until_exit(supervisor, sleep)
            break
        except BaseException as error:
            if pending is None:
                pending=error
            else:
                additional+=1
                last_type=type(error).__name__
            try:
                _fallback_pause()
            except BaseException as pace_error:
                additional+=1
                last_type=type(pace_error).__name__
    if additional:
        pending.add_note("Child retention interrupted " + str(additional) + " time(s); last: " + last_type)
    if original is None and pending is not None:
        raise pending


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
            channel_profile = None
            if config.get('fixed_cycle_channel_enabled') is True:
                import fixed_cycle_channel
                channel_profile = fixed_cycle_channel.owner_preflight(supervisor, lease)
            updater = updater_factory(config, supervisor=supervisor)
            def before_spawn():
                lease.require(root / 'supervisor.lock')
                if cancelled():
                    raise RuntimeError('Canonical owner cancelled before spawn')
            updater.start_initial(operation=uuid.uuid4().hex, expected=expected, held_lock=lease,
                                  before_effect=before_spawn, authority='owner')
            coordinator = coordinator_factory(config, supervisor, lease)
            channel = None
            if channel_profile is not None:
                channel = fixed_cycle_channel.owner_after_ready(supervisor, lease, *channel_profile)
            def before_update():
                lease.require(root / 'supervisor.lock')
                if cancelled():
                    raise RuntimeError('Canonical owner cancelled before maintenance admission')
            while not cancelled():
                lease.require(root / 'supervisor.lock')
                if getattr(supervisor, '_fixed_cycle_halted', False) is not False:
                    raise RuntimeError('Fixed cycle outcome requires owner reconciliation')
                if channel is not None and not channel.closed:
                    channel.poll_once()
                    if getattr(supervisor, '_fixed_cycle_halted', False) is not False:
                        raise RuntimeError('Fixed cycle outcome requires owner reconciliation')
                coordinator.poll_admin(before_update=before_update)
                if getattr(supervisor, '_fixed_cycle_halted', False) is not False:
                    raise RuntimeError('Fixed cycle outcome requires owner reconciliation')
                if not cancelled():
                    sleep(1)
            if supervisor.child is not None:
                report('Canonical owner cancelled; retaining the owned child until exit.')
        except BaseException as original:
            try:
                report('Canonical owner stopped polling; retaining any owned child until exit.')
            except BaseException as report_error:
                original.add_note('Owner report interrupted: ' + type(report_error).__name__)
            retain_preserving_interruption(supervisor, sleep, original)
            raise
        else:
            retain_preserving_interruption(supervisor, sleep)


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
