"""Offline source/fixture controls; no compiler, daemon, client or network."""
import importlib.util
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('bump_mining_runner', Path(__file__).with_name('run.py'))
R = importlib.util.module_from_spec(spec)
spec.loader.exec_module(R)
BASE = 'cc03b199128f8afed58713912c551ad7556e6bc4'


class Sources(unittest.TestCase):
    def test_optional_null_wait_projection_matches_existing_full_helper(self):
        old = subprocess.check_output(['git', 'show', BASE + ':code/_helpers/mobs.dm'], cwd=ROOT).decode()
        current = (ROOT / 'code/_helpers/mobs.dm').read_text()
        current = current.replace(', datum/pickaxe_mining_action/mining_context = null', '')
        # Remove only explicit new optional-context branches. Every other byte
        # of the helper file must remain the normalized original Git source.
        rows = current.splitlines(keepends=True); projected = []; skip = None
        for row in rows:
            depth = len(row) - len(row.lstrip('\t'))
            if skip is not None:
                if not row.strip():
                    projected.append(row); continue
                if depth > skip: continue
                skip = None
            if row.lstrip().startswith('if ') and 'mining_context' in row:
                skip = depth; continue
            projected.append(row)
        self.assertEqual(''.join(projected), old.replace('\r\n','\n'))

    def test_exact_held_selection_and_single_canonical_completion(self):
        generated, _, _ = R.source()
        self.assertLess(generated.index('P = get_active_hand()'), generated.index('P = get_inactive_hand()'))
        self.assertNotIn('equip_to_slot', generated)
        self.assertNotIn('swap_hand(', generated)
        self.assertEqual(generated.count('wall.mining_proc(actor)'), 1)
        self.assertLess(generated.index('committed = TRUE'), generated.index('wall.mining_proc(actor)'))
        self.assertIn('240 / actor.getStatCoeff("strength") / tool:usespeed', generated)
        production = (ROOT / 'code/game/turfs/floor_attackby.dm').read_text()
        self.assertIn('start_pickaxe_mining(H, C)', production)
        self.assertIn('spawn(0)\n\t\t\tM.perform()', production)

    def test_reservations_are_runtime_only_and_release_only_their_owners(self):
        generated, _, _ = R.source()
        self.assertIn('should_save = FALSE', generated)
        self.assertIn('actor.pickaxe_mining_action == src', generated)
        self.assertIn('wall.pickaxe_mining_owner == src', generated)
        functions = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        for field in ('pickaxe_mining_action', 'pickaxe_mining_owner'):
            self.assertIn('key == "' + field + '"', functions)
        self.assertIn('catch (var/exception/mining_error)\n\t\trelease()', generated)

    def test_mutations_change_actual_production_and_name_specific_oracles(self):
        normal, _, _ = R.source()
        for control, label in [('dispatch','bump_starts_once'), ('reservation','different_wall_cannot_queue'), ('position','subtile_motion_cancels')]:
            changed, expected, _ = R.source(control)
            self.assertNotEqual(normal, changed)
            self.assertEqual(expected, label)
            self.assertIn(label, Path(__file__).with_name('probe.dm').read_text())

    def test_prepare_only_binds_actual_inputs_and_never_spawns(self):
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(R.subprocess, 'run', side_effect=AssertionError('native forbidden')), patch.object(R.subprocess, 'check_output', return_value=BASE):
                M = R.prepare(Path(temp) / 'probe')
            self.assertEqual(len(M['source_sha256']), 4)
            self.assertEqual(set(M['generated_sha256']), {'support.dm','probe.dm','production.dm','probe.dme'})
            self.assertIn('not integrated', M['subtile_3228'])

    def test_ci_selects_new_suite_on_PR_and_retains_diagnostics(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        self.assertIn("contains(fromJSON(needs.changes.outputs.new_tests), 'tests/bump_mining')", workflow)
        for control in ('dispatch', 'reservation', 'position'):
            self.assertIn('--negative-control ' + control, workflow)
        runner = Path(__file__).with_name('run.py').read_text()
        self.assertIn(r'\b0 errors,\s*0 warnings', runner)
        self.assertIn("'named negative control escaped'", runner)


if __name__ == '__main__': unittest.main()
