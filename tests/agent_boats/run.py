"""Pinned BYOND fixture for agent boats (code/modules/agent_control/agent_boats.dm).

Compiles the production sources with ordinary startup and maps removed, runs
tests/agent_boats/probe.dm in an isolated temporary directory and requires
every assertion to pass with no runtime errors.
"""
import argparse
import json
import os
import re
import shutil
import sys
import tempfile
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import fixture_toolchain as current  # noqa: E402


def build_source(root, prefix):
    """Production DME without maps or the normal world/global start-up."""
    source = (root / 'civ13.dme').read_text(encoding='utf-8')
    world = (root / 'code/world.dm').read_text(encoding='utf-8')
    start = world.index('/world/New()')
    parent = world.index('\n\t..()', start)
    world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
    world = world.replace('/world/New()', '/world/proc/unused_agent_boats_startup()', 1)
    world = world.replace('/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n', 1)
    globals_text = (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
    marker = '/datum/controller/global_vars/New()\n'
    if globals_text.count(marker) != 1:
        raise RuntimeError('Global startup isolation marker changed')
    files = {
        prefix + '_world.dm': world,
        prefix + '_globals.dm': globals_text.replace(marker, marker + '\treturn\n'),
    }
    source = source.replace('code\\world.dm', prefix + '_world.dm')
    source = source.replace('code\\controllers\\mc\\globals.dm', prefix + '_globals.dm')
    source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
    source += '\n#include "tests/agent_boats/probe.dm"\n'
    files[prefix + '.dme'] = source
    return files


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    args = parser.parse_args()
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    prefix = '.agent_boats_' + uuid.uuid4().hex
    files = build_source(ROOT, prefix)
    generated = [ROOT / name for name in files] + [ROOT / (prefix + '.dmb'), ROOT / (prefix + '.rsc')]
    try:
        for name, text in files.items():
            (ROOT / name).write_text(text, encoding='utf-8')
        built = current.run_compiler([str(compiler), '-max_errors', '0', prefix + '.dme'], cwd=ROOT,
                                     capture_output=True, text=True, timeout=180)
        print(built.stdout[-400:])
        with tempfile.TemporaryDirectory(prefix='civ13-agent-boats-') as temp:
            target = Path(temp)
            shutil.copy2(ROOT / (prefix + '.dmb'), target / 'probe.dmb')
            shutil.copy2(ROOT / (prefix + '.rsc'), target / 'probe.rsc')
            shutil.copytree(ROOT / 'config/names', target / 'config/names')
            (target / 'data').mkdir()
            platform = ['-invisible', '-close'] if os.name == 'nt' else []
            ran = current.run_daemon([str(daemon), 'probe.dmb', '-ip', '127.0.0.1', '-nowebclient', *platform,
                                      '-trusted', '-log', 'runtime.log'], cwd=target,
                                     capture_output=True, text=True, timeout=120)
            log = (target / 'runtime.log').read_text(errors='replace') if (target / 'runtime.log').exists() else ''
            print(log[-12000:])
            result_path = target / 'result.json'
            result = json.loads(result_path.read_text()) if result_path.exists() else None
            if (ran.returncode or not result or result.get('failures') != 0 or result.get('checks', 0) < 1
                    or result.get('runtime_error') or current.DIAGNOSTIC.search(log)):
                raise RuntimeError(f'Agent boats fixture failed: {result}')
            print(f"PASS: {result['checks']} agent boat checks")
    finally:
        for path in generated:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
