"""Offline execution of the full cut/sew bodies with explicit engine boundaries.

Not a DM compiler, native inventory test, or save round trip. Sprite checks read
actual DMI metadata/pixels. The compiled crafting fixture covers the native paths.
"""
import importlib.util
from pathlib import Path
import re
import struct
import zlib
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
PATH = 'code/modules/1713/dressmaking.dm'
SOURCE = (ROOT / PATH).read_text()
_spec = importlib.util.spec_from_file_location('dress_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(adapter)


def action(name, source=SOURCE):
    # Qualify DM's implicit src fields and calls; retain every statement/branch.
    fields = ('actor_ready', 'stage', 'dress_cut', 'primary_color', 'secondary_color',
              'accent_color', 'name', 'wait_for_dressmaking')
    declaration = '/obj/item/dressmaking_project/proc/' + name
    body = adapter.extract(source, declaration)
    pieces = re.split(r'("(?:[^"\\]|\\.)*")', body)
    for index in range(0, len(pieces), 2):
        for field in fields:
            pieces[index] = re.sub(r'(?<![\w.])' + field + r'\b', 'src.' + field, pieces[index])
    adapted = ''.join(pieces)
    # The one new(site) expression is the explicit allocation boundary.
    adapted = adapted.replace('= new(site)', '= make_dress(site)')
    env = {'to_chat': lambda *args: None, 'SPAN_NOTICE': lambda text: text,
           'dressmaking_design_valid': lambda *args: True,
           'make_dress': lambda site: Dress(), 'qdel': lambda item: setattr(item, 'deleted', True)}
    return adapter.project(declaration + '()\n' + adapted + '\n', declaration, 'src, user, site, save_epoch', env)


class Dress:
    def refresh_design(self):
        self.refreshed = True
        self.name = 'tailored dress'


class Project:
    def __init__(self, mode='complete'):
        self.stage = 0
        self.mode = mode
        self.ready = True
        self.deleted = False
        self.dress_cut = 'Layered'
        self.primary_color, self.secondary_color, self.accent_color = '#112233', '#445566', '#778899'

    def actor_ready(self, user, site, epoch):
        return self.ready and not self.deleted

    def wait_for_dressmaking(self, user, delay):
        if self.mode == 'late_invalid':
            self.ready = False
        elif self.mode == 'competing_finish':
            self.stage = 2
        return self.mode != 'cancel'


class Actor:
    def __init__(self, transfer=True):
        self.transfer = transfer
        self.outputs = []

    def transfer_held_item_to(self, item, site):
        return self.transfer

    def put_in_any_hand_if_possible(self, item):
        self.outputs.append(item)


class DressmakingTests(unittest.TestCase):
    def test_cut_then_sew_consumes_one_project_and_copies_design(self):
        p, h = Project(), Actor()
        self.assertFalse(action('sew_dress')(p, h, None, None))
        self.assertTrue(action('cut_fabric')(p, h, None, None))
        self.assertEqual(p.stage, 1)
        self.assertFalse(action('cut_fabric')(p, h, None, None))
        self.assertTrue(action('sew_dress')(p, h, None, None))
        self.assertTrue(p.deleted)
        self.assertEqual(p.stage, 2)
        self.assertEqual(len(h.outputs), 1)
        d = h.outputs[0]
        for field in ('dress_cut', 'primary_color', 'secondary_color', 'accent_color'):
            self.assertEqual(getattr(d, field), getattr(p, field))
        self.assertTrue(d.refreshed)
        self.assertFalse(action('sew_dress')(p, h, None, None))
        self.assertEqual(len(h.outputs), 1)

    def test_cancellation_and_late_invalidity_preserve_paid_project(self):
        for name, stage in [('cut_fabric', 0), ('sew_dress', 1)]:
            for mode in ('cancel', 'late_invalid', 'competing_finish'):
                with self.subTest(name=name, mode=mode):
                    p, h = Project(mode), Actor()
                    p.stage = stage
                    self.assertFalse(action(name)(p, h, None, None))
                    self.assertFalse(p.deleted)
                    self.assertEqual(h.outputs, [])
                    self.assertEqual(p.stage, 2 if mode == 'competing_finish' else stage)

    def test_failed_inventory_transfer_cannot_consume_or_output(self):
        p, h = Project(), Actor(transfer=False)
        p.stage = 1
        self.assertFalse(action('sew_dress')(p, h, None, None))
        self.assertEqual(p.stage, 1)
        self.assertFalse(p.deleted)
        self.assertEqual(h.outputs, [])

    def test_missing_post_wait_guard_mutation_is_detected(self):
        mutated = SOURCE.replace(' || !actor_ready(user, site, save_epoch) || stage != 1)', ' || stage != 1)')
        p, h = Project('late_invalid'), Actor()
        p.stage = 1
        self.assertTrue(action('sew_dress', mutated)(p, h, None, None))
        self.assertEqual(len(h.outputs), 1, 'control must expose stale completion')

    def test_actor_guard_checks_hands_ability_research_and_save_identity(self):
        body = adapter.extract(SOURCE, '/obj/item/dressmaking_project/proc/actor_ready')
        for term in ('!gcDestroyed', 'loc == user', 'user.l_hand == src || user.r_hand == src',
                     'isturf(user.loc)', 'user.loc == site', '!user.incapacitated()', 'user.can_use_hands()',
                     '!persistence_save_in_progress', '!persistence_active_operation',
                     '!persistence_load_recovery_required', 'save_epoch == persistence_admission_identity',
                     'crafting_node_allowed(user, "fine_garments")'):
            self.assertIn(term, body)

    def test_menu_default_and_preview_terminate_without_client_spin(self):
        body = adapter.extract(SOURCE, '/obj/item/dressmaking_project/proc/design_menu')
        self.assertIn('"Dressmaking", "Close", options)', body)
        self.assertRegex(body, r'if \("Preview"\)\n\s+show_design\(user\)\n\s+return')
        attack = adapter.extract(SOURCE, '/obj/item/dressmaking_project/attack_self')
        self.assertLess(attack.index('dressmaking_busy = TRUE'), attack.index('design_menu('))
        self.assertGreater(attack.index('dressmaking_busy = FALSE'), attack.index('design_menu('))
        self.assertIn('stage == 0 && dressmaking_cut(selected_cut)', body)
        self.assertIn('stage != 0 || !dressmaking_color_valid(selected_color)', body)

    def test_recipe_and_research_preserve_existing_dresses(self):
        rows = (ROOT / 'config/crafting/material_recipes_global.txt').read_text().splitlines()
        projects = [line for line in rows if ',/obj/item/dressmaking_project,' in line]
        self.assertEqual(projects, ['RECIPE: /material/cloth/,dressmaking project,/obj/item/dressmaking_project,4,25,0,1,feminine clothing,0,0,38,8,null'])
        for material in ('cloth', 'woolcloth'):
            for output in ('customdress', 'customdress2'):
                self.assertTrue(any(f'/material/{material}/,' in line and f',/obj/item/clothing/under/{output},4,85,' in line for line in rows))
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text()
        self.assertIn('"/obj/item/dressmaking_project" = "fine_garments"', nodes)
        self.assertIn('recipe_ci_dressmaking()', (ROOT / 'tests/crafting/checks.dm').read_text())
        self.assertIn('tests/crafting/dressmaking.dm', (ROOT / 'scripts/check-recipes.py').read_text())

    def test_restoration_rebuilds_panels_then_accessories_and_blood(self):
        body = adapter.extract(SOURCE, '/obj/item/clothing/under/tailored_dress/after_load')
        self.assertLess(body.index('refresh_design()'), body.index('accessory.get_inv_overlay()'))
        self.assertLess(body.index('accessory.get_inv_overlay()'), body.index('overlays += blood_overlay'))
        self.assertIn('return key == "dressmaking_busy" || ..()', SOURCE)
        self.assertIn('return key == "dressmaking_overlays" || ..()', SOURCE)
        render = adapter.extract(SOURCE, '/obj/item/clothing/under/tailored_dress/proc/refresh_design')
        self.assertIn('overlays -= dressmaking_overlays', render)
        self.assertIn('item_state_slots[slot_w_uniform_str] = icon_state', render)
        icons = (ROOT / 'code/game/mob/living/carbon/human/update_icons.dm').read_text()
        self.assertIn('standing.overlays += dress.worn_design_layers()', icons)

    def test_atlas_exposes_finished_dress_and_rejects_changed_timing(self):
        spec = importlib.util.spec_from_file_location('dress_atlas', ROOT / 'scripts/atlas/dressmaking.py')
        atlas = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(atlas)
        records = []
        def add(name, kind, inputs, outputs, *args):
            records.append(dict(inputs=[dict(id=path) for path, count in inputs],
                                outputs=[dict(id=path) for path, count in outputs]))
        routes = atlas.add_dressmaking({PATH: SOURCE}, add, records)
        self.assertEqual(routes[0]['outputs'], ['/obj/item/clothing/under/tailored_dress'])
        self.assertIn('Fine Garments', routes[0]['conditions'])
        self.assertIn('four cloth sheets', routes[0]['conditions'])
        for timing in ('30', '60'):
            bad = SOURCE.replace('wait_for_dressmaking(user, ' + timing + ')', 'wait_for_dressmaking(user, 999)')
            with self.assertRaises(ValueError):
                atlas.add_dressmaking({PATH: bad}, add, records)

    def test_only_native_fixture_enters_introduced_ci_suites(self):
        spec = importlib.util.spec_from_file_location('dress_selection', ROOT / 'scripts/select-ci.py')
        selection = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(selection)
        added = b'tests/dressmaking/test_source.py\0tests/dressmaking/check_sprites.py\0tests/crafting/dressmaking.dm\0'
        with patch.object(selection.subprocess, 'check_output', return_value=added):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), ['tests/crafting'])
        with patch.object(selection.subprocess, 'check_output', return_value=b'tests/dressmaking/unreviewed.dm\0'):
            with self.assertRaises(RuntimeError):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_every_reused_state_has_item_and_four_worn_directions(self):
        cut = adapter.extract(SOURCE, '/proc/dressmaking_cut')
        states = set(re.findall(r'"((?:customdress|custombuttonup|crinoline_dress)[a-z_]*)"', cut))
        self.assertEqual(len(states), 11)
        for path, required_dirs in [('icons/obj/clothing/uniforms.dmi', 1), ('icons/mob/uniform.dmi', 4)]:
            data = (ROOT / path).read_bytes()
            at, metadata = 8, ''
            while at < len(data):
                size = struct.unpack('>I', data[at:at+4])[0]
                kind, payload = data[at+4:at+8], data[at+8:at+8+size]
                at += size + 12
                if kind == b'zTXt' and payload.startswith(b'Description\0'):
                    metadata = zlib.decompress(payload.split(b'\0', 1)[1][1:]).decode()
            found = set()
            for block in metadata.split('state = ')[1:]:
                name = block.split('\n')[0].strip('"')
                if name in states:
                    found.add(name)
                    self.assertGreaterEqual(int(re.search(r'dirs = (\d+)', block)[1]), required_dirs)
            self.assertEqual(found, states)


if __name__ == '__main__':
    unittest.main()
