"""Offline checks for the packed multi-depth mining floor registry (no compiler or game).

The native probe (probe.dm) runs the production decoder against the fixtures; these
check the fixtures are current and that Phase 1 stays unwired (docs/multi-depth-mining.md).
"""
from pathlib import Path
import importlib.util
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
MODULE = 'code/modules/multiz/mine_floor_registry.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def generator():
    spec = importlib.util.spec_from_file_location('mine_registry_fixtures', HERE / 'make_fixtures.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Wiring(unittest.TestCase):
    def test_included_with_early_defines(self):
        dme = read('civ13.dme')
        self.assertIn('#include "code\\__defines\\mine_registry.dm"', dme)
        self.assertIn('#include "code\\modules\\multiz\\mine_floor_registry.dm"', dme)
        self.assertNotIn('#define', read(MODULE), 'shared defines live in code/__defines/mine_registry.dm')

    def test_phase_one_is_not_wired(self):
        # No global registry, save hook, allocation or entrance until later phases.
        module = read(MODULE)
        self.assertNotRegex(module, r'(?m)^var/|GLOB\.|world\.(maxz|maxx|maxy)|locate\(|ChangeTurf|map_storage|spawn\(|sleep\(')
        callers = []
        for path in (ROOT / 'code').rglob('*.dm'):
            rel = path.relative_to(ROOT).as_posix()
            if rel in (MODULE, 'code/__defines/mine_registry.dm'):
                continue
            text = path.read_text(encoding='utf-8', errors='replace')
            if re.search(r'mine_registry|MINE_REGISTRY_|MINE_FLOOR_', text):
                callers.append(rel)
        self.assertEqual(callers, [])

    def test_runtime_indexes_are_tmp(self):
        module = read(MODULE)
        self.assertIn('var/tmp/list/mine_index', module)
        self.assertIn('var/tmp/list/floor_index', module)

    def test_hard_caps_fit_exact_integers(self):
        defines = dict(re.findall(r'(?m)^#define (MINE_REGISTRY_\w+) (\d+)', read('code/__defines/mine_registry.dm')))
        self.assertEqual(int(defines['MINE_REGISTRY_MAX_INT']), 2 ** 24 - 1)
        self.assertLessEqual(int(defines['MINE_REGISTRY_MAX_FLOORS']), 256, 'insertion sort and pair checks stay small')


class Fixtures(unittest.TestCase):
    def test_fixtures_are_current(self):
        gen = generator()
        self.assertEqual(json.loads((HERE / 'fixtures/valid.json').read_text(encoding='utf-8')), gen.VALID)
        self.assertEqual(json.loads((HERE / 'fixtures/negative.json').read_text(encoding='utf-8')), json.loads(json.dumps(gen.NEGATIVE)))

    def test_every_negative_names_a_reason_the_validator_can_give(self):
        module = read(MODULE)
        cases = json.loads((HERE / 'fixtures/negative.json').read_text(encoding='utf-8'))
        names = [c['name'] for c in cases]
        self.assertEqual(len(names), len(set(names)))
        templates = re.findall(r'(?m)return "(.+)"$', module)
        patterns = [re.compile('^' + '.+'.join(re.escape(part) for part in re.split(r'\[[^\]]*\]+', t)) + '$') for t in templates]
        for case in cases:
            self.assertTrue(any(p.match(case['expect']) for p in patterns), case['name'])
            self.assertNotEqual(case['registry'], generator().VALID, case['name'])


if __name__ == '__main__':
    unittest.main()
