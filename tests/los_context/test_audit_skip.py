"""Offline projection of the presentation-audit skip; no native pixels or FPS.

The one-second audit used to repay the whole presenter refresh for every idle
client. The projected production procs below must renew the audit only for a
scene whose blockers, tree bounds, atoms, appearances and client image/screen
counts are all unchanged, and must refresh for every other difference.
"""
import re
import unittest
from pathlib import Path
from types import SimpleNamespace as N

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / 'code/modules/visibility/los_context.dm'
LIFECYCLE = ROOT / 'code/modules/visibility/los_lifecycle.dm'
PRESENTER = ROOT / 'code/modules/visibility/los_presenter.dm'
TREE = ROOT / 'code/modules/visibility/root_tree_presenter.dm'

SNAPSHOT_FIELDS = ['presentation', 'eye_x', 'eye_y', 'eye_z', 'radius_x', 'radius_y', 'blockers', 'tree_bounds']
CONTEXT_FIELDS = ['audit_snapshot', 'audit_appearances', 'audit_image_count', 'audit_screen_count',
                  'retired', 'owner', 'body', 'audit_scene_radius', 'audit_scene_member', 'clear_audit_scene']


def fragment(source, signature):
    lines = source.splitlines()
    start = next(i for i, line in enumerate(lines) if line.startswith(signature))
    end = next((i for i in range(start+1, len(lines)) if lines[i].startswith('/')), len(lines))
    return '\n'.join(lines[start:end]).rstrip()


def project(source, signature, env, fields):
    """Translate one production proc into a Python method bound to `self`."""
    body = fragment(source, signature).splitlines()
    name = re.fullmatch(r'.*/(\w+)\((.*)\)', body[0])[1]
    args = [a.strip().split('/')[-1].split(' = ')[0] for a in re.fullmatch(r'.*/\w+\((.*)\)', body[0])[1].split(',') if a.strip()]
    out = ['def '+name+'(self'+''.join(', '+a for a in args)+'):']
    for raw in body[1:]:
        line = raw.strip()
        if not line or line.startswith('//'):
            continue
        indent = len(raw)-len(raw.lstrip('\t'))
        line = re.sub(r'^var/(?:[\w]+/)*(\w+)\s*=', r'\1 =', line)
        counted = re.fullmatch(r'for \(var/(\w+) = 1, \1 <= ([\w.]+)\.len, \1\+\+\)', line)
        if counted:
            line = 'for '+counted[1]+' in py_range(1, len('+counted[2]+')+1):'
        loop = re.fullmatch(r'for \(var/(?:[\w]+/)*(\w+) in (.+)\)', line)
        if loop:
            line = 'for '+loop[1]+' in dm_iter('+loop[2].replace('range(', 'scene_range(')+'):'
        line = line.replace('||', ' or ').replace('&&', ' and ')
        line = re.sub(r'!(?!=)', 'not ', line)
        for a, b in [('TRUE', 'True'), ('FALSE', 'False'), ('null', 'None')]:
            line = re.sub(r'\b'+a+r'\b', b, line)
        line = re.sub(r'\blist\(\)', 'keyed()', line)
        line = re.sub(r'([\w.]+)\.len\b', r'len(\1)', line)
        line = re.sub(r'istype\((\w+), (/[\w/]+)\)', r'istype(\1, "\2")', line)
        for field in fields:
            line = re.sub(r'(?<![.\w])'+field+r'\b', 'self.'+field, line)
        if line.startswith('if (') and line.endswith(')'):
            line = 'if '+line[4:-1]+':'
        ternary = re.fullmatch(r'(\w+) = (.+) \? (.+) : (.+)', line)
        if ternary:
            line = ternary[1]+' = '+ternary[3]+' if '+ternary[2]+' else '+ternary[4]
        if line.endswith('++'):
            line = line[:-2]+' += 1'
        out.append('    '*indent+line)
    code = '\n'.join(out)+'\n'
    exec(compile(code, str(CORE)+':'+name, 'exec'), env)
    return env[name]


class DMList(list):
    def __getitem__(self, index):
        return super().__getitem__(index-1)


class Keyed(dict):
    """Associative DM list: missing keys read as null."""
    def __getitem__(self, key):
        return self.get(key)


