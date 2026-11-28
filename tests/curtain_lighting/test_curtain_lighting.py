"""Exercise curtain and roof opacity transitions with fake map boundaries."""
import re
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
            def update_transparency(self, value, recheck_openings=False):
                events.append(('roof', value, recheck_openings))

        class Overlay:
            def update_overlay(self):
                events.append(('overlay',))

        roofs = [Roof(), Roof()]
        roof_turf = object()
        curtain = SimpleNamespace(opacity=True, loc=roof_turf, icon_state='closed')

        def detach():
            events.append(('parent',))
            curtain.loc = None

        def nearby_roofs(distance, center):
            if distance == 1 and (center is roof_turf or getattr(center, 'loc', None) is roof_turf):
                return roofs
            return []

        env = {
            'range': nearby_roofs,
            'view': lambda distance, owner: [Overlay()],
            'get_turf': lambda owner: owner.loc,
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
                                             '/curtain/destroy', 'src', {**env, 'parent': detach}, method=True)
        finally:
            source_adapter.FIELDS = previous

        curtain.refresh_nearby_roofs = lambda transparent: helper(curtain, transparent)
        new(curtain)
        self.assertEqual(events, [('parent',), ('delay', 1), ('roof', False, False), ('roof', False, False)])
        events.clear()
        curtain.opacity = False
        new(curtain)
        self.assertEqual(events, [('parent',), ('delay', 1), ('roof', True, False), ('roof', True, False)])
        events.clear()
        curtain.opacity = True
        toggle(curtain)
        self.assertEqual(curtain.icon_state, 'open')
        self.assertEqual(events, [('invalidate',), ('roof', True, False), ('roof', True, False), ('overlay',)])
        events.clear()
        toggle(curtain)
        self.assertEqual(curtain.icon_state, 'closed')
        self.assertEqual(events, [('invalidate',), ('roof', False, False), ('roof', False, False), ('overlay',)])
        events.clear()
        curtain.opacity = False
        destroy(curtain)
        self.assertIsNone(curtain.loc)
        self.assertEqual(events, [('overlay',), ('parent',), ('roof', True, True), ('roof', True, True)])

    def test_roof_recheck_uses_surviving_visible_openings(self):
        source = (ROOT / 'code/game/objects/roof_stuff.dm').read_text()
        source = re.sub(r'/\*.*?\*/', '', source, flags=re.S)
        source = re.sub(r', (/obj/structure/[\w/]+)', r', "\1"', source)
        openings = []
        callbacks = []
        env = {
            'range': lambda distance, center: openings if distance == 1 and center.loc else [],
            'typed_iter': lambda items, kind: items,
            'get_turf': lambda atom: atom.loc,
            'istype': lambda atom, kind: atom.kind == kind or atom.kind.startswith(kind + '/'),
            'deferred': lambda delay: callbacks.append((delay, roof.roof_overlay.alpha)) or True,
        }
        previous = source_adapter.FIELDS
        try:
            source_adapter.FIELDS += ('is_window_opening', 'has_visible_opening', 'roof_overlay')
            roof = SimpleNamespace(roof_overlay=SimpleNamespace(alpha=127))
            for name, args in (
                ('is_window_opening', 'S'),
                ('has_visible_opening', ''),
                ('update_transparency', 'on=True, recheck_openings=False'),
            ):
                signature = 'src, ' + args if args else 'src'
                proc = source_adapter.project(source, '/obj/roof/proc/' + name, signature,
                                              env.copy(), method=True)
                setattr(roof, name, proc.__get__(roof))
        finally:
            source_adapter.FIELDS = previous

        clear = SimpleNamespace(has_opaque_atom=False, recalc_atom_opacity=lambda: None)
        opaque = SimpleNamespace(has_opaque_atom=True, recalc_atom_opacity=lambda: None)
        for kind, opening_turf, roof_turf, initial, expected in (
            (None, None, clear, 127, 255),
            ('window/classic/reinforced', clear, clear, 255, 127),
            ('window/classic/reinforced', clear, clear, 127, 127),
            ('window_frame', clear, clear, 255, 127),
            ('simple_door', clear, clear, 127, 127),
            ('curtain/open', clear, clear, 127, 127),
            ('window/classic', opaque, clear, 127, 255),
            ('window/barrier', clear, clear, 127, 255),
            ('curtain/open', clear, opaque, 127, 255),
            ('curtain/open', clear, None, 127, 127),
        ):
            with self.subTest(kind=kind, opening_turf=opening_turf, roof_turf=roof_turf):
                roof.loc = roof_turf
                roof.roof_overlay.alpha = initial
                openings[:] = [SimpleNamespace(kind='/obj/structure/' + kind, loc=opening_turf)] if kind else []
                callbacks.clear()
                roof.update_transparency(recheck_openings=True)
                self.assertEqual(callbacks, [(1, initial)])
                self.assertEqual(roof.roof_overlay.alpha, expected)


if __name__ == '__main__':
    unittest.main()
