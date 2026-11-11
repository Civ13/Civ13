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
        soon = source[source.index('/client/proc/fit_viewport_soon()'):source.index('/client/verb/on_window_resize()')]
        self.assertIn('is_preference_enabled(/datum/client_preference/fit_viewport)', soon)
        self.assertRegex(soon, r'token == fit_viewport_token')
        resize = source[source.index('/client/verb/on_window_resize()'):source.index('/client/verb/set_map_icon_size(')]
        self.assertIn('fit_viewport_soon()', resize)

    def test_connect_and_login_refit_once_the_layout_settles(self):
        # A reconnect (region switch) runs client/New, the lobby Login and the
        # mob Login within a few ticks while the skin is still restoring its
        # saved size. Each must ask for a debounced refit, never refit at once,
        # and the connect must not throw the saved splitter away.
        for path in ('code/modules/client/fullscreen.dm', 'code/game/mob/new_player/login.dm', 'code/game/mob/login.dm'):
            source = read(path)
            self.assertIn('fit_viewport_soon()', source, path)
        new_client = read('code/modules/client/fullscreen.dm')
        new_client = new_client[new_client.index('client/New()'):new_client.index('client/verb/updateFullscreen()')]
        self.assertNotIn('splitter=', new_client)
        self.assertNotIn('fit_viewport()', new_client)
        for path in ('code/game/mob/new_player/login.dm', 'code/game/mob/login.dm'):
            self.assertNotIn('client.fit_viewport()', read(path), path)

    def test_fit_reads_icon_size(self):
        source = read(PROCS)
        body = source[source.index('/client/verb/fit_viewport()'):source.index('#define FIT_VIEWPORT_MIN_RPANE')]
        self.assertIn('winget(src, "mapwindow.map", "icon-size")', body)
        self.assertIn('fit_viewport_width(', body)


if __name__ == '__main__':
    unittest.main()


class SkinControlsFitTheirWindow(unittest.TestCase):
    """A control wider than its pane at design size stays wider at every size.

    Anchors scale a control's edges with the pane, so a control that starts
    past the right or bottom edge keeps that overhang however the window is
    resized (the chat input once hid the end of typed text this way).
    """

    @staticmethod
    def windows():
        import re
        skin = read('interface/skin.dmf').replace('\r\n', '\n')
        for block in re.split(r'\nwindow ', skin)[1:]:
            name = block.split('\n', 1)[0].strip('"')
            elems = re.split(r'\n\telem ', block)[1:]
            props = [dict(re.findall(r'^\t\t([\w-]+) = (.*)$', e, re.M)) for e in elems]
            names = [e.split('\n', 1)[0].strip('"') for e in elems]
            yield name, list(zip(names, props))

    def test_every_control_fits_inside_its_window(self):
        checked = 0
        for window, elems in self.windows():
            width, height = map(int, elems[0][1]['size'].split('x'))
            for elem, props in elems[1:]:
                if 'size' not in props:
                    continue
                x, y = map(int, props.get('pos', '0,0').split(','))
                w, h = map(int, props['size'].split('x'))
                checked += 1
                self.assertLessEqual(x + w, width, f'{window}.{elem} overhangs the right edge')
                self.assertLessEqual(y + h, height, f'{window}.{elem} overhangs the bottom edge')
        self.assertGreater(checked, 5)

    def test_chat_input_spans_the_chat_pane(self):
        elems = dict(dict(self.windows())['outputwindow'])
        chat, entry = elems['browser_chat'], elems['input']
        self.assertEqual(entry['size'].split('x')[0], chat['size'].split('x')[0])
        self.assertEqual(entry['anchor1'], '0,100')
        self.assertEqual(entry['anchor2'], '100,100')
