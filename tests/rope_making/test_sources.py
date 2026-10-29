"""Offline cordage compatibility, catalog and Help contracts. No native launch."""
import importlib.util
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from atlas.rope_making import add_rope_making, PATH
import player_help_bridge as bridge

SPEC = importlib.util.spec_from_file_location('rope_runner', Path(__file__).with_name('run.py'))
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class RopeSourceTests(unittest.TestCase):
    def test_frozen_existing_cordage_stays_available(self):
        fixture = json.loads(Path(__file__).with_name('legacy-cordage.json').read_text())
        for path, excerpt in fixture['sources'].items():
            self.assertIn(excerpt, (ROOT / path).read_text(encoding='utf-8'))
        rows = (ROOT / 'config/crafting/material_recipes_global.txt').read_text().splitlines()
        for row in fixture['legacy_recipes']:
            self.assertIn(row, rows)

    def test_mutations_have_reviewed_targets(self):
        for control in (None, *runner.CONTROLS):
            self.assertTrue(runner.source_for(control))

    def test_action_guards_and_exact_types(self):
        source = (ROOT / PATH).read_text()
        self.assertEqual(source.count('admission != persistence_admission_identity'), 4)
        self.assertEqual(source.count('return key == "working" || ..()'), 3)
        self.assertIn('return key == "spinning" || ..()', source)
        self.assertIn('!persistence_save_in_progress && !persistence_active_operation', source)
        self.assertIn('F.type == /obj/item/stack/dressed_hemp', source)
        self.assertIn('F.type == /obj/item/stack/flax_tow', source)
        self.assertIn('W.type == /obj/item/stack/rope_yarn/hemp', source)
        self.assertIn('W.type == /obj/item/stack/rope_yarn/flax', source)
        self.assertIn('B.stage != old_stage', source)
        self.assertIn('H.transfer_held_item_to(I, target) && I.loc == target', source)

    def test_hemp_feedstock_includes_stalks_without_new_crop_grants(self):
        materials = (ROOT / 'code/modules/materials/materials.dm').read_text()
        hemp = materials.split('/material/hemp\n', 1)[1].split('/material/flax\n', 1)[0]
        self.assertIn('sheet_singular_name = "plant bundle"', hemp)
        farm = (ROOT / 'code/game/objects/farming.dm').read_text()
        hemp = farm.split('/obj/structure/farming/plant/hemp\n', 1)[1].split('/obj/structure/farming/plant/flax\n', 1)[0]
        self.assertIn('stack = "material/hemp"', hemp)

    def test_catalog_quantity_drift_fails_before_export(self):
        source = (ROOT / PATH).read_text()
        for old in ('F.use(1)', 'Y.use(4)', 'rope(site, 4, FALSE)'):
            with self.subTest(old=old), self.assertRaises(ValueError):
                add_rope_making({PATH: source.replace(old, old.replace('1', '2').replace('4', '5'))}, None, [])

    def test_atlas_lists_procedural_routes_and_gates(self):
        catalog = json.loads((ROOT / 'UI/crafting-atlas.json').read_text())
        records = [x for x in catalog['recipes'] if x['kind'] == 'Rope making']
        self.assertEqual(len(records), 6)
        for recipe in records:
            self.assertEqual(recipe['file'], PATH)
        for path in ('/obj/item/stack/dressed_hemp', '/obj/item/stack/rope_yarn/hemp',
                     '/obj/item/stack/rope_yarn/flax', '/material/rope'):
            routes = catalog['acquisition'][path]
            self.assertTrue(any(x['file'] == PATH for x in routes))
        gates = (ROOT / 'code/modules/research_tree/research_node.dm').read_text()
        for path, node in [('/obj/item/rope_spindle', 'basic_tools'),
                           ('/obj/structure/hemp_dressing_bench', 'resource_processing'),
                           ('/obj/structure/ropewalk', 'resource_processing')]:
            self.assertIn('"' + path + '" = "' + node + '"', gates)

    def test_help_indexes_stages_without_invented_unlocks(self):
        rows = bridge.acquisition_context(ROOT / 'UI/crafting-atlas.json')
        rope = [x for x in rows if 'counter-lay hemp rope' in x['topic']]
        self.assertEqual(len(rope), 1)
        text = rope[0]['text']
        for term in ('opposite direction', 'Resource Processing', 'same yarn material',
                     'Grass crude twine', 'game units'):
            self.assertIn(term, text)
        self.assertNotIn('already researched', text)

    def test_recovery_and_single_stack_instructions_reach_help(self):
        source = (ROOT / PATH).read_text()
        verb = source.split('/obj/item/hemp_rope_bundle/verb/recover_hemp_bundle()', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('set src in view(1)', verb)
        self.assertIn('recover_bundle(usr)', verb)
        rows = bridge.acquisition_context(ROOT / 'UI/crafting-atlas.json')
        recovery = next(row['text'] for row in rows if 'tie and ret hemp for rope' in row['topic'])
        for term in ('Recover Hemp Bundle', 'free hand', 'salty or irradiated water'):
            self.assertIn(term, recovery)
        rope = next(row['text'] for row in rows if 'counter-lay hemp rope' in row['topic'])
        self.assertIn('one held stack', rope)
        self.assertIn('Apply matching yarn stacks to each other', rope)
        guide = (ROOT / 'docs/rope-making.md').read_text()
        self.assertIn('four separate stacks cannot be loaded individually', guide)
        self.assertIn('right-click the submerged bundle', guide)

    def test_runner_compile_only_cannot_launch_daemon(self):
        source = Path(__file__).with_name('run.py').read_text()
        begin = source.index('if args.compile_only:')
        end = source.index('with tempfile.TemporaryDirectory', begin)
        self.assertIn('return', source[begin:end])
        self.assertIn('byond_runtime.verify_linux(binary, archive)', source)
        self.assertIn("'-trusted'", source)
        self.assertNotIn("'-safe'", source)


if __name__ == '__main__':
    unittest.main()
