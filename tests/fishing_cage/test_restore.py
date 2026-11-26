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
EXIT = '/turf/floor/beach/water/Exited'
FINISH = '/obj/structure/fishing_cage/proc/finish_fishing_soak'
CANCEL = '/obj/structure/fishing_cage/proc/cancel_fishing_soak'
RESTORE = '/obj/structure/fishing_cage/after_load'
POLICY = '/obj/structure/fishing_cage/persistence_runtime_var'
WATER = '/turf/floor/beach/water'
CAGE = '/obj/structure/fishing_cage'
BUOY = '/obj/structure/buoy'
OBJ = '/obj'


def project_entry(source, constructing=False, parent=lambda: None, checks=None):
    body = adapter.extract(source, ENTRY).replace('..()', 'parent()')
    body = body.replace('var/obj/structure/fishing_cage/FC = O', 'FC = O')
    for path in (WATER, CAGE, BUOY):
        body = body.replace(path, repr(path))
    def istype(value, kind):
        if checks is not None:
            checks.append(kind)
        return kind in getattr(value, 'kinds', ())

    env = {'parent': parent, 'istype': istype, 'isobj': lambda value: istype(value, OBJ),
           'persistence_saved_atom_construction': constructing}
    return adapter.project(ENTRY + '(atom/movable/O)\n' + body + '\n', ENTRY, 'src,O', env)


def project_restore(source):
    body = adapter.extract(source, RESTORE).replace('..()', 'parent()')
    body = body.replace(WATER, repr(WATER))
    for field in ('generating', 'found', 'loc', 'update_icon', 'generate_fish', 'cancel_fishing_soak'):
        body = re.sub(r'(?<![\w.])' + field + r'\b', 'src.' + field, body)
    env = {'parent': lambda: None, 'istype': lambda value, kind: kind in value.kinds}
    return adapter.project(RESTORE + '()\n' + body + '\n', RESTORE, 'src', env)


def project_exit(source):
    body = adapter.extract(source, EXIT).replace('..()', 'parent()')
    body = body.replace(CAGE + ')', repr(CAGE) + ')').replace('var/obj/structure/fishing_cage/FC = O', 'FC = O')
    env = {'parent': lambda: None, 'istype': lambda value, kind: kind in getattr(value, 'kinds', ())}
    return adapter.project(EXIT + '(atom/movable/O, atom/new_loc)\n' + body + '\n', EXIT, 'src,O,new_loc', env)


def project_cage_method(source, signature, fields, args):
    name = signature.split('(', 1)[0]
    body = adapter.extract(source, name).replace(WATER, repr(WATER))
    for field in fields:
        body = re.sub(r'(?<![\w.])' + field + r'\b', 'src.' + field, body)
    env = {'QDELETED': lambda value: getattr(value, 'deleted', False),
           'istype': lambda value, kind: kind in getattr(value, 'kinds', ())}
    return adapter.project(signature + '\n' + body + '\n', name, args, env)


def project_policy(source):
    source = source.replace('..()', 'parent(key)')
    return adapter.project(source, POLICY, 'src,key', {'parent': lambda key: key == 'appearance'})


class Cage:
    kinds = {OBJ, CAGE}

    def __init__(self, loc, found=None, restoring=False):
        self.loc, self.found, self.restoring = loc, found, restoring
        self.generating = False
        self.soak_generation = 0
        self.timers = 0
        self.icons = 0

    def update_icon(self):
        self.icons += 1

    def generate_fish(self):
        if not self.generating:
            self.soak_generation += 1
            self.generating = True
            self.found = None
            self.timers += 1

    def cancel_fishing_soak(self):
        self.soak_generation += 1
        self.generating = False


class CageRestoreTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')
        self.water = SimpleNamespace(kinds={WATER})
        self.land = SimpleNamespace(kinds=set())

    def test_runtime_policy_filters_new_and_legacy_timer_state(self):
        policy = project_policy(self.source)
        self.assertTrue(policy(None, 'generating'))
        self.assertTrue(policy(None, 'soak_generation'))
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

    def test_old_callback_cannot_finish_or_clear_a_new_soak(self):
        finish = project_cage_method(
            self.source, FINISH + '(turf/site, generation)',
            ('soak_generation', 'generating', 'found', 'loc', 'pick_catch', 'barren_water', 'generate_fish'),
            'src,site,generation')
        cancel = project_cage_method(
            self.source, CANCEL + '()', ('soak_generation', 'generating'), 'src')
        exit_water = project_exit(self.source)
        enter = project_entry(self.source)
        start = adapter.extract(self.source, CAGE + '/proc/generate_fish')
        self.assertLess(start.index('soak_generation++'), start.index('spawn(rand(18000,24000))'))
        self.assertIn('finish_fishing_soak(site, generation)', start)
        for destination in (self.water, SimpleNamespace(kinds={WATER}, tile="other")):
            with self.subTest(same_tile=destination is self.water):
                cage = Cage(self.water)
                cage.cancel_fishing_soak = lambda: cancel(cage)
                debits = []
                cage.pick_catch = lambda tile: debits.append(tile) or 'fish'
                enter(self.water, cage)
                first_timer = cage.soak_generation
                cage.loc = self.land
                exit_water(self.water, cage, self.land)
                self.assertFalse(cage.generating)
                cage.loc = destination
                enter(destination, cage)
                self.assertEqual(cage.timers, 2)
                finish(cage, self.water, first_timer)
                self.assertTrue(cage.generating, 'stale callback must not clear the current timer')
                self.assertIsNone(cage.found)
                self.assertEqual(debits, [])
                finish(cage, destination, cage.soak_generation)
                self.assertFalse(cage.generating)
                self.assertEqual(cage.found, 'fish')
                self.assertEqual(debits, [destination])
                cage.loc = self.land
                exit_water(destination, cage, self.land)
                self.assertEqual(cage.found, 'fish')

    def test_old_same_tile_callback_negative_control(self):
        mutant = self.source.replace(' || generation != soak_generation', '', 1)
        self.assertNotEqual(mutant, self.source)
        finish = project_cage_method(
            mutant, FINISH + '(turf/site, generation)',
            ('soak_generation', 'generating', 'found', 'loc', 'pick_catch', 'barren_water', 'generate_fish'),
            'src,site,generation')
        cage = Cage(self.water)
        cage.generate_fish()
        old_timer = cage.soak_generation
        cage.cancel_fishing_soak()
        cage.generate_fish()
        debits = []
        cage.pick_catch = lambda tile: debits.append(tile) or 'fish'
        finish(cage, self.water, old_timer)
        self.assertFalse(cage.generating, 'the control must reproduce clearing the new timer')
        self.assertEqual(debits, [self.water])

    def test_empty_catch_retries_only_in_nonbarren_water(self):
        finish = project_cage_method(
            self.source, FINISH + '(turf/site, generation)',
            ('soak_generation', 'generating', 'found', 'loc', 'pick_catch', 'barren_water', 'generate_fish'),
            'src,site,generation')
        for barren in (False, True):
            cage = Cage(self.water)
            cage.generate_fish()
            cage.pick_catch = lambda tile: None
            cage.barren_water = lambda tile: barren
            finish(cage, self.water, cage.soak_generation)
            self.assertEqual(cage.timers, 1 if barren else 2)
            self.assertEqual(cage.generating, not barren)

    def test_nonobject_guard_preserves_callbacks_and_models_type_checks(self):
        guard = '\tif (!isobj(O))\n\t\treturn\n'
        self.assertEqual(self.source.count(guard), 1)
        original = self.source.replace(guard, '', 1)
        mutant = self.source.replace('if (!isobj(O))', 'if (isobj(O))', 1)

        def run(source, kind, water=True, constructing=False, restoring=False, found=None, generating=False):
            trace, checks = [], []
            loc = self.water if water else self.land
            if kind == 'null':
                value = None
            elif kind == 'mob':
                value = SimpleNamespace(kinds={'/mob'})
            elif kind == 'object':
                value = SimpleNamespace(kinds={OBJ})
            elif kind == 'buoy':
                value = SimpleNamespace(kinds={OBJ, BUOY}, update_icon=lambda: trace.append('icon'))
            else:
                value = Cage(loc, found=found, restoring=restoring)
                value.generating = generating
                update, generate = value.update_icon, value.generate_fish
                value.update_icon = lambda: (trace.append('icon'), update())
                value.generate_fish = lambda: (trace.append('generate'), generate())
                if kind == 'subtype':
                    value.kinds = {OBJ, CAGE, '/obj/structure/fishing_cage/subtype'}
            result = project_entry(source, constructing, lambda: trace.append('parent'), checks)(loc, value)
            return trace, result, len(checks), getattr(value, 'timers', None)

        cases = [('null', {}), ('mob', {}), ('object', {}), ('buoy', {}),
                 ('cage', {}), ('subtype', {}), ('cage', {'water': False}),
                 ('cage', {'constructing': True}), ('cage', {'restoring': True}),
                 ('cage', {'found': 'fish'}), ('cage', {'generating': True})]
        for kind, options in cases:
            with self.subTest(kind=kind, options=options):
                before, after = run(original, kind, **options), run(self.source, kind, **options)
                self.assertEqual((before[0], before[1], before[3]), (after[0], after[1], after[3]))
                self.assertEqual(after[2] - before[2], -1 if kind in ('null', 'mob') else 1)
                self.assertEqual(after[0][0], 'parent')
        self.assertNotEqual(run(mutant, 'cage')[0], run(original, 'cage')[0])

    def test_fresh_entry_still_starts_generation(self):
        cage = Cage(self.water)
        project_entry(self.source)(self.water, cage)
        self.assertEqual(cage.timers, 1)
        self.assertTrue(cage.generating)


if __name__ == '__main__':
    unittest.main()
