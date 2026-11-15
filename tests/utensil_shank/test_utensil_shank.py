"""Every wall and jail cover shares one utensil-to-shank proc.

original_wall_block.dm.txt freezes the sharpening block that was copied into
seven wall covers before the shared /obj/covers/proc/sharpen_utensil existed.
These are source checks; no BYOND runtime.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
COVERS = ROOT / 'code/game/objects'
WALLS = ('brick_wall', 'tiled_wall', 'cement_wall', 'stone_wall', 'marble_wall/plain',
         'sandstone_wall', 'sandstone_smooth_wall')


def helper_body(source):
    match = re.search(r'(?m)^/obj/covers/proc/sharpen_utensil\(.*\n((?:\t.*\n)*)', source)
    return match.group(1) if match else ''


def errors(sources):
    found = []
    helper = helper_body(sources['covers.dm'])
    original = (HERE / 'original_wall_block.dm.txt').read_text(encoding='utf-8')
    # Each decision line of the frozen copy survives in the helper.
    for needle in ('I.shiv < 10', 'I.shiv++', 'I.shiv >= 10', 'drop_from_inventory(I)',
                   'put_in_hands(', 'turns into a shank.', 'qdel(I)'):
        if needle not in original:
            found.append(f'fixture lost {needle}')
        if needle not in helper and needle != 'I.shiv < 10':
            found.append(f'helper lost {needle}')
    if 'if (I.shiv >= 10)\n\t\treturn' not in helper:
        found.append('helper must stop at ten scrapes')
    for name, source in sources.items():
        if name != 'covers.dm' and 'shiv++' in source:
            found.append(f'{name} copies the sharpening block again')
    joined = '\n'.join(sources.values())
    for wall in WALLS:
        bodies = re.findall(r'(?m)^/obj/covers/' + re.escape(wall) + r'/attackby\(.*\n((?:\t.*\n)*)', joined)
        if not any('\t\tsharpen_utensil(I, U)\n' in body for body in bodies):
            found.append(f'{wall} must call sharpen_utensil')
    jail = re.search(r'(?m)^/obj/covers/jail/attackby\(.*\n((?:\t.*\n|\n)*)', joined)
    if not jail or 'sharpen_utensil(W, user, /obj/item/weapon/material/kitchen/utensil/knife/shank/wood)' not in jail.group(1):
        found.append('jail chopsticks must keep the wooden shank')
    return found


class UtensilShank(unittest.TestCase):
    def setUp(self):
        paths = [COVERS / 'covers.dm', *sorted((COVERS / 'covers_types').glob('*.dm'))]
        self.sources = {path.name: path.read_text(encoding='utf-8') for path in paths}

    def test_walls_and_jail_share_the_helper(self):
        self.assertEqual(errors(self.sources), [])

    def test_detects_reintroduced_copy(self):
        changed = dict(self.sources)
        changed['cover_jail.dm'] += '\n/obj/covers/x/attackby(I, U)\n\tI.shiv++\n'
        self.assertTrue(errors(changed))

    def test_detects_wall_without_helper(self):
        changed = dict(self.sources)
        changed['covers_buildable.dm'] = changed['covers_buildable.dm'].replace('\t\tsharpen_utensil(I, U)\n', '\t\treturn\n', 1)
        self.assertTrue(errors(changed))


if __name__ == '__main__':
    unittest.main()
