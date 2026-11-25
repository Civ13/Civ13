"""Source contracts for modern bridges. Never launches BYOND."""
from pathlib import Path
import glob
import importlib.util
import re
from types import SimpleNamespace
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run  # noqa: E402

BRIDGES = (ROOT / 'code/modules/1713/bridges.dm').read_text(encoding='utf-8')


class ModernBridgeSourceTests(unittest.TestCase):
    def test_included_once(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\bridges.dm"'), 1)

    def test_spans_are_crafted_wherever_steel_floors_are(self):
        for path in glob.glob(str(ROOT / 'config/crafting/material_recipes_*.txt')):
            text = Path(path).read_text(encoding='utf-8')
            if ',/obj/covers/steelplating,' in text:
                self.assertIn('RECIPE: /material/steel/,steel bridge span,/obj/item/weapon/bridge_span,', text, path)
            # the span is cast from whatever that file builds concrete floors from
            floor = re.search(r'(?m)^RECIPE: (/material/\w+/),[^,]*,/obj/covers/concretefloor,', text)
            if floor:
                self.assertIn('RECIPE: %s,concrete bridge span,/obj/item/weapon/bridge_span/concrete,' % floor.group(1), text, path)

    def test_spans_need_industrial_research(self):
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        for path in ('/obj/item/weapon/bridge_span', '/obj/item/weapon/bridge_span/concrete'):
            self.assertIn('"%s" = "reinforced_concrete"' % path, nodes)

    def test_decks_are_not_sinking_repaired_floors(self):
        # /obj/covers/repairedfloor sinks on saltwater; a bridge deck must not.
        self.assertIn('\n/obj/covers/bridge\n', BRIDGES)
        self.assertNotIn('/obj/covers/repairedfloor', BRIDGES)

    def test_crafting_allowed_while_standing_on_a_deck(self):
        stack = (ROOT / 'code/game/objects/items/stacks/craft_guards.dm').read_text(encoding='utf-8')
        guard = stack.split('/datum/craft_guard/deep_water/refusal(', 1)[1].split('\n\n', 1)[0]
        self.assertIn('!istype(T, /turf/floor/beach/water/deep)', guard)
        self.assertRegex(guard, r'(?m)^\tif \(bridge_deck_at\(T\)\)\n\t\treturn null$')

    def test_track_can_be_laid_on_a_deck(self):
        laying = (ROOT / 'code/modules/1713/track_laying.dm').read_text(encoding='utf-8')
        self.assertIn('(istype(T, /turf/floor/beach/water) && !bridge_deck_at(T))', laying)

    def test_native_fixture_preparation(self):
        generated = run.sources()
        self.assertIn('#include "tests/modern_bridges/probe.dm"', generated[run.PREFIX + '.dme'])
        self.assertNotRegex(generated[run.PREFIX + '.dme'], r'(?m)^#include ".*\.dmm"')


class BridgeHammerClearanceTests(unittest.TestCase):
    """Project the actual timed hammer action and clearance path, not BYOND."""
    def make_hammer_action(self, initial=(), arrives=(), delayed=True):
        spec = importlib.util.spec_from_file_location(
            'bridge_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
        adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(adapter)

        class BridgeDeck:
            pass

        deck = BridgeDeck()
        tile = [deck, *initial]
        actor = SimpleNamespace(turf=object(), visible_message=lambda *args: None)
        outcome = SimpleNamespace(waited=0, refunded=[], removed=[], messages=[])
        def wait(user, time, target):
            self.assertIs(user, actor)
            self.assertEqual(time, 150)
            self.assertIs(target, deck)
            outcome.waited += 1
            tile.extend(arrives)
            return delayed

        clearance_source = re.sub(
            r'locate\((/[^)]+)\) in T', r'contains(T, "\1")', BRIDGES)
        clearance_source = clearance_source.replace('istype(C, /obj/covers/bridge)', 'is_bridge(C)')
        clear_problem = adapter.project(clearance_source, '/proc/bridge_clear_problem', 'T', dict(
            typed_iter=lambda objects, kind: [v for v in objects if isinstance(v, BridgeDeck)],
            is_bridge=lambda value: isinstance(value, BridgeDeck),
            rail_at=lambda T: '/obj/structure/rails' in T,
            contains=lambda T, path: path in T,
        ))
        action_source = BRIDGES.replace('new span_type(get_turf(user))', 'refund(span_type, get_turf(user))')
        action = adapter.project(action_source, '/obj/covers/bridge/proc/take_apart', 'src,user,span_type', dict(
            get_turf=lambda entity: tile if entity is deck else entity.turf,
            bridge_clear_problem=clear_problem,
            to_chat=lambda user, message: outcome.messages.append(message),
            SPAN_NOTICE=lambda msg: msg,
            SPAN_WARNING=lambda msg: msg,
            BRIDGE_SPAN_REMOVE_TIME=150,
            do_after=wait,
            refund=lambda span, turf: outcome.refunded.append((span, turf)),
            qdel=outcome.removed.append,
        ))
        return lambda span: action(deck, actor, span), deck, actor, outcome

    def test_occupied_deck_refuses_before_wait_and_when_occupant_arrives(self):
        for occupant, warning in (
            ('/obj/structure/vehicle', 'Move the vehicle off the deck first.'),
            ('/obj/structure/vehicleparts', 'Move the vehicle off the deck first.'),
            ('/obj/structure/oilwell/offshore', 'Take the offshore drilling rig off the deck first.'),
            ('/obj/structure/rails', 'Take the railway track off the deck first.'),
            ('/mob/living', 'Nobody can stand on the deck while it comes apart.'),
        ):
            for during_wait in (False, True):
                with self.subTest(occupant=occupant, during_wait=during_wait):
                    action, deck, actor, outcome = self.make_hammer_action(
                        initial=() if during_wait else (occupant,),
                        arrives=(occupant,) if during_wait else (),
                    )
                    self.assertFalse(action('steel'))
                    self.assertEqual(outcome.waited, int(during_wait))
                    self.assertEqual(outcome.messages[-1], warning)
                    self.assertEqual(outcome.refunded, [])
                    self.assertEqual(outcome.removed, [])

    def test_bare_steel_and_concrete_decks_refund_only_on_completion(self):
        for span in ('steel', 'concrete'):
            with self.subTest(span=span):
                action, deck, actor, outcome = self.make_hammer_action()
                self.assertTrue(action(span))
                self.assertEqual(outcome.waited, 1)
                self.assertEqual(outcome.refunded, [(span, actor.turf)])
                self.assertEqual(outcome.removed, [deck])
        action, deck, actor, outcome = self.make_hammer_action(delayed=False)
        self.assertFalse(action('steel'))
        self.assertEqual(outcome.waited, 1)
        self.assertEqual(outcome.refunded, [])
        self.assertEqual(outcome.removed, [])


if __name__ == '__main__':
    unittest.main()
