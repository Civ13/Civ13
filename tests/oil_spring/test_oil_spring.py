"""Replay petroleum spring filling and fire refills from source, not BYOND."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/oil_fires.dm'

# Pre-fix code, frozen as negative controls.
OLD_FILL = '''		var/obj/item/weapon/reagent_containers/RG = O
		if (istype(RG) && RG.is_open_container() && do_after(user, 15, src, check_for_repeats = FALSE))
			if (counter > 0)
				RG.reagents.add_reagent("petroleum", min(RG.volume - RG.reagents.total_volume, 10))
				counter--
'''
OLD_FIRE = '''	for (var/obj/structure/oil_spring/OS in src.loc)
		if (OS.counter > 0)
			OS.oil_explode()
			OS.counter = 0

//burn floors
'''


def fill_block(source):
    start = source.index('var/obj/item/weapon/reagent_containers/RG = O')
    return source[start:source.index('counter--', start)]


def fill(source, free, capacity=250):
    """Fill a container with `free` units of room; return (petroleum added, charges used)."""
    block = fill_block(source)
    volume, total = capacity, capacity - free
    # Guards that return before the transfer when the container has no room.
    for cond in re.findall(r'if \((.*)\)\n\t+(?:to_chat\(.*\)\n\t+)?return', block):
        if 'total_volume >= RG.volume' in cond and total >= volume:
            return 0, 0
        if 'free <= 0' in cond and volume - total <= 0:
            return 0, 0
    amount = min(volume - total, 10)
    return max(amount, 0), 1


def fire_block(source):
    start = source.index('for (var/obj/structure/oil_spring/OS in src.loc)')
    return source[start:source.index('//burn floors', start)]


class OilSpringTest(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_full_container_keeps_the_charge(self):
        self.assertEqual(fill(self.source, 0), (0, 0))

    def test_open_container_with_room_fills(self):
        self.assertEqual(fill(self.source, 250), (10, 1))
        self.assertEqual(fill(self.source, 4), (4, 1))

    def test_room_is_rechecked_after_the_delay(self):
        block = fill_block(self.source)
        after = block[block.index('do_after('):]
        self.assertIn('free <= 0', after)
        self.assertIn('min(free, 10)', after)

    def test_fire_schedules_the_refill(self):
        block = fire_block(self.source)
        guarded = block.split('if (OS.counter > 0)', 1)[1]
        for line in ('OS.timeout = world.time + 1800', 'OS.update_icon()', 'OS.refill()'):
            self.assertIn(line, guarded)

    def test_refill_is_guarded_against_duplicates(self):
        refill = self.source[self.source.index('/obj/structure/oil_spring/proc/refill()'):]
        self.assertIn('if (refill_pending', refill.split('\n/', 1)[0])

    def test_negative_controls(self):
        self.assertEqual(fill(OLD_FILL, 0), (0, 1))
        self.assertNotIn('refill()', fire_block(OLD_FIRE))


if __name__ == '__main__':
    unittest.main()
