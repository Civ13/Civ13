"""Ship Stocks source/lifecycle contracts; no DM/native execution."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/map_metadata/voyage.dm').read_text(errors='replace')
BOOK = SOURCE.split('/obj/structure/voyage/quartermaster_book\n', 1)[1].split('/datum/topic_state/ship_stocks\n', 1)[0]
OPEN = BOOK.split('\tui_interact(', 1)[1].split('\tproc/tally_treasure()', 1)[0]
STATE = SOURCE.split('/datum/topic_state/ship_stocks/can_use_topic', 1)[1].split('/obj/structure/voyage/sextant', 1)[0]


class ShipStocksContract(unittest.TestCase):
    def test_new_snapshot_requires_local_human_interaction_before_any_tally(self):
        tally = OPEN.index('tally_materials()')
        self.assertLess(OPEN.index('!ishuman(user) || !user.client'), tally)
        self.assertLess(OPEN.index('default_state.can_use_topic(src, user) != STATUS_INTERACTIVE'), tally)
        self.assertNotIn('original_job_title', OPEN)
        self.assertNotIn('Pirate Quartermaster', OPEN)

    def test_manager_refresh_preserves_snapshot_without_repeating_tallies(self):
        branch = OPEN.split('if (ui)\n\t\t\tui.push_data(null, TRUE)', 1)[1]
        self.assertTrue(branch.startswith('\n\t\t\treturn'))
        self.assertLess(OPEN.index('ui.push_data(null, TRUE)'), OPEN.index('tally_materials()'))
        self.assertNotIn('set_auto_update', OPEN)
        self.assertNotIn('spawn(', OPEN)

    def test_all_ten_original_resources_have_the_original_units_and_numeric_sources(self):
        rows = re.findall(r'list\("label" = "([^"]+)", "amount" = ([^,\n]+), "unit" = "([^"]+)"\)', OPEN)
        self.assertEqual(rows, [
            ('Treasury', 'tally_treasure()', 'reales'), ('Wood', 'mats["wood"]', 'logs'),
            ('Cloth', 'mats["cloth"]', 'sheets'), ('Rope', 'mats["rope"]', 'coils'),
            ('Food', 'food["food"]', 'doses'), ('Water', 'food["water"]', 'units'),
            ('Cannon Ammo', 'wep["cannonballs"]', 'balls'), ('Musket Ammo', 'wep["musket"]', 'projectiles'),
            ('Pistol Ammo', 'wep["pistol"]', 'projectiles'), ('Blunderbuss Ammo', 'wep["blunderbuss"]', 'projectiles'),
        ])

    def test_projected_state_denies_wrong_book_body_type_and_logout(self):
        # Evaluate the actual production guard with synthetic values. This is a
        # source projection, not evidence of native client ownership or transfer.
        guard = re.search(r'if \((.+)\)\n\t\treturn STATUS_CLOSE', STATE).group(1)
        expression = guard.replace('!ishuman(user)', 'not human').replace('!user.client', 'not connected').replace('||', 'or')
        def allowed(source, book, user, reader, human=True, connected=True):
            return not eval(expression, {'__builtins__': {}}, dict(src_object=source, book=book, user=user, reader=reader, human=human, connected=connected))
        book, owner, other = object(), object(), object()
        self.assertTrue(allowed(book, book, owner, owner))
        self.assertFalse(allowed(other, book, owner, owner))
        self.assertFalse(allowed(book, book, other, owner))
        self.assertFalse(allowed(book, book, owner, owner, human=False))
        self.assertFalse(allowed(book, book, owner, owner, connected=False))
        self.assertIn('return STATUS_UPDATE', STATE)
        self.assertNotIn('STATUS_INTERACTIVE', STATE)
        self.assertNotIn('get_dist', STATE)  # Opened snapshot remains readable while walking.

    def test_read_only_in_both_protocols_and_no_machine_close_side_effect(self):
        self.assertNotIn('set_using_object', BOOK)
        self.assertNotIn('unset_using_object', BOOK)
        self.assertIn('ui.use_on_close_logic(FALSE)', OPEN, 'Reader close must preserve unrelated machine interactions')
        self.assertIn('ui.open()', OPEN)
        self.assertLess(OPEN.index('ui.use_on_close_logic(FALSE)'), OPEN.index('ui.open()'))
        transport = (ROOT / 'code/modules/nano/tgui.dm').read_text()
        self.assertIn('/datum/nanoui/tgui/Topic', transport)
        self.assertNotIn('ship_stocks.tmpl', transport.split('/datum/nanoui/tgui/Topic', 1)[0])
        legacy_source = (ROOT / 'code/modules/nano/_nanoui.dm').read_text()
        self.assertIn('/datum/nanoui/Topic', legacy_source)
        legacy = legacy_source.split('/datum/nanoui/Topic', 1)[1]
        self.assertIn('status != STATUS_INTERACTIVE', legacy)
        self.assertIn('src_object.Topic', legacy)
        self.assertLess(legacy.index('status != STATUS_INTERACTIVE'), legacy.index('src_object.Topic'))
        template = (ROOT / 'UI/templates/ship_stocks.tmpl').read_text()
        self.assertNotIn('href=', template)
        self.assertNotIn('<input', template)

    def test_uses_existing_manager_and_real_classic_template(self):
        self.assertIn('GLOB.nanomanager.try_update_ui(user, src, ui_key, null, data, TRUE)', OPEN)
        self.assertIn('var/datum/topic_state/ship_stocks/reader_state = new(src, user)', OPEN)
        self.assertIn('"ship_stocks.tmpl", "Ship Stocks", 500, 520, _state = reader_state', OPEN)
        workflow = (ROOT / '.github/workflows/tgui.yml').read_text()
        self.assertIn("'code/game/objects/map_metadata/voyage.dm'", workflow)
        self.assertIn("'UI/js/libraries/doT.js'", workflow)


if __name__ == '__main__':
    unittest.main()
