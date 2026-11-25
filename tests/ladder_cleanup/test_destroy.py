"""Offline destruction-chain characterization; no engine or collector launch."""
from itertools import product
from pathlib import Path
import re
import sys
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project

BASE = '/obj/structure/multiz/ladder'
SOURCE = ROOT / 'code/modules/multiz/structures.dm'
BEFORE = Path(__file__).with_name('fixtures') / 'destroy_before.txt'


class LadderViewTests(unittest.TestCase):
    """Execute the production control flow with engine boundaries stubbed."""

    def setUp(self):
        source = SOURCE.read_text(encoding='utf-8')
        body = extract(source, BASE + '/MouseDrop_T')
        body = re.sub(r'(?m)^(\t*)visible_message\(.*\)$', r'\1visible_message()', body)
        body = re.sub(r'\btarget\b', 'src.target', body)
        self.env = dict(istype=lambda value: isinstance(value, Human),
                        QDELETED=lambda value: value is None or getattr(value, 'deleted', False),
                        visible_message=lambda: None, do_after=lambda *args: True)
        self.action = project('/action(dropping, user)\n' + body + '\n', '/action',
                              'src, dropping, user', self.env)
        body = extract(source, '/mob/living/human/proc/update_laddervision')
        body = re.sub(r'(?<![\w.])client\b', 'src.client', body)
        body = self.bind_ladder_fields(body)
        self.update = project('/update(ladder)\n' + body + '\n', '/update', 'src, ladder',
                              dict(istype=lambda value: isinstance(value, Ladder),
                                   EYE_PERSPECTIVE='eye', MOB_PERSPECTIVE='mob'))

    @staticmethod
    def bind_ladder_fields(body):
        return re.sub(r'(?<![\w.])(z|laddervision|laddervision_origin_z|update_laddervision)\b',
                      r'src.\1', body)

    def human(self, connected=True):
        human = Human()
        human.client = SimpleNamespace(perspective='mob', eye=human) if connected else None
        human.laddervision = None
        human.z = 1
        human.laddervision_origin_z = 0
        human.update_laddervision = lambda ladder: self.update(human, ladder)
        return human

    def test_only_self_drag_can_start_and_repeat_stops_viewing(self):
        actor, other, ladder, peer = self.human(), self.human(), Ladder(), Ladder()
        ladder.target = peer
        self.action(ladder, other, actor)
        self.assertIsNone(other.laddervision)
        self.assertIsNone(actor.laddervision)
        self.action(ladder, actor, actor)
        self.assertIs(actor.laddervision, peer)
        self.assertIs(actor.client.eye, peer)
        self.action(ladder, actor, actor)
        self.assertIsNone(actor.laddervision)
        self.assertIs(actor.client.eye, actor)
        self.assertEqual(actor.client.perspective, 'mob')

    def test_wait_rechecks_disconnect_and_target_replacement(self):
        for mutation in ('disconnect', 'replace', 'delete', 'already_viewing'):
            with self.subTest(mutation=mutation):
                actor, ladder, peer = self.human(), Ladder(), Ladder()
                ladder.target = peer
                def wait(*args):
                    if mutation == 'disconnect': actor.client = None
                    if mutation == 'replace': ladder.target = Ladder()
                    if mutation == 'delete': peer.deleted = True
                    if mutation == 'already_viewing': actor.laddervision = Ladder()
                    return True
                self.env['do_after'] = wait
                self.action(ladder, actor, actor)
                self.assertIsNot(actor.laddervision, peer)

    def test_forced_floor_move_drops_only_ladder_owned_eye(self):
        source = SOURCE.read_text(encoding='utf-8')
        body = self.bind_ladder_fields(extract(source, '/mob/living/human/proc/reconcile_laddervision'))
        body = re.sub(r'(?<![\w.])client\b', 'src.client', body)
        reconcile = project('/reconcile()\n' + body + '\n', '/reconcile', 'src', self.env)
        for replacement in (False, True):
            actor, peer = self.human(), Ladder()
            self.update(actor, peer)
            reconcile(actor)
            self.assertIs(actor.client.eye, peer)
            actor.z = 2
            wanted = object() if replacement else actor
            if replacement:
                actor.client.eye = wanted
            reconcile(actor)
            self.assertIsNone(actor.laddervision)
            self.assertEqual(actor.laddervision_origin_z, 0)
            self.assertIs(actor.client.eye, wanted)
            self.assertEqual(actor.client.perspective, 'eye' if replacement else 'mob')

    def test_movement_reconciles_ladder_before_destination_los(self):
        lifecycle = (ROOT / 'code/modules/visibility/los_lifecycle.dm').read_text(encoding='utf-8')
        move = extract(lifecycle, '/proc/los_refresh_moved_viewer')
        self.assertLess(move.index('H.reconcile_laddervision()'), move.index('H.client.reconcile_geometric_los()'))
        for path, name in [('code/game/atoms_movable.dm', 'forceMove'),
                           ('code/game/atoms_movable.dm', 'persistence_set_loc')]:
            source = (ROOT / path).read_text(encoding='utf-8')
            body = extract(source, f'/atom/movable/proc/{name}', defines={'CIV13_ROOT_TREE_PRESENTATION': True})
            self.assertLess(body.index('loc = destination'), body.index('los_refresh_moved_viewer'))

    def test_clientless_clear_still_resets_state(self):
        actor = self.human(connected=False)
        actor.laddervision = Ladder()
        self.update(actor, None)
        self.assertIsNone(actor.laddervision)


