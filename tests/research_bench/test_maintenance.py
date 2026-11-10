"""Offline production control-flow checks, with explicit fake engine boundaries.

Executes complete bench attackby/maintenance/Destroy and faction-count bodies.
Messages, time, inventory, research-map APIs, qdel and constructors are adapters;
this does not establish native timing, movement, UI or save/load acceptance.
"""
from pathlib import Path
import math
import re
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
BENCH = '/obj/structure/research_bench'
SOURCE = (ROOT / 'code/modules/research_tree/research_bench.dm').read_text()
FACTION = (ROOT / 'code/modules/research_tree/research_faction.dm').read_text()
DEFINES = (ROOT / 'code/modules/research_tree/_research_tree_defines.dm').read_text()
CONSTANTS = {name: float(value) if '.' in value else int(value)
             for name, value in re.findall(r'^#define (RESEARCH_MODE_\w+|RESEARCH_\w+_FRACTION|RNODE_ENTRY_TICKS)\s+([0-9.]+)', DEFINES, re.M)}
WRENCH = '/obj/item/weapon/wrench'
HAMMER = '/obj/item/weapon/hammer'
BOOK = '/obj/item/weapon/book/research/tree_book'
COPPER = '/obj/item/stack/money/coppercoin'


def body(source, path):
    match = re.search(r'^' + re.escape(path) + r'\([^\n]*\)\n(.*?)(?=^/|\Z)', source, re.M | re.S)
    if not match:
        raise AssertionError('Missing production procedure: ' + path)
    return match[1]


class DMList(list):
    def __iadd__(self, item):
        if item not in self:
            self.append(item)
        return self

    def __isub__(self, item):
        if item in self:
            self.remove(item)
        return self


def istype(item, path='/obj/item'):
    return bool(item and (item.type == path or item.type.startswith(path + '/')))


FIELDS = ('assigned_node', 'faction', 'tier', 'studied_samples', 'not_movable',
          'not_disassemblable', 'powersource', 'anchored', 'contents', 'loc')
METHODS = ('maintain_bench', 'is_upgrade_coin', 'try_feed_coins', 'try_advance_queue',
           'anchor_changed', 'book_mode', 'book_attackby')


def project(source, path, args, env, fields=FIELDS):
    """Translate every executable line of a selected complete production proc.

    No branch is omitted. Unsupported syntax fails compilation. Only opaque
    player messages and native engine boundaries are replaced with adapters.
    """
    lines = ['def projected(' + args + '):', '    global research_benches']
    for raw in body(source, path).splitlines():
        text = raw.split('//', 1)[0].rstrip()
        if not text.strip():
            continue
        indent = len(text) - len(text.lstrip('\t'))
        text = text.strip()
        if text.startswith('to_chat('):
            text = 'message()'  # messages have no gameplay side effects
        else:
            text = re.sub(r'for \(var/((?:obj|mob)(?:/\w+)*)/(\w+) in (.+)\)',
                          r'for (\2 in typed_iter(\3, /\1))', text)
            text = re.sub(r'var/(?:\w+/)*(\w+)', r'\1', text)
            text = text.replace('..()', 'parent()')
            text = re.sub(r'(/(?:obj|mob)(?:/\w+)+)', lambda m: repr(m[1]), text)
            text = text.replace('using_wrench ? 15 : 25', '(15 if using_wrench else 25)')
            text = text.replace('isnum(book.boost_scale) ? clamp(book.boost_scale, 0.25, 3) : 1',
                                '(clamp(book.boost_scale, 0.25, 3) if isnum(book.boost_scale) else 1)')
            text = text.replace('&&', ' and ').replace('||', ' or ')
            text = re.sub(r'!(?!=)', 'not ', text)
            text = re.sub(r'\b(TRUE|FALSE|null)\b', lambda m: {'TRUE': 'True', 'FALSE': 'False', 'null': 'None'}[m[1]], text)
            text = re.sub(r"^new ('[^']+')\((.*)\)$", r'new(\1, \2)', text)
            text = re.sub(r'^(\w+)\+\+$', r'\1 += 1', text)
            # Count's argument named faction must not become a receiver field.
            names = set(fields) - set(args.split(', '))
            pieces = re.split(r'("(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\')', text)
            for i in range(0, len(pieces), 2):
                for name in names | (set(METHODS) if fields else set()):
                    pieces[i] = re.sub(r'(?<![\w.])' + name + r'\b', 'src.' + name, pieces[i])
            text = ''.join(pieces)
        if text.startswith('if ('):
            text = 'if ' + text[4:-1] + ':'
        elif text.startswith('else if ('):
            text = 'elif ' + text[9:-1] + ':'
        elif text == 'else':
            text += ':'
        elif text.startswith('for ('):
            text = 'for ' + text[5:-1] + ':'
        lines.append('    ' * indent + text)
    translated = '\n'.join(lines) + '\n'
    exec(compile(translated, path, 'exec'), env)
    return env['projected']


