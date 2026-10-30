"""Offline source-binding checks. Never compile or start a game."""
import argparse
import ast
from contextlib import redirect_stdout
import hashlib
import importlib.util
import io
import json
import re
from pathlib import Path
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch


HERE = Path(__file__).resolve().parent
SOURCE_ROOT = HERE.parents[1]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


progress = load('progress_source_test', 'build-progress-probe.py')
backend = load('backend_source_test', 'build-gaia-phase-backend.py')


class ProgressSources(unittest.TestCase):
    def test_phase_negative_results_do_not_fall_through_to_positive_check(self):
        # Execute the runner's actual result dispatcher without compiling DM.
        tree = ast.parse((HERE / 'run-string-path.py').read_text())
        main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'main')
        dispatch = next(node for node in main.body if isinstance(node, ast.If)
                        and isinstance(node.test, ast.Attribute)
                        and node.test.attr == 'phase_profile_attribution_negative_control')
        dispatch_nodes = []
        for node in main.body[main.body.index(dispatch):]:
            if not isinstance(node, ast.If):
                break
            dispatch_nodes.append(node)
        executable = compile(ast.Module(body=dispatch_nodes, type_ignores=[]), '<result-dispatch>', 'exec')
        marker = self.root / 'map_saves/save_complete.txt'
        marker.parent.mkdir()
        marker.write_text('completed generation')
        for control, failure in (
            ('phase_profile_attribution_negative_control', 'phase category attribution failed'),
            ('phase_profile_negative_control', 'phase value calls missing'),
        ):
            with self.subTest(control=control):
                arguments = SimpleNamespace(phase_profile_attribution_negative_control=False,
                                            phase_profile_negative_control=False)
                setattr(arguments, control, True)
                environment = dict(args=arguments, output=self.root, actual='FAIL: expected control',
                                   read=lambda path: failure)
                exec(executable, environment)
                environment['read'] = lambda path: 'unrelated failure'
                with self.assertRaisesRegex(RuntimeError, 'Wrong .* negative failure'):
                    exec(executable, environment)

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='civ13-progress-sources-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.output = self.root / 'generated'
        self.inputs = {}
        paths = dict(saving='code/modules/persistence/saving.dm',
                     functions='code/modules/persistence/functions.dm',
                     tick='code/__defines/_tick.dm')
        for name, relative in paths.items():
            data = (SOURCE_ROOT / relative).read_bytes()
            path = self.root / (name + '.dm')
            path.write_bytes(data)
            self.inputs[name] = (path, data)

    def arguments(self, hashes=True):
        arguments = ['source-test', '--output-dir', str(self.output)]
        for name, (path, data) in self.inputs.items():
            arguments += ['--' + name + '-source', str(path)]
            if hashes:
                arguments += ['--expected-' + name + '-sha256',
                              hashlib.sha256(data).hexdigest()]
        return arguments

    def test_source_bound_output_preserves_functions_and_inputs(self):
        with patch.object(sys, 'argv', self.arguments() + ['--phase-profile']):
            with redirect_stdout(io.StringIO()):
                progress.main()
        manifest = json.loads((self.output / 'manifest.json').read_text())
        self.assertTrue(manifest['phase_profile'])
        self.assertEqual((self.output / 'functions.dm').read_bytes(),
                         self.inputs['functions'][1])
        generated = (self.output / 'saving.dm').read_text()
        self.assertIn('/map_storage/proc/world_save_profile_original_BuildVarDirectory(', generated)
        self.assertIn('/map_storage/proc/world_save_profile_original_encode_saved_value(', generated)
        for name, (path, original) in self.inputs.items():
            self.assertEqual(path.read_bytes(), original)
            self.assertEqual(manifest['sources'][name]['sha256'],
                             hashlib.sha256(original).hexdigest())
        for name, expected in manifest['generated'].items():
            self.assertEqual(hashlib.sha256((self.output / name).read_bytes()).hexdigest(), expected)

    def test_current_admission_precedes_profile_and_is_not_wrapped(self):
        saving = self.inputs['saving'][1].decode().replace('\r\n', '\n')
        if 'save_world_contents(' not in saving:
            self.skipTest('Legacy source has no operation-admission boundary')
        generated, _ = progress.instrument(saving, '', phase_profile=True)
        self.assertIn('/map_storage/proc/Save_World()\n\treturn run_world_operation("save")\n', generated)
        self.assertNotIn('world_save_progress_original_Save_World', generated)
        self.assertEqual(generated.count('operation.enter_contents(src, "save")'), 1)
        self.assertIn('if(!operation || !operation.enter_contents(src, "save")) return FALSE\n\tworld_save_progress_begin()\n', generated)
        for broken in ('', '\treturn TRUE\n'):
            with self.assertRaisesRegex(ValueError, 'Expected'):
                progress.instrument(saving.replace('\tif(!operation || !operation.enter_contents(src, "save")) return FALSE\n', broken), '', True)

    def test_wrong_source_hash_rejects_before_creating_outputs(self):
        for name in self.inputs:
            with self.subTest(source=name):
                arguments = self.arguments()
                index = arguments.index('--expected-' + name + '-sha256') + 1
                arguments[index] = '0' * 64
                with patch.object(sys, 'argv', arguments):
                    with self.assertRaisesRegex(ValueError, name + ' source hash mismatch'):
                        progress.main()
                self.assertFalse(self.output.exists())

    def test_missing_and_duplicate_anchors_reject(self):
        saving = self.inputs['saving'][1].decode().replace('\r\n', '\n')
        functions = self.inputs['functions'][1].decode().replace('\r\n', '\n')
        for anchor in ('/map_storage/proc/Save_World()\n',
                       '/map_storage/proc/encode_saved_value(savefile/F, value)\n',
                       '\tTICK_CHECK\n'):
            for duplicate in (False, True):
                with self.subTest(anchor=anchor, duplicate=duplicate):
                    changed = saving.replace(anchor, anchor + anchor if duplicate else '', 1)
                    with self.assertRaisesRegex(ValueError, 'Expected'):
                        progress.instrument(changed, functions, phase_profile=True)

    def test_legacy_backend_rejects_unfrozen_source_before_git_or_outputs(self):
        path, original = self.inputs['saving']
        path.write_bytes(original + b'\n// Deliberately outside the frozen legacy closure.\n')
        arguments = self.arguments(hashes=False) + ['--repository', str(SOURCE_ROOT)]
        with patch.object(sys, 'argv', arguments):
            with patch.object(backend.subprocess, 'run', side_effect=AssertionError('Unexpected Git access')):
                with self.assertRaisesRegex(ValueError, 'saving frozen source mismatch'):
                    backend.main()
        self.assertFalse(self.output.exists())


