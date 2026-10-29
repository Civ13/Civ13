"""Offline declaration and hook contracts. Never launches BYOND or sends alerts."""
import json
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inventory import ROOT, inventory, declarations, SCOPE
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project

FUNCTIONS = 'code/modules/persistence/functions.dm'
NPC = 'code/game/mob/living/simple_animal/subtile_movement.dm'
HUMAN = 'code/modules/persistence/player_reclaim.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


def hooks(overrides=None):
    """Execute complete audited hooks with parent dispatch and inert AI state.

    These selected hooks have no switch statements. The ancestor fixture is an
    injected boundary; source checks below keep sensitive names out of ancestors.
    This is an offline projection, not native DM dispatch acceptance.
    """
    sources = {path: read(path) for path in (FUNCTIONS, NPC, HUMAN)}
    sources.update(overrides or {})
    result = {}
    result['/mob'] = lambda key: key in ('LAssailant', 'appearance', 'persistence_export_frame')
    for owner, path, parent in (
        ('/mob/living/simple_animal', NPC, '/mob'),
        ('/mob/living/simple_animal/hostile', FUNCTIONS, '/mob/living/simple_animal'),
        ('/mob/living/simple_animal/pet', FUNCTIONS, '/mob/living/simple_animal'),
        ('/mob/observer/ghost', FUNCTIONS, '/mob'),
        ('/mob/living/human', HUMAN, '/mob'),
    ):
        body = extract(sources[path], owner + '/persistence_runtime_var')
        if '..()' not in body:
            raise AssertionError('Hook lost parent delegation: ' + owner)
        body = body.replace('..()', 'parent(key)')
        env = dict(parent=result[parent], list=lambda *values: values,
                   npc_subtile_glide_owned=False, npc_subtile_import_owned=False,
                   npc_subtile_position=None)
        result[owner] = project(owner + '/persistence_runtime_var(key)\n' + body + '\n',
                                owner + '/persistence_runtime_var', 'key', env)
    return result


def assert_scoped_target_names(source):
    for owner in ('/datum/proc', '/atom', '/atom/movable', '/mob'):
        body = extract(source, owner + '/persistence_runtime_var')
        for key in ('target', 'following', 'target_mob', 'assailant', 'victim'):
            if '"' + key + '"' in body:
                raise AssertionError('Ambiguous target name globally excluded: ' + owner + ':' + key)


