"""Stage a read-only full-type Gaia save inspection. Does not launch native tools."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--save-directory', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--diagnose-values', action='store_true')
    parser.add_argument('--validation-source', type=Path)
    parser.add_argument('--ownership-source', type=Path)
    parser.add_argument('--migration-manifest', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    source = args.save_directory.resolve(strict=True)
    output = args.output.resolve()
    if output.drive.upper() != 'D:':
        raise RuntimeError('Inspector output must remain on D:')
    if output.exists():
        raise RuntimeError('Choose a fresh output directory')
    names = ('1.sav', '2.sav', 'map.txt', 'save_complete.txt')
    hashes = {name: hashlib.sha256((source / name).read_bytes()).hexdigest() for name in names}
    if args.migration_manifest:
        manifest = json.loads(args.migration_manifest.read_text(encoding='utf-8'))
        if manifest.get('schema') != 1 or manifest.get('generation_sha256') != hashes:
            raise RuntimeError('Migration manifest is not bound to this exact generation')
    output.mkdir(parents=True)
    (output / 'map_saves').mkdir()
    # Some production globals read name catalogs even with startup disabled.
    # Only versioned checkout defaults, never the running host configuration.
    shutil.copytree(root / 'config', output / 'config')
    for name in names:
        shutil.copyfile(source / name, output / 'map_saves' / name)
    if args.migration_manifest:
        shutil.copyfile(args.migration_manifest, output / 'migration-manifest.json')
    # Keep Gaia's exact area topology for production area-reference validation.
    # Discard all mapped objects and use neutral turfs, avoiding constructors.
    map_source = (root / 'maps/nomads/nomads_gaia.dmm').read_text(encoding='utf-8')
    def neutral_tile(match):
        atoms = match.group(2)
        marker = atoms.rfind('/area/')
        if marker < 0:
            raise RuntimeError('Map tile lacks an area')
        return match.group(1) + '(/turf,' + atoms[marker:] + ')'
    neutral = re.sub(r'^("[^"]+"\s*=\s*)\((.*)\)$', neutral_tile, map_source, flags=re.M)
    (output / 'inspection-map.dmm').write_text(neutral, encoding='utf-8')
    environment = (root / 'civ13.dme').read_text(encoding='utf-8')
    environment = re.sub(r'^#include ".*\.dmm"\s*$', '', environment, flags=re.M)
    adapters = {}
    if args.ownership_source:
        target = output / 'pinned-player-reclaim.dm'
        shutil.copyfile(args.ownership_source, target)
        adapters['code/modules/persistence/player_reclaim.dm'] = target
    if args.diagnose_values or args.validation_source:
        relative = 'code/modules/persistence/loading.dm'
        text = (args.validation_source or (root / relative)).read_text(encoding='utf-8')
        marker = '\t\t\t\t\t\tvalidate_saved_value(F, value, entry_set, validated_lists)\n'
        if text.count(marker) != 1:
            raise RuntimeError('Validation diagnostic marker changed')
        if args.diagnose_values:
            text = text.replace(marker, '\t\t\t\t\t\tif(!islist(value))\n'
                            '\t\t\t\t\t\t\tworld.log << "INVALID_VALUE z=[z] entry=[ref] type=[type] field=[field] null=[isnull(value)] raw=[value]"\n' + marker)
        target = output / 'diagnostic-loading.dm'
        target.write_text(text, encoding='utf-8')
        adapters[relative] = target
    for relative, marker in (
        ('code/world.dm', '/datum/global_init/New()\n'),
        ('code/controllers/mc/globals.dm', '/datum/controller/global_vars/New()\n'),
        ('code/game/objects/map_metadata/_map_metadata.dm', '/obj/map_metadata/New()\n'),
        ('code/game/turfs/turf.dm', '/turf/New()\n'),
    ):
        text = (root / relative).read_text(encoding='utf-8')
        if text.count(marker) != 1:
            raise RuntimeError(f'Isolation marker changed: {relative}')
        text = text.replace(marker, marker + '\treturn\n', 1)
        if relative == 'code/world.dm':
            start = text.index('/world/New()')
            parent = text.index('\n\t..()', start)
            text = text[:parent] + text[parent:].replace('\n\t..()', '', 1)
            text = text.replace('/world/New()', '/world/proc/unused_inspection_startup()', 1)
            text = text.replace('turf = /turf/floor/dirt', 'turf = /turf', 1)
        target = output / Path(relative).name
        target.write_text(text, encoding='utf-8')
        adapters[relative] = target
    def include(match):
        relative = match.group(1).replace('\\', '/')
        if relative.endswith('.dmf'):
            shutil.copyfile(root / relative, output / Path(relative).name)
            return '#include "' + Path(relative).name + '"'
        return '#include "' + adapters.get(relative, root / relative).as_posix() + '"'
    environment = re.sub(r'^#include "([^"]+)"', include, environment, flags=re.M)
    environment = re.sub(r'^#define FILE_DIR .*$', '#define FILE_DIR "' + root.as_posix() + '"', environment, flags=re.M)
    probe = output / 'inspect-generation.dm'
    shutil.copyfile(root / 'tests/world_save/inspect-generation.dm', probe)
    environment += '\n#include "inspect-generation.dm"\n#include "inspection-map.dmm"\n'
    if args.migration_manifest:
        environment = '#define WORLD_SAVE_PLAYER_MIGRATION\n' + environment
    (output / 'inspect-generation.dme').write_text(environment, encoding='utf-8')
    (output / 'inspection-inputs.json').write_text(json.dumps({
        'source_save_directory': str(source), 'generation_sha256': hashes,
        'source_root': str(root), 'scope': ('derived-copy ownership migration, no body loading or client transfer'
                                          if args.migration_manifest else 'read-only validator and raw saved body census; no load or ownership migration'),
    }, indent=2), encoding='utf-8')
    print(output / 'inspect-generation.dme')


if __name__ == '__main__':
    main()