CLICK_SOURCE = ROOT / 'code/_onclick/click.dm'


def click_stop_block(source):
    """Return the ClickOn ladder-stop branch, projected as its own procedure."""
    matches = list(re.finditer(r'(?m)^(\t+)if \(istype\(A, /obj/structure/multiz/ladder/ww2\)\).*\n'
                               r'(?:\1\t.*\n)+', source))
    if len(matches) != 1:
        raise AssertionError('Expected exactly one ladder stop click branch')
    depth = len(matches[0][1])
    lines = [line[depth - 1:] for line in matches[0][0].splitlines()]
    body = '\n'.join(lines)
    body = re.sub(r'istype\(A, (/[\w/]+)\)', r'istype(A, "\1")', body)

    def interpolate(match):
        template = match[1]
        expressions = re.findall(r'\[([^\]]+)\]', template)
        text = re.sub(r'\[[^\]]+\]', '{}', template)
        return 'visible_message(fmt(' + ', '.join([repr(text)] + expressions) + '))'
    return re.sub(r'visible_message\("((?:[^"\\]|\\.)*)"\)', interpolate, body)


class LadderStopClickTests(unittest.TestCase):
    """The stop message names the direction that was being viewed (#4196)."""

    def setUp(self):
        self.direction = production_direction()

    def project(self, body):
        return project('/click(A)\n' + body + '\n', '/click', 'src, A',
                       dict(istype=lambda value, kind=None: kind is None and isinstance(value, Viewer)
                            or kind == '/obj/structure/multiz/ladder/ww2',
                            fmt=lambda text, *values: text.format(*values)))

    def stop(self, body, istop):
        viewer = Viewer(Ladder(), self.direction)
        viewer.laddervision.istop = istop
        self.project(body)(viewer, object())
        return viewer

    def test_both_directions_are_named_after_stopping(self):
        body = click_stop_block(CLICK_SOURCE.read_text(encoding='utf-8'))
        for istop, direction in ((True, 'up'), (False, 'down')):
            with self.subTest(direction=direction):
                viewer = self.stop(body, istop)
                self.assertIsNone(viewer.laddervision)
                self.assertEqual(viewer.messages, [
                    f"<span class = 'notice'>{viewer} stops looking {direction} the ladder.</span>"])

    def test_mutation_reading_direction_after_clearing_loses_it(self):
        body = click_stop_block(CLICK_SOURCE.read_text(encoding='utf-8'))
        lines = body.splitlines()
        capture = next(index for index, line in enumerate(lines) if 'laddervision_direction()' in line)
        clear = next(index for index, line in enumerate(lines) if 'update_laddervision(null)' in line)
        self.assertLess(capture, clear)
        lines[capture], lines[clear] = lines[clear], lines[capture]
        viewer = self.stop('\n'.join(lines), True)
        self.assertIn('stops looking  the ladder', viewer.messages[0])


