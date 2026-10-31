"""One reviewed hosted attempt. Genuine Civ13 guest camera, no production account."""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import time
from guard_config import digest, LIMITS

REVISION = '58404f5bd16e3fed80f1d9844c5db3edd144942c'
TITLE = 'Civ13 flatbread bakery take'
ADMISSION_DEADLINE = datetime(2026, 10, 31, 20, 0, 0, tzinfo=timezone.utc)
# Sampling cannot prevent short-lived egress. Do not start native programs until
# a separately reviewed network authority/containment solution exists.
NETWORK_RUNTIME_ADMITTED = True


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


def socket_contract(rows, server=False, port=None, allow_client_listener=False):
    listeners = 0
    for row in rows:
        if not (row['protocol'] == 'tcp' and row['address'] == '127.0.0.1'):
            raise OwnedSocketViolation('Non-loopback or unexpected owned socket', row)
        if row['state'] == 'listen':
            listeners += 1
            game_listener = server and row['port'] == port and row['remote'] in ('0.0.0.0', '127.0.0.1')
            client_listener = (allow_client_listener and not server and type(port) is int and
                               row['remote'] == '0.0.0.0' and type(row['port']) is int and
                               49152 <= row['port'] <= 65535 and row['port'] != port)
            if listeners != 1 or not (game_listener or client_listener):
                raise OwnedSocketViolation('Unexpected owned listener', row)
        elif row['remote'] != '127.0.0.1':
            raise OwnedSocketViolation('Non-loopback owned peer', row)


