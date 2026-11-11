"""Project the production manual-stack transaction with injected engine effects.

This checks control flow and scalar accounting, not DM runtime or item movement.
"""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/structures/blacksmithing/refining.dm').read_text(encoding='utf-8')
HELPER = '/obj/structure/furnace/proc/accept_manual_stack'
_spec = importlib.util.spec_from_file_location('grinder_projection', ROOT / 'tests/grinder/test_transaction.py')
projection = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(projection)


class Actor(projection.Record):
    def __init__(self):
        super().__init__(removed=[])

    def remove_from_mob(self, item):
        self.removed.append(item)


class Furnace(projection.Record):
    def __init__(self):
        super().__init__(fuel=0, iron=0, recorded=[])

    def record_wood_fuel(self, item, amount):
        self.recorded.append((item, amount))


def transact(kind, amount=2, source=SOURCE):
    furnace, actor = Furnace(), Actor()
    item = projection.Record(type=kind, amount=amount, loc=actor, gcDestroyed=False)
    projection.Projection(source).run(HELPER, furnace, I=item, H=actor)
    return furnace, actor, item


class FurnaceManual(unittest.TestCase):
    def test_both_handlers_dispatch_only_live_help_intent_stacks(self):
        p = projection.Projection(SOURCE)
        for path in ('/obj/structure/furnace/attackby', '/obj/structure/furnace/blast_furnace/attackby'):
            with self.subTest(path=path):
                lines = p.proc(path)
                self.assertEqual(lines[:5], [(1, 'if (!I || !I.loc)'), (2, 'return'),
                                             (1, 'if (!istype(H))'), (2, 'return'),
                                             (1, 'if (H.a_intent == I_HELP)')])
                self.assertIn((2, 'if (istype(I, /obj/item/stack/))'), lines)
                self.assertIn((3, 'accept_manual_stack(I, H)'), lines)
                index = lines.index((3, 'accept_manual_stack(I, H)'))
                self.assertEqual(lines[index + 1], (3, 'return'))
        self.assertNotIn('accept_manual_stack', '\n'.join(line for _, line in p.proc('/obj/structure/furnace/kiln/attackby')))

    def test_fuel_values_and_credits_consume_once(self):
        fuels = {
            '/obj/item/stack/material/wood': 2,
            '/obj/item/stack/material/bamboo': 2,
            '/obj/item/stack/material/leaf': 2.5,
            '/obj/item/stack/dung': 3,
            '/obj/item/stack/ore/charcoal': 5,
            '/obj/item/stack/ore/coal': 6,
            '/obj/item/stack/material/woodplank': 2,
        }
        for kind, credit in fuels.items():
            with self.subTest(kind=kind):
                furnace, actor, item = transact(kind)
                self.assertEqual((furnace.fuel, furnace.iron), (credit, 0))
                self.assertEqual(furnace.recorded, [(item, credit)])
                self.assertEqual(actor.removed, [item])
                self.assertTrue(item.gcDestroyed)
                self.assertIsNone(item.loc)  # The attackby's live-item guard rejects a repeat.

    def test_ore_and_unknown_stack(self):
        furnace, actor, ore = transact('/obj/item/stack/ore/iron', 3)
        self.assertEqual((furnace.iron, furnace.fuel, furnace.recorded), (3, 0, []))
        self.assertEqual(actor.removed, [ore])
        self.assertTrue(ore.gcDestroyed)
        furnace, actor, stone = transact('/obj/item/stack/material/stone', 3)
        self.assertEqual((furnace.iron, furnace.fuel, furnace.recorded), (0, 0, []))
        self.assertEqual(actor.removed, [])
        self.assertFalse(stone.gcDestroyed)
        self.assertIs(stone.loc, actor)

    def test_negative_controls_detect_retained_or_rejected_fuel(self):
        no_delete = SOURCE.replace('\n\tqdel(I)\n\treturn\n\n/obj/structure/furnace/proc/handle_structure_tool',
                                   '\n\treturn\n\n/obj/structure/furnace/proc/handle_structure_tool', 1)
        self.assertNotEqual(no_delete, SOURCE)
        _, _, item = transact('/obj/item/stack/material/wood', source=no_delete)
        self.assertFalse(item.gcDestroyed)
        broken_chain = SOURCE.replace('else if (istype(I, /obj/item/stack/ore/iron))',
                                      'if (istype(I, /obj/item/stack/ore/iron))', 1)
        self.assertNotEqual(broken_chain, SOURCE)
        furnace, actor, item = transact('/obj/item/stack/material/wood', source=broken_chain)
        self.assertEqual(furnace.fuel, 2)
        self.assertEqual(actor.removed, [])
        self.assertFalse(item.gcDestroyed)


