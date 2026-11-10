"""Offline source checks for riding vehicles under free movement.

The native acceptance is ride.py (headless full game, all four directions).
These checks keep the three pieces of the fix in place: seats settle a rider
squarely on its tile, a motorcycle never hits its own rider, and every
vehicle (not only carriages) leases one glide to its riders.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
BUCKLING = ROOT / 'code/game/objects/buckling.dm'
TRANSPORT = ROOT / 'code/game/objects/structures/transports.dm'


def proc(source, path):
    start = source.index(path + '(')
    end = source.find('\n/', start + 1)
    return source[start:end if end != -1 else None]


class RidingSources(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.b = BUCKLING.read_text()
        cls.t = TRANSPORT.read_text()

    def test_settle_clears_offset_and_ownership(self):
        body = proc(self.b, '/mob/living/proc/settle_on_tile')
        for line in ('step_x = 0', 'step_y = 0', 'H.human_subtile_offset_owned = FALSE', 'A.npc_subtile_offset_owned = FALSE'):
            self.assertIn(line, body)

    def test_buckling_settles_before_seating(self):
        body = proc(self.b, '/obj/proc/buckle_mob')
        self.assertLess(body.index('M.settle_on_tile()'), body.index('M.buckled = src'))
        self.assertLess(body.index('(M.loc != loc)'), body.index('M.settle_on_tile()'))

    def test_every_boarding_move_settles(self):
        # Passengers are not always buckled, so each mob boarding move settles too.
        lines = self.t.split('\n')
        settles = [i for i, line in enumerate(lines) if line.strip() == 'M.settle_on_tile()']
        self.assertEqual(len(settles), 6)
        for i in settles:
            self.assertEqual(lines[i - 1].strip(), 'M.forceMove(get_turf(src))', f'line {i + 1}')

    def test_motorcycle_never_hits_its_own_riders(self):
        body = proc(self.t, '/obj/structure/vehicle/motorcycle/do_vehicle_check')
        loop = body.index('for (var/mob/living/L in T)')
        skip = body.index('if (L == driver || (L in ontop))', loop)
        self.assertLess(skip, body.index('HH.adjustBruteLoss', loop))
        self.assertEqual(body[skip:].split('\n')[1].strip(), 'continue')

    def test_all_vehicles_lease_rider_glide(self):
        body = proc(self.t, '/obj/structure/vehicle/proc/do_move')
        self.assertLess(body.index('claim_ride_glides(m_dir, interval)'), body.index('ML.forceMove('))
        claim = proc(self.t, '/obj/structure/vehicle/proc/claim_ride_glides')
        self.assertIn('for (var/mob/living/M in ontop)\n\t\t\tlease.claim(M, interval, m_dir, destination)', claim)
        self.assertIn('/obj/structure/vehicle\n\tvar/tmp/datum/carriage_glide_lease/carriage_glide', self.t)
        self.assertIn('/obj/structure/vehicle/persistence_runtime_var(key)', self.t)

    def test_omission_controls(self):
        for before, after in (('if (L == driver || (L in ontop))', 'if (FALSE)'),):
            mutated = self.t.replace(before, after)
            with self.assertRaises((AssertionError, ValueError)):
                body = proc(mutated, '/obj/structure/vehicle/motorcycle/do_vehicle_check')
                body.index('if (L == driver || (L in ontop))')
        mutated = self.b.replace('\tM.settle_on_tile()\n', '')
        with self.assertRaises(ValueError):
            proc(mutated, '/obj/proc/buckle_mob').index('M.settle_on_tile()')


if __name__ == '__main__':
    unittest.main()
