"""Bounded production trench whole-world save probe with temporary runtime storage."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid


def argument_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', choices=('filling', 'digging'))
    # Historical callers remain strict 1681. Current-target admission is explicit
    # and cannot relabel the old receipts or silently accept a future engine.
    parser.add_argument('--expected-byond-version', choices=('516.1681', '516.1688'), default='516.1681')
    parser.add_argument('--compile-only', action='store_true')
    return parser


def compiler_matches(text, returncode, version):
    return (returncode == 0 and
            re.search(r'^DM compiler version ' + re.escape(version) + r'\b', text, re.MULTILINE) is not None and
            re.search(r'\b0 errors,\s*0 warnings\b', text) is not None)


def main():
    args = argument_parser().parse_args()
    root = Path(__file__).resolve().parents[2]
    stem = '.trench_save_' + uuid.uuid4().hex
    generated = {suffix: root / (stem + suffix) for suffix in
                 ('.dme', '_world.dm', '_globals.dm', '_trench.dm', '.dmb', '.rsc')}
    output = Path(tempfile.mkdtemp(prefix='civ13-trench-save-'))
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    print(f'Evidence: {output}', flush=True)
    try:
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_trench_startup()', 1)
        world = world.replace('/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n', 1)
        generated['_world.dm'].write_text(world, encoding='utf-8')
        globals_source = (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        marker = '/datum/controller/global_vars/New()\n'
        if globals_source.count(marker) != 1:
            raise RuntimeError('Global isolation marker changed')
        generated['_globals.dm'].write_text(globals_source.replace(marker, marker + '\treturn\n'), encoding='utf-8')
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        for original, suffix in [('code\\world.dm', '_world.dm'),
                                 ('code\\controllers\\mc\\globals.dm', '_globals.dm')]:
            source = source.replace(original, generated[suffix].name)
        if args.negative_control:
            trench = (root / 'code/modules/1713/trench.dm').read_text(encoding='utf-8')
            marker = 'icon_state;name;trench_filling' if args.negative_control == 'filling' else 'icon_state;name;trench_stage'
            if trench.count(marker) != (1 if args.negative_control == 'filling' else 2):
                raise RuntimeError('Trench allowlist mutation marker changed')
            generated['_trench.dm'].write_text(trench.replace(marker, 'icon_state;name'), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\trench.dm', generated['_trench.dm'].name)
        source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
        generated['.dme'].write_text(source + '\n#include "tests/trench_save/probe.dm"\n', encoding='utf-8')
        head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
        metadata = {'commit': head, 'negative_control': args.negative_control,
            'normal_startup': False, 'map': 'synthetic 12x8x2 trench layout',
            'expected_byond_version': args.expected_byond_version,
            'compile_only': args.compile_only, 'runtime_started': False}
        (output / 'metadata.json').write_text(json.dumps(metadata), encoding='utf-8')
        (output / 'checkout.patch').write_text(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=root, text=True), encoding='utf-8')
        shutil.copy2(root / 'tests/trench_save/probe.dm', output / 'probe.dm')
        for path in generated.values():
            if path.exists():
                shutil.copy2(path, output / path.name)
        compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated['.dme'])], cwd=root,
                               capture_output=True, text=True, timeout=120, creationflags=flags)
        text = build.stdout + build.stderr
        (output / 'compile.log').write_text(text, encoding='utf-8')
        print(text, flush=True)
        if not compiler_matches(text, build.returncode, args.expected_byond_version):
            raise RuntimeError('Pinned production-source compilation failed')
        for suffix in ('.dmb', '.rsc'):
            shutil.copy2(generated[suffix], output / generated[suffix].name)
        metadata['compiler_verified'] = args.expected_byond_version
        (output / 'metadata.json').write_text(json.dumps(metadata), encoding='utf-8')
        if args.compile_only:
            print('PASS: prepared trench fixture compiled; runtime not started', flush=True)
            return
        for rel in subprocess.check_output(['git', 'ls-files', 'config/names'], cwd=root, text=True).splitlines():
            destination = output / rel
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / rel, destination)
        command = [str(daemon), str(output / generated['.dmb'].name)]
        if os.name == 'nt':
            command += ['-invisible', '-close']
        metadata['runtime_started'] = True
        (output / 'metadata.json').write_text(json.dumps(metadata), encoding='utf-8')
        runtime = subprocess.run(command + ['-trusted', '-log', 'runtime.log'], cwd=output,
                                 capture_output=True, text=True, timeout=60, creationflags=flags)
        (output / 'daemon.log').write_text(runtime.stdout + runtime.stderr, encoding='utf-8')
        log = (output / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        print(log, flush=True)
        result = (output / 'trench_result.txt').read_text(encoding='utf-8')
        print(result, flush=True)
        expected = ('FAIL: trench fill progress survives' if args.negative_control == 'filling' else
                    'FAIL: dirt and sand partial digging survives' if args.negative_control == 'digging' else 'PASS:')
        if runtime.returncode or not result.startswith(expected) or any(x in log.lower() for x in ('runtime error:', '## error:', 'bug:')):
            raise RuntimeError('Production trench save probe failed')
        if args.negative_control:
            print('PASS: expected trench omission mutation detected', flush=True)
        metadata['runtime_result'] = 'passed'
        (output / 'metadata.json').write_text(json.dumps(metadata), encoding='utf-8')
    finally:
        for path in generated.values():
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
