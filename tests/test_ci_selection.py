import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
import subprocess
import tempfile
import os
import json
import sys

spec = importlib.util.spec_from_file_location('selection', Path(__file__).resolve().parents[1] / 'scripts/select-ci.py')
selection = importlib.util.module_from_spec(spec)
spec.loader.exec_module(selection)

class SelectionTests(unittest.TestCase):
    def test_mood_sleep_admission_is_exact_and_offline(self):
        path = 'tests/mood_sleep/test_mood_sleep.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a'*40, 'b'*40, 'pull_request'), [])
        for other in ('tests/mood_sleep/new_probe.dm', 'tests/mood_sleep/new_runner.py',
                      'tests/mood_sleep/new_runner.ps1', 'tests/mood_sleep/new_runner.sh'):
            with self.subTest(path=other), patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
                with self.assertRaisesRegex(RuntimeError, 'Unregistered mood-sleep'):
                    selection.introduced_tests('a'*40, 'b'*40, 'pull_request')
        with patch.object(selection, 'MOOD_SLEEP_OFFLINE_TESTS', frozenset()), \
             patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered mood-sleep'):
                selection.introduced_tests('a'*40, 'b'*40, 'pull_request')

    def test_help_toxin_offline_admission_is_exact_and_preserves_native_gates(self):
        path = 'tests/player_help/test_toxin_context.py'
        def introduced(value):
            with patch.object(selection.subprocess, 'check_output', return_value=(value + '\0').encode()):
                return selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')
        self.assertEqual(introduced(path), [])
        for other in ('tests/player_help/new_native_probe.dm', 'tests/player_help/new_native.py',
                      'tests/player_help/new_runner.ps1', 'tests/player_help/new_runner.sh',
                      'tests/player_help/Test_toxin_context.py',
                      'tests/player_help/nested/test_toxin_context.py'):
            with self.subTest(path=other):
                self.assertEqual(introduced(other), ['tests/player_help'])
        remaining = selection.PLAYER_HELP_OFFLINE_TESTS - {path}
        with patch.object(selection, 'PLAYER_HELP_OFFLINE_TESTS', remaining):
            self.assertEqual(introduced(path), ['tests/player_help'])
        for production in ('scripts/player_help_bridge.py', 'code/game/mob/player_help.dm',
                           'code/game/mob/living/carbon/human/human_life.dm'):
            self.assertTrue(selection.needs_game([production]))
        payload={'action':'synchronize','pull_request':{'title':'Toxin help','base':{'ref':'master'}}}
        with patch.object(selection, 'select', return_value=(True, 'Production changed')), \
             patch.object(selection, 'introduced_tests', return_value=['tests/player_help']), \
             patch.object(selection, 'changed_atlas_tests', return_value=[]):
            game, extensive, suites, _ = selection.selections('a'*40, 'b'*40, 'pull_request', True, True, payload)
            _, manual_extensive, _, _ = selection.selections('a'*40, 'b'*40, 'workflow_dispatch', True, True, {})
        self.assertTrue(game)
        self.assertFalse(extensive, 'PR admission does not enable manual extensive mode')
        self.assertEqual(suites, ['tests/player_help'])
        self.assertTrue(manual_extensive, 'Existing manual opt-in remains available')

    def test_stone_brazier_offline_admission_is_exact(self):
        path = 'tests/stone_brazier/test_stone_brazier_disposal.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/stone_brazier/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered stone-brazier'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')
        with patch.object(selection, 'STONE_BRAZIER_OFFLINE_TESTS', frozenset()):
            with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
                with self.assertRaisesRegex(RuntimeError, 'Unregistered stone-brazier'):
                    selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_mcp_changed_files_and_comparison_failure(self):
        for path in ('tools/mcp/server.mjs', 'tools/mcp/test.mjs',
                     'tools/mcp/package-lock.json', '.github/workflows/mcp.yml', 'scripts/ci_skill_prose.py',
                     'scripts/ci_checkout_refs.py', 'tests/test_ci_checkout_refs.py',
                     'scripts/nomads-lifecycle/agent_debug.py',
                     'scripts/nomads-lifecycle/variable_observability.py',
                     'scripts/nomads-lifecycle/read_blackout.py',
                     'tests/nomads_lifecycle/test_agent_debug.py',
                     'tests/nomads_lifecycle/test_variable_observability.py',
                     'code/modules/persistence/functions.dm', 'code/modules/persistence/saving.dm',
                     'code/modules/persistence/restart_transaction.dm',
                     'code/modules/persistence/nomads_lifecycle.dm',
                     'code/modules/persistence/variable_observability.dm',
                     'code/modules/persistence/zone_topology.dm'):
            with self.subTest(path=path), patch.object(selection.subprocess, 'check_output',
                                                        return_value=(path + '\0').encode()):
                self.assertTrue(selection.select_mcp('a' * 40, 'b' * 40, 'pull_request'))
                self.assertTrue(selection.select_mcp('a' * 40, 'b' * 40, 'push'))
        with patch.object(selection.subprocess, 'check_output', return_value=b'code/world.dm\0'):
            self.assertFalse(selection.select_mcp('a' * 40, 'b' * 40, 'pull_request'))
        with patch.object(selection.subprocess, 'check_output', side_effect=subprocess.CalledProcessError(1, 'git')):
            with self.assertRaises(RuntimeError):
                selection.select_mcp('a' * 40, 'b' * 40, 'pull_request')
        with self.assertRaises(RuntimeError):
            selection.select_mcp('', 'b' * 40, 'pull_request')
        self.assertTrue(selection.select_mcp('', '', 'workflow_dispatch'))
        self.assertTrue(selection.select_mcp('0' * 40, 'b' * 40, 'push'))

    def test_mcp_workflow_keeps_both_platforms_and_requires_selection(self):
        workflow = (Path(__file__).resolve().parents[1] / '.github/workflows/mcp.yml').read_text()
        self.assertIn('os: [ubuntu-latest, windows-latest]', workflow)
        self.assertIn("if: needs.changes.outputs.mcp == 'true'", workflow)
        self.assertIn('--mcp-only', workflow)
        self.assertIn('scripts/ci_checkout_refs.py', workflow)
        self.assertIn('ref: ${{ github.event.pull_request.head.sha || github.sha }}', workflow.split('  mcp:\n', 1)[1])
        self.assertIn('Verify checked-out head', workflow)

    def test_mcp_selector_real_diff_and_no_output_on_failure(self):
        script = Path(__file__).resolve().parents[1] / 'scripts/select-ci.py'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(['git', '-c', 'user.name=Fixture',
                    '-c', 'user.email=fixture@example.invalid', '-c', 'commit.gpgsign=false',
                    *args], cwd=root, stderr=subprocess.PIPE, text=True).strip()
            git('init', '-q')
            (root / 'tools/mcp').mkdir(parents=True)
            (root / 'scripts').mkdir()
            (root / 'scripts/ci_checkout_refs.py').write_text('before', encoding='utf-8')
            (root / 'scripts/nomads-lifecycle').mkdir()
            for name in ('agent_debug.py', 'variable_observability.py', 'read_blackout.py'):
                (root / 'scripts/nomads-lifecycle' / name).write_text('before', encoding='utf-8')
            for name in ('server.mjs', 'test.mjs'):
                (root / 'tools/mcp' / name).write_text('before', encoding='utf-8')
            git('add', '.')
            git('commit', '-qm', 'base')
            base = git('rev-parse', 'HEAD')
            for name in ('server.mjs', 'test.mjs'):
                (root / 'tools/mcp' / name).write_text('after', encoding='utf-8')
                git('add', '.')
                git('commit', '-qm', name)
                head = git('rev-parse', 'HEAD')
                output = root / 'selection-output'
                args = [sys.executable, '-B', str(script), '--mcp-only', '--base', base,
                        '--head', head, '--event', 'pull_request', '--output', str(output)]
                result = subprocess.run(args, cwd=root, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(output.read_text(encoding='utf-8'), 'mcp=true\n')
                output.unlink()
                args[args.index('--base') + 1] = 'f' * 40
                result = subprocess.run(args, cwd=root, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(output.exists())
                base = head
            (root / 'scripts/ci_checkout_refs.py').write_text('after', encoding='utf-8')
            git('add', '.')
            git('commit', '-qm', 'helper-only')
            result = subprocess.run([sys.executable, '-B', str(script), '--mcp-only', '--base', base,
                '--head', git('rev-parse', 'HEAD'), '--event', 'pull_request', '--output', str(root / 'helper-output')],
                cwd=root, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((root / 'helper-output').read_text(), 'mcp=true\n')
            (root / 'helper-output').unlink()
            base = git('rev-parse', 'HEAD')
            for name in ('agent_debug.py', 'variable_observability.py', 'read_blackout.py'):
                (root / 'scripts/nomads-lifecycle' / name).write_text('after', encoding='utf-8')
                git('add', '.')
                git('commit', '-qm', name)
                head = git('rev-parse', 'HEAD')
                output = root / ('reader-' + name)
                result = subprocess.run([sys.executable, '-B', str(script), '--mcp-only', '--base', base,
                    '--head', head, '--event', 'pull_request', '--output', str(output)],
                    cwd=root, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(output.read_text(), 'mcp=true\n')
                output.unlink()
                base = head

    def test_well_smell_offline_admission_is_exact(self):
        path = 'tests/well_smell/test_well_smell.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/well_smell/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered well-smell'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')
        with patch.object(selection, 'WELL_SMELL_OFFLINE_TESTS', frozenset()):
            with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
                with self.assertRaisesRegex(RuntimeError, 'Unregistered well-smell'):
                    selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_showcase_rooms_offline_admission_is_exact(self):
        path = 'tests/showcase_rooms/test_templates.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/showcase_rooms/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered showcase-room'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_gaia_host_offline_admission_is_exact(self):
        for path in ('tests/gaia_host/test_gaia_host.py', 'tests/gaia_host/test_shard_group.py', 'tests/gaia_host/test_doorman.py',
                     'tests/gaia_host/test_wait_group.py', 'tests/gaia_host/test_relay.py',
                     'tests/gaia_host/test_mobile_host.py'):
            with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
                self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/gaia_host/new_native_probe.ps1'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered gaia-host'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_farmers_almanac_offline_admission_is_exact(self):
        path = 'tests/farmers_almanac/test_farmers_almanac.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/farmers_almanac/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered farmers-almanac'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_crossroads_mall_offline_admission_is_exact(self):
        for path in ('tests/crossroads_mall/test_crossroads_mall.py', 'tests/crossroads_mall/build.py'):
            with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
                self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/crossroads_mall/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered crossroads-mall'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_train_raid_offline_admission_is_exact(self):
        for path in ('tests/train_raid/test_train_raid.py', 'tests/train_raid/build.py',
                     'tests/train_raid/native_probe.py', 'tests/train_raid/native_probe.dm'):
            with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
                self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/train_raid/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered train-raid'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_zombie_city_offline_admission_is_exact(self):
        for path in ('tests/zombie_city/test_zombie_city.py', 'tests/zombie_city/build_base.py',
                     'tests/zombie_city/check.py', 'tests/zombie_city/native_probe.py',
                     'tests/zombie_city/native_probe.dm', 'tests/zombie_city/horde_probe.py',
                     'tests/zombie_city/horde_probe.dm'):
            with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
                self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/zombie_city/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered zombie-city'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_safehouse_map_offline_admission_is_exact(self):
        for path in ('tests/safehouse_map/test_layout.py', 'tests/safehouse_map/build_map.py',
                     'tests/safehouse_map/validate_map.py', 'tests/safehouse_map/compile_map.py',
                     'tests/safehouse_map/preview.py'):
            with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
                self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/safehouse_map/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered safehouse-map'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_inventory_drag_offline_admission_is_exact(self):
        path = 'tests/inventory_drag/test_inventory_drag.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/inventory_drag/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered inventory-drag'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_research_staff_offline_admission_is_exact(self):
        path = 'tests/research_staff/test_research_staff.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/research_staff/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered research-staff'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_flint_mining_offline_admission_is_exact(self):
        for path in ('tests/flint_mining/test_flint_mining.py', 'tests/flint_mining/run.py', 'tests/flint_mining/probe.dm'):
            with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
                self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/flint_mining/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered flint-mining'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_door_intents_offline_admission_is_exact(self):
        for path in ('tests/door_intents/test_door_intents.py', 'tests/door_intents/test_jail_keys.py'):
            with self.subTest(path=path):
                with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
                    self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/door_intents/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered door-intent'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_map_tools_offline_admission_is_exact(self):
        path = 'tests/map_tools/test_map_tools.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/map_tools/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered map-tools'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_fireman_carry_offline_admission_is_exact(self):
        for path in ('tests/fireman_carry/test_source.py', 'tests/fireman_carry/probe.dm',
                     'tests/fireman_carry/run_native.py'):
            with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
                self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/fireman_carry/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered fireman-carry'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_medical_care_offline_admission_is_exact(self):
        path = 'tests/medical_care/test_source.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/medical_care/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered medical-care'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_held_movement_offline_admission_is_exact(self):
        path = 'tests/held_movement/test_held_movement.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/held_movement/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered held-movement'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_sweep_loops_offline_admission_is_exact(self):
        path = 'tests/sweep_loops/test_sweep_loops.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/sweep_loops/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered sweep-loop'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_zombie_spawn_selection_offline_admission_is_exact(self):
        path = 'tests/zombie_spawn_selection/test_selection.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/zombie_spawn_selection/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered zombie-spawn-selection'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_nomads_adoption_offline_admission_is_exact(self):
        path = 'tests/nomads_adoption/test_nomads_adoption.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/nomads_adoption/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered nomads-adoption'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_savestream_admission_is_exact(self):
        for path in ('tests/savestream/test_helper.py', 'tests/savestream/helper_client.py',
                     'tests/savestream/run_native.py', 'tests/savestream/roundtrip/fixture.dm'):
            with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
                self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/savestream/new_probe.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered savestream'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_local_ci_offline_admission_is_exact(self):
        path = 'tests/local_ci/test_local_ci.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/local_ci/new_probe.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered local-ci'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_agent_ci_digest_offline_admission_is_exact(self):
        path = 'tests/agent_ci_digest/test_ci_digest.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/agent_ci_digest/new_probe.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered agent-ci-digest'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_agent_control_offline_admission_is_exact(self):
        for path in ('tests/agent_control/test_agent_control.py',
                     'tests/agent_control/test_perception_replay.py',
                     'tests/agent_control/test_visibility.py',
                     'tests/agent_control/test_action_contract.py',
                     'tests/agent_control/test_navigation_replay.py'):
            with self.subTest(path=path), patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
                self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        for path in ('tests/agent_control/new_native_probe.dm',
                     'tests/agent_control/visibility/rogue.py',
                     'tests/agent_control/visibility/rogue.ps1',
                     'tests/agent_control/visibility/rogue.sh'):
            with self.subTest(path=path), patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
                with self.assertRaisesRegex(RuntimeError, 'Unregistered agent-control'):
                    selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_agent_parity_probes_remain_manual_only(self):
        paths = {'tests/agent_control/windows_probe.dm', 'tests/agent_control/prompts_probe.dm',
                 'tests/agent_control/stance_probe.dm', 'tests/agent_control/move_probe.dm',
                 'tests/agent_control/vehicle_probe.dm', 'tests/agent_control/screens_probe.dm',
                 'tests/agent_control/travel_probe.dm'}
        self.assertEqual(selection.AGENT_PARITY_MANUAL_NATIVE, paths)
        self.assertFalse(paths & selection.AGENT_CONTROL_OFFLINE_TESTS)
        for path in paths:
            with self.subTest(path=path), patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
                self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
                with patch.object(selection, 'AGENT_PARITY_MANUAL_NATIVE', frozenset()):
                    with self.assertRaisesRegex(RuntimeError, 'Unregistered agent-control'):
                        selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_agent_visibility_native_fixture_remains_manual_only(self):
        paths = {'tests/agent_control/visibility/prepare.py',
                 'tests/agent_control/visibility/run.py',
                 'tests/agent_control/visibility/adapters.dm',
                 'tests/agent_control/visibility/probe.dm'}
        self.assertEqual(selection.AGENT_CONTROL_MANUAL_NATIVE, paths)
        self.assertFalse(paths & selection.AGENT_CONTROL_OFFLINE_TESTS)
        for path in paths:
            with self.subTest(path=path), patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
                self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
                with patch.object(selection, 'AGENT_CONTROL_MANUAL_NATIVE', frozenset()):
                    with self.assertRaisesRegex(RuntimeError, 'Unregistered agent-control'):
                        selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_action_contract_native_probe_remains_manual_only(self):
        path = 'tests/agent_observe/action_contract_probe.dm'
        self.assertEqual(selection.AGENT_OBSERVE_MANUAL_NATIVE, {path})
        with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
            with patch.object(selection, 'AGENT_OBSERVE_MANUAL_NATIVE', frozenset()):
                self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), ['tests/agent_observe'])
        # Existing admission for unrelated observe fixtures is not broadened or exempted.
        other = 'tests/agent_observe/unreviewed.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), ['tests/agent_observe'])

    def test_manual_comparison_base_requires_distinct_local_full_commits(self):
        with tempfile.TemporaryDirectory() as directory:
            def git(*args):
                return subprocess.check_output(['git', '-C', directory, *args], stderr=subprocess.PIPE).decode().strip()
            git('init')
            git('config', 'user.name', 'Selection test')
            git('config', 'user.email', 'selection@example.invalid')
            file = Path(directory) / 'file.txt'
            file.write_text('base', encoding='utf-8')
            git('add', 'file.txt')
            git('commit', '-m', 'base')
            base = git('rev-parse', 'HEAD')
            file.write_text('head', encoding='utf-8')
            git('add', 'file.txt')
            git('commit', '-m', 'head')
            head = git('rev-parse', 'HEAD')
            selection.validate_manual_base(base, head, cwd=directory)
            for invalid in ('', 'HEAD', '0' * 40, 'f' * 40, head):
                with self.subTest(base=invalid), self.assertRaises(ValueError):
                    selection.validate_manual_base(invalid, head, cwd=directory)

    def test_manual_workflow_routes_one_base_through_all_receipts(self):
        workflow = (Path(__file__).resolve().parents[1] / '.github/workflows/test.yml').read_text()
        self.assertIn('      comparison_base:\n', workflow)
        self.assertIn('        required: true\n', workflow.split('      comparison_base:\n', 1)[1].split('      extensive_regressions:', 1)[0])
        expression = "${{ github.event_name == 'workflow_dispatch' && inputs.comparison_base || github.event.pull_request.base.sha || github.event.before || '' }}"

        def assert_routes(source):
            changes = source.split('\n  changes:\n', 1)[1].split('\n  baseline:\n', 1)[0]
            baseline = source.split('\n  baseline:\n', 1)[1].split('\n  evidence-checker:\n', 1)[0]
            build = source.split('\n  build:\n', 1)[1].split('\n  ci-required:\n', 1)[0]
            aggregate = source.split('\n  ci-required:\n', 1)[1]
            self.assertIn('      base: ' + expression, changes)
            for job in (baseline, aggregate):
                prepare = job.split('      - name: Prepare exact comparison commit\n', 1)[1].split('\n      - ', 1)[0]
                self.assertIn('          BASE_REF: ' + expression, prepare)
            for job in (baseline, build, aggregate):
                self.assertIn('          CI_BASE: ' + expression, job)

        assert_routes(workflow)
        # Mutate each actual producer/consumer binding, independent of unrelated steps.
        for job, end, field in (('changes', 'baseline', 'base'),
                                ('baseline', 'evidence-checker', 'BASE_REF'),
                                ('baseline', 'evidence-checker', 'CI_BASE'),
                                ('build', 'ci-required', 'CI_BASE'),
                                ('ci-required', None, 'BASE_REF'),
                                ('ci-required', None, 'CI_BASE')):
            start = workflow.index('\n  ' + job + ':\n')
            stop = workflow.index('\n  ' + end + ':\n', start) if end else len(workflow)
            section = workflow[start:stop]
            binding = field + ': ' + expression
            self.assertEqual(section.count(binding), 1)
            altered = workflow[:start] + section.replace(binding, field + ': ${{ github.sha }}', 1) + workflow[stop:]
            with self.subTest(job=job, field=field), self.assertRaises(AssertionError):
                assert_routes(altered)

    def test_manual_selector_publishes_only_validated_base_receipt(self):
        source = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'repo'
            (root / 'scripts').mkdir(parents=True)
            for name in ('select-ci.py', 'ci_baseline.py', 'ci_skill_prose.py', 'byond_toolchain.py'):
                (root / 'scripts' / name).write_bytes((source / 'scripts' / name).read_bytes())
            def git(*args):
                return subprocess.check_output(['git', '-c', 'user.name=CI fixture',
                    '-c', 'user.email=ci@example.invalid', '-c', 'commit.gpgsign=false', *args],
                    cwd=root, stderr=subprocess.PIPE, text=True, timeout=15).strip()
            git('init', '-q')
            (root / 'README.md').write_text('base\n', encoding='utf-8')
            git('add', '.')
            git('commit', '-qm', 'base')
            base = git('rev-parse', 'HEAD')
            (root / 'README.md').write_text('head\n', encoding='utf-8')
            git('commit', '-qam', 'head')
            head = git('rev-parse', 'HEAD')
            output, receipt = Path(directory) / 'output', Path(directory) / 'receipt.json'
            script = root / 'scripts/select-ci.py'
            args = [sys.executable, '-B', str(script), '--base', base, '--head', head,
                    '--event', 'workflow_dispatch', '--build-prefix', 'true',
                    '--output', str(output), '--receipt', str(receipt)]
            env = dict(os.environ)
            env.pop('GITHUB_EVENT_PATH', None)
            env.pop('GITHUB_STEP_SUMMARY', None)
            result = subprocess.run(args, cwd=root, env=env, capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            plan = json.loads(receipt.read_text(encoding='utf-8'))
            self.assertEqual((plan['base'], plan['requested_base'], plan['head']), (base, base, head))
            self.assertEqual(plan['comparison']['status'], 'available')
            self.assertEqual(plan['new_tests'], [])
            output.unlink(); receipt.unlink()
            args[args.index('--base') + 1] = head
            result = subprocess.run(args, cwd=root, env=env, capture_output=True, text=True, timeout=30)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('must differ', result.stderr)
            self.assertFalse(output.exists())
            self.assertFalse(receipt.exists())

    def test_axe_active_hand_offline_admission_is_exact(self):
        path = 'tests/axe_active_hand/test_axe_active_hand.py'
        with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
            self.assertEqual(selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request'), [])
        other = 'tests/axe_active_hand/new_native_probe.dm'
        with patch.object(selection.subprocess, 'check_output', return_value=(other + '\0').encode()):
            with self.assertRaisesRegex(RuntimeError, 'Unregistered axe active-hand'):
                selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')
        with patch.object(selection, 'AXE_ACTIVE_HAND_OFFLINE_TESTS', frozenset()):
            with patch.object(selection.subprocess, 'check_output', return_value=(path + '\0').encode()):
                with self.assertRaisesRegex(RuntimeError, 'Unregistered axe active-hand'):
                    selection.introduced_tests('a' * 40, 'b' * 40, 'pull_request')

    def test_extensive_is_explicit_manual_opt_in(self):
        self.assertTrue(selection.needs_extensive('workflow_dispatch', True))
        self.assertFalse(selection.needs_extensive('workflow_dispatch', False))
        for event in ('push', 'pull_request', 'pull_request_target', ''):
            with self.subTest(event=event):
                self.assertFalse(selection.needs_extensive(event, True))
                self.assertFalse(selection.needs_extensive(event, False))

    def test_documentation_only(self):
        self.assertFalse(selection.needs_game(['AGENTS.md', 'docs/api/search.js',
            'docs/api/search.css', 'scripts/build-api-docs.py',
            '.github/workflows/api-pages.yml']))
    def test_repository_prose_and_metadata_avoid_game_compilation(self):
        for path in ('tests/local_ci/README.md', 'tools/byond/README.md', '.claude/skills/x/SKILL.md',
                     'LICENSE', '.gitattributes', '.gitignore'):
            with self.subTest(path=path):
                self.assertFalse(selection.needs_game([path]))
        for path in ('code/notes.md', 'maps/README.md', 'config/x.md', 'wiki/x.md', 'html/x.md', 'UI/x.md',
                     'tgui/README.md', '.agents/skills/civ13/README.md', 'tools/x.py', 'tests/../code/x.md',
                     'LICENSE.txt', '.claude/settings.json'):
            with self.subTest(path=path):
                self.assertTrue(selection.needs_game([path]))

    def test_only_reviewed_skill_prose_avoids_game_compilation(self):
        prose = ['.agents/skills/civ13-compile/SKILL.md',
                 '.agents/skills/group/skill/SKILL.md',
                 '.agents/skills/civ13-compile/references/notes.md',
                 '.agents/skills/civ13-compile/references/nested/notes.md']
        self.assertFalse(selection.needs_game(prose))
        for path in ('.agents/skills/civ13/scripts/run.py', '.agents/skills/civ13/references/probe.dm',
                     '.agents/skills/civ13/references/run.sh', '.agents/skills/civ13/references/config.yaml',
                     '.agents/skills/civ13/references/config.json', '.agents/skills/civ13/README.md',
                     '.agents/skills/civ13/templates/note.md', '.agents/skills/civ13/skill.md',
                     '.agents/skills/SKILL.md', '.agents/skills/references/note.md',
                     '.agents/skills/civ13/../SKILL.md', '.agents/skills/civ13/references/note.MD'):
            with self.subTest(path=path):
                self.assertTrue(selection.needs_game(prose + [path]))
        # Atlas ancestry is independently exercised by the real-Git graph controls.
        with patch.object(selection.subprocess,'check_output',return_value=('\0'.join(prose)+'\0').encode()), \
             patch.object(selection, 'changed_atlas_tests', return_value=[]):
            self.assertFalse(selection.select('base','head')[0])
            self.assertTrue(selection.select('0'*40,'head')[0])
            for title,expected in [('Document skill prose',False),('build: document skill prose',True)]:
                game,extensive,new_tests,_=selection.selections('base','head','pull_request',False,True,
                    dict(action='synchronize',pull_request=dict(title=title,base=dict(ref='master'))))
                self.assertEqual(game,expected);self.assertFalse(extensive);self.assertEqual(new_tests,[])

    def test_shared_and_runtime_paths(self):
        for path in ('civ13.dme', 'code/__defines/maps.dm', 'code/world.dm',
                     'maps/nomads/map.dmm', 'icons/obj/test.dmi', 'sound/a.ogg',
                     'config/config.txt', '_compile_options.dm', 'docs/new_include.dm',
                     '.github/workflows/test.yml', '.github/workflows/ci-selection.yml',
                     'scripts/select-ci.py', 'tests/chemistry/run.py',
                     'scripts/test-power.ps1', 'tools/new-tool/file'):
            with self.subTest(path=path):
                self.assertTrue(selection.needs_game(['docs/api/README.md', path]))
    def test_renamed_or_deleted_game_file(self):
        # git diff --name-only without rename detection returns both old/new paths.
        self.assertTrue(selection.needs_game(['code/old.dm', 'docs/moved.md']))
    def test_missing_base_or_manual_runs_all(self):
        self.assertTrue(selection.select('', 'abc')[0])
        self.assertTrue(selection.select('0' * 40, 'abc')[0])
    def test_failed_diff_runs_all(self):
        with patch.object(selection.subprocess, 'check_output',
                          side_effect=subprocess.CalledProcessError(1, 'git')):
            self.assertTrue(selection.select('abc', 'def')[0])
    def test_nul_delimited_paths(self):
        with patch.object(selection.subprocess, 'check_output',
                          return_value=b'docs/api/a file.md\0'):
            self.assertFalse(selection.select('abc', 'def')[0])


    def test_real_git_diff_docs_shared_and_deleted(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(['git', '-C', directory, *args], stderr=subprocess.PIPE).decode().strip()
            git('init')
            git('config', 'user.name', 'Selection test')
            git('config', 'user.email', 'selection@example.invalid')
            (root / 'docs').mkdir()
            (root / 'docs/note.md').write_text('before')
            (root / 'shared.dm').write_text('// before')
            git('add', '.')
            git('commit', '-m', 'base')
            base = git('rev-parse', 'HEAD')
            (root / 'docs/note.md').write_text('after')
            git('add', '.')
            git('commit', '-m', 'docs')
            docs = git('rev-parse', 'HEAD')
            previous = os.getcwd()
            try:
                os.chdir(root)
                self.assertFalse(selection.select(base, docs)[0])
                (root / 'shared.dm').unlink()
                git('add', '-A')
                git('commit', '-m', 'delete shared include')
                self.assertTrue(selection.select(docs, git('rev-parse', 'HEAD'))[0])
            finally:
                os.chdir(previous)

if __name__ == '__main__':
    unittest.main()
