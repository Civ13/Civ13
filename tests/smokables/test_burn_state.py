"""Offline projections of smokable burn-out and ignition admission."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('smokable_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/game/objects/items/weapons/cigs_lighters.dm').read_text()


def flame_source(kind, enabled):
    body = adapter.extract(SOURCE, '/proc/isflamesource')
    for path, name in [('/obj/item/weapon/flame', 'flame'),
                       ('/obj/item/flashlight/torch', 'torch'),
                       ('/obj/item/flashlight/flare', 'flare')]:
        body = body.replace(path + ')', repr(name) + ')')
    def istype(obj, kind):
        return obj.kind == kind
    proc = adapter.project('/test/proc/run()\n' + body + '\n', '/test/proc/run', 'A', {'istype': istype})
    return proc(SimpleNamespace(kind=kind, lit=enabled, on=enabled))


def burnout(on_mob):
    body = adapter.extract(SOURCE, '/obj/item/clothing/mask/smokable/proc/die')
    lines = body.splitlines()
    start = next(i for i, line in enumerate(lines) if 'new /obj/effect/decal/cleanable/ash(T)' in line)
    end = next(i for i in range(start + 1, len(lines)) if 'processing_objects -= src' in lines[i])
    segment = [line[1:] for line in lines[start + 1:end]]
    segment = [line for line in segment if 'to_chat(' not in line and 'if (!nomessage)' not in line]
    segment = [line.replace('var/mob/living/M = loc', 'var/M = mob') for line in segment]
    segment += ['\treturn list(lit, icon_state, item_state)']
    proc = adapter.project('/test/proc/run()\n' + '\n'.join(segment) + '\n', '/test/proc/run',
                           'loc, mob, lit, icon_state, item_state, icon_off',
                           {'ismob': lambda loc: loc, 'list': lambda *values: list(values)})
    noop = lambda *args: None
    mob = SimpleNamespace(update_inv_wear_mask=noop, update_inv_l_hand=noop, update_inv_r_hand=noop)
    return proc(on_mob, mob, True, 'on', 'on', 'off')


class SmokableTest(unittest.TestCase):
    def test_ignition_requires_active_flame(self):
        for kind in ('flame', 'torch', 'flare'):
            with self.subTest(kind=kind):
                self.assertFalse(flame_source(kind, False))
                self.assertTrue(flame_source(kind, True))
        self.assertFalse(flame_source('flashlight', True))
        parent = adapter.extract(SOURCE, '/obj/item/clothing/mask/smokable/attackby')
        self.assertIn('if (isflamesource(W))', parent)
        self.assertNotIn('istype(W, /obj/item/flashlight)', SOURCE)

    def test_reusable_pipe_burnout_resets_on_floor_and_mob(self):
        for on_mob in (False, True):
            with self.subTest(on_mob=on_mob):
                self.assertEqual(burnout(on_mob), [False, 'off', 'off'])


if __name__ == '__main__':
    unittest.main()
