"""Check the chemical dispenser's refill and loading branches, from source, not BYOND."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/reagents/Chemistry-Machinery.dm'
DECL = '/obj/structure/chemical_dispenser/attackby('

# The pre-fix proc, frozen as a negative control.
OLD_BODY = '''
	if (beaker)
		if (B && B.reagents && B.reagents.reagent_list.len)
			to_chat(user, "You transfer the reagents to the dispenser.")
			B.reagents.clear_reagents()
			sanitize_reagents()
			return
		else
			return
	if (istype(B, /obj/item/weapon/reagent_containers/glass) || istype(B, /obj/item/weapon/reagent_containers/food))
		if (!accept_glass && istype(B,/obj/item/weapon/reagent_containers/food))
			to_chat(user, "<span class='notice'>You should only use beakers to manage chemicals.</span>")
		beaker =  B
'''


def attackby_body(source):
    start = source.index(DECL)
    end = source.find('\n/', start + 1)
    return source[start:end]


def problems(body):
    found = []
    transfer = body.find('You transfer the reagents')
    lid = body.find('if (!B.is_open_container())')
    if lid == -1 or lid > transfer or 'return' not in body[lid:transfer]:
        found.append('a sealed container is emptied into the dispenser (#4749)')
    clear = body.find('B.reagents.clear_reagents()')
    refill_end = body.find('return', clear)
    if 'GLOB.nanomanager.update_uis(src)' not in body[clear:refill_end]:
        found.append('open windows are not refreshed after a refill (#4750)')
    warn = body.find('You should only use beakers')
    load = body.find('beaker =  B')
    if 'return' not in body[warn:load]:
        found.append('a rejected food container is still loaded (#4748)')
    return found


class ChemDispenserRefillTest(unittest.TestCase):
    def test_dispenser_branches(self):
        self.assertEqual(problems(attackby_body(SOURCE.read_text(encoding='utf-8'))), [])

    def test_negative_control_old_proc_fails_all_three(self):
        self.assertEqual(len(problems(OLD_BODY)), 3)


class AlcoholDistilleryTest(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8').split('/obj/structure/distillery/proc/process_machine()', 1)[1]

    def test_rechecks_current_collector_after_timed_wait(self):
        self.assertIn('spawn(150)\n\t\tfinish_distilling()', self.source)
        guard = self.source.index('if (QDELETED(collector) || collector.loc != src || !collector.reagents)')
        self.assertIn('active = FALSE\n\tupdate_icon()', self.source[:guard])
        self.assertIn('return FALSE', self.source[guard:self.source.index('var/ethanol_sum')])

    def test_complete_exact_entry_yield_must_fit_before_consumption(self):
        body = self.source.split('/obj/structure/distillery/proc/finish_distilling()', 1)[1]
        self.assertIn('ethanol_sum += r.volume * (1 - r.strength / 100)', body)
        self.assertNotIn('get_reagent_amount', body)
        guard = body.index('if (ethanol_sum > collector.reagents.get_free_space())')
        add = body.index('!collector.reagents.add_reagent("ethanol", ethanol_sum)')
        clear = body.index('reagents.clear_reagents()')
        self.assertLess(guard, add)
        self.assertLess(add, clear)
        self.assertIn('return FALSE', body[guard:add])
        self.assertIn('return FALSE', body[add:clear])


if __name__ == '__main__':
    unittest.main()
