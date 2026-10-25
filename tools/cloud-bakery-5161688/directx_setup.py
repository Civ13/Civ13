"""One consent-gated bundled DirectX setup on a disposable hosted Windows runner.

No alternate installer, download, elevation, reboot, or manual DLL replacement.
The unchanged retained-handle adapter limits setup to one process in its Job.
"""
import argparse
import ipaddress
import json
import os
from pathlib import Path
import re
import time

import acquire
from guard_config import LIMITS

BRANCH = 'refs/heads/ci/cloud-bakery-5161688-failed-frame-v22-20261025'
SETUP_SHA256 = '046041aba6ba77534c36bb0c2496408d23c6a09f930c46b392f1edc70dfd66de'
WORK_SECONDS = 60
CLEANUP_SECONDS = 5
DLLS = {
    'd3dx9_43.dll': (1998168, acquire.D3DX_SHA256),
    'D3DCompiler_43.dll': (2106216, '2f23182ec6f4889397ac4bf03d62536136c5bdba825c7d2c4ef08c827f3a8a1c'),
}


def require(ok, reason):
    if not ok:
        raise RuntimeError(reason)


def binding():
    require(os.name == 'nt' and os.environ.get('GITHUB_ACTIONS') == 'true' and
            os.environ.get('RUNNER_ENVIRONMENT') == 'github-hosted', 'hosted_windows_required')
    require(os.environ.get('GITHUB_REPOSITORY') == 'Civ13/Civ13' and
            os.environ.get('GITHUB_RUN_ATTEMPT') == '1' and
            os.environ.get('GITHUB_REF') == BRANCH, 'wrong_run_admission')
    fields = {key: os.environ.get(key, '') for key in
              ('GITHUB_SHA', 'GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT', 'GITHUB_JOB', 'GITHUB_REF')}
    require(re.fullmatch('[0-9a-f]{40}', fields['GITHUB_SHA']) and
            re.fullmatch('[0-9]+', fields['GITHUB_RUN_ID']) and
            re.fullmatch('[A-Za-z0-9_-]{1,100}', fields['GITHUB_JOB']), 'invalid_run_binding')
    return fields


def system_dlls():
    """Read-only checks of actual x86 system files, with no package-bin fallback."""
    system = acquire._windows_root() / 'SysWOW64'
    acquire._plain_ancestors(system)
    result = {}
    for name, (size, digest) in DLLS.items():
        require(size > 0 and re.fullmatch('[0-9a-f]{64}', digest), 'unresolved_review_pin')
        raw = acquire._read(system / name, size)
        acquire._pe_x86(raw)
        require(len(raw) == size and acquire._sha(raw) == digest, 'system_dll_hash_mismatch')
        result[name] = {'bytes': size, 'sha256': digest, 'location': 'windows-x86-system'}
    return result


def verify_setup_receipt(root, receipt_path):
    """Rebind successful setup and both installed DLLs before scene execution."""
    expected = binding()
    root = Path(root).absolute()
    acquire.verify_files(root)
    path = Path(receipt_path).absolute()
    require(path == root / 'directx-evidence' / 'directx-setup-receipt.json', 'wrong_setup_receipt_location')
    acquire._plain_ancestors(path.parent)
    record = json.loads(acquire._read(path, 16384))
    require(record.get('schema') == 1 and record.get('status') == 'PASSED' and
            record.get('binding') == expected and
            record.get('archive_sha256') == acquire.ARCHIVE_SHA256 and
            record.get('installer_sha256') == SETUP_SHA256 and
            record.get('exit_code') == 0 and
            record.get('cleanup', {}).get('all_exited') is True and
            record.get('system_dlls') == system_dlls(), 'setup_receipt_not_same_successful_run')
    return record


