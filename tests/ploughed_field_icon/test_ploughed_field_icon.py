"""Ploughed fields keep their furrowed sprite through floor icon updates and
world loads. Projects the production turf/flooring definitions and the floor
icon_state selection order; stdlib only, no BYOND runtime."""
import re
import struct
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FLOORING = ROOT / 'code/game/turfs/flooring'
FLOOR_ICON = (ROOT / 'code/game/turfs/floor_icon.dm').read_text(encoding='utf-8')
PREMADE = (FLOORING / 'flooring_premade.dm').read_text(encoding='utf-8')
PLOUGHED = {
    '/turf/floor/dirt/ploughed': 'dirt_ploughed',
    '/turf/floor/dirt/ploughed/fertile': 'dirt_ploughed',
    '/turf/floor/dirt/ploughed/medium_fertile': 'dirt_ploughed',
    '/turf/floor/dirt/ploughed/infertile': 'dirt_ploughed',
    '/turf/floor/dirt/ploughed/flooded': 'flood_dirt_ploughed',
}


def type_vars(paths):
    """Type path -> {var: raw value} for top-level type blocks."""
    types = {}
    for path in paths:
        current = None
        for line in path.read_text(encoding='utf-8').splitlines():
            match = re.match(r'^(/[\w/]+)\s*$', line)
            if match:
                current = types.setdefault(match.group(1), {})
                continue
            if line and not line[0].isspace():
                current = None
                continue
            match = current is not None and re.match(r'^\t(\w+)\s*=\s*(.+?)\s*(//.*)?$', line)
            if match:
                current.setdefault(match.group(1), match.group(2).strip('"'))
    return types


TYPES = type_vars(sorted(FLOORING.glob('*.dm')) + [ROOT / 'code/game/turfs/floor.dm'])


def inherited(path, name):
    while path:
        if name in TYPES.get(path, {}):
            value = TYPES[path][name]
            return None if value == 'null' else value
        path = path.rsplit('/', 1)[0]
    return None


def selected_icon_state(path):
    """The icon_state /turf/floor/update_icon() picks for a fresh turf (no
    set_update_icon, no flooring_override yet)."""
    if inherited(path, 'set_update_icon'):
        return inherited(path, 'set_update_icon')
    override = inherited(path, 'overrided_icon_state')
    if override:
        return override
    flooring = inherited(path, 'initial_flooring')
    if not flooring:
        return inherited(path, 'icon_state')
    base = inherited(flooring, 'icon_base')
    return base + '0' if inherited(flooring, 'has_base_range') not in (None, '0') else base


def dmi_states(path):
    data = path.read_bytes()
    offset = 8
    while offset < len(data):
        length, kind = struct.unpack('>I4s', data[offset:offset + 8])
        chunk = data[offset + 8:offset + 8 + length]
        if kind == b'zTXt' and chunk.startswith(b'Description\0'):
            text = zlib.decompress(chunk[len(b'Description\0') + 1:]).decode('utf-8')
            return set(re.findall(r'^state = "([^"]*)"', text, re.M))
        offset += 12 + length
    return set()


class PloughedFieldIcon(unittest.TestCase):
    def test_floor_icon_prefers_type_override_over_shared_flooring_base(self):
        for proc in ('/turf/floor/New()', '/turf/floor/update_icon(var/update_neighbors)'):
            text = FLOOR_ICON.split(proc, 1)[1]
            order = [text.index(token) for token in (
                'set_update_icon', 'flooring_override', 'overrided_icon_state', 'flooring.icon_base')]
            self.assertEqual(order, sorted(order), proc)

    def test_every_ploughed_turf_resolves_to_its_furrowed_sprite(self):
        states = dmi_states(ROOT / 'icons/turf/floors.dmi')
        for path, expected in PLOUGHED.items():
            with self.subTest(path=path):
                self.assertEqual(inherited(path, 'icon_state'), expected)
                self.assertEqual(selected_icon_state(path), expected)
                self.assertIn(expected, states)

    def test_shared_dirt_flooring_base_would_hide_the_furrows(self):
        # Negative control: the decl's base state is plain dirt, so the type
        # override is what keeps the sprite.
        flooring = inherited('/turf/floor/dirt/ploughed', 'initial_flooring')
        self.assertEqual(inherited(flooring, 'icon_base'), 'dirt')

    def test_load_restores_furrows_over_a_saved_plain_dirt_state(self):
        hook = PREMADE.split('/turf/floor/dirt/ploughed/after_load()', 1)[1]
        hook = hook.split('\n/', 1)[0]
        self.assertIn('..()', hook)
        self.assertRegex(hook, r'icon_state = overrided_icon_state')


if __name__ == '__main__':
    unittest.main()
