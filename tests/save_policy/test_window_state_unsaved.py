"""Open windows and the static crafting catalog must stay out of world saves.

One open Crafting Atlas window made a live Gaia level save the whole catalog
(68,516 lists, 28 MB), and each restore left another copy for the next save:
over half of the level's 1.48 million saved values (2026-11-11).
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/persistence/functions.dm'


class WindowStateUnsavedTest(unittest.TestCase):
    def setUp(self):
        self.text = SOURCE.read_text(encoding='utf-8')

    def test_window_types_are_not_saved(self):
        for path in ('/datum/nanoui', '/datum/topic_state', '/datum/crafting_atlas_reference'):
            pattern = r'^' + re.escape(path) + r'\n\tshould_save = FALSE$'
            self.assertRegex(self.text, re.compile(pattern, re.M), f'{path} is saved')

    def test_mob_window_index_is_runtime_state(self):
        body = self.text.split('/mob/persistence_runtime_var(key)', 1)[1].split('\n/', 1)[0]
        self.assertRegex(body, r'key == "open_uis"\)\n\t\treturn TRUE')


if __name__ == '__main__':
    unittest.main()
