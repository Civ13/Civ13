"""Glassblowing bench and mason's saw: source contract checks.

The bench's wares stay equal to the hand recipes, the saw never gives fewer
bricks than cutting by hand, both stations have a recipe row, a research node
and sprite states, and both check research again after the wait.

    python3 tests/glass_stone_machines/test_contract.py
"""
import re
import subprocess
import sys
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/glass_stone_machines.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
DMI = ROOT / 'icons/obj/glass_stone_machines.dmi'

STATIONS = {
    '/obj/structure/workshop_machine/glass_bench': ('/material/wood/', 6, 'glassworking'),
    '/obj/structure/workshop_machine/masons_saw': ('/material/wood/', 8, 'stone_masonry'),
}
STATES = {'glass_bench': 1, 'glass_bench_on': 4, 'masons_saw': 1, 'masons_saw_on': 4}


def recipe_rows():
    rows = {}
    for line in RECIPES.splitlines():
        if line.startswith('RECIPE: '):
            f = line[len('RECIPE: '):].split(',')
            rows.setdefault(f[2], []).append(f)
    return rows


def proc_body(header):
    start = SOURCE.index(header)
    end = SOURCE.find('\n/', start + 1)
    return SOURCE[start:end]


def dmi_states():
    data = DMI.read_bytes()
    at = data.index(b'zTXtDescription\x00\x00') + len(b'zTXtDescription\x00\x00')
    text = zlib.decompressobj().decompress(data[at:]).decode()
    return {m.group(1): int(m.group(2))
            for m in re.finditer(r'state = "([^"]+)"\n\tdirs = 1\n\tframes = (\d+)', text)}


class GlassStoneMachines(unittest.TestCase):
    def test_every_station_has_a_recipe_and_a_research_node(self):
        rows = recipe_rows()
        for path, (material, amount, node) in STATIONS.items():
            self.assertEqual(len(rows.get(path, [])), 1, path)
            row = rows[path][0]
            self.assertEqual((row[0], float(row[3])), (material, amount), path)
            self.assertIn('"%s" = "%s"' % (path, node), NODES)
            self.assertRegex(SOURCE, r'(?m)^%s$' % re.escape(path))

    def test_bench_loads_after_the_workshop_machine_base(self):
        self.assertLess(DME.index('clay_lime_fire.dm'), DME.index('glass_stone_machines.dm'))

    def test_blown_wares_match_the_hand_recipes(self):
        rows = recipe_rows()
        body = re.search(r'var/global/list/glass_bench_wares = list\((.*?)\n\)', SOURCE, re.S).group(1)
        wares = {m.group(1): (float(m.group(2)), float(m.group(3)))
                 for m in re.finditer(r'(/obj/[\w/]+) = list\(([\d.]+), ([\d.]+)\)', body)}
        self.assertEqual(len(wares), 18)
        for path, (glass, time) in wares.items():
            self.assertTrue(any(r[0] == '/material/glass/' and (float(r[3]), float(r[4])) == (glass, time)
                                for r in rows[path]), path)
        self.assertIn('#define GLASS_BENCH_YIELD 2', SOURCE)

    def test_bench_needs_and_burns_a_fuelled_fire(self):
        fire = proc_body('/obj/structure/workshop_machine/glass_bench/proc/glory_hole()')
        self.assertIn('F.fuel >= GLASS_BENCH_FUEL && Adjacent(F)', fire)
        body = proc_body('/obj/structure/workshop_machine/glass_bench/proc/blow_wares(')
        self.assertLess(body.index('do_after('), body.index('F.burn_structure_fuel(GLASS_BENCH_FUEL)'))
        self.assertLess(body.index('F.burn_structure_fuel(GLASS_BENCH_FUEL)'), body.index('new ware('))
        self.assertIn('I.type != /obj/item/stack/material/glass', SOURCE)

    def test_touch_and_persistence_identity_survive_both_wait_boundaries(self):
        picker = proc_body('/obj/structure/workshop_machine/glass_bench/attackby(')
        guard = proc_body('/obj/structure/workshop_machine/glass_bench/proc/glass_worker_ready(')
        batch = proc_body('/obj/structure/workshop_machine/glass_bench/proc/blow_wares(')
        self.assertIn('worker_ready(H, S)', guard)
        self.assertIn('isturf(H.loc) && Adjacent(H)', guard)
        self.assertIn('!persistence_admission_changed(admission)', guard)
        self.assertLess(picker.index('admission = persistence_admission_identity'), picker.index('WWinput('))
        self.assertIn('blow_wares(H, I, choices[picked], picked, admission)', picker)
        self.assertLess(batch.index('!glass_worker_ready(H, S, admission)'), batch.index('busy = TRUE'))
        wait = batch.index('do_after(')
        debit = batch.index('F.burn_structure_fuel(')
        self.assertIn('!glass_worker_ready(H, S, admission)', batch[wait:debit])
        self.assertIn('F = glory_hole()', batch[wait:debit])
        self.assertNotIn('persistence_admission_identity', batch)

    def test_saw_cuts_beat_the_hand_recipes(self):
        rows = recipe_rows()
        body = re.search(r'var/global/list/masons_saw_cuts = list\((.*?)\n\)', SOURCE, re.S).group(1)
        cuts = re.findall(r'(/obj/item/stack/material/\w+) = list\((\d+), (/obj/item/stack/material/\w+), (\d+)\)', body)
        self.assertEqual({c[0].rsplit('/', 1)[1] for c in cuts}, {'stone', 'marble', 'sandstone'})
        for block, blocks_in, brick, bricks_out in cuts:
            material = '/material/%s/' % block.rsplit('/', 1)[1]
            hand = [r for r in rows[brick] if r[0] == material]
            self.assertEqual(len(hand), 1, block)
            self.assertGreater(int(bricks_out) / int(blocks_in), 1 / float(hand[0][3]), block)

    def test_stations_check_research_after_the_wait_and_release_the_lock(self):
        for header in ('/obj/structure/workshop_machine/glass_bench/proc/blow_wares(',
                       '/obj/structure/workshop_machine/masons_saw/proc/saw_blocks('):
            body = proc_body(header)
            wait = body.index('do_after(')
            self.assertIn('crafting_recipe_allowed(', body[wait:])
            self.assertLess(wait, body.index('S.use('))
            guard = 'glass_worker_ready(H, S, admission)' if '/glass_bench/' in header else 'worker_ready(H, S)'
            self.assertIn(guard, body[wait:])
            self.assertIn('busy = FALSE', body)

    def test_sprites_exist_and_match_the_script(self):
        self.assertEqual(dmi_states(), STATES)
        for state in re.findall(r'icon_state = "(\w+)"', SOURCE):
            self.assertIn(state, STATES)
        done = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_glass_stone.py'), '--check'],
                              capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stderr)


if __name__ == '__main__':
    unittest.main()
