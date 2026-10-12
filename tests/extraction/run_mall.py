"""Pinned mall compilation/native probe, offline temporary storage only."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--compile-only', action='store_true')
    parser.add_argument('--negative-control', choices=('mission', 'vehicle'))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    prefix = '.mall_' + uuid.uuid4().hex
    files = [root / (prefix + suffix) for suffix in ('.dme', '_world.dm', '_globals.dm', '_metadata.dm', '.dmb', '.rsc')]
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    try:
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_mall_startup()', 1)
        world = world.replace('/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n', 1)
        files[1].write_text(world, encoding='utf-8')
        globals_text = (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        marker = '/datum/controller/global_vars/New()\n'
        if globals_text.count(marker) != 1:
            raise RuntimeError('Global startup isolation marker changed')
        files[2].write_text(globals_text.replace(marker, marker+'\treturn\n', 1), encoding='utf-8')
        source = source.replace('code\\world.dm', files[1].name).replace('code\\controllers\\mc\\globals.dm', files[2].name)
        expected = None
        if args.negative_control:
            metadata = (root / 'code/modules/1713/extraction/mall.dm').read_text(encoding='utf-8')
            marker, replacement, expected = {
                'mission': ('return level in list(1, 4, 5)', 'return level in list(1, 2, 3, 4, 5)', 'secure floors excluded by mission policy'),
                'vehicle': ('return ..() && istype(E, /obj/effect/extraction_exit/highway) && E.z == 1', 'return ..()', 'only highway exits admit cars'),
            }[args.negative_control]
            if metadata.count(marker) != 1:
                raise RuntimeError('Mutation marker changed')
            files[3].write_text(metadata.replace(marker, replacement), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\extraction\\mall.dm', files[3].name)
        source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
        source += '\n#include "tests/extraction/mall_probe.dm"\n#include "maps/extraction/interchange_mall.dmm"\n'
        files[0].write_text(source, encoding='utf-8')
        compiled = subprocess.run([str(compiler), '-max_errors', '0', files[0].name], cwd=root, capture_output=True, text=True, timeout=120, creationflags=flags)
        output = compiled.stdout + compiled.stderr
        if compiled.returncode or '516.1681' not in output or '0 errors, 0 warnings' not in output:
            raise RuntimeError(output)
        print('PASS: pinned mall fixture compile')
        if args.compile_only:
            return
        with tempfile.TemporaryDirectory(prefix='civ13-mall-') as directory:
            target = Path(directory)
            shutil.copy2(files[4], target / 'probe.dmb')
            shutil.copy2(files[5], target / 'probe.rsc')
            shutil.copytree(root / 'config/names', target / 'config/names')
            platform = ['-invisible', '-close'] if os.name == 'nt' else []
            try:
                result = subprocess.run([str(daemon), 'probe.dmb', *platform, '-safe', '-log', 'runtime.log'], cwd=target, capture_output=True, text=True, timeout=90, creationflags=flags)
            except subprocess.TimeoutExpired as error:
                # subprocess.run kills and waits for this directly owned headless
                # process before returning. Read diagnostics before temp cleanup.
                log_path = target / 'runtime.log'
                log = log_path.read_text(errors='replace') if log_path.exists() else 'No runtime log produced'
                raise RuntimeError('Native mall fixture exceeded 90 seconds:\n'+log) from error
            report = (target / 'result.txt').read_text(encoding='utf-8') if (target / 'result.txt').exists() else ''
            log = result.stdout + result.stderr + ((target / 'runtime.log').read_text(errors='replace') if (target / 'runtime.log').exists() else '')
            if result.returncode or any(value in log.lower() for value in ('runtime error', 'bad ref', '## error')):
                raise RuntimeError(log)
            if expected:
                if not report.startswith('FAIL:') or expected not in report:
                    raise RuntimeError('Negative control missed expected assertion: '+report+'\n'+log)
                print('PASS: negative control rejected at '+expected)
            elif not report.startswith('PASS:'):
                raise RuntimeError(report+'\n'+log)
            else:
                print(report.strip())
    finally:
        for path in files:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()

