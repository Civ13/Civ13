"""Fit Viewport: skin wiring and the pane-width math.

The width proc is compiled into a tiny fixture and run in DreamDaemon when the
pinned BYOND tools are on PATH; the wiring checks are always offline.
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
PROCS = 'code/modules/client/client_procs.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace')


def width_proc():
    source = read(PROCS)
    start = source.index('#define FIT_VIEWPORT_MIN_RPANE')
    end = source.index('#undef FIT_VIEWPORT_MIN_RPANE', start)
    return source[start:end] + '#undef FIT_VIEWPORT_MIN_RPANE\n'


class FitViewportWiring(unittest.TestCase):
    def test_main_window_resize_refits(self):
        skin = read('interface/skin.dmf')
        main = skin[skin.index('window "mainwindow"'):skin.index('elem "mainvsplit"')]
        self.assertIn('on-size = "on-window-resize"', main)
        self.assertIn('set name = "on-window-resize"', read(PROCS))

    def test_icons_menu_uses_refitting_verb(self):
        skin = read('interface/skin.dmf')
        menu = skin[skin.index('menu "menu"'):skin.index('window "mainwindow"')]
        self.assertNotIn('icon-size=', menu)
        for size in ('0', '32', '48', '64', '96', '128'):
            self.assertIn(f'command = "set-map-icon-size {size}"', menu)
        self.assertIn('command = "Fit-Viewport"', menu)

    def test_resize_honours_preference_and_debounces(self):
        source = read(PROCS)
        body = source[source.index('/client/verb/on_window_resize()'):source.index('/client/verb/set_map_icon_size(')]
        self.assertIn('is_preference_enabled(/datum/client_preference/fit_viewport)', body)
        self.assertRegex(body, r'token == fit_viewport_token')

    def test_fit_reads_icon_size(self):
        source = read(PROCS)
        body = source[source.index('/client/verb/fit_viewport()'):source.index('#define FIT_VIEWPORT_MIN_RPANE')]
        self.assertIn('winget(src, "mapwindow.map", "icon-size")', body)
        self.assertIn('fit_viewport_width(', body)


@unittest.skipUnless(shutil.which('DreamMaker') and shutil.which('DreamDaemon'), 'BYOND tools not on PATH')
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
