"""Prepare by default. Native execution requires --native and maintainer approval."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[2]


def prepare(prefix):
    generated = {}
    for original, suffix, marker in (
        ('code/world.dm', '_world.dm', '/datum/global_init/New()\n'),
        ('code/controllers/mc/globals.dm', '_globals.dm', '/datum/controller/global_vars/New()\n')):
        source = (ROOT / original).read_text(encoding='utf-8')
        if original == 'code/world.dm':
            start = source.index('/world/New()')
            parent = source.index('\n\t..()', start)
            source = source[:parent] + source[parent:].replace('\n\t..()', '', 1)
            source = source.replace('/world/New()', '/world/proc/unused_tree_startup()', 1)
        if source.count(marker) != 1:
            raise RuntimeError('Startup isolation marker drift: ' + original)
        generated[suffix] = source.replace(marker, marker + '\treturn\n', 1)
    source = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
    for original, suffix in (('code\\world.dm', '_world.dm'),
                             ('code\\controllers\\mc\\globals.dm', '_globals.dm')):
        if source.count(original) != 1:
            raise RuntimeError('Include marker drift: ' + original)
        source = source.replace(original, prefix + suffix)
    source = re.sub(r'^#include ".*\.dmm".*$', '', source, flags=re.M)
    generated['.dme'] = source + '\n#include "tests/tree_planting/probe.dm"\n'
    return generated


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--native', action='store_true')
    parser.add_argument('--byond-bin', type=Path)
    args = parser.parse_args()
    if args.native and not args.byond_bin:
        parser.error('--native requires --byond-bin')
    args.output.mkdir(parents=True, exist_ok=True)
    if any(args.output.iterdir()):
        parser.error('Use an empty evidence directory')
    prefix = '.tree_probe_' + uuid.uuid4().hex
    generated = prepare(prefix)
    files = ('code/game/objects/farming.dm', 'code/game/turfs/floor_attackby.dm',
             'code/game/objects/structures/wild.dm', 'code/modules/persistence/saving.dm',
             'code/modules/persistence/loading.dm', 'tests/tree_planting/probe.dm')
    metadata = dict(head_sha=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    native_requested=args.native, map='synthetic 8x4x1', normal_startup=False,
                    source_sha256={name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in files})
    (args.output / 'metadata.json').write_text(json.dumps(metadata, indent=2))
    (args.output / 'tested.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=ROOT))
    for suffix, text in generated.items():
        (args.output / (prefix + suffix)).write_text(text, encoding='utf-8')
    shutil.copy2(ROOT / 'tests/tree_planting/probe.dm', args.output / 'probe.dm')
    if not args.native:
        print('PASS: production-source fixture prepared; no compiler or runtime executed')
        return
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    binary = args.byond_bin.resolve()
    paths = [ROOT / (prefix + suffix) for suffix in (*generated, '.dmb', '.rsc')]
    try:
        for suffix, text in generated.items():
            (ROOT / (prefix + suffix)).write_text(text, encoding='utf-8')
        build = subprocess.run([str(binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')),
                                '-max_errors', '0', str(ROOT / (prefix + '.dme'))], cwd=ROOT,
                               capture_output=True, text=True, timeout=180, creationflags=flags)
        output = build.stdout + build.stderr
        (args.output / 'compile.log').write_text(output)
        if build.returncode or 'DM compiler version 516.1681' not in output or '0 errors, 0 warnings' not in output:
            raise RuntimeError('Pinned compile failed: ' + output[-4000:])
        with tempfile.TemporaryDirectory(prefix='civ13-tree-runtime-') as temporary:
            work = Path(temporary)
            for suffix in ('.dmb', '.rsc'):
                shutil.copy2(ROOT / (prefix + suffix), work / (prefix + suffix))
            shutil.copytree(ROOT / 'config/names', work / 'config/names')
            runtime = subprocess.run([str(binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')),
                                      str(work / (prefix + '.dmb')),
                                      *(['-invisible', '-close'] if os.name == 'nt' else []),
                                      '-trusted', '-log', 'runtime.log'], cwd=work,
                                     capture_output=True, text=True, timeout=45, creationflags=flags)
            diagnostics = runtime.stdout + runtime.stderr
            for name in ('runtime.log', 'result.txt', 'errors.txt'):
                if (work / name).exists():
                    shutil.copy2(work / name, args.output / name)
                    if name != 'result.txt':
                        diagnostics += (work / name).read_text(errors='replace')
            (args.output / 'daemon.log').write_text(runtime.stdout + runtime.stderr)
            result = (work / 'result.txt').read_text().strip() if (work / 'result.txt').exists() else ''
            if runtime.returncode or result != 'PASS: tree planting production paths and disk round trip' or any(
                    marker in diagnostics.lower() for marker in ('runtime error:', 'runtime in ', 'uncaught exception:', 'bug:', '## error:')):
                raise RuntimeError('Native fixture failed: ' + result + '\n' + diagnostics[-3000:])
            print(result)
    finally:
        for path in paths:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
