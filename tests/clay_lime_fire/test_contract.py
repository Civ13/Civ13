"""Clay, lime and fire machines: source contract checks.

The potter's wheel and brick bench tables stay equal to the hand recipes, each
station has a recipe row, a research node and a sprite state, the bellows
change only the firing they blow on, and the lime kiln stays off the factory
ports.

    python3 tests/clay_lime_fire/test_contract.py
"""
import re
import subprocess
import sys
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/clay_lime_fire.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
DMI = ROOT / 'icons/obj/workshop_machines.dmi'

STATIONS = {
    '/obj/structure/workshop_machine/potters_wheel': ('/material/wood/', 6, 'pottery_storage'),
    '/obj/structure/workshop_machine/brick_bench': ('/material/wood/', 6, 'brickmaking'),
    '/obj/structure/workshop_machine/bellows': ('/material/leather/', 2, 'bronze_working'),
    '/obj/structure/furnace/lime_kiln': ('/material/stone/', 20, 'stone_masonry'),
}
STATES = {
    'potters_wheel': 1, 'potters_wheel_on': 8, 'bellows': 1, 'bellows_pump': 4,
    'brick_bench': 1, 'brick_bench_full': 1, 'lime_kiln': 1, 'lime_kiln_on': 4, 'quicklime': 1,
}


def recipe_rows():
    rows = {}
    for line in RECIPES.splitlines():
        if line.startswith('RECIPE: '):
            f = line[len('RECIPE: '):].split(',')
            rows.setdefault(f[2], []).append(f)
    return rows


def table(name):
    body = re.search(r'var/global/list/%s = list\((.*?)\n\)' % name, SOURCE, re.S).group(1)
    return {m.group(1): (float(m.group(2)), float(m.group(3)))
            for m in re.finditer(r'(/obj/[\w/]+) = list\(([\d.]+), ([\d.]+)\)', body)}


def dmi_states():
    data = DMI.read_bytes()
    at = data.index(b'zTXtDescription\x00\x00') + len(b'zTXtDescription\x00\x00')
    text = zlib.decompressobj().decompress(data[at:]).decode()
    return {m.group(1): int(m.group(2))
            for m in re.finditer(r'state = "([^"]+)"\n\tdirs = 1\n\tframes = (\d+)', text)}


def proc_body(header):
    start = SOURCE.index(header)
    end = SOURCE.find('\n/', start + 1)
    return SOURCE[start:end]


class ClayLimeFire(unittest.TestCase):
    def test_every_station_has_a_recipe_and_a_research_node(self):
        rows = recipe_rows()
        for path, (material, amount, node) in STATIONS.items():
            self.assertEqual(len(rows.get(path, [])), 1, path)
            row = rows[path][0]
            self.assertEqual((row[0], float(row[3])), (material, amount), path)
            self.assertEqual(row[5], '1', path + ' is one per turf')
            self.assertIn('"%s" = "%s"' % (path, node), NODES)
            self.assertRegex(SOURCE, r'(?m)^%s$' % re.escape(path))

    def test_wheel_wares_match_the_hand_recipes(self):
        rows = recipe_rows()
        wares = table('potters_wheel_wares')
        self.assertEqual(len(wares), 18)  # + storage jar, zeer pot, wash basin, steel crucible
        for path, (clay, time) in wares.items():
            row = rows[path][0]
            self.assertEqual(row[0], '/material/clay/', path)
            self.assertEqual((float(row[3]), float(row[4])), (clay, time), path)

    def test_every_clay_vessel_recipe_is_on_the_wheel(self):
        vessels = {p for p, r in recipe_rows().items()
                   if r[0][0] == '/material/clay/' and p.startswith('/obj/item/weapon/clay/')
                   and '/mold' not in p and 'bricks' not in p and '/roofing' not in p
                   and '/floortiles' not in p  # pressed flat like bricks, not thrown
                   and '/porcelain_dentures' not in p}  # modelled by hand, not thrown
        self.assertEqual(vessels, set(table('potters_wheel_wares')))

    def test_bench_batches_never_cost_more_than_hand_bricks(self):
        rows = recipe_rows()
        batches = table('brick_bench_batches')
        self.assertEqual(set(batches), {
            '/obj/item/weapon/clay/claybricks', '/obj/item/weapon/clay/advclaybricks',
            '/obj/item/weapon/clay/advclaybricks/cement'})
        size = int(re.search(r'#define BRICK_BENCH_BATCH (\d+)', SOURCE).group(1))
        for path, (clay, lime) in batches.items():
            self.assertLessEqual(clay, float(rows[path][0][3]) * size, path)
        self.assertEqual(batches['/obj/item/weapon/clay/advclaybricks/cement'][1], 2)
        self.assertEqual(batches['/obj/item/weapon/clay/claybricks'][1], 0)

    def test_stations_check_research_before_and_after_the_wait(self):
        for header in ('/obj/structure/workshop_machine/potters_wheel/proc/throw_wares(',
                       '/obj/structure/workshop_machine/brick_bench/proc/mould_bricks('):
            body = proc_body(header)
            wait = body.index('do_after(')
            self.assertIn('crafting_recipe_allowed(', body[wait:])
            self.assertLess(body.index('do_after('), body.index('.use('))
            self.assertIn('busy = FALSE', body)
        self.assertIn('crafting_recipe_allowed(H, "[ware]")', proc_body('/proc/potters_wheel_choices('))
        self.assertIn('crafting_recipe_allowed(H, "[brick]")', proc_body('/proc/brick_bench_choices('))

    def test_work_stops_for_saves(self):
        ready = proc_body('/obj/structure/workshop_machine/proc/worker_ready(')
        for guard in ('persistence_save_in_progress', 'persistence_active_operation',
                      'persistence_load_recovery_required', 'anchored'):
            self.assertIn(guard, ready)
        self.assertIn('return key == "busy" || ..()', SOURCE)

    def test_bellows_restore_the_furnace_time(self):
        body = proc_body('/obj/structure/furnace/start_smelt()')
        self.assertIn('if (!bellows_blowing())\n\t\treturn ..()', body)
        lower = body.index('smelt_time = round(normal_time * BELLOWS_TIME_FACTOR)')
        call = body.index('. = ..()')
        restore = body.index('smelt_time = normal_time')
        self.assertTrue(lower < call < restore)
        self.assertIn('var/tmp/bellows_until', SOURCE)
        self.assertIn('#define BELLOWS_TIME_FACTOR 0.75', SOURCE)
        self.assertIn('#define BELLOWS_FUEL_BACK 0.5', SOURCE)

    def test_lime_kiln_is_manual_and_keeps_its_charge_apart(self):
        self.assertIn('/obj/structure/furnace/lime_kiln/factory_port_ready()\n\treturn FALSE', SOURCE)
        load = proc_body('/obj/structure/furnace/lime_kiln/attackby(')
        self.assertIn('!istype(S, /obj/item/stack/material/stone) && !is_marble', load)
        self.assertIn('solid_fuel_value(S, furnace_fuel_rates)', load)
        burn = proc_body('/obj/structure/furnace/lime_kiln/process()')
        self.assertIn('/obj/item/stack/ore/quicklime', burn)
        self.assertNotIn('iron', burn)

    def test_sprites_exist_and_match_the_script(self):
        self.assertEqual(dmi_states(), STATES)
        for state in re.findall(r'icon_state = "(\w+)"', SOURCE):
            self.assertIn(state, STATES)
        done = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_clay_lime_fire.py'), '--check'],
                              capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stderr)


if __name__ == '__main__':
    unittest.main()
