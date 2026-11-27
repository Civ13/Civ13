"""Cement mixer, concrete blocks and the pile driver: source contract checks.

Concrete is built from concrete blocks rather than raw clay, the mixer is the
way to make those blocks, it has a recipe, a research node and sprite states,
and a batch is only paid for after the wait re-checks the worker and drum.

    python3 tests/building_site/test_contract.py
"""
import re
import subprocess
import sys
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/building_site.dm').read_text(encoding='utf-8')
MATERIALS = (ROOT / 'code/modules/materials/materials.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
DMI = ROOT / 'icons/obj/building_site.dmi'
MIXER = '/obj/structure/workshop_machine/cement_mixer'
DRIVER = '/obj/structure/workshop_machine/pile_driver'
SPAN = '/obj/item/weapon/bridge_span/timber'
CONCRETE_WORKS = {
    '/obj/item/weapon/roofbuilder/concrete': 1,
    '/obj/covers/concretefloor': 1,
    '/obj/item/weapon/bridge_span/concrete': 6,
    '/obj/structure/mine_support/stone/concrete': 2,
}


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


class BuildingSite(unittest.TestCase):
    def test_mixer_has_a_recipe_and_a_research_node(self):
        rows = recipe_rows()[MIXER]
        self.assertEqual(len(rows), 1)
        self.assertEqual((rows[0][0], float(rows[0][3])), ('/material/iron/', 8))
        self.assertIn('"%s" = "reinforced_concrete"' % MIXER, NODES)
        self.assertRegex(SOURCE, r'(?m)^%s$' % re.escape(MIXER))
        self.assertLess(DME.index('clay_lime_fire.dm'), DME.index('building_site.dm'))

    def test_concrete_works_are_built_from_concrete_blocks_only(self):
        rows = recipe_rows()
        for path, amount in CONCRETE_WORKS.items():
            self.assertEqual(len(rows[path]), 1, path)
            self.assertEqual((rows[path][0][0], float(rows[path][0][3])), ('/material/concrete/', amount), path)
            self.assertIn('"%s" = "reinforced_concrete"' % path, NODES)

    def test_concrete_material_has_one_stack_type(self):
        self.assertIn('/material/concrete\n\tstack_type = /obj/item/stack/material/concrete\n', SOURCE)
        block = MATERIALS[MATERIALS.index('\n/material/concrete\n'):]
        block = block[:block.index('\n/', 1)]
        self.assertNotIn('stack_type', block)
        self.assertIn('default_type = "concrete"', SOURCE)

    def test_a_batch_uses_real_ingredients(self):
        body = re.search(r'var/global/list/cement_mixer_charge = list\((.*?)\n\)', SOURCE, re.S).group(1)
        charge = {m.group(1): (int(m.group(2)), m.group(3))
                  for m in re.finditer(r'(/obj/[\w/]+) = list\((\d+), "(\w+)"', body)}
        self.assertEqual(charge, {'/obj/item/stack/ore/quicklime': (1, 'lime'),
                                  '/obj/item/stack/ore/glass': (2, 'sand'),
                                  '/obj/item/stack/material/stone': (2, 'stone')})
        for _, var in charge.values():
            self.assertRegex(SOURCE, r'(?m)^\tvar/%s = 0$' % var)
        self.assertIn('#define CEMENT_MIXER_YIELD 4', SOURCE)

    def test_batch_is_paid_only_after_the_wait_rechecks(self):
        body = proc_body(MIXER + '/proc/mix(')
        wait = body.index('do_after(H, driven_time(CEMENT_MIXER_TIME), src)')
        recheck = body.index('if (!mixer_ready(H) || batch_refusal() || !crafting_recipe_allowed(H, "[type]"))')
        pay = body.index('vars[part[2]] -= part[1]')
        self.assertLess(wait, recheck)
        self.assertLess(recheck, pay)
        self.assertLess(body.index('crafting_recipe_allowed'), wait)
        self.assertIn('busy = FALSE', body[pay:])
        ready = proc_body(MIXER + '/proc/mixer_ready(')
        for needed in ('anchored', 'persistence_save_in_progress', 'persistence_active_operation',
                       'persistence_load_recovery_required'):
            self.assertIn(needed, ready)

    def test_loading_is_capped_and_dismantling_returns_the_charge(self):
        self.assertIn('min(S.amount, CEMENT_MIXER_LIMIT - vars[part[2]])', proc_body(MIXER + '/attackby('))
        body = proc_body(MIXER + '/dismantled()')
        self.assertIn('new refund_type(get_turf(src))', body)
        self.assertIn('vars[part[2]] = 0', body)

    def test_pile_driver_and_pier_span_have_recipes_and_nodes(self):
        rows = recipe_rows()
        for path, amount in ((DRIVER, 14), (SPAN, 8)):
            self.assertEqual(len(rows[path]), 1, path)
            self.assertEqual((rows[path][0][0], float(rows[path][0][3])), ('/material/wood/', amount), path)
            self.assertIn('"%s" = "imperial_architecture"' % path, NODES)
            self.assertRegex(SOURCE, r'(?m)^%s$' % re.escape(path))

    def test_pier_span_is_a_bridge_span_that_needs_a_driver(self):
        self.assertIn('deck_type = /obj/covers/bridge/timber', SOURCE)
        self.assertIn('span_type = %s' % SPAN, SOURCE)
        body = proc_body(SPAN + '/build_span(')
        # deep water stays for steel and concrete spans
        deep = body.index('if (istype(T, /turf/floor/beach/water/deep))')
        self.assertIn('return FALSE', body[deep:body.index('pile_driver_for(T)')])
        refuse = body.index('if (!D)')
        build = body.index('. = ..()')
        self.assertLess(body.index('pile_driver_for(T)'), refuse)
        self.assertLess(refuse, build)
        self.assertIn('return FALSE', body[refuse:build])
        self.assertLess(body.index('D.busy = TRUE'), build)
        self.assertIn('D.busy = FALSE', body[build:])
        # the shared span rules (water only, firm footing, re-check after the wait) stay in bridges.dm
        bridges = (ROOT / 'code/modules/1713/bridges.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/item/weapon/bridge_span/proc/build_span(turf/T, mob/user)', bridges)
        self.assertIn('new deck_type(T)', bridges)

    def test_driver_must_be_fastened_idle_and_on_firm_footing(self):
        body = proc_body('/proc/pile_driver_for(')
        self.assertIn('range(PILE_DRIVER_REACH, T)', body)
        self.assertIn('if (!D.anchored || D.busy || !footing)\n\t\t\tcontinue', body)
        self.assertIn('istype(footing, /turf/floor/beach/water/deep) && !footing.iscovered()', body)
        self.assertIn('#define PILE_DRIVER_REACH 2', SOURCE)

    def test_sprite_sheet_states_and_script(self):
        data = DMI.read_bytes()
        at = data.index(b'zTXtDescription\x00\x00') + len(b'zTXtDescription\x00\x00')
        text = zlib.decompressobj().decompress(data[at:]).decode()
        states = {m.group(1): int(m.group(2))
                  for m in re.finditer(r'state = "([^"]+)"\n\tdirs = 1\n\tframes = (\d+)', text)}
        self.assertEqual(states, {'cement_mixer': 1, 'cement_mixer_on': 4,
                                  'concrete': 1, 'concrete_2': 1, 'concrete_3': 1,
                                  'pile_driver': 1, 'pile_driver_on': 4})
        self.assertIn('pile_suffix(amount, list(17, 33))', SOURCE)
        try:
            import PIL  # noqa: F401
        except ImportError:
            self.skipTest('Pillow not installed')
        result = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_building_site.py'), '--check'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
