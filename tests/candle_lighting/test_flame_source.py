"""Source checks for the shared open-flame check used to light candles.

No compiler, game or network. The native behaviour is in probe.dm.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
LIGHTERS = 'code/game/objects/items/weapons/cigs_lighters.dm'
CANDLE = 'code/game/objects/items/weapons/candle.dm'
LANTERN = 'code/modules/1713/lantern.dm'
OVEN = 'code/game/objects/structures/kitchen/oven.dm'
GLOWSTICK = 'code/modules/1713/cmss13_gear.dm'


def source(path):
    return (ROOT / path).read_text(encoding='utf-8')


def block(text, header):
    # A header ending in '(' names a proc; otherwise it is an exact type line.
    tail = r'[^\n]*\n' if header.endswith('(') else r'\n'
    match = re.search(r'^' + re.escape(header) + tail + r'((?:\t[^\n]*\n|\n)*)', text, re.M)
    if not match:
        raise AssertionError('missing ' + header)
    return match[1]


class FlameSourceTests(unittest.TestCase):
    def test_shared_check_dispatches_to_atoms(self):
        text = source(LIGHTERS)
        self.assertIn('return AT.is_open_flame()', block(text, '/proc/isflamesource('))
        for header in ('/obj/item/weapon/flame/is_open_flame(', '/obj/item/flashlight/is_open_flame(',
                       '/obj/structure/oven/is_open_flame(', '/obj/structure/furnace/is_open_flame(',
                       '/obj/structure/brazier/is_open_flame(', '/obj/effect/fire/is_open_flame(',
                       '/obj/structure/torch_stand/is_open_flame('):
            self.assertIn(header, text)
        self.assertIn('open_flame && on', block(text, '/obj/item/flashlight/is_open_flame('))

    def test_burning_lights_are_flames_and_electric_ones_are_not(self):
        lantern = source(LANTERN)
        for path in ('/obj/item/flashlight/lantern', '/obj/item/flashlight/torch', '/obj/item/flashlight/tiki_torch'):
            self.assertIn('open_flame = TRUE', block(lantern, path))
        self.assertIn('open_flame = FALSE', block(source(GLOWSTICK), '/obj/item/flashlight/flare/glowstick'))
        oven = source(OVEN)
        for path in ('/obj/structure/oven/stove', '/obj/structure/oven/griddle', '/obj/structure/oven/fryer'):
            self.assertIn('open_flame = FALSE', block(oven, path))

    def test_candle_lights_from_any_flame_both_ways(self):
        text = source(CANDLE)
        held = block(text, '/obj/item/weapon/flame/candle/attackby(')
        self.assertIn('isflamesource(W)', held)
        self.assertNotIn('istype(W, /obj/item/flashlight)', held)
        placed = block(text, '/obj/item/weapon/flame/candle/resolve_attackby(')
        self.assertIn('isflamesource(A)', placed)
        self.assertIn('A != src', placed)
        self.assertLess(placed.index('light_from'), placed.index('return ..()'))


if __name__ == '__main__':
    unittest.main()
