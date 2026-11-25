"""Amalgamation and river bed mercury: source contract and balance checks.

    python3 tests/amalgam/test_contract.py
"""
import re
import struct
import sys
import unittest
import zlib
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/amalgam.dm').read_text(encoding='utf-8')
FLOOD = (ROOT / 'code/modules/1713/river_flood.dm').read_text(encoding='utf-8')
MERCURY = (ROOT / 'code/modules/1713/mercury.dm').read_text(encoding='utf-8')
PLACER = (ROOT / 'code/modules/1713/placer.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
DMI = ROOT / 'icons/obj/amalgam.dmi'

sys.path.insert(0, str(ROOT / 'tests/save_movement'))
import source_adapter


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

class PatioTurnOwnership(unittest.TestCase):
    def project_turn(self, wait):
        path = '/obj/structure/patio_heap/proc/turn_heap'
        fields = source_adapter.FIELDS
        env = dict(
            to_chat=lambda actor, message: None, SPAN_WARNING=str, SPAN_NOTICE=str,
            signal_fire_open_sky=lambda heap: True, crafting_node_allowed_or_warn=lambda *args: True,
            QDELETED=lambda heap: False, PATIO_TURNS=define('PATIO_TURNS'), do_after=wait,
        )
        try:
            source_adapter.FIELDS = fields + (
                'turning', 'charged', 'turn_time', 'turns', 'update_icon', 'finish',
            )
            return source_adapter.project(SOURCE, path, 'src, H', env, method=True)
        finally:
            source_adapter.FIELDS = fields

    def test_hand_and_shovel_use_the_same_turn_entry(self):
        hand = SOURCE.split('/obj/structure/patio_heap/attack_hand(', 1)[1].split('\n/', 1)[0]
        tool = SOURCE.split('/obj/structure/patio_heap/attackby(', 1)[1].split('\n/', 1)[0]
        self.assertIn('turn_heap(H)', hand)
        self.assertIn('turn_heap(H)', tool)

    def test_busy_wait_refuses_second_worker_and_allows_retry_after_cancel(self):
        waits = []
        heap = SimpleNamespace(turning=False, turns=0, charged=lambda: True,
                               turn_time=lambda: 1, update_icon=lambda: None)
        workers = [SimpleNamespace(visible_message=lambda *args: None) for _ in range(2)]

        def wait(worker, seconds, target):
            self.assertIs(target, heap)
            self.assertTrue(heap.turning)
            waits.append(worker)
            if worker is workers[0]:
                # Enter the same production proc at a fake timer boundary, not in game.
                turn(heap, workers[1])
                self.assertTrue(heap.turning)
                return False
            return True

        turn = self.project_turn(wait)
        turn(heap, workers[0])
        self.assertEqual(waits, [workers[0]])
        self.assertEqual(heap.turns, 0)
        self.assertFalse(heap.turning)
        turn(heap, workers[1])
        self.assertEqual(waits, workers)
        self.assertEqual(heap.turns, 1)
        self.assertFalse(heap.turning)


if __name__ == '__main__':
    unittest.main()
