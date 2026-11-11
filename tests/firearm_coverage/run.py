"""Coverage manifest of every gun type, from compiler-resolved defaults.

Compiles the production game with normal startup disabled, dumps the
compiler-resolved defaults of every /obj/item/weapon/gun type and, with
--write, regenerates docs/firearm-coverage.json through firearm_coverage.py.
Without --write it fails when the checked-in manifest is stale.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import uuid


def compiler_matches(text, returncode, version):
    return (returncode == 0 and
            re.search(r'^DM compiler version ' + re.escape(version) + r'\b', text, re.MULTILINE) is not None and
            re.search(r'\b0 errors,\s*0 warnings\b', text) is not None)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--expected-byond-version', default='516.1688')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    stem = '.firearm_coverage_' + uuid.uuid4().hex
    generated = {suffix: root / (stem + suffix) for suffix in
                 ('.dme', '_world.dm', '_globals.dm', '_helpers.dm', '.dmb', '.rsc')}
    output = Path(tempfile.mkdtemp(prefix='civ13-firearm-coverage-'))
    print(f'Evidence: {output}', flush=True)
    try:
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_roof_startup()', 1)
        world = world.replace('/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n', 1)
        generated['_world.dm'].write_text(world, encoding='utf-8')
        globals_source = (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        marker = '/datum/controller/global_vars/New()\n'
        if globals_source.count(marker) != 1:
            raise RuntimeError('Global isolation marker changed')
        generated['_globals.dm'].write_text(globals_source.replace(marker, marker + '\treturn\n'), encoding='utf-8')
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        replacements = [('code\\world.dm', '_world.dm'), ('code\\controllers\\mc\\globals.dm', '_globals.dm')]
        for original, suffix in replacements:
            if source.count(original) != 1:
                raise RuntimeError(f'Include {original} missing from civ13.dme')
            source = source.replace(original, generated[suffix].name)
        source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
        generated['.dme'].write_text(source + '\n#include "tests/firearm_coverage/probe.dm"\n', encoding='utf-8')
        compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated['.dme'])], cwd=root,
                               capture_output=True, text=True, timeout=300)
        text = build.stdout + build.stderr
        (output / 'compile.log').write_text(text, encoding='utf-8')
        print(text, flush=True)
        if not compiler_matches(text, build.returncode, args.expected_byond_version):
            raise RuntimeError('Pinned production-source compilation failed')
        for suffix in ('.dmb', '.rsc'):
            shutil.copy2(generated[suffix], output / generated[suffix].name)
        for rel in subprocess.check_output(['git', 'ls-files', 'config/names'], cwd=root, text=True).splitlines():
            destination = output / rel
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / rel, destination)
        (output / 'data').mkdir(exist_ok=True)
        command = [str(daemon), str(output / generated['.dmb'].name)]
        if os.name == 'nt':
            command += ['-invisible', '-close']
        runtime = subprocess.run(command + ['-trusted', '-log', 'runtime.log'], cwd=output,
                                 capture_output=True, text=True, timeout=120)
        (output / 'daemon.log').write_text(runtime.stdout + runtime.stderr, encoding='utf-8')
        log = (output / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        print(log, flush=True)
        result = (output / 'firearm_result.txt').read_text(encoding='utf-8')
        print(result, flush=True)
        if runtime.returncode or not result.startswith('PASS:') or any(x in log.lower() for x in ('runtime error:', '## error:', 'bug:')):
            raise RuntimeError('Firearm coverage probe failed')
        rows = json.loads((output / 'firearm_types.json').read_text(encoding='utf-8'))
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import firearm_coverage
        manifest = firearm_coverage.build(rows)
        target = root / firearm_coverage.MANIFEST
        text = firearm_coverage.dump(manifest)
        if args.write:
            target.write_text(text, encoding='utf-8')
            print(f'Wrote {firearm_coverage.MANIFEST}: {manifest["summary"]}', flush=True)
        elif not target.exists() or target.read_text(encoding='utf-8') != text:
            raise RuntimeError(f'{firearm_coverage.MANIFEST} is stale: rerun with --write')
        else:
            print(f'PASS: {firearm_coverage.MANIFEST} is current', flush=True)
    finally:
        for path in generated.values():
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
