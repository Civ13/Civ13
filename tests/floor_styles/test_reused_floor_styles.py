"""Offline contracts for established floor-cover art opened up to player recipes."""
from collections import Counter
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
COVERS = (ROOT / 'code/game/objects/covers_types/cover_floortypes.dm').read_text()
RESEARCH = (ROOT / 'code/modules/research_tree/research_node.dm').read_text()
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text()

WOOD = {
    '/obj/covers/wood/alt' + suffix: 'woodalt' + (str(i) if i > 1 else '')
    for i, suffix in enumerate(('', '/two', '/three', '/four', '/five',
                               '/six', '/seven', '/eight', '/nine', '/ten', '/eleven'), 1)
}
STONE = {
    '/obj/covers/cobblestone/vertical': 'cobble_vertical',
    '/obj/covers/cobblestone/horizontal': 'cobble_horizontal',
    '/obj/covers/cobblestone/horizontal/dark': 'cobble_horizontal_dark',
    '/obj/covers/stone/slab/decorative/mossy': 'stone_old',
}
TRIM = {
    '/obj/covers/tatami/trim': 'tatami_frame',
    '/obj/covers/tatami/trim/angle': 'tatami_frame_angle',
    '/obj/covers/tatami/trim/corner': 'tatami_frame_corner',
    '/obj/covers/tatami/trim/cee': 'tatami_frame_cee',
    '/obj/covers/tatami/trim/full': 'tatami_frame_full',
}


def state_directories(path):
    # The repository DMI reader handles both compressed and uncompressed
    # PNG Description metadata. A state block supplies its registered dirs.
    # Pillow is not needed for this offline fixture.
    from struct import unpack
    from zlib import decompress
    with path.open('rb') as source:
        if source.read(8) != b'\x89PNG\r\n\x1a\n':
            raise ValueError(f'{path} is not PNG')
        while size := source.read(4):
            length = unpack('>I', size)[0]
            name = source.read(4)
            body = source.read(length)
            source.read(4)  # CRC
            if name not in (b'tEXt', b'zTXt') or not body.startswith(b'Description\x00'):
                continue
            data = body.split(b'\x00', 1)[1]
            if name == b'zTXt':
                data = decompress(data[1:])
            return dict(re.findall(r'^state = "(.*?)"\s+dirs = (\d+)', data.decode(), re.M))
    raise ValueError(f'No DMI Description in {path}')


def source_body(head):
    regex = r'^' + re.escape(head) + r'\n((?:^[ \t].*\n)+)'
    match = re.search(regex, COVERS, re.M)
    if not match:
        raise AssertionError(f'Missing floor declaration: {head}')
    return match[1]


class ReusedFloorStyles(unittest.TestCase):
    def test_exact_recipes_have_material_and_research_parity(self):
        catalog = [row.removeprefix('RECIPE: ').split(',')
                   for row in RECIPES.splitlines() if row.startswith('RECIPE: ')]
        counts = Counter(row[2] for row in catalog)
        by_output = {row[2]: row for row in catalog}
        for table, material, cost, time, gate in (
            (WOOD, 'wood/soft', '1', '25', 'primitive_construction'),
            (STONE, 'stone', '1', '25', 'stone_masonry'),
            (TRIM, 'bamboo', '1', '20', 'primitive_construction'),
        ):
            for typ in table:
                with self.subTest(typ=typ):
                    self.assertEqual(counts[typ], 1)
                    row = by_output[typ]
                    self.assertEqual(row[0], f'/material/{material}/')
                    self.assertEqual(row[3:7], [cost, time, '1', '1'])
                    self.assertIn(f'"{typ}" = "{gate}",', RESEARCH)
        self.assertEqual(counts['/obj/covers/cobblestone'], 1)
        self.assertFalse(any(path.startswith('/obj/effect/floor_decal') for path in counts))

    def test_floor_paths_reference_existing_states_with_expected_directions(self):
        for table, filename in ((WOOD, 'flooring/wood.dmi'),
                                (STONE, 'floors.dmi'), (TRIM, 'flooring/decals.dmi')):
            states = state_directories(ROOT / 'icons/turf' / filename)
            for typ, state in table.items():
                with self.subTest(typ=typ):
                    self.assertIn(f'icon_state = "{state}"', source_body(typ))
                    self.assertEqual(states[state], '4' if typ in TRIM and not typ.endswith('/full') else '1')

    def test_trim_is_one_floor_cover_with_rebuilt_mat_and_bounded_rotation(self):
        new = source_body('/obj/covers/tatami/trim/New()')
        self.assertIn('..()', new)
        self.assertIn('underlays += image(icon = \'icons/turf/floors.dmi\', icon_state = "tatami0")', new)
        self.assertIn('verbs -= /obj/covers/tatami/trim/verb/rotate_trim', new)
        self.assertIn('directional_trim = FALSE', source_body('/obj/covers/tatami/trim/full'))
        rotate = source_body('/obj/covers/tatami/trim/verb/rotate_trim()')
        for guard in ('!directional_trim', '!isliving(usr)', 'usr.incapacitated()',
                      '!usr.Adjacent(src)', 'persistence_save_in_progress',
                      'persistence_active_operation', 'persistence_load_recovery_required'):
            self.assertLess(rotate.index(guard), rotate.index('set_dir('))
        self.assertIn('set src in oview(1)', rotate)
        self.assertIn('set_dir(turn(cardinal_dir, 90))', rotate)
        for typ in TRIM:
            self.assertNotRegex(source_body(typ), r'\b(?:layer|density|wall)\s*=')
        self.assertIn('layer = 1.99', source_body('/obj/covers/tatami'))
        self.assertFalse(any(f'{typ}/Destroy()' in COVERS for typ in TRIM))


if __name__ == '__main__':
    unittest.main()
