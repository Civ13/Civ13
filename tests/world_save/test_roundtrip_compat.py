"""Offline source/preparation contracts; never compile or execute the DM world."""
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / 'tests/world_save'
ZONE_OVERRIDE = '/map_storage/roundtrip_fixture/begin_zone_restore'
_adapter_spec = importlib.util.spec_from_file_location('roundtrip_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
_adapter = importlib.util.module_from_spec(_adapter_spec)
_adapter_spec.loader.exec_module(_adapter)


def procedure(source, path):
    """Read one complete top-level DM procedure, refusing conditional truncation."""
    matches = list(re.finditer(r'^' + re.escape(path) + r'\([^\n]*\)\n', source, re.M))
    if len(matches) != 1:
        raise ValueError('Expected one procedure: ' + path)
    start = matches[0].start()
    next_declaration = re.search(r'^/', source[matches[0].end():], re.M)
    end = matches[0].end() + next_declaration.start() if next_declaration else len(source)
    body = source[start:end].strip()
    if re.search(r'^\s*#', body, re.M):
        raise ValueError('Conditional procedure requires explicit handling')
    return body


def compatibility_blocks(source):
    """Extract only the two explicit roundtrip-scoped blocks; reject new directives."""
    marker = '#ifdef ROUNDTRIP_NO_TOPOLOGY_COMPAT'
    if re.findall(r'^#.*$', source, re.M) != [marker, '#endif', marker, '#endif']:
        raise ValueError('Roundtrip compatibility guards changed')
    blocks = re.findall(r'^' + marker + r'\n(.*?)^#endif\n', source, re.M | re.S)
    if len(blocks) != 2:
        raise ValueError('Expected setup and probe compatibility blocks')
    return blocks


def prepare_only(output, control=None):
    # Execute only the existing runner's contiguous source-generation block.
    # Do not import or call main(), inspect a BYOND install, or reach owned().
    source = (HERE / 'run-round-metadata.py').read_text()
    main = next(node for node in ast.parse(source).body
                if isinstance(node, ast.FunctionDef) and node.name == 'main')

    def assignment(node, name):
        return isinstance(node, ast.Assign) and any(
            isinstance(target, ast.Name) and target.id == name for target in node.targets)

    start = next(i for i, node in enumerate(main.body) if assignment(node, 'loader'))
    end = next(i for i, node in enumerate(main.body) if assignment(node, 'processes'))
    block = ast.Module(body=main.body[start:end], type_ignores=[])
    if any(isinstance(node, ast.Name) and node.id in ('subprocess', 'owned', 'compiler', 'daemon')
           for node in ast.walk(block)):
        raise ValueError('Preparation block gained a native dependency')
    namespace = {'root': ROOT, 'fixture': HERE, 'output': output,
                 'args': SimpleNamespace(negative_control=control),
                 'hashlib': hashlib, 're': re}
    with patch('subprocess.Popen', side_effect=AssertionError('process forbidden')), \
         patch('subprocess.run', side_effect=AssertionError('process forbidden')), \
         patch('subprocess.check_output', side_effect=AssertionError('process forbidden')):
        exec(compile(block, 'roundtrip-source-generation-only', 'exec'), namespace)
    return namespace


def require_roundtrip_topology_boundary(adapter, shared):
    """Exact source contract, not a DM interpreter or runtime acceptance."""
    expected = (ZONE_OVERRIDE + '(datum/persistence_world_operation/operation)\n'
                '\tif(isnull(validated_zone_state)) return\n\treturn ..()')
    if procedure(adapter, ZONE_OVERRIDE) != expected:
        raise ValueError('Roundtrip null-only topology dispatch changed')
    parent = '/map_storage/proc/begin_zone_restore'
    shared_body = '\n'.join(line for line in procedure(shared, parent).splitlines()
                            if not line.lstrip().startswith('//'))
    if shared_body != (parent + '(datum/persistence_world_operation/operation)\n'
                       '\tif(isnull(validated_zone_state)) return\n'
                       '\tthrow EXCEPTION("Topology needs the full-source fixture")'):
        raise ValueError('Shared topology refusal changed')


class RoundtripCompatibilityTests(unittest.TestCase):
    def test_real_runner_prepares_positive_and_all_exact_controls(self):
        expected = {None: 'PASS', 'restore': 'FAIL: round-mode flag lost: persistence',
                    'preflight': 'FAIL: invalid round extension passed preflight: partial',
                    'integrity': 'FAIL: modern metadata tamper passed preflight'}
        for control, result in expected.items():
            with self.subTest(control=control), tempfile.TemporaryDirectory() as temp:
                output = Path(temp)
                prepared = prepare_only(output, control)
                self.assertEqual(prepared['expected'], result)
                environment = (output / 'roundtrip.dme').read_text()
                includes = re.findall(r'^#include "([^"]+)"$', environment, re.M)
                self.assertEqual(len(includes), 13)
                for path in includes:
                    self.assertTrue(Path(path).is_file(), path)
                self.assertIn((HERE / 'roundtrip_compat.dm').as_posix(), includes)
                self.assertIn((HERE / 'restore_wrapper.dm').as_posix(), includes)
                key = 'tests/world_save/roundtrip_compat.dm'
                self.assertEqual(prepared['hashes'][key],
                                 hashlib.sha256((ROOT / key).read_bytes()).hexdigest())
                if control is None:
                    self.assertEqual((output / 'loading.dm').read_bytes(),
                                     (ROOT / 'code/modules/persistence/loading.dm').read_bytes())

    def test_compatibility_include_precedes_unmodified_loader(self):
        environment = (HERE / 'roundtrip.dme').read_text()
        self.assertEqual(environment.count('#include "roundtrip_compat.dm"'), 1)
        self.assertLess(environment.index('#include "stubs.dm"'),
                        environment.index('#include "roundtrip_compat.dm"'))
        self.assertLess(environment.index('#include "roundtrip_compat.dm"'),
                        environment.index('#include "../../code/modules/persistence/loading.dm"'))

    def test_area_registry_matches_ordinary_membership_and_immediate_deletion(self):
        adapter = (HERE / 'roundtrip_compat.dm').read_text()
        production = (ROOT / 'code/modules/persistence/zone_topology.dm').read_text()
        globals_source = (ROOT / 'code/_helpers/global_lists.dm').read_text()
        self.assertIn('var/list/area_list = list()', (HERE / 'stubs.dm').read_text())
        self.assertIn('var/global/list/area_list = list()', globals_source)
        self.assertIn('area_list |= A', procedure(production, '/proc/persistence_register_area'))
        self.assertIn('area_list -= A', procedure(production, '/proc/persistence_unregister_area'))
        self.assertEqual(procedure(adapter, '/area/New'), '/area/New()\n\t..()\n\tarea_list |= src')
        # qdel in the frozen fixture immediately calls del(D); it never invokes Destroy.
        self.assertEqual(procedure(adapter, '/area/Del'), '/area/Del()\n\tarea_list -= src\n\t..()')
        self.assertEqual(procedure((HERE / 'stubs.dm').read_text(), '/proc/qdel'),
                         '/proc/qdel(datum/D)\n\tdel(D)')

    def test_generated_packet_has_single_shared_dependency_declarations(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            prepare_only(output)
            includes = re.findall(r'^#include "([^"]+)"$', (output / 'roundtrip.dme').read_text(), re.M)
            packet = '\n'.join(Path(path).read_text() for path in includes)
            for name, pattern in (
                ('area_list', r'^var/(?:global/)?list/area_list\b'),
                ('weather_snow', r'^(?:\tvar/weather_snow|/turf/var/weather_snow)\b'),
                ('snowfall_ground_icon', r'^/turf/proc/snowfall_ground_icon\('),
            ):
                with self.subTest(declaration=name):
                    self.assertEqual(len(re.findall(pattern, packet, re.M)), 1)

    def test_shared_snow_adapter_rejects_nonzero_state_without_weather_simulation(self):
        adapter = (HERE / 'roundtrip_compat.dm').read_text()
        shared = (HERE / 'stubs.dm').read_text()
        production = (ROOT / 'code/modules/1713/snowfall_ground.dm').read_text()
        self.assertIn('var/weather_snow = 0', production)
        self.assertIn('/turf/var/weather_snow = 0', shared)
        self.assertEqual(procedure(shared, '/turf/proc/snowfall_ground_icon'),
                         '/turf/proc/snowfall_ground_icon()\n'
                         '\tif(!isnum(weather_snow) || weather_snow != 0)\n'
                         '\t\tthrow EXCEPTION("Generated snow requires the production snowfall fixture")\n'
                         '\treturn')
        self.assertNotIn('weather_snow_overlay', adapter)
        loading = (ROOT / 'code/modules/persistence/loading.dm').read_text()
        self.assertIn('restored_turf.weather_snow = 0\n\t\t\trestored_turf.snowfall_ground_icon()', loading)
        self.assertIn('map_storage_saved_vars = "name;dir"', (HERE / 'roundtrip.dm').read_text())

    def test_no_roof_gameplay_or_topology_bypass_added(self):
        adapter = (HERE / 'roundtrip_compat.dm').read_text()
        self.assertIn('\n/area/caribbean/roofed\n', (HERE / 'stubs.dm').read_text())
        for forbidden in (r'^/obj/roof', r'^/area/caribbean/roofed/',
                          r'^/world', r'^/turf/proc/snowfall_ground_check'):
            self.assertIsNone(re.search(forbidden, adapter, re.M), forbidden)
        self.assertEqual(re.findall(r'^/map_storage[^\n]*', adapter, re.M),
                         [ZONE_OVERRIDE + '(datum/persistence_world_operation/operation)'])
        loading = (ROOT / 'code/modules/persistence/loading.dm').read_text()
        self.assertIn('if(!ispath(roof_root)) return // Serializer-only fixtures can omit roofs.', loading)
        self.assertIn('if(found) throw EXCEPTION("Ambiguous current roof area identity")', loading)
        stubs = (HERE / 'stubs.dm').read_text()
        self.assertIn('if(islist(state) && state["schema"] == 2) throw EXCEPTION("Topology needs the full-source fixture")', stubs)
        self.assertEqual(procedure(stubs, '/map_storage/proc/restore_zone_topology'),
                         '/map_storage/proc/restore_zone_topology()\n\tthrow EXCEPTION("Topology needs the full-source fixture")')
        require_roundtrip_topology_boundary(adapter, stubs)

    def test_null_only_dispatch_preserves_production_early_return_and_parent_refusal(self):
        adapter = (HERE / 'roundtrip_compat.dm').read_text()
        stubs = (HERE / 'stubs.dm').read_text()
        require_roundtrip_topology_boundary(adapter, stubs)
        production = procedure((ROOT / 'code/modules/persistence/zone_topology.dm').read_text(),
                               '/map_storage/proc/begin_zone_restore')
        self.assertEqual(production.splitlines()[1], '\tif(!validated_zone_state) return')
        self.assertLess(production.index('if(!validated_zone_state) return'), production.index('operation.current'))
        self.assertIn('var/list/validated_zone_state', stubs)
        self.assertEqual(procedure(stubs, '/map_storage/proc/clear_saved_zones'),
                         '/map_storage/proc/clear_saved_zones()\n\tvalidated_zone_state = null')

    def test_subtype_is_selected_before_helpers_without_changing_legacy_import_assertion(self):
        source = (HERE / 'roundtrip.dm').read_text()
        compatibility_blocks(source)
        start = procedure(source.replace('#ifdef ROUNDTRIP_NO_TOPOLOGY_COMPAT\n', '').replace('#endif\n', ''), '/world/New')
        setup = ('\t\tvar/map_storage/initial_storage = map_storage\n'
                 '\t\tmap_storage = new /map_storage/roundtrip_fixture(initial_storage.game_id)\n'
                 '\t\tqdel(initial_storage)\n\t\tcheck_roundtrip_topology_boundary()\n')
        self.assertEqual(start.count(setup), 1)
        self.assertLess(start.index(setup), start.index('check_datum_constructor()'))
        self.assertIn('write_legacy_fixture()\n\t\t\tcheck(ticker.loadmap(), "legacy fixture import failed")', start)
        functions = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        self.assertIn('var/map_storage/map_storage = new("SS13")', functions)
        # Select both explicitly known branches; unknown conditionals still fail.
        for enabled in (False, True):
            defines = {**_adapter.DEFAULT_DEFINES, 'CIV13_HUMAN_SPATIAL_EXPERIMENTAL': enabled}
            loadmap = _adapter.extract(functions, '/datum/controller/gameticker/proc/loadmap', defines=defines)
            self.assertIn('\tvar/map_storage/storage = map_storage\n', loadmap)
            self.assertIn('\t\tstorage.begin_zone_restore(operation)\n', loadmap)
            self.assertLess(loadmap.index('storage.begin_zone_restore(operation)'), loadmap.index('storage.ClearMap()'))
            self.assertEqual('operation.validate_human_direct_restores()' in loadmap, enabled)
        with self.assertRaisesRegex(AssertionError, 'Unknown conditional symbol'):
            _adapter.extract(functions.replace('#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL', '#ifdef UNREVIEWED_HUMAN_MODE'),
                             '/datum/controller/gameticker/proc/loadmap')
        pins = json.loads((HERE / 'character_return/inputs.json').read_text())['reference_sha256']
        self.assertEqual(len(pins), 20)
        self.assertNotIn('tests/world_save/roundtrip.dm', pins)
        self.assertNotIn('tests/world_save/roundtrip_compat.dm', pins)

    def test_future_native_probe_requires_null_success_and_empty_schema_one_two_rejection(self):
        probe = compatibility_blocks((HERE / 'roundtrip.dm').read_text())[1]
        source = procedure(probe, '/proc/check_roundtrip_topology_boundary')
        self.assertIn('check(isnull(probe.validated_zone_state), "roundtrip topology probe did not start empty")', source)
        self.assertLess(source.index('probe.begin_zone_restore(null)'), source.index('for(var/list/state'))
        self.assertIn('for(var/list/state in list(list(), list("schema" = 1), list("schema" = 2)))', source)
        self.assertIn('probe.validated_zone_state = state', source)
        self.assertIn('check("[topology_error]" == "Topology needs the full-source fixture", "unexpected roundtrip topology rejection")', source)
        self.assertIn('check(rejected, "roundtrip topology state was accepted")', source)
        self.assertIn('\n\tqdel(probe)', source)

    def test_other_fixture_includers_do_not_acquire_setup_or_probe(self):
        environment = (HERE / 'roundtrip.dme').read_text()
        self.assertEqual(environment.count('#define ROUNDTRIP_NO_TOPOLOGY_COMPAT\n'), 1)
        self.assertLess(environment.index('#define ROUNDTRIP_NO_TOPOLOGY_COMPAT'),
                        environment.index('#include "roundtrip.dm"'))
        string_path = (HERE / 'string_path_roundtrip.dme').read_text()
        self.assertIn('#include "roundtrip.dm"', string_path)
        self.assertNotIn('ROUNDTRIP_NO_TOPOLOGY_COMPAT', string_path)
        source = (HERE / 'roundtrip.dm').read_text()
        for block in compatibility_blocks(source):
            source = source.replace('#ifdef ROUNDTRIP_NO_TOPOLOGY_COMPAT\n' + block + '#endif\n', '', 1)
        self.assertNotIn('roundtrip_fixture', source)
        self.assertNotIn('check_roundtrip_topology_boundary', source)
        self.assertNotIn('check_roundtrip_topology_boundary', (HERE / 'roundtrip_compat.dm').read_text())
        floor = (ROOT / 'tests/floor_decal_tracking/prepare.py').read_text()
        self.assertIn("removed = {'roundtrip.dm', 'transfers.dm', 'player_reclaim_probe.dm', 'round_metadata.dm'}", floor)
        self.assertIn('if name in removed:\n            return', floor)

    def test_missing_null_guard_or_parent_delegation_is_rejected_offline(self):
        adapter = (HERE / 'roundtrip_compat.dm').read_text()
        stubs = (HERE / 'stubs.dm').read_text()
        for before, after in (('\tif(isnull(validated_zone_state)) return\n', ''),
                              ('\treturn ..()\n', '\treturn\n'),
                              ('if(isnull(validated_zone_state))', 'if(!validated_zone_state.len)'),
                              ('if(isnull(validated_zone_state))', 'if(!isnull(validated_zone_state))')):
            self.assertEqual(adapter.count(before), 1)
            with self.subTest(mutation=before), self.assertRaisesRegex(ValueError, 'null-only'):
                require_roundtrip_topology_boundary(adapter.replace(before, after, 1), stubs)

    def test_shared_topology_boundary_and_explicit_current_engine_selection(self):
        inputs = json.loads((HERE / 'character_return/inputs.json').read_text())
        self.assertIn('tests/world_save/stubs.dm', inputs['reference_sha256'])
        require_roundtrip_topology_boundary((HERE / 'roundtrip_compat.dm').read_text(),
                                           (HERE / 'stubs.dm').read_text())
        runner = (HERE / 'run-round-metadata.py').read_text()
        self.assertIn("parser.add_argument('--byond-archive'", runner)
        self.assertIn('selected_runtime(byond, args.byond_archive)', runner)
        self.assertIn('return module.select(bin_dir, archive)', runner)
        self.assertIn('runtime.validate_compile(', runner)

    def test_full_source_recovery_setup_uses_separate_safe_floor_identities(self):
        source = (HERE / 'recovery_reconnect_probe.dm').read_text()
        self.assertIn('/turf/floor/recovery_return/New()\n', source)
        self.assertIn('var/return_x = 2\n', source)
        self.assertIn('var/turf/floor/recovery_return/return_turf = new(locate(return_x,2,1))', source)
        self.assertIn('var/mob/living/human/durable_probe_leader/H = new(return_turf)\n\t\t\treturn_x++', source)
        accounts = re.search(r'for\(var/account in list\(([^\n]+)\)\)', source)[1].split(', ')
        self.assertEqual(len(accounts), 6)
        self.assertEqual(len(set(accounts)), 6)
        self.assertLess(2 + len(accounts) - 1, 8)
        self.assertNotIn('new(locate(2,2,1))', source)
        # Retain the causal recovery/ban/control assertions, not an admitted bypass.
        for anchor in ('!T.resume_startup() && T.import_complete',
                       'waiting authenticated client not reclaimed after recovery',
                       '!playing.transfers && !server.transfers && !guest.transfers',
                       'eligible waiting account could not reclaim retained body'):
            self.assertIn(anchor, source)


if __name__ == '__main__':
    unittest.main()
