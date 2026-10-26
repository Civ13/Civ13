"""Minimal fixture dependency/preparation checks; all process launches forbidden."""
import importlib.util
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / 'tests/world_save'


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def closure(path):
    """Read quoted include closures only; this is not a DM preprocessor."""
    sources = {}
    def visit(path):
        path = path.resolve(strict=True)
        if path in sources:
            return
        text = path.read_text(encoding='utf-8-sig')
        sources[path] = text
        for include in re.findall(r'^#include "([^"]+)"', text, re.M):
            visit(path.parent / include.replace('\\', '/'))
    visit(path)
    return list(sources.values())


class StubDependencies(unittest.TestCase):
    def setUp(self):
        self.spawn = self.enterContext(patch.object(subprocess, 'Popen',
            side_effect=AssertionError('Native process forbidden')))
        self.enterContext(patch.object(socket, 'socket', side_effect=AssertionError('Socket forbidden')))

    def check_dependencies(self, sources, roof_free=True):
        text = '\n'.join(sources)
        self.check_clear_ground(text)
        self.project_zone_restore(text)
        self.assertEqual(len(re.findall(r'^var/(?:global/)?list/area_list\s*=', text, re.M)), 1)
        self.assertEqual(len(re.findall(r'^/area/caribbean/roofed\s*$', text, re.M)), 1)
        if roof_free:
            self.assertNotRegex(text, r'(?m)^/obj/roof(?:/|\s|$)')
        self.assertIn('if(!ispath(roof_root)) return // Serializer-only fixtures can omit roofs.', text)
        self.assertIn('throw EXCEPTION("Ambiguous current roof area identity")', text)

    def project_zone_restore(self, text):
        signature = '/map_storage/proc/begin_zone_restore(datum/persistence_world_operation/operation)\n'
        self.assertEqual(text.count(signature), 1)
        body = text.split(signature,1)[1].split('\n/',1)[0]
        instructions = [line for line in body.splitlines() if line.strip() and not line.lstrip().startswith('//')]
        translations = {
            '\tif(isnull(validated_zone_state)) return': '    if state is None: return',
            '\tthrow EXCEPTION("Topology needs the full-source fixture")':
                '    raise RuntimeError("Topology needs the full-source fixture")'}
        self.assertEqual(len(instructions), 2)
        self.assertEqual(instructions[0], next(iter(translations)))
        namespace = {}
        exec('def restore(state):\n'+'\n'.join(translations[line] for line in instructions), namespace)
        return namespace['restore']

    def test_zone_restore_null_branch_matches_production_without_admitting_topology(self):
        production = (ROOT/'code/modules/persistence/zone_topology.dm').read_text()
        body = production.split('/map_storage/proc/begin_zone_restore(',1)[1].split('\n/map_storage/proc/',1)[0]
        self.assertIn('\n\tif(!validated_zone_state) return\n', body)
        self.assertLess(body.index('if(!validated_zone_state) return'), body.index('operation.current(src, "load")'))
        restore = self.project_zone_restore((FIXTURE/'stubs.dm').read_text())
        self.assertIsNone(restore(None))
        for state in ({'schema':2,'zones':[{'id':'zone:fixture:1'}]}, [], {}, [None], {'schema':'bad'}, 0, False, '', 'malformed', object()):
            with self.subTest(state=repr(state)), self.assertRaisesRegex(RuntimeError, '^Topology needs the full-source fixture$'):
                restore(state)
        self.spawn.assert_not_called()

    def test_zone_adapter_missing_guard_unconditional_success_and_missing_refusal_are_rejected(self):
        text = (FIXTURE/'stubs.dm').read_text()
        signature = '/map_storage/proc/begin_zone_restore(datum/persistence_world_operation/operation)\n'
        head, rest = text.split(signature,1)
        body, tail = rest.split('\n/',1)
        for changed in (body.replace('\tif(isnull(validated_zone_state)) return\n',''),
                        body.replace('isnull(validated_zone_state)','!validated_zone_state'),
                        body.replace('\tthrow EXCEPTION("Topology needs the full-source fixture")','\treturn'),
                        body+'\n\treturn'):
            with self.subTest(), self.assertRaises((AssertionError,KeyError)):
                self.project_zone_restore(head+signature+changed+'\n/'+tail)
        self.spawn.assert_not_called()

    def check_clear_ground(self, text):
        self.assertEqual(text.count('/turf/var/weather_snow = 0\n'), 1)
        self.assertEqual(text.count('/turf/proc/snowfall_ground_icon()\n'), 1)
        self.assertIn('if(!isnum(weather_snow) || weather_snow != 0)\n'
                      '\t\tthrow EXCEPTION("Generated snow requires the production snowfall fixture")', text)
        self.assertEqual(text.count('/turf/before_save()\n\tsnowfall_ground_icon()\n\treturn ..()'), 1)
        self.assertEqual(text.count('/turf/after_load()\n\t..()\n\tsnowfall_ground_icon()'), 1)
        self.assertNotIn('/turf/proc/snowfall_ground_check(', text)
        self.assertNotIn('var/tmp/image/weather_snow_overlay', text)
        self.assertNotIn("'icons/turf/snow.dmi'", text)

    def test_snow_adapter_guard_matches_clear_only_production_branch_and_rejects_other_states(self):
        text = (FIXTURE/'stubs.dm').read_text()
        condition, = re.findall(r'^\tif\(([^\n]+)\)\n\t\tthrow EXCEPTION\("Generated snow requires', text, re.M)
        expression = condition.replace('!isnum(weather_snow)', 'not isnum(value)').replace('weather_snow', 'value').replace('||', 'or')
        for value in (0, 0.0, 1, -1, None, '0', [], {}):
            rejected = eval(expression, {'__builtins__': {}}, dict(value=value, isnum=lambda x: type(x) in (int,float)))
            self.assertEqual(rejected, value not in (0, 0.0), repr(value))
        production = (ROOT/'code/modules/1713/snowfall_ground.dm').read_text()
        body = production.split('/turf/proc/snowfall_ground_icon()\n',1)[1].split('\n/turf/proc/',1)[0]
        self.assertIn('if (weather_snow_overlay)\n\t\toverlays -= weather_snow_overlay', body)
        self.assertTrue(body.rstrip().endswith('else\n\t\tweather_snow_overlay = null'))
        loader = (ROOT/'code/modules/persistence/loading.dm').read_text()
        self.assertIn('restored_turf.weather_snow = 0\n\t\t\trestored_turf.snowfall_ground_icon()', loader)
        self.spawn.assert_not_called()

    def test_snow_adapter_missing_duplicate_and_silent_acceptance_controls_are_rejected(self):
        text = '\n'.join(closure(FIXTURE/'roundtrip.dme'))
        for changed in (text.replace('/turf/var/weather_snow = 0\n', ''),
                        text+'\n/turf/var/weather_snow = 0\n',
                        text.replace('weather_snow != 0', 'FALSE'),
                        text.replace('/turf/before_save()\n\tsnowfall_ground_icon()', '/turf/before_save()\n\treturn'),
                        text.replace('/turf/after_load()\n\t..()\n\tsnowfall_ground_icon()', '/turf/after_load()\n\t..()')):
            with self.subTest(), self.assertRaises(AssertionError):
                self.check_clear_ground(changed)
        self.spawn.assert_not_called()

    def test_direct_include_consumers_have_unique_dependencies_and_remain_roof_free(self):
        for name in ('roundtrip.dme', 'string_path_roundtrip.dme', 'immutable_capture.dme'):
            with self.subTest(name=name):
                self.check_dependencies(closure(FIXTURE / name))
        self.spawn.assert_not_called()

    def test_dimension_consumer_keeps_its_existing_building_roof_types_without_duplicates(self):
        self.check_dependencies(closure(FIXTURE / 'dimension_bootstrap.dme'), roof_free=False)
        building = (ROOT / 'code/game/objects/building_levels.dm').read_text(encoding='utf-8')
        self.assertRegex(building, r'(?m)^/obj/roof\s*$')
        self.assertNotRegex((FIXTURE / 'stubs.dm').read_text(), r'(?m)^/obj/roof(?:/|\s|$)')
        self.spawn.assert_not_called()

    def test_dependency_checker_rejects_missing_duplicate_or_real_roof_declarations(self):
        sources = closure(FIXTURE / 'roundtrip.dme')
        text = '\n'.join(sources)
        for changed in (text.replace('var/list/area_list = list()', ''),
                        text.replace('/area/caribbean/roofed\n', ''),
                        text + '\nvar/list/area_list = list()\n',
                        text + '\n/area/caribbean/roofed\n',
                        text + '\n/obj/roof\n'):
            with self.subTest(), self.assertRaises(AssertionError):
                self.check_dependencies([changed])
        self.spawn.assert_not_called()

    def test_actual_round_metadata_preparation_retains_loader_before_forbidden_compile(self):
        runner = module('stub_round_metadata', FIXTURE / 'run-round-metadata.py')
        original = (ROOT / 'code/modules/persistence/loading.dm').read_bytes()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tools, output = root / 'inert-tools', root / 'prepared'
            tools.mkdir(); output.mkdir()
            for name in (('dm.exe', 'dd.exe') if os.name == 'nt' else ('DreamMaker', 'DreamDaemon')):
                (tools / name).write_bytes(b'inert file; never executable')
            with patch.object(sys, 'argv', ['run-round-metadata.py', '--byond-bin', str(tools)]), \
                    patch.object(runner.tempfile, 'mkdtemp', return_value=str(output)), patch('builtins.print'):
                with self.assertRaisesRegex(AssertionError, 'Native process forbidden'):
                    runner.main()
            self.spawn.assert_called_once()
            self.check_dependencies(closure(output / 'roundtrip.dme'))
            self.assertEqual((output / 'loading.dm').read_text(encoding='utf-8'),
                             original.decode('utf-8').replace('\r\n', '\n'))
            self.assertEqual(json.loads((output / 'cleanup.json').read_text()),
                             [{'role': 'compile', 'pid': None, 'exit': None, 'cancelled': False}])
            self.assertFalse(list(output.glob('*.dmb')))
            self.assertFalse((output / 'summary.json').exists())
        self.assertEqual((ROOT / 'code/modules/persistence/loading.dm').read_bytes(), original)

    def test_cross_level_preparer_keeps_dependencies_without_starting_processes(self):
        runner = module('stub_cross_level', FIXTURE / 'run-cross-level.py')
        def git_read(command, **kwargs):
            self.assertEqual(command[0], 'git')
            self.assertIn(command[1], ('rev-parse', 'diff'))
            return 'offline-identity\n' if kwargs.get('text') else b''
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(runner.subprocess, 'check_output', side_effect=git_read):
            output = Path(directory)
            receipt = runner.prepare(output)
            self.check_dependencies(closure(output / 'probe.dme'))
            self.assertTrue(receipt['prepared_only'])
            self.assertFalse(receipt['native_verified'])
        self.spawn.assert_not_called()

    def test_operation_preparer_keeps_dependencies_without_starting_processes(self):
        runner = module('stub_operations', ROOT / 'tests/world_save_operations/run.py')
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            with patch.object(sys, 'argv', ['run.py', '--prepare-only']), \
                    patch.object(runner.tempfile, 'mkdtemp', return_value=directory), patch('builtins.print'):
                runner.main()
            self.check_dependencies(closure(output / 'probe.dme'))
            self.assertFalse(list(output.glob('*.dmb')))
        self.spawn.assert_not_called()


if __name__ == '__main__':
    unittest.main()
