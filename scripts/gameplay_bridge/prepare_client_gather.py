"""Freeze a normal-startup gather source candidate; never launch or bootstrap it."""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import tarfile

from prepare_native import git, selected_files
from client_gather_profile import IDENTITIES, MAP, ORACLE, normal_dme, verify_map, verify_oracle


def sha(data):
    return hashlib.sha256(data).hexdigest()


def prepare(root, output, expected):
    root, output = Path(root).resolve(), Path(output).resolve()
    if not re.fullmatch(r'[0-9a-f]{40}', expected):
        raise ValueError('full frozen commit required')
    if output.exists() or output == root or root in output.parents:
        raise ValueError('fresh output outside checkout required')
    def frozen():
        if git(root, 'rev-parse', 'HEAD').decode().strip() != expected or git(root, 'status', '--porcelain', '--untracked-files=no').strip():
            raise ValueError('exact clean frozen HEAD required')
    frozen()
    tracked = set(git(root, 'ls-files', '-z').decode().split('\0')) - {''}
    selected = sorted(p for p in selected_files(root, tracked) if not p.startswith('config/') and p != 'rust_g.dll')
    read = lambda p: git(root, 'show', expected + ':' + p)
    original = read('civ13.dme').decode('utf-8-sig').replace('\r\n', '\n')
    generated = normal_dme(original)
    verify_map(read(MAP).decode('utf-8-sig').replace('\r\n', '\n'))
    verify_oracle(read(ORACLE).decode('utf-8-sig').replace('\r\n', '\n'))
    prefixes = ('code/', 'icons/', 'sound/', 'UI/', 'interface/', 'scripts/gameplay_bridge/', 'tests/gameplay_bridge/native/')
    archive_paths = [p.rstrip('/') for p in prefixes if any(f.startswith(p) for f in selected)]
    archive_paths += [p for p in selected if not p.startswith(prefixes)]
    archive = git(root, 'archive', '--format=tar', expected, '--', *archive_paths)
    entries = {}
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:') as tar:
        for member in tar:
            rel = PurePosixPath(member.name)
            if rel.is_absolute() or '..' in rel.parts or not (member.isfile() or member.isdir()):
                raise ValueError('unsafe source archive')
            if member.isfile():
                if member.name not in selected or member.name in entries:
                    raise ValueError('unselected/duplicate source archive entry')
                entries[member.name] = tar.extractfile(member).read()
    if set(entries) != set(selected) or not set(IDENTITIES).issubset(entries):
        raise ValueError('incomplete normal production source closure')
    frozen()  # Validate everything before writing any packet.
    source = output / 'source'
    for relative, data in entries.items():
        target = source.joinpath(*PurePosixPath(relative).parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    (source / 'client_gather.dme').write_text(generated, encoding='utf-8', newline='\n')
    hashes = {p.relative_to(source).as_posix(): sha(p.read_bytes()) for p in sorted(source.rglob('*')) if p.is_file()}
    manifest = {
        'schema': 1, 'kind': 'ordinary_client_gather', 'commit': expected,
        'state': 'prepared_not_executed', 'compiler': 'not_run', 'runtime': 'not_run',
        'runtime_ready': False, 'native_grant': None, 'actual_native_geometry': None,
        'desired_dimensions': [9, 9, 1], 'scope': 'Testing/Nomad-role supplied-resource fixture',
        'dme': 'source/client_gather.dme', 'source_sha256': hashes,
        'normal_source_sha256': {p: sha(entries[p]) for p in IDENTITIES},
        'production_dme_sha256': sha(entries['civ13.dme']),
        'two_real_client_roles_required': ['consenting ordinary human', 'separate genuine local R_ADMIN native assignment'],
        'pending': ['authorized run-local normal config and public runtime dependencies',
                    'existing private bridge config/tokens; no new account or credential',
                    'autosave disabled by authorized run-local config',
                    'normal lobby admission/Nomad role; natural pickup of supplied sharp flint',
                    'separate isolated execution/client allocation and geometry proof',
                    'real deterministic v3 controller status/cancel and post-ACK status witness',
                    'external retained-process/client/bridge cleanup proof'],
        'acceptance': {'ordinary_client': 'not_run', 'native_assignment': 'not_run',
                       'natural_acquisition': 'unsupported', 'physical_cancel_horizon_ticks': 35},
        'oracle': {'bootstrap_ticks': 9000, 'observation_ticks': 1200, 'max_samples': 1201,
                   'fixed_outputs': ['client-gather-status.json', 'client-gather-result.json'],
                   'output_bytes': 2097152, 'does_not_shutdown_or_stop_bridge': True}}
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    return source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--expected-commit', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source = prepare(Path(__file__).resolve().parents[2], args.output, args.expected_commit)
    print(json.dumps({'prepared': str(source), 'runtime_ready': False, 'runtime': 'not_run'}))


if __name__ == '__main__':
    main()