def production_direction():
    """Project the production helper so the test cannot drift from it."""
    body = extract(SOURCE.read_text(encoding='utf-8'), '/mob/living/human/proc/laddervision_direction')
    body = re.sub(r'(?<![\w.])laddervision\b', 'src.laddervision', body)
    body = re.sub(r'var/obj/structure/multiz/ladder', 'var/ladder', body)
    return project('/direction()\n' + body + '\n', '/direction', 'src', {})


class Viewer:
    def __init__(self, ladder, direction):
        self.laddervision = ladder
        self.direction = direction
        self.messages = []

    def __str__(self):
        return 'Viewer'

    def laddervision_direction(self):
        return self.direction(self)

    def update_laddervision(self, ladder):
        self.laddervision = ladder

    def visible_message(self, message):
        self.messages.append(message)


class Human:
    pass


class Ladder:
    pass


def definitions(text, path):
    """Retain every complete same-type definition in textual include order."""
    result = []
    for match in re.finditer(r'^' + re.escape(path) + r'/Destroy\(\)\n', text, re.M):
        body = []
        for line in text[match.end():].splitlines():
            if line.strip() and not line.startswith('\t'):
                break
            body.append(line)
        result.append('\n'.join(body).rstrip())
    return result


class Registry:
    def __init__(self, members, trace):
        self.members = members
        self.trace = trace

    def __isub__(self, owner):
        self.trace.append(('unregister', tuple(self.members)))
        # Explicit boundary model: native -= is not implemented by this test.
        for index in range(len(self.members) - 1, -1, -1):
            if self.members[index] == owner:
                self.members.pop(index)
                break
        return self


class Harness:
    def __init__(self, text, *, ww2=False, top=True, target=True, copies=1,
                 hint='parent-hint', delivery='retain'):
        self.trace = []
        self.owner = SimpleNamespace(target='peer' if target else None, istop=top)
        self.registry = SimpleNamespace(members=Registry(['other'] + ['owner'] * copies, self.trace))
        self.hint = hint
        self.delivery = delivery
        chain = self.parent
        bodies = definitions(text, BASE)
        if ww2:
            bodies += definitions(text, BASE + '/ww2')
        for body in bodies:
            # Rename just this layer so the existing strict projector can accept
            # duplicate declarations without guessing which definition wins.
            body = re.sub(r'\btarget\b', 'owner.target', body)
            body = re.sub(r'\bistop\b', 'owner.istop', body)
            body = re.sub(r'\bsrc\b', '"owner"', body)
            body = body.replace('ladder_list', 'registry.members').replace('..()', 'parent()')
            env = dict(owner=self.owner, registry=self.registry, parent=chain, qdel=self.qdel)
            chain = project('/layer()\n' + body + '\n', '/layer', '', env)
        self.invoke = chain

    def parent(self):
        self.trace.append(('parent', tuple(self.registry.members.members)))
        return self.hint

    def qdel(self, target):
        self.trace.append(('qdel', target, tuple(self.registry.members.members)))
        if self.delivery == 'clear-target':
            self.owner.target = None
        elif self.delivery == 'clear-top':
            self.owner.istop = False

    def run(self):
        result = self.invoke()
        return result, self.trace, self.registry.members.members, self.owner.target, self.owner.istop


class DestroyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.before = BEFORE.read_text(encoding='utf-8')
        cls.after = SOURCE.read_text(encoding='utf-8')

    def test_preimage_and_single_definition_keep_ww2_layer(self):
        self.assertEqual(len(definitions(self.before, BASE)), 2)
        self.assertEqual(len(definitions(self.after, BASE)), 1)
        self.assertEqual(definitions(self.before, BASE + '/ww2'), definitions(self.after, BASE + '/ww2'))

    def test_before_after_matrix(self):
        cases = product((False, True), (False, True), (False, True), (0, 1, 2), (None, 'hint'))
        for ww2, top, target, copies, hint in cases:
            with self.subTest(ww2=ww2, top=top, target=target, copies=copies, hint=hint):
                options = dict(ww2=ww2, top=top, target=target, copies=copies, hint=hint)
                old = Harness(self.before, **options).run()
                new = Harness(self.after, **options).run()
                self.assertEqual(new, old)
                self.assertIsNone(new[0])
                self.assertEqual(sum(row[0] == 'parent' for row in new[1]), 1)
                self.assertEqual(new[2].count('other'), 1)

    def test_partner_cleanup_precedes_registry_then_parent(self):
        trace = Harness(self.after).run()[1]
        self.assertEqual(trace, [('qdel', 'peer', ('other', 'owner')),
                                 ('unregister', ('other', 'owner')), ('parent', ('other',))])

    def test_ww2_retains_two_requests_when_boundary_retains_target(self):
        self.assertEqual([row[0] for row in Harness(self.after, ww2=True).run()[1]],
                         ['qdel', 'qdel', 'unregister', 'parent'])

    def test_callback_state_changes_are_observed_by_next_layer(self):
        for delivery in ('clear-target', 'clear-top'):
            options = dict(ww2=True, delivery=delivery)
            old = Harness(self.before, **options).run()
            new = Harness(self.after, **options).run()
            self.assertEqual(new, old)
            self.assertEqual([row[0] for row in new[1]], ['qdel', 'unregister', 'parent'])

    def test_mutation_controls_detect_missing_effects_order_and_return(self):
        body = definitions(self.after, BASE)[0]
        variants = [body.replace('\t\tqdel(target)', '\t\t..()'),
                    body.replace('\tladder_list -= src\n', ''),
                    body.replace('\t..()', '\treturn null'),
                    body.replace('\tladder_list -= src\n', '').replace('\tif (', '\tladder_list -= src\n\tif (', 1),
                    body.replace('\t..()', '\treturn ..()')]
        expected = Harness(self.after).run()
        for mutant in variants:
            with self.subTest(mutant=mutant):
                self.assertNotEqual(Harness(BASE + '/Destroy()\n' + mutant + '\n').run(), expected)


class SiegeLadderTile(list):
    pass


class SiegeLadderTarget:
    def __init__(self, loc, *, key=None, climbable=False, inherent=False, eligible=True):
        self.loc = loc
        self.siege_ladder_support_key = key
        self.climbable = climbable
        self.initial_climbable = inherent
        self.eligible = eligible
        self.dir = 2
        self.deleted = False
        loc.append(self)

    def supports_siege_ladders(self):
        return self.eligible

    def ensure_siege_ladder_support_key(self):
        self.siege_ladder_support_key = self.siege_ladder_support_key or 'adopted-key'
        return self.siege_ladder_support_key


class SiegeLadderItem:
    def __init__(self, loc, key=None):
        self.loc = loc
        self.ladder_target_key = key
        self.anchored = True
        self.deployed = True
        self.deleted = False
        self.dir = 2
        self.icon_state = 'deployed'
        loc.append(self)


