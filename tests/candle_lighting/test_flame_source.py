"""Source checks for the shared open-flame check used to light candles.

No compiler, game or network. The native behaviour is in probe.dm.
"""
from pathlib import Path
import importlib.util
import re
import struct
from types import SimpleNamespace
import unittest
import zlib

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

    def test_processor_registration_follows_ignition_and_snuffing(self):
        text = source(CANDLE)
        light = block(text, '/obj/item/weapon/flame/candle/proc/light(')
        snuff = block(text, '/obj/item/weapon/flame/candle/attack_self(')
        self.assertIn('processing_objects |= src', light)
        self.assertNotIn('processing_objects += src', light)
        self.assertLess(light.index('lit = TRUE'), light.index('processing_objects |= src'))
        self.assertLess(snuff.index('lit = FALSE'), snuff.index('processing_objects -= src'))

    def test_restore_reconciles_previously_lit_and_prelit_candle_types(self):
        text = source(CANDLE)
        spec = importlib.util.spec_from_file_location('candle_adapter', ROOT / 'tests/save_movement/source_adapter.py')
        adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(adapter)
        decl = '/obj/item/weapon/flame/candle/after_load'
        body = adapter.extract(text, decl).replace('..()', 'parent()')
        body = body.replace('if (lit)', 'if (src.lit)')
        body = body.replace('processing_objects |= src', 'register(src)')
        body = body.replace('processing_objects -= src', 'unregister(src)')
        registrations, parent_calls = [], []
        def register(candle):
            if candle not in registrations:
                registrations.append(candle)

        restore = adapter.project(decl + '()\n' + body + '\n', decl, 'src', {
            'parent': lambda: parent_calls.append(True),
            'register': register, 'unregister': lambda candle: registrations.remove(candle)
            if candle in registrations else None,
        })
        for kind in ('ordinary', 'lard'):
            for prelit in (False, True):
                for saved_lit in (False, True):
                    with self.subTest(kind=kind, prelit=prelit, saved_lit=saved_lit):
                        candle = SimpleNamespace(lit=saved_lit, wax=413.5)
                        registrations[:] = [candle] if prelit else []
                        parent_calls.clear()
                        restore(candle)
                        restore(candle)
                        self.assertEqual(registrations, [candle] if saved_lit else [])
                        self.assertEqual(candle.wax, 413.5)
                        self.assertEqual(parent_calls, [True, True])
        self.assertNotIn('light(', body)

    def test_candle_appearance_stages_and_variant_states(self):
        text = source(CANDLE)
        spec = importlib.util.spec_from_file_location('candle_adapter', ROOT / 'tests/save_movement/source_adapter.py')
        adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(adapter)
        adapter.FIELDS += ('wax',)
        stage = adapter.project(text, '/obj/item/weapon/flame/candle/proc/candle_wax_stage',
                                'src', {}, method=True)
        for wax, expected in ((1050, 1), (801, 1), (800, 2), (500.5, 2),
                              (501, 2), (500, 3), (0, 3)):
            with self.subTest(wax=wax):
                self.assertEqual(stage(SimpleNamespace(wax=wax)), expected)

        ordinary = block(text, '/obj/item/weapon/flame/candle/update_icon(')
        lard = block(text, '/obj/item/weapon/flame/candle/lard/update_icon(')
        for body, suffix in ((ordinary, ''), (lard, '_lard')):
            self.assertIn('var/i = candle_wax_stage()', body)
            self.assertIn(f'icon_state = "candle[i][lit ? "_lit" : ""]{suffix}"', body)

        data = (ROOT / 'icons/obj/candle.dmi').read_bytes()
        offset, metadata = 8, ''
        while offset < len(data):
            size = struct.unpack('>I', data[offset:offset + 4])[0]
            kind, chunk = data[offset + 4:offset + 8], data[offset + 8:offset + 8 + size]
            offset += 12 + size
            if kind == b'zTXt':
                metadata += zlib.decompress(chunk.split(b'\0', 1)[1][1:]).decode('latin1')
            elif kind == b'tEXt':
                metadata += chunk.decode('latin1')
        states = set(re.findall(r'^state = "(.*)"', metadata, re.MULTILINE))
        for index in (1, 2, 3):
            for lit in ('', '_lit'):
                for suffix in ('', '_lard'):
                    self.assertIn(f'candle{index}{lit}{suffix}', states)


if __name__ == '__main__':
    unittest.main()