def environment(source=None):
    source = CORE.read_text() if source is None else source
    scene = []
    env = {'__builtins__': {}, 'len': len, 'max': max, 'py_range': range, 'keyed': Keyed,
           'dm_iter': lambda x: [] if x is None else list(x),
           'length': lambda x: 0 if x is None else len(x),
           'istype': lambda x, t: getattr(x, 'type', '').startswith(t),
           'scene_range': lambda radius, body: list(scene)}
    Snapshot = type('Snapshot', (N,), {})
    Snapshot.same_geometry = project(source, '/datum/los_snapshot/proc/same_geometry(', env, SNAPSHOT_FIELDS)
    Context = type('Context', (N,), {})
    for name in ['audit_scene_radius', 'audit_scene_member', 'clear_audit_scene', 'record_audit_scene', 'audit_scene_unchanged']:
        setattr(Context, name, project(source, '/datum/los_context/proc/'+name+'(', env, CONTEXT_FIELDS))
    return env, scene, Snapshot, Context


def cell(tile_x, tile_y, owner, owners=1, dx=0, dy=0):
    return N(tile_x=tile_x, tile_y=tile_y, cell_x=tile_x+dx, cell_y=tile_y+dy, surface_owner=owner, owners=owners)


def bounds(**values):
    base = dict(root_x=5, root_y=6, root_z=2, step_x=0, step_y=0, bound_x=0, bound_y=0, bound_width=32, bound_height=32)
    base.update(values)
    return N(**base)


class Atom(N):
    __eq__ = object.__eq__
    __hash__ = object.__hash__


def atom(kind='/obj/item'):
    return Atom(type=kind, appearance=object())


class Geometry(unittest.TestCase):
    def setUp(self):
        self.env, self.scene, self.Snapshot, self.Context = environment()
        self.wall = atom('/turf/wall')
        self.tree = atom('/obj/structure/wild/tree')

    def snapshot(self, **values):
        base = dict(presentation=True, eye_x=10, eye_y=12, eye_z=2, radius_x=7, radius_y=7,
                    blockers=DMList([cell(-2, 0, self.wall), cell(3, 1, self.tree, dx=.25)]),
                    tree_bounds=Keyed({self.tree: bounds()}))
        base.update(values)
        return self.Snapshot(**base)

    def test_fresh_capture_of_an_unchanged_scene_matches(self):
        a, b = self.snapshot(), self.snapshot()
        self.assertIsNot(a.blockers[1], b.blockers[1])
        self.assertTrue(a.same_geometry(b))
        self.assertTrue(b.same_geometry(a))
        self.assertTrue(self.snapshot(tree_bounds=None).same_geometry(self.snapshot(tree_bounds=None)))
        self.assertTrue(self.snapshot(tree_bounds=None).same_geometry(self.snapshot(tree_bounds=Keyed())))

    def test_each_geometric_input_is_load_bearing(self):
        a = self.snapshot()
        self.assertFalse(a.same_geometry(None))
        for change in [dict(presentation=False), dict(eye_x=11), dict(eye_y=11), dict(eye_z=1), dict(radius_x=8), dict(radius_y=6)]:
            self.assertFalse(a.same_geometry(self.snapshot(**change)), change)
        other = atom('/obj/structure/simple_door')
        for blockers in [DMList([cell(-2, 0, self.wall)]),
                         DMList([cell(-2, 0, self.wall), cell(3, 1, self.tree, dx=.25), cell(4, 4, other)]),
                         DMList([cell(-2, 1, self.wall), cell(3, 1, self.tree, dx=.25)]),
                         DMList([cell(-2, 0, self.wall), cell(3, 1, self.tree, dx=.5)]),
                         DMList([cell(-2, 0, other), cell(3, 1, self.tree, dx=.25)]),
                         DMList([cell(-2, 0, self.wall, owners=2), cell(3, 1, self.tree, dx=.25)]),
                         DMList([cell(3, 1, self.tree, dx=.25), cell(-2, 0, self.wall)])]:
            self.assertFalse(a.same_geometry(self.snapshot(blockers=blockers)))
        for tree_bounds in [None, Keyed(), Keyed({self.tree: bounds(step_x=2)}), Keyed({self.tree: bounds(bound_height=64)}),
                            Keyed({self.tree: bounds(root_x=6)}), Keyed({other: bounds()}),
                            Keyed({self.tree: bounds(), other: bounds()})]:
            self.assertFalse(a.same_geometry(self.snapshot(tree_bounds=tree_bounds)))

    def test_owner_and_bound_comparisons_are_not_redundant(self):
        source = CORE.read_text()
        owner_dropped = source.replace(' || A.surface_owner != B.surface_owner', '')
        bounds_dropped = source.replace(' || R.bound_height != O.bound_height', '')
        for mutant in [owner_dropped, bounds_dropped]:
            self.assertNotEqual(mutant, source)
        _, _, Snap, _ = environment(owner_dropped)
        other = atom('/obj/structure/simple_door')
        same = Snap(**vars(self.snapshot()))
        changed = Snap(**vars(self.snapshot(blockers=DMList([cell(-2, 0, other), cell(3, 1, self.tree, dx=.25)]))))
        self.assertTrue(same.same_geometry(changed))
        _, _, Snap, _ = environment(bounds_dropped)
        same = Snap(**vars(self.snapshot()))
        changed = Snap(**vars(self.snapshot(tree_bounds=Keyed({self.tree: bounds(bound_height=64)}))))
        self.assertTrue(same.same_geometry(changed))


