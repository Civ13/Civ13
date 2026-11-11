"""Execute the production fridge handler with controlled engine boundaries.

This is source projection, not a DM compiler or native gameplay test. The frozen
original handler is a negative control for the three reported failure modes.
"""
import importlib.util
import hashlib
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/structures/crates_lockers/closets/fridge.dm'
ORIGINAL = Path(__file__).with_name('original_fridge.dm')
spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
adapter.FIELDS += ('anchored', 'powersource')
DECL = '/obj/structure/closet/fridge/attackby'


class Connections(list):
    def __iadd__(self, item):
        self.append(item)
        return self


class Cable:
    def __init__(self):
        self.connections = Connections()
        self.tiledir = 'none'
        self.updated = False

    def update_icon(self):
        self.updated = True


class Coil:
    def __init__(self, result=True):
        self.calls = 0
        self.result = result

    def place_turf(self, turf, user, direction):
        self.calls += 1
        return Cable() if self.result else None


class Wrench:
    pass


class User:
    def __init__(self, during_wait=None, completes=True):
        self.during_wait = during_wait
        self.completes = completes
        self.waits = 0


class Fridge:
    def __init__(self, anchored=True, cable=None):
        self.anchored = anchored
        self.powersource = cable
        self.parent_calls = 0


def make_handler(path):
    source = path.read_text(encoding='utf-8-sig')
    body = adapter.extract(source, DECL)
    # Message interpolation and audio are engine output boundaries, not control
    # flow. Preserve each call's position and nesting while discarding its text.
    body = re.sub(r'(?m)^(\t*)(?:visible_message|to_chat|playsound)\(.*\)$', r'\1output()', body)
    body = body.replace('istype(W, /obj/item/weapon/wrench)', 'is_wrench(W)')
    body = body.replace('istype(W, /obj/item/stack/cable_coil)', 'is_coil(W)')
    body = body.replace('..()', 'parent(src)')
    wrapped = '/fixture/attackby()\n' + body + '\n'

    def do_after(user, duration, target):
        assert duration == 50
        user.waits += 1
        if user.during_wait:
            user.during_wait()
        return user.completes

    env = {
        'is_wrench': lambda item: isinstance(item, Wrench),
        'is_coil': lambda item: isinstance(item, Coil),
        'do_after': do_after,
        'get_turf': lambda atom: atom,
        'get_dir': lambda user, target: 1,
        'turn': lambda direction, angle: direction,
        'get_step': lambda cable, direction: [],
        'typed_iter': lambda atoms, typ: atoms,
        'list_cmp': lambda a, b: a == b,
        'output': lambda: None,
        'parent': lambda fridge: setattr(fridge, 'parent_calls', fridge.parent_calls + 1),
    }
    return adapter.project(wrapped, '/fixture/attackby', 'src, W, user', env, method=True)


class Cases:
    def test_cable_rejected_when_unanchored(self):
        fridge, coil = Fridge(anchored=False), Coil()
        self.handler(fridge, coil, User())
        self.assertIsNone(fridge.powersource)
        self.assertEqual(coil.calls, 0)

    def test_cable_connected_during_wrench_wait_prevents_unanchor(self):
        fridge, coil = Fridge(), Coil()
        user = User(during_wait=lambda: self.handler(fridge, coil, User()))
        self.handler(fridge, Wrench(), user)
        self.assertEqual(user.waits, 1)
        self.assertIsNotNone(fridge.powersource)
        self.assertTrue(fridge.anchored)

    def test_overlapping_wrenches_do_not_reverse_first_change(self):
        fridge = Fridge()
        other = User()
        user = User(during_wait=lambda: self.handler(fridge, Wrench(), other))
        self.handler(fridge, Wrench(), user)
        self.assertEqual((user.waits, other.waits), (1, 1))
        self.assertFalse(fridge.anchored)

    def test_ordinary_cable_and_wrench_controls(self):
        fridge, coil = Fridge(), Coil()
        self.handler(fridge, coil, User())
        self.assertEqual(coil.calls, 1)
        self.assertEqual(fridge.powersource.connections, [fridge])
        self.assertTrue(fridge.powersource.updated)
        blocked = User()
        self.handler(fridge, Wrench(), blocked)
        self.assertEqual(blocked.waits, 0)
        duplicate = Coil()
        self.handler(fridge, duplicate, User())
        self.assertEqual(duplicate.calls, 0)
        standalone = Fridge()
        self.handler(standalone, Wrench(), User())
        self.assertFalse(standalone.anchored)
        self.handler(standalone, Wrench(), User())
        self.assertTrue(standalone.anchored)

    def test_interrupted_wrench_and_failed_cable_are_noops(self):
        fridge = Fridge()
        self.handler(fridge, Wrench(), User(completes=False))
        self.assertTrue(fridge.anchored)
        self.assertEqual(fridge.parent_calls, 0)
        coil = Coil(result=False)
        self.handler(fridge, coil, User())
        self.assertEqual(coil.calls, 1)
        self.assertIsNone(fridge.powersource)


class Production(Cases, unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.handler = staticmethod(make_handler(SOURCE))


class OriginalNegativeControl(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        assert hashlib.sha256(ORIGINAL.read_bytes()).hexdigest() == (
            '4097376bd48cf3bce8d7b2691b48fa082f9f8db33b1e5e716c9deb791ee9619e'
        ), 'Frozen master fixture changed'
        cls.handler = staticmethod(make_handler(ORIGINAL))

    def test_original_exhibits_each_regression(self):
        fridge, coil = Fridge(anchored=False), Coil()
        self.handler(fridge, coil, User())
        self.assertIsNotNone(fridge.powersource)
        self.assertEqual(coil.calls, 1)

        fridge = Fridge()
        self.handler(fridge, Wrench(), User(during_wait=lambda: self.handler(fridge, Coil(), User())))
        self.assertIsNotNone(fridge.powersource)
        self.assertFalse(fridge.anchored)

        fridge, other = Fridge(), User()
        first = User(during_wait=lambda: self.handler(fridge, Wrench(), other))
        self.handler(fridge, Wrench(), first)
        self.assertEqual((first.waits, other.waits), (1, 1))
        self.assertTrue(fridge.anchored)

        fridge = Fridge()
        self.handler(fridge, Wrench(), User(completes=False))
        self.assertEqual(fridge.parent_calls, 1)
