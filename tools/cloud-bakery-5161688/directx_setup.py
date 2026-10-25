"""One consent-gated bundled DirectX setup on a disposable hosted Windows runner.

No alternate installer, download, elevation, reboot, or manual DLL replacement.
The unchanged retained-handle adapter limits setup to one process in its Job.
"""
import argparse
import json
import os
from pathlib import Path
import re
import time

import acquire
from guard_config import LIMITS

BRANCH = 'refs/heads/ci/cloud-bakery-5161688-directx-v14-20261025'
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
              'runtime_rendering_verified': False}

    def budget():
        require(time.monotonic() - started < WORK_SECONDS, 'setup_work_timeout')

    def watch():
        budget()
        require(adapter.accounting().total == 1, 'setup_child_process_rejected')
        require(adapter.memory(process.process) <= LIMITS['process_private_bytes'] and
                adapter.times(process)[1] <= WORK_SECONDS, 'setup_resource_limit')
        require(not adapter.sockets(process), 'setup_socket_rejected')
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
            result['cleanup'] = adapter.cleanup(process, CLEANUP_SECONDS)
            if result['cleanup'].get('all_exited') is not True:
                result['status'] = 'FAILED'
            # Retain only cleanup primitives, never process image/user paths.
            result['cleanup'] = {'all_exited': result['cleanup'].get('all_exited') is True}
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
