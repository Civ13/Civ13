"""Exercise directional overlay initialization and its use at both entry points."""
from collections import defaultdict
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('tape_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/game/objects/items/weapons/policetape.dm').read_text(encoding='utf-8-sig')


def init(cache):
    body = adapter.extract(SOURCE, '/proc/initialize_hazard_overlays')
    for name in ('NORTH', 'EAST', 'SOUTH', 'WEST'):
        body = body.replace(f'"[{name}]"', repr(name))
    body = re.sub(r"new/image\('icons/effects/warning_stripes.dmi', icon_state = \"([NESW])\"\)",
                  r"make_image('\1')", body)
    body += '\n\treturn hazard_overlays'
    proc = adapter.project('/test/proc/run()\n' + body + '\n', '/test/proc/run',
                           'hazard_overlays', {'list': dict, 'make_image': lambda state: state})
    return proc(cache)


def project_body(body, args, env=None):
    declaration = '/test/proc/run'
    return adapter.project(declaration + '()\n' + body + '\n', declaration, args, env or {})


class OverlayList(set):
    """Model DM list union/subtraction with a single image or a list."""

    @property
    def len(self):
        return len(self)

    def Cut(self):
        self.clear()

    def __ior__(self, value):
        if isinstance(value, set):
            self.update(value)
        else:
            self.add(value)
        return self

    def __isub__(self, value):
        self.discard(value)
        return self


class Floor:
    def __init__(self):
        self.overlays = OverlayList()
        self.decals = None


def floor_marking_placement():
    body = adapter.extract(SOURCE, '/obj/item/taperoll/afterattack')
    body = body[body.index('\tif (isfloor(A))'):]
    body = body.replace('"[direction]"', 'direction').replace(
        'user.loc == F ? user.dir : turn(user.dir, 180)',
        '(user.dir if user.loc == F else turn(user.dir, 180))')
    return project_body(body, 'A, user', {
        'isfloor': lambda _: True,
        'initialize_hazard_overlays': lambda: None,
        'hazard_overlays': {1: 'north', 4: 'east'},
        'tape_roll_applications': defaultdict(lambda: None),
        'turn': lambda direction, degrees: {1: 2, 2: 1, 4: 8, 8: 4}[direction],
        'list': OverlayList,
    })


def rebuild_floor_appearance(floor):
    body = adapter.extract(adapter.read('code/game/turfs/floor_icon.dm'),
                           '/turf/floor/update_icon')
    # Project the production clear and restore around the base sprite rebuild.
    clear = body[:body.index('\t\tname = flooring.name')].strip('\n')
    restore = body[body.index('\tif (decals && decals.len)'):]
    restore = restore[:restore.index('\n\n')]
    project_body(clear + '\n' + restore, 'flooring, overlays, decals')(
        True, floor.overlays, floor.decals)


def strip_flooring(floor):
    body = adapter.extract(adapter.read('code/game/turfs/floor.dm'),
                           '/turf/floor/proc/make_plating')
    clear = body[:body.index('\tname = base_name')].strip('\n')
    clear = re.sub(r'\b(overlays|decals)\b', r'floor.\1', clear)
    project_body(clear, 'floor', {'islist': lambda value: isinstance(value, OverlayList)})(floor)


class TapeMarkingTest(unittest.TestCase):
    def test_cache_initializes_for_fresh_world_and_is_reused(self):
        cache = init(None)
        self.assertEqual(cache, {'NORTH': 'N', 'EAST': 'E', 'SOUTH': 'S', 'WEST': 'W'})
        self.assertIs(init(cache), cache)

    def test_floor_and_placed_tape_initialize_before_use(self):
        placement = adapter.extract(SOURCE, '/obj/item/taperoll/afterattack')
        floor = placement[placement.index('if (isfloor(A))'):]
        self.assertLess(floor.index('initialize_hazard_overlays()'), floor.index('hazard_overlays['))
        created = adapter.extract(SOURCE, '/obj/item/tape/New')
        self.assertIn('initialize_hazard_overlays()', created)


    def setUp(self):
        self.place = floor_marking_placement()
        self.floor = Floor()
        self.user = SimpleNamespace(loc=self.floor, dir=1, visible_message=lambda *args: None)

    def test_floor_rebuild_keeps_markings_and_each_side_toggles_independently(self):
        self.floor.decals = OverlayList({'trim'})
        self.place(self.floor, self.user)
        self.user.dir = 4
        self.place(self.floor, self.user)
        rebuild_floor_appearance(self.floor)
        self.assertEqual(self.floor.overlays, {'trim', 'north', 'east'})

        self.place(self.floor, self.user)
        rebuild_floor_appearance(self.floor)
        self.assertEqual(self.floor.overlays, {'trim', 'north'})

    def test_removed_flooring_does_not_leave_an_invisible_marking(self):
        self.place(self.floor, self.user)
        self.assertEqual(self.floor.overlays, {'north'})
        strip_flooring(self.floor)
        rebuild_floor_appearance(self.floor)
        self.assertEqual(self.floor.overlays, set())

        self.place(self.floor, self.user)
        self.assertEqual(self.floor.overlays, {'north'})


if __name__ == '__main__':
    unittest.main()