class SiegeLadderSupportTests(unittest.TestCase):
    """Run the actual support selection and retraction procs without a game server."""

    ITEM = '/obj/item/weapon/siegeladder'
    TOOL_PATH = 'code/game/objects/items/weapons/tools.dm'
    STRUCTURE_PATH = 'code/game/objects/structures.dm'
    TRAPS_PATH = 'code/modules/1713/siege/castle_traps.dm'

    @staticmethod
    def read(path):
        return (ROOT / path).read_text(encoding='utf-8')

    def setUp(self):
        self.env = dict(
            isturf=lambda value: isinstance(value, SiegeLadderTile),
            QDELETED=lambda value: value is None or value.deleted,
            initial=lambda value: 'stowed',
            typed_iter=lambda values, path: [value for value in values if isinstance(
                value, SiegeLadderItem if path == self.ITEM else SiegeLadderTarget
            )],
        )
        self.select = self.bind(self.TOOL_PATH, self.ITEM + '/proc/deployed_target')
        self.retract = self.bind(self.TOOL_PATH, self.ITEM + '/proc/retract')
        self.access = self.bind(self.STRUCTURE_PATH, '/obj/structure/proc/is_climbable_with_support')

    def bind(self, path, declaration):
        source = extract(self.read(path), declaration)
        source = re.sub(r'(?m)^(\t+var/[\w/]+)$', r'\1 = null', source)
        source = re.sub(r'initial\((S|target)\.climbable\)', r'\1.initial_climbable', source)
        source = re.sub(
            r'(?<![\w.])(loc|deployed|anchored|dir|ladder_target_key|deployed_target|icon_state|climbable|supports_siege_ladders)\b',
            r'src.\1', source,
        )
        return project('/selection()\n' + source + '\n', '/selection', 'src', self.env)

    def ladder(self, tile, key=None):
        item = SiegeLadderItem(tile, key)
        item.deployed_target = lambda: self.select(item)
        return item

    def test_remove_one_keyed_ladder_preserves_other_and_intrinsic_routes(self):
        tile = SiegeLadderTile()
        target = SiegeLadderTarget(tile, key='target')
        second_target = SiegeLadderTarget(tile, key='other')
        intrinsic = SiegeLadderTarget(tile, climbable=True, inherent=True, eligible=False)
        first, second = self.ladder(tile, 'target'), self.ladder(tile, 'target')
        unrelated = self.ladder(tile, 'other')
        self.assertTrue(self.access(target) and self.access(second_target) and self.access(intrinsic))
        self.assertTrue(self.retract(first))
        self.assertTrue(self.access(target))
        self.assertTrue(self.retract(second))
        self.assertFalse(self.access(target))
        self.assertTrue(self.access(second_target) and self.access(intrinsic))
        self.assertIs(self.select(unrelated), second_target)
        self.assertIsNone(first.ladder_target_key)
        self.assertFalse(first.deployed or first.anchored)
        self.assertEqual(first.icon_state, 'stowed')

    def test_persisted_scalar_recovers_route_only_on_the_same_tile(self):
        tile, other_tile = SiegeLadderTile(), SiegeLadderTile()
        # Separate reconstructed objects; only the value stored in the save joins them.
        target = SiegeLadderTarget(tile, key='stored-target')
        recovered = self.ladder(tile, key='stored-target')
        unrelated = SiegeLadderTarget(tile, key='unrelated')
        self.assertIs(self.select(recovered), target)
        self.assertFalse(self.access(unrelated))
        tile.remove(target)
        other_tile.append(target)
        target.loc = other_tile
        self.assertIsNone(self.select(recovered))
        self.assertFalse(self.access(target))

    def test_old_flag_adopts_all_identifiable_ladders_before_it_is_cleared(self):
        tile = SiegeLadderTile()
        target = SiegeLadderTarget(tile, climbable=True)
        nearby = SiegeLadderTarget(tile)
        intrinsic = SiegeLadderTarget(tile, climbable=True, inherent=True)
        first, second = self.ladder(tile), self.ladder(tile)
        self.assertIs(self.select(second), target)
        self.assertTrue(self.retract(first))
        self.assertFalse(target.climbable)
        self.assertEqual(second.ladder_target_key, target.siege_ladder_support_key)
        self.assertTrue(self.access(target))
        self.assertFalse(self.access(nearby))
        self.assertTrue(self.retract(second))
        self.assertFalse(self.access(target))
        self.assertTrue(self.access(intrinsic))

    def test_ambiguous_legacy_ladder_does_not_invent_a_target(self):
        tile = SiegeLadderTile()
        left = SiegeLadderTarget(tile, climbable=True)
        right = SiegeLadderTarget(tile, climbable=True)
        item = self.ladder(tile)
        self.assertIsNone(self.select(item))
        self.assertTrue(self.retract(item))
        self.assertTrue(left.climbable and right.climbable)

    def test_deployment_and_both_removal_paths_use_support_procs(self):
        for path, declaration in (
            ('code/game/objects/controls.dm', '/obj/structure/gate/attackby'),
            ('code/game/objects/structures/barricades.dm', '/obj/structure/barricade/attackby'),
            ('code/modules/1713/structures.dm', '/obj/structure/grille/metalsheetfence/attackby'),
        ):
            source = extract(self.read(path), declaration)
            self.assertIn('do_after(user, 8 SECONDS, src) && ladder.deploy_on(src, user)', source)
            self.assertNotIn('climbable = TRUE', source)
        hand = extract(self.read(self.TOOL_PATH), self.ITEM + '/attack_hand')
        fork = extract(self.read(self.TRAPS_PATH).split('\n#undef', 1)[0], self.ITEM + '/proc/push_off')
        self.assertIn('do_after(user, 8 SECONDS, src) && retract()', hand)
        self.assertLess(fork.index('if (!retract())'), fork.index('!target.is_climbable_with_support()'))
        self.assertIn('fallers = target.climbers.Copy()', fork)
        self.assertNotIn('climbable = FALSE', hand + fork)


if __name__ == '__main__':
    unittest.main()
