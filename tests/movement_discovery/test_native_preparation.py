"""Bounded offline staging checks. Never compile or execute the native packet."""
import ast
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import prepare_native as prep
from test_lifecycle import BASE, ROOT, TYPE, WRITES, baseline, read
from test_movement import body


class NativePreparationTests(unittest.TestCase):
    def test_master_reconciliation_preserves_source_projection_and_all_fourteen_writes(self):
        self.assertEqual(sum(WRITES.values()), 14)
        for path in WRITES:
            self.assertIn('living_mob_list', baseline(path))
        workflow = read('.github/workflows/test.yml')
        for suite in ('movement_discovery', 'persistence_year', 'ping_scheduler',
                      'local_discovery', 'roof_area_recovery', 'footwear_water_mask'):
            self.assertIn(f"contains(fromJSON(needs.changes.outputs.new_tests), 'tests/{suite}')", workflow)
        guide = read('AGENTS.md')
        for rule in ('ordered movement discovery subset', 'ping pass aggregation',
                     'persistence minimum date', 'save movement and physical sleep guards'):
            self.assertIn(rule, guide)

    def test_production_constructor_destructor_and_helpers_are_extracted(self):
        source = prep.production()
        for path, signature in (
            ('code/game/mob/mob.dm', '/mob/New()'),
            ('code/game/mob/mob.dm', '/mob/Destroy()'),
            ('code/_helpers/unsorted.dm', '/mob/dview/New()'),
            ('code/game/mob/living/carbon/human/announcer.dm', '/mob/living/human/announcer/New('),
        ):
            self.assertIn(prep.procedure(path, signature), source)
        helpers = read('code/_helpers/mobs.dm').split('/proc/register_living_mob(', 1)[1]
        self.assertIn('/proc/register_living_mob(' + helpers, source)

    def test_legacy_and_candidate_native_loops_keep_live_list_iteration(self):
        source = prep.production()
        for mode in ('legacy', 'candidate'):
            for path, kind in (('code/game/mob/mob_movement.dm', 'human'),
                               ('code/modules/1713/complex_animal/_backend.dm', 'animal')):
                original = body(path, baseline(path) if mode == 'legacy' else read(path))
                if kind == 'animal':
                    original = original.replace('\t..()\n', '\tprobe_parent_move()\n', 1)
                self.assertIn(original, source)
        self.assertNotIn('.Copy()', source)
        self.assertNotIn('.z !=', source)

    def test_all_lifecycle_fragments_and_return_paths_present(self):
        source = prep.production()
        for signature in ('probe_death_fragment', 'probe_rejuvenate_fragment',
                          'probe_life_fragment', 'probe_admin_fragment',
                          'probe_after_load_fragment', 'probe_cleanup_one', 'probe_cleanup_two'):
            self.assertIn(signature + '(', source)
        self.assertIn('\t\tregister_living_mob(src)\n\t\ttimeofdeath = FALSE', source)
        self.assertIn('\tset_stat(CONSCIOUS)', source)
        self.assertIn('\t\t\tregister_living_mob(src)\n\t\t\tstat = CONSCIOUS', source)
        self.assertIn('return global.dead_mob_list.Remove(src)', source)

    def test_seven_packets_hash_exact_sources_and_never_launch_native_tools(self):
        original_call = subprocess.check_output
        def git_only(args, **kwargs):
            self.assertEqual(args[0], 'git')
            return original_call(args, **kwargs)
        before = {path: (ROOT / path).read_bytes() for path in WRITES}
        with tempfile.TemporaryDirectory() as temp, patch.object(prep.subprocess, 'check_output', side_effect=git_only):
            for control in prep.CONTROLS:
                target = Path(temp) / control
                manifest = prep.stage(target, control)
                self.assertTrue(manifest['prepared_only'])
                self.assertFalse(manifest['compiled'])
                self.assertFalse(manifest['executed'])
                self.assertEqual(manifest['oracle_commit'], BASE)
                self.assertEqual(manifest['world'], [16, 16, 2])
                self.assertEqual(sum(manifest['write_inventory'].values()), 14)
                for name, digest in manifest['files'].items():
                    self.assertEqual(hashlib.sha256((target / name).read_bytes()).hexdigest(), digest)
                self.assertEqual((target / 'probe.dm').read_bytes(), (prep.HERE / 'native_probe.dm').read_bytes())
                with self.assertRaises(FileExistsError):
                    prep.stage(target, control)
        self.assertEqual(before, {path: (ROOT / path).read_bytes() for path in WRITES})

    def test_control_mutations_only_touch_the_intended_candidate_operation(self):
        source = prep.production()
        legacy_animal = source.split(f'{TYPE}/proc/probe_legacy_animal()', 1)[1].split('/mob/proc/probe_candidate_human()', 1)[0]
        for control in prep.CONTROLS:
            candidate = prep.controlled(source, control)
            self.assertIn(legacy_animal, candidate)
            self.assertEqual(candidate == source, control == 'fixed')
        self.assertIn('prob(89)', prep.controlled(source, 'rng-order'))
        self.assertIn('if (C.z != mob.z)', prep.controlled(source, 'same-z'))
        with self.assertRaises(ValueError):
            prep.controlled(source, 'unknown')

    def test_case_contract_has_exact_oracles_for_all_mutation_scenarios(self):
        contract = json.loads((prep.HERE / 'native_expectations.json').read_text())
        self.assertEqual(len(contract['cases']), 16)
        self.assertEqual(set(contract['controls']), set(prep.CONTROLS))
        self.assertEqual(len({case['id'] for case in contract['cases']}), 16)
        native = (prep.HERE / 'native_probe.dm').read_text()
        for case in contract['cases']:
            self.assertIn('members', case)
            self.assertEqual(set(case['events']), {'human', 'animal'})
        for action in ('remove-unrelated', 'remove-self', 'remove-next', 'append',
                       'delete-self', 'delete-next', 'delete-duplicate', 'reentry',
                       'yield-remove-next', 'yield-append'):
            self.assertIn('"' + action + '"', native)
        self.assertIn('json_encode(legacy) == json_encode(candidate)', native)
        self.assertIn('probe_trace.len < 256', native)
        self.assertIn('probe_depth <= 1', native)
        self.assertIn('sleep(1)', native)
        self.assertIn('spawn (0)', native)
        self.assertIn('isnull(living_complex_animal_list[1])', native)

    def test_preparer_has_no_execution_switch_or_non_git_subprocess(self):
        tree = ast.parse((prep.HERE / 'prepare_native.py').read_text())
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
                if isinstance(node.func.value, ast.Name) and node.func.value.id == 'subprocess':
                    self.assertEqual(node.func.attr, 'check_output')
                    self.assertIsInstance(node.args[0], ast.List)
                    self.assertEqual(node.args[0].elts[0].value, 'git')
        native = (prep.HERE / 'native_probe.dm').read_text()
        self.assertIn('if (port == "none") return ..()', native)
        self.assertIn('/client/New()\n    del(src)\n    return', native)
        self.assertTrue(native.rstrip().endswith('del(world)\n    return'))


if __name__ == '__main__':
    unittest.main()
