"""Offline control-flow checks for window breakage and glazing.

Production branches are projected with fake object creation and timer boundaries;
this does not exercise the BYOND engine, a map, or actual delayed scheduling.
"""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'save_movement'))
from source_adapter import extract, project, read

PATH = 'code/game/objects/structures/window.dm'
PARENT = '/obj/structure/window/proc/shatter'
METAL = '/obj/structure/window/classic/metal/shatter'
ATTACK = '/obj/structure/window_frame/attackby'


def adapted(source):
    source = re.sub(r'istype\(src,\s*(/obj/[\w/]+)\)', r'istype(src, "\1")', source)
    source = re.sub(r'new\s*(/obj/[\w/]+)\(', r'create("\1", ', source)
    source = re.sub(r'(?<![\w.])glassed\b', 'src.glassed', source)
    return source.replace('spawn (', 'spawn(').replace('..(display_message)', 'parent(src, display_message)')


class FakeObject:
    def __init__(self, kind, glassed=True):
        self.kind = kind
        self.glassed = glassed
        self.loc = 'turf'


def istype(obj, typepath):
    return obj.kind == typepath or obj.kind.startswith(typepath + '/')


class WindowFrames(unittest.TestCase):
    def setUp(self):
        self.source = read(PATH)
        self.created = []
        self.env = {'istype': istype, 'create': lambda kind, loc: self.created.append((kind, loc)),
                    'get_turf': lambda obj: obj.loc, 'playsound': lambda *a: None,
                    'visible_message': lambda *a: None, 'qdel': lambda obj: None,
                    'deferred': lambda delay: True}

    def shatter(self, obj):
        source = adapted(self.source)
        self.env['parent'] = project(source, PARENT, 'src, display_message', self.env, method=True)
        method = project(source, METAL, 'src, display_message', self.env, method=True)
        method(obj, False)
        return [kind for kind, _ in self.created]

    def glaze(self, kind):
        body = extract(self.source, ATTACK)
        start = '\t\t\t\tif (istype(src, /obj/structure/window_frame/shoji))'
        end = '\t\t\t\tvisible_message('
        segment = body[body.index(start):body.index(end, body.index(start))]
        segment = '\n'.join(line[3:] for line in segment.splitlines())
        source = adapted('/proc/glaze()\n' + segment + '\n')
        method = project(source, '/proc/glaze', 'src', self.env, method=True)
        method(FakeObject(kind))
        return [kind for kind, _ in self.created]

    def test_glassed_metal_shattering_leaves_one_frame(self):
        self.assertEqual(self.shatter(FakeObject('/obj/structure/window/classic/metal')),
                         ['/obj/structure/window_frame/metal'])

    def test_unglassed_metal_keeps_existing_fallback(self):
        self.assertEqual(self.shatter(FakeObject('/obj/structure/window/classic/metal', False)),
                         ['/obj/structure/window_frame/metal'])

    def test_abashiri_frame_preserves_style_when_glazed(self):
        self.assertEqual(self.glaze('/obj/structure/window_frame/abashiri'),
                         ['/obj/structure/window/classic/abashiri'])

    def test_shoji_frame_preserves_style_when_glazed(self):
        self.assertEqual(self.glaze('/obj/structure/window_frame/shoji'),
                         ['/obj/structure/window/classic/shoji'])

    def test_generic_frame_remains_generic_when_glazed(self):
        self.assertEqual(self.glaze('/obj/structure/window_frame'),
                         ['/obj/structure/window/classic'])


if __name__ == '__main__':
    unittest.main()
