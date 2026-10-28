"""Source boundaries only; not evidence of native restore acceptance."""
from pathlib import Path
import importlib.util
import tempfile
import unittest
import re

ROOT = Path(__file__).resolve().parents[2]


class RestoreIntegrationSources(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.functions = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        cls.wrapper = cls.functions.split('/datum/controller/gameticker/proc/loadmap(', 1)[1].split('/map_storage/proc/capture_round_state(', 1)[0]

    def test_admission_encloses_custody_and_failed_mutation_keeps_hold(self):
        self.assertLess(self.wrapper.index('begin_persistence_operation'), self.wrapper.index('policy.begin_attempt'))
        self.assertLess(self.wrapper.index('attempt.fail('), self.wrapper.index('operation.finish(FALSE)'))
        self.assertIn('operation.mutation_started && outcome.recovery_retained != TRUE', self.wrapper)
        self.assertIn('if(!success && kind == "load" && mutation_started)\n\t\t\tpersistence_load_recovery_required = TRUE', self.functions)
        self.assertNotIn('persistence_save_in_progress = FALSE', self.wrapper)

    def test_dimensions_use_owned_custody_before_growth(self):
        dimensions = self.functions.split('/map_storage/proc/prepare_saved_dimensions(', 1)[1]
        self.assertLess(dimensions.index('operation.authorize_restore_mutation(src)'), dimensions.index('operation.mutation_started = TRUE'))
        self.assertLess(dimensions.index('operation.mutation_started = TRUE'), dimensions.index('allocate_saved_level(z)'))
        self.assertIn('prepare_saved_dimensions(expected_intent, operation)', self.wrapper)

    def test_wrapper_cases_own_metadata_before_geographic_restore(self):
        source = (ROOT / 'tests/world_save/restore_wrapper.dm').read_text()
        case = source.split('/proc/wrapper_case(', 1)[1].split('/proc/check_restore_wrapper()', 1)[0]
        self.assertLess(case.index('fixture_map = new'), case.index('result = ticker.loadmap()'))
        self.assertEqual(case.count('map = original_map'), 2)
        self.assertEqual(case.count('if(fixture_map) qdel(fixture_map)'), 2)
        self.assertIn('check(result == expected', case)
        self.assertNotIn('/obj/map_metadata/proc/restore_elevation_snapshot', source)

    def test_master_geography_and_player_restore_remain_inside_custody(self):
        ordered = ('operation.authorize_restore_mutation(storage)',
                   'operation.mutation_started = TRUE',
                   'transaction.import_started = TRUE',
                   'map.restore_elevation_snapshot(', 'storage.begin_zone_restore(operation)',
                   'storage.suspend_durable_world()', 'invalidate_persistence_area_snapshots()',
                   'storage.ClearMap()', 'storage.run_world_operation("load", operation)',
                   'storage.load_map_metadata()', 'storage.restore_durable_world()',
                   'map.apply_persistence_age_floor()', 'storage.restore_round_state(src, saved_round)',
                   'storage.restore_zone_spawns()', 'storage.finish_player_restoration()',
                   'attempt.release_transients()')
        offsets = [self.wrapper.index(call) for call in ordered]
        self.assertEqual(offsets, sorted(offsets))
        # Neither the optional provider nor native callbacks may leak into saves.
        runtime = self.functions.split('/map_storage/persistence_runtime_var(key)', 1)[1].split('return ..()', 1)[0]
        for field in ('restore_policy', 'restore_cleanup_error', 'validated_roof_areas',
                      'validated_zone_state', 'zone_export_state', 'last_save_reference_failure'):
            self.assertIn('"' + field + '"', runtime)

    def test_startup_cannot_allocate_outside_admitted_wrapper(self):
        source = (ROOT / 'code/modules/persistence/restart_transaction.dm').read_text()
        self.assertNotIn('prepare_saved_dimensions(', source)
        self.assertIn('return ticker.loadmap(src, expected_intent)', source)
        self.assertIn('if(import_complete && !matches(I, current_identity()))', source)
        self.assertIn('transaction.matches(expected_intent, transaction.current_identity())', self.wrapper)

    def test_restart_fixture_has_production_client_list_and_preserves_transaction_controls(self):
        production = (ROOT / 'code/modules/persistence/restart_transaction.dm').read_text(encoding='utf-8')
        client_source = (ROOT / 'code/_helpers/global_lists.dm').read_text(encoding='utf-8')
        fixture = (ROOT / 'tests/world_save/restart_transaction_probe.dm').read_text(encoding='utf-8')
        declaration = 'var/list/clients = list()'
        self.assertEqual(len(re.findall(r'^' + re.escape(declaration) + r'(?=\s|$)', client_source, re.M)), 1)
        self.assertEqual(len(re.findall(r'^' + re.escape(declaration) + r'$', fixture, re.M)), 1)
        self.assertIn('if(clients.len)', production)
        self.assertIn('world.OpenPort("none")', fixture)
        self.assertNotRegex(fixture, r'(?m)^\s*clients\s*(?:\+=|-=|=)')
        lifecycle = (ROOT / 'tests/world_save/lifecycle_probe.dm').read_text(encoding='utf-8')
        self.assertNotRegex(lifecycle, r'(?m)^var/list/clients\b')
        lifecycle_runner = (ROOT / 'tests/world_save/run-lifecycle.py').read_text(encoding='utf-8')
        self.assertIn("base = (output / 'probe.dm').read_text(encoding='utf-8').split('/world/New()')[0]", lifecycle_runner)
        self.assertIn("(output / 'probe.dm').write_text(base + probe, encoding='utf-8')", lifecycle_runner)
        self.assertEqual(len(re.findall(r'^' + re.escape(declaration) + r'$', fixture.split('/world/New()')[0] + lifecycle, re.M)), 1)
        spec = importlib.util.spec_from_file_location('restart_fixture', ROOT / 'tests/world_save/run-restart-transaction.py')
        runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(runner)
        with tempfile.TemporaryDirectory(prefix='restart-fixture-source-') as directory:
            for control in (None, 'generation', 'consume', 'import', 'deferred-reboot'):
                with self.subTest(control=control):
                    output = Path(directory) / (control or 'positive')
                    output.mkdir()
                    receipt = runner.prepare(ROOT, output, control)
                    self.assertEqual(receipt['negative_control'], control)
                    self.assertEqual((output / 'probe.dm').read_text(encoding='utf-8'), fixture)
                    transaction = (output / 'transaction.dm').read_text(encoding='utf-8')
                    if control in (None, 'deferred-reboot'):
                        self.assertEqual(transaction, production)
                    else:
                        self.assertNotEqual(transaction, production)
                    self.assertIn('if(clients.len)', transaction)
                    self.assertIn('sleep(600)', transaction)
                    self.assertIn('#include "transaction.dm"', (output / 'probe.dme').read_text(encoding='utf-8'))

    def test_policy_callback_binding_is_rechecked(self):
        method = self.functions.split('proc/authorize_restore_mutation(', 1)[1].split('proc/current(', 1)[0]
        self.assertEqual(method.count('!current(expected_storage, "load")'), 2)
        self.assertEqual(method.count('restore_attempt != expected_attempt'), 2)
        self.assertLess(method.index('before_mutation()'), method.rindex('!current(expected_storage, "load")'))

    def test_both_loading_contracts_survive(self):
        source = (ROOT / 'code/modules/persistence/loading.dm').read_text()
        self.assertLess(source.index('operation.enter_contents(src, "load")'), source.index('surface_inventory.begin_world_inventory'))
        for required in ('register_restored_player(ob)', 'light_turf.recalc_atom_opacity()', 'light_owner.update_light()', 'surface_inventory.feed_loaded_level', 'surface_inventory.finish_world_inventory'):
            self.assertIn(required, source)

    def test_combined_native_probe_uses_production_startup(self):
        source = (ROOT / 'tests/world_save/durable_dimension_probe.dm').read_text()
        self.assertIn('persistence_restart.resume_startup()', source)
        self.assertIn('world.maxz == 2 && !persistence_restart.import_started', source)
        self.assertIn('persistence_load_recovery_required == !denied', source)
        self.assertNotIn('/load_generation(', source)
        self.assertNotIn('/prepare_saved_dimensions(', source)
        self.assertNotIn('/loadmap(', source)
        runner = (ROOT / 'tests/world_save/run-durable-world.py').read_text()
        for case in ('custody-success', 'custody-denied', 'custody-release'):
            self.assertIn(case, runner)
        self.assertIn('visibility = 0', runner)
        self.assertIn('offline fixture rejects native clients', runner)
        self.assertIn('return port == "none" ? ..("none") : 0', runner)

    def test_port_rewrite_is_standalone_and_preserves_rejection_expression(self):
        source = '\tworld.OpenPort(0)\n\t\tdurable_world_check(!world.port && !world.OpenPort(0), "reject")\n'
        # Exact runner pattern: never inject a statement into an expression.
        pattern = r'^(\t+)world\.OpenPort\((?:0|"none")\)$'
        runner = (ROOT / 'tests/world_save/run-durable-world.py').read_text()
        self.assertIn(pattern, runner)
        rewritten = re.sub(pattern, lambda match: match[1] + 'world.OpenPort("none")', source, flags=re.M)
        self.assertTrue(rewritten.startswith('\tworld.OpenPort("none")\n'))
        self.assertIn('!world.OpenPort(0)', rewritten)
        self.assertIn("if '/world/OpenPort(' not in probe:", runner)

    def test_shell_and_dynamic_binary_launchers_bind_loopback(self):
        shell = (ROOT / 'tests/world_save/run.sh').read_text()
        self.assertIn('"$daemon" roundtrip.dmb -ip 127.0.0.1 -nowebclient', shell)
        vote = (ROOT / 'tests/persistence_round/run.py').read_text()
        self.assertIn("[str(daemon), str(logs / generated[2].name), '-ip', '127.0.0.1', '-nowebclient',", vote)

    def test_every_roundtrip_environment_includes_wrapper(self):
        for path in (ROOT / 'tests/world_save').glob('*.dme'):
            source = path.read_text()
            if '#include "roundtrip.dm"' in source:
                self.assertIn('#include "restore_wrapper.dm"', source, str(path))

    def test_fixture_exercises_admitted_backend_and_recovery_hold(self):
        source = (ROOT / 'tests/world_save/restore_wrapper.dm').read_text()
        self.assertNotIn('\tLoad_World()', source)
        self.assertIn('operation.enter_contents(src, "load")', source)
        self.assertIn('persistence_load_recovery_required == (!expected && mutated)', source)
        self.assertIn('wrapper enters admitted contents once', source)


if __name__ == '__main__':
    unittest.main()
