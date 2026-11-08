"""Fit Viewport: skin wiring and the pane-width math.

Offline wiring checks only. The pane-width math runs natively in
native_width.py, by hand, because the offline CI suite forbids skipped tests.
"""
from pathlib import Path
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


if __name__ == '__main__':
    unittest.main()
