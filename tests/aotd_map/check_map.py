"""Offline authored AOTD map checks. No native process or world is started."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
MAP = Path('maps/special/the_art_of_the_deal.dmm')
DEFINITION = re.compile(r'^"([A-Za-z]+)" = \(([^\n]*)\)\s*$', re.M)
BLOCK = re.compile(r'^\((\d+),(\d+),(\d+)\) = \{"\n(.*?)"\}', re.M | re.S)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate(text):
    text = text.replace('\r\n', '\n')
    require(not re.search(r'^(<<<<<<<|=======|>>>>>>>)', text, re.M), 'unresolved conflict marker')
    require(not re.search(r'=\s*alist\s*\(', text), 'unsupported DMM alist initializer')
    require('forced_ambience' not in text, 'obsolete forced_ambience override')
    palette = {}
    for match in DEFINITION.finditer(text):
        key, body = match.groups()
        require(key not in palette, 'duplicate palette key: ' + key)
        palette[key] = body
    require(bool(palette) and {len(key) for key in palette} == {3}, 'expected uniform three-character keys')
    require('/mob/living/simple_animal/npc_vendor/cartel' in palette.get('mHm', ''), 'cartel must use migrated mob type')
    require('/mob/living/simple_animal/npc_vendor/walter' in palette.get('tNG', ''), 'Walter must use migrated mob type')
    require('pixel_y = 64; layer = 3.1' in palette['mHm'], 'cartel placement overrides lost')
    require(all("ambience = list('sound/ambience/nightclub2.ogg')" in palette.get(key, '') for key in ('mHm', 'tOH')), 'nightclub ambience lost')
    require('unique_door_name = "Strobe NIght Club"' in palette['tOH'], 'nightclub door identity lost')
    require(re.search(r'\bspeedlist\s*=\s*list\(', palette.get('ata', '')), 'vehicle override must use a map list literal')
    levels, cells, metadata = set(), 0, 0
    for block in BLOCK.finditer(text):
        x, y, z = map(int, block.group(1, 2, 3))
        require((x, y) == (1, 1) and z not in levels, 'invalid or duplicate map block')
        levels.add(z)
        rows = block[4].strip('\n').splitlines()
        require(len(rows) == 220 and {len(row) for row in rows} == {660}, 'AOTD level must be 220 by 220')
        for row in rows:
            for offset in range(0, len(row), 3):
                key = row[offset:offset + 3]
                require(key in palette, 'undefined grid key: ' + key)
                metadata += '/obj/map_metadata/art_of_the_deal' in palette[key]
                cells += 1
    require(levels == {1, 2} and cells == 96800, 'AOTD two-level geometry incomplete')
    require(metadata == 1, 'expected one AOTD metadata object')
    require(not BLOCK.sub('', DEFINITION.sub('', text)).strip(), 'unparsed DMM content')
    return {'palette_keys': len(palette), 'dimensions': [220, 220, 2], 'cells': cells}


if __name__ == '__main__':
    print(validate((ROOT / MAP).read_text(encoding='utf-8')))
