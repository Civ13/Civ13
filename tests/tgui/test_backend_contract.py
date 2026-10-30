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
                      'href_list["generation"] != "[render_generation]"', 'status != STATUS_INTERACTIVE',
                      '!(action in allowed_actions())', 'length(raw_payload) > 8192', 'params.len > 8',
                      '!(key in keys)', '!istext(params[key]) && !isnum(params[key])'):
            self.assertLess(topic.index(guard), dispatch)

    def test_status_only_updates_and_ready_snapshot(self):
        self.assertIn('if (!isnull(data))\n\t\tlatest_data = data', DM)
        self.assertIn('push_data(status == STATUS_DISABLED ? null : latest_data, TRUE)', DM)
        self.assertIn('if (!state || !frontend_ready', DM)

    def test_legacy_fallback_preserves_parent(self):
        self.assertIn('legacy_renderer = TRUE\n\t\tset_initial_data(latest_data)\n\t\topen()', DM)
        self.assertIn('if (legacy_renderer)\n\t\treturn ..()', DM)
        self.assertIn('if (href_list["type"])\n\t\t\treturn', DM)

    def test_reopening_and_close_invalidate_generation(self):
        self.assertEqual(DM.count('render_generation++'), 2)
        self.assertGreaterEqual(DM.count('frontend_ready = FALSE'), 3)

    def test_all_ten_templates_adopted(self):
        templates = set()
        for path in (ROOT / 'code').rglob('*.dm'):
            source = path.read_text(errors='replace')
            templates.update(re.findall(r'new /datum/nanoui/tgui\(user, src, ui_key, "([^"]+)"', source))
            self.assertNotRegex(source, r'ui = new\(user, src, ui_key, "[^"\n]+\.tmpl"')
        self.assertEqual(templates, {'appearance_changer.tmpl', 'chem_disp.tmpl', 'faction_creation.tmpl',
                                    'faction_symbol.tmpl', 'research_bench.tmpl', 'warehouse_book.tmpl',
                                    'vending_machine.tmpl', 'vending_machine2.tmpl',
                                    'vending_machine_gulag.tmpl', 'vending_machine_taotd.tmpl'})

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
