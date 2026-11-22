"""Bounded source-contract checks. Not a DM execution or gameplay substitute."""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
DM = (ROOT / 'code/modules/nano/tgui.dm').read_text()


def declared(path, owner):
    """The actions a window's owner declares in its ui_actions()."""
    source = (ROOT / path).read_text(errors='replace')
    signature = f'/{owner}/ui_actions(ui_key)\n'
    assert source.count(signature) == 1, f'{owner} must declare its actions once'
    body = source.split(signature, 1)[1].split('\n/', 1)[0]
    lists = re.findall(r'return list\(([^\n]+)\)', body)
    assert len(lists) == 1, f'{owner} must return one action list'
    return set(re.findall(r'"([^"\n]+)"', lists[0]))


def declared_fields(path, owner):
    """{action: extra fields} from the owner's ui_action_fields()."""
    source = (ROOT / path).read_text(errors='replace')
    body = source.split(f'/{owner}/ui_action_fields(ui_key, action)\n', 1)[1].split('\n/', 1)[0]
    found = {}
    for action, fields in re.findall(r'(?:if \(action == |if \()"(\w+)"\)+\n\t+return list\(([^\n]+)\)', body):
        found[action] = re.findall(r'"([^"\n]+)"', fields)
    return found


class BackendContract(unittest.TestCase):
    def test_dm_include(self):
        self.assertIn('#include "code\\modules\\nano\\tgui.dm"', (ROOT / 'civ13.dme').read_text())

    def test_owner_and_generation_precede_dispatch(self):
        topic = DM.split('/datum/nanoui/tgui/Topic', 1)[1]
        dispatch = topic.index('if (act_typed(action, params))')
        for guard in ('usr != user', '!src_object || !state', 'href_list["window_id"] != window_id',
                      'href_list["generation"] != "[render_generation]"', 'status != STATUS_INTERACTIVE', '!frontend_acknowledged',
                      '!(action in allowed_actions())', 'length(raw_payload) > 8192', 'params.len > 8',
                      '!(key in keys)', '!istext(params[key]) && !isnum(params[key])'):
            self.assertLess(topic.index(guard), dispatch)

    def test_typed_actions_reach_ui_act_before_the_href_bridge(self):
        self.assertIn('/datum/proc/ui_act(action, list/params, mob/user, datum/nanoui/ui)\n\treturn FALSE', DM)
        topic = DM.split('/datum/nanoui/tgui/Topic', 1)[1]
        # The action no longer doubles as a payload key, and values stay typed.
        self.assertIn('var/list/keys = list("value")', topic)
        self.assertNotIn('isnull(params[action])', topic)
        self.assertNotIn('params[key] = "[params[key]]"', topic)
        self.assertLess(topic.index('if (act_typed(action, params))'), topic.index('return ..(list2params(legacy), legacy)'))
        typed = DM.split('/datum/nanoui/tgui/proc/act_typed(action, list/params)', 1)[1].split('\n/', 1)[0]
        self.assertIn('if (!src_object.ui_act(action, params, user, src))\n\t\treturn FALSE', typed)
        self.assertIn('if (src_object)\n\t\tGLOB.nanomanager.update_uis(src_object)', typed)
        bridge = DM.split('/datum/nanoui/tgui/proc/href_form(action, list/params)', 1)[1]
        self.assertIn('.[action] = "[params["value"]]"', bridge)
        # The reference owner: one guarded handler, no Topic a typed href could reach.
        chem = (ROOT / 'code/modules/reagents/Chemistry-Machinery.dm').read_text(errors='replace')
        self.assertNotIn('/obj/structure/chemical_dispenser/Topic(', chem)
        act = chem.split('/obj/structure/chemical_dispenser/ui_act(', 1)[1].split('\n/', 1)[0]
        self.assertIn('amount = min(max(round(value, 5), 0), 120)', act)
        self.assertIn('if (!isnum(value))', act)
        self.assertIn('add_fingerprint(user)', act)
        # No screen sends the action name as its own payload key any more.
        for path in (ROOT / 'tgui/src').rglob('*.tsx'):
            if not path.name.endswith('.test.tsx'):
                self.assertNotRegex(path.read_text(), r"act\('(\w+)',\s*\{\s*\1:", path.name)
        self.assertIn('ui.act(action, { value, ...params })', (ROOT / 'tgui/src/interfaces/common.tsx').read_text())

    def test_vending_buttons_use_typed_handlers(self):
        base = (ROOT / 'code/game/objects/structures/vending/vending.dm').read_text(errors='replace')
        sales = (ROOT / 'code/game/objects/structures/vending/vending_sales.dm').read_text(errors='replace')
        self.assertNotIn('/obj/structure/vending/Topic(', base)
        row = 'if (!isnum(key) || key != round(key) || key < 1 || key > product_records.len)'
        for source, owner in ((base, '/obj/structure/vending'), (sales, '/obj/structure/vending/sales')):
            act = source.split(f'{owner}/ui_act(action, list/params, mob/user, datum/nanoui/ui)\n', 1)[1].split('\n/', 1)[0]
            self.assertTrue(act.startswith('\t. = TRUE\n'))
            self.assertLess(act.index('user.stat || user.restrained()'), act.index('action == "vend"'))
            self.assertLess(act.index('in_range(src, user)'), act.index('action == "vend"'))
            self.assertLess(act.index(row), act.index('product_records[key]'))
            self.assertNotRegex(act, r'\busr\b|href_list')
        # The owner's management page is a panel window with its own checked handler.
        self.assertNotIn('/obj/structure/vending/sales/Topic(', sales)
        self.assertNotIn('window=vendor_management', sales)
        manage = sales.split('/obj/structure/vending/sales/proc/manage_act(action, list/params, mob/user)\n', 1)[1].split('\n/', 1)[0]
        for check in ('user.stat || user.restrained()', 'in_range(src, user)', 'find_company_member(user, owner)', 'index > product_records.len'):
            self.assertLess(manage.index(check), manage.index('switch (action)'))
        self.assertIn('fiat.currency_list[new_currency][5]', manage)
        self.assertIn('sanitize("[value]", 50)', manage)
        self.assertNotRegex(manage, r'\busr\b|href_list|locate\(')

    def test_status_only_updates_and_ready_snapshot(self):
        self.assertIn('if (!isnull(data))\n\t\tlatest_data = data', DM)
        self.assertIn('push_data(status == STATUS_DISABLED ? null : latest_data, TRUE)', DM)
        self.assertIn('if (!state || !frontend_ready', DM)

    def test_single_renderer_and_plain_pages_only_where_declared(self):
        # No NanoUI template renderer, no server startup watchdog, no link to
        # another interface: the modern screen is the window.
        self.assertFalse((ROOT / 'UI/templates').exists())
        self.assertNotIn('spawn(', DM)
        html = DM.split('/datum/nanoui/tgui/get_html()', 1)[1].split('/datum/nanoui/tgui/push_data', 1)[0]
        self.assertNotIn('..()', html)
        self.assertNotIn('byond://', html)
        self.assertNotRegex(html, r'(?i)classic')
        self.assertIn('This window could not load. Close it and open it again.', html)
        self.assertIn('/datum/nanoui/tgui/proc/has_plain_page()\n\treturn FALSE', DM)
        show = DM.split('/datum/nanoui/tgui/proc/show_plain_page()', 1)[1].split('/datum/nanoui/tgui/get_config_data()', 1)[0]
        self.assertLess(show.index('!has_plain_page()'), show.index('plain_page = TRUE'))
        self.assertLess(show.index('update_status(FALSE)'), show.index('plain_page = TRUE'))
        self.assertIn('if (!state || status == STATUS_CLOSE)', show)
        self.assertIn('plain_page = TRUE\n\tset_initial_data(latest_data)\n\topen()', DM)
        self.assertIn('if (href_list["type"])\n\t\t\treturn', DM)
        # The window's own title bar: BYOND's bar comes back before any plain page
        # or fallback, and the close button closes through the checked Topic.
        self.assertLess(show.index('restore_title_bar()'), show.index('plain_page = TRUE'))
        topic = DM.split('/datum/nanoui/tgui/Topic(href, href_list)', 1)[1]
        self.assertLess(topic.index('href_list["generation"]'), topic.index('message_type == "close"'))
        self.assertIn('if (message_type == "fallback")\n\t\trestore_title_bar()\n\t\tshow_plain_page()', topic)
        self.assertIn('config["title_bar"] = own_title_bar() ? 1 : 0', DM)
        self.assertIn('return !plain_page && user && user.client && user.client.is_preference_enabled(/datum/client_preference/tgui_title_bar)', DM)
        # Only these windows keep a page of their own, or end in the game's own dialog or list.
        pages, endings = set(), set()
        for path in (ROOT / 'code').rglob('*.dm'):
            source = path.read_text(errors='replace')
            pages.update(re.findall(r'(?m)^/datum/nanoui/tgui/(?!proc/)([\w/]+)/has_plain_page\(\)', source))
            endings.update(re.findall(r'(?m)^/datum/nanoui/tgui/(?!proc/)([\w/]+)/show_plain_page\(\)', source))
        self.assertEqual(pages, {'snapshot', 'paper_editor'})
        self.assertEqual(endings, {'prompt', 'crafting_window', 'storage_window'})
        client = (ROOT / 'code/modules/client/client_procs.dm').read_text(errors='replace')
        self.assertIn('#define REAL_MIN_CLIENT_VERSION 516', client)
        self.assertNotIn('UI/templates', client)
        index = (ROOT / 'tgui/src/index.tsx').read_text()
        self.assertNotRegex(index, r'(?i)classic')

    def test_reopening_and_close_invalidate_generation(self):
        self.assertEqual(DM.count('render_generation++'), 3)
        self.assertGreaterEqual(DM.count('frontend_ready = FALSE'), 3)
        self.assertGreaterEqual(DM.count('frontend_acknowledged = FALSE'), 3)

    def test_ack_is_owner_and_generation_guarded_and_requires_ready(self):
        topic = DM.split('/datum/nanoui/tgui/Topic', 1)[1]
        ack = topic.index('message_type == "ack"')
        for guard in ('usr != user', 'href_list["window_id"] != window_id', 'href_list["generation"] != "[render_generation]"', 'status == STATUS_CLOSE'):
            self.assertLess(topic.index(guard), ack)
        self.assertIn('if (frontend_ready)\n\t\t\tfrontend_acknowledged = TRUE', topic)

    def test_transfer_invalidates_before_client_link_and_reopens_after_key_assignment(self):
        manager = (ROOT / 'code/modules/nano/nanomanager.dm').read_text()
        transfer = manager.split('/datum/nanomanager/proc/user_transferred', 1)[1]
        self.assertIn('for (var/datum/nanoui/ui in oldMob.open_uis.Copy())', transfer)
        self.assertLess(transfer.index('ui.user = newMob'), transfer.index('modern_ui.prepare_user_transfer(oldMob.client)'))
        self.assertIn('if (istype(ui, /datum/nanoui/tgui))', transfer)
        prepare = DM.split('/datum/nanoui/tgui/proc/prepare_user_transfer', 1)[1].split('/datum/nanoui/tgui/proc/complete_user_transfer', 1)[0]
        self.assertLess(prepare.index('render_generation++'), prepare.index('if (plain_page)'))
        self.assertNotIn('open()', prepare)
        self.assertIn('expected_client = pending_transfer_client', prepare)
        complete = DM.split('/datum/nanoui/tgui/proc/complete_user_transfer', 1)[1].split('/datum/nanoui/tgui/proc/show_plain_page', 1)[0]
        for guard in ('user != linked_user', '!state || !src_object', 'user.client != pending_transfer_client', 'pending_transfer_client.mob != user'):
            self.assertLess(complete.index(guard), complete.index('open()'))
        self.assertIn('ui.user == newMob', manager)
        mind = (ROOT / 'code/datums/mind.dm').read_text().split('/datum/mind/proc/transfer_to', 1)[1]
        self.assertLess(mind.index('user_transferred('), mind.index('new_character.key = key'))
        self.assertLess(mind.index('new_character.key = key'), mind.index('user_transfer_completed(new_character)'))

    def test_modern_adapter_is_default_for_converted_producers(self):
        self.assertIn('var/plain_page = FALSE', DM)

    def test_direct_tgui_templates_adopted(self):
        templates = set()
        for path in (ROOT / 'code').rglob('*.dm'):
            source = path.read_text(errors='replace')
            templates.update(re.findall(r'new /datum/nanoui/tgui(?:/\w+)*\((?:user, src|reader, src|viewer, src|viewer, reference), ui_key, "([^"]+)"', source))
            templates.update(re.findall(r'open_tgui\(user, ui_key, "([^"]+)"', source))
            templates.update(re.findall(r'(?m)^\t+(?:var/)?template = "([^"]+\.tmpl)"', source))
            self.assertNotRegex(source, r'ui = new\(user, src, ui_key, "[^"\n]+\.tmpl"')
        self.assertEqual(templates, {'appearance_changer.tmpl', 'book_reader.tmpl', 'character_flavor.tmpl', 'character_notes.tmpl', 'character_setup.tmpl', 'chem_disp.tmpl', 'computer.tmpl', 'crafting_atlas.tmpl', 'crafting_window.tmpl', 'crew_log.tmpl', 'faction_creation.tmpl', 'faction_list.tmpl', 'faction_symbol.tmpl', 'haircut.tmpl', 'known_languages.tmpl', 'panel.tmpl', 'photo_viewer.tmpl', 'recruitment_station.tmpl', 'religion_list.tmpl', 'research_bench.tmpl', 'research_book.tmpl', 'ship_stocks.tmpl', 'spawn_menu.tmpl', 'storage_window.tmpl', 'tech_tree.tmpl', 'vending_machine.tmpl', 'vending_machine2.tmpl', 'vending_machine_gulag.tmpl', 'vending_machine_taotd.tmpl', 'warehouse_book.tmpl', 'wiremod_circuit.tmpl'})

    def test_plain_owners_open_through_one_helper(self):
        helper = DM.split('/datum/proc/open_tgui(', 1)[1].split('\n/', 1)[0]
        self.assertLess(helper.index('GLOB.nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)'), helper.index('new /datum/nanoui/tgui('))
        self.assertLess(helper.index('ui.use_on_close_logic(FALSE)'), helper.index('ui.open()'))
        self.assertLess(helper.index('ui.set_initial_data(data)'), helper.index('ui.open()'))
        self.assertIn('_state = state ? state : default_state', helper)
        # Plain windows no longer build the adapter by hand or call NanoUI layout setup.
        for path in (ROOT / 'code').rglob('*.dm'):
            source = path.read_text(errors='replace')
            self.assertNotRegex(source, r'ui\.(set_layout_key|add_stylesheet|add_script)\(', path.name)
            if path.name not in ('tgui.dm', 'voyage.dm'):
                self.assertNotIn('new /datum/nanoui/tgui(', source, path.name)

    def test_modern_windows_skip_the_classic_asset_send(self):
        # The classic NanoUI scripts, styles and images are megabytes the modern screen never loads.
        base = (ROOT / "code/modules/nano/_nanoui.dm").read_text(errors='replace')
        self.assertIn("\tsend_base_assets(ntemplate_filename)\n", base)
        self.assertEqual(base.count("get_asset_datum(/datum/asset/nanoui)"), 1)
        self.assertIn("/datum/nanoui/tgui/send_base_assets(template_filename)\n\treturn\n", DM)
        self.assertIn("get_asset_datum(/datum/asset/simple/civ13_tgui)", DM)

    def test_unchanged_automatic_refreshes_are_not_resent(self):
        push = DM.split('/datum/nanoui/tgui/push_data(', 1)[1].split('\n/datum', 1)[0]
        self.assertIn('if (digest == last_sent && !force_push && !reply_owed)\n\t\treturn', push)
        self.assertLess(push.index('last_sent = digest'), push.index('user << output('))
        # A reopened page starts clean, and a press is owed an answer even when nothing changed.
        opening = DM.split('/datum/nanoui/tgui/open()', 1)[1].split('\n/datum', 1)[0]
        self.assertIn('last_sent = null', opening)
        topic = DM.split('/datum/nanoui/tgui/Topic(', 1)[1].split('\n/datum', 1)[0]
        self.assertLess(topic.index('reply_owed = TRUE'), topic.index('act_typed(action, params)'))
        # The ready push stays forced.
        self.assertIn('push_data(status == STATUS_DISABLED ? null : latest_data, TRUE)', topic)

    def test_recovery_without_bootstrap_and_close_ownership(self):
        self.assertIn("document.getElementById('tgui-loading').textContent=", DM)
        external = (ROOT / "code/modules/nano/nanoexternal.dm").read_text()
        self.assertIn("istype(ui, /datum/nanoui/tgui) && ui.user != mob", external)
        self.assertNotIn('"manage"', DM)

    def test_recruitment_actions_reach_the_existing_topic(self):
        # React click tests alone missed this bug: act() was called correctly,
        # but the shared DM transport rejected every recruitment action.
        source = (ROOT / 'code/game/mob/groups/recruitment_station.dm').read_text()
        frontend = (ROOT / 'tgui/src/interfaces/RecruitmentStation.tsx').read_text()
        topic = source.split('/datum/recruitment_panel/Topic', 1)[1]
        expected = {'designate', 'unbind', 'apply', 'withdraw', 'confirm',
                    'approve', 'reject', 'revoke', 'set_mode', 'set_open',
                    'set_language', 'set_skill', 'set_nonmatch', 'refresh'}
        allowed = declared('code/game/mob/groups/recruitment_station.dm', 'datum/recruitment_panel')
        self.assertEqual(allowed, expected)
        # Both local station and remote application review use this producer.
        self.assertIn('station ? "Recruitment Station" : "Recruitment Applications"', source)
        self.assertEqual(set(re.findall(r'href_list\["([^"\n]+)"\]', topic)), expected)
        self.assertEqual(set(re.findall(r'action="([^"\n]+)"', frontend)), expected - {'refresh'})

    def test_recruitment_permission_checks_remain_at_dispatch(self):
        source = (ROOT / 'code/game/mob/groups/recruitment_station.dm').read_text()
        topic = source.split('/datum/recruitment_panel/Topic', 1)[1]
        self.assertLess(topic.index('!still_valid(H)'), topic.index('href_list["designate"]'))
        for guard in ('map.is_faction_leader(H, own)', 'map.can_recruit_for_faction(H, faction)',
                      '!station.valid_for_recruitment()', 'station.faction != faction'):
            self.assertIn(guard, topic)
        # The common transport still admits only one action and its own scalar
        # payload. The existing owner/generation test covers forged windows.
        transport = DM.split('/datum/nanoui/tgui/Topic', 1)[1]
        self.assertIn('var/list/keys = list("value")', transport)
        self.assertIn('!(key in keys)', transport)
        self.assertNotIn('if ("designate")', transport)

    def test_research_actions_reach_their_topics(self):
        # Every button on the bench screen and the book window must pass the
        # transport allowlist and have a branch in the Topic that receives it.
        owners = {'research_bench.tmpl': ('code/modules/research_tree/research_bench.dm', 'obj/structure/research_bench'),
                  'research_book.tmpl': ('code/modules/research_tree/book_interface.dm', 'obj/item/weapon/book')}
        def allowed(template):
            return declared(*owners[template])
        def buttons(*names):
            found = set()
            for name in names:
                source = (ROOT / 'tgui/src/interfaces' / name).read_text()
                found |= set(re.findall(r'action="([^"\n]+)"', source))
                found |= set(re.findall(r"ui\.act\('([^'\n]+)'", source))
            return found
        bench = (ROOT / 'code/modules/research_tree/research_bench.dm').read_text().split('/obj/structure/research_bench/Topic', 1)[1].split('/obj/structure/research_bench/proc/write_research_item', 1)[0]
        handled = set(re.findall(r'href_list\["([^"\n]+)"\]', bench))
        self.assertEqual(allowed('research_bench.tmpl'), handled)
        self.assertLessEqual(buttons('Research.tsx'), handled)
        book_mode = bench.split('if (book_mode())', 1)[1].split('if (!H.civilization', 1)[0]
        for action in ('assign', 'take_book', 'swap_books', 'study', 'copy', 'copy_all', 'write', 'queue', 'unqueue', 'clear_queue', 'stop_research'):
            self.assertIn('href_list["%s"]' % action, book_mode)
        self.assertLess(bench.index('in_range(src, usr)'), bench.index('if (book_mode())'))
        book = (ROOT / 'code/modules/research_tree/book_interface.dm').read_text().split('/obj/item/weapon/book/Topic', 1)[1].split('/obj/item/weapon/book/AltClick', 1)[0]
        self.assertEqual(allowed('research_book.tmpl'), set(re.findall(r'href_list\["([^"\n]+)"\]', book)))
        self.assertEqual(buttons('ResearchBook.tsx'), allowed('research_book.tmpl'))
        self.assertLess(book.index('research_book_state.can_use_topic(src, H) != STATUS_INTERACTIVE'), book.index('study_research_source('))

    def test_crafting_window_actions_reach_its_topic(self):
        # The same transport allowlist that once swallowed recruitment actions.
        source = (ROOT / 'code/game/objects/items/stacks/crafting_window.dm').read_text()
        frontend = (ROOT / 'tgui/src/interfaces/CraftingWindow.tsx').read_text()
        topic = source.split('/datum/crafting_window/Topic', 1)[1]
        allowed = declared('code/game/objects/items/stacks/crafting_window.dm', 'datum/crafting_window')
        self.assertEqual(allowed, {'make', 'makeable_only', 'images', 'atlas', 'pin', 'source', 'detail', 'process_atlas', 'tech_tree'})
        self.assertEqual(set(re.findall(r'href_list\["([^"\n]+)"\]', topic)), allowed | {'quantity', 'options'})
        self.assertEqual(set(re.findall(r"ui\.act\('([^'\n]+)'", frontend)), allowed)
        transport = DM.split('/datum/nanoui/tgui/Topic', 1)[1]
        self.assertEqual(declared_fields('code/game/objects/items/stacks/crafting_window.dm', 'datum/crafting_window'), {'make': ['quantity', 'options']})
        self.assertIn('var/list/fields = allowed_fields(action)\n\tif (islist(fields))\n\t\tkeys += fields', transport)

    def test_crafting_window_processing_rows_are_read_only_atlas_routes(self):
        source = (ROOT / 'code/game/objects/items/stacks/crafting_window_processing.dm').read_text()
        topic = (ROOT / 'code/game/objects/items/stacks/crafting_window.dm').read_text().split('/datum/crafting_window/Topic', 1)[1]
        # Rows come from the Atlas acquisition routes; the link opens only a page the server listed.
        self.assertIn('catalog["acquisition"]', source)
        branch = topic.split('if (href_list["process_atlas"])', 1)[1].split('if (href_list["source"])', 1)[0]
        self.assertIn('processing_links["[href_list["process_atlas"]]"]', branch)
        self.assertIn('resource_exists(page)', branch)
        for action in ('.use(', 'new ', 'qdel(', 'attackby(', 'produce_recipe('):
            self.assertNotIn(action, source)

    def test_crafting_window_requests_keep_server_admission(self):
        source = (ROOT / 'code/game/objects/items/stacks/crafting_window.dm').read_text()
        topic = source.split('/datum/crafting_window/Topic', 1)[1]
        make = topic.split('if (href_list["make"])', 1)[1]
        # Held, conscious and unrestrained before any branch; then the row id,
        # the batch limit and the busy lock before the unchanged craft proc.
        self.assertLess(topic.index('!still_valid(H) || H.stat || H.restrained()'), topic.index('href_list["makeable_only"]'))
        for earlier, later in (('working || !H.can_build_recipe', 'find_recipe('), ('find_recipe(', 'batch_limit(R)'),
                               ('quantity > limit', 'H.can_build_recipe = FALSE'), ('H.can_build_recipe = FALSE', 'S.produce_recipe(R, quantity, H, options)'),
                               ('S.produce_recipe(R, quantity, H, options)', 'H.can_build_recipe = TRUE')):
            self.assertLess(make.index(earlier), make.index(later), (earlier, later))
        valid = source.split('/datum/crafting_window/proc/still_valid', 1)[1].split('/datum/topic_state', 1)[0]
        self.assertIn('source.loc == H && H.get_active_hand() == source', valid)
        finder = source.split('/datum/crafting_window/proc/find_recipe', 1)[1].split('/datum/crafting_window/proc/batch_limit', 1)[0]
        self.assertIn('crafting_window_row_id(R, sublist, index) != id', finder)
        # The window never pays, builds or edits recipe lists itself.
        for action in ('.use(', 'new R.result_type', 'recipes.Cut(', 'recipes.Remove(', 'qdel('):
            self.assertNotIn(action, source)
        self.assertEqual(source.count('produce_recipe('), 3)  # two comments and the one call

    def test_crafting_window_pins_and_purposes_only_mark_rows(self):
        source = (ROOT / 'code/game/objects/items/stacks/crafting_window.dm').read_text()
        topic = source.split('/datum/crafting_window/Topic', 1)[1]
        pin = topic.split('if (href_list["pin"])', 1)[1].split('if (href_list["make"])', 1)[0]
        # A pin names a row the same way a craft does, is capped, and never reaches the craft proc.
        self.assertLess(pin.index('find_recipe(href_list["pin"])'), pin.index('pinned += pin_key'))
        self.assertIn('pinned.len < CRAFTING_WINDOW_PIN_LIMIT', pin)
        self.assertNotIn('produce_recipe', pin)
        saving = (ROOT / 'code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm').read_text()
        self.assertIn('"craft_pinned"', saving)
        # Every purpose a rule names is a tab the window can show, and most
        # recipes land somewhere better than Other.
        rules = json.loads((ROOT / 'config/crafting_purposes.json').read_text())
        order = rules['order']
        self.assertEqual(order[-1], 'Other')
        self.assertEqual(len(order), len(set(order)))
        named = set(rules['categories'].values()) | {rule[1] for rule in rules['types']}
        self.assertLessEqual(named, set(order))
        self.assertTrue(all(key == key.strip().lower() for key in rules['categories']))
        def purpose(path, category):
            category = category.strip().lower()
            if category in rules['categories']:
                return rules['categories'][category]
            return next((name for prefix, name in rules['types'] if path == prefix or path.startswith(prefix + '/')), 'Other')
        found = [purpose(fields[2], fields[7]) for fields in (line.split(',') for line in
                 (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8', errors='replace').splitlines()
                 if line.startswith('RECIPE')) if len(fields) > 7]
        self.assertGreater(len(found), 1500)
        self.assertLess(found.count('Other') / len(found), 0.10)
        self.assertIn('file2text("config/crafting_purposes.json")', source)

    def test_crafting_window_reach_mode_only_uses_materials_the_server_sees(self):
        source = (ROOT / 'code/game/objects/items/stacks/crafting_window.dm').read_text()
        valid = source.split('/datum/crafting_window/proc/still_valid', 1)[1].split('/mob/living/human/proc/crafting_stacks_within_reach', 1)[0]
        self.assertLess(valid.index('if (reach)'), valid.index('source.crafting_stack_accessible(H)'))
        topic = source.split('/datum/crafting_window/Topic', 1)[1]
        switch = topic.split('if (href_list["source"])', 1)[1].split('if (href_list["pin"])', 1)[0]
        # A switch is refused mid-craft and outside reach mode, and the named
        # stack must be one the server finds next to the player right now.
        self.assertLess(switch.index('!reach || working'), switch.index('locate(href_list["source"])'))
        self.assertIn('picked in H.crafting_stacks_within_reach()', switch)
        shown = source.split('/obj/item/stack/proc/crafting_window_shown', 1)[1].split('/datum/crafting_window/ui_interact', 1)[0]
        self.assertIn('reach ? !crafting_stack_accessible(H) : (loc != H || H.get_active_hand() != src)', shown)

    def test_atlas_hand_off_opens_the_window_and_makes_nothing(self):
        source = (ROOT / 'code/game/objects/items/stacks/crafting_window.dm').read_text()
        hand_off = source.split('/proc/crafting_window_from_atlas(mob/viewer, product)', 1)[1].split('// Where a material is', 1)[0]
        # A working human only, a real type path, and only materials the server finds in reach.
        self.assertLess(hand_off.index('!istype(H) || !H.client || H.stat || H.restrained()'), hand_off.index('text2path('))
        self.assertLess(hand_off.index('ispath(wanted, /atom)'), hand_off.index('H.crafting_stacks_within_reach()'))
        self.assertIn('near.crafting_window_shown(H, TRUE, row)', hand_off)
        for action in ('produce_recipe', '.use(', 'put_in_hands', 'new wanted'):
            self.assertNotIn(action, hand_off)
        core = (ROOT / 'code/game/mob/crafting_atlas.dm').read_text()
        adapter = (ROOT / 'code/game/mob/crafting_atlas_tgui.dm').read_text()
        # The standalone Atlas fixture compiles without the Crafting window: only the adapter names it.
        self.assertNotIn('crafting_window', core)
        self.assertIn('crafting_atlas_presenter.craft(viewer, copytext("[href_list["atlas_craft"]]", 1, 257), state)', core)
        craft = adapter.split('/datum/crafting_atlas_presenter/tgui/craft(mob/viewer, product, state)', 1)[1].split('\n/', 1)[0]
        for guard in ('ui.user != viewer', 'ui.state != state', 'ui.plain_page', '!ui.frontend_ready', '!ui.frontend_acknowledged', 'resource_exists(product)'):
            self.assertLess(craft.index(guard), craft.index('crafting_window_from_atlas(viewer, product)'))
        atlas = (ROOT / 'tgui/src/interfaces/CraftingAtlas.tsx').read_text()
        self.assertIn("ui.act('atlas_craft', { value: craftable })", atlas)

    def test_crafting_window_details_read_only_and_choices_stay_declared(self):
        source = (ROOT / 'code/game/objects/items/stacks/crafting_window.dm').read_text()
        detail = source.split('/datum/crafting_window/proc/detail_for(id)', 1)[1].split('/datum/crafting_window/proc/given_options', 1)[0]
        # Looking closely uses the shared read-only hooks and names a row the same way a craft does.
        self.assertLess(detail.index('find_recipe(id)'), detail.index('craft_recipe_requirements(viewer, R)'))
        self.assertIn('craft_product_for(R)', detail)
        for action in ('player_input', 'WWinput', 'craft_product_options', 'craft_product_answer'):
            self.assertNotIn(action, source)
        given = source.split('/datum/crafting_window/proc/given_options(datum/stack_recipe/R, raw)', 1)[1].split('\n/', 1)[0]
        # Only fields the product declares, bounded text only; the craft code validates each answer.
        self.assertLess(given.index('length(raw) > 4096'), given.index('json_decode(raw)'))
        self.assertIn('for (var/list/prompt in P.prompts)', given)
        self.assertIn('istext(value) && length(value) <= 1024', given)
        self.assertNotIn('for (var/key in sent)', given)
        products = (ROOT / 'code/game/objects/items/stacks/craft_products.dm').read_text()
        answer = products.split('/proc/craft_product_answer(', 1)[1].split('\n/proc/', 1)[0]
        for check in ('if (!(answer in companies))', 'hex.Find(answer)', 'sanitize(copytext('):
            self.assertIn(check, answer)
        topic = source.split('/datum/crafting_window/Topic', 1)[1]
        look = topic.split('if (href_list["detail"])', 1)[1].split('if (href_list["make"])', 1)[0]
        self.assertNotIn('refresh()', look)
        self.assertIn('push_cached()', look)

    def test_anvil_window_routes_crafts_back_through_the_anvil(self):
        window = (ROOT / 'code/game/objects/structures/blacksmithing/anvil_window.dm').read_text()
        smith = (ROOT / 'code/game/objects/structures/blacksmithing/blacksmithing.dm').read_text()
        topic = window.split('/datum/crafting_window/anvil/Topic(', 1)[1].split('/obj/structure/anvil/proc/anvil_window_shown', 1)[0]
        make = topic.split('if (href_list["make"])', 1)[1]
        # A request names a row offered right now, is refused mid-craft, and is
        # worked by attackby() so the anvil's own admission checks run again.
        self.assertLess(make.index('working || anvil.in_use'), make.index('offered_name(href_list["make"])'))
        self.assertLess(make.index('offered_name(href_list["make"])'), make.index('A.attackby(S, H)'))
        self.assertLess(make.index('pending = wanted'), make.index('A.attackby(S, H)'))
        self.assertNotIn('forge_stack_recipe', topic)
        self.assertNotIn('amount -=', window)
        self.assertNotIn('new ', topic)
        shown = window.split('/obj/structure/anvil/proc/anvil_window_shown', 1)[1]
        picked = shown.split('if (!H.client', 1)[0]
        # The pending row is consumed once and checked against the offered rows again.
        self.assertLess(picked.index('W.pending = null'), picked.index('wanted in stack_offers(P, H)'))
        self.assertLess(picked.index('wanted in stack_offers(P, H)'), picked.index('forge_stack_recipe(P, H, H, R[2], metal[1], metal[2], "[wanted] - ")'))
        self.assertIn('!H.client || H.client.crafting_window_classic || H.client.modern_ui_failed', shown)
        # The window hook sits after the anvil's admission prefix and material check.
        attack = smith.split('/obj/structure/anvil/attackby(', 1)[1]
        self.assertLess(attack.index("You can't use this material on this anvil."), attack.index('else if (anvil_window_shown(P, H))'))
        self.assertLess(attack.index('else if (anvil_window_shown(P, H))'), attack.index('/////////IRON//////////'))
        # One category table serves the menus and the window.
        self.assertEqual(smith.count('var/list/optlist = stack_categories(P, H)'), 4)
        # The window and the item menu admit rows through the same filter.
        self.assertIn('(R[2] in kinds) && anvil_recipe_offered(R, R[2], R[metal[1]], metal[2])', window)
        self.assertIn('anvil_recipe_offered(anvil_recipes[i], choice, anvil_recipes[i][material_index], material_name)', smith)
        valid = window.split('/datum/crafting_window/anvil/still_valid(', 1)[1].split('/datum/crafting_window/anvil/load_recipes', 1)[0]
        self.assertIn('source.loc == H && H.get_active_hand() == source && isturf(H.loc) && in_range(anvil, H)', valid)
        base = (ROOT / 'code/game/objects/items/stacks/crafting_window.dm').read_text()
        fallback = base.split('/datum/nanoui/tgui/crafting_window/show_plain_page()', 1)[1].split('/obj/item/stack/proc/crafting_window_shown', 1)[0]
        self.assertLess(fallback.index('crafting_window_classic = TRUE'), fallback.index('A.attackby(S, H)'))
        self.assertIn('W.type != /datum/crafting_window', base)

    def test_crafting_window_falls_back_to_the_classic_list(self):
        source = (ROOT / 'code/game/objects/items/stacks/crafting_window.dm').read_text()
        fallback = source.split('/datum/nanoui/tgui/crafting_window/show_plain_page()', 1)[1].split('/obj/item/stack/proc/crafting_window_shown', 1)[0]
        self.assertLess(fallback.index('crafting_window_classic = TRUE'), fallback.index('S.list_recipes(H)'))
        shown = source.split('/obj/item/stack/proc/crafting_window_shown', 1)[1].split('/datum/crafting_window/ui_interact', 1)[0]
        self.assertIn('!H.client || H.client.crafting_window_classic || H.client.modern_ui_failed', shown)
        stack = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text()
        menu = stack.split('/obj/item/stack/proc/list_recipes(', 1)[1].split('// Custom qdel', 1)[0]
        self.assertLess(menu.index('if (crafting_window_shown(user))'), menu.index('user.set_using_object(src)'))
        self.assertIn("<title>Crafting</title>", menu)

    def test_windows_declare_their_own_actions(self):
        # The transport asks the window's owner; it holds no per-window table,
        # so a new window cannot forget to register its buttons somewhere else.
        self.assertIn('/datum/proc/ui_actions(ui_key)\n\treturn list()', DM)
        self.assertIn('/datum/proc/ui_action_fields(ui_key, action)\n\treturn null', DM)
        self.assertIn('return src_object ? src_object.ui_actions(ui_key) : list()', DM)
        self.assertIn('return src_object ? src_object.ui_action_fields(ui_key, action) : null', DM)
        self.assertNotIn('.tmpl")', DM.split('/datum/nanoui/tgui/push_data', 1)[1])
        owners = {
            'chem_disp.tmpl': ('code/modules/reagents/Chemistry-Machinery.dm', 'obj/structure/chemical_dispenser'),
            'appearance_changer.tmpl': ('code/modules/nano/modules/appearance_changer.dm', 'datum/nano_module/appearance_changer'),
            'vending_machine.tmpl': ('code/game/objects/structures/vending/vending.dm', 'obj/structure/vending'),
            'vending_machine2.tmpl': ('code/game/objects/structures/vending/vending_sales.dm', 'obj/structure/vending/sales'),
            'faction_symbol.tmpl': ('code/game/mob/groups/faction_symbol.dm', 'datum/nano_module/faction_symbol_editor'),
            'faction_creation.tmpl': ('code/game/mob/groups/faction_creation.dm', 'datum/nano_module/faction_creation'),
        }
        for template, (path, owner) in owners.items():
            actions = declared(path, owner)
            self.assertTrue(actions, template)
        for path, owner in (owners['faction_symbol.tmpl'], owners['faction_creation.tmpl']):
            fields = declared_fields(path, owner)
            self.assertEqual(fields, {'paint': ['x', 'y'], 'stroke': ['cells', 'stroke_continue']})
            self.assertLessEqual(set(fields), declared(path, owner))
        self.assertEqual(declared(*owners['vending_machine.tmpl']) ^ declared(*owners['vending_machine2.tmpl']), {'remove_coin', 'remove_money'})
        # A book's reader window shares the object but sends nothing.
        book = (ROOT / 'code/modules/research_tree/book_interface.dm').read_text()
        self.assertIn('/obj/item/weapon/book/ui_actions(ui_key)\n\tif (ui_key == "research_book")', book)

    def test_assets_registered(self):
        assets = (ROOT / 'code/modules/client/asset_cache.dm').read_text()
        for name in ('civ13-tgui-bootstrap.js', 'civ13-tgui.js', 'civ13-tgui.css'):
            self.assertIn(f"'UI/tgui/{name}'", assets)
        # Sent under content-versioned names so a reconnect to an updated
        # world cannot reuse the browser's remembered copy of the old bundle.
        self.assertIn('assets[civ13_tgui_versioned_name(name, civ13_tgui_assets_version)] = sources[name]', assets)
        self.assertIn('digests += "[md5(sources[name])]"', assets)


if __name__ == '__main__':
    unittest.main()
