"""Project outhouse admission and release with fake movement, not a BYOND world."""
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'save_movement'))
import source_adapter

SOURCE = (ROOT / 'code/game/objects/structures/watercloset.dm').read_text(encoding='utf-8')


class Place:
    def __init__(self):
        self.members = []

    def __iter__(self):
        # BYOND iteration tolerates moved members; snapshot the fake boundary.
        return iter(self.members[:])


class Mob:
    def __init__(self, place, size=20, buckled=False, pinned=False):
        self.loc = place
        place.members.append(self)
        self.mob_size = size
        self.buckled = buckled
        self.pinned = SimpleNamespace(len=int(pinned))
        self.client = None

    def forceMove(self, destination):
        self.loc.members.remove(self)
        self.loc = destination
        destination.members.append(self)


def machine(source=SOURCE):
    # Project the ordinary door branch; the separate cistern retrieval branch
    # is outside this fixture. Refuse unexpected changes to the branch boundary.
    boundary = '\tif (cistern && open)\n'
    start = source.index('/obj/structure/toilet/outhouse/attack_hand(')
    end = source.index(boundary, start)
    next_proc = source.index('\n/obj/structure/toilet/outhouse/AltClick', end)
    door_source = source[:end] + source[next_proc:]
    env = {'typed_iter': lambda place, kind: iter(place), 'EYE_PERSPECTIVE': 1,
           'MOB_PERSPECTIVE': 0}
    fields = source_adapter.FIELDS
    try:
        source_adapter.FIELDS += ('open', 'cistern', 'density', 'icon_state_open',
                                  'icon_state_closed', 'stored_units', 'storage_capacity',
                                  'store_mobs', 'dump_contents')
        store = source_adapter.project(source, '/obj/structure/toilet/outhouse/proc/store_mobs',
                                       'src, stored_units', env, method=True)
        dump = source_adapter.project(source, '/obj/structure/toilet/outhouse/proc/dump_contents',
                                      'src', env, method=True)
        attack = source_adapter.project(door_source, '/obj/structure/toilet/outhouse/attack_hand',
                                        'src, user', env, method=True)
    finally:
        source_adapter.FIELDS = fields
    turf, house = Place(), Place()
    house.loc = turf
    house.open, house.cistern, house.density = True, False, False
    house.icon_state_open, house.icon_state_closed = 'open', 'closed'
    house.stored_units, house.storage_capacity = 0, 20
    house.store_mobs = lambda count=0: store(house, count)
    house.dump_contents = lambda: dump(house)
    return turf, house, lambda: attack(house, None)


class OuthouseOccupancyTests(unittest.TestCase):
    def test_capacity_release_and_reclose(self):
        turf, house, toggle = machine()
        first, second = Mob(turf), Mob(turf)
        toggle()
        self.assertEqual(house.members, [first])
        self.assertEqual((house.stored_units, house.density), (20, True))
        toggle()
        self.assertEqual(house.members, [])
        self.assertEqual(house.stored_units, 0)
        self.assertCountEqual(turf.members, [first, second])
        toggle()
        self.assertEqual(len(house.members), 1)
        self.assertEqual(house.stored_units, 20)

    def test_unavailable_occupants_are_skipped(self):
        turf, house, toggle = machine()
        buckled, pinned, free = Mob(turf, buckled=True), Mob(turf, pinned=True), Mob(turf)
        toggle()
        self.assertEqual(house.members, [free])
        self.assertEqual(turf.members, [buckled, pinned])

    def test_stale_count_is_recomputed_from_existing_occupants(self):
        turf, house, toggle = machine()
        house.stored_units = 20
        incoming = Mob(turf)
        toggle()
        self.assertEqual(house.members, [incoming])
        self.assertEqual(house.stored_units, 20)

        turf, house, toggle = machine()
        existing, incoming = Mob(house), Mob(turf)
        house.stored_units = 0
        toggle()
        self.assertEqual(house.members, [existing])
        self.assertEqual(turf.members, [incoming])
        self.assertEqual(house.stored_units, 20)

    def test_old_double_admission_and_missing_reset_are_detected(self):
        old = SOURCE.replace('\t\t\tstored_units += store_mobs(stored_units)',
                             '\t\t\tstore_mobs()\n\t\t\tstored_units += store_mobs(stored_units)', 1)
        self.assertNotEqual(old, SOURCE)
        turf, house, toggle = machine(old)
        Mob(turf); Mob(turf)
        toggle()
        self.assertEqual(len(house.members), 2)
        no_reset = SOURCE.replace('\tstored_units = 0\n\n/obj/structure/toilet/outhouse/male',
                                  '\n/obj/structure/toilet/outhouse/male', 1)
        self.assertNotEqual(no_reset, SOURCE)
        turf, house, toggle = machine(no_reset)
        Mob(turf)
        toggle(); toggle()
        self.assertEqual(house.stored_units, 20)


if __name__ == '__main__':
    unittest.main()
