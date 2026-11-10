"""Exercise the curtain's production opacity transition with fake turf boundaries."""
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'save_movement'))
import source_adapter


def toggle_transition():
    source = (ROOT / 'code/game/objects/structures/curtains.dm').read_text()
    body = source.split('/obj/structure/curtain/proc/toggle()\n', 1)[1]
    body = body.split('\n\tif (opacity)\n\t\ticon_state', 1)[0]
    fixture = '/curtain/transition()\n' + body + '\n'
    previous = source_adapter.FIELDS
    try:
        source_adapter.FIELDS += ('opacity',)
        return source_adapter.project(fixture, '/curtain/transition', 'src', {
            'los_invalidate': lambda *args: None,
            'isturf': lambda value: isinstance(value, Turf),
        }, method=True)
    finally:
        source_adapter.FIELDS = previous


class Turf:
    def __init__(self, curtain):
        self.curtain = curtain
        self.cached_opacity = curtain.opacity
        self.visibility_updates = []

    def recalc_atom_opacity(self):
        self.cached_opacity = self.curtain.opacity

    def reconsider_lights(self):
        self.visibility_updates.append(self.cached_opacity)


class CurtainLightingTests(unittest.TestCase):
    def test_open_and_close_refresh_cached_opacity_before_lights(self):
        curtain = SimpleNamespace(opacity=True)
        turf = curtain.loc = Turf(curtain)
        transition = toggle_transition()
        transition(curtain)
        self.assertFalse(turf.cached_opacity)
        self.assertEqual(turf.visibility_updates, [False])
        transition(curtain)
        self.assertTrue(turf.cached_opacity)
        self.assertEqual(turf.visibility_updates, [False, True])

    def test_nullspace_transition_does_not_require_a_turf(self):
        curtain = SimpleNamespace(opacity=True, loc=None)
        toggle_transition()(curtain)
        self.assertFalse(curtain.opacity)


if __name__ == '__main__':
    unittest.main()
