"""The existing animal omission control must preserve the separate human guard."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('origin_control', HERE / 'correctness.py')
correctness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(correctness)


class OriginControlTests(unittest.TestCase):
    def test_mutation_omits_only_animal_edge_guard(self):
        source = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        self.assertEqual(source.count(correctness.ORIGIN_ANCHOR), 1)
        with tempfile.TemporaryDirectory() as tmp:
            packet = Path(tmp)
            target = packet / 'code/modules/persistence/functions.dm'
            target.parent.mkdir(parents=True)
            target.write_text(source)
            correctness.mutate(packet, 'origin')
            result = target.read_text()
            self.assertNotIn(correctness.ORIGIN_ANCHOR, result)
            self.assertIn('var/datum/child = saving_reference_pins[ref]', result)
            self.assertIn('var/list/human_root = child ? human_save_roots', result)
            self.assertIn('Human save root entered a captured container', result)
            with self.assertRaisesRegex(ValueError, 'origin mutation anchor differs'):
                correctness.mutate(packet, 'origin')


if __name__ == '__main__':
    unittest.main()
