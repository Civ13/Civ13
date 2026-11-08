"""Fit Viewport: native pane-width check (run by hand, needs the pinned BYOND).

    source byondsetup && python3 tests/fit_viewport/native_width.py

The offline CI suite (test_fit_viewport.py) forbids skipped tests, so this
DreamDaemon check lives here instead of skipping on runners without BYOND.
"""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_fit_viewport import width_proc  # noqa: E402


class FitViewportWidth(unittest.TestCase):
    CASES = [
        # view, map height, icon size, split width -> width
        ((15, 15), 990, 0, 1920, 990),     # stretch: square view follows the height
        ((21, 15), 600, 0, 1920, 840),     # stretch: wide view
        ((15, 15), 990, 64, 1920, 960),    # fixed icon size: exact tiles
        ((15, 15), 990, 0, 1000, 800),     # chat/stat panel keeps 200 px
        ((15, 15), 0, 0, 1920, 0),         # no map yet: do nothing
    ]

    def test_widths(self):
        self.assertTrue(shutil.which('DreamMaker') and shutil.which('DreamDaemon'), 'source byondsetup first')
        with tempfile.TemporaryDirectory() as tmp:
            calls = '\n'.join(
                f'\tout += "[fit_viewport_width(list({v[0]}, {v[1]}), {h}, {i}, {s})]"'
                for v, h, i, s, _ in self.CASES)
            (Path(tmp) / 'fixture.dme').write_text(
                width_proc() + '\n/world/New()\n\tvar/list/out = list()\n' + calls +
                '\n\ttext2file(jointext(out, ","), "out.txt")\n\tdel src\n', encoding='utf-8')
            subprocess.run(['DreamMaker', 'fixture.dme'], cwd=tmp, check=True, capture_output=True)
            subprocess.run(['DreamDaemon', 'fixture.dmb', '-trusted', '-invisible'], cwd=tmp,
                check=True, capture_output=True, timeout=60)
            got = (Path(tmp) / 'out.txt').read_text().strip().split(',')
        self.assertEqual(got, [str(c[-1]) for c in self.CASES])


if __name__ == '__main__':
    unittest.main()
