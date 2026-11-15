"""Offline source checks for tailoring (dressmaking.dm) with explicit boundaries.

Not a DM compiler, native inventory test, or save round trip. Sprite checks read
actual DMI metadata. The compiled crafting fixture (tests/crafting/dressmaking.dm)
covers cutting, sewing, interruptions and save round trips natively.
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

ART = {'under': ('icons/mob/uniform.dmi', 'icons/obj/clothing/uniforms.dmi'),
       'suit': ('icons/mob/suit.dmi', 'icons/obj/clothing/suits.dmi'),
       'head': ('icons/mob/head.dmi', 'icons/obj/clothing/hats.dmi'),
       'tailoring': ('icons/mob/tailoring.dmi', 'icons/obj/clothing/tailoring.dmi')}


def catalogue():
    """Parse every C["id"] = list(...) row of tailoring_bodies()."""
    body = adapter.extract(SOURCE, '/proc/tailoring_bodies')
    rows = {}
    for match in re.finditer(r'C\["(\w+)"\] = list\((.*)\)\n', body):
        text = match[2]
        row = {'slot': re.search(r'"slot" = "(\w+)"', text)[1],
               'base': re.search(r'"base" = "(\w+)"', text)[1],
               'node': re.search(r'"node" = "(\w+)"', text)[1],
               'cost': int(re.search(r'"cost" = (\d+)', text)[1])}
        art = re.search(r'"art" = "(\w+)"', text)
        row['art'] = art[1] if art else row['slot']
        item_base = re.search(r'"item_base" = "(\w+)"', text)
        row['item_base'] = item_base[1] if item_base else None
        panels = re.search(r'"panels" = list\(([^)]*)\)', text)[1]
        row['panels'] = re.findall(r'"[^"]+" = "(\w+)"', panels)
        fixed = re.search(r'"fixed" = list\(([^)]*)\)', text)
        row['fixed'] = re.findall(r'"(\w+)"', fixed[1]) if fixed else []
        rows[match[1]] = row
    return rows


def dmi_states(path):
    data = (ROOT / path).read_bytes()
    at, metadata = 8, ''
    while at < len(data):
        size = struct.unpack('>I', data[at:at+4])[0]
        kind, payload = data[at+4:at+8], data[at+8:at+8+size]
        at += size + 12
        if kind == b'zTXt' and payload.startswith(b'Description\0'):
            metadata = zlib.decompress(payload.split(b'\0', 1)[1][1:]).decode()
    states = {}
    for block in metadata.split('state = ')[1:]:
        name = block.split('\n')[0].strip('"')
        states.setdefault(name, int(re.search(r'dirs = (\d+)', block)[1]))
    return states


class TailoringTests(unittest.TestCase):
    def test_catalogue_covers_existing_customizable_garments_within_layer_cap(self):
        rows = catalogue()
        self.assertGreaterEqual(len(rows), 30)
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text()
        for body_id, row in rows.items():
            with self.subTest(body=body_id):
                self.assertIn(row['slot'], ART)
                self.assertLessEqual(1 + len(row['panels']), 6)
                self.assertTrue(1 <= row['cost'] <= 8)
                self.assertIn(f'register_research_node(new /datum/research_node("{row["node"]}"', nodes)

    def test_every_state_has_item_art_and_four_worn_directions(self):
        rows = catalogue()
        cache = {}
        for body_id, row in rows.items():
            worn_path, item_path = ART[row['art']]
            worn = cache.setdefault(worn_path, dmi_states(worn_path))
            item = cache.setdefault(item_path, dmi_states(item_path))
            for state in [row['base']] + row['panels'] + row['fixed']:
                with self.subTest(body=body_id, state=state):
                    self.assertGreaterEqual(worn.get(state, 0), 4)
                    if state != row['base'] or not row['item_base']:
                        self.assertIn(state, item)
            if row['item_base']:
                self.assertIn(row['item_base'], item)

    def test_every_piece_state_has_template_art(self):
        body = adapter.extract(SOURCE, '/proc/tailoring_bodies')
        states = set(re.findall(r'"(tl_\w+)"', body))
        self.assertGreaterEqual(len(states), 39)
        worn, item = dmi_states(ART['tailoring'][0]), dmi_states(ART['tailoring'][1])
        for state in sorted(states):
            with self.subTest(state=state):
                self.assertGreaterEqual(worn.get(state, 0), 4)
                self.assertIn(state, item)
        info = re.search(r'var/global/list/tailoring_piece_info = list\((.*?)\)\n\n', SOURCE, re.S)[1]
        for state, node, cost in re.findall(r'"(tl_\w+)" = list\("(\w+)", (\d+), [^)]*\)', info):
            with self.subTest(piece=state):
                self.assertIn(state, states)
                self.assertTrue(0 <= int(cost) <= 2)

    def test_fabric_and_dyes(self):
        fabrics = re.search(r'var/global/list/tailoring_fabrics = list\((.*?)\)\n\n', SOURCE, re.S)[1]
        self.assertIn('"cloth" = list("stack" = /obj/item/stack/material/cloth', fabrics)
        self.assertIn('"woolcloth" = list("stack" = /obj/item/stack/material/woolcloth', fabrics)
        dyes = re.search(r'var/global/list/tailoring_dye_tiers = list\((.*?)\)\n\n', SOURCE, re.S)[1]
        colors = re.findall(r'"(#[0-9a-f]{6})"', dyes)
        self.assertEqual(len(colors), len(set(colors)))
        self.assertIn('"undyed" = "#ffffff"', dyes)
        self.assertIn('#define TAILORING_ANY_DYE_NODE "textile_mills"', SOURCE)
        stack = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text()
        self.assertIn('project.fabric_kind = tailoring_fabric_kind_of(src) || project.fabric_kind', stack)
        attack = adapter.extract(SOURCE, '/obj/item/tailoring_project/attackby')
        self.assertLess(attack.index('if (sheet_kind != fabric_kind)'), attack.index('S.use(1)'))

    def test_actor_guard_checks_hands_ability_research_and_save_identity(self):
        body = adapter.extract(SOURCE, '/obj/item/tailoring_project/proc/actor_ready')
        for term in ('!gcDestroyed', 'loc == user', 'user.l_hand == src || user.r_hand == src',
                     'isturf(user.loc)', 'user.loc == site', '!user.incapacitated()', 'user.can_use_hands()',
                     '!persistence_save_in_progress', '!persistence_active_operation',
                     '!persistence_load_recovery_required', 'save_epoch == persistence_admission_identity',
                     'crafting_node_allowed(user, "weaving")'):
            self.assertIn(term, body)
        for name in ('cut_fabric', 'sew_garment'):
            proc = adapter.extract(SOURCE, '/obj/item/tailoring_project/proc/' + name)
            self.assertIn('tailoring_design_allowed(user, design_body, design_pieces, design_colors)', proc)
            # Re-check after every wait: the world can change while cutting.
            wait = proc.index('wait_for_tailoring(')
            self.assertIn('!actor_ready(user, site, save_epoch)', proc[wait:])

    def test_sew_clears_hand_before_replacing_the_paid_project(self):
        proc = adapter.extract(SOURCE, '/obj/item/tailoring_project/proc/sew_garment')
        self.assertLess(proc.index('user.transfer_held_item_to(src, site)'), proc.index('stage = 2'))
        self.assertLess(proc.index('stage = 2'), proc.index('new garment_type(site)'))
        self.assertLess(proc.index('new garment_type(site)'), proc.index('qdel(src)'))

    def test_menu_lock_and_preview_are_runtime_only_and_closed(self):
        attack = adapter.extract(SOURCE, '/obj/item/tailoring_project/attack_self')
        self.assertLess(attack.index('crafting_node_allowed_or_warn(user, "weaving")'), attack.index('tailoring_busy = TRUE'))
        self.assertLess(attack.index('tailoring_busy = TRUE'), attack.index('design_menu('))
        self.assertLess(attack.index('design_menu('), attack.index('hide_tailoring_preview()'))
        self.assertLess(attack.index('hide_tailoring_preview()'), attack.index('tailoring_busy = FALSE'))
        self.assertIn('return key == "tailoring_busy" || ..()', SOURCE)
        self.assertIn('return key == "tailoring_overlays" || ..()', SOURCE)
        menu = adapter.extract(SOURCE, '/obj/item/tailoring_project/proc/design_menu')
        self.assertIn('"Tailoring", "Close", options)', menu)
        self.assertIn('tailoring_body_allowed(user, known[selected])', menu)
        self.assertIn('!tailoring_color_valid(selected_color)', menu)

    def test_no_runtime_icon_blending_or_resource_uploads(self):
        # Memory budget: worn and preview art are shared image appearances only.
        for forbidden in ('.Blend(', 'send_rsc', 'browse_rsc', 'new /icon', 'icon/'):
            self.assertNotIn(forbidden, SOURCE)
        self.assertIsNone(re.search(r'(?<![\w.])icon\(', SOURCE))

    def test_restoration_rebuilds_design_then_accessories_and_blood(self):
        body = adapter.extract(SOURCE, '/obj/item/clothing/proc/tailoring_rebuild_after_load')
        self.assertLess(body.index('tailoring_refresh()'), body.index('accessory.get_inv_overlay()'))
        self.assertLess(body.index('accessory.get_inv_overlay()'), body.index('overlays += blood_overlay'))
        render = adapter.extract(SOURCE, '/obj/item/clothing/proc/tailoring_refresh')
        self.assertIn('overlays -= tailoring_overlays', render)
        self.assertIn('item_state_slots[slot_w_uniform_str] = body["base"]', render)
        icons = (ROOT / 'code/game/mob/living/carbon/human/update_icons.dm').read_text()
        self.assertIn('standing.overlays += tailored_under.worn_design_layers()', icons)
        self.assertIn('standing.overlays += tailored_suit.worn_design_layers()', icons)
        self.assertIn('standing.overlays += tailored_head.worn_design_layers()', icons)

    def test_pattern_book(self):
        self.assertIn('#define TAILORING_BOOK_MAX 20', SOURCE)
        path = adapter.extract(SOURCE, '/proc/tailoring_book_path')
        self.assertIn('key = ckey(key)', path)
        self.assertIn('get_player_notes_file_dir()', path)
        entry = adapter.extract(SOURCE, '/proc/tailoring_book_entry')
        self.assertIn('tailoring_design_valid(body_id, colors_text, pieces_text)', entry)
        self.assertIn('tailoring_clean_name(html_decode(design_name))', entry)
        add = adapter.extract(SOURCE, '/proc/tailoring_book_add')
        self.assertLess(add.index('"duplicate"'), add.index('book.len >= TAILORING_BOOK_MAX'))
        book = adapter.extract(SOURCE, '/proc/tailoring_book')
        self.assertIn('if (book.len >= TAILORING_BOOK_MAX)', book)
        menu = adapter.extract(SOURCE, '/obj/item/tailoring_project/proc/pattern_book_menu')
        self.assertIn('!actor_ready(user, site, save_epoch) || stage != 0', menu)
        self.assertIn('load_design(user, entry["body"]', menu)

    def test_patterns_names_and_staff_panel(self):
        trace = adapter.extract(SOURCE, '/proc/tailoring_trace_pattern')
        # The sheet must be blank, held, and still blank and held after the wait.
        wait = trace.index('user.tailoring_trace_wait(source)')
        self.assertIn('recipe_blank_paper(sheet) || sheet.loc != user', trace[wait:])
        self.assertLess(wait, trace.index('qdel(sheet)'))
        self.assertIn('crafting_node_allowed_or_warn(user, "weaving")', trace)
        pattern_load = adapter.extract(SOURCE, '/obj/item/tailoring_project/proc/load_pattern')
        self.assertIn('load_design(user, P.design_body, P.design_colors, P.design_pieces', pattern_load)
        load = adapter.extract(SOURCE, '/obj/item/tailoring_project/proc/load_design')
        self.assertIn('if (stage != 0)', load)
        self.assertIn('tailoring_design_allowed(user, body_id, pieces_text, colors_text)', load)
        self.assertIn('tailoring_name_blocked(design_author)', load)
        clean = adapter.extract(SOURCE, '/proc/tailoring_clean_name')
        self.assertIn('sanitizeSafe(text, TAILORING_NAME_MAX + 1)', clean)
        self.assertIn('#define TAILORING_NAME_MAX 32', SOURCE)
        name = adapter.extract(SOURCE, '/obj/item/tailoring_project/proc/choose_name')
        self.assertLess(name.index('tailoring_name_blocked(user.ckey)'), name.index('WWinput('))
        self.assertIn('!actor_ready(user, site, save_epoch) || stage != 0', name)
        allowed = adapter.extract(SOURCE, '/proc/tailoring_admin_allowed')
        self.assertIn('R_ADMIN|R_MOD', allowed)
        topic = adapter.extract(SOURCE, '/datum/tailoring_admin_panel/Topic')
        self.assertLess(topic.index('tailoring_admin_allowed(C)'), topic.index('switch'))
        self.assertIn('!(I in tailoring_named_items)', topic)
        self.assertEqual(topic.count('log_admin('), 3)
        verbs = (ROOT / 'code/modules/admin/admin_verbs.dm').read_text()
        self.assertEqual(verbs.count('/client/proc/admin_clothing_designs,'), 3)
        for owner in ('/obj/item/sewing_pattern', '/obj/item/tailoring_project'):
            self.assertIn('tailoring_named_items -= src', adapter.extract(SOURCE, owner + '/Destroy'))

    def test_recipe_and_research(self):
        rows = (ROOT / 'config/crafting/material_recipes_global.txt').read_text().splitlines()
        projects = [line for line in rows if ',/obj/item/tailoring_project,' in line]
        self.assertEqual(projects, ['RECIPE: /material/cloth/,tailoring project,/obj/item/tailoring_project,1,25,0,1,clothing,0,0,18,8,null'])
        self.assertFalse([line for line in rows if ',/obj/item/dressmaking_project,' in line])
        for material in ('cloth', 'woolcloth'):
            for output in ('customdress', 'customdress2'):
                self.assertTrue(any(f'/material/{material}/,' in line and f',/obj/item/clothing/under/{output},4,85,' in line for line in rows))
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text()
        self.assertIn('"/obj/item/tailoring_project" = "weaving"', nodes)
        self.assertIn('recipe_ci_dressmaking()', (ROOT / 'tests/crafting/checks.dm').read_text())
        self.assertIn('tests/crafting/dressmaking.dm', (ROOT / 'scripts/check-recipes.py').read_text())

    def test_atlas_lists_both_garment_types_and_rejects_changed_timing(self):
        spec = importlib.util.spec_from_file_location('dress_atlas', ROOT / 'scripts/atlas/dressmaking.py')
        atlas = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(atlas)
        records = []
        def add(name, kind, inputs, outputs, *args):
            records.append(dict(inputs=[dict(id=path) for path, count in inputs],
                                outputs=[dict(id=path) for path, count in outputs]))
        routes = atlas.add_dressmaking({PATH: SOURCE}, add, records)
        self.assertEqual([route['outputs'] for route in routes],
                         [['/obj/item/clothing/under/tailored'], ['/obj/item/clothing/suit/storage/jacket/tailored'],
                          ['/obj/item/clothing/head/tailored']])
        self.assertIn('Weaving', routes[0]['conditions'])
        for timing in ('30', '60'):
            bad = SOURCE.replace('wait_for_tailoring(user, ' + timing + ')', 'wait_for_tailoring(user, 999)')
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


if __name__ == '__main__':
    unittest.main()
