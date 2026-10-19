"""Stage exact committed sources; optionally run closed, bounded Linux CI probes.

--prepare-only never resolves or launches a BYOND executable. Windows native
execution needs the separately reviewed owned-Job envelope, not this CI runner.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import signal
import subprocess
import tarfile
import time

ROOT = Path(__file__).resolve().parents[2]
DIAGNOSTICS = re.compile(
    r'infinite[ _]loop|switching proc to background|runtime error|unexpected runtime|'
    r'\bBad ref\b|\bBad loc\b|Cannot read null|Cannot execute null|\bBUG:|'
    r'##\s*ERROR\s*:|uncaught exception|fatal error|segmentation|assertion failed|\bRUNTIME:|'
    r'\bOOM\b|out of memory|access violation|\bCRASH(?:ED)?\b|invalid file', re.I)
LIMIT_FILES = 8000
LIMIT_BYTES = 2 * 1024**3


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args])


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def isolate_startup(rel, text):
    """Same two startup seams as the existing full-source durable fixture."""
    if rel == 'code/world.dm':
        start = text.index('/world/New()')
        parent = text.index('\n\t..()', start)
        text = text[:parent] + text[parent:].replace('\n\t..()', '', 1)
        text = text.replace('/world/New()', '/world/proc/unused_subtile_fixture_startup()', 1)
        marker = '/datum/global_init/New()\n'
    elif rel == 'code/controllers/mc/globals.dm':
        marker = '/datum/controller/global_vars/New()\n'
    else:
        raise ValueError('Unknown startup seam')
    if text.count(marker) != 1:
        raise ValueError('Startup isolation anchor drift: ' + rel)
    return text.replace(marker, marker + '\treturn\n', 1)


def prepare(root, out, suite, control='none'):
    if suite not in ('human', 'primitive') or control not in ('none', 'cosmetic'):
        raise ValueError('Unknown suite/control')
    if suite == 'human' and control != 'none':
        raise ValueError('The human fixture has no cosmetic transport adapter')
    out = out.resolve()
    if out.exists():
        raise ValueError('Evidence output must not already exist')
    head = git(root, 'rev-parse', 'HEAD').decode().strip()
    if not re.fullmatch('[0-9a-f]{40}', head):
        raise ValueError('Expected exact commit')
    # Always use Git objects. Uncommitted source cannot silently enter evidence.
    wanted = (['civ13.dme', 'code', 'icons', 'sound', 'UI', 'interface', 'config',
               'tests/human_subtile'] if suite == 'human' else ['tests/subtile_movement'])
    tracked = git(root, 'ls-tree', '-r', '--name-only', head).decode().splitlines()
    wanted = [p for p in wanted if any(f == p or f.startswith(p + '/') for f in tracked)]
    if not wanted:
        raise ValueError('Missing fixture source')
    out.mkdir(parents=True)
    stage = out / 'stage'
    stage.mkdir()
    proc = subprocess.Popen(['git', '-C', str(root), 'archive', '--format=tar', head,
                             '--', *wanted], stdout=subprocess.PIPE)
    originals = {}
    total = 0
    try:
        with tarfile.open(fileobj=proc.stdout, mode='r|') as archive:
            for member in archive:
                if member.isdir():
                    continue
                name = PurePosixPath(member.name)
                if (not member.isfile() or name.is_absolute() or '..' in name.parts
                        or member.size > 256 * 1024**2):
                    raise ValueError('Unsafe/oversized archive input')
                total += member.size
                if total > LIMIT_BYTES or len(originals) >= LIMIT_FILES:
                    raise ValueError('Source budget exceeded')
                target = stage.joinpath(*name.parts)
                if not target.resolve().is_relative_to(stage):
                    raise ValueError('Source escaped stage')
                raw = archive.extractfile(member).read()
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(raw)
                originals[member.name] = {'bytes': len(raw), 'sha256': digest(raw)}
        if proc.wait(timeout=30):
            raise ValueError('Git archive failed')
    finally:
        if proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=10)
        if proc.stdout:
            proc.stdout.close()
    adaptations = {}
    if suite == 'human':
        for rel in ('code/world.dm', 'code/controllers/mc/globals.dm'):
            path = stage / rel
            adapted = isolate_startup(rel, path.read_text(encoding='utf-8'))
            path.write_text(adapted, encoding='utf-8', newline='\n')
            adaptations[rel] = {'original_sha256': originals[rel]['sha256'],
                                'adapted_sha256': digest(path.read_bytes())}
        source = (stage / 'civ13.dme').read_text(encoding='utf-8')
        source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
        source += '\n#include "tests\\human_subtile\\probe.dm"\n'
        dme = stage / 'human_subtile.dme'
        dme.write_text(source, encoding='utf-8', newline='\n')
        # Names/public data only; this is still a temporary committed snapshot.
        if not (stage / 'config/config.txt').exists():
            (stage / 'config').mkdir(exist_ok=True)
            (stage / 'config/config.txt').write_bytes(b'')
    else:
        dme = stage / 'tests/subtile_movement/prototype.dme'
    manifest = {'head': head, 'suite': suite, 'control': control,
                'prepared_only': True, 'native_executed': False,
                'original_bytes': total, 'original_git_files': originals,
                'adaptations': adaptations, 'dme': dme.relative_to(out).as_posix(),
                'stage_files': {p.relative_to(stage).as_posix():
                                {'bytes': p.stat().st_size, 'sha256': digest(p.read_bytes())}
                                for p in stage.rglob('*') if p.is_file()}}
    (out / 'source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    return manifest


def diagnostic_paths(work):
    paths = set(work.rglob('*.log')) | set((work / 'data/logs/runtime').rglob('*.txt'))
    if len(paths) > 128:
        raise RuntimeError('Too many diagnostic paths')
    return sorted(paths)


def inspect_logs(work, check_diagnostics=True):
    for path in diagnostic_paths(work):
        if path.stat().st_size > 4 * 1024**2:
            raise RuntimeError('Oversized diagnostic log: ' + str(path.relative_to(work)))
        if check_diagnostics and DIAGNOSTICS.search(path.read_text(errors='replace')):
            raise RuntimeError('Native diagnostic: ' + str(path.relative_to(work)))


def validate_compile(log, artifact):
    # Same exact-banner/result contract as the reviewed bounded native envelope.
    if len(log.encode('utf-8')) > 1024**2 or DIAGNOSTICS.search(log):
        raise RuntimeError('Compiler output bound or diagnostic')
    lines = log.splitlines()
    banners = [line for line in lines if re.search(r'DM compiler version', line, re.I)]
    if banners != ['DM compiler version 516.1681']:
        raise RuntimeError('Exactly one pinned compiler banner required')
    results = [line for line in lines if re.search(r'\berrors?\b|\bwarnings?\b', line, re.I)]
    summary = (re.escape(artifact) + r' - 0 errors, 0 warnings'
               r'(?: \(\d{1,2}/\d{1,2}/\d{2,4} \d{1,2}:\d{2}(?::\d{2})? (?:am|pm)\))?')
    if len(results) != 1 or not re.fullmatch(summary, results[0]):
        raise RuntimeError('Exactly one clean compiler result required')
    if lines.index(banners[0]) >= lines.index(results[0]):
        raise RuntimeError('Compiler result preceded banner')


def prepare_runtime(out, manifest):
    # Native BYOND file IO is rooted beside the DMB, not necessarily daemon cwd.
    # Put the binary and cwd in one explicit directory for BOTH suites.
    dme = out / manifest['dme']
    work = out / 'runtime'
    work.mkdir()
    artifacts = {}
    for extension in ('.dmb', '.rsc'):
        source = dme.with_suffix(extension)
        if not source.exists() and extension == '.rsc' and manifest['suite'] == 'primitive':
            continue  # The primitive has no resources; a .rsc is not produced.
        if not source.is_file() or not 0 < source.stat().st_size <= 1024**3:
            raise RuntimeError('Missing/oversized compiled artifact: ' + source.name)
        target = work / source.name
        shutil.copy2(source, target)
        raw = target.read_bytes()
        artifacts[target.name] = {'bytes': len(raw), 'sha256': digest(raw)}
    if manifest['suite'] == 'human':
        shutil.copytree(out / 'stage/config', work / 'config')
    return work, work / dme.with_suffix('.dmb').name, artifacts


def run_process(command, cwd, name, deadline):
    started = time.monotonic()
    timed_out = False
    oversized_log = False
    logs = [cwd / (name + '-' + stream + '.log') for stream in ('stdout', 'stderr')]
    with logs[0].open('wb') as stdout, logs[1].open('wb') as stderr:
        process = subprocess.Popen(command, cwd=cwd, stdout=stdout, stderr=stderr,
                                   start_new_session=True)
        try:
            while process.poll() is None:
                if time.monotonic() - started >= deadline:
                    timed_out = True
                    break
                inspect_logs(cwd, check_diagnostics=name != 'compile')
                time.sleep(0.05)
        finally:
            # Own process group only, including a surviving descendant on exit.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=10)
    inspect_logs(cwd, check_diagnostics=name != 'compile')
    row = {'command': command, 'returncode': process.returncode, 'timed_out': timed_out,
           'oversized_log': oversized_log,
           'seconds': time.monotonic() - started, 'deadline': deadline}
    if timed_out or oversized_log or process.returncode:
        raise RuntimeError('Native phase failed: ' + json.dumps(row))
    return row


def validate_receipt(row, suite, control, head):
    if type(row) is not dict or (row.get('byond_version'), row.get('byond_build')) != (516, 1681):
        raise ValueError('Wrong engine/receipt')
    if suite == 'primitive':
        # Reuse the independent physical-displacement oracle, not return truthiness.
        import importlib.util
        spec = importlib.util.spec_from_file_location('subtile_oracle', ROOT / 'tests/subtile_movement/test_oracle.py')
        oracle = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(oracle)
        oracle.receipt_contract(row, control)
        if len(row['observations']) != (9 if control == 'none' else 1):
            raise ValueError('Wrong observation count')
    else:
        if row.get('head') != head or row.get('checks') != 42 or row.get('error') is not None:
            raise ValueError('Human fixture failed/wrong source')
        rows = row.get('rows')
        if not isinstance(rows, list) or len(rows) != 1 or rows[0].get('scene') != 'normal':
            raise ValueError('Missing actual human observations')
        pulses = rows[0].get('rows')
        if not isinstance(pulses, list) or len(pulses) != 8:
            raise ValueError('Wrong human physical pulse count')
        if (pulses[0].get('sx'), pulses[0].get('locs'), pulses[0].get('native')) != (4, 2, 4):
            raise ValueError('Missing physical displacement/overlap')
        if any(p.get('native') != 4 for p in pulses):
            raise ValueError('Unexpected ordinary native displacement')


def execute(out, manifest, byond):
    if os.name != 'posix':
        raise RuntimeError('Native execution is Linux CI only; Windows requires the reviewed owned-Job envelope')
    stage = out / 'stage'
    dme = out / manifest['dme']
    compiler, daemon = byond / 'DreamMaker', byond / 'DreamDaemon'
    if not compiler.is_file() or not daemon.is_file():
        raise ValueError('Missing BYOND executables')
    phases = [run_process([str(compiler), '-max_errors', '0', str(dme)], stage, 'compile', 180)]
    compile_log = ''.join((stage / ('compile-' + stream + '.log')).read_text(errors='replace') for stream in ('stdout', 'stderr'))
    validate_compile(compile_log, dme.with_suffix('.dmb').name)
    work, binary, artifacts = prepare_runtime(out, manifest)
    params = 'tested_commit=' + manifest['head']
    if manifest['control'] != 'none':
        params += ';control=' + manifest['control']
    phases.append(run_process([str(daemon), str(binary), '59474',
                               '-ip', '127.0.0.1', '-trusted', '-params', params,
                               '-log', 'runtime.log'], work, 'daemon', 120))
    inspect_logs(work)
    expected = b'FAIL physical_east_four_pixels\n' if manifest['control'] == 'cosmetic' else b'PASS\n'
    if (work / 'port-closed.txt').read_bytes() != b'closed\n' or (work / 'result.txt').read_bytes() != expected:
        raise RuntimeError('Exact closed-port/result markers required')
    receipt = work / 'receipt.json'
    if receipt.stat().st_size > 64 * 1024:
        raise RuntimeError('Oversized native receipt')
    row = json.loads(receipt.read_text())
    validate_receipt(row, manifest['suite'], manifest['control'], manifest['head'])
    summary = {'head': manifest['head'], 'suite': manifest['suite'], 'control': manifest['control'],
               'native_executed': True, 'accepted': True, 'phases': phases,
               'runtime_root': str(work), 'artifacts': artifacts,
               'scope': 'sequential Linux CI process groups; loopback application closure, not OS socket isolation or Windows owned-Job census',
               'receipt_sha256': digest(receipt.read_bytes())}
    (out / 'runner-receipt.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite', choices=('human', 'primitive'), default='human')
    parser.add_argument('--control', choices=('none', 'cosmetic'), default='none')
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--byond-bin', type=Path)
    args = parser.parse_args()
    if not args.prepare_only and args.byond_bin is None:
        parser.error('--byond-bin is required for native execution')
    manifest = prepare(ROOT, args.output, args.suite, args.control)
    result = ({'prepared_only': True, 'head': manifest['head'], 'output': str(args.output.resolve())}
              if args.prepare_only else execute(args.output.resolve(), manifest, args.byond_bin.resolve()))
    print(json.dumps(result))


if __name__ == '__main__':
    main()
