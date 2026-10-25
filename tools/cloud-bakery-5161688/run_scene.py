"""One reviewed hosted attempt. Genuine Civ13 guest camera, no production account."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import socket
import time
from guard_config import digest, LIMITS

REVISION = '58404f5bd16e3fed80f1d9844c5db3edd144942c'
TITLE = 'Civ13 native bakery cloud'


def require(ok, reason):
    if not ok:
        raise RuntimeError(reason)


def bounded_text(path, cap=65536):
    if not path.exists():
        return None
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= cap, 'Unexpected diagnostic file')
    return path.read_text(errors='replace').strip()


def socket_contract(rows, server=False, port=None):
    for row in rows:
        require(row['protocol'] == 'tcp' and row['address'] == '127.0.0.1', 'Non-loopback or unexpected owned socket')
        require(row['remote'] in ('0.0.0.0', '127.0.0.1'), 'Non-loopback owned peer')
        require(row['state'] != 'listen' or (server and row['port'] == port), 'Unexpected owned listener')


def run(binary, source, output):
    require(os.name == 'nt' and os.environ.get('GITHUB_ACTIONS') == 'true' and os.environ.get('RUNNER_ENVIRONMENT') == 'github-hosted', 'Only reviewed hosted Windows runner')
    require(os.environ.get('GITHUB_REPOSITORY') == 'Civ13/Civ13' and os.environ.get('GITHUB_RUN_ATTEMPT') == '1', 'Wrong repository/attempt')
    require(os.environ.get('GITHUB_REF') == 'refs/heads/ci/cloud-bakery-5161688-20261025', 'Wrong activation branch')
    require(not output.exists(), 'Fresh output required; no retry/overwrite')
    output.mkdir()
    from windows import Adapter
    from capture import capture_owned
    from acquire import check_dependencies
    started = time.monotonic()
    owners = []
    port = None
    result = {'status': 'FAILED', 'head': os.environ.get('GITHUB_SHA'), 'run_id': os.environ.get('GITHUB_RUN_ID'),
              'scene_revision': REVISION, 'engine': '516.1688', 'scope': 'native staged Civ13 bakery; guest camera, not ordinary-player acceptance',
              'cleanup': [], 'captures': {}, 'execution_source_sha256': {p.name: digest(p) for p in Path(__file__).parent.glob('*.py')}}
    def budget():
        require(time.monotonic()-started < 165, 'Shared 165-second work budget exhausted')
    def watch():
        budget()
        for role, adapter, process in owners:
            if process is None or adapter.exited(process):
                continue
            require(adapter.memory(process.process) <= LIMITS['process_private_bytes'], 'Owned memory cap exceeded')
            require(adapter.times(process)[1] <= 60 and adapter.accounting().total == 1, 'Owned CPU/child cap exceeded')
            socket_contract(adapter.sockets(process), role == 'server', port if role == 'server' else None)
        for path in output.glob('*.log'):
            require(path.stat().st_size <= 1024**2, 'Log cap exceeded')
        stop = bounded_text(source/'filming-stop.txt')
        require(stop is None, 'Native scene stopped: '+str(stop)[:500])
        budget()
    def launch(role, executable, args, visible=False):
        budget()
        adapter = Adapter()
        owners.append((role, adapter, None))
        adapter.preflight(LIMITS)
        require(adapter.free() >= 2*1024**3, 'Insufficient current free RAM')
        adapter.open(creation_guard=budget)
        process = adapter.launch([str(binary/executable)]+args, source, output, role, visible, creation_guard=budget)
        owners[-1] = (role, adapter, process)
        return adapter, process
    def wait_file(name, expected=None):
        while True:
            watch()
            for role, adapter, process in owners:
                if role in ('server', 'client'):
                    require(not adapter.exited(process), role+' exited before scene evidence')
            value = bounded_text(source/name)
            if value is not None:
                if expected is not None:
                    require(value == expected, 'Native identity/phase receipt mismatch: '+name)
                return value
            time.sleep(.1)
    try:
        result['source'] = json.loads((source/'source-receipt.json').read_text())
        require(result['source']['source_revision'] == REVISION, 'Wrong source revision')
        result['dependencies'] = check_dependencies(binary)
        from acquire import verify_files
        verify_files(binary.parent.parent)
        compiler, compiled = launch('compiler', 'dm.exe', ['-max_errors', '0', 'civ13.dme'])
        while not compiler.exited(compiled):
            watch(); time.sleep(.1)
        result['compiler'] = compiler.finish(compiled)
        logs = ''.join(bounded_text(p) or '' for p in output.glob('compiler.*.log'))
        require(result['compiler']['exit_code'] == 0 and '0 errors, 0 warnings' in logs, 'Exact bakery compile failed')
        require('DM compiler version 516.1688' in logs, 'Wrong native compiler version')
        sealed = {name: digest(source/name) for name in ('civ13.dmb', 'civ13.rsc')}
        result['compiled_sha256'] = sealed
        require(all((source/n).stat().st_size <= 256*1024**2 for n in sealed), 'Compiled artifact cap')
        with socket.socket() as reservation:
            reservation.bind(('127.0.0.1', 0)); port = reservation.getsockname()[1]
        require(port >= 1024, 'Privileged port rejected')
        server, serving = launch('server', 'dd.exe', ['civ13.dmb', str(port), '-ip', '127.0.0.1', '-invisible', '-trusted', '-nowebclient', '-params', 'observer_mode=engine_guest_camera&filming_port='+str(port)])
        wait_file('cloud-listening.txt', 'port=%d;version=516;build=1688' % port)
        rows = server.sockets(serving)
        socket_contract(rows, True, port)
        require(any(r['state'] == 'listen' and r['port'] == port for r in rows), 'Owned loopback listener absent')
        result['server_listener'] = rows
        require(all(digest(source/n) == v for n,v in sealed.items()), 'Compiled input changed')
        client, playing = launch('client', 'dreamseeker.exe', ['byond://127.0.0.1:%d##guest' % port], True)
        result['client'] = wait_file('cloud-client.txt', 'guest=1;version=516;build=1688')
        wait_file('filming-ready.txt')
        watch(); time.sleep(.5); watch()
        result['captures']['before'] = capture_owned(client, playing, output/'bakery-before.png', TITLE, (480,480))
        (source/'cloud-stage-captured.txt').write_text('captured\n')
        take = json.loads(wait_file('filming-take.json'))
        require(take['engine'] == '516.1688' and take['source'] == REVISION, 'Take binding mismatch')
        watch(); time.sleep(.5); watch()
        result['captures']['after'] = capture_owned(client, playing, output/'bakery-after.png', TITLE, (480,480))
        require(digest(output/'bakery-before.png') != digest(output/'bakery-after.png'), 'Unchanged scene images need inspection; not accepted')
        result['take'] = take
        result['native_checks'] = bounded_text(source/'filming-checks.txt')
        watch()
        result['status'] = 'PASS_NATIVE_CIV13_BAKERY_STILLS'
    except BaseException as error:
        result['error'] = str(error)[:1024]
    finally:
        for role, adapter, process in reversed(owners):
            try:
                row = adapter.cleanup(process, max(0, min(5, 180-(time.monotonic()-started))))
            except BaseException as error:
                row = {'all_exited': False, 'error': type(error).__name__}
            result['cleanup'].append({'role': role, **row})
        if not all(row['all_exited'] for row in result['cleanup']):
            result['status'] = 'FAILED_CLEANUP'
        result['elapsed_seconds'] = time.monotonic()-started
        if result['elapsed_seconds'] >= 180:
            result['status'] = 'FAILED_TOTAL_BUDGET'
        raw = json.dumps(result, indent=2)
        require(len(raw) < 65536, 'Receipt cap exceeded')
        (output/'receipt.json').write_text(raw+'\n')
        for name in ('source-receipt.json', 'filming-take.json', 'filming-checks.txt', 'filming-stop.txt'):
            value = bounded_text(source/name)
            if value is not None:
                (output/name).write_text(value+'\n')
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--binary', type=Path, required=True)
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--execute-reviewed-scene', action='store_true')
    a = p.parse_args()
    require(a.execute_reviewed_scene, 'Explicit reviewed scene entry required')
    result = run(a.binary.resolve(), a.source.resolve(), a.output.resolve())
    print(result['status'])
    raise SystemExit(0 if result['status'] == 'PASS_NATIVE_CIV13_BAKERY_STILLS' else 2)