def socket_diagnostic(adapter, process, rows):
    """First offending owned row only; malformed/stale data is never exported."""
    unavailable = {'status': 'unavailable'}
    try:
        require(type(rows) is list and 0 < len(rows) <= 65536, 'bad_rows')
        require(not adapter.exited(process), 'stale_identity')
        identity = adapter.identity(process)
        pid, created = identity['pid'], identity['creation_filetime']
        require(type(pid) is int and 0 < pid <= 0xffffffff and
                type(created) is int and 0 < created <= 0xffffffffffffffff, 'bad_identity')
        row = rows[0]
        require(type(row) is dict, 'bad_row')
        protocol, address, remote, port, state = (row[key] for key in
                                               ('protocol', 'address', 'remote', 'port', 'state'))
        require(protocol in ('tcp', 'udp') and type(protocol) is str, 'bad_protocol')
        require(type(address) is str and len(address) <= 45 and '%' not in address, 'bad_address')
        local = ipaddress.ip_address(address)
        require(type(port) is int and 0 <= port <= 65535, 'bad_port')
        require(type(state) is str and len(state) <= 6, 'bad_state')
        if protocol == 'tcp':
            require(state == 'listen' or state in tuple(str(n) for n in range(1, 13)), 'bad_state')
            require(type(remote) is str and len(remote) <= 45 and '%' not in remote, 'bad_remote')
            peer = ipaddress.ip_address(remote)
            require(peer.version == local.version, 'bad_family')
            remote = str(peer)
        else:
            require(remote is None and state == 'None', 'bad_udp')
        rebound = adapter.identity(process)
        require(rebound['pid'] == pid and rebound['creation_filetime'] == created and
                not adapter.exited(process), 'stale_identity')
        result = {'status': 'observed', 'pid': pid, 'creation_filetime': created,
                  'owned_rows_count': len(rows), 'retained_handle_live_after_query': True,
                  'first_row': {'protocol': protocol, 'address': str(local), 'remote': remote,
                                'port': port, 'state': state}}
        require(len(json.dumps(result)) <= 1024, 'diagnostic_bound')
        return result
    except Exception:
        return unavailable


# This is a sampled owned-connection check, NOT continuous OS network isolation.
# TCP state alone cannot prove which side initiated an established connection.
ALLOWED_SETUP_TCP_STATES = frozenset(('3', '5', '6', '7', '8', '9', '10', '11'))
MAX_SETUP_SOCKET_ROWS = 64
MAX_SETUP_OBSERVATIONS = 8


def check_setup_sockets(adapter, process, result):
    """Narrow approved installer TCP policy; no listener, UDP or stale admission."""
    rows = adapter.sockets(process)
    require(type(rows) is list, 'setup_socket_rejected')
    if not rows:
        return
    result['socket_diagnostic'] = socket_diagnostic(adapter, process, rows)
    require(type(rows) is list and len(rows) <= MAX_SETUP_SOCKET_ROWS,
            'setup_socket_rejected')
    first_identity = None
    observations = []
    for row in rows:
        evidence = socket_diagnostic(adapter, process, [row])
        # Always retain the actual first rejected row, not a preceding allowed row.
        result['socket_diagnostic'] = evidence
        require(evidence.get('status') == 'observed', 'setup_socket_rejected')
        identity = (evidence['pid'], evidence['creation_filetime'])
        if first_identity is None:
            first_identity = identity
        require(identity == first_identity, 'setup_socket_rejected')
        item = evidence['first_row']
        require(item['protocol'] == 'tcp' and item['state'] in ALLOWED_SETUP_TCP_STATES,
                'setup_socket_rejected')
        local, peer = ipaddress.ip_address(item['address']), ipaddress.ip_address(item['remote'])
        require(not local.is_unspecified and not local.is_multicast and
                not peer.is_unspecified and not peer.is_multicast and item['port'] > 0,
                'setup_socket_rejected')
        observations.append(evidence)
    identity = adapter.identity(process)
    require((identity['pid'], identity['creation_filetime']) == first_identity and
            not adapter.exited(process), 'setup_socket_rejected')
    # Bounded metadata only. All rows above are checked even after retention fills.
    retained = result.setdefault('sampled_tcp_observations', [])
    for evidence in observations:
        if evidence not in retained and len(retained) < MAX_SETUP_OBSERVATIONS:
            retained.append(evidence)
    result.pop('socket_diagnostic', None)


def cleanup_diagnostic(raw):
    """Keep only fixed primitive fields, never images, paths or exception text."""
    if type(raw) is not dict or type(raw.get('all_exited')) is not bool:
        return {'all_exited': False, 'diagnostic_status': 'malformed'}
    result = {'all_exited': raw['all_exited']}
    try:
        primitives = raw.get('primitives', {})
        require(type(primitives) is dict, 'bad_cleanup')
        result['primitives'] = {}
        for key in ('terminate_job', 'close_job'):
            if key in primitives:
                require(type(primitives[key]) is bool, 'bad_cleanup')
                result['primitives'][key] = primitives[key]
        exits = raw.get('exits', [])
        require(type(exits) is list and len(exits) <= 1, 'bad_cleanup')
        result['exits'] = []
        for row in exits:
            require(type(row) is dict, 'bad_cleanup')
            kept = {}
            for key in ('wait_signaled', 'exit_code_read', 'thread_handle_closed', 'process_handle_closed'):
                if key in row:
                    require(type(row[key]) is bool, 'bad_cleanup')
                    kept[key] = row[key]
            for key in ('wait_result', 'exit_code'):
                if key in row:
                    require(type(row[key]) is int and 0 <= row[key] <= 0xffffffff, 'bad_cleanup')
                    kept[key] = row[key]
            result['exits'].append(kept)
        errors = raw.get('errors', [])
        require(type(errors) is list and len(errors) <= 16, 'bad_cleanup')
        result['error_count'] = len(errors)
        require(len(json.dumps(result)) <= 2048, 'bad_cleanup')
        return result
    except Exception:
        return {'all_exited': False, 'diagnostic_status': 'malformed'}


