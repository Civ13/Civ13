"""Project cage restore and water-entry decisions; no BYOND server is run."""
import importlib.util
import re
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/structures/sea.dm'
spec = importlib.util.spec_from_file_location('dm_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
ENTRY = '/turf/floor/Entered'
RESTORE = '/obj/structure/fishing_cage/after_load'
POLICY = '/obj/structure/fishing_cage/persistence_runtime_var'
WATER = '/turf/floor/beach/water'
CAGE = '/obj/structure/fishing_cage'
BUOY = '/obj/structure/buoy'


def project_entry(source, constructing=False):
    body = adapter.extract(source, ENTRY).replace('..()', 'parent()')
    body = body.replace('var/obj/structure/fishing_cage/FC = O', 'FC = O')
    for path in (WATER, CAGE, BUOY):
        body = body.replace(path, repr(path))
    env = {'parent': lambda: None, 'istype': lambda value, kind: kind in value.kinds,
           'persistence_saved_atom_construction': constructing}
    return adapter.project(ENTRY + '(atom/movable/O)\n' + body + '\n', ENTRY, 'src,O', env)


def project_restore(source):
    body = adapter.extract(source, RESTORE).replace('..()', 'parent()')
    body = body.replace(WATER, repr(WATER))
    for field in ('generating', 'found', 'loc', 'update_icon', 'generate_fish'):
        body = re.sub(r'(?<![\w.])' + field + r'\b', 'src.' + field, body)
    env = {'parent': lambda: None, 'istype': lambda value, kind: kind in value.kinds}
    return adapter.project(RESTORE + '()\n' + body + '\n', RESTORE, 'src', env)


def project_policy(source):
    source = source.replace('..()', 'parent(key)')
    return adapter.project(source, POLICY, 'src,key', {'parent': lambda key: key == 'appearance'})


class Cage:
    kinds = {CAGE}

    def __init__(self, loc, found=None, restoring=False):
        self.loc, self.found, self.restoring = loc, found, restoring
        self.generating = False
        self.timers = 0
        self.icons = 0

    def update_icon(self):
        self.icons += 1

    def generate_fish(self):
        if not self.generating:
            self.generating = True
            self.found = None
            self.timers += 1


class CageRestoreTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')
        self.water = SimpleNamespace(kinds={WATER})
        self.land = SimpleNamespace(kinds=set())

    def test_runtime_policy_filters_new_and_legacy_timer_state(self):
        policy = project_policy(self.source)
        self.assertTrue(policy(None, 'generating'))
        self.assertTrue(policy(None, 'appearance'))
        self.assertFalse(policy(None, 'found'))
        loading = (ROOT / 'code/modules/persistence/loading.dm').read_text(encoding='utf-8')
        body = adapter.extract(loading, '/map_storage/proc/load_entry_fields')
        self.assertLess(body.index('if(object.persistence_runtime_var(v))'), body.index('object.vars[v] ='))
        # Negative control: removing the exclusion saves and imports the old TRUE.
        old = self.source.replace('key == "generating" || ', '', 1)
        self.assertFalse(project_policy(old)(None, 'generating'))

    def test_entry_during_both_restore_phases_never_schedules(self):
        for constructing, restoring in ((True, False), (False, True), (True, True)):
            cage = Cage(self.water, restoring=restoring)
            project_entry(self.source, constructing)(self.water, cage)
            self.assertEqual(cage.timers, 0)
        # Each guard independently matters at its corresponding restore phase.
        for guard, constructing, restoring in (
            ('!persistence_saved_atom_construction && ', True, False),
            ('!FC.restoring && ', False, True),
        ):
            cage = Cage(self.water, restoring=restoring)
            project_entry(self.source.replace(guard, '', 1), constructing)(self.water, cage)
            self.assertEqual(cage.timers, 1)

    def test_empty_wet_restore_starts_one_timer_and_dry_waits_for_entry(self):
        for loc in (self.water, self.land):
            cage = Cage(loc, restoring=True)
            # A legacy TRUE is discarded by the import policy; after_load also resets it.
            cage.generating = True
            project_restore(self.source)(cage)
            self.assertEqual(cage.timers, int(loc is self.water))
            self.assertEqual(cage.generating, loc is self.water)
            cage.restoring = False
            cage.loc = self.water
            project_entry(self.source)(self.water, cage)
            self.assertEqual(cage.timers, 1)
            project_entry(self.source)(self.water, cage)
            self.assertEqual(cage.timers, 1)

    def test_stored_catch_survives_restore_and_entry(self):
        for loc in (self.water, self.land):
            cage = Cage(loc, found='fish type', restoring=True)
            cage.generating = True
            project_restore(self.source)(cage)
            cage.restoring = False
            project_entry(self.source)(self.water, cage)
            self.assertEqual(cage.found, 'fish type')
            self.assertFalse(cage.generating)
            self.assertEqual(cage.timers, 0)

    def test_fresh_entry_still_starts_generation(self):
        cage = Cage(self.water)
        project_entry(self.source)(self.water, cage)
        self.assertEqual(cage.timers, 1)
        self.assertTrue(cage.generating)


if __name__ == '__main__':
    unittest.main()
