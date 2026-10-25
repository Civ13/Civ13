"""One reviewed hosted attempt. Genuine Civ13 guest camera, no production account."""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import socket
import time
from guard_config import digest, LIMITS

REVISION = '58404f5bd16e3fed80f1d9844c5db3edd144942c'
TITLE = 'Civ13 native bakery cloud'
OUTBOUND_DEADLINE = datetime(2026, 10, 26, 16, 36, 18, tzinfo=timezone.utc)


def require(ok, reason):
    if not ok:
        raise RuntimeError(reason)


def bounded_text(path, cap=65536):
    if not path.exists():
        return None
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= cap, 'Unexpected diagnostic file')
    return path.read_text(errors='replace').strip()


class OwnedSocketViolation(RuntimeError):
    """Fail-closed admission rejection, with one bounded already-filtered row."""
    def __init__(self, reason, row):
        super().__init__(reason)
        values = {key: row[key] for key in ('protocol', 'address', 'port', 'state', 'remote')}
        require(type(values['port']) is int and 0 <= values['port'] <= 65535, 'Socket diagnostic port malformed')
        for key, cap in (('protocol', 3), ('address', 45), ('state', 16), ('remote', 45)):
            value = values[key]
            require((key == 'remote' and value is None) or
                    (isinstance(value, str) and len(value) <= cap and all(ord(c) >= 32 for c in value)),
                    'Socket diagnostic field malformed')
        self.row = values
        self.evidence = None


def socket_contract(rows, server=False, port=None, allow_outbound=False, allow_client_listener=False):
    listeners = 0
    for row in rows:
        if allow_outbound:
            if row['protocol'] != 'tcp':
                raise OwnedSocketViolation('UDP/non-TCP is not approved', row)
            if row['state'] == 'listen':
                listeners += 1
                game_listener = (server and row['address'] == '127.0.0.1' and row['port'] == port and row['remote'] in ('0.0.0.0', '127.0.0.1'))
                client_listener = (allow_client_listener and not server and type(port) is int and
                                   row['address'] == '127.0.0.1' and row['remote'] == '0.0.0.0' and
                                   type(row['port']) is int and 49152 <= row['port'] <= 65535 and row['port'] != port)
                if not (listeners == 1 and (game_listener or client_listener)):
                    raise OwnedSocketViolation('Unexpected owned listener', row)
            continue
        if not (row['protocol'] == 'tcp' and row['address'] == '127.0.0.1'):
            raise OwnedSocketViolation('Non-loopback or unexpected owned socket', row)
        if row['remote'] not in ('0.0.0.0', '127.0.0.1'):
            raise OwnedSocketViolation('Non-loopback owned peer', row)
        if not (row['state'] != 'listen' or (server and row['port'] == port)):
            raise OwnedSocketViolation('Unexpected owned listener', row)