class Case:
    def __init__(self, source=SOURCE, kind=WRENCH, intent='harm', staff=True):
        self.source = source
        self.events = []
        self.wait_effect = lambda: None
        self.wait_result = True
        self.in_range = True
        self.item = NS(type=kind, deleted=False, subject='tools', transfer_type='book', boost_scale=1)
        self.user = NS(type='/mob/living/human', civilization='A', a_intent=intent,
                       deleted=False, hand=self.item)
        self.user.get_active_hand = lambda: self.user.hand
        self.bench = NS(type=BENCH, assigned_node='tools', faction='A', tier=0,
                        studied_samples=None, not_movable=False, not_disassemblable=False,
                        powersource=None, anchored=True, contents=[], loc='bench turf', deleted=False)
        self.registry = DMList([self.bench])
        self.node = NS(mode=CONSTANTS['RESEARCH_MODE_ANALYSIS'], prototype_type=None, min_bench_tier=0, cost_ticks=100)
        self.ticks = 0
        self.done = False
        self.prereqs = True
        self.prototype = False
        self.map = NS(can_manage_faction_research=lambda *_: staff,
                      is_node_done=lambda *_: self.done,
                      node_prereqs_met=lambda *_: self.prereqs,
                      add_research_ticks=self.add_ticks,
                      complete_node=self.complete,
                      node_prototype_submitted=lambda *_: self.prototype,
                      set_prototype_submitted=lambda *_: setattr(self, 'prototype', True),
                      get_node_entry=lambda *_: {CONSTANTS['RNODE_ENTRY_TICKS']: self.ticks})
        self.env = dict(map=self.map, research_benches=self.registry, I_HARM='harm',
                        typed_iter=lambda items, kind: [x for x in items if istype(x, kind)],
                        istype=istype, ishuman=lambda x: istype(x, '/mob/living/human'),
                        QDELETED=lambda x: x is None or x.deleted,
                        do_after=self.wait, in_range=lambda *_: self.in_range,
                        new=lambda kind, loc: self.events.append(('new', kind, loc)),
                        get_turf=lambda x: x.loc,
                        qdel=self.delete,
                        playsound=lambda *_: None, message=lambda: None,
                        parent=lambda: self.events.append(('parent',)),
                        get_research_node=lambda _: self.node,
                        get_node_recipe_paths=lambda _: [WRENCH, HAMMER],
                        list=DMList, max=max, round=math.floor,
                        isnum=lambda x: isinstance(x, (int, float)),
                        clamp=lambda x, low, high: min(high, max(low, x)))
        self.env.update(CONSTANTS)
        self.attack = project(source, BENCH + '/attackby', 'src, W, user', self.env)
        self.maintain = project(source, BENCH + '/proc/maintain_bench', 'src, W, user', self.env)
        self.destroy = project(source, BENCH + '/Destroy', 'src', self.env)
        self.count = project(FACTION, '/obj/map_metadata/proc/count_faction_benches',
                             'src, faction', self.env, fields=())
        coin = project(source, BENCH + '/proc/is_upgrade_coin', 'src, W', self.env)
        self.bench.maintain_bench = lambda W, user: self.maintain(self.bench, W, user)
        self.bench.is_upgrade_coin = lambda W: coin(self.bench, W)
        self.bench.try_feed_coins = lambda *_: self.events.append(('coins',))
        self.bench.try_advance_queue = lambda: self.events.append(('queue',))
        self.bench.anchor_changed = lambda: self.events.append(('anchor',))
        # Book research (opt-in, off here) has its own fixture in tests/recipe_knowledge.
        self.bench.book_mode = lambda: False
        self.bench.book_attackby = lambda *_: self.events.append(('book',))

    def wait(self, user, delay, target):
        self.events.append(('wait', delay))
        self.wait_effect()
        return self.wait_result

    def delete(self, item):
        if item.deleted:
            raise AssertionError('duplicate qdel')
        item.deleted = True
        self.events.append(('delete', item.type))
        if item is self.bench:
            self.destroy(item)

    def add_ticks(self, *_args):
        self.ticks += _args[-1]
        return False

    def complete(self, *_):
        self.done = True
        return True

    def click(self):
        return self.attack(self.bench, self.item, self.user)


