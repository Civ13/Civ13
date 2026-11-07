"""Execute complete oil-well ownership helpers with fake locations/reagents.

These offline projections prove source control flow, not native save/load. The
sibling probe.dm exercises production objects and the disk-backed serializer.
"""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('oilwell_projection', ROOT / 'tests/save_movement/source_adapter.py')
vm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vm)
vm.FIELDS += ('work_barrel', 'base', 'recover_barrel', 'load_barrel', 'unload_barrel',
              'start_extraction', 'stop_extraction', 'extracting_now', 'extraction_due')
PRODUCTION = vm.read('code/modules/1713/production.dm')
CHEMISTRY = vm.read('code/modules/1713/factory_chemistry.dm')
PIPES = vm.read('code/modules/1713/factory_pipes.dm')
BARREL = '/obj/item/weapon/reagent_containers/glass/barrel'


class Contents(list):
    def Copy(self):
        return Contents(self)


class Atom:
    def __init__(self, loc=None):
        self.contents = Contents()
        self._loc = None
        self.loc = loc

    @property
    def loc(self):
        return self._loc

    @loc.setter
    def loc(self, target):
        if self._loc is not None:
            self._loc.contents.remove(self)
        self._loc = target
        if target is not None:
            target.contents.append(self)

    def __iter__(self):
        return iter(self.contents)


class Turf(Atom):
    pass


class Reagents:
    def __init__(self, volume=0):
        self.total_volume = volume
        self.maximum_volume = 250
        self.composition = {'petroleum': volume}

    def get_free_space(self):
        return self.maximum_volume - self.total_volume


class Barrel(Atom):
    def __init__(self, loc, volume=0):
        super().__init__(loc)
        self.reagents = Reagents(volume)


def turf(atom):
    while atom is not None and not isinstance(atom, Turf):
        atom = atom.loc
    return atom


def parent_destroy(atom):
    # Model the destructive parent boundary: anything not released is lost.
    for item in atom.contents.Copy():
        item.loc = None
    atom.loc = None


class Well(Atom):
    def __init__(self, loc, source=PRODUCTION):
        super().__init__(loc)
        self.work_barrel = None
        self.base = None
        self.extracting_now = False
        self.extraction_due = 0
        env = {'typed_iter': lambda items, path: [item for item in items if path == BARREL and isinstance(item, Barrel)],
               'get_turf': turf, 'parent_destroy': parent_destroy}
        for name, args in [('recover_barrel', 'src'), ('load_barrel', 'src, load_floor_barrel=True'),
                           ('unload_barrel', 'src'), ('stop_extraction', 'src')]:
            projected = vm.project(source, '/obj/structure/oilwell/proc/' + name, args, env, method=True)
            setattr(self, name, projected.__get__(self))
        projected = vm.project(source.replace('. = ..()', '. = parent_destroy(src)'),
                               '/obj/structure/oilwell/Destroy', 'src', env, method=True)
        self.destroy = projected.__get__(self)

    def start_extraction(self):
        # Extraction timing is deliberately outside this ownership projection.
        self.extracting_now = bool(self.work_barrel and self.work_barrel.reagents
                                   and self.work_barrel.reagents.get_free_space() > 0)


