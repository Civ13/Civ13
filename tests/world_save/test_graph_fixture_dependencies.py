"""Minimal graph compile dependencies only; no native processes or sockets."""
from contextlib import redirect_stdout
import importlib.util
import io
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
SIGNATURES = ('/map_storage/proc/capture_zone_descriptor(area/A)',
              '/map_storage/proc/validate_zone_reference(id, type)')
REFUSAL = 'throw EXCEPTION("Topology needs the full-source fixture")'


def load(name):
    spec = importlib.util.spec_from_file_location('dependency_'+name, HERE/name)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


def closure(path):
    """Resolve quoted include files, without pretending to preprocess DM."""
    sources = {}
    def visit(path):
        path = path.resolve(strict=True)
        if path in sources: return
        text = path.read_text(encoding='utf-8-sig'); sources[path] = text
        for include in re.findall(r'^#include "([^"]+)"', text, re.M):
            visit(path.parent/include.replace('\\', '/'))
    visit(path)
    return '\n'.join(sources.values())


class GraphFixtureDependencies(unittest.TestCase):
    def setUp(self):
        self.spawn = self.enterContext(patch.object(subprocess, 'Popen', side_effect=AssertionError('Native process forbidden')))
        self.enterContext(patch.object(socket, 'socket', side_effect=AssertionError('Socket forbidden')))

    def check(self, text):
        for signature in SIGNATURES:
            self.assertEqual(text.count(signature+'\n'), 1, signature)
            body = text.split(signature+'\n', 1)[1].split('\n/', 1)[0]
            instructions = [line.strip() for line in body.splitlines()
                            if line.strip() and not line.lstrip().startswith('//')]
            self.assertEqual(instructions, [REFUSAL], signature)
        for field in ('zone_export_state', 'restored_zones'):
            declarations = re.findall(r'(?m)^(?:/map_storage/|\t)var/list/'+field+r'(?: = list\(\))?$', text)
            self.assertEqual(len(declarations), 1, field)
        self.assertEqual(text.count('/area/var/tmp/persistence_zone_id\n'), 1)

    def git(self, command, **kwargs):
        self.assertEqual(command[0], 'git')
        self.assertIn(command[1], ('rev-parse', 'diff'))
        return 'offline-preparation\n' if kwargs.get('text') else b''

    def test_shared_fixture_dependencies_stay_unique_and_fail_closed(self):
        for name in ('roundtrip.dme', 'dimension_bootstrap.dme', 'string_path_roundtrip.dme', 'immutable_capture.dme'):
            with self.subTest(name=name): self.check(closure(HERE/name))
        self.spawn.assert_not_called()

    def test_cross_level_and_all_sleep_preparations_keep_dependencies_without_launching(self):
        cross = load('run-cross-level.py'); sleep = load('run-sleep-transfer.py')
        for module in (cross, sleep):
            for control in (None, *module.CONTROLS):
                with self.subTest(module=module.__name__, control=control), tempfile.TemporaryDirectory() as directory, \
                     patch.object(subprocess, 'check_output', side_effect=self.git):
                    output = Path(directory); receipt = module.prepare(output, control)
                    self.check(closure(output/'probe.dme'))
                    self.assertTrue(receipt['prepared_only']); self.assertFalse(receipt['native_verified'])
        self.spawn.assert_not_called()

    def test_selected_standalone_graph_variants_keep_dependencies_without_launching(self):
        runner = load('run-durable-graph.py')
        modes = ((), ('--alist',), ('--contracts',))
        controls = ('generation', 'alias', 'binding', 'alist-values', 'alist-kind', 'alist-alias', 'alist-binding',
                    'clock', 'omission', 'timer', 'infinity')
        variants = [*modes, *(('--negative-control', control) for control in controls)]
        for flags in variants:
            with self.subTest(flags=flags), tempfile.TemporaryDirectory() as directory:
                output = Path(directory)
                with patch.object(sys, 'argv', ['graph', '--prepare-only', *flags]), \
                     patch.object(runner.tempfile, 'mkdtemp', return_value=directory), redirect_stdout(io.StringIO()):
                    runner.main()
                self.check(closure(output/'probe.dme'))
        self.spawn.assert_not_called()

    def test_checker_rejects_missing_duplicate_and_permissive_dependency_adapters(self):
        text = (HERE/'durable_graph_probe.dm').read_text()
        self.check(text)
        for signature in SIGNATURES:
            block = signature+'\n\t'+REFUSAL+'\n'
            for changed in (text.replace(block, ''), text+block, text.replace(block, signature+'\n\treturn null\n')):
                with self.subTest(signature=signature), self.assertRaises(AssertionError): self.check(changed)
        for field in ('zone_export_state', 'restored_zones'):
            changed = re.sub(r'(?m)^/map_storage/var/list/'+field+r'.*\n', '', text)
            with self.subTest(field=field), self.assertRaises(AssertionError): self.check(changed)
        self.spawn.assert_not_called()


if __name__ == '__main__': unittest.main()
