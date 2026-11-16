"""Amalgamation and river bed mercury: source contract and balance checks.

    python3 tests/amalgam/test_contract.py
"""
import re
import struct
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/amalgam.dm').read_text(encoding='utf-8')
FLOOD = (ROOT / 'code/modules/1713/river_flood.dm').read_text(encoding='utf-8')
MERCURY = (ROOT / 'code/modules/1713/mercury.dm').read_text(encoding='utf-8')
PLACER = (ROOT / 'code/modules/1713/placer.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
DMI = ROOT / 'icons/obj/amalgam.dmi'


def define(name):
    match = re.search(rf'#define {name} ([0-9.]+)', SOURCE)
    assert match, name
    return float(match.group(1))


def dmi_description(path):
    data = path.read_bytes()
    pos = 8
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind in (b'zTXt', b'tEXt') and body.startswith(b'Description\0'):
            text = body[len(b'Description\0'):]
            return zlib.decompress(text[1:]).decode() if kind == b'zTXt' else text.decode()
        pos += 12 + length
    return ''


class Balance(unittest.TestCase):
    def test_recoveries_from_the_plan(self):
        self.assertEqual(define('ARRASTRA_RECOVERY'), 0.55)
        self.assertEqual(define('PATIO_RECOVERY'), 0.7)
        self.assertEqual(define('ARRASTRA_LOSS'), 0.15)

    def test_patio_loses_about_thirty_percent(self):
        made = int(define('PATIO_LOADS') * 0.5 * define('PATIO_RECOVERY'))
        lost = define('PATIO_MERCURY') - made * define('AMALGAM_WET_MERCURY')
        self.assertAlmostEqual(lost / define('PATIO_MERCURY'), 0.3, delta=0.05)

    def test_press_returns_sixty_percent(self):
        share = (define('AMALGAM_WET_MERCURY') - define('AMALGAM_HARD_MERCURY')) / define('AMALGAM_WET_MERCURY')
        self.assertAlmostEqual(share, 0.6)

    def test_bed_decays_one_percent_an_hour(self):
        self.assertAlmostEqual(define('RIVER_MERCURY_MINUTE_KEEP') ** 60, 0.99, places=4)


class Wiring(unittest.TestCase):
    def test_included_and_gated(self):
        self.assertIn('#include "code\\modules\\1713\\amalgam.dm"', DME)
        self.assertLess(DME.index('lode.dm'), DME.index('amalgam.dm'))
        for path in ('/obj/structure/workshop_machine/amalgam_press', '/obj/structure/patio_heap'):
            self.assertIn(f'"{path}" = "amalgamation"', NODES)
            self.assertIn(f',{path},', RECIPES)

    def test_bed_mercury_saved_and_stepped(self):
        self.assertIn('F.step_bed_mercury() // amalgam.dm', FLOOD)
        self.assertIn('. += round(bed_mercury[i], 0.001)', FLOOD)
        self.assertIn('var/has_mercury = hollows_end && state.len == hollows_end + count * 2', FLOOD)

    def test_retort_hooks(self):
        for proc in ('retort_contents', 'retort_charge', 'retort_empty'):
            self.assertIn(f'/obj/structure/workshop_machine/mercury_retort/proc/{proc}(', MERCURY)
            self.assertIn(f'/obj/structure/workshop_machine/mercury_retort/{proc}(', SOURCE)

    def test_sluice_loss_reaches_the_river(self):
        self.assertIn('river_mercury_spill(get_turf(src), SLUICE_MERCURY_LOSS)', PLACER)

    def test_hooks_outside(self):
        hooks = {
            'code/game/turfs/floor_attackby.dm': 'river_mercury_drink(H, src)',
            'code/game/objects/structures/watercloset.dm': 'river_mercury_fill(RG, get_turf(src), 3)',
            'code/modules/1713/fishing_grounds.dm': 'river_mercury_taint_catch(fish, water)',
            'code/modules/1713/resource_sifting.dm': 'river_mercury_pan_message(src, water)',
        }
        for path, text in hooks.items():
            self.assertIn(text, (ROOT / path).read_text(encoding='utf-8'), path)

    def test_runtime_only_state(self):
        self.assertNotIn('world.time', SOURCE)
        self.assertIn('. -= "arrastra_busy"', SOURCE)
        self.assertIn('return key == "turning" || ..()', SOURCE)

    def test_sprites(self):
        text = dmi_description(DMI)
        states = set(re.findall(r'(?:icon_state) = "([a-z_]+)"', SOURCE)) | {'arrastra_overlay', 'patio_heap_2', 'patio_heap_3'}
        for state in states:
            self.assertIn(f'state = "{state}"', text, state)


if __name__ == '__main__':
    unittest.main()
