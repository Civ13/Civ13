"""Boot the full production game headless and exercise base systems; fails on any runtime error.

No client connects and no port is opened. The world runs from a temporary copy of
the tracked config with webhooks, ToR bans and persistence saving disabled.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
DIAGNOSTICS = re.compile(r'Infinite loop suspected|switching proc to background|runtime error|\bBad ref\b|\bBad loc\b|Cannot read null|Cannot execute null|\bBUG:|##\s*ERROR:', re.I)
EXPECTED = 'PASS: boot, round start, scheduler, mob, chemistry and object lifecycle without world errors'
# Generated-source controls; each must be caught by the named mechanism.
CONTROLS = {
    'runtime': ('code/modules/reagents/Chemistry-Holder.dm',
                '/datum/reagents/proc/process_reactions()\n',
                '/datum/reagents/proc/process_reactions()\n\tif (my_atom && istype(my_atom, /obj/item/weapon/reagent_containers/glass/beaker/large))\n\t\tvar/list/core_boot_control = null\n\t\tcore_boot_control.Cut()\n',
                'runtime diagnostic'),
}
DEADLINE_SECONDS = 600


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], text=True, encoding='utf-8')


def scan_logs(work):
    hits = []
    for path in work.rglob('*'):
        if path.is_file() and path.suffix in ('.log', '.txt') and path.name not in ('compile.log', 'result.txt'):
            text = path.read_text(errors='replace')
            for line in text.splitlines():
                if DIAGNOSTICS.search(line):
                    hits.append(f'{path.relative_to(work)}: {line.strip()[:300]}')
    return hits


def generate(control, created):
    dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8-sig')
    if control:
        path, old, new, _ = CONTROLS[control]
        source = (ROOT / path).read_text(encoding='utf-8-sig')
        if source.count(old) != 1:
            raise RuntimeError('Control target missing or ambiguous: ' + control)
        generated = ROOT / ('.core_boot_' + uuid.uuid4().hex + '_control.dm')
        generated.write_text(source.replace(old, new, 1), encoding='utf-8')
        created.append(generated)
        include = '#include "' + path.replace('/', '\\') + '"'
        if dme.count(include) != 1:
            raise RuntimeError('Control include missing: ' + path)
        dme = dme.replace(include, '#include "' + generated.name + '"')
    dme += '\n#include "tests\\core_boot\\probe.dm"\n'
    source = ROOT / ('.core_boot_' + uuid.uuid4().hex + '.dme')
    source.write_text(dme, encoding='utf-8')
    created += [source, source.with_suffix('.dmb'), source.with_suffix('.rsc')]
    return source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--negative-control', choices=CONTROLS)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    if any(args.output.iterdir()):
        parser.error('Preserve existing evidence; use an empty output directory')
    byond = args.byond_bin.resolve()
    compiler = byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    head = git('rev-parse', 'HEAD').strip()
    (args.output / 'metadata.json').write_text(json.dumps({
        'head_sha': head, 'control': args.negative_control,
        'probe_sha256': hashlib.sha256((ROOT / 'tests/core_boot/probe.dm').read_bytes()).hexdigest(),
        'scope': 'Headless full-source boot of the default map with processes running; no clients, round start, rendering or long-term memory'}, indent=2), encoding='utf-8')
    (args.output / 'tested.patch').write_text(git('diff', 'HEAD'), encoding='utf-8')
    created = []
    try:
        source = generate(args.negative_control, created)
        build = subprocess.run([str(compiler), '-max_errors', '0', str(source)], cwd=ROOT,
                               capture_output=True, text=True, timeout=600, creationflags=flags)
        compile_log = build.stdout + build.stderr
        (args.output / 'compile.log').write_text(compile_log, encoding='utf-8')
        if build.returncode or '516.1681' not in compile_log or '0 errors, 0 warnings' not in compile_log:
            raise RuntimeError('Pinned zero-error/zero-warning compilation failed:\n' + compile_log[-4000:])
        with tempfile.TemporaryDirectory(prefix='civ13-core-boot-') as temporary:
            work = Path(temporary)
            for suffix in ('.dmb', '.rsc'):
                shutil.copy2(source.with_suffix(suffix), work / ('probe' + suffix))
            for path in git('ls-files', '--', 'config').splitlines():
                destination = work / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / path, destination)
            command = [str(daemon), 'probe.dmb']
            if os.name == 'nt':
                command += ['-invisible', '-close']
            command += ['-safe', '-log', 'startup.log']
            started = time.monotonic()
            with (work / 'stdout.log').open('w') as stdout, (work / 'stderr.log').open('w') as stderr:
                process = subprocess.Popen(command, cwd=work, stdout=stdout, stderr=stderr, creationflags=flags)
                try:
                    process.wait(timeout=DEADLINE_SECONDS)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=10)
            wall = time.monotonic() - started
            hits = scan_logs(work)
            for path in work.rglob('*'):
                if path.is_file() and path.suffix in ('.log', '.txt', '.json') and path.stat().st_size < 8 * 1024 * 1024:
                    destination = args.output / 'runtime' / path.relative_to(work)
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, destination)
            result = (work / 'result.txt').read_text(errors='replace').strip() if (work / 'result.txt').exists() else ''
            summary = {'returncode': process.returncode, 'wall_seconds': round(wall, 1), 'result': result, 'diagnostics': hits[:200]}
            (args.output / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
        if args.negative_control:
            expected = CONTROLS[args.negative_control][3]
            detected = bool(hits) if expected == 'runtime diagnostic' else result == expected
            if not detected:
                raise RuntimeError(f'Negative control {args.negative_control} was not detected: {summary}')
            print(f'PASS expected mutation: {args.negative_control} detected ({result or hits[0]})')
            return
        if hits or result != EXPECTED or wall >= DEADLINE_SECONDS:
            raise RuntimeError('Core boot failed: ' + json.dumps(summary, indent=2)[:6000])
        print(f'{result} ({wall:.0f}s)')
    finally:
        for path in created:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
