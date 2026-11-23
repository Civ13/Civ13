"""Every canteen, not only the WW2 ones, is non-glass and survives a throw (#6911)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/reagents/reagent_containers/food/drinks/canteen.dm'
BASE = '/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen'


class CanteenNotGlassTests(unittest.TestCase):
    def test_base_canteen_is_not_glass(self):
        text = SOURCE.read_text(encoding='utf-8-sig').replace('\r\n', '\n')
        start = text.index(BASE + '\n') + len(BASE) + 1
        end = re.search(r'\n(?=\S)', text[start:])
        body = text[start:start + end.start()]
        self.assertRegex(body, r'\n?\tisGlass = FALSE\b')
        # No canteen subtype turns glass back on.
        self.assertNotIn('isGlass = TRUE', text)


if __name__ == '__main__':
    unittest.main()