class BenchMaintenance(unittest.TestCase):
    def test_harm_wrench_toggles_without_research_or_tool_consumption(self):
        c = Case()
        self.assertTrue(c.click())
        self.assertFalse(c.bench.anchored)
        self.assertEqual(c.events, [('wait', 15), ('anchor',)])
        self.assertTrue(c.click())
        self.assertTrue(c.bench.anchored)
        self.assertFalse(c.item.deleted)
        self.assertEqual(c.ticks, 0)

    def test_hammer_frees_only_its_factions_slot_and_preserves_research(self):
        for anchored in (True, False):
            c = Case(kind=HAMMER)
            c.bench.anchored = anchored
            c.ticks = 37
            c.registry.extend([NS(type=BENCH, faction='A'), NS(type=BENCH, faction='B'),
                               NS(type=BENCH + '/adminbench', faction='A')])
            self.assertEqual(c.count(c.map, 'A'), 2)
            c.click()
            self.assertTrue(c.bench.deleted)
            self.assertFalse(c.item.deleted)
            self.assertEqual(c.count(c.map, 'A'), 1)
            self.assertEqual(c.count(c.map, 'B'), 1)
            self.assertEqual(c.ticks, 37)
            self.assertEqual([e for e in c.events if e[0] == 'new'],
                             [('new', '/obj/item/stack/material/wood', 'bench turf')])

    def test_dismantling_releases_contained_books_like_generic_structures(self):
        c = Case(kind=HAMMER)
        book = NS(type=BOOK, loc=c.bench)
        other = NS(type=WRENCH, loc=c.bench)
        c.bench.contents = [book, other]
        c.click()
        self.assertEqual(book.loc, 'bench turf')
        self.assertIs(other.loc, c.bench)  # Typed book loop, not arbitrary contents.

    def test_idle_max_tier_and_non_staff_can_maintain(self):
        for kind in (WRENCH, HAMMER):
            c = Case(kind=kind, staff=False)
            c.bench.assigned_node = None
            c.bench.tier = 100
            c.click()
            self.assertIn(('wait', 15 if kind == WRENCH else 25), c.events)
            self.assertNotIn(('coins',), c.events)

    def test_non_harm_tools_keep_sample_submission_and_staff_gate(self):
        for kind in (WRENCH, HAMMER, WRENCH + '/pipe'):
            for intent in ('help', 'disarm', 'grab'):
                for staff in (True, False):
                    c = Case(kind=kind, intent=intent, staff=staff)
                    c.click()
                    self.assertEqual(c.item.deleted, staff)
                    self.assertEqual(c.ticks, 12 if staff else 0)
                    self.assertTrue(c.bench.anchored)
                    self.assertFalse(c.bench.deleted)
                    self.assertFalse(any(e[0] == 'wait' for e in c.events))

    def test_wrong_faction_unowned_nonhuman_and_missing_map_refuse(self):
        for kind in (WRENCH, HAMMER):
            for fault in ('foreign', 'no_faction', 'none_faction', 'unclaimed', 'nonhuman', 'map'):
                c = Case(kind=kind)
                if fault == 'foreign': c.user.civilization = 'B'
                if fault == 'no_faction': c.user.civilization = None
                if fault == 'none_faction': c.user.civilization = c.bench.faction = 'none'
                if fault == 'unclaimed': c.bench.faction = None
                if fault == 'nonhuman': c.user.type = '/mob/living/animal'
                if fault == 'map': c.env['map'] = None
                c.click()
                self.assertEqual(c.events, [], (kind, fault))
                self.assertFalse(c.item.deleted)

    def test_cancelled_or_stale_wait_has_no_effect(self):
        for kind in (WRENCH, HAMMER):
            for fault in ('cancel', 'user_faction', 'bench_faction', 'both_factions', 'intent',
                          'hand', 'range', 'item_deleted', 'user_deleted', 'bench_deleted', 'map'):
                c = Case(kind=kind)
                def change():
                    if fault == 'cancel': c.wait_result = False
                    if fault == 'user_faction': c.user.civilization = 'B'
                    if fault == 'bench_faction': c.bench.faction = 'B'
                    if fault == 'both_factions': c.user.civilization = c.bench.faction = 'B'
                    if fault == 'intent': c.user.a_intent = 'help'
                    if fault == 'hand': c.user.hand = None
                    if fault == 'range': c.in_range = False
                    if fault == 'item_deleted': c.item.deleted = True
                    if fault == 'user_deleted': c.user.deleted = True
                    if fault == 'bench_deleted': c.bench.deleted = True
                    if fault == 'map': c.env['map'] = None
                c.wait_effect = change
                c.click()
                self.assertEqual(c.events, [('wait', 15 if kind == WRENCH else 25)], (kind, fault))
                self.assertTrue(c.bench.anchored)

    def test_flags_power_and_concurrent_wrench_state_are_rechecked(self):
        for kind, field in ((WRENCH, 'not_movable'), (WRENCH, 'powersource'),
                            (HAMMER, 'not_disassemblable')):
            for during_wait in (False, True):
                c = Case(kind=kind)
                change = lambda: setattr(c.bench, field, True)
                if during_wait: c.wait_effect = change
                else: change()
                c.click()
                self.assertEqual(c.events, [('wait', 15 if kind == WRENCH else 25)] if during_wait else [])
        c = Case()
        c.wait_effect = lambda: setattr(c.bench, 'anchored', False)
        c.click()
        self.assertFalse(c.bench.anchored)
        self.assertNotIn(('anchor',), c.events)

    def test_books_prototypes_and_idle_coins_keep_existing_dispatch(self):
        c = Case(kind=BOOK, intent='help')
        c.click()
        self.assertTrue(c.done)
        self.assertTrue(c.item.deleted)
        c = Case(kind=WRENCH, intent='help')
        c.node.mode, c.node.prototype_type = CONSTANTS['RESEARCH_MODE_PROTOTYPE'], WRENCH
        c.click()
        self.assertTrue(c.prototype)
        self.assertTrue(c.item.deleted)
        c = Case(kind=COPPER, intent='help')
        c.bench.assigned_node = None
        c.click()
        self.assertEqual(c.events, [('coins',)])

    def test_duplicate_samples_and_prerequisite_completion_gates_remain(self):
        for fault in ('duplicate', 'prereqs', 'done', 'book_mode'):
            c = Case(intent='help')
            if fault == 'duplicate': c.bench.studied_samples = DMList([WRENCH])
            if fault == 'prereqs': c.prereqs = False
            if fault == 'done': c.done = True
            if fault == 'book_mode': c.node.mode = CONSTANTS['RESEARCH_MODE_BOOK']
            c.click()
            self.assertFalse(c.item.deleted, fault)
            self.assertEqual(c.ticks, 0, fault)

    def test_examine_hint_precedes_idle_return_and_dismantling_is_enabled(self):
        hint = body(SOURCE, BENCH + '/examine')
        self.assertLess(hint.index('Use Help intent'), hint.index('if (!assigned_node)'))
        for phrase in ('including tools', 'Harm intent', 'wrench', 'hammer', 'owning faction'):
            self.assertIn(phrase, hint)
        declaration = SOURCE.split(BENCH + '\n', 1)[1].split('\n/', 1)[0]
        self.assertIn('not_disassemblable = FALSE', declaration)

    def test_mutations_expose_wrong_intent_ownership_and_slot_cleanup(self):
        def mutate(old, new):
            self.assertIn(old, SOURCE)
            return SOURCE.replace(old, new, 1)
        c = Case(mutate('user.a_intent == I_HARM &&', 'user.a_intent != I_HARM &&'))
        c.click()
        self.assertTrue(c.item.deleted)  # Harm was wrongly consumed as a sample.
        c = Case(mutate('faction != owning_faction || ', ''), kind=HAMMER)
        def transfer():
            c.user.civilization = c.bench.faction = 'B'
        c.wait_effect = transfer
        c.click()
        self.assertTrue(c.bench.deleted)  # Ownership transfer should cancel.
        c = Case(mutate('\tresearch_benches -= src\n', ''), kind=HAMMER)
        c.click()
        self.assertEqual(c.count(c.map, 'A'), 1)  # Deleted bench wrongly keeps its slot.


if __name__ == '__main__':
    unittest.main()