class OilWellBarrelRecovery(unittest.TestCase):
    def setUp(self):
        self.floor = Turf()
        self.well = Well(self.floor)

    def test_restore_full_empty_and_part_filled_originals(self):
        for volume in (0, 17, 250):
            with self.subTest(volume=volume):
                barrel = Barrel(self.well, volume)
                holder = barrel.reagents
                self.well.load_barrel(False)
                self.assertIs(self.well.work_barrel, barrel)
                self.assertIs(barrel.reagents, holder)
                self.assertEqual(holder.total_volume, volume)
                self.well.unload_barrel()
                self.assertIs(barrel.loc, self.floor)

    def test_four_orphans_are_removed_once_each_without_replacements(self):
        originals = [Barrel(self.well, volume) for volume in (250, 0, 17, 250)]
        holders = [barrel.reagents for barrel in originals]
        for barrel in originals:
            self.assertIs(self.well.recover_barrel(), barrel)
            self.well.unload_barrel()
        self.assertEqual(self.floor.contents, [self.well] + originals)
        self.assertFalse(self.well.contents)
        self.assertEqual([barrel.reagents for barrel in originals], holders)

    def test_destroy_with_and_without_link_returns_all_originals(self):
        for linked in (False, True):
            with self.subTest(linked=linked):
                well = Well(self.floor)
                originals = [Barrel(well, volume) for volume in (250, 0, 17, 250)]
                if linked:
                    well.work_barrel = originals[2]
                well.destroy()
                self.assertTrue(all(barrel.loc is self.floor for barrel in originals))
                self.assertEqual([b.reagents.total_volume for b in originals], [250, 0, 17, 250])
                self.assertIsNone(well.work_barrel)

    def test_stale_link_does_not_reclaim_a_moved_barrel(self):
        moved = Barrel(Turf(), 23)
        other_floor = moved.loc
        actual = Barrel(self.well, 250)
        self.well.work_barrel = moved
        self.assertIs(self.well.recover_barrel(), actual)
        self.well.destroy()
        self.assertIs(moved.loc, other_floor)
        self.assertIs(actual.loc, self.floor)

    def test_deleted_barrel_is_not_resurrected(self):
        deleted = Barrel(None, 250)
        self.well.work_barrel = deleted
        self.well.unload_barrel()
        self.assertIsNone(deleted.loc)
        self.assertIsNone(self.well.work_barrel)

    def test_missing_reagents_do_not_hide_a_physical_barrel(self):
        barrel = Barrel(self.well)
        barrel.reagents = None
        self.well.unload_barrel()
        self.assertIs(barrel.loc, self.floor)

    def test_recovery_never_claims_unrelated_floor_barrels(self):
        spare = Barrel(self.floor)
        self.well.load_barrel(False)
        self.assertIsNone(self.well.work_barrel)
        full = Barrel(self.well, 250)
        self.well.load_barrel()
        self.assertIs(self.well.work_barrel, full)
        self.assertIs(spare.loc, self.floor)

    def test_floor_loading_still_requires_capacity(self):
        full = Barrel(self.floor, 250)
        empty = Barrel(self.floor)
        self.well.load_barrel()
        self.assertIs(self.well.work_barrel, empty)
        self.assertIs(full.loc, self.floor)

    def test_manual_and_automation_entries_recover_before_occupancy_checks(self):
        for source, name in [(PRODUCTION, 'attackby'), (PRODUCTION, 'attack_hand'),
                             (CHEMISTRY, 'factory_accepts'), (CHEMISTRY, 'factory_offer'),
                             (CHEMISTRY, 'factory_take'), (PIPES, 'fluid_supply_holder')]:
            with self.subTest(name=name):
                body = vm.extract(source, '/obj/structure/oilwell/' + name)
                self.assertLess(body.index('load_barrel(FALSE)'), body.index('work_barrel'))
        body = vm.extract(PRODUCTION, '/obj/structure/oilwell/attackby')
        after_wait = body[body.index('if (do_after(user, 35, src))'):]
        self.assertLess(after_wait.index('load_barrel(FALSE)'), after_wait.index('work_barrel ||'))

    def test_save_hooks_rebuild_only_runtime_link_from_contents(self):
        after = vm.extract(PRODUCTION, '/obj/structure/oilwell/after_load')
        self.assertIn('link_to_spring()', after)
        link = vm.extract(PRODUCTION, '/obj/structure/oilwell/proc/link_to_spring')
        self.assertIn('load_barrel(load_floor_barrel)', link)
        saved = vm.extract(PRODUCTION, '/obj/structure/oilwell/get_saved_vars')
        self.assertIn('"work_barrel"', saved)
        before = vm.extract(PRODUCTION, '/obj/structure/oilwell/before_save')
        self.assertNotIn('unload_barrel', before)

    def test_old_capacity_filter_is_detected(self):
        changed = PRODUCTION.replace('if (contained.loc == src)\n\t\t\twork_barrel',
            'if (contained.loc == src && contained.reagents && contained.reagents.get_free_space() > 0)\n\t\t\twork_barrel', 1)
        self.assertNotEqual(changed, PRODUCTION)
        well = Well(self.floor, changed)
        original = Barrel(well, 250)
        well.load_barrel(False)
        self.assertIsNot(well.work_barrel, original)

    def test_old_single_barrel_destroy_is_detected(self):
        start = PRODUCTION.index('\t// Older saves can contain several barrels')
        end = PRODUCTION.index('\tbase = null', start)
        well = Well(self.floor, PRODUCTION[:start] + PRODUCTION[end:])
        originals = [Barrel(well, 250) for _ in range(4)]
        well.destroy()
        self.assertEqual(sum(barrel.loc is self.floor for barrel in originals), 1)


if __name__ == '__main__':
    unittest.main()
