"""Compile the production Wiremod sources with probe.dm and run them natively.

    python3 tests/wiremod/run.py --byond-bin "$HOME/byond-516.1688/byond/bin"

The fixture holds code/__defines/wiremod.dm, every file under
code/modules/wiremod and the probe; nothing else from the game. --source-root
points at another checkout's files to see which checks that version fails; the
checkout needs the current type and field names for the probe to compile.
--evidence-dir keeps the logs.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[2]
PINNED_BYOND = json.loads((REPO / 'tools/byond/version.json').read_text(encoding='utf-8'))['version']
PINNED_BANNER = 'DM compiler version ' + PINNED_BYOND


def sources(root):
    files = sorted((root / 'code/__defines').glob('wiremod.dm'))
    files += sorted((root / 'code/modules/wiremod').rglob('*.dm'))
    if not any('core' in path.parts for path in files):
        raise SystemExit('No Wiremod sources under ' + str(root))
    return files


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--source-root', type=Path, default=REPO)
    parser.add_argument('--evidence-dir', type=Path)
    parser.add_argument('--allow-failures', action='store_true',
                        help='report failed checks without a failing exit status')
    args = parser.parse_args()
    win = (args.byond_bin / 'dm.exe').exists()
    compiler = args.byond_bin / ('dm.exe' if win else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if win else 'DreamDaemon')
    environment = dict(os.environ)
    if not win:
        environment['LD_LIBRARY_PATH'] = str(args.byond_bin) + os.pathsep + environment.get('LD_LIBRARY_PATH', '')
    with tempfile.TemporaryDirectory(prefix='civ13-wiremod-') as directory:
        temp = Path(directory)
        # Constants first, then the probe's stand-ins, then the module.
        defines, module = [], []
        shutil.copy(Path(__file__).with_name('probe.dm'), temp / 'probe.dm')
        for index, path in enumerate(sources(args.source_root.resolve())):
            name = 'production_%02d_%s' % (index, path.name)
            shutil.copy(path, temp / name)
            constants = '__defines' in path.parts or path.name == '_compat.dm'
            (defines if constants else module).append('#include "%s"' % name)
        includes = defines + ['#include "probe.dm"'] + module
        # The module's icons are not part of the behaviour under test. Its sounds
        # are: DM needs the files at compile time, so copy just the referenced
        # ones from the checkout into the temporary fixture.
        for path in temp.glob('production_*.dm'):
            text = path.read_text(encoding='utf-8')
            path.write_text(re.sub(r"^\s*icon = '[^']*'\s*$", '', text, flags=re.M), encoding='utf-8')
            for asset in re.findall(r"'((?:sound|icons)/[^']+)'", path.read_text(encoding='utf-8')):
                asset_path = args.source_root.resolve() / asset
                if not asset_path.is_file():
                    continue
                destination = temp / asset
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(asset_path, destination)
        (temp / 'probe.dme').write_text('\n'.join(includes) + '\n', encoding='utf-8')
        compiled = subprocess.run([str(compiler), 'probe.dme'], cwd=temp, capture_output=True,
                                  text=True, timeout=120, env=environment)
        print(compiled.stdout, end='')
        clean = (not compiled.returncode and PINNED_BANNER in compiled.stdout
                 and '0 errors, 0 warnings' in compiled.stdout)
        log = ''
        returncode = None
        if clean:
            process = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-trusted', '-log', 'runtime.log'],
                                     cwd=temp, capture_output=True, timeout=120, env=environment)
            returncode = process.returncode
            log = (temp / 'runtime.log').read_text(encoding='utf-8', errors='replace')
            print(log, end='')
        if args.evidence_dir:
            args.evidence_dir.mkdir(parents=True, exist_ok=True)
            (args.evidence_dir / 'compile.log').write_text(compiled.stdout + compiled.stderr, encoding='utf-8')
            (args.evidence_dir / 'runtime.log').write_text(log, encoding='utf-8')
        if not clean:
            raise SystemExit('Fixture compilation failed' + ('' if not compiled.stderr else ': ' + compiled.stderr))
        failed = re.findall(r'^FAIL (.+)$', log, re.M)
        engine_error = bool(re.search(r'runtime error|bad ref|bad loc', log, re.I))
        passed = not returncode and not failed and not engine_error and re.search(r'^PASS wiremod', log, re.M)
        if not passed:
            print('%d failed check(s); runtime errors: %s' % (len(failed), engine_error))
            if not args.allow_failures:
                raise SystemExit(1)


if __name__ == '__main__':
    main()
