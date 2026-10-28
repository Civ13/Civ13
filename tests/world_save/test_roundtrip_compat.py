"""Offline source/preparation contracts; never compile or execute the DM world."""
import ast
import hashlib
import json
from pathlib import Path
import re
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / 'tests/world_save'


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
                self.assertEqual(len(includes), 12)
                for path in includes:
                    self.assertTrue(Path(path).is_file(), path)
                self.assertIn(str(HERE / 'roundtrip_compat.dm'), includes)
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
        self.assertIn('var/global/list/area_list = list()', adapter)
        self.assertIn('var/global/list/area_list = list()', globals_source)
        self.assertIn('area_list |= A', procedure(production, '/proc/persistence_register_area'))
        self.assertIn('area_list -= A', procedure(production, '/proc/persistence_unregister_area'))
        self.assertEqual(procedure(adapter, '/area/New'), '/area/New()\n\t..()\n\tarea_list |= src')
        # qdel in the frozen fixture immediately calls del(D); it never invokes Destroy.
        self.assertEqual(procedure(adapter, '/area/Del'), '/area/Del()\n\tarea_list -= src\n\t..()')
        self.assertEqual(procedure((HERE / 'stubs.dm').read_text(), '/proc/qdel'),
                         '/proc/qdel(datum/D)\n\tdel(D)')

    def test_snow_defaults_and_projection_match_production_exactly(self):
        adapter = (HERE / 'roundtrip_compat.dm').read_text()
        production = (ROOT / 'code/modules/1713/snowfall_ground.dm').read_text()
        for declaration in ('var/weather_snow = 0 // Durable generated loose-snow units; authored snow uses available_snow.',
                            'var/tmp/image/weather_snow_overlay = null'):
            self.assertIn(declaration, adapter)
            self.assertIn(declaration, production)
        self.assertEqual(procedure(adapter, '/turf/proc/snowfall_ground_icon'),
                         procedure(production, '/turf/proc/snowfall_ground_icon'))
        loading = (ROOT / 'code/modules/persistence/loading.dm').read_text()
        self.assertIn('restored_turf.weather_snow = 0\n\t\t\trestored_turf.snowfall_ground_icon()', loading)
        self.assertIn('map_storage_saved_vars = "name;dir"', (HERE / 'roundtrip.dm').read_text())

    def test_no_roof_gameplay_or_topology_bypass_added(self):
        adapter = (HERE / 'roundtrip_compat.dm').read_text()
        self.assertIn('\n/area/caribbean/roofed\n', adapter)
        for forbidden in (r'^/obj/roof', r'^/area/caribbean/roofed/', r'^/map_storage',
                          r'^/world', r'^/turf/proc/snowfall_ground_check'):
            self.assertIsNone(re.search(forbidden, adapter, re.M), forbidden)
        loading = (ROOT / 'code/modules/persistence/loading.dm').read_text()
        self.assertIn('if(!ispath(roof_root)) return // Serializer-only fixtures can omit roofs.', loading)
        self.assertIn('if(found) throw EXCEPTION("Ambiguous current roof area identity")', loading)
        stubs = (HERE / 'stubs.dm').read_text()
        self.assertIn('if(islist(state) && state["schema"] == 2) throw EXCEPTION("Topology needs the full-source fixture")', stubs)
        self.assertEqual(procedure(stubs, '/map_storage/proc/restore_zone_topology'),
                         '/map_storage/proc/restore_zone_topology()\n\tthrow EXCEPTION("Topology needs the full-source fixture")')

    def test_shared_historical_stubs_pin_and_engine_gate_unchanged(self):
        inputs = json.loads((HERE / 'character_return/inputs.json').read_text())
        self.assertEqual(hashlib.sha256((HERE / 'stubs.dm').read_bytes()).hexdigest(),
                         inputs['sha256']['tests/world_save/stubs.dm'])
        runner = (HERE / 'run-round-metadata.py').read_text()
        self.assertIn("if '516.1681' not in build or '0 errors, 0 warnings' not in build:", runner)


if __name__ == '__main__':
    unittest.main()