def checked_owned_sockets(role, adapter, process, server=False, port=None, observations=None, client_listener_binding=None):
    # Adapter still reads GLOBAL tables, filters PID rows in memory, then checks
    # its retained handle. Never retain raw tables or other-process rows here.
    require(server == (role == 'server'), 'Socket role/listener contract mismatch')
    rows = adapter.sockets(process)
    try:
        socket_contract(rows, server, port,
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


def require_admission_window(now=None, start=False):
    moment = datetime.now(timezone.utc) if now is None else now
    reserve = timedelta(minutes=5) if start else timedelta(0)
    require(moment + reserve < ADMISSION_DEADLINE, 'Admission deadline expired or insufficient run reserve')


def verify_live_firewall():
    # Read-only verification of the exact rules and active policy, before each
    # owned native process. The verification helper has its own 10s timeout.
    program_files = Path(os.environ.get('ProgramFiles', ''))
    pwsh = program_files / 'PowerShell' / '7' / 'pwsh.exe'
    require(program_files.is_absolute() and pwsh.is_file() and not pwsh.is_symlink(), 'trusted runner PowerShell unavailable')
    helper = Path(__file__).with_name('firewall_supervisor.ps1')
    require(helper.is_file() and not helper.is_symlink(), 'firewall verification helper unavailable')
    try:
        r = subprocess.run([str(pwsh), '-NoLogo', '-NoProfile', '-NonInteractive', '-File', str(helper), '-VerifyOnly'],
                           stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=10, check=False)
    except (OSError, subprocess.TimeoutExpired):
        raise RuntimeError('firewall_verification_unavailable') from None
    require(r.returncode == 0, 'firewall_verification_failed')


def run(binary, source, output, *, client_diagnostic=False):
    from activation import require_runtime
    admission = require_runtime()
    from client_debug import mode
    mode(client_diagnostic, admission)
    require(os.name == 'nt' and os.environ.get('GITHUB_ACTIONS') == 'true' and os.environ.get('RUNNER_ENVIRONMENT') == 'github-hosted', 'Only reviewed hosted Windows runner')
    require(os.environ.get('GITHUB_REPOSITORY') == 'Civ13/Civ13' and os.environ.get('GITHUB_RUN_ATTEMPT') == '1', 'Wrong repository/attempt')
    require(os.environ.get('GITHUB_REF') == 'refs/heads/ci/cloud-bakery225-control-5161688-20261031-r1', 'Wrong activation branch')
    require_admission_window(start=True)
    require(NETWORK_RUNTIME_ADMITTED, 'HELD: native network containment or specific authorization unresolved')
    require(not output.exists(), 'Fresh output required; no retry/overwrite')
    output.mkdir()
    from windows import Adapter
    from acquire import check_dependencies
    started = time.monotonic()
    owners = []
    port = None
    listener_required = False
    result = {'status': 'FAILED', 'head': os.environ.get('GITHUB_SHA'), 'run_id': os.environ.get('GITHUB_RUN_ID'),
              'scene_revision': REVISION, 'engine': '516.1688',
              'scope': ('five-second owned-client DLL/exception/exit diagnostic; no startup or gameplay acceptance'
                        if client_diagnostic else
                        'scripted isolated route, bakery and staged train preflight; no capture or ordinary-player acceptance'),
              'native_acceptance': False, 'client_diagnostic_mode': client_diagnostic,
              'cleanup': [], 'capture_performed': False, 'owned_connections': [], 'client_loopback_listener': {},
              'network_policy': 'Loopback-only sampled socket contract; sampling is not prevention; native launch held until network scope is resolved',
              'endpoint_identity_and_purpose_verified': False, 'zero_egress': False,
              'execution_source_sha256': {p.name: digest(p) for p in Path(__file__).parent.glob('*.py')}}
    def budget():
        require_admission_window()
        require(time.monotonic()-started < 240, 'Shared 240-second work budget exhausted')
    def watch():
        budget()
        for role, adapter, process in owners:
            if process is None or adapter.exited(process):
                continue
            require(adapter.memory(process.process) <= LIMITS['process_private_bytes'], 'Owned memory cap exceeded')
            require(adapter.memory(adapter.k.GetCurrentProcess()) <= LIMITS['watcher_private_bytes'], 'Watcher memory cap exceeded')
            require(adapter.times(process)[1] <= 60 and adapter.accounting().total == 1, 'Owned CPU/child cap exceeded')
            rows = checked_owned_sockets(role, adapter, process, role == 'server', port if role in ('server', 'client') else None, result['owned_connections'], result['client_loopback_listener'])
            if role == 'server' and listener_required:
                require_game_listener(rows, port)
        for path in output.glob('*.log'):
            require(path.stat().st_size <= 1024**2, 'Log cap exceeded')
        stop = bounded_text(source/'intro-stop.txt')
        require(stop is None, 'Native scene stopped: '+str(stop)[:500])
        budget()
    def launch(role, executable, args, visible=False, *, debug_client=False):
        budget()
        verify_live_firewall()
        from nuget_local_runtime import verify_receipt as verify_nuget_runtime
        verify_nuget_runtime(binary.parent.parent)
        budget()
        adapter = Adapter()
        owners.append((role, adapter, None))
        adapter.preflight(LIMITS)
        require(adapter.free() >= 2*1024**3, 'Insufficient current free RAM')
        adapter.open(creation_guard=budget)
        extra = {'client_debug': True} if debug_client else {}
        process = adapter.launch([str(binary/executable)]+args, source, output, role, visible,
                                 creation_guard=budget, **extra)
        owners[-1] = (role, adapter, process)
        return adapter, process
    def wait_file(name, expected=None):
        while True:
            watch()
            for role, adapter, process in owners:
                if role in ('server', 'client'):
                    require(not adapter.exited(process), role+' exited before scene evidence')
            value = bounded_text(source/name, 16384 if name == 'filming-viewport.txt' else 65536)
            if value is not None:
                if expected is not None:
                    require(value == expected, 'Native identity/phase receipt mismatch: '+name)
                return value
            time.sleep(.1)
    try:
        result['admission'] = admission
        result['source'] = json.loads((source/'source-receipt.json').read_text())
        require(result['source']['derived_manifest_sha256'] == admission['scene_sha256'], 'Wrong scene source')
        require(result['source']['source_revision'] == REVISION, 'Wrong source revision')
        from nuget_local_runtime import verify_receipt as verify_nuget_runtime
        result['nuget_runtime'] = verify_nuget_runtime(binary.parent.parent)
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
        server, serving = launch('server', 'dd.exe', ['civ13.dmb', str(port), '-ip', '127.0.0.1', '-invisible', '-trusted', '-nowebclient', '-params', 'observer_mode=engine_guest_camera&intro_port='+str(port)])
        wait_file('cloud-listening.txt', 'port=%d;version=516;build=1688' % port)
        rows = checked_owned_sockets('server', server, serving, True, port, result['owned_connections'])
        result['server_listener'] = require_game_listener(rows, port)
        listener_required = True
        require(all(digest(source/n) == v for n,v in sealed.items()), 'Compiled input changed')
        client, playing = launch('client', 'dreamseeker.exe', ['byond://127.0.0.1:%d##guest' % port], True,
                                 debug_client=client_diagnostic)
        if client_diagnostic:
            from client_debug import collect
            from bakery_startup import sample_within_observation, end_observation
            sampled = {}
            def startup_watch():
                watch()
                if sampled.get('ready_checkpoints_observed') is not True:
                    sampled.clear()
                    sampled.update(sample_within_observation(source,playing._debug_backend.started,
                                                              time.perf_counter))
            result['client_startup_diagnostic'] = collect(playing._debug_trace, playing._debug_backend,
                                                         startup_watch, time.perf_counter)
            result['bakery_startup_comparison'] = end_observation(sampled,
                result['client_startup_diagnostic'],not client.exited(playing))
            require(not playing._debug_trace.errors and
                    result['client_startup_diagnostic']['status'] == 'DIAGNOSTIC_REVIEW_REQUIRED',
                    'Owned client diagnostic failed')
            result['native_acceptance'] = False
            result['pending'] = 'Review owned-client debug metadata; no capture or startup acceptance'
            result['status'] = 'CLIENT_STARTUP_DIAGNOSTIC_REVIEW_REQUIRED'
            return result
        result['client'] = wait_file('cloud-client.txt', 'guest=1;version=516;build=1688')
        # Let the real map resources render before the first guarded capture.
        first_frame_ready_at = time.monotonic() + 2
        while time.monotonic() < first_frame_ready_at:
            watch(); time.sleep(.1)
        watch()
        from capture import wait_owned_ready
        result['window_readiness'] = wait_owned_ready(client,playing,TITLE,watch)
        readiness = result['window_readiness']
        playing.expected_hwnd = readiness['hwnd']
        owner = {k: readiness[k] for k in ('pid','creation_filetime','hwnd')}
        wait_file('intro-ready.txt')
        from owned_nuget_modules import inspect as inspect_owned_nuget_modules
        result['nuget_owned_modules'] = inspect_owned_nuget_modules(client, playing, binary)
        wait_file('city-preflight-complete.txt', 'complete')
        from preflight_result import validate
        result['preflight'] = validate(source, Path(__file__).with_name('route.json'))
        result['native_acceptance'] = False
        result['pending'] = 'Review native receipts; no capture performed'
        watch()
        result['status'] = 'SCRIPTED_NATIVE_PREFLIGHT_REVIEW_REQUIRED'
    except BaseException as error:
        result['error'] = str(error)[:1024]
        from capture import OwnedRectangleMismatch, PixelHeuristicFailure, OwnedWindowUnavailable
        if isinstance(error, PixelHeuristicFailure):
            result['failed_pixel_heuristic'] = error.facts
            if error.diagnostic is not None:
                result['failed_frame_diagnostic'] = error.diagnostic
                result['failed_capture_readiness'] = dict(
                    client_receipt=result.get('client'),
                    native_checks=bounded_text(source/'filming-checks.txt'),
                    authored_stage_capture_complete=(source/'cloud-stage-captured.txt').exists(),
                    fixture_ready=(source/'filming-ready.txt').exists(),
                    take_complete=(source/'filming-take.json').exists(),
                    render_readiness_proven=False)
        if (isinstance(error, OwnedWindowUnavailable) and error.evidence is not None
                and error.evidence.get('process_identity_revalidated') is True):
            result['owned_window_unavailable'] = error.evidence
        if (isinstance(error, OwnedRectangleMismatch) and error.evidence is not None
                and error.evidence.get('process_identity_revalidated') is True):
            result['owned_rectangle_mismatch'] = error.evidence
        if isinstance(error, OwnedSocketViolation) and error.evidence is not None:
            result['owned_socket_violation'] = error.evidence
    finally:
        for role, adapter, process in reversed(owners):
            try:
                row = adapter.cleanup(process, max(0, min(5, 270-(time.monotonic()-started))))
            except BaseException as error:
                row = {'all_exited': False, 'error': type(error).__name__}
            result['cleanup'].append({'role': role, **row})
        if not all(row['all_exited'] for row in result['cleanup']):
            result['status'] = 'FAILED_CLEANUP'
        debug_clients = [process for role, _, process in owners
                         if role == 'client' and process is not None and hasattr(process, '_debug_trace')]
        if len(debug_clients) == 1:
            result['client_startup_diagnostic'] = debug_clients[0]._debug_trace.snapshot()
        if client_diagnostic:
            from bakery_startup import finalize
            result['bakery_startup_comparison'] = finalize(result.get('bakery_startup_comparison'),
                result.get('client_startup_diagnostic',{}),result['cleanup'])
        # Persist these independently before crash diagnostics or aggregation.
        from evidence import retain_independent, write_aggregate
        result['independent_evidence'] = retain_independent(source, output, result)
        # Only after every retained Job has confirmed cleanup, read exact-client
        # Application Error metadata. No broad event-log fallback; any optional
        # owned debug observation has already ended and drained above.
        clients = [row for row in result['cleanup'] if row['role'] == 'client']
        if len(clients) == 1 and all(row['all_exited'] for row in result['cleanup']):
            exits = clients[0].get('exits', [])
            if len(exits) == 1 and exits[0].get('wait_signaled') and exits[0].get('exit_code_read'):
                crashed = exits[0]
                if 0x80000000 <= crashed['exit_code'] <= 0xffffffff:
                    from owned_crash import collect
                    result['client_crash_diagnostic'] = collect(crashed['identity'], crashed['exit_code'],
                        seconds=max(0, min(2, 269-(time.monotonic()-started))))
        result['elapsed_seconds'] = time.monotonic()-started
        if result['elapsed_seconds'] >= 270:
            result['status'] = 'FAILED_TOTAL_BUDGET'
        write_aggregate(output, result)
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--binary', type=Path, required=True)
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    entry = p.add_mutually_exclusive_group(required=True)
    entry.add_argument('--execute-reviewed-scene', action='store_true')
    entry.add_argument('--execute-reviewed-client-diagnostic', action='store_true')
    a = p.parse_args()
    result = run(a.binary.resolve(), a.source.resolve(), a.output.resolve(),
                 client_diagnostic=a.execute_reviewed_client_diagnostic)
    print(result['status'])
    raise SystemExit(0 if result['status'] in ('SCRIPTED_NATIVE_PREFLIGHT_REVIEW_REQUIRED',
                                             'CLIENT_STARTUP_DIAGNOSTIC_REVIEW_REQUIRED') else 2)
