"""Source preparation and oracle controls only; no native execution."""
from pathlib import Path
import tempfile
import unittest

from run import ACCESSORY, CONTROLS, PREFIX, ROOT, prepare, replace_once, sources, verify_result


class AccessoryPreparation(unittest.TestCase):
    def test_three_actual_source_variants_prepare_without_native(self):
        with tempfile.TemporaryDirectory() as directory:
            for control in (None, *CONTROLS):
                generated, metadata = prepare(Path(directory) / (control or 'positive'), control)
                body = generated[PREFIX + '_accessory.dm']
                expected = (ROOT / ACCESSORY).read_text(encoding='utf-8')
                if control:
                    expected = expected.replace('\t\tuser.put_in_hands(src)\n', '\t\tusr.put_in_hands(src)\n')
                if control == 'fork-guard':
                    expected = expected.replace('\tif (user)\n', '\tif (usr)\n')
                self.assertEqual(body, expected)
                self.assertIn('\t\t' + ('usr' if control else 'user') + '.put_in_hands(src)', body)
                self.assertIn('\tif (' + ('usr' if control == 'fork-guard' else 'user') + ')', body)
                self.assertEqual(metadata['control'], control)
                self.assertIn('tests/accessory_removal/probe.dm', generated[PREFIX + '.dme'])
                self.assertNotIn('.dmm"', generated[PREFIX + '.dme'])
                self.assertNotIn('CIV13_GAMEPLAY_BRIDGE', generated[PREFIX + '.dme'])

    def test_ambiguous_or_missing_source_and_unknown_controls_refuse(self):
        for text in ('absent', 'anchor anchor'):
            with self.assertRaises(ValueError):
                replace_once(text, 'anchor', 'replacement')
        with self.assertRaises(ValueError):
            sources(control='unknown')

    def test_incomplete_generic_fault_or_wrong_named_failure_never_accepts(self):
        labels = [f'check-{i}' for i in range(266)] + list(CONTROLS.values())
        labels += [label.rsplit('/', 1)[0] + '/completed' for label in CONTROLS.values()]
        good = dict(case_count=27, check_count=270, runtime_error=False, failed_labels=[],
                    checks=[dict(label=label, passed=True) for label in labels])
        verify_result(good, None)
        for changed in (dict(case_count=26), dict(check_count=269), dict(runtime_error=True),
                        dict(failed_labels=['unrelated'])):
            with self.assertRaises(ValueError):
                verify_result(dict(good, **changed), None)
        for control in CONTROLS:
            with self.assertRaises(ValueError):
                verify_result(dict(good, failed_labels=['unrelated']), control)
            checks = [dict(label=label, passed=label != CONTROLS[control]) for label in labels]
            verify_result(dict(good, checks=checks, failed_labels=[CONTROLS[control]]), control)
            completion = CONTROLS[control].rsplit('/', 1)[0] + '/completed'
            failed = [label for label in labels if label in (CONTROLS[control], completion)]
            checks = [dict(label=label, passed=label not in failed) for label in labels]
            with self.assertRaises(ValueError):
                verify_result(dict(good, checks=checks, failed_labels=failed), control)
        with self.assertRaises(ValueError):
            verify_result(dict(good, checks=[]), None)

    def test_workflow_selects_only_this_registered_suite(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        step = workflow.split('      - name: Verify accessory removal actor and native controls\n', 1)[1].split('      - name:', 1)[0]
        self.assertIn("contains(fromJSON(needs.changes.outputs.new_tests), 'tests/accessory_removal')", step)
        self.assertIn('--negative-control "$control"', step)
        self.assertIn('for control in original-usr fork-guard', step)


if __name__ == '__main__':
    unittest.main()