class AuditSkip(unittest.TestCase):
    def setUp(self):
        self.env, self.scene, self.Snapshot, self.Context = environment()
        self.body = atom('/mob/living/human')
        self.wall = atom('/turf/wall')
        self.item = atom('/obj/item')
        self.mask = atom('/atom/movable/lighting_overlay')
        self.scene += [atom('/turf/floor'), self.wall, self.item, self.body, self.mask]
        self.owner = N(images=DMList(['mask-a', 'mask-b']), screen=DMList(['hud']))
        self.context = self.Context(owner=self.owner, body=self.body, retired=False, audit_snapshot=None,
                                    audit_appearances=None, audit_image_count=-1, audit_screen_count=-1)

    def snapshot(self, **values):
        base = dict(presentation=True, eye_x=10, eye_y=12, eye_z=2, radius_x=7, radius_y=7,
                    blockers=DMList([cell(-2, 0, self.wall)]), tree_bounds=None)
        base.update(values)
        return self.Snapshot(**base)

    def test_unchanged_scene_renews_without_refresh(self):
        self.assertFalse(self.context.audit_scene_unchanged(self.snapshot()))
        self.assertTrue(self.context.record_audit_scene(self.snapshot()))
        self.assertEqual(self.context.audit_scene_radius(self.snapshot()), 13)
        for _ in range(3):
            self.assertTrue(self.context.audit_scene_unchanged(self.snapshot()))
        self.assertEqual(len(self.context.audit_appearances), 4)

    def test_lighting_masks_are_not_audit_members(self):
        self.context.record_audit_scene(self.snapshot())
        self.mask.appearance = object()
        self.assertTrue(self.context.audit_scene_unchanged(self.snapshot()))
        self.scene.append(atom('/atom/movable/lighting_fullbright'))
        self.assertTrue(self.context.audit_scene_unchanged(self.snapshot()))

    def test_every_scene_difference_forces_a_refresh(self):
        record = self.snapshot()
        self.context.record_audit_scene(record)
        changed = [
            ('appearance', lambda: setattr(self.item, 'appearance', object())),
            ('body appearance', lambda: setattr(self.body, 'appearance', object())),
            ('new atom', lambda: self.scene.append(atom())),
            ('removed atom', lambda: self.scene.remove(self.item)),
            ('replaced atom', lambda: self.scene.__setitem__(2, atom())),
            ('client image', lambda: self.owner.images.append('mask-c')),
            ('client screen', lambda: self.owner.screen.append('plane')),
        ]
        for label, mutate in changed:
            self.setUp()
            self.context.record_audit_scene(self.snapshot())
            mutate()
            self.assertFalse(self.context.audit_scene_unchanged(self.snapshot()), label)
        self.setUp()
        self.context.record_audit_scene(self.snapshot())
        self.assertFalse(self.context.audit_scene_unchanged(self.snapshot(blockers=DMList([cell(-2, 0, self.wall), cell(1, 1, self.item)]))))
        self.assertFalse(self.context.audit_scene_unchanged(self.snapshot(presentation=False)))
        self.assertFalse(self.context.audit_scene_unchanged(None))
        self.context.retired = True
        self.assertFalse(self.context.audit_scene_unchanged(self.snapshot()))

    def test_clear_and_failed_record_deny_the_skip(self):
        self.context.record_audit_scene(self.snapshot())
        self.context.clear_audit_scene()
        self.assertIsNone(self.context.audit_snapshot)
        self.assertIsNone(self.context.audit_appearances)
        self.assertEqual(self.context.audit_image_count, -1)
        self.assertFalse(self.context.audit_scene_unchanged(self.snapshot()))
        # A read-authority (non-presentation) capture never records a scene.
        self.assertFalse(self.context.record_audit_scene(self.snapshot(presentation=False)))
        self.assertIsNone(self.context.audit_snapshot)
        self.assertTrue(self.context.record_audit_scene(self.snapshot()))
        self.context.body = None
        self.assertFalse(self.context.record_audit_scene(self.snapshot()))
        self.assertIsNone(self.context.audit_appearances)

    def test_appearance_comparison_is_not_redundant(self):
        source = CORE.read_text()
        mutant = source.replace('\t\tif (audit_appearances[A] != A.appearance)\n\t\t\treturn FALSE\n', '')
        self.assertNotEqual(mutant, source)
        env, scene, Snap, Ctx = environment(mutant)
        scene += list(self.scene)
        context = Ctx(**vars(self.context))
        context.record_audit_scene(Snap(**vars(self.snapshot())))
        self.item.appearance = object()
        self.assertTrue(context.audit_scene_unchanged(Snap(**vars(self.snapshot()))))


