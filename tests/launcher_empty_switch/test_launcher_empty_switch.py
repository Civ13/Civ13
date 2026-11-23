"""An emptied underslung launcher hands firing back to the rifle (#6924)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/projectiles/guns/projectile.dm'
HEADER = '/obj/item/weapon/gun/projectile/Fire('


class LauncherEmptySwitchTests(unittest.TestCase):
    def test_empty_launcher_clears_launcher_mode_only(self):
        text = SOURCE.read_text(encoding='utf-8-sig').replace('\r\n', '\n')
        start = text.index('\n' + HEADER) + 1
        end = re.search(r'\n(?=\S)', text[start:])
        body = text[start:start + end.start()]
        empty = body[body.index('if(!launcher.grenades.len)'):body.index('\telse\n')]
        self.assertIn('use_launcher = FALSE', empty)
        # Advancing the fire selector would change the rifle's chosen mode.
        self.assertNotIn('switch_firemodes(', empty)
        self.assertNotIn('sel_mode', empty)


if __name__ == '__main__':
    unittest.main()
