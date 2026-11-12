"""Offline model of manual biofuel feed against the shared capacity (native probe: probe.dm)."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/modern_items.dm'

# Pre-fix olive oil branch, frozen as a negative control.
OLD = '''			if (C.reagents.has_reagent("olive_oil",1))
				var/barrelamt = C.reagents.get_reagent_amount("olive_oil")
				if (barrelamt < (maxvolume-volume_di))
					C.reagents.remove_reagent("olive_oil",barrelamt)
'''


def helper(source):
    start = source.index('/obj/structure/refinery/biofuel/proc/pour_feed(')
    return source[start:source.index('\n/', start + 1)]


def pour(source, et, di, donor, maxvolume=300, yield_=1.0, ethanol=False):
    """Return (volume_et, volume_di, donor_left) for one manual pour."""
    if 'pour_feed(H, C, "olive_oil"' not in source:
        # Old path: room ignores the other counter, donor is fully debited.
        room = maxvolume - di
        taken = donor if donor < room else room
        di = min(di + taken, maxvolume - et)
        return et, di, donor - taken
    body = helper(source)
    assert 'var/free = maxvolume - volume_et - volume_di' in body
    assert 'min(barrelamt, free/yield)' in body
    free = maxvolume - et - di
    if free <= 0 or yield_ <= 0:
        return et, di, donor
    poured = min(donor, free / yield_)
    if ethanol:
        et = min(et + poured * yield_, maxvolume - di)
    else:
        di = min(di + poured, maxvolume - et)
    return et, di, donor - poured


class BiofuelFeedTest(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_oil_fills_only_shared_space(self):
        self.assertEqual(pour(self.source, 290, 0, 20), (290, 10, 10))

    def test_ethanol_keeps_stored_oil(self):
        et, di, left = pour(self.source, 0, 290, 20, yield_=0.5, ethanol=True)
        self.assertEqual((et, di, left), (10, 290, 0))

    def test_zero_yield_ethanol_is_refused(self):
        self.assertEqual(pour(self.source, 0, 0, 20, yield_=0, ethanol=True), (0, 0, 20))
        self.assertIn('if (yield <= 0)', helper(self.source))

    def test_negative_control_old_branch_loses_donor_oil(self):
        self.assertEqual(pour(OLD, 290, 0, 20), (290, 10, 0))


if __name__ == '__main__':
    unittest.main()