class LifecycleContracts(unittest.TestCase):
    def test_skip_is_bounded_by_publication_and_policy(self):
        reconcile = fragment(LIFECYCLE.read_text(), '/client/proc/reconcile_geometric_los(')
        early_return = reconcile.index('world.time < los_next_audit')
        audit_only = reconcile.index('var/audit_only = !los_dirty && key == los_last_policy')
        capture = reconcile.index('var/datum/los_snapshot/S = V.capture(TRUE)')
        skip = reconcile.index('if(audit_only && V.audit_scene_unchanged(S))')
        refresh = reconcile.index('root_tree_presenter.refresh(S)')
        published = reconcile.index('los_dirty = FALSE')
        record = reconcile.index('V.record_audit_scene(S)')
        renew = reconcile.index('los_next_audit = world.time + 10', record)
        self.assertLess(early_return, audit_only)
        self.assertLess(audit_only, capture)
        self.assertLess(capture, skip)
        self.assertLess(skip, refresh)
        self.assertLess(published, record)
        self.assertLess(record, renew)
        # The skip renews the audit and returns before any presenter publication.
        skipped = reconcile[skip:refresh]
        self.assertIn('los_next_audit = world.time + 10', skipped)
        self.assertIn('return TRUE', skipped)
        self.assertNotIn('refresh(', skipped)
        self.assertNotIn('images', skipped)

    def test_a_stepping_viewer_skips_recording_until_it_stops(self):
        # Recording scans range(view + 6) appearances. A viewer that stepped a
        # tile since its last publication refreshes again next step, so it
        # clears the scene instead; a stationary publication still records.
        reconcile = fragment(LIFECYCLE.read_text(), '/client/proc/reconcile_geometric_los(')
        # A half-tile eye step counts as a step too (los_terrain.dm).
        self.assertIn('var/stepped = V.movement_turf != los_published_turf || V.movement_bucket != los_published_bucket\n\tlos_published_turf = V.movement_turf\n\tlos_published_bucket = V.movement_bucket', reconcile)
        self.assertIn('if(stepped)\n\t\tV.clear_audit_scene()\n\telse\n\t\tV.record_audit_scene(S)', reconcile)
        self.assertLess(reconcile.index('V.movement_turf = get_turf(mob)'), reconcile.index('var/stepped'))

    def test_presenters_and_mutations_clear_the_recorded_scene(self):
        core = CORE.read_text()
        self.assertIn('clear_audit_scene()', fragment(core, '/datum/los_context/proc/retire('))
        self.assertIn('clear_audit_scene()', fragment(core, '/datum/los_context/proc/begin_change('))
        for path, kind in [(PRESENTER, '/datum/los_presenter'), (TREE, '/datum/root_tree_presenter')]:
            source = path.read_text()
            self.assertIn('context.clear_audit_scene()', fragment(source, kind+'/New('))
            self.assertIn('context.clear_audit_scene()', fragment(source, kind+'/proc/retire('))

    def test_recorded_scene_is_never_an_authority_lease(self):
        core = CORE.read_text()
        for signature in ['/datum/los_context/proc/decision(', '/datum/los_context/proc/decision_snapshot(',
                          '/datum/los_context/proc/capture(', '/proc/los_read_allowed(']:
            self.assertNotIn('audit_', fragment(core, signature))


if __name__ == '__main__':
    unittest.main()
