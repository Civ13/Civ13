"""Source-projected mob-loop checks with offline lifecycle adapters, not BYOND."""

import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/processes/mob.dm').read_text(encoding='utf-8-sig')
MACROS = (ROOT / 'code/_macros.dm').read_text(encoding='utf-8-sig')
SPEC = importlib.util.spec_from_file_location('mob_guard_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)

OLD_GUARD = ('\t\t\tif (!M)\n\t\t\t\tcatchBadType(M)\n\t\t\t\tmob_list -= M\n'
             '\t\t\t\tunregister_living_mob(M)\n\t\t\t\tcontinue\n')


class Mob:
    def __init__(self, events, kind='living', deleted=False, phase='active'):
        self.events, self.kind, self.gc_destroyed, self.phase = events, kind, deleted, phase
        self.retired, self.last_movement, self.velocity = False, 0, 5
        self.client = kind == 'human'

    def __getattribute__(self, name):
        if name in ('last_movement', 'velocity') and object.__getattribute__(self, 'retired'):
            raise AttributeError('retired reference')
        return object.__getattribute__(self, name)

    def __bool__(self):
        return not self.retired

    def __eq__(self, other):
        return self.retired if other is None else self is other

    def Life(self):
        self.events.append('life')
        self.retired = self.phase == 'retire'

    def ecology_hold_still(self):
        self.events.append('hold')


def run(source, kind='living', deleted=False, phase='active', saving=False):
    events = []
    mob = None if kind == 'null' else Mob(events, kind, deleted, phase)
    source = source.replace('mob_list -= M', 'remove_mob(M)')
    source = source.replace('zoom_processing_mobs |= M', 'zoom_add(M)')
    source = source.replace('zoom_processing_mobs -= M', 'zoom_remove(M)')
    source = source.replace('PROCESS_LIST_CHECK', 'list_check(current)')
    source = source.replace('PROCESS_TICK_CHECK', 'tick_check(current)')
    def record(name):
        return lambda *args: events.append(name)
    env = {
        'current_list': [mob], 'ecology_refresh_observers': record('refresh'),
        'isliving': lambda m: bool(m) and m.kind in ('living', 'human'),
        'isDeleted': lambda m: not m or m.gc_destroyed,
        'ishuman': lambda m: bool(m) and m.kind == 'human',
        'ecology_animal_frozen': lambda m: m.phase == 'frozen',
        'ecology_animal_resting': lambda m: m.phase == 'resting',
        'catchBadType': record('bad'), 'remove_mob': record('remove'),
        'unregister_living_mob': record('unregister'), 'zoom_add': record('zoom_add'),
        'zoom_remove': record('zoom_remove'), 'list_check': record('list_check'),
        'tick_check': record('tick_check'), 'catchException': record('exception'),
        'world': SimpleNamespace(time=20),
        'persistence_frozen_levels': SimpleNamespace(len=1 if saving else 0),
        'persistence_life_frozen': lambda m: saving and m.kind == 'human',
    }
    ADAPTER.project(source, '/process/mob/fire', '', env)()
    return events, None if mob is None else object.__getattribute__(mob, 'velocity')


class MobGuardTests(unittest.TestCase):
    def test_guards_and_callback_boundary(self):
        self.assertIn('#define isDeleted(D) (!D || D:gcDestroyed)', MACROS)
        self.assertIn('#define isliving(A) istype(A, /mob/living)', MACROS)
        segment = SOURCE[SOURCE.index('\t\tif (!M || !isliving(M))'):SOURCE.index('\t\ttry')]
        self.assertEqual(segment.strip().splitlines(), [
            'if (!M || !isliving(M))', '\t\t\tcontinue', '', '\t\tif (isDeleted(M))',
            '\t\t\tcatchBadType(M)', '\t\t\tmob_list -= M',
            '\t\t\tunregister_living_mob(M)', '\t\t\tcontinue',
        ])
        self.assertIn('M.Life()\n\t\t\tif (!(M == null))', SOURCE)

    def test_original_and_candidate_event_traces_match(self):
        before = SOURCE.replace('\t\ttry\n', '\t\ttry\n' + OLD_GUARD, 1)
        for kind, deleted, phase in [
            ('null', False, 'active'), ('other', False, 'active'),
            ('living', True, 'active'), ('living', False, 'active'),
            ('living', False, 'frozen'), ('living', False, 'resting'),
            ('human', False, 'active'), ('human', False, 'retire'),
        ]:
            with self.subTest(kind=kind, deleted=deleted, phase=phase):
                self.assertEqual(run(before, kind, deleted, phase), run(SOURCE, kind, deleted, phase))

    def test_missing_outer_guard_changes_null_cleanup(self):
        bad = SOURCE.replace('if (!M || !isliving(M))', 'if (!isliving(M) && M)', 1)
        self.assertNotEqual(run(SOURCE, 'null'), run(bad, 'null'))

    def test_post_life_guard_is_needed(self):
        bad = SOURCE.replace('if (!(M == null))', 'if (TRUE)', 1)
        # A retired DM reference becomes null; the adapter rejects dereference.
        self.assertNotEqual(run(SOURCE, 'human', phase='retire'), run(bad, 'human', phase='retire'))

    def test_saving_level_holds_player_life(self):
        # A player's Life() waits while their level is captured (persistence_life_frozen).
        self.assertIn('persistence_life_frozen(M)', SOURCE)
        held, _ = run(SOURCE, 'human', saving=True)
        self.assertNotIn('life', held)
        self.assertIn('zoom_add', held)
        self.assertIn('life', run(SOURCE, 'human')[0])
        self.assertIn('life', run(SOURCE, 'living', saving=True)[0])


if __name__ == '__main__':
    unittest.main()
