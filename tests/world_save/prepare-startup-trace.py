"""Generate startup phase markers in copies; never compile, launch or edit inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import re


INPUTS = ('civ13.dme', 'code/world.dm',
          'code/game/objects/map_metadata/_map_metadata.dm',
          'code/game/objects/map_metadata/nomads/nomads.dm')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def once(source, anchor, replacement):
    if source.count(anchor) != 1:
        raise ValueError(f'Expected unique startup anchor: {anchor!r}')
    return source.replace(anchor, replacement, 1)


def mark(label):
    return f'\ttext2file("{label}", "startup-construction-trace.log")\n'


def generate(root, output, expected, entrypoint='civ13.dme', dme_output=None):
    root = root.resolve(strict=True)
    output = output.resolve()
    if output.exists():
        raise ValueError('Output directory must be new; preserve earlier evidence')
    dme_output = (dme_output or root / '.startup-construction-trace.dme').resolve()
    if dme_output.parent != root or dme_output.exists():
        raise ValueError('Generated DME must be a new file directly inside the staged source root')
    entry = (root / entrypoint).resolve(strict=True)
    if not entry.is_relative_to(root) or entry.suffix != '.dme':
        raise ValueError('Entrypoint must be a DME inside the source root')
    inputs = (entry.relative_to(root).as_posix(), *INPUTS[1:])
    sources = {name: (root / name).read_bytes() for name in inputs}
    actual = {name: sha(data) for name, data in sources.items()}
    if actual != expected:
        raise ValueError('Startup source input hashes do not match the supplied manifest')
    world = sources['code/world.dm'].decode('utf-8-sig').replace('\r\n', '\n')
    world = once(world, '/datum/global_init/New()\n', '/datum/global_init/New()\n' + mark('global_init:enter'))
    for call in ('generate_gameid()', 'makeDatumRefLists()', 'load_configuration()',
                 'initialize_chemical_reagents()', 'initialize_chemical_reactions()'):
        anchor = '\t' + call + '\n'
        world = once(world, anchor, mark('before:' + call) + anchor + mark('after:' + call))
    world = once(world, '/world/New()\n', '/world/New()\n' + mark('world.New:enter'))
    world = once(world, '\tconfig.post_load()\n', mark('before:config.post_load') + '\tconfig.post_load()\n' + mark('after:config.post_load'))
    overrides = {'code/world.dm': world}
    for name, header, label in (
        (INPUTS[2], '/obj/map_metadata/New()\n', 'map_metadata.New'),
        (INPUTS[3], '/obj/map_metadata/nomads/New()\n', 'nomads.New')):
        source = sources[name].decode('utf-8-sig').replace('\r\n', '\n')
        overrides[name] = once(source, header + '\t..()\n',
                               header + mark(label + ':before_parent') + '\t..()\n' + mark(label + ':after_parent'))
    environment = sources[inputs[0]].decode('utf-8-sig').replace('\r\n', '\n')
    if environment.count('#define FILE_DIR .\n') != 1:
        raise ValueError('Expected original relative FILE_DIR in staged entrypoint')
    generated = {}
    output.mkdir(parents=True)
    for name, source in overrides.items():
        target = output / ('trace-' + Path(name).name)
        target.write_text(source, encoding='utf-8')
        generated[name] = target

    def include(match):
        name = match.group(1).replace('\\', '/')
        if name not in generated:
            (root / name).resolve(strict=True)
            return match.group(0)
        return f'#include "{generated[name].as_posix()}"'

    environment = re.sub(r'^#include "([^"]+)"', include, environment, flags=re.MULTILINE)
    dme_output.write_text(environment, encoding='utf-8')
    receipt = {'scope': __doc__, 'source_root': str(root), 'entrypoint': inputs[0], 'inputs_sha256': actual,
               'generated_sha256': {p.name: sha(p.read_bytes()) for p in output.iterdir()},
               'generated_dme': str(dme_output), 'generated_dme_sha256': sha(dme_output.read_bytes()),
               'runtime_log': 'startup-construction-trace.log',
               'native_execution': False}
    (output / 'source-receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    if any(sha((root / name).read_bytes()) != digest for name, digest in actual.items()):
        raise RuntimeError('Source changed during generation; reject this packet')
    return receipt


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root', required=True, type=Path)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--entrypoint', default='civ13.dme')
    parser.add_argument('--dme-output', type=Path)
    parser.add_argument('--expected-manifest', required=True, type=Path,
                        help='JSON mapping the four INPUTS paths to SHA-256 hashes')
    args = parser.parse_args()
    generate(args.source_root, args.output_dir,
             json.loads(args.expected_manifest.read_text(encoding='utf-8-sig')), args.entrypoint, args.dme_output)
    print('Generated source only; see source-receipt.json for DME path and hashes')
