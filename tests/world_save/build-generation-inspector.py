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
    output.mkdir(parents=True)
    (output / 'map_saves').mkdir()
    for name in names:
        shutil.copyfile(source / name, output / 'map_saves' / name)
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
        return '#include "' + adapters.get(relative, root / relative).as_posix() + '"'
    environment = re.sub(r'^#include "([^"]+)"', include, environment, flags=re.M)
    environment = re.sub(r'^#define FILE_DIR .*$', '#define FILE_DIR "' + root.as_posix() + '"', environment, flags=re.M)
    probe = output / 'inspect-generation.dm'
    shutil.copyfile(root / 'tests/world_save/inspect-generation.dm', probe)
    environment += '\n#include "inspect-generation.dm"\n#include "inspection-map.dmm"\n'
    (output / 'inspect-generation.dme').write_text(environment, encoding='utf-8')
    (output / 'inspection-inputs.json').write_text(json.dumps({
        'source_save_directory': str(source), 'generation_sha256': hashes,
        'source_root': str(root), 'scope': 'read-only validator and raw saved body census; no load or ownership migration',
    }, indent=2), encoding='utf-8')
    print(output / 'inspect-generation.dme')


if __name__ == '__main__':
    main()
