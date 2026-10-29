"""Prepare/compile the exact-Git NPC fixture. Deliberately no runtime launch mode.

NPC runtime admission and real-client rendering require separate scope review.
Reuses the existing 516.1688 compiler allowlist, owned Job and zero-socket guard.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path, PurePosixPath
import os
import re
import subprocess
import tarfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('npc_current', HERE / 'run-diagonal.py')
current = importlib.util.module_from_spec(spec)
spec.loader.exec_module(current)


def prepare_source(root, out):
    """NPC staging uses a bounded on-disk tar, avoiding Windows pipe-tail stalls.

    Historical preparers remain unchanged. Only exact Git objects enter the tar;
    retain its hash and the same per-file/aggregate extraction bounds.
    """
    current.require(not out.exists(), 'Evidence output must not already exist')
    head = current.legacy.git(root, 'rev-parse', 'HEAD').decode().strip()
    current.require(re.fullmatch('[0-9a-f]{40}', head), 'Expected exact Git commit')
    wanted = ('civ13.dme', 'code', 'icons', 'sound', 'UI', 'interface', 'config', 'tests/human_subtile')
    out.mkdir(parents=True)
    archive = out / 'source.tar'
    command = ['git', '-C', str(root), 'archive', '--format=tar', '--output=' + str(archive), head, '--', *wanted]
    subprocess.run(command, check=True, capture_output=True, timeout=30)
    current.require(archive.stat().st_size <= current.legacy.LIMIT_BYTES + 16 * 1024**2, 'Source archive byte bound')
    stage = out / 'stage'
    stage.mkdir()
    originals = {}
    total = 0
    with tarfile.open(archive, 'r:') as source:
        for member in source:
            if member.isdir():
                continue
            name = PurePosixPath(member.name)
            current.require(member.isfile() and not name.is_absolute() and '..' not in name.parts and
                            member.size <= 256 * 1024**2, 'Unsafe NPC archive member')
            total += member.size
            current.require(total <= current.legacy.LIMIT_BYTES and len(originals) < current.legacy.LIMIT_FILES,
                            'NPC source extraction budget')
            target = stage.joinpath(*name.parts)
            current.require(target.resolve().is_relative_to(stage), 'NPC source escaped stage')
            current.require(member.name not in originals, 'Duplicate NPC archive member')
            raw = source.extractfile(member).read()
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
            originals[member.name] = dict(bytes=len(raw), sha256=current.legacy.digest(raw))
    adaptations = {}
    for relative in ('code/world.dm', 'code/controllers/mc/globals.dm'):
        path = stage / relative
        text = current.legacy.isolate_startup(relative, path.read_text(encoding='utf-8'))
        path.write_text(text, encoding='utf-8', newline='\n')
        adaptations[relative] = dict(original_sha256=originals[relative]['sha256'],
                                     adapted_sha256=current.legacy.digest(path.read_bytes()))
    text = (stage / 'civ13.dme').read_text(encoding='utf-8')
    text = re.sub(r'^#include ".*\.dmm"\s*$', '', text, flags=re.M)
    text += '\n#include "tests\\human_subtile\\mining.dm"\n#include "tests\\human_subtile\\probe.dm"\n'
    dme = stage / 'human_subtile.dme'
    dme.write_text(text, encoding='utf-8', newline='\n')
    if not (stage / 'config/config.txt').exists():
        (stage / 'config').mkdir(exist_ok=True)
        (stage / 'config/config.txt').write_bytes(b'')
    manifest = dict(head=head, suite='human', control='none', prepared_only=True,
                    native_executed=False, original_bytes=total, original_git_files=originals,
                    adaptations=adaptations, dme=dme.relative_to(out).as_posix(),
                    archive=dict(bytes=archive.stat().st_size, sha256=file_digest(archive)),
                    stage_files={p.relative_to(stage).as_posix(): dict(bytes=p.stat().st_size,
                        sha256=current.legacy.digest(p.read_bytes())) for p in stage.rglob('*') if p.is_file()})
    (out / 'source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


def file_digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def prepare(out):
    manifest = prepare_source(ROOT, out)
    current.adapt(out, manifest, 'tests/human_subtile/probe.dm',
                  '\t\t\thuman_subtile_fixture_headless()', '\t\t\tnpc_subtile_fixture()')
    current.adapt(out, manifest, 'tests/human_subtile/probe.dm',
                  '"checks" = human_subtile_fixture_checks,',
                  '"checks" = human_subtile_fixture_checks, "npc_checks" = npc_subtile_checks, "npc_rows" = npc_subtile_rows,')
    dme = out / manifest['dme']
    with dme.open('a', encoding='utf-8') as stream:
        stream.write('\n#include "tests\\human_subtile\\npc.dm"\n')
    for relative in ('tests/human_subtile/probe.dm', 'human_subtile.dme'):
        path = out / 'stage' / relative
        manifest['stage_files'][relative] = dict(bytes=path.stat().st_size, sha256=file_digest(path))
    manifest['npc_scope'] = 'unowned vendor AI; no client authority adapter'
    manifest['runtime_executed'] = False
    (out / 'npc-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


def validate_npc_receipt(row, head):
    """Future native oracle; never treat compile output or counts alone as PASS."""
    current.require(row.get('head') == head and row.get('error') is None and
                    row.get('port') == 0 and (row.get('byond_version'), row.get('byond_build')) == (516, 1688),
                    'Wrong NPC source/engine or failed native fixture')
    current.require(row.get('npc_checks') == 46, 'Incomplete NPC native assertions')
    rows = row.get('npc_rows')
    current.require(isinstance(rows, list) and [r.get('direction') for r in rows] == [1, 2, 4, 8, 5, 9, 6, 10], 'Missing NPC directions')
    for scene in rows:
        direction = scene['direction']
        dx = 1 if direction & 4 else -1 if direction & 8 else 0
        dy = 1 if direction & 1 else -1 if direction & 2 else 0
        pulses = scene.get('pulses')
        current.require(isinstance(pulses, list) and len(pulses) == 16 and
                        scene.get('deadline') == scene.get('started') + 4, 'Wrong NPC pulse count/deadline')
        for index, pulse in enumerate(pulses, 1):
            # Coordinates are authoritative; native Move return truthiness is not.
            current.require((pulse['x'] - 5) * 32 + pulse['sx'] == index * 2 * dx and
                            (pulse['y'] - 5) * 32 + pulse['sy'] == index * 2 * dy,
                            'Wrong physical NPC displacement')
            due = scene['started'] + (index - 1) * 4 / 16
            current.require(due <= pulse['at'] <= due + .5, 'NPC pulse cadence outside one server tick')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--prepare-only', action='store_true')
    mode.add_argument('--compile-only', action='store_true')
    parser.add_argument('--byond-bin', type=Path)
    args = parser.parse_args()
    current.require(args.prepare_only or args.byond_bin, 'Compile requires pinned BYOND directory')
    out = args.output.resolve()
    manifest = prepare(out)
    if args.prepare_only:
        print('Prepared NPC exact Git ' + manifest['head'] + '; no native execution')
        return
    dme = out / manifest['dme']
    binary = args.byond_bin.resolve() / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    session = current.Session(out / 'supervisor', manifest['head'], backend_factory=current.current_backend) if os.name == 'nt' else None
    built = current.run_phase(session, [str(binary), '-max_errors', '0', str(dme)],
                              cwd=out / 'stage', phase='compile', timeout=120,
                              artifacts=[dme.with_suffix('.dmb'), dme.with_suffix('.rsc')])
    log = built.stdout + built.stderr
    (out / 'compile.log').write_text(log)
    current.require(built.returncode == 0, 'NPC fixture compiler exit failed')
    current.legacy.validate_compile(log, dme.with_suffix('.dmb').name)
    for relative, expected in manifest['stage_files'].items():
        path = out / 'stage' / relative
        current.require(path.stat().st_size == expected['bytes'] and file_digest(path) == expected['sha256'],
                        'Compiler altered staged input: ' + relative)
    receipt = dict(head=manifest['head'], engine='516.1688', compile_passed=True,
                   runtime_executed=False, native_client=False, input_hashes_verified=len(manifest['stage_files']),
                   artifacts={p.name: dict(bytes=p.stat().st_size, sha256=file_digest(p))
                              for p in (dme.with_suffix('.dmb'), dme.with_suffix('.rsc'))})
    (out / 'compile-accepted.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