def checked_owned_sockets(role, adapter, process, server=False, port=None, observations=None, client_listener_binding=None):
    # Adapter still reads GLOBAL tables, filters PID rows in memory, then checks
    # its retained handle. Never retain raw tables or other-process rows here.
    require(server == (role == 'server'), 'Socket role/listener contract mismatch')
    rows = adapter.sockets(process)
    try:
        socket_contract(rows, server, port, allow_outbound=role in ('server', 'client'),
                        allow_client_listener=role == 'client')
        listeners = [row for row in rows if row['state'] == 'listen']
        if role == 'client' and listeners:
            identity = adapter.identity(process)
            require(not adapter.exited(process), 'Client listener attribution unavailable after owned exit')
            require(isinstance(client_listener_binding, dict), 'Client listener binding record required')
            require(type(identity['pid']) is int and identity['pid'] > 0 and
                    type(identity['creation_filetime']) is int and identity['creation_filetime'] > 0,
                    'Client listener retained identity unavailable')
            binding = {'pid': identity['pid'], 'creation_filetime': identity['creation_filetime'],
                       'protocol': 'tcp', 'address': '127.0.0.1', 'port': listeners[0]['port']}
            if client_listener_binding and client_listener_binding != binding:
                raise OwnedSocketViolation('Client loopback HTTP listener identity/port changed', listeners[0])
            client_listener_binding.update(binding)
    except OwnedSocketViolation as error:
        identity = adapter.identity(process)
        require(not adapter.exited(process), 'Socket violation attribution unavailable after owned exit')
        require(role in ('compiler', 'server', 'client') and
                type(identity['pid']) is int and identity['pid'] > 0 and
                type(identity['creation_filetime']) is int and identity['creation_filetime'] > 0,
                'Socket violation retained identity unavailable')
        error.evidence = {'role': role, 'pid': identity['pid'],
                          'creation_filetime': identity['creation_filetime'],
                          'violation': str(error), 'socket': error.row,
                          'retained_handle_live_after_query': True,
                          'scope': 'first violating owned row only; no raw table'}
        require(len(json.dumps(error.evidence)) <= 1024, 'Socket violation diagnostic bound')
        raise
    if rows:
        identity = adapter.identity(process)
        require(not adapter.exited(process), 'Socket attribution unavailable after owned exit')
        require(role in ('compiler', 'server', 'client') and
                type(identity['pid']) is int and identity['pid'] > 0 and
                type(identity['creation_filetime']) is int and identity['creation_filetime'] > 0,
                'Socket retained identity unavailable')
        if observations is not None and role in ('server', 'client'):
            for row in rows:
                # Reuse the same bounded allowlist without retaining other fields.
                bounded = OwnedSocketViolation('metadata only', row).row
                record = {'role': role, 'pid': identity['pid'],
                          'creation_filetime': identity['creation_filetime'],
                          'socket': bounded}
                require(len(json.dumps(record)) <= 512, 'Owned connection metadata bound')
                if record not in observations:
                    require(len(observations) < 32, 'Owned connection observation limit')
                    observations.append(record)
    return rows


def require_game_listener(rows, port):
    listeners = [row for row in rows if row['state'] == 'listen']
    require(len(listeners) == 1 and listeners[0]['protocol'] == 'tcp' and
            listeners[0]['address'] == '127.0.0.1' and listeners[0]['port'] == port and
            listeners[0]['remote'] in ('0.0.0.0', '127.0.0.1'),
            'Exactly one chosen loopback game listener required')
    return listeners


def require_outbound_window(now=None, start=False):
    moment = datetime.now(timezone.utc) if now is None else now
    reserve = timedelta(minutes=5) if start else timedelta(0)
    require(moment + reserve < OUTBOUND_DEADLINE, 'Outbound authorization window expired or insufficient run reserve')


