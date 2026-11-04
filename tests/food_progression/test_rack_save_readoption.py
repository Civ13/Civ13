"""Offline source contract: a live save must not strand rack items or their drawings."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
RACK = (ROOT / 'code/modules/1713/production.dm').read_text(encoding='utf-8')
FIXTURE = (ROOT / 'tests/food_progression/rack_save.dm').read_text(encoding='utf-8')


def section(start, end='\n/obj/'):
    return RACK.split(start, 1)[1].split(end, 1)[0]


class RackSaveReadoptionTests(unittest.TestCase):
    def test_successful_save_transfer_schedules_readoption(self):
        hook = section('/obj/structure/dehydrator/before_save_context(')
        commit = hook.index('save_storage.commit_save_transfer(ticket)')
        readopt = hook.index('readopt_after_save(save_storage)')
        self.assertLess(commit, readopt)
        self.assertLess(readopt, hook.index('catch'))
        wait = section('/obj/structure/dehydrator/proc/readopt_after_save(')
        for guard in ('persistence_save_in_progress', 'persistence_save_active()', 'saving_export_stack', 'SAVE_REPAIR_REQUIRED'):
            self.assertIn(guard, wait)
        self.assertIn('reinit()', wait)
        self.assertIn('while (!gcDestroyed && (persistence_save_in_progress', wait)

    def test_dropping_and_refilling_redraw_the_rack(self):
        self.assertIn('update_icon()', section('/obj/structure/dehydrator/before_save()'))
        refill = section('/obj/structure/dehydrator/proc/refill()')
        self.assertIn('for (var/obj/item/E in src.loc)', refill)
        self.assertIn('dehydrator_area_free(pos, sizeHV)', refill)
        self.assertIn('E.clear_dehydrator_marker()\n\t\t\t\tdisplaced += E', refill)
        self.assertIn('if (!(S in displaced))\n\t\t\tattackby(S, null)', refill)
        self.assertTrue(refill.rstrip().endswith('update_icon()'))
        hand = section('/obj/structure/dehydrator/attack_hand(')
        self.assertIn('else\n\t\tupdate_icon()', hand)

    def test_orphaned_items_are_repaired(self):
        repair = section('/obj/item/proc/clear_dehydrator_marker(')
        self.assertIn('name = copytext(name, 1, marker)', repair)
        self.assertIn('D.decay = original_decay', repair)
        self.assertIn('D.food_decay()', repair)
        for hook in ('/obj/item/pickup(mob/user)', '/obj/item/weapon/pickup(mob/user)',
                     '/obj/item/on_enter_storage(', '/obj/item/after_load()'):
            self.assertIn(hook, RACK)
        orphan = section('/obj/item/proc/dehydrator_marker_orphaned(')
        self.assertIn('istype(holder.master_item, /obj/structure/dehydrator)', orphan)
        self.assertIn('locate(/obj/structure/dehydrator) in loc', orphan)

    def test_native_fixture_covers_live_save_and_strays(self):
        for message in ('rack re-adopts its input after a live save',
                        'live save drops input and clears its drawing',
                        'picking up a stray rack item restores its name and decay',
                        'storing a stray rack item restores its name and decay'):
            self.assertIn(message, FIXTURE)


if __name__ == '__main__':
    unittest.main()
