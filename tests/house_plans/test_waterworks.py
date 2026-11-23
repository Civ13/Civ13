"""Waterworks planner contracts and the real embedded editor's drawing flow."""

import json
from pathlib import Path
import re
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]
PLAN = (ROOT / 'code/modules/1713/waterworks_plan.dm').read_text()
DESIGNER = (ROOT / 'code/modules/1713/waterworks_designer.dm').read_text()
MARKERS = (ROOT / 'code/game/objects/build_markers.dm').read_text()


def block(text, signature):
    return text.split(signature, 1)[1].split('\n/', 1)[0]


class WaterworksSource(unittest.TestCase):
    def test_every_option_uses_the_cost_and_research_of_a_real_recipe(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text()
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text()
        rows = re.findall(r'^\s+"([A-Z])" = list\("mode".*"type" = ([\w/]+), "name" = "[^"]+", "stock" = "([^"]+)", "units" = (\d+), "research" = "([^"]+)"', PLAN, re.M)
        self.assertEqual({row[0] for row in rows}, set('ICAFPUVDSBO'))
        for key, path, stock, units, node in rows:
            with self.subTest(key=key):
                material = {'stone bricks': 'stonebrick'}.get(stock, stock)
                self.assertRegex(recipes, rf'(?m)^RECIPE: /material/{material}/,[^,]+,{path},{units},')
                self.assertIn(f'"{path}" = "{node.lower().replace(" ", "_")}"', research)

    def test_preview_uses_installed_network_rules(self):
        aqueduct = (ROOT / 'code/modules/1713/aqueducts.dm').read_text()
        sewer = (ROOT / 'code/modules/1713/sewers.dm').read_text()
        site = block(PLAN, '/datum/waterworks_plan/proc/check_site(')
        for helper, runtime in [('aqueduct_route_level', aqueduct), ('aqueduct_bank_water', aqueduct), ('sewer_bank_outfall_dir', sewer)]:
            self.assertIn(helper + '(', site)
            self.assertEqual(runtime.count(helper + '('), 2)
        self.assertIn('R.warning("This section goes uphill.', site)
        self.assertIn('R.warning("Freshwater discharge', site)
        self.assertIn('R.error("This earlier bank tile', site)

    def test_pegs_only_after_checks_and_capacity_and_match_exact_types(self):
        stage = block(PLAN, '/datum/waterworks_plan/proc/peg_out(')
        ordered = ('check_site(origin, R, seen, H)', 'if (blocked)', 'BUILD_MARKER_WORLD_MAX',
                   'build_markers_pull(set_id)', 'build_marker_place(')
        self.assertEqual([stage.index(k) for k in ordered], sorted(stage.index(k) for k in ordered))
        self.assertNotIn('new ', stage)
        self.assertIn('S.type == row["type"] && !QDELETED(S)', MARKERS)
        admission = block(PLAN, '/obj/item/ship_draught/proc/waterworks_peg_menu(')
        self.assertEqual(admission.count('waterworks_context(H, actor, identity, current)'), 3)
        self.assertEqual(admission.count('get_turf(H) != origin'), 2)
        self.assertIn('cartography_visible_turfs(H)', admission)
        self.assertIn('waterworks_bank_surveyed(T, seen, H)', PLAN)
        self.assertIn('los_read_allowed(H, A, "examine")', PLAN)
        self.assertIn('/obj/item/ship_draught/proc/waterworks_held(', PLAN)

    def test_saved_browser_and_native_fixture_are_wired(self):
        topic = block(DESIGNER, '/datum/waterworks_designer/Topic(')
        for needle in ('H != drawer', 'waterworks_editors()[H] != src', 'ship_designer_can_draw(H, sheet)',
                       'sheet.waterworks_held(H)', 'source_code != sheet.draught_code',
                       'length(code) <= DESIGN_CODE_WATER_MAX', 'if (action != "preview")'):
            self.assertIn(needle, topic)
        probe = (ROOT / 'tests/house_plans/probe.dm').read_text()
        self.assertIn('#include "waterworks_probe.dm"', probe)
        self.assertIn('waterworks_probe()', probe)
        self.assertIn('tests/house_plans/run.py', (ROOT / '.github/workflows/test.yml').read_text())

    @unittest.skipUnless(shutil.which('node'), 'node not installed')
    def test_editor_appends_in_order_rejects_gap_and_shows_preview(self):
        script = re.search(r'<script>\s*(var D=@@DATA@@.*)</script>', DESIGNER, re.S)[1]
        data = dict(ref='editor', side=7, limit=24, route=[], name='Test plan', mode='A', parts={
            'I': dict(mode='A', name='intake', use='bank', cost='4 stone', research='Irrigation'),
            'C': dict(mode='A', name='channel', use='slope', cost='2 stone', research='Irrigation'),
            'D': dict(mode='S', name='grate', use='puddles', cost='1 stone', research='Sanitation'),
        })
        script = '''
const assert = require('node:assert/strict');
const ids = {};
function node(){
  const n={value:'', children:[],textContent:'',className:'',
    classes:new Set(),setAttribute(){},appendChild(x){this.children.push(x);if(!this.value)this.value=x.value;},
    insertCell(){return node()},insertRow(){const r=node();this.children.push(r);return r;}};
  n.classList={add(c){n.classes.add(c)},remove(c){n.classes.delete(c)}};
  return n;
}
global.document={getElementById(k){return ids[k] ||= node()}, createElement:node};
let confirmChoice=true;
global.window={confirm(){return confirmChoice;}};
''' + script.replace('@@DATA@@', json.dumps(data)) + r'''
assert.equal(el('grid').children.length,7);
el('palette').value='I'; buttons['1,1'].onclick();
el('palette').value='C'; buttons['2,2'].onclick();
assert.equal(route.length,1);
assert.match(el('status').textContent,/tile edge/);
buttons['2,1'].onclick(); buttons['3,1'].onclick();
assert.equal(buttons['3,1'].textContent,3);
el('undo').onclick();
assert.equal(route.length,2);
el('preview').onclick();
assert.equal(decodeURIComponent(window.location),'?src=editor;waterworks=preview;code=C13WATER/1/Test_plan/A/1,1,I;2,1,C');
waterworksAnswer(JSON.stringify({message:'checked',site:'10, 12, level 1',materials:{stone:6},checks:[{level:'error',text:'Slope',cells:['2,1']}]}));
assert.equal(el('materials').textContent,'6 stone');
el('checks').children[0].onfocus();
assert(buttons['2,1'].classes.has('mark'));
el('checks').children[0].onblur();
assert(!buttons['2,1'].classes.has('mark'));
el('save').onclick(); assert.match(window.location,/waterworks=save/);
confirmChoice=false;
el('mode').value='S'; el('mode').onchange();
assert.equal(el('mode').value,'A');
assert.equal(route.length,2);
confirmChoice=true;
el('mode').value='S'; el('mode').onchange();
assert.equal(route.length,0);
el('palette').value='D'; buttons['1,1'].onclick();
el('export').onclick(); assert.match(decodeURIComponent(window.location),/C13WATER\/1\/Test_plan\/S\/1,1,D$/);
'''
        result = subprocess.run(['node', '-'], input=script, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
