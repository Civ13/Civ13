"""Offline checks for the Pocket Stronghold food sprite port."""
from pathlib import Path
import re
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pocket_stronghold_food as port  # noqa: E402

ROOT = port.ROOT


class PocketStrongholdFoodTest(unittest.TestCase):
    def test_dmi_matches_attributed_pixels(self):
        port.verify()

    def test_licence_notice_names_every_state(self):
        notice = (ROOT / 'icons/obj/food/pocket_stronghold_food.dmi.LICENSE.md').read_text(encoding='utf-8')
        self.assertIn('CC BY-SA 3.0', notice)
        for entry in port.load_manifest()['states']:
            self.assertIn(f"`{entry['state']}`", notice)

    def test_code_uses_only_existing_states(self):
        states = set(port.state_names(ROOT / port.load_manifest()['target']))
        used = set()
        for path in (ROOT / 'code').rglob('*.dm'):
            text = path.read_text(encoding='utf-8', errors='replace')
            if 'pocket_stronghold_food.dmi' not in text:
                continue
            for block in re.split(r'\n(?=/)', text):
                if 'pocket_stronghold_food.dmi' in block:
                    used.update(re.findall(r'(?:roasted_rotten_icon_state|roasted_icon_state|rotten_icon_state|icon_state) = "([^"]+)"', block))
        self.assertTrue(used)
        # rawcrab keeps its own raw states in food.dmi; only roasted states use this DMI.
        used -= {'raw_crabmeat', 'rotraw_crabmeat'}
        self.assertLessEqual(used, states)


if __name__ == '__main__':
    unittest.main()