class ToolProjection(projection.Projection):
    def expression(self, text, receiver, local):
        # Supply deterministic wait and parent adapters without emulating DM scheduling.
        return super().expression(text.replace('do_after(H,50,src)', 'wait()'), receiver, local)


def tool_action(handler, kind, completed, anchored=True, source=SOURCE):
    # Parent fallback is an injected observation; all other logic comes from source.
    # The scalar projector cannot parse DM type paths with a trailing slash.
    p = ToolProjection(source.replace('..()', 'parent()').replace('/obj/item/stack/)', '/obj/item/stack)'))
    events = []
    furnace = projection.Record(anchored=anchored, gcDestroyed=False, loc='floor', I_HELP='help')
    furnace.wait = lambda: events.append('wait') or completed
    furnace.empty = lambda: events.append('empty:' + handler)
    furnace.parent = lambda: events.append('parent')
    furnace.handle_structure_tool = lambda item, actor: p.run(
        '/obj/structure/furnace/proc/handle_structure_tool', furnace, I=item, H=actor)
    actor = projection.Record(type='/mob/living/human', a_intent='help')
    item = projection.Record(type=kind, loc=actor, basematerials=projection.Record(len=0))
    p.run(handler, furnace, I=item, H=actor)
    return furnace, events


class FurnaceToolActions(unittest.TestCase):
    handlers = ('/obj/structure/furnace/attackby',
                '/obj/structure/furnace/blast_furnace/attackby',
                '/obj/structure/furnace/kiln/attackby')
    wrench = '/obj/item/weapon/wrench'
    hammer = '/obj/item/weapon/hammer'

    def test_success_and_interruption_preserve_each_handler(self):
        for handler in self.handlers:
            for tool in (self.wrench, self.hammer):
                for completed in (False, True):
                    for anchored in (False, True):
                        with self.subTest(handler=handler, tool=tool, completed=completed, anchored=anchored):
                            furnace, events = tool_action(handler, tool, completed, anchored)
                            expected = ['wait']
                            if completed and tool == self.hammer:
                                expected.append('empty:' + handler)
                            if not completed and handler == self.handlers[0]:
                                expected.append('parent')
                            self.assertEqual(events, expected)
                            self.assertEqual(furnace.anchored, not anchored if completed and tool == self.wrench else anchored)
                            self.assertEqual(furnace.gcDestroyed, completed and tool == self.hammer)

    def test_non_tool_does_not_wait_and_continues_to_parent(self):
        furnace, events = tool_action(self.handlers[0], '/obj/item/other', True)
        self.assertEqual(events, ['parent'])
        self.assertFalse(furnace.gcDestroyed)

    def test_negative_controls_detect_interrupted_return_and_missing_empty(self):
        broken = SOURCE.replace('\n\treturn FALSE\n\n/obj/structure/furnace/attackby',
                                '\n\treturn TRUE\n\n/obj/structure/furnace/attackby', 1)
        self.assertNotEqual(broken, SOURCE)
        _, events = tool_action(self.handlers[0], self.wrench, False, source=broken)
        self.assertNotEqual(events, ['wait', 'parent'])
        broken = SOURCE.replace('\n\t\t\t\tempty()\n\t\t\t\tqdel(src)',
                                '\n\t\t\t\tqdel(src)', 1)
        self.assertNotEqual(broken, SOURCE)
        _, events = tool_action(self.handlers[1], self.hammer, True, source=broken)
        self.assertNotIn('empty:' + self.handlers[1], events)


if __name__ == '__main__':
    unittest.main()
