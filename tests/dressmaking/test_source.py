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
# Gloves, footwear and belts are drawn only as tailoring pieces.
ACCESSORY_SLOTS = ('gloves', 'shoes', 'belt')


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
                self.assertIn(row['slot'], ART.keys() | set(ACCESSORY_SLOTS))
                if row['slot'] in ACCESSORY_SLOTS:
                    self.assertEqual(row['art'], 'tailoring')
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
        self.assertGreaterEqual(len(states), 98)
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

    def test_mix_and_match_hats(self):
        rows = catalogue()
        hats = {k: v for k, v in rows.items() if v['slot'] == 'head' and v['art'] == 'tailoring'}
        self.assertEqual(sorted(hats), ['made_pointed_hat', 'made_round_hat', 'made_soft_hat', 'made_tall_hat'])
        body = adapter.extract(SOURCE, '/proc/tailoring_bodies')
        for body_id, row in hats.items():
            line = re.search(r'C\["%s"\] = list\((.*)\)\n' % body_id, body)[1]
            with self.subTest(body=body_id):
                # Body plus five options: exactly the colour cap.
                labels = re.findall(r'"(Pattern|Band|Brim|Flaps|Decoration)" = ', line)
                self.assertEqual(labels, ['Pattern', 'Band', 'Brim', 'Flaps', 'Decoration'])
                self.assertIn('"%s_stripes"' % row['base'], line)
                self.assertIn('"%s_panels"' % row['base'], line)
        self.assertIn('#define TAILORING_MAX_COLOURS 6', SOURCE)
        sprites = (ROOT / 'tests/sprites/create_tailoring_pieces.py').read_text()
        for state in set(re.findall(r'"(tl_hat_\w+)"', body)):
            self.assertIn("'%s'" % state, sprites)

    def test_gloves_footwear_and_belts_are_looks_only(self):
        rows = catalogue()
        body = adapter.extract(SOURCE, '/proc/tailoring_bodies')
        made = {k: v for k, v in rows.items() if v['slot'] in ACCESSORY_SLOTS}
        self.assertEqual(sorted(made), ['made_belt', 'made_boots', 'made_gloves', 'made_long_gloves', 'made_sash',
                                        'made_shoes', 'made_tall_boots', 'made_wide_belt'])
        for body_id in made:
            line = re.search(r'C\["%s"\] = list\((.*)\)\n' % body_id, body)[1]
            with self.subTest(body=body_id):
                # No accessory changes what is covered: that stays the item's own.
                self.assertNotIn('"covers"', line)
                self.assertLessEqual(1 + len(re.findall(r'"\w+" = (?:list\(|\w+\.Copy\(\))', line.split('"options" = ', 1)[1].split('"node"')[0])), 6)
                if body_id != 'made_sash':
                    self.assertIn('"fabrics" = ', line)
        info = re.search(r'var/global/list/tailoring_piece_info = list\((.*?)\)\n\n', SOURCE, re.S)[1]
        for state, covers in re.findall(r'"(tl_(?:glove|gloves|boot|boots|shoes|waist)\w*)" = list\("\w+", \d+, ([^)]*)\)', info):
            self.assertEqual(covers, '0', state)
        for path in ('/obj/item/clothing/gloves/thick/leather/tailored', '/obj/item/clothing/shoes/tailored',
                     '/obj/item/clothing/shoes/leatherboots/tailored', '/obj/item/clothing/pouch_belt/tailored'):
            with self.subTest(item=path):
                self.assertIn('tailoring_rebuild_after_load()', adapter.extract(SOURCE, path + '/after_load'))
                self.assertIn('tailoring_named_items -= src', adapter.extract(SOURCE, path + '/Destroy'))
        refresh = adapter.extract(SOURCE, '/obj/item/clothing/proc/tailoring_refresh')
        self.assertIn('if (design_fabric && (body["slot"] in list("under", "suit", "head")))', refresh)
        fabrics = re.search(r'var/global/list/tailoring_fabrics = list\((.*?)\)\n\n', SOURCE, re.S)[1]
        self.assertIn('"leather" = list("stack" = /obj/item/stack/material/leather', fabrics)
        fits = adapter.extract(SOURCE, '/proc/tailoring_body_fits')
        self.assertIn('body["fabrics"] ? body["fabrics"] : TAILORING_WOVEN', fits)
        for name in ('cut_fabric', 'load_design'):
            self.assertIn('tailoring_body_fits(', adapter.extract(SOURCE, '/obj/item/tailoring_project/proc/' + name))
        icons = (ROOT / 'code/game/mob/living/carbon/human/update_icons.dm').read_text()
        self.assertIn('standing.overlays += tailored_gloves.worn_design_layers()', icons)
        self.assertIn('standing.overlays += tailored_shoes.worn_design_layers()', icons)
        belt = adapter.extract(icons, '/mob/living/human/update_inv_belt')
        self.assertLess(belt.index('cbelt.worn_design_layers()'), belt.index('A.get_mob_overlay()'))
        sprites = (ROOT / 'tests/sprites/create_tailoring_pieces.py').read_text()
        for state in set(re.findall(r'"(tl_(?:glove|gloves|boot|boots|shoes|waist)\w*)"', body)):
            self.assertIn("'%s'" % state, sprites)

    def test_bags_and_bandoliers_are_restyled_without_changing_function(self):
        styling = (ROOT / 'code/modules/1713/bag_styling.dm').read_text()
        kinds = re.search(r'var/global/list/bag_style_kinds = list\((.*?)\)\)\n', styling, re.S)[1]
        rows = dict((path, (bag, re.findall(r'"(\w+)"', zones))) for path, bag, zones in
                    re.findall(r'"(/obj/item/[\w/]+)" = list\("(\w+)", list\(([^)]*)\)', kinds))
        self.assertEqual(sorted(bag for bag, _ in rows.values()),
                         ['backpack', 'baldric', 'bandolier', 'duffel', 'quiver', 'rucksack', 'satchel', 'sling_bag'])
        loose = dmi_states('icons/obj/clothing/bag_styles.dmi')
        worn = dmi_states('icons/mob/bag_styles.dmi')
        script = (ROOT / 'tests/sprites/create_bag_styles.py').read_text()
        for bag, zones in rows.values():
            self.assertIn(zones, (['Fabric', 'Straps', 'Trim'], ['Straps', 'Trim']))
            self.assertIn("'%s': (" % bag, script)
            for zone in zones:
                with self.subTest(bag=bag, zone=zone):
                    self.assertEqual(loose['%s_%s' % (bag, zone.lower())], 1)
                    self.assertEqual(worn['%s_%s' % (bag, zone.lower())], 4)
        self.assertEqual(len(loose), sum(len(zones) for _, zones in rows.values()))
        # Exact types only, and the style never touches anything but looks.
        self.assertIn('bag_style_kinds["[I.type]"]', styling)
        sew = adapter.extract(styling, '/obj/item/tailoring_project/proc/sew_bag_style')
        self.assertLess(sew.index('wait_for_tailoring(user, BAG_STYLE_TIME)'), sew.index('spend_alteration_sheet(user, site)'))
        self.assertLess(sew.index('spend_alteration_sheet(user, site)'), sew.index('bag.bag_style = new_style'))
        self.assertEqual(sew.count('alteration_ready(user, site, save_epoch, bag)'), 2)
        self.assertEqual(sew.count('bag_style_allowed(user, colors)'), 2)
        for word in ('max_storage_space', 'storage_slots', 'can_hold', 'slots =', 'armor', 'new /obj', '.name =', 'w_class'):
            self.assertNotIn(word, styling)
        for forbidden in ('icon(', '.Blend(', 'browse_rsc', 'fcopy_rsc'):
            self.assertNotIn(forbidden, styling)
        ready = adapter.extract(styling, '/obj/item/tailoring_project/proc/alteration_ready')
        for guard in ('actor_ready(user, site, save_epoch)', 'stage == 0', 'target.loc == user'):
            self.assertIn(guard, ready)
        self.assertIn('key == "bag_style_overlays"', styling)
        attack = adapter.extract(SOURCE, '/obj/item/tailoring_project/attackby')
        self.assertLess(attack.index('bag_style_kind(W)'), attack.index('tailoring_fabric_kind_of(W)'))
        icons = (ROOT / 'code/game/mob/living/carbon/human/update_icons.dm').read_text()
        self.assertIn('standing.overlays += bag_style_layers(back, TRUE)', adapter.extract(icons, '/mob/living/human/update_inv_back'))
        accessory = (ROOT / 'code/game/objects/items/clothing/under/accessories/accessory.dm').read_text()
        self.assertEqual(accessory.count('bag_style_layers(src, TRUE)'), 2)

    def test_minor_alterations_never_redesign_a_garment(self):
        alter = (ROOT / 'code/modules/1713/tailoring_alterations.dm').read_text()
        self.assertIn('#define TAILORING_ALTER_MAX 2', alter)
        problem = adapter.extract(alter, '/proc/tailoring_alteration_problem')
        for rule in ('changes > TAILORING_ALTER_MAX', 'if (info && info[2])', 'tailoring_variant_allowed(H, body, state)',
                     'tailoring_alteration_covers(G.design_body, new_pieces) != tailoring_alteration_covers(G.design_body, G.design_pieces)',
                     'tailoring_dye_node(after[i])'):
            self.assertIn(rule, problem)
        sew = adapter.extract(alter, '/obj/item/tailoring_project/proc/sew_alteration')
        self.assertEqual(sew.count('tailoring_alteration_problem(user, G, new_colors, new_pieces)'), 2)
        self.assertEqual(sew.count('alteration_ready(user, site, save_epoch, G)'), 2)
        self.assertIn('alteration_material_fits(G)', sew)
        self.assertLess(sew.index('wait_for_tailoring(user, TAILORING_ALTER_TIME)'), sew.index('spend_alteration_sheet(user, site)'))
        self.assertLess(sew.index('spend_alteration_sheet(user, site)'), sew.index('G.design_colors = '))
        # Only colours and pieces are ever written: never the body, name, maker or fabric.
        for field in ('design_body', 'design_name', 'design_maker', 'design_author', 'design_fabric'):
            self.assertNotRegex(alter, r'G\.%s = ' % field)
        for forbidden in ('new /obj', 'armor', 'body_parts_covered', '.Blend(', 'qdel(G'):
            self.assertNotIn(forbidden, alter)
        attack = adapter.extract(SOURCE, '/obj/item/tailoring_project/attackby')
        self.assertLess(attack.index('alter_garment(user, garment)'), attack.index('tailoring_fabric_kind_of(W)'))
        self.assertIn('if (tailoring_body(garment.design_body))', attack)

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

    def test_live_alterations_replace_design_before_other_overlays(self):
        class Overlays(list):
            def __isub__(self, removing):
                for entry in removing:
                    while entry in self:
                        self.remove(entry)
                return self

            def Copy(self):
                return list(self)

        proc = '/obj/item/clothing/proc/tailoring_refresh'
        render = adapter.extract(SOURCE, proc)
        tail = render[render.index('\tif (tailoring_overlays)') : render.index('\treturn TRUE')]
        extras = ['accessory', 'blood', 'unrelated']
        updates = []
        replacement = adapter.project(
            proc + '()\n' + tail + '\treturn overlays, tailoring_overlays\n',
            proc, 'overlays, tailoring_overlays, design_colors',
            dict(tailoring_layers=lambda _body, color, *_: [color + ':body', color + ':trim'],
                 design_body='tunic', design_pieces=None, design_fabric='cloth',
                 update_clothing_icon=lambda: updates.append(True)))
        old = ['white:body', 'white:trim']
        overlays, design = replacement(Overlays(old + extras), old, 'blue')
        self.assertEqual(overlays, ['blue:body', 'blue:trim'] + extras)
        overlays, design = replacement(Overlays(overlays), design, 'red')
        self.assertEqual(overlays, ['red:body', 'red:trim'] + extras)
        self.assertEqual(design, ['red:body', 'red:trim'])
        self.assertEqual(len(updates), 2)

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
        self.assertEqual(projects, ['RECIPE: /material/leather/,tailoring project,/obj/item/tailoring_project,1,25,0,1,clothing,0,0,18,8,null',
                                    'RECIPE: /material/cloth/,tailoring project,/obj/item/tailoring_project,1,25,0,1,clothing,0,0,18,8,null'])
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
                          ['/obj/item/clothing/head/tailored'], ['/obj/item/clothing/gloves/thick/leather/tailored'],
                          ['/obj/item/clothing/shoes/tailored'], ['/obj/item/clothing/shoes/leatherboots/tailored'],
                          ['/obj/item/clothing/pouch_belt/tailored']])
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
