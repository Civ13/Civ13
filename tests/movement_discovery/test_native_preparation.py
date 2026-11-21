"""Bounded offline staging checks. Never compile or execute the native packet."""
import ast
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import prepare_native as prep
from test_lifecycle import FIXTURES, ROOT, TYPE, WRITES, load_audit, read
from test_movement import body, legacy_body


class NativePreparationTests(unittest.TestCase):
    def test_master_reconciliation_preserves_audited_writes_and_suite_admission(self):
        self.assertEqual(sum(WRITES.values()), 13)
        self.assertIn('in living_mob_list)', legacy_body('code/modules/1713/complex_animal/_backend.dm'))
        workflow = read('.github/workflows/test.yml')
        # Only this suite's own lane; other suites' workflow wiring belongs to master.
        self.assertIn("contains(fromJSON(needs.changes.outputs.new_tests || '[]'), 'tests/movement_discovery')", workflow)
        # AGENTS.md links scoped guides; the dated notes live in those READMEs.
        guide = read('AGENTS.md') + ''.join(path.read_text(encoding='utf-8')
                                            for path in sorted((ROOT / 'docs/agent-guides').glob('*/README.md')))
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
                original = legacy_body(path) if mode == 'legacy' else body(path, read(path))
                if kind == 'animal':
                    original = original.replace('\t..()\n', '\tprobe_parent_move()\n', 1)
                self.assertIn(original, source)
        self.assertNotIn('.Copy()', source)
        self.assertNotIn('.z !=', source)

    def test_all_lifecycle_fragments_and_return_paths_present(self):
        source = prep.production()
        for signature in ('probe_death_fragment', 'probe_rejuvenate_fragment',
                          'probe_life_fragment', 'probe_admin_fragment',
                          'probe_after_load_fragment', 'probe_deleted_cleanup_membership'):
            self.assertIn(signature + '(', source)
        self.assertIn('\t\tregister_living_mob(src)\n\t\ttimeofdeath = FALSE', source)
        self.assertIn('\tset_stat(CONSCIOUS)', source)
        self.assertIn('\t\t\tregister_living_mob(src)\n\t\t\tstat = CONSCIOUS', source)
        self.assertIn('return global.dead_mob_list.Remove(src)', source)
        self.assertEqual(source.count('/proc/probe_deleted_cleanup_membership('), 1)
        fixture = (prep.HERE / 'native_probe.dm').read_text()
        self.assertIn('probe_deleted_cleanup_membership(B)', fixture)
        self.assertIn('unregister_living_mob(null)', fixture)
        self.assertNotIn('probe_cleanup_two', source + fixture)

    def test_seven_packets_hash_exact_sources_and_never_launch_native_tools(self):
        all_sources = {row[0] for row in load_audit()['references']}
        before = {path: (ROOT / path).read_bytes() for path in all_sources}
        # Packet bytes and semantic evidence do not depend on a Git checkout.
        # Verify shell exclusion independently of the read-only CLI provenance.
        with tempfile.TemporaryDirectory() as temp, \
                patch.object(prep, 'checkout_metadata', return_value=('f' * 40, b'')), \
                patch.object(prep.subprocess, 'check_output', side_effect=AssertionError('unexpected subprocess')):
            for control in prep.CONTROLS:
                target = Path(temp) / control
                manifest = prep.stage(target, control)
                self.assertTrue(manifest['prepared_only'])
                self.assertFalse(manifest['compiled'])
                self.assertFalse(manifest['executed'])
                self.assertEqual(manifest['head_sha'], 'f' * 40)
                self.assertEqual(manifest['audit_source_sha'], load_audit()['source_review_sha'])
                self.assertEqual(manifest['source_sha256'], {
                    path: hashlib.sha256(before[path]).hexdigest() for path in all_sources})
                for path in FIXTURES.iterdir():
                    self.assertEqual(manifest['contract_fixture_sha256'][path.name],
                                     hashlib.sha256(path.read_bytes()).hexdigest())
                self.assertEqual(manifest['world'], [16, 16, 2])
                self.assertEqual(sum(manifest['write_inventory'].values()), 13)
                for name, digest in manifest['files'].items():
                    self.assertEqual(hashlib.sha256((target / name).read_bytes()).hexdigest(), digest)
                self.assertEqual((target / 'probe.dm').read_bytes(), (prep.HERE / 'native_probe.dm').read_bytes())
                with self.assertRaises(FileExistsError):
                    prep.stage(target, control)
        self.assertEqual(before, {path: (ROOT / path).read_bytes() for path in all_sources})

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
