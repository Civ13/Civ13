"""Native research-unlock regression on a persistent Auto-Research world.

Compiles the production research_faction.dm with the research tree defines,
the real /datum/research_node and the real legacy age helpers copied from
_map_metadata.dm, plus small stubs, into a temporary fixture. DreamDaemon runs
it with -safe on port 0 (no clients) and the probe writes result.txt.
"""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
FACTION = 'code/modules/research_tree/research_faction.dm'
DEFINES = 'code/modules/research_tree/_research_tree_defines.dm'
NODE = 'code/modules/research_tree/research_node.dm'
METADATA = 'code/game/objects/map_metadata/_map_metadata.dm'

# Each control breaks one fix; the probe must then fail.
CONTROLS = {
    'baseline': (FACTION, 'faction_baseline_era[faction] = reached', 'era = reached'),
    'regression': (METADATA, '\tif (ordinal_age >= new_ordinal)\n\t\treturn FALSE\n', ''),
    'specialist': (FACTION, 'N.era_tier <= PERSISTENT_SPECIALIST_BASELINE_ERA)', 'FALSE)'),
}


def read(path, control):
    text = (ROOT / path).read_text(encoding='utf-8')
    if control:
        target, old, new = CONTROLS[control]
        if target == path:
            if text.count(old) != 1:
                raise RuntimeError(f'Control target missing or ambiguous: {control}')
            text = text.replace(old, new, 1)
    return text


def proc_text(source, signature):
    start = source.index(signature)
    body = source.index('\n', start) + 1
    end = re.compile(r'^\S', re.M).search(source, body)
    return source[start:end.start() if end else len(source)]


def node_datum(source):
    start = source.index('\n/datum/research_node\n') + 1
    end = source.index('// Human-readable name', start)
    return source[start:end] + proc_text(source, '/proc/register_research_node(') + proc_text(source, '/proc/get_research_node(')


def build(directory, control):
    metadata = read(METADATA, control)
    (directory / 'defines.dm').write_text(read(DEFINES, control), encoding='utf-8')
    (directory / 'faction.dm').write_text(read(FACTION, control), encoding='utf-8')
    (directory / 'node.dm').write_text('var/global/list/research_nodes = list()\n' + node_datum(read(NODE, control)), encoding='utf-8')
    (directory / 'legacy.dm').write_text(proc_text(metadata, '/obj/map_metadata/proc/set_ordinal_age()') + '\n' + proc_text(metadata, '/obj/map_metadata/proc/legacy_age_advance('), encoding='utf-8')
    shutil.copy(HERE / 'probe.dm', directory / 'probe.dm')
    (directory / 'fixture.dme').write_text(''.join(f'#include "{name}"\n' for name in ('defines.dm', 'probe.dm', 'node.dm', 'faction.dm', 'legacy.dm')), encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--negative-control', choices=CONTROLS)
    args = parser.parse_args()
    exe = '.exe' if os.name == 'nt' else ''
    compiler = args.byond_bin / (('dm' if os.name == 'nt' else 'DreamMaker') + exe)
    daemon = args.byond_bin / (('dd' if os.name == 'nt' else 'DreamDaemon') + exe)
    with tempfile.TemporaryDirectory(prefix='research_persistence_') as temp:
        directory = Path(temp)
        build(directory, args.negative_control)
        compiled = subprocess.run([str(compiler), '-max_errors', '0', 'fixture.dme'], cwd=directory, capture_output=True, text=True, timeout=300)
        if compiled.returncode != 0 or ' 0 errors' not in compiled.stdout:
            print(compiled.stdout + compiled.stderr)
            return 2
        subprocess.run([str(daemon), 'fixture.dmb', '0', '-safe', '-invisible', '-close', '-logself'], cwd=directory, capture_output=True, text=True, timeout=120)
        result = directory / 'result.txt'
        text = result.read_text(encoding='utf-8') if result.exists() else 'FAIL: probe wrote no result\n'
    print(text.strip())
    passed = text.strip().endswith('PASS')
    if args.negative_control:
        print('control reached its failure' if not passed else 'CONTROL DID NOT FAIL')
        return 0 if not passed else 1
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
