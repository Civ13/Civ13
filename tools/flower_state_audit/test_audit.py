from pathlib import Path
import hashlib
import json
import re
import unittest

import audit


class FlowerStateTests(unittest.TestCase):
    def setUp(self):
        self.source = (audit.ROOT / 'code/game/objects/structures/wild.dm').read_text(encoding='utf-8')
        self.decoded = audit.states(audit.ROOT / 'icons/obj/flora/ausflora.dmi')

    def test_every_outcome_has_nonempty_static_32px_art(self):
        for name in audit.outcomes(self.source):
            with self.subTest(state=name):
                self.assertIn(name, self.decoded)
                self.assertEqual(self.decoded[name]['size'], [32, 32])
                self.assertEqual(self.decoded[name]['directions'], 1)
                self.assertEqual(self.decoded[name]['frames'], 1)
                self.assertTrue(self.decoded[name]['nonempty'])

    def test_original_failure_is_preserved_and_causal_control_still_fails(self):
        evidence = json.loads((Path(__file__).parent / 'baseline-10d264e.json').read_text())
        self.assertEqual(evidence['status'], 'failed')
        self.assertEqual(evidence['missing_states'], ['flower3'])
        icon = audit.ROOT / 'icons/obj/flora/ausflora.dmi'
        self.assertEqual(hashlib.sha256(icon.read_bytes()).hexdigest(), evidence['icon_sha256'])
        original = re.sub(r'\n(\t+)if \(icon_state == "flower3"\)\n\1\ticon_state = "flower2"', '', self.source)
        missing = sorted(set(audit.outcomes(original)) - self.decoded.keys())
        self.assertEqual(missing, ['flower3'])

    def test_other_thirteen_slots_and_single_original_draw_are_preserved(self):
        expected = [f'flower{i}' if i != 3 else 'flower2' for i in range(1, 15)]
        self.assertEqual(audit.outcomes(self.source), expected)
        block = self.source.split('/obj/structure/wild/flowers\n', 1)[1].split('\n/obj/', 1)[0]
        self.assertEqual(block.count('rand('), 1)

    def test_wrong_existing_or_missing_alias_is_detected(self):
        wrong = re.sub(r'(if \(icon_state == "flower3"\)\n\t+icon_state = )"flower2"',
                       r'\1"flower99"', self.source)
        self.assertEqual(sorted(set(audit.outcomes(wrong)) - self.decoded.keys()), ['flower99'])


if __name__ == '__main__':
    unittest.main()
