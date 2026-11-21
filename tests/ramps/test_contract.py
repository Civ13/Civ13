"""Ramps: offline source contracts.

Behaviour (climbing, loads, wheelchairs, walking down) is covered natively by
tests/ramps/run_native.py --byond-bin <dir>.

    python3 tests/ramps/test_contract.py
"""
from pathlib import Path
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/multiz/ramps.dm').read_text(encoding='utf-8')
EDGE = (ROOT / 'code/modules/multiz/edge_climbing.dm').read_text(encoding='utf-8')
RAMPS = {
    '/obj/covers/cobblestone/ramp_earth': ('earth_ramp', 4, 'RAMP_FOOT', '/material/stone/', 'primitive_construction'),
    '/obj/covers/wood/ramp': ('timber_ramp', 4, 'RAMP_WHEELS', '/material/wood/soft/', 'carts'),
    '/obj/covers/cobblestone/ramp_gentle': ('stone_ramp', 8, 'RAMP_HEAVY', '/material/stone/', 'reinforced_concrete'),
    '/obj/covers/concretefloor/ramp': ('concrete_ramp', 8, 'RAMP_HEAVY', '/material/concrete/', 'reinforced_concrete'),
}


def proc_body(text, header):
    start = text.index(header)
    end = text.find('\n/', start + 1)
    return text[start:end if end != -1 else len(text)]


def type_block(path):
    m = re.search(r'(?m)^' + re.escape(path) + r'\n((?:\t.*\n)+)', SOURCE)
    return m.group(1) if m else ''


class Ramps(unittest.TestCase):
    def test_included_in_build_after_its_defines(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\multiz\\ramps.dm"', dme)
        self.assertIn('#include "code\\__defines\\ramps.dm"', dme)
        defines = (ROOT / 'code/__defines/ramps.dm').read_text(encoding='utf-8')
        for name in ('RAMP_FOOT', 'RAMP_WHEELS', 'RAMP_HEAVY', 'RAMP_HEAVY_TIME'):
            self.assertIn('#define ' + name, defines)

    def test_each_kind_has_length_load_art_recipe_and_research(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        for path, (state, sections, carries, material, node) in RAMPS.items():
            block = type_block(path)
            self.assertIn('icon_state = "%s"' % state, block, path)
            self.assertIn('ramp_sections = %d' % sections, block, path)
            self.assertIn('ramp_carries = %s' % carries, block, path)
            self.assertRegex(recipes, r'RECIPE: %s,[^,]+,%s,' % (re.escape(material), re.escape(path)))
            self.assertIn('"%s" = "%s"' % (path, node), nodes)

    def test_concrete_ramp_keeps_its_state(self):
        # concretefloor/New() picks a random floor state
        self.assertIn('icon_state = initial(icon_state)', proc_body(SOURCE, '/obj/covers/concretefloor/ramp/New()'))

    def test_only_a_full_run_with_headroom_climbs(self):
        body = proc_body(SOURCE, '/proc/ramp_problem(')
        for needed in ('ramp_section_in(get_step(T, R.dir), R)', 'ramp_run_length(R)', 'sections < R.ramp_sections',
                       'multiz_level_above(T.z)', 'ramp_headroom(over)'):
            self.assertIn(needed, body)
        # people walking through the opening are not a ceiling
        self.assertIn('A.density && !isliving(A)', proc_body(SOURCE, '/proc/ramp_headroom('))

    def test_stairs_paths_take_the_ramp_top(self):
        self.assertIn('return ramp_top_in(T)', proc_body(EDGE, '/proc/stairs_in('))
        dest = proc_body(EDGE, '/proc/stairs_destination(')
        self.assertIn('(H.buckled && !ramp_takes_chair(H, S))', dest)
        self.assertIn('if (!S.ramp_sections)', dest)
        climb = proc_body(EDGE, '/mob/living/human/proc/climb_stairs(')
        self.assertIn('stairs_check_load(src, destination, S)', climb)
        self.assertLess(climb.index('do_after('), climb.index('stairs_check_load('))
        self.assertIn('RAMP_HEAVY_TIME', climb)
        self.assertIn('stairs_check_load(H, below, route)', proc_body(EDGE, '/proc/stairs_soft_descent('))
        self.assertIn('ramp_takes_chair', SOURCE)
        self.assertIn('S.ramp_carries >= RAMP_WHEELS', proc_body(SOURCE, '/proc/ramp_takes_chair('))

    def test_sprite_sheet_matches_its_generator(self):
        result = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_ramps.py'), '--check'],
                                cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
