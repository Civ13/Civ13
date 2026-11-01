"""Bounded source-contract checks. Not a DM execution or gameplay substitute."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
DM = (ROOT / 'code/modules/nano/tgui.dm').read_text()


class BackendContract(unittest.TestCase):
    def test_dm_include(self):
        self.assertIn('#include "code\\modules\\nano\\tgui.dm"', (ROOT / 'civ13.dme').read_text())

    def test_owner_and_generation_precede_dispatch(self):
        topic = DM.split('/datum/nanoui/tgui/Topic', 1)[1]
        dispatch = topic.index('return ..(list2params(params), params)')
        for guard in ('usr != user', '!src_object || !state', 'href_list["window_id"] != window_id',
                      'href_list["generation"] != "[render_generation]"', 'status != STATUS_INTERACTIVE', '!frontend_acknowledged',
                      '!(action in allowed_actions())', 'length(raw_payload) > 8192', 'params.len > 8',
                      '!(key in keys)', '!istext(params[key]) && !isnum(params[key])'):
            self.assertLess(topic.index(guard), dispatch)

    def test_status_only_updates_and_ready_snapshot(self):
        self.assertIn('if (!isnull(data))\n\t\tlatest_data = data', DM)
        self.assertIn('push_data(status == STATUS_DISABLED ? null : latest_data, TRUE)', DM)
        self.assertIn('if (!state || !frontend_ready', DM)

    def test_legacy_fallback_preserves_parent(self):
        self.assertIn('legacy_renderer = TRUE\n\tset_initial_data(latest_data)\n\topen()', DM)
        self.assertIn('if (legacy_renderer)\n\t\treturn ..()', DM)
        self.assertIn('if (href_list["type"])\n\t\t\treturn', DM)

    def test_reopening_and_close_invalidate_generation(self):
        self.assertEqual(DM.count('render_generation++'), 3)
        self.assertGreaterEqual(DM.count('frontend_ready = FALSE'), 3)
        self.assertGreaterEqual(DM.count('frontend_acknowledged = FALSE'), 3)

    def test_startup_watchdog_has_owner_client_generation_and_lifecycle_guards(self):
        opening = DM.split('/datum/nanoui/tgui/open()', 1)[1].split('/datum/nanoui/tgui/close()', 1)[0]
        self.assertLess(opening.index('. = ..()'), opening.index('spawn(200)'))
        timeout = opening.split('spawn(200)', 1)[1]
        for guard in ('legacy_renderer', 'frontend_acknowledged', 'render_generation != open_generation',
                      'user != open_user', '!user || user.client != open_client', '!src_object || !state'):
            self.assertLess(timeout.index(guard), timeout.index('use_legacy_renderer()'))
        fallback = DM.split('/datum/nanoui/tgui/proc/use_legacy_renderer()', 1)[1].split('/datum/nanoui/tgui/get_config_data()', 1)[0]
        self.assertLess(fallback.index('update_status(FALSE)'), fallback.index('legacy_renderer = TRUE'))
        self.assertIn('if (!state || status == STATUS_CLOSE)', fallback)

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
        self.assertLess(prepare.index('render_generation++'), prepare.index('if (legacy_renderer)'))
        self.assertNotIn('open()', prepare)
        self.assertIn('expected_client = pending_transfer_client', prepare)
        complete = DM.split('/datum/nanoui/tgui/proc/complete_user_transfer', 1)[1].split('/datum/nanoui/tgui/proc/use_legacy_renderer', 1)[0]
        for guard in ('user != linked_user', '!state || !src_object', 'user.client != pending_transfer_client', 'pending_transfer_client.mob != user'):
            self.assertLess(complete.index(guard), complete.index('open()'))
        self.assertIn('ui.user == newMob', manager)
        mind = (ROOT / 'code/datums/mind.dm').read_text().split('/datum/mind/proc/transfer_to', 1)[1]
        self.assertLess(mind.index('user_transferred('), mind.index('new_character.key = key'))
        self.assertLess(mind.index('new_character.key = key'), mind.index('user_transfer_completed(new_character)'))

    def test_modern_adapter_is_default_for_converted_producers(self):
        self.assertIn('var/legacy_renderer = FALSE', DM)

    def test_direct_tgui_templates_adopted(self):
        templates = set()
        for path in (ROOT / 'code').rglob('*.dm'):
            source = path.read_text(errors='replace')
            templates.update(re.findall(r'new /datum/nanoui/tgui(?:/\w+)*\(user, src, ui_key, "([^"]+)"', source))
            self.assertNotRegex(source, r'ui = new\(user, src, ui_key, "[^"\n]+\.tmpl"')
        self.assertEqual(templates, {'appearance_changer.tmpl', 'chem_disp.tmpl', 'faction_creation.tmpl', 'faction_symbol.tmpl', 'known_languages.tmpl', 'religion_list.tmpl', 'research_bench.tmpl', 'ship_stocks.tmpl', 'vending_machine.tmpl', 'vending_machine2.tmpl', 'vending_machine_gulag.tmpl', 'vending_machine_taotd.tmpl', 'warehouse_book.tmpl'})

    def test_recovery_without_bootstrap_and_close_ownership(self):
        self.assertIn('href="byond://?src=\\ref[src]&amp;window_id=', DM)
        self.assertIn('onerror="window.location.href=', DM)
        external = (ROOT / "code/modules/nano/nanoexternal.dm").read_text()
        self.assertIn("istype(ui, /datum/nanoui/tgui) && ui.user != mob", external)
        self.assertNotIn('"manage"', DM)

    def test_assets_registered(self):
        assets = (ROOT / 'code/modules/client/asset_cache.dm').read_text()
        for name in ('civ13-tgui-bootstrap.js', 'civ13-tgui.js', 'civ13-tgui.css'):
            self.assertIn(f"'UI/tgui/{name}'", assets)


if __name__ == '__main__':
    unittest.main()
