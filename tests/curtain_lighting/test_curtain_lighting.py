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

    def test_roof_refresh_lifecycle_and_toggle_order(self):
        source = (ROOT / 'code/game/objects/structures/curtains.dm').read_text()
        events = []

        class Roof:
            def update_transparency(self, value):
                events.append(('roof', value))

        class Overlay:
            def update_overlay(self):
                events.append(('overlay',))

        roofs = [Roof(), Roof()]
        env = {
            'range': lambda distance, owner: roofs if distance == 1 else [],
            'view': lambda distance, owner: [Overlay()],
            'typed_iter': lambda items, kind: items,
            'los_invalidate': lambda *args: events.append(('invalidate',)),
            'isturf': lambda value: False,
            'deferred': lambda delay: events.append(('delay', delay)) or True,
            'parent': lambda: events.append(('parent',)),
        }
        previous = source_adapter.FIELDS
        try:
            source_adapter.FIELDS += ('opacity', 'refresh_nearby_roofs')
            helper = source_adapter.project(source, '/obj/structure/curtain/proc/refresh_nearby_roofs',
                                            'src, transparent', env.copy(), method=True)
            toggle = source_adapter.project(source, '/obj/structure/curtain/proc/toggle',
                                            'src', env.copy(), method=True)
            new_body = source.split('\tNew()\n', 1)[1].split('\n/obj/structure/curtain/open', 1)[0]
            new_body = '\n'.join(line[1:] if line.startswith('\t') else line
                                 for line in new_body.splitlines()).replace('..()', 'parent()')
            new = source_adapter.project('/curtain/new()\n' + new_body + '\n', '/curtain/new',
                                         'src', env.copy(), method=True)
            destroy_body = source_adapter.extract(source, '/obj/structure/curtain/Destroy').replace('..()', 'parent()')
            destroy = source_adapter.project('/curtain/destroy()\n' + destroy_body + '\n',
                                             '/curtain/destroy', 'src', env.copy(), method=True)
        finally:
            source_adapter.FIELDS = previous

        curtain = SimpleNamespace(opacity=True, loc=None, icon_state='closed')
        curtain.refresh_nearby_roofs = lambda transparent: helper(curtain, transparent)
        new(curtain)
        self.assertEqual(events, [('parent',), ('delay', 1), ('roof', False), ('roof', False)])
        events.clear()
        curtain.opacity = False
        new(curtain)
        self.assertEqual(events, [('parent',), ('delay', 1), ('roof', True), ('roof', True)])
        events.clear()
        curtain.opacity = True
        toggle(curtain)
        self.assertEqual(curtain.icon_state, 'open')
        self.assertEqual(events, [('invalidate',), ('roof', True), ('roof', True), ('overlay',)])
        events.clear()
        toggle(curtain)
        self.assertEqual(curtain.icon_state, 'closed')
        self.assertEqual(events, [('invalidate',), ('roof', False), ('roof', False), ('overlay',)])
        events.clear()
        curtain.opacity = False
        destroy(curtain)
        self.assertEqual(events, [('overlay',), ('parent',), ('roof', False), ('roof', False)])


if __name__ == '__main__':
    unittest.main()
