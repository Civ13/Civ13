"""Offline checks for the Pocket Stronghold gemstone sprite port."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pocket_stronghold_gems as port  # noqa: E402

ROOT = port.ROOT


class PocketStrongholdGemsTest(unittest.TestCase):
    def test_dmi_matches_attributed_pixels(self):
        port.verify()

    def test_licence_notice_names_every_state(self):
        notice = (ROOT / port.LICENSE).read_text(encoding='utf-8')
        self.assertIn('CC BY-SA 3.0', notice)
        for entry in port.load_manifest()['states']:
            self.assertIn(f"`{entry['state']}`", notice)


if __name__ == '__main__':
    unittest.main()
