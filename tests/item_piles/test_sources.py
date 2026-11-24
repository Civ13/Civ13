"""Source contract for choosing a nearby piled item via ordinary ClickOn."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
CLICK = (ROOT / 'code/_onclick/click.dm').read_text()
PILES = (ROOT / 'code/game/objects/items/item_piles.dm').read_text()
PAPER = (ROOT / 'code/game/objects/items/paper/paper.dm').read_text()


def proc(source, signature):
    return source.split(signature, 1)[1].split('\n/', 1)[0]


class ItemPileTargetingTest(unittest.TestCase):
    def test_selection_is_opt_in_and_uses_the_existing_click_pipeline(self):
        click = proc(CLICK, '/mob/proc/ClickOn(')
        self.assertLess(click.index('travel_hold_input(src)'), click.index('H.item_pile_choose(site, options)'))
        self.assertIn('modifiers["shift"] && modifiers["alt"] && !modifiers["ctrl"] && !modifiers["middle"] && !modifiers["right"]', click)
        selected = click.index('A = selected')
        self.assertLess(selected, click.index('params = "left=1"', selected))
        self.assertLess(selected, click.index('if (stat || paralysis || stunned || weakened)'))
        self.assertLess(selected, click.index('if (!canClick())'))
        self.assertLess(selected, click.index('if (A.Adjacent(src))'))
        self.assertIn('W.resolve_attackby(A, src, icon_x, icon_y)', click)
        self.assertIn('UnarmedAttack(A, TRUE, icon_x, icon_y)', click)

    def test_mixed_pile_only_lists_visible_direct_acquirable_items(self):
        eligible = proc(PILES, '/proc/item_pile_selectable(')
        for required in ('!QDELETED(I)', 'I.loc == site', 'I.alpha', 'I.invisibility <= H.see_invisible',
                         'I.pile_hidden && I.pile_opacity', 'I.Adjacent(H)',
                         '!is_type_in_list(I, H.shouldnt_see)', 'los_read_allowed(H, I, "click")'):
            self.assertIn(required, eligible)
        options = proc(PILES, '/proc/item_pile_options(')
        self.assertIn('for (var/obj/item/I in site)', options)
        self.assertIn('if (!item_pile_selectable(H, site, I, context, snapshot))', options)
        self.assertIn('options["[options.len + 1]. [display_name]"] = I', options)
        self.assertNotIn('I.contents', options)
        self.assertIn('++scanned > ITEM_PILE_PICK_LIMIT', options)
        self.assertEqual(options.count('current.capture(FALSE, site)'), 1)
        self.assertIn('context.decision_snapshot(I, snapshot, "click")', eligible)

    def test_prompt_result_rechecks_origin_intent_held_item_and_new_los(self):
        choose = proc(PILES, '/mob/living/human/proc/item_pile_choose(')
        self.assertIn('chooser.item_pile_prompt_open = TRUE', choose)
        resume = choose.split('var/label = player_input', 1)[1]
        for required in ('chooser.item_pile_prompt_open = FALSE', 'client != chooser', 'loc != origin',
                         'hand != original_hand', 'held != get_active_hand()', 'a_intent != original_intent',
                         '!item_pile_can_choose(site)', '!item_pile_selectable(src, site, selected)',
                         'travel_hold_refuses(src, selected)'):
            self.assertLess(resume.index(required), resume.index('return selected'))
        site_gate = proc(PILES, '/mob/living/human/proc/item_pile_can_choose(')
        for required in ('client.eye == src', 'z == site.z', 'site.Adjacent(src)', '!restrained()',
                         '!in_throw_mode', '!using_object', 'canClick()'):
            self.assertIn(required, site_gate)

    def test_paper_bundling_and_quantity_renames_keep_pile_state_current(self):
        join = proc(PAPER, '/obj/item/weapon/paper/attackby(')
        self.assertLess(join.index('pile_reveal()'), join.index('loc = B'))
        name_change = proc(PILES, '/obj/item/proc/loose_pile_update(')
        self.assertIn('if (new_name != name)', name_change)
        self.assertIn('if (isturf(loc))\n\t\t\titem_pile_mark(loc)', name_change)
        refresh = proc(PILES, '/proc/item_pile_refresh(')
        self.assertIn('I.pile_hide()', refresh)
        self.assertIn('I.pile_reveal()', refresh)


if __name__ == '__main__':
    unittest.main()
