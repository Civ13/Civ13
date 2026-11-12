"""Cooling fan examine text follows its on/off state (issue #4762)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/structures/appliances.dm'


def proc_body(text, header):
    start = text.index(header + '\n') + len(header) + 1
    lines = []
    for line in text[start:].splitlines():
        if line and not line.startswith('\t'):
            break
        lines.append(line)
    return '\n'.join(lines)


class CoolingFanDescTest(unittest.TestCase):
    def setUp(self):
        self.text = SOURCE.read_text(encoding='utf-8')

    def render_desc(self, on):
        body = proc_body(self.text, '/obj/structure/coolingfan/proc/update_desc()')
        match = re.search(r'desc = "(.*)\[on \? "(\w+)" : "(\w+)"\](.*)"', body)
        self.assertIsNotNone(match, body)
        prefix, on_word, off_word, suffix = match.groups()
        return prefix + (on_word if on else off_word) + suffix

    def test_desc_matches_state(self):
        self.assertEqual(self.render_desc(True), "A rotating cooling fan. It's switched on.")
        self.assertEqual(self.render_desc(False), "A rotating cooling fan. It's switched off.")

    def test_default_desc_matches_default_state(self):
        block = proc_body(self.text, '/obj/structure/coolingfan')
        self.assertIn('var/on = FALSE', block)
        self.assertIn('desc = "%s"' % self.render_desc(False), block)

    def test_toggle_refreshes_desc_after_both_branches(self):
        body = proc_body(self.text, '/obj/structure/coolingfan/attack_hand(mob/user as mob)')
        last = [line for line in body.splitlines() if line.strip()][-1]
        self.assertEqual(last, '\tupdate_desc()')


if __name__ == '__main__':
    unittest.main()
