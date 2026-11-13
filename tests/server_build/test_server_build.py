"""Server Revision verb (code/modules/server_build/server_build.dm): offline wiring.

The offline CI suite forbids skipped tests, so the DreamDaemon check of the
reader (host record, lifecycle and .git fallbacks) is native_server_build.py,
run by hand with the pinned BYOND. The host side (gaia_host.py
write_server_build) is covered in tests/gaia_host.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/server_build/server_build.dm').read_text(encoding='utf-8')
PANEL = (ROOT / 'code/modules/statpanel/statpanel.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
GITIGNORE = (ROOT / '.gitignore').read_text(encoding='utf-8')


class Wiring(unittest.TestCase):
    def test_included_and_generated_file_ignored(self):
        self.assertIn('#include "code\\modules\\server_build\\server_build.dm"', DME)
        self.assertIn('config/server-build.json', GITIGNORE.splitlines())

    def test_public_verb_and_admin_status_line(self):
        self.assertIn('set name = "Server Revision"', SOURCE)
        self.assertIn('set category = "OOC"', SOURCE)
        self.assertIn('if(holder) add_stat("<b>Server build:</b>", server_build_summary())', PANEL)
        self.assertLess(PANEL.index('add_stat("<b>Last save:</b>"'), PANEL.index('add_stat("<b>Server build:</b>"'))

    def test_subject_is_escaped(self):
        self.assertIn('html_encode(info["subject"])', SOURCE)


if __name__ == '__main__':
    unittest.main()
