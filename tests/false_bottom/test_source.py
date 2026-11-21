"""Offline source contract for false bottoms (hidden compartments in containers); does not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
TEXT = (ROOT / 'code/modules/storage_window/false_bottom.dm').read_text(encoding='utf-8')
STORAGE = (ROOT / 'code/game/objects/items/weapons/storage/storage.dm').read_text(encoding='utf-8')
WINDOW = (ROOT / 'code/modules/storage_window/storage_window.dm').read_text(encoding='utf-8')
TRAVEL = (ROOT / 'code/modules/persistence/region_travel_gear.dm').read_text(encoding='utf-8')


def body(text, header):
    return text.split(header, 1)[1].split('\n/', 1)[0]


class FalseBottomSource(unittest.TestCase):
    def test_included(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\storage_window\\false_bottom.dm"', dme)

    def test_compartment_is_never_an_item(self):
        # Every "for (var/obj/item/I in contents)" loop (search, strip, empty,
        # capacity) must pass over it, so it can't be an /obj/item.
        self.assertIn('\n/obj/false_bottom\n', TEXT)
        self.assertNotIn('/obj/item/false_bottom', TEXT)
        decl = body(TEXT, '\n/obj/false_bottom\n')
        self.assertIn('invisibility = 101', decl)
        self.assertIn('mouse_opacity = 0', decl)

    def test_storage_grid_and_counts_skip_it(self):
        self.assertIn('var/adjusted_contents = shown_contents_count()', STORAGE)
        self.assertIn('shown_contents_count() >= storage_slots', STORAGE)
        self.assertEqual(STORAGE.count('if (istype(O, /obj/false_bottom))\n'), 2)
        self.assertIn('G["total"] = S.shown_contents_count()', WINDOW)

    def test_only_knowers_use_it_and_search_needs_the_container_in_hand(self):
        use = body(TEXT, '/mob/living/human/verb/use_hidden_compartment()')
        self.assertIn('false_bottom_knows(F, src)', use)
        self.assertLess(use.index('false_bottom_knows(F, src)'), use.index('player_input('))
        search = body(TEXT, '/mob/living/human/verb/search_thoroughly()')
        self.assertIn('false_bottom_held_container()', search)
        self.assertIn('do_after(src, FALSE_BOTTOM_SEARCH_TIME, S)', search)
        self.assertIn('F.known_by |= ckey', search)

    def test_fitting_needs_an_empty_container_and_a_plank(self):
        fit = body(TEXT, '/mob/living/human/verb/fit_false_bottom()')
        self.assertIn('S.shown_contents_count()', fit)
        self.assertIn('W.use(1)', fit)
        self.assertLess(fit.index('do_after('), fit.index('W.use(1)'))

    def test_small_things_only(self):
        use = body(TEXT, '/mob/living/human/verb/use_hidden_compartment()')
        self.assertIn('I.w_class > FALSE_BOTTOM_MAX_W_CLASS', use)
        self.assertIn('F.contents.len >= FALSE_BOTTOM_ITEMS', use)

    def test_ward_hook_defaults_to_visible(self):
        hook = body(TEXT, '/atom/movable/proc/hidden_from_wards()')
        self.assertIn('return FALSE', hook)

    def test_region_travel_drops_empty_compartment_and_blocks_full_one(self):
        blockers = body(TRAVEL, '/proc/region_travel_bag_blockers(')
        self.assertIn('istype(A, /obj/false_bottom) && !length(A.contents)', blockers)
        self.assertIn('B.shown_contents_count() > REGION_TRAVEL_BAG_ITEMS_MAX', TRAVEL)


if __name__ == '__main__':
    unittest.main()
