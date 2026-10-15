"""Pure source guards and fixture preparation; no compiler or game process."""
import json
from pathlib import Path
import tempfile
import unittest

from check_writers import ROOT, HELPER, check, inspect_sources
from run import CONTROLS, prepare, replace_once


class SourceContracts(unittest.TestCase):
    def test_all_migrated_writer_expressions_unchanged(self):
        self.assertEqual(check(), (86, 29))

    def test_mutation_and_expression_omission_controls(self):
        sources = {path.relative_to(ROOT).as_posix(): path.read_text(encoding='utf-8')
                   for path in (ROOT / 'code').rglob('*.dm')}
        inventory = json.loads((ROOT / 'tests/attack_history/writer-migration.json').read_text())
        self.assertEqual(inspect_sources(sources, inventory), [])
        for mutation in ('M.attack_log += "bypass"', 'M.attack_log.Add("bypass")',
                         'attack_log.Cut()', 'M.attack_log = list()', 'M.attack_log[1] = "bypass"'):
            with self.subTest(mutation=mutation):
                changed = dict(sources)
                changed['code/test_bypass.dm'] = mutation
                self.assertTrue(inspect_sources(changed, inventory))
        changed = dict(sources)
        changed[HELPER] = changed[HELPER].replace('victim.append_attack_log(', 'victim.lost_append(', 1)
        self.assertIn('Migrated writer expressions or multiplicities changed', inspect_sources(changed, inventory))

    def test_all_fixture_variants_prepare_without_native_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            for control in (None, *CONTROLS):
                evidence = Path(directory) / (control or 'positive')
                metadata = prepare(evidence, control)
                self.assertEqual(metadata['writer_count'], 86)
                self.assertEqual(metadata['control'], control)
                helper = (evidence / 'history.dm').read_text()
                self.assertIn('history_probe_write(payload, global.attack_log)', helper)
                self.assertNotIn('proc/log_and_message_admins', helper)
                if control:
                    self.assertIn(CONTROLS[control][1], helper)

    def test_missing_or_ambiguous_anchors_fail_closed(self):
        for source in ('absent', 'anchor anchor'):
            with self.assertRaises(ValueError):
                replace_once(source, 'anchor', 'replacement')


if __name__ == '__main__':
    unittest.main()
