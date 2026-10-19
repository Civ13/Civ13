"""Exact reviewed movement states; offline only, with fail-closed mutations."""
import importlib.util
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('turret_proof_policy', Path(__file__).with_name('run.py'))
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)
TURRET_HEAD = '28652dd42861718fda58eba2a1283ef6b5e01194'
SUBTILE_HEAD = '4b77eab58979ca718faf1aebe9a879a631dcdedf'


def pinned_source(commit, path):
    return subprocess.check_output(['git', 'show', commit + ':' + path], cwd=ROOT, encoding='utf-8')


class ProofBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.current = pinned_source(TURRET_HEAD, runner.MOVEMENT)
        cls.subtile = pinned_source(SUBTILE_HEAD, runner.MOVEMENT)
        cls.combined = cls.subtile
        for name, direction in [('stopmovingright', 'EAST'), ('stopmovingleft', 'WEST')]:
            anchor = ('/client/verb/' + name + '()\n\tset name = ".' + name + '"\n'
                      '\tset instant = TRUE\n\tif (mob && mob.movement_eastwest == ' + direction + ')\n'
                      '\t\tmob.movement_eastwest = null\n')
            if cls.combined.count(anchor) != 1:
                raise ValueError('Pinned release insertion boundary changed')
            cls.combined = cls.combined.replace(anchor, anchor + runner.ADDITION, 1)

    def test_only_two_exact_full_file_states_accepted(self):
        self.assertEqual(runner.movement_reference(self.current), runner.BASELINE)
        self.assertEqual(runner.movement_reference(self.combined), SUBTILE_HEAD)
        self.assertEqual(len(runner.APPROVED_MOVEMENT_REFERENCES), 2)
        self.assertEqual((ROOT / runner.MOVEMENT).read_text(encoding='utf-8'), self.combined)

    def test_combined_is_exact_pinned_movement_plus_release_insertions(self):
        self.assertEqual(self.combined.count(runner.ADDITION), 2)
        self.assertEqual(self.combined.replace(runner.ADDITION, ''), self.subtile)
        for name in runner.RELEASES:
            header = '/client/verb/' + name + '()'
            self.assertEqual(runner.proc(self.current, header), runner.proc(self.combined, header))

    def test_missing_duplicate_or_relocated_release_stops_rejected(self):
        relocated = self.combined.replace(runner.ADDITION, '', 1) + runner.ADDITION
        for source in (self.subtile, self.combined.replace(runner.ADDITION, '', 1),
                       self.combined + runner.ADDITION, relocated):
            with self.subTest(length=len(source)), self.assertRaises(ValueError):
                runner.movement_reference(source)

    def test_selfmove_dispatch_context_and_legacy_fallback_mutations_rejected(self):
        mutations = [
            ('H.SelfMove(n, direct, subtile_deadline)', 'H.Move(n, direct)'),
            ('mob.SelfMove(n, direct)', 'mob.Move(n, direct)'),
            ('H.human_subtile_eligible(direct)', 'TRUE'),
            ('subtile_actor.human_subtile_take_pulse(newloc, direct)', 'null'),
            ('input_actor.client != src', 'FALSE'),
        ]
        for old, new in mutations:
            self.assertIn(old, self.combined)
            with self.subTest(anchor=old), self.assertRaises(ValueError):
                runner.movement_reference(self.combined.replace(old, new, 1))

    def test_direction_drone_or_arbitrary_motion_edit_rejected(self):
        for old, new in [('mob.movement_eastwest == EAST', 'mob.movement_eastwest == WEST'),
                         ('RC.stop_move_drone()', 'pass()'), ('return Move(n, direct)', 'return FALSE')]:
            self.assertIn(old, self.combined)
            with self.subTest(anchor=old), self.assertRaises(ValueError):
                runner.movement_reference(self.combined.replace(old, new, 1))

    def test_control_and_native_execution_body_unchanged(self):
        original = pinned_source(TURRET_HEAD, 'tests/turret_key_release/run.py')
        proposed = Path(__file__).with_name('run.py').read_text(encoding='utf-8')
        self.assertIn('source = baseline if negative_control else movement', proposed)
        self.assertEqual(original[original.index('def main():'):], proposed[proposed.index('def main():'):])
        self.assertIn("'movement_reference_sha': reference_sha", proposed)


if __name__ == '__main__':
    unittest.main(verbosity=2)
