"""Own one isolated Europe daemon and verify its real native recovery cycle."""
import argparse
from contextlib import contextmanager
import hashlib
import json
from pathlib import Path
import socket
import subprocess
import time

from prepare import BASE, prepare
from query import request

PROTECTED_PORTS = (18459, 18460, 18461, 18462)


@contextmanager
def owned_daemon(command, **kwargs):
    process = subprocess.Popen(command, **kwargs)
    try:
        yield process
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=30)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=30)


def diagnostic_failures(root):
    markers = ('runtime error:', 'bad ref', 'bad loc', '##error', 'bug:')
    failures = []
    paths = [root / 'daemon.stdout.log', root / 'daemon.stderr.log', root / 'game/native.log']
    paths += sorted((root / 'game/data/logs/runtime').glob('*'))
    for path in paths:
        if not path.is_file():
            continue
        with path.open(encoding='utf-8', errors='replace') as stream:
            for number, line in enumerate(stream, 1):
                if any(marker in line.lower() for marker in markers):
                    failures.append({'path': str(path.relative_to(root)), 'line': number,
                                     'message': line.strip()[:400]})
    return failures


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2), encoding='utf-8')


def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def compare(before, after, receipt):
    """Fail closed on incomplete recovery, identity changes or lost contents."""
    if before['session'] == after['session']:
        raise AssertionError('Native boot session did not change')
    for field in ('session', 'source', 'map', 'maxx', 'maxy', 'maxz', 'game_id'):
        if before[field] != receipt['status'][field]:
            raise AssertionError(f'Pre-reboot receipt changed {field}')
    for field in ('source', 'map', 'maxx', 'maxy', 'maxz', 'game_id'):
        if before[field] != after[field]:
            raise AssertionError(f'Recovery changed {field}')
    if not after['playing'] or not after['import_complete']:
        raise AssertionError('Recovery did not resume PLAYING with completed import')
    if any(after[field] for field in ('save_busy', 'restart_busy', 'restart_hold', 'intent')):
        raise AssertionError('Recovery retained a lock, hold or restart intent')
    if after['error'] or after['storage_error']:
        raise AssertionError('Recovery reported a persistence error')
    if receipt['generation'] != after['generation']:
        raise AssertionError('Completed generation changed during reboot')
    for field in ('season', 'time_of_day'):
        if receipt['status'][field] != after[field]:
            raise AssertionError(f'Recovery changed saved {field}')
    # The research clock advances during ordinary gameplay; only backwards
    # movement across the saved boundary is invalid.
    if after['research_clock'] < receipt['status']['research_clock']:
        raise AssertionError('Research clock moved backwards across recovery')
    for status in (before, receipt['status'], after):
        if status['clients'] != 0:
            raise AssertionError('Headless probe admitted a player session')
        fixture = status['fixture']
        if not fixture['seeded'] or fixture['crates'] != 1 or fixture['nested_knives'] != 1:
            raise AssertionError('Representative crate/nested item missing or duplicated')
        if fixture['baseline'] != before['fixture']['baseline']:
            raise AssertionError('Representative object identity or coordinates changed')


