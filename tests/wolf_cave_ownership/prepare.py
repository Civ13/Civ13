"""Prepare source-bound wolf cave controls offline; never launches native tools."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASE = '9db2b2f42a5fbbb0bdd49d50a2672da6111a7709'
SOURCE = 'code/game/objects/structures/animalspawner/wolfcave.dm'
PARENT = 'code/game/objects/structures/animalspawner/animal_spawner.dm'
CAVE = '/obj/structure/animalspawner/wolfcave'
CASES = ('fixed', 'world-scan', 'duplicate-start', 'missing-stop',
         'saved-flag', 'missing-recount', 'baseline')
METHODS = ('New()', 'Destroy()', 'persistence_runtime_var(key)',
           'proc/Tick()', 'proc/Ticker()', 'proc/reproduction()',
           'proc/wolf_out()', 'proc/process_cub(', 'proc/set_cavetype()', 'full/New()')


def read(path, root=ROOT):
    return (root / path).read_text(encoding='utf-8').replace('\r\n', '\n')


def method(source, suffix):
    pattern = r'^' + re.escape(CAVE + '/' + suffix) + r'[^\n]*\n.*?(?=^/obj/|\Z)'
    matches = re.findall(pattern, source, flags=re.M | re.S)
    if len(matches) != 1:
        raise ValueError(f'Expected one cave method: {suffix}')
    return matches[0].rstrip() + '\n'


def once(source, old, new):
    if source.count(old) != 1:
        raise ValueError(f'Expected exactly one anchor: {old!r}')
    return source.replace(old, new, 1)


def production(case='fixed', root=ROOT):
    if case not in CASES:
        raise ValueError('Unknown case')
    source = read(SOURCE, root)
    if case == 'baseline':
        source = subprocess.check_output(
            ['git', '-C', str(root), 'show', f'{BASE}:{SOURCE}'], timeout=10).decode('utf-8').replace('\r\n', '\n')
    suffixes = METHODS if case != 'baseline' else tuple(
        s for s in METHODS if s not in ('Destroy()', 'persistence_runtime_var(key)'))
    result = '\n'.join(method(source, s) for s in suffixes)
    if case == 'world-scan':
        result = once(result, '\t\ttotal_population = males + females + cubs\n\t\tTicker()\n',
                      '\t\tfor(var/obj/structure/animalspawner/wolfcave/B in world)\n'
                      '\t\t\tB.total_population = B.males + B.females + B.cubs\n\t\t\tB.Ticker()\n')
    elif case == 'duplicate-start':
        result = once(result, '\tif(ticking || gcDestroyed || gc_destroyed)\n\t\treturn\n', '')
    elif case == 'missing-stop':
        result = once(result, '\tticking = FALSE\n', '')
    elif case == 'saved-flag':
        result = once(result, method(source, 'persistence_runtime_var(key)'), '')
    elif case == 'missing-recount':
        result = once(result, '\t\ttotal_population = males + females + cubs\n', '')
    # Accelerate the ownership cadence and cub wait only, retaining exact
    # cooldown-holder expressions. Fixture subtype holder values are six ticks.
    result = once(result, '\t\tsleep(50)\n', '\t\tsleep(2)\n')
    result = once(result, '\t\tspawn(4500)', '\t\tspawn(6)')
    result = result.replace('prob(', 'fixture_prob(')
    result = once(result, CAVE + '/proc/Ticker()\n', CAVE + '/proc/Ticker()\n'
                  '\tfixture_calls++\n'
                  '\tfixture_services++\n'
                  '\tfixture_assert(total_population == males + females + cubs, "population recount")\n')
    return result


def prepare(output, root=ROOT):
    output.mkdir(parents=True, exist_ok=False)
    parent = read(PARENT, root).split('/obj/structure/animalspawner/attackby(')[0]
    # Resource-free declaration adapter: real population/cooldown defaults remain.
    parent = '\n'.join(line for line in parent.splitlines() if not line.startswith('\ticon =')) + '\n'
    fixture = read('tests/wolf_cave_ownership/probe.dm', root)
    manifest = {
        'base': BASE, 'head': subprocess.check_output(
            ['git', '-C', str(root), 'rev-parse', 'HEAD'], timeout=10).decode().strip(),
        'compiler_executed': False, 'native_executed': False,
        'source_sha256': {p: hashlib.sha256((root / p).read_bytes()).hexdigest()
                          for p in (SOURCE, PARENT, 'tests/wolf_cave_ownership/probe.dm')},
        'bounds': {'map': [12, 12, 1], 'max_caves_per_batch': 10,
                   'cases': len(CASES), 'native_parallelism': 1,
                   'fixture_watchdog_deciseconds': 150,
                   'proposed_external_wall_seconds_per_case': 20,
                   'proposed_external_memory_mib_per_case': 256,
                   'native_launch_authorized': False},
        'cases': {},
    }
    for case in CASES:
        files = {'parent.dm': parent, 'production.dm': production(case, root),
                 'probe.dm': fixture,
                 'probe.dme': '#define TRUE 1\n#define FALSE 0\n#define CONSCIOUS 0\n'
                              '#define FILE_DIR "."\n#include "parent.dm"\n'
                              '#include "probe.dm"\n#include "production.dm"\n'}
        hashes = {}
        for name, content in files.items():
            path = output / case / name
            path.parent.mkdir(parents=True, exist_ok=True)
            raw = content.encode('utf-8')
            path.write_bytes(raw)
            hashes[name] = hashlib.sha256(raw).hexdigest()
        manifest['cases'][case] = hashes
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(prepare(args.output), indent=2))
