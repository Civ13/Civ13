"""Ship Stocks source/lifecycle contracts; no DM/native execution."""
from pathlib import Path
import re
import unittest
import reader_base

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/map_metadata/voyage.dm').read_text(errors='replace')
BOOK = SOURCE.split('/obj/structure/voyage/quartermaster_book\n', 1)[1].split('/datum/topic_state/reader/ship_stocks/reader_allowed', 1)[0]
OPEN = BOOK.split('\tui_interact(', 1)[1].split('\tproc/tally_treasure()', 1)[0]
RULE = reader_base.rule(SOURCE, 'ship_stocks')


class ShipStocksContract(unittest.TestCase):
    def test_general_hold_and_galley_share_the_water_tally(self):
        tally = BOOK.split('\tproc/tally_food()\n', 1)[1].split('\tproc/tally_weapons()', 1)[0]
        area = '/area/caribbean/pirates/ship/voyage/lower/storage'
        self.assertIn(f'get_area_turfs({area})', tally)
        self.assertIn(f'galley = istype(storage, {area}/kitchen)', tally)
        self.assertIn(f'if (!galley && storage.type != {area})\n\t\t\t\tcontinue', tally)
        self.assertIn('tally_provisions(sel_turf, galley, tally)', tally)
        self.assertIn('for (var/obj/structure/closet/crate/S in sel_turf)\n'
                      '\t\t\t\ttally_provisions(S, galley, tally)', tally)
        self.assertIn('for (var/obj/structure/reagent_dispensers/largebarrel/L in sel_turf)\n'
                      '\t\t\t\ttally["water"] += tally_barrel_water(L.reagents)', tally)
        map_text = (ROOT / 'maps/special/voyage.dmm').read_text()
        self.assertRegex(map_text, rf'barrel/water,[^\n]+,{area}\)')

    def test_portable_and_fixed_barrels_share_a_water_only_filter(self):
        items = BOOK.split('\tproc/tally_provisions(', 1)[1].split('\tproc/tally_barrel_water(', 1)[0]
        self.assertIn('for (var/obj/item/weapon/reagent_containers/glass/barrel/B in container)\n'
                      '\t\t\ttally["water"] += tally_barrel_water(B.reagents)', items)
        self.assertNotIn('tally_provisions(', items)
        water = BOOK.split('\tproc/tally_barrel_water(', 1)[1].split('\tproc/tally_food()', 1)[0]
        self.assertIn('if (contents)', water)
        self.assertIn('if (istype(R, /datum/reagent/water))\n\t\t\t\t\ttotal += R.volume', water)

    def test_food_remains_galley_only_and_excludes_empty_drinkware(self):
        items = BOOK.split('\tproc/tally_provisions(', 1)[1].split('\tproc/tally_barrel_water(', 1)[0]
        self.assertIn('if (galley)\n\t\t\tfor (var/obj/item/weapon/reagent_containers/food/F in container)',
                      items)
        self.assertIn('if (!istype(F, /obj/item/weapon/reagent_containers/food/drinks) || '
                      'F.reagents?.total_volume > 0)\n\t\t\t\t\ttally["food"]++', items)

    def test_treasury_counts_loose_money_once_per_turf(self):
        treasury = BOOK.split('\tproc/tally_treasure()\n', 1)[1].split('\tproc/tally_materials()', 1)[0]
        chest = re.search(r'(?m)^(\t+)for\(var/obj/structure/closet/crate/chest/treasury/ship/S in sel_turf\)', treasury)
        loose = re.search(r'(?m)^(\t+)for\(var/obj/item/stack/money/M1 in (\w+(?:\.loc)?)\)', treasury)
        self.assertIsNotNone(chest)
        self.assertIsNotNone(loose)
        self.assertIn('for(var/obj/item/stack/money/M in S)\n\t\t\t\t\ttally += M.value*M.amount', treasury)
        self.assertIn('tally += M1.value*M1.amount', treasury)
        self.assertIn(loose.group(2), ('sel_turf', 'S.loc'))
        # Project loop nesting: chest contents count individually, loose coins
        # count once per turf, including turfs with no chest.
        for chest_values in ([], [7], [7, 11]):
            with self.subTest(chests=len(chest_values)):
                loose_repetitions = len(chest_values) if len(loose.group(1)) > len(chest.group(1)) else 1
                actual = sum(chest_values) + loose_repetitions * (3 * 5)
                self.assertEqual(actual, sum(chest_values) + 15)

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
        # The shared guard binds book, body and connection; this window adds the human rule.
        self.assertEqual(RULE, 'ishuman(user)')
        allowed = reader_base.allowed
        book, owner, other = object(), object(), object()
        self.assertTrue(allowed(book, book, owner, owner))
        self.assertFalse(allowed(book, other, owner, owner))
        self.assertFalse(allowed(book, book, other, owner))
        self.assertFalse(allowed(book, book, owner, owner, rule=False))
        self.assertFalse(allowed(book, book, owner, owner, connected=False))

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
        self.assertFalse((ROOT / 'UI/templates').exists())

    def test_uses_existing_manager_and_real_classic_template(self):
        self.assertIn('GLOB.nanomanager.try_update_ui(user, src, ui_key, null, data, TRUE)', OPEN)
        self.assertIn('var/datum/topic_state/reader/ship_stocks/reader_state = new(src, user)', OPEN)
        self.assertIn('"ship_stocks.tmpl", "Ship Stocks", 500, 520, _state = reader_state', OPEN)
        workflow = (ROOT / '.github/workflows/tgui.yml').read_text()
        self.assertIn("'code/game/objects/map_metadata/voyage.dm'", workflow)
        self.assertIn("'UI/js/libraries/doT.js'", workflow)


if __name__ == '__main__':
    unittest.main()