def run(args):
    if args.port in PROTECTED_PORTS or not 1024 <= args.port <= 65535:
        raise ValueError('Existing protected hosts and invalid ports are excluded')
    if args.deadline < 1200:
        raise ValueError('Full-map save/recovery deadline must be at least 1200 seconds')
    # Refuse occupied ports before preparation; the process ownership check
    # below is still required because a competing process could bind later.
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', args.port))
    root = args.output.resolve()
    manifest = prepare(args.repository, root)
    game = root / 'game'
    config = game / 'config/config.txt'
    # Only exported public configuration is used. Remove networking switches
    # before global initialization; no credentials or live saves are copied.
    blocked = {'HUB', 'SERVER', 'ALLOW_WEBCLIENT', 'WEBHOOK_CAN_FIRE',
               'WEBHOOK_ADDRESS', 'WEBHOOK_KEY', 'TORBAN', 'IPINTEL_EMAIL'}
    lines = config.read_text(encoding='utf-8').splitlines()
    config.write_text('\n'.join(line for line in lines
                               if not line.strip() or line.strip().split()[0].upper() not in blocked)
                      + '\n', encoding='utf-8')
    manifest['isolated_config_sha256'] = digest(config)
    write_json(root / 'prepare.json', manifest)
    compiler = args.byond_bin / 'dm.exe'
    with (root / 'compile.log').open('w', encoding='utf-8') as log:
        compiled = subprocess.run([str(compiler), '-max_errors', '0', 'full-map-europe.dme'],
                                  cwd=game, stdout=log, stderr=subprocess.STDOUT, timeout=300)
    log = (root / 'compile.log').read_text(encoding='utf-8', errors='replace')
    if compiled.returncode or '0 errors, 0 warnings' not in log or '516.1681' not in log:
        raise RuntimeError('Pinned native compiler did not produce a clean build')
    binary = game / 'full-map-europe.dmb'
    token = (game / 'config/full-map-probe-token.txt').read_text(encoding='ascii').strip()
    command = [str(args.byond_bin / 'dd.exe'), binary.name, str(args.port),
               '-invisible', '-safe', '-params', f'tested_commit={BASE}', '-log', 'native.log']
    started = time.time()
    binary_hashes = {'dmb_sha256': digest(binary), 'rsc_sha256': digest(binary.with_suffix('.rsc'))}
    with (root / 'daemon.stdout.log').open('w') as out, (root / 'daemon.stderr.log').open('w') as err:
        with owned_daemon(command, cwd=game, stdout=out, stderr=err) as process:
            write_json(root / 'host.json', {'pid': process.pid, 'started_unix': started,
                       'command': command, 'port': args.port, 'source_commit': BASE,
                       **binary_hashes})
            try:
                def poll(predicate, seconds, phase):
                    deadline = time.monotonic() + seconds
                    last_error = None
                    while time.monotonic() < deadline:
                        if process.poll() is not None:
                            raise RuntimeError(f'Owned daemon exited during {phase}')
                        try:
                            status = request(args.port, token, 'status', 'observe')
                            if status.get('source') != BASE:
                                raise RuntimeError('Host source identity differs')
                            if status.get('error') or status.get('storage_error'):
                                raise RuntimeError('Persistence reported a failure; preserve the output')
                            if status['clients'] != 0:
                                raise RuntimeError('Headless probe admitted a player session')
                            with (root / 'observations.jsonl').open('a', encoding='utf-8') as stream:
                                stream.write(json.dumps({'phase': phase, 'elapsed': time.time() - started,
                                                         'status': status}) + '\n')
                            progress_file = game / 'world_save_progress.json'
                            if progress_file.exists():
                                try:
                                    progress = json.loads(progress_file.read_text(encoding='utf-8'))
                                    with (root / 'save-progress.jsonl').open('a', encoding='utf-8') as stream:
                                        stream.write(json.dumps({'elapsed': time.time() - started,
                                                                 'progress': progress}) + '\n')
                                except (OSError, ValueError):
                                    pass  # Diagnostic replacement is intentionally non-atomic.
                            if predicate(status):
                                return status
                        except (OSError, ValueError) as error:
                            last_error = type(error).__name__
                        time.sleep(2)
                    raise TimeoutError(f'{phase} deadline expired; last transport error: {last_error}')

                initial = poll(lambda s: s['state'] == 1 and not s['restart_hold'], 600, 'startup')
                # Query response alone cannot establish PID ownership.
                ownership = subprocess.run(['powershell', '-NoProfile', '-Command',
                    f"$listeners = @(Get-NetTCPConnection -State Listen -LocalPort {args.port} -ErrorAction Stop); "
                    f"[ordered]@{{owners=@($listeners | Select-Object -ExpandProperty OwningProcess -Unique); "
                    f"addresses=@($listeners | Select-Object -ExpandProperty LocalAddress -Unique); "
                    f"process_start_utc=(Get-Process -Id {process.pid}).StartTime.ToUniversalTime().ToString('o')}} | ConvertTo-Json -Compress"],
                    capture_output=True, text=True, check=True, timeout=30)
                listener = json.loads(ownership.stdout)
                if set(listener['owners']) != {process.pid}:
                    raise RuntimeError('Listener is not exclusively owned by the new daemon')
                write_json(root / 'listener.json', listener)
                for bad_token, action, session in ((('0' * 64 if token != '0' * 64 else '1' * 64), 'status', 'observe'),
                                                    (token, 'start', 'stale-session')):
                    try:
                        request(args.port, bad_token, action, session)
                    except PermissionError:
                        continue
                    raise AssertionError('Authentication negative control was accepted')
                request(args.port, token, 'start', initial['session'])
                before = poll(lambda s: s['ready'] and s['fixture']['seeded'], 1200, 'settling')
                write_json(root / 'before.json', before)
                request(args.port, token, 'restart', before['session'])
                after = poll(lambda s: s['session'] != before['session'] and s['import_complete']
                             and not any(s[k] for k in ('save_busy', 'restart_busy', 'restart_hold', 'intent')),
                             args.deadline, 'save-reboot-import')
                write_json(root / 'after.json', after)
                receipt = json.loads((game / 'full-map-before-reboot.json').read_text(encoding='utf-8'))
                compare(before, after, receipt)
                for name, expected in receipt['files_md5'].items():
                    if Path(name).name != name:
                        raise AssertionError('Invalid save receipt path')
                    if hashlib.md5((game / 'map_saves' / name).read_bytes()).hexdigest() != expected:
                        raise AssertionError(f'Completed save file changed: {name}')
                # Production identity hashes map.txt and round.json synchronously.
                # Compare raw text MD5 exactly as the transaction does.
                for key, name in (('metadata', 'map.txt'), ('round', 'round.json')):
                    if hashlib.md5((game / 'map_saves' / name).read_bytes()).hexdigest() != receipt[key]:
                        raise AssertionError(f'Completed {name} changed after reboot')
                saves = {str(p.relative_to(game)): {'bytes': p.stat().st_size, 'sha256': digest(p)}
                         for p in sorted((game / 'map_saves').rglob('*')) if p.is_file()}
                failures = diagnostic_failures(root)
                write_json(root / 'diagnostics.json', failures)
                if failures:
                    raise AssertionError('Native runtime diagnostics invalidate recovery acceptance')
                write_json(root / 'result.json', {'passed': True, 'elapsed_seconds': time.time() - started,
                           'generation': after['generation'], 'saves': saves,
                           'limits': ['Injected representative objects; no real player/client acceptance',
                                      'Not an atomic snapshot or TEST1714 supervisor test']})
            except BaseException as error:
                write_json(root / 'failure.json', {'type': type(error).__name__, 'message': str(error),
                           'elapsed_seconds': time.time() - started})
                raise
            finally:
                # The sole process handle belongs to this invocation. Never discover
                # and stop hosts by name, port or a stale PID loaded from disk.
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=30)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=30)
                write_json(root / 'exit.json', {'pid': process.pid, 'exit_code': process.returncode})
    return root


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--port', type=int, default=18463)
    parser.add_argument('--deadline', type=int, default=1800)
    print(run(parser.parse_args()))