def run(root, output, *, accept_terms=False):
    # A source flag is not consent. Caller supplies this only after user approval.
    require(accept_terms is True, 'explicit_terms_acceptance_required')
    context = binding()
    root, output = Path(root).absolute(), Path(output).absolute()
    acquire._plain_ancestors(root)
    acquire._plain_ancestors(output.parent)
    require(not output.exists() and not output.is_symlink(), 'fresh_setup_output_required')
    acquire.verify_files(root)
    executable = root / 'byond' / 'directx' / 'DXSETUP.exe'
    raw = acquire._read(executable, 537432)
    require(len(raw) == 537432 and acquire._sha(raw) == SETUP_SHA256, 'setup_hash_mismatch')
    acquire._pe_x86(raw)
    # Ensure no unfinished pin can admit native execution.
    require(all(size > 0 and re.fullmatch('[0-9a-f]{64}', sha) for size, sha in DLLS.values()),
            'unresolved_review_pin')
    output.mkdir()
    from windows import Adapter
    adapter = Adapter()
    process = None
    started = time.monotonic()
    result = {'schema': 1, 'status': 'FAILED', 'binding': context,
              'archive_sha256': acquire.ARCHIVE_SHA256, 'installer_sha256': SETUP_SHA256,
              'command': ['DXSETUP.exe', '/silent'], 'terms_accepted_by_authorized_caller': True,
              'work_seconds': WORK_SECONDS, 'cleanup_seconds': CLEANUP_SECONDS,
              'runtime_rendering_verified': False,
              'setup_network_policy': 'Sampled installer-owned non-listening TCP only; UDP, LISTEN, SYN_RECEIVED, malformed/stale rows rejected; initiation direction and endpoint purpose not proven',
              'continuous_os_network_isolation': False}

    def budget():
        require(time.monotonic() - started < WORK_SECONDS, 'setup_work_timeout')

    def watch():
        budget()
        require(adapter.accounting().total == 1, 'setup_child_process_rejected')
        require(adapter.memory(process.process) <= LIMITS['process_private_bytes'] and
                adapter.times(process)[1] <= WORK_SECONDS, 'setup_resource_limit')
        check_setup_sockets(adapter, process, result)
        for path in output.glob('*.log'):
            require(acquire._plain(path).st_size <= 1048576, 'setup_log_limit')
        budget()

    try:
        adapter.preflight(LIMITS)
        require(adapter.free() >= 2 * 1024 ** 3, 'setup_free_memory_limit')
        adapter.open(creation_guard=budget)
        process = adapter.launch([str(executable), '/silent'], executable.parent,
                                 output, 'directx', creation_guard=budget)
        while not adapter.exited(process):
            watch()
            adapter.pause(0.05)
        budget()
        finished = adapter.finish(process)
        require(finished['total_processes'] == 1 and finished['active_processes'] == 0,
                'setup_job_accounting_mismatch')
        result['exit_code'] = finished['exit_code']
        require(finished['exit_code'] == 0, 'setup_nonzero_or_reboot_required')
        result['system_dlls'] = system_dlls()
        budget()
        result['status'] = 'PASSED'
    except Exception as error:
        # Export only controlled, bounded error codes, never raw native errors.
        code = str(error)
        result['error'] = code if re.fullmatch('[a-z_]{1,80}', code) else 'setup_failed'
        raise
    finally:
        try:
            result['cleanup'] = cleanup_diagnostic(adapter.cleanup(process, CLEANUP_SECONDS))
            if result['cleanup'].get('all_exited') is not True:
                result['status'] = 'FAILED'
        except Exception:
            result['status'] = 'FAILED'
            result['cleanup'] = {'all_exited': False}
            raise
        finally:
            data = (json.dumps(result, indent=2) + '\n').encode()
            require(len(data) <= 16384, 'setup_receipt_size_limit')
            with (output / 'directx-setup-receipt.json').open('xb') as stream:
                stream.write(data)
        require(result['cleanup']['all_exited'], 'setup_cleanup_unconfirmed')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--accept-bundled-microsoft-directx-terms', action='store_true')
    args = parser.parse_args()
    run(args.root, args.output, accept_terms=args.accept_bundled_microsoft_directx_terms)