def run(binary, source, output):
    require(os.name == 'nt' and os.environ.get('GITHUB_ACTIONS') == 'true' and os.environ.get('RUNNER_ENVIRONMENT') == 'github-hosted', 'Only reviewed hosted Windows runner')
    require(os.environ.get('GITHUB_REPOSITORY') == 'Civ13/Civ13' and os.environ.get('GITHUB_RUN_ATTEMPT') == '1', 'Wrong repository/attempt')
    require(os.environ.get('GITHUB_REF') == 'refs/heads/ci/cloud-bakery-5161688-directx-diag-v15-20261025', 'Wrong activation branch')
    require_outbound_window(start=True)
    require(not output.exists(), 'Fresh output required; no retry/overwrite')
    output.mkdir()
    from windows import Adapter
    from capture import capture_owned
    from acquire import check_dependencies
    started = time.monotonic()
    owners = []
    port = None
    listener_required = False
    result = {'status': 'FAILED', 'head': os.environ.get('GITHUB_SHA'), 'run_id': os.environ.get('GITHUB_RUN_ID'),
              'scene_revision': REVISION, 'engine': '516.1688', 'scope': 'native staged Civ13 bakery; guest camera, not ordinary-player acceptance',
              'cleanup': [], 'captures': {}, 'owned_connections': [], 'client_loopback_listener': {},
              'network_policy': 'Outbound TCP approved until 2026-10-26 16:36:18 UTC; one bound client loopback HTTP listener; UDP/non-loopback or extra listeners rejected; compiler unchanged',
              'endpoint_identity_and_purpose_verified': False, 'zero_egress': False,
              'execution_source_sha256': {p.name: digest(p) for p in Path(__file__).parent.glob('*.py')}}
    def budget():
        require_outbound_window()
        require(time.monotonic()-started < 165, 'Shared 165-second work budget exhausted')
    def watch():
        budget()
        for role, adapter, process in owners:
            if process is None or adapter.exited(process):
                continue
            require(adapter.memory(process.process) <= LIMITS['process_private_bytes'], 'Owned memory cap exceeded')
            require(adapter.times(process)[1] <= 60 and adapter.accounting().total == 1, 'Owned CPU/child cap exceeded')
            rows = checked_owned_sockets(role, adapter, process, role == 'server', port if role in ('server', 'client') else None, result['owned_connections'], result['client_loopback_listener'])
            if role == 'server' and listener_required:
                require_game_listener(rows, port)
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
        from directx_setup import verify_setup_receipt
        result['directx_setup'] = verify_setup_receipt(binary.parent.parent, binary.parent.parent/'directx-evidence'/'directx-setup-receipt.json')
        result['dependencies'] = check_dependencies(binary, allow_cab_extraction=False)
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
        rows = checked_owned_sockets('server', server, serving, True, port, result['owned_connections'])
        result['server_listener'] = require_game_listener(rows, port)
        listener_required = True
        require(all(digest(source/n) == v for n,v in sealed.items()), 'Compiled input changed')
        client, playing = launch('client', 'dreamseeker.exe', ['byond://127.0.0.1:%d##guest' % port], True)
        result['client'] = wait_file('cloud-client.txt', 'guest=1;version=516;build=1688')
        # Let the real map resources render before the first guarded capture.
        first_frame_ready_at = time.monotonic() + 2
        while time.monotonic() < first_frame_ready_at:
            watch(); time.sleep(.1)
        watch()
        result['captures']['before'] = capture_owned(client, playing, output/'bakery-before.png', TITLE, (480,480))
        result['captures']['before']['scene_phase'] = 'authored bakery map before staged actors'
        (source/'cloud-stage-captured.txt').write_text('captured\n')
        wait_file('filming-ready.txt')
        take = json.loads(wait_file('filming-take.json'))
        require(take['engine'] == '516.1688' and take['source'] == REVISION, 'Take binding mismatch')
        watch(); time.sleep(.5); watch()
        result['captures']['after'] = capture_owned(client, playing, output/'bakery-after.png', TITLE, (480,480))
        result['captures']['after']['scene_phase'] = 'staged native bakery after recipe and take'
        require(digest(output/'bakery-before.png') != digest(output/'bakery-after.png'), 'Unchanged scene images need inspection; not accepted')
        result['take'] = take
        result['native_checks'] = bounded_text(source/'filming-checks.txt')
        watch()
        result['status'] = 'PASS_NATIVE_CIV13_BAKERY_STILLS'
    except BaseException as error:
        result['error'] = str(error)[:1024]
        if isinstance(error, OwnedSocketViolation) and error.evidence is not None:
            result['owned_socket_violation'] = error.evidence
    finally:
        for role, adapter, process in reversed(owners):
            try:
                row = adapter.cleanup(process, max(0, min(5, 180-(time.monotonic()-started))))
            except BaseException as error:
                row = {'all_exited': False, 'error': type(error).__name__}
            result['cleanup'].append({'role': role, **row})
        if not all(row['all_exited'] for row in result['cleanup']):
            result['status'] = 'FAILED_CLEANUP'
        # Only after every retained Job has confirmed cleanup, read exact-client
        # Application Error metadata. No debugger or broad event-log fallback.
        clients = [row for row in result['cleanup'] if row['role'] == 'client']
        if len(clients) == 1 and all(row['all_exited'] for row in result['cleanup']):
            exits = clients[0].get('exits', [])
            if len(exits) == 1 and exits[0].get('wait_signaled') and exits[0].get('exit_code_read'):
                crashed = exits[0]
                if 0x80000000 <= crashed['exit_code'] <= 0xffffffff:
                    from owned_crash import collect
                    result['client_crash_diagnostic'] = collect(crashed['identity'], crashed['exit_code'],
                        seconds=max(0, min(2, 179-(time.monotonic()-started))))
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
