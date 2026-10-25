"""Synthetic evidence only: these offline tests launch no compiler or daemon."""
import copy
import hashlib
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

import oracle
from prepare import ADAPTER, VERSION, VARIANTS, CONTROLS, HEAD, TREE

HERE = Path(__file__).resolve().parent
BINDING = 'a' * 64


def evidence(variant='baseline', phase='roundtrip'):
    rows = oracle.expected(variant, phase)
    failure = None if variant == 'baseline' else CONTROLS[variant][3]
    result = dict(schema=1, adapter=ADAPTER, candidate_manifest_sha256=BINDING,
                  version=VERSION, head=HEAD, tree=TREE, variant=variant, phase=phase, port=0,
                  status='passed' if failure is None else 'assertion-rejected',
                  failure=failure, assertions=rows)
    log = '\n'.join('WINTER1688_ASSERT ' + json.dumps(row) for row in rows)
    log += '\nWINTER1688_RESULT ' + variant + ':' + phase + '\n'
    return result, log


def proc(file, name):
    source = (HERE / file).read_text()
    marker = '/proc/' + name + '('
    if source.count(marker) != 1:
        raise ValueError('Ambiguous source procedure')
    return source.split(marker, 1)[1].split('\n', 1)[1].split('\n/proc/', 1)[0]


def labels(body):
    result = []
    for line in body.splitlines():
        if 'winter_check(' not in line:
            continue
        match = re.search(r'winter_check\(.*, "([^"\n]*)"\)\s*$', line)
        if not match:
            raise ValueError('Unreviewed assertion syntax')
        result.append(match[1])
    return result


def derive_inventory():
    """Reviewed finite expansion, not a DM interpreter. Hash pin rejects source drift."""
    setup = labels(proc('probe.dm', 'winter_setup'))
    body = proc('probe.dm', 'winter_fixture')
    for literal in ('for (var/trial = 1, trial <= 128, trial++)',
                    'for (var/biome_index = 1, biome_index <= biomes.len, biome_index++)',
                    'for (var/state_suffix in list("", "-seeds", "-grow1", "-grow2", "-grow3", "-grow4", "-grow5", "-grow6", "-harvest", "-dead"))'):
        if body.count(literal) != 1:
            raise ValueError('Reviewed loop changed')
    suffixes = ['', '-seeds', *[f'-grow{i}' for i in range(1, 7)], '-harvest', '-dead']
    biomes = ['sea', 'temperate', 'tundra', 'taiga', 'desert', 'semiarid', 'savanna', 'jungle']
    actual_biomes = re.search(r'var/list/biomes = list\(([^\n]+)\)', body)
    if not actual_biomes or re.findall(r'"([^"]+)"', actual_biomes[1]) != biomes:
        raise ValueError('Reviewed biome ordering changed')
    rows = labels(body)
    crop = []
    index = 0
    while index < len(rows):
        name = rows[index]
        if '[state_suffix]' in name or '[biomes[biome_index]]' in name:
            token, values = ('[state_suffix]', suffixes) if '[state_suffix]' in name else ('[biomes[biome_index]]', biomes)
            if index + 1 == len(rows) or token not in rows[index + 1]:
                raise ValueError('Loop assertion pairing changed')
            crop += [row.replace(token, value) for value in values for row in rows[index:index+2]]
            index += 2
        elif name == 'plump growth trial advances at most one stage':
            crop += [name] * 128
            index += 1
        else:
            if '[' in name:
                raise ValueError('Unreviewed interpolation')
            crop.append(name)
            index += 1
    bite = labels(proc('food-save.dm', 'winter_food_bite'))
    writer_body = proc('food-save.dm', 'winter_food_writer')
    reader_body = proc('food-save.dm', 'winter_food_reader')
    for food_body in (writer_body, reader_body):
        if food_body.count('var/list/kinds = list("turnip", "plump_helmet")') != 1:
            raise ValueError('Food kinds changed')
    writer = (bite + labels(writer_body)) * 2
    reader_rows = labels(reader_body)
    reader = reader_rows[:1] + reader_rows[1:] * 2
    return {'roundtrip': setup + crop + writer + reader,
            'writer': setup + writer, 'reader': setup + reader}


