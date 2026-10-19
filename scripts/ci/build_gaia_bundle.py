#!/usr/bin/env python3
"""Compile one immutable Gaia source tree and package runtime assets; never run it."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

REVISION = '5bf351248de6050876fe5b53f91209a970cc5668'
VERSION = '516.1681'
MAP = 'maps/nomads/nomads_gaia.dmm'
MAP_INCLUDE = '#include "maps\\nomads\\nomads_gaia.dmm"'
TREES = ('UI', 'maps/zones', 'config/names', 'config/crafting', 'sound/music', 'icons/lobby')
EXTRA = ('civ13.dmb', 'civ13.rsc', 'civ13.dme', MAP)
MAP_PATTERN = re.compile(r'^\s*#include\s+"([^"\r\n]+[.]dmm)"\s*$', re.M | re.I)


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''):
            h.update(block)
    return h.hexdigest()


def select_gaia(text):
    matches = list(MAP_PATTERN.finditer(text))
    require(len(matches) == 1, 'Expected exactly one active map include.')
    match = matches[0]
    require(match.group(1).replace('\\', '/') == 'maps/nomads/nomads.dmm',
            'Pinned source map selection differs.')
    selected = text[:match.start()] + MAP_INCLUDE + text[match.end():]
    require([p.replace('\\', '/') for p in MAP_PATTERN.findall(selected)] == [MAP],
            'Gaia selection was not exact.')
    return selected


def validate_compile(log, source):
    require(re.search(r'DM compiler version\s+516[.]1681\b', log), 'Wrong compiler version.')
    require('0 errors, 0 warnings' in log
            and not re.search(r'\b[1-9]\d* (?:errors?|warnings?)\b', log),
            'Compilation was not zero-error and zero-warning.')
    for name in ('civ13.dmb', 'civ13.rsc'):
        path = source/name
        require(path.is_file() and not path.is_symlink() and path.stat().st_size > 0,
                'Missing or invalid compiled output: '+name)


def selected_files(source):
    names = set(EXTRA)
    for folder in TREES:
        root = source/folder
        require(root.is_dir() and not root.is_symlink(), 'Missing runtime tree: '+folder)
        tree_files = 0
        for path in root.rglob('*'):
            require(not path.is_symlink(), 'Runtime tree contains a symlink.')
            if path.is_dir():
                continue
            require(path.is_file(), 'Runtime tree contains a special file.')
            names.add(path.relative_to(source).as_posix())
            tree_files += 1
        require(tree_files > 0, 'Runtime tree is empty: '+folder)
    require(len(names) <= 20000, 'Runtime inventory exceeds deployment bound.')
    for name in sorted(names):
        path = source/name
        require(path.is_file() and path.resolve() == path and not path.is_symlink(),
                'Runtime member is missing or indirect: '+name)
    return sorted(names)


def package(source, output, compile_log, provenance):
    require(not output.exists(), 'Bundle output already exists.')
    output.mkdir(parents=True)
    files = {}
    for name in selected_files(source):
        path = source/name
        target = output/'game'/name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        files[name] = {'bytes': target.stat().st_size, 'sha256': digest(target)}
        require(digest(path) == files[name]['sha256'], 'Source changed during packaging.')
    shutil.copyfile(compile_log, output/'compile.log')
    manifest = dict(schema=1, state='BUILT_NOT_DEPLOYED', revision=REVISION,
                    repository='https://github.com/Civ13/Civ13.git', map='NOMADS_GAIA',
                    map_include=MAP_INCLUDE, compiler_version=VERSION,
                    built_utc=datetime.now(timezone.utc).isoformat(),
                    compile_log_sha256=digest(output/'compile.log'), files=files,
                    provenance=provenance,
                    deployment_gates=['Build only; no game startup or save/load acceptance performed.',
                                      'Fresh deployment requires the separately reviewed host procedure.'])
    raw = json.dumps(manifest, indent=2, sort_keys=True)+'\n'
    require(len(raw.encode()) <= 2*1024*1024, 'Manifest exceeds deployment bound.')
    (output/'build-manifest.json').write_text(raw, encoding='utf-8')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source, output = args.source.resolve(strict=True), args.output.resolve()
    require(not output.exists() and source not in output.parents and output not in source.parents,
            'Bundle must be a fresh directory outside the source tree.')
    actual = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=source, text=True).strip()
    require(actual == REVISION, 'Source revision differs from pinned merge.')
    require(not subprocess.check_output(['git', 'status', '--porcelain'], cwd=source, text=True).strip(),
            'Source checkout is not clean.')
    for name in ('civ13.dmb', 'civ13.rsc'):
        require(not (source/name).exists(), 'Refusing pre-existing compiler output.')
    dme = source/'civ13.dme'
    before_dme = digest(dme)
    dme.write_text(select_gaia(dme.read_text(encoding='utf-8')), encoding='utf-8')
    subprocess.run([sys.executable, '-B', 'scripts/build-crafting-atlas.py', '--catalog-only',
                    '--game-catalog', 'UI/crafting-atlas.json'], cwd=source, check=True, timeout=600)
    log_path = output.parent/'gaia-compile.log'
    with log_path.open('xb') as log:
        result = subprocess.run([str(args.byond_bin.resolve(strict=True)/'DreamMaker'),
                                 '-max_errors', '0', 'civ13.dme'], cwd=source,
                                stdout=log, stderr=subprocess.STDOUT, timeout=1200)
    log = log_path.read_text(encoding='utf-8', errors='replace')
    print(log, end='')
    require(result.returncode == 0, 'Compiler exited unsuccessfully.')
    validate_compile(log, source)
    changed = subprocess.check_output(['git', 'diff', '--name-only'], cwd=source, text=True).splitlines()
    require(set(changed) <= {'civ13.dme', 'UI/crafting-atlas.json'}, 'Unexpected source changes.')
    workflow_sha = os.environ.get('GITHUB_SHA', '')
    require(re.fullmatch(r'[0-9a-f]{40}', workflow_sha), 'Missing immutable workflow commit.')
    provenance = {'source_dme_sha256': before_dme, 'compiled_dme_sha256': digest(dme),
                  'catalog_sha256': digest(source/'UI/crafting-atlas.json'),
                  'compiler_sha256': digest(args.byond_bin.resolve(strict=True)/'DreamMaker'),
                  'workflow_sha': workflow_sha, 'run_id': os.environ.get('GITHUB_RUN_ID', ''),
                  'run_attempt': os.environ.get('GITHUB_RUN_ATTEMPT', '')}
    manifest = package(source, output, log_path, provenance)
    print('BUILT_NOT_DEPLOYED: '+str(len(manifest['files']))+' hashed runtime members')


if __name__ == '__main__':
    main()