def project_player_status(source, name):
    """Execute only the fixed-return DM status helper; reject unknown syntax."""
    header = '/proc/' + name + '(list/state)\n'
    body = source.split(header, 1)[1].split('\n/', 1)[0]
    lines = ['def projected(state):']
    for raw in body.splitlines():
        if not raw.strip() or raw.lstrip().startswith('//'):
            continue
        depth = len(raw) - len(raw.lstrip('\t'))
        line = raw.strip()
        branch = re.fullmatch(r'if\((.*)\)(?: return ("[^"]*"))?', line)
        returned = re.fullmatch(r'return ("[^"]*")', line)
        if branch:
            condition = branch.group(1).replace('||', ' or ').replace('&&', ' and ')
            condition = re.sub(r'!(?!=)', 'not ', condition)
            statement = 'if ' + condition + ':'
            if branch.group(2):
                statement += ' return ' + repr(ast.literal_eval(branch.group(2)))
        elif returned:
            statement = 'return ' + repr(ast.literal_eval(returned.group(1)))
        else:
            raise AssertionError('Unsupported status statement: ' + line)
        lines.append('    ' * depth + statement)
    namespace = {'GAME_STATE_PLAYING': 3}
    exec('\n'.join(lines), namespace)
    return namespace['projected']


class PlayerStatusSources(unittest.TestCase):
    def setUp(self):
        self.world = (SOURCE_ROOT / 'code/world.dm').read_text(encoding='utf-8')
        self.panel = (SOURCE_ROOT / 'code/modules/statpanel/statpanel.dm').read_text(encoding='utf-8')
        self.functions = (SOURCE_ROOT / 'code/modules/persistence/functions.dm').read_text(encoding='utf-8')
        self.setup = (SOURCE_ROOT / 'code/setup.dm').read_text(encoding='utf-8')
        self.lobby = (SOURCE_ROOT / 'code/game/mob/new_player/new_player.dm').read_text(encoding='utf-8')
        self.activity = project_player_status(self.world, 'player_world_activity')
        self.join = project_player_status(self.world, 'player_join_status')
        self.ready = dict(recovery_hold=False, kind=None, phase=None, startup_pending=False,
                          restart_hold=False, restart_busy=False, restart_phase=None,
                          persistence_busy=False, lifecycle_busy=False, maintenance_pending=False,
                          ticker_known=True, map_known=True, round_state=3, players_can_join=True,
                          entry_status='open', character_unconfirmed=False)

    def test_phases_and_hold_take_precedence_without_percentages(self):
        cases = [
            ({'kind':'save','phase':'admitted'}, 'Preparing a world save.'),
            ({'kind':'save','phase':'capture'}, 'Saving the world.'),
            ({'kind':'save','phase':'candidate_validation'}, 'Validating the world save.'),
            ({'kind':'save','phase':'write_marker'}, 'Finishing the world save.'),
            ({'kind':'load','phase':'preflight'}, 'Validating and preparing the saved world.'),
            ({'kind':'load','phase':'allocate_levels'}, 'Validating and preparing the saved world.'),
            ({'kind':'load','phase':'restore'}, 'Loading the saved world.'),
            ({'kind':'load','phase':'metadata'}, 'Restoring world state.'),
            ({'kind':'load','phase':'players'}, 'Restoring player readiness.'),
            ({'startup_pending':True}, 'Preparing world recovery.'),
            ({'restart_busy':True,'restart_phase':'post_save_validation'}, 'Validating the saved world.'),
            ({'restart_busy':True,'restart_phase':'intent_publication'}, 'Preparing the saved world for restart.'),
            ({'restart_busy':True,'restart_phase':'shutdown'}, 'Server shutdown is in progress.'),
            ({'maintenance_pending':True}, 'Maintenance requested, shutdown is not yet confirmed.'),
            ({'recovery_hold':True,'kind':'load'}, 'World recovery needs administrator attention.'),
        ]
        for change, expected in cases:
            with self.subTest(change=change):
                value = self.activity(self.ready | change)
                self.assertEqual(value, expected)
                self.assertNotIn('%', value)
                self.assertNotIn(';', value)

    def test_join_text_distinguishes_holds_and_global_gates(self):
        cases = [
            ({'recovery_hold':True}, 'World recovery needs administrator attention.'),
            ({'kind':'load'}, 'World is loading - please wait before joining.'),
            ({'kind':'save'}, 'World is saving - joining may be delayed.'),
            ({'startup_pending':True}, 'World recovery is pending - please wait.'),
            ({'restart_busy':True}, 'Joining is paused for maintenance - please wait.'),
            ({'ticker_known':False}, 'Server is starting - please wait.'),
            ({'round_state':1}, 'Round has not started - please wait.'),
            ({'round_state':4}, 'Round has finished - wait for the next round.'),
            ({'players_can_join':False}, 'Joining is temporarily unavailable.'),
            ({'entry_status':'unknown'}, 'Joining status is unavailable.'),
            ({'entry_status':'locked'}, 'Joining is locked by an administrator.'),
            ({'character_unconfirmed':True}, 'Character recovery is not confirmed - joining may be delayed.'),
        ]
        for change, expected in cases:
            with self.subTest(change=change):
                value = self.join(self.ready | change)
                self.assertEqual(value, expected)
                self.assertNotIn(';', value)
        self.assertIn('checks still apply', self.join(self.ready))

    def test_public_labels_never_echo_error_or_phase_data(self):
        private = self.ready | {'kind':'load', 'phase':'private/path:12 secret 99,99',
                                'error':'private/path:12 secret 99,99'}
        for value in (self.activity(private), self.join(private)):
            self.assertNotIn('secret', value)
            self.assertNotIn('private/path', value)
            self.assertNotIn('99,99', value)
            self.assertNotIn(';', value)
        observation = self.world.split('/proc/player_status_observation()\n', 1)[1].split('\n/proc/', 1)[0]
        self.assertIn('map_storage.player_restoration_blocked()', observation)
        self.assertIn('persistence_restart.diagnostic_phase == "readiness_unconfirmed" && !persistence_player_restore_ready', observation)
        for signal in ('persistence_load_recovery_required', 'dimension_recovery_required',
                       'dimension_budget_hold', 'persistence_startup_recovery_status',
                       'persistence_active_operation', 'P.diagnostic_phase',
                       'persistence_restart.startup_hold', 'persistence_restart.busy',
                       'persistence_restart.diagnostic_phase', 'readiness_unconfirmed',
                       'persistence_save_in_progress', 'nomads_lifecycle.maintenance_operation',
                       'ticker.players_can_join', 'GLOB.enter_allowed', 'persistence_player_restore_ready'):
            with self.subTest(signal=signal):
                self.assertIn(signal, observation)
        for forbidden in ('last_error', 'last_save_reference_failure', 'agent_diagnostic_state', 'file2text', 'fexists'):
            self.assertNotIn(forbidden, observation)

    def test_status_surfaces_share_fixed_labels_and_preserve_legacy_order(self):
        self.assertIn('player_world_activity(player_status)', self.panel)
        self.assertIn('player_join_status(player_status)', self.panel)
        packaged = self.world.split('/proc/get_packaged_server_status_data()\n', 1)[1].split('\n/proc/', 1)[0]
        self.assertIn('"<b>Server Status</b>: Online"', packaged)
        fields = ['<b>Server Status</b>', '<b>Address</b>', '<b>Map</b>', '<b>Gamemode</b>',
                  '<b>Players</b>', 'realtime=', 'world.address=', 'round_timer=', 'map=',
                  'epoch=', 'season=', 'ckey_list=', 'allow_vote_restart=',
                  '<b>World activity</b>', '<b>Joining</b>']
        indexes = [packaged.index(field) for field in fields]
        self.assertEqual(indexes, sorted(indexes))
        self.assertLess(packaged.index('allow_vote_restart='), packaged.index('<b>World activity</b>'))
        self.assertLess(packaged.index('<b>World activity</b>'), packaged.index('<b>Joining</b>'))
        self.assertIn('hub_status_text(player_world_activity(player_status))', self.world)
        loop = self.world.split('/proc/start_serverdata_loop()\n', 1)[1].split('\nvar/global/', 1)[0]
        self.assertIn('world.update_status()', loop)
        self.assertIn('if(current_player_status != last_player_status)', loop)
        self.assertIn('sleep (100)', loop)

    def test_failed_player_readiness_blocks_success_and_announcement(self):
        load = self.functions.split('/datum/controller/gameticker/proc/loadmap(', 1)[1].split('\n/map_storage/proc/capture_round_state', 1)[0]
        guard = 'if(!storage.finish_player_restoration())\n\t\t\t\tthrow EXCEPTION("Player restoration readiness was not confirmed")'
        self.assertIn(guard, load)
        self.assertLess(load.index(guard), load.index('operation.finish(TRUE)'))
        failure = load.split('catch(var/exception/e)', 1)[1]
        self.assertLess(failure.index('operation.finish(FALSE)'), failure.index('return FALSE'))
        finish = self.functions.split('\tproc/finish(success)\n', 1)[1].split('\n/datum/', 1)[0]
        self.assertRegex(finish, r'if\(!success && kind == "load" && mutation_started\)\s+persistence_load_recovery_required = TRUE')
        self.assertIn('persistence_startup_recovery_status = null', load)
        self.assertRegex(self.setup, r'if\(ticker\.loadmap\(\)\) announce_restored_round_once\(\)\s+else persistence_startup_recovery_status = "unresolved"')
        self.assertIn('persistence_startup_recovery_status = "pending"', self.setup)

        fixture = (SOURCE_ROOT / 'tests/world_save_operations/probe.dm').read_text(encoding='utf-8')
        callback = fixture.split('\tfinish_player_restoration()\n', 1)[1].split('\n\tclear_bookkeeping()', 1)[0]
        self.assertIn('if(mode == "player-readiness-false") return FALSE', callback)
        self.assertIn('var/ready = ..()', callback)
        self.assertIn('if(!ready) return FALSE', callback)
        self.assertTrue(callback.rstrip().endswith('return TRUE'))
        self.assertIn('unconfirmed player readiness retains recovery hold', fixture)

    def test_early_join_rejection_records_only_a_still_owned_lobby(self):
        handler = self.lobby.split('/mob/new_player/proc/handle_lobby_join(', 1)[1].split('\n/mob/new_player/proc/clear_lobby_join', 1)[0]
        self.assertRegex(handler, r'if\(!map_storage\.allow_new_character\(src\)\)\s+//[^\n]*\n\s*//[^\n]*\n\s*if\(!QDELETED\(src\) && client && client\.mob == src\) lobby_join_trace\("handler_denied", "character_or_recovery_hold"\)\s+return FALSE')
        self.assertLess(handler.index('allow_new_character(src)'), handler.index('handler_entered'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root', type=Path, default=SOURCE_ROOT)
    arguments, remaining = parser.parse_known_args()
    SOURCE_ROOT = arguments.source_root.resolve(strict=True)
    unittest.main(argv=[sys.argv[0], *remaining])