class WinterOracle(unittest.TestCase):
    def test_inventory_matches_ordered_fixture_expansion(self):
        inventory = oracle.inventory()
        self.assertEqual(inventory, derive_inventory())
        self.assertEqual({name: len(rows) for name, rows in inventory.items()},
                         {'roundtrip': 239, 'writer': 20, 'reader': 21})
        self.assertEqual(inventory['roundtrip'].count('plump growth trial advances at most one stage'), 128)
        self.assertEqual(inventory['roundtrip'].count('fresh winter produce contains two nutriment units'), 2)

    def test_wrapper_phase_order_and_single_setup(self):
        wrapper = (HERE / 'wrapper.dm').read_text()
        self.assertEqual(wrapper.count('\t\twinter_setup()\n'), 1)
        self.assertIn('\t\tswitch (winter_phase)\n'
                      '\t\t\tif ("roundtrip")\n'
                      '\t\t\t\twinter_fixture()\n'
                      '\t\t\t\twinter_food_roundtrip()\n'
                      '\t\t\tif ("writer")\n'
                      '\t\t\t\twinter_food_writer()\n'
                      '\t\t\tif ("reader")\n'
                      '\t\t\t\twinter_food_reader()\n', wrapper)
        self.assertNotIn('winter_check(', wrapper)
        self.assertEqual(wrapper.count('winter_record('), 1)
        self.assertIn('winter_food_writer()\n\twinter_food_reader()',
                      proc('food-save.dm', 'winter_food_roundtrip'))

    def test_exact_inventory_and_fixture_bytes_are_bound(self):
        original = Path.read_bytes
        for filename in ('expected-assertions.json', 'probe.dm', 'food-save.dm'):
            def changed(path, target=filename):
                raw = original(path)
                return raw + b'\n' if path.name == target else raw
            with self.subTest(filename=filename), patch.object(Path, 'read_bytes', changed), self.assertRaises(ValueError):
                oracle.inventory()

    def test_all_baseline_phases_and_exact_control_prefixes(self):
        for variant in VARIANTS:
            for phase in (oracle.COUNTS if variant == 'baseline' else ('roundtrip',)):
                result, log = evidence(variant, phase)
                verdict = oracle.verify_result(BINDING, variant, phase, result, log)
                self.assertEqual(verdict['status'], 'passed' if variant == 'baseline' else 'causal-control-detected')
                if variant != 'baseline':
                    self.assertEqual(result['assertions'][-1], {'name': CONTROLS[variant][3], 'ok': 0})
                    self.assertTrue(all(row['ok'] == 1 for row in result['assertions'][:-1]))

    def test_result_binding_schema_and_boolean_rejection(self):
        result, log = evidence()
        cases = [('schema', True), ('port', False), ('port', 1), ('head', 'b' * 40),
                 ('tree', 'c' * 40), ('version', '516.1681'), ('variant', 'hardiness'),
                 ('phase', 'reader'), ('adapter', 'wrong'), ('candidate_manifest_sha256', 'b' * 64),
                 ('status', 'fatal'), ('failure', 'unrelated')]
        for key, value in cases:
            altered = copy.deepcopy(result)
            altered[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                oracle.verify_result(BINDING, 'baseline', 'roundtrip', altered, log)
        for extra in ('legacy_result', 'unexpected'):
            altered = copy.deepcopy(result)
            altered[extra] = 'PASS'
            with self.assertRaises(ValueError):
                oracle.verify_result(BINDING, 'baseline', 'roundtrip', altered, log)
        for bad in (True, 1.0, '1', None):
            altered = copy.deepcopy(result)
            altered['assertions'][0]['ok'] = bad
            with self.subTest(ok=bad), self.assertRaises(ValueError):
                oracle.verify_result(BINDING, 'baseline', 'roundtrip', altered, log)

    def test_wrong_control_target_or_early_failure_rejected(self):
        for variant in CONTROLS:
            result, log = evidence(variant)
            altered = copy.deepcopy(result)
            altered['failure'] = 'different failure'
            with self.assertRaises(ValueError):
                oracle.verify_result(BINDING, variant, 'roundtrip', altered, log)
            altered = copy.deepcopy(result)
            altered['assertions'] = altered['assertions'][:-1]
            with self.assertRaises(ValueError):
                oracle.verify_result(BINDING, variant, 'roundtrip', altered, log)

    def test_missing_extra_reordered_or_bool_log_rows_rejected(self):
        result, log = evidence()
        lines = log.splitlines()
        variants = [lines[1:], lines[:1] + lines, lines[1:2] + lines[:1] + lines[2:],
                    lines[:-1], lines + [lines[-1]], [lines[-1]] + lines[:-1],
                    [lines[0].replace('"ok": 1', '"ok": true')] + lines[1:],
                    [lines[0].replace('"ok": 1', '"ok": 1.0')] + lines[1:],
                    [lines[0].replace('"ok": 1', '"ok": 0, "ok": 1')] + lines[1:]]
        for modified in variants:
            with self.subTest(log_head=modified[:2]), self.assertRaises(ValueError):
                oracle.verify_result(BINDING, 'baseline', 'roundtrip', result, '\n'.join(modified))

    def test_strict_json_rejects_duplicates_and_nonfinite(self):
        for raw in ('{"ok":0,"ok":1}', '{"value":NaN}', '{"value":Infinity}'):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                oracle.strict_json(raw)

    def test_fatal_auxiliary_diagnostics_and_partial_transcripts(self):
        result, log = evidence()
        for diagnostic in ('runtime error', 'warning: unused', 'WINTER1688_FATAL failure',
                           'FAIL: unexpected', 'cleanup failed', 'bad ref'):
            with self.subTest(diagnostic=diagnostic), self.assertRaises(ValueError):
                oracle.verify_result(BINDING, 'baseline', 'roundtrip', result, log, {'extra.log': diagnostic})
        self.assertEqual(oracle.verify_result(BINDING, 'baseline', 'roundtrip', result, log, {'copy.log': log})['status'], 'passed')
        with self.assertRaises(ValueError):
            oracle.verify_result(BINDING, 'baseline', 'roundtrip', result, log, {'partial.log': log.splitlines()[0]})
        # RNG diagnostics are intentionally neither assertions nor pass thresholds.
        oracle.verify_result(BINDING, 'baseline', 'roundtrip', result, 'WINTER RNG DIAGNOSTIC: pauses=128 advances=0\n' + log)

    def test_listener_diagnostics_not_socket_census(self):
        good = 'World opened on network port 1234 for address 127.0.0.1.\nWorld no longer opened to new users.'
        oracle.listener_diagnostics(good)
        oracle.listener_diagnostics('')
        for bad in (good.replace('127.0.0.1', '0.0.0.0'), good.replace('1234', '0'), good + good,
                    good.splitlines()[0], 'World opened on network port nonsense'):
            with self.subTest(log=bad), self.assertRaises(ValueError):
                oracle.listener_diagnostics(bad)

    def test_compiler_clean_exact_version_and_phase_restrictions(self):
        good = 'DM compiler version 516.1688\n0 errors, 0 warnings\n'
        self.assertEqual(oracle.verify_compile(good)['status'], 'passed')
        for bad in (good.replace('1688', '1681'), good + good, good.replace('0 errors', '1 errors'),
                    good + 'warning: bad', good + 'invalid file', good.replace('0 warnings', '1 warnings')):
            with self.subTest(log=bad), self.assertRaises(ValueError):
                oracle.verify_compile(bad)
        for variant, phase in (('other', 'roundtrip'), ('baseline', 'other'), ('hardiness', 'reader')):
            with self.subTest(variant=variant, phase=phase), self.assertRaises(ValueError):
                oracle.expected(variant, phase)


if __name__ == '__main__':
    unittest.main()
