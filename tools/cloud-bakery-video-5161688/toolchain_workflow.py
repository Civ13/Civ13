"""Held same-run orchestration; does not change network or firewall policy."""
import json
from pathlib import Path

import acquire
import directx_official_setup
import encoder_proof
import installed_directx

ORCHESTRATION_ENABLED = False


def missing_system_dlls():
    system = acquire._windows_root() / 'SysWOW64'
    acquire._plain_ancestors(system)
    missing = []
    for name, (size, digest) in directx_official_setup.DLLS.items():
        path = system / name
        try:
            path.lstat()
        except FileNotFoundError:
            missing.append(name)
            continue
        raw = acquire._read(path, size)
        acquire._pe_x86(raw)
        if len(raw) != size or acquire._sha(raw) != digest:
            raise RuntimeError('existing_system_dll_mismatch')
    return missing


def prepare_runtime(root):
    if ORCHESTRATION_ENABLED is not True:
        raise RuntimeError('toolchain_orchestration_disabled')
    from activation import require_runtime
    require_runtime()
    root = Path(root).absolute()
    acquire._plain_ancestors(root)
    before = installed_directx.probe(root / 'installed-directx-before.json')
    if before.get('status') == 'BLOCKED_SYSTEM_COMPONENTS':
        if not missing_system_dlls():
            raise RuntimeError('blocked_without_missing_system_dll')
        directx_official_setup.run(root, root / 'directx-evidence', accept_terms=True)
    elif before.get('status') != 'AVAILABLE_PINNED_SYSTEM_COMPONENTS':
        raise RuntimeError('unexpected_directx_probe_state')
    after = installed_directx.probe(root / 'installed-directx-receipt.json')
    if after.get('status') != 'AVAILABLE_PINNED_SYSTEM_COMPONENTS':
        raise RuntimeError('directx_unavailable_after_setup')
    installed_directx.verify(root / 'installed-directx-receipt.json')
    return {'before': before['status'], 'after': after['status']}


def prove_encoder(root):
    if ORCHESTRATION_ENABLED is not True:
        raise RuntimeError('toolchain_orchestration_disabled')
    return encoder_proof.run(root)


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--phase', choices=('directx', 'encoder'), required=True)
    args = parser.parse_args()
    print(json.dumps(prepare_runtime(args.root) if args.phase == 'directx' else prove_encoder(args.root), sort_keys=True))