class PointerContracts(unittest.TestCase):
    def test_every_scoped_declaration_has_an_explicit_reviewed_classification(self):
        actual = {(r['path'], r['owner'], r['field'], r['type']) for r in inventory()}
        reviewed = json.loads(read('tests/persistence_pointers/classifications.json'))
        expected = {(r['path'], r['owner'], r['field'], r['type']) for r in reviewed}
        self.assertEqual(actual, expected, 'Review new/changed pointer declarations; do not auto-allowlist')
        self.assertEqual(len(expected), len(reviewed))
        for row in reviewed:
            self.assertIn(row['policy'], ('runtime', 'unsaved_graph', 'coordinate', 'retained_fail_closed', 'level_link'))
            self.assertGreater(len(row['reason']), 15)

    def test_scanner_covers_tmp_and_explicit_paths_without_proc_locals(self):
        source = ('/mob/test\n\tvar/tmp/atom/a\n\tvar/obj/b\n'
                  '/mob/test/proc/work()\n\tvar/atom/local\n'
                  '/mob/test/var/tmp/mob/c\n')
        self.assertEqual([r['field'] for r in declarations(source, 'fixture')], ['a', 'b', 'c'])
        added = declarations('/mob/test\n\tvar/atom/new_pointer\n', SCOPE[0])
        expected = {(r['owner'], r['field']) for r in inventory()}
        self.assertNotIn((added[0]['owner'], added[0]['field']), expected)

    def test_actual_hooks_exclude_targets_and_dependent_ai_state(self):
        dispatch = hooks()
        for row in json.loads(read('tests/persistence_pointers/classifications.json')):
            if row['policy'] == 'runtime':
                self.assertTrue(dispatch[row['owner']](row['field']), row)
        for key in ('stance', 'stance_step', 'found_path', 'moving', 'last_pathfound', 'move_gen'):
            self.assertTrue(dispatch['/mob/living/simple_animal/hostile'](key), key)
        for owner, fn in dispatch.items():
            self.assertTrue(fn('LAssailant'), owner)
            self.assertTrue(fn('persistence_export_frame'), owner)
        self.assertFalse(dispatch['/mob/living/simple_animal']('following_mob'))
        self.assertFalse(dispatch['/mob/living/simple_animal']('origin'))

    def test_lost_target_exclusion_and_parent_delegation_mutations_are_detected(self):
        source = read(NPC)
        mutated = source.replace('"target_mob", ', '', 1)
        self.assertNotEqual(source, mutated)
        self.assertFalse(hooks({NPC: mutated})['/mob/living/simple_animal/hostile']('target_mob'))
        owner = '/mob/living/simple_animal/hostile/persistence_runtime_var'
        body = extract(read(FUNCTIONS), owner)
        changed = read(FUNCTIONS).replace(body, body.replace('..()', 'FALSE'), 1)
        with self.assertRaisesRegex(AssertionError, 'parent delegation'):
            hooks({FUNCTIONS: changed})

    def test_generic_target_names_are_never_globally_excluded(self):
        source = read(FUNCTIONS)
        assert_scoped_target_names(source)
        anchor = 'return key == "persistence_export_frame"'
        self.assertEqual(source.count(anchor), 1)
        with self.assertRaisesRegex(AssertionError, 'globally excluded'):
            assert_scoped_target_names(source.replace(anchor, 'return key == "target" || key == "persistence_export_frame"'))
        self.assertFalse(hooks()['/mob/living/simple_animal']('target'))
        saving = read('code/modules/persistence/saving.dm')
        self.assertIn('if(movable.z && movable.z != saving_z)', saving)
        self.assertIn('throw EXCEPTION("Cross-level object reference cannot be represented', saving)

    def test_whole_ephemeral_graphs_and_legacy_constructor_guards(self):
        source = read(FUNCTIONS)
        loading = read('code/modules/persistence/loading.dm')
        for owner in ('/obj/item/weapon/grab', '/datum/action'):
            self.assertIn(owner + '\n\tshould_save = FALSE', source)
            self.assertIn('ispath(type, ' + owner + ')', loading)
        mob = extract(source, '/mob/persistence_runtime_var')
        for key in ('actions', 'grab_list', 'grabbed_by'):
            self.assertIn('"' + key + '"', mob)
        guard = loading.index('ispath(type, /datum/action)')
        self.assertLess(guard, loading.index('object = new type(starting_loc)'))

    def test_unsaved_worker_and_pull_graphs_stay_unsaved(self):
        for path, types in ((NPC, ('npc_subtile_pulse', 'npc_subtile_transaction')),
                            ('code/game/mob/living/carbon/human/pull_pair_ownership.dm',
                             ('subtile_pull_pair', 'subtile_pull_capability'))):
            for name in types:
                self.assertIn('/datum/' + name + '\n\tshould_save = FALSE', read(path))

    def test_alert_threshold_reset_and_cadence_execute_production_body(self):
        fn = project(read(FUNCTIONS), '/map_storage/proc/save_failure_alert_due', 'src, success', {})
        storage = SimpleNamespace(consecutive_save_failures=0)
        self.assertEqual([i for i in range(1, 32) if fn(storage, False)], [3, 10, 20, 30])
        self.assertFalse(fn(storage, True))
        self.assertEqual(storage.consecutive_save_failures, 0)
        self.assertEqual([fn(storage, False) for _ in range(3)], [False, False, True])

    def test_rejected_busy_and_load_requests_do_not_count_as_save_failures(self):
        from test_guard import Fixture
        f = Fixture()
        op = f.begin(f.store, 'save')
        self.assertFalse(f.backend(f.store, 'save'))
        self.assertEqual(f.save_results, [])
        op.finish(False)
        f.store.load_world_contents = lambda operation: False
        f.store.cleanup_world_operation = lambda: None
        self.assertFalse(f.backend(f.store, 'load'))
        self.assertEqual(f.save_results, [])

    def test_alert_counts_only_admitted_save_backend_and_uses_existing_sinks(self):
        source = read(FUNCTIONS)
        backend = extract(source, '/map_storage/proc/run_world_operation')
        self.assertLess(backend.index('!operation.enter_backend'), backend.index('record_save_outcome(FALSE)'))
        self.assertEqual(backend.count('record_save_outcome('), 2)
        self.assertIn('if(kind == "save") record_save_outcome(FALSE)', backend)
        self.assertIn('if(kind == "save") record_save_outcome(success)', backend)
        alert = extract(source, '/map_storage/proc/record_save_outcome')
        self.assertIn('message_admins(message)', alert)
        self.assertIn('world.log << message', alert)
        self.assertIn('\n\tcatch\n', '\n' + alert + '\n')
        for private in ('lookup_ref', '\\ref[', '.ckey', '.name', 'discord'):
            self.assertNotIn(private, alert)
        self.assertIn('if(key == "consecutive_save_failures") return TRUE', source)

    def test_full_game_cross_z_regression_uses_real_save_and_keeps_live_targets(self):
        source = read('tests/world_save/full_game_probe.dm')
        body = extract(source, '/datum/world_save_game_probe/proc/check_runtime_pointers')
        for marker in ('target.forceMove(locate(23,20,2))', 'ticker.savemap()',
                       'actor.target_mob != target', 'storage.Load_Entry(F, ref',
                       '"ref" = 999999', 'initial(restored.stance)'):
            self.assertIn(marker, body)


if __name__ == '__main__':
    unittest.main()
