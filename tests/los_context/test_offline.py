"""Offline production-source projection; never compiles or executes DM.

Only five arithmetic helpers and three mutation methods use the constrained
projection below. Native view, client events, persistence and pixels are NOT
evaluated. Integer/half/quarter inputs stay exactly representable in float32
in the historical 21x21 arithmetic cases. The independent oracle uses rational convex hulls.
"""
from fractions import Fraction as Q
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / 'code/modules/visibility/los_context.dm'
ADDITIONS = {
    'civ13.dme': '#include "code\\modules\\visibility\\los_context.dm"\n',
    'code/_onclick/hud/hover_name.dm': '\tif (!los_read_allowed(parentmob, target, "hover"))\n\t\treturn FALSE\n',
    'code/game/mob/mob.dm': '\tif (!los_read_allowed(src, A, "examine"))\n\t\treturn\n',
    'code/game/mob/logout.dm': '\tif (CIV13_GEOMETRIC_LOS_CORE && client && client.los_context)\n\t\tclient.los_context.retire()\n',
    'code/modules/client/client_procs.dm': '\tif (CIV13_GEOMETRIC_LOS_CORE && los_context)\n\t\tlos_context.retire()\n',
}
TURN_OFF = '\tif (dir != get_dir(src,A))\n\t\tface_atom(A)'
TURN_GUARD = '\tif (!CIV13_GEOMETRIC_LOS_CORE && dir != get_dir(src,A))\n\t\tface_atom(A)'


def event_base():
    base, head = os.environ.get('LOS_EVENT_BASE', ''), os.environ.get('LOS_EVENT_HEAD', '')
    if not re.fullmatch('[0-9a-f]{40}', base) or not re.fullmatch('[0-9a-f]{40}', head):
        raise ValueError('LOS event base and head must be explicit full commit IDs; for workflow_dispatch supply comparison_base, or locally set LOS_EVENT_BASE and LOS_EVENT_HEAD')
    def git(*args):
        return subprocess.check_output(['git', *args], cwd=ROOT, stderr=subprocess.PIPE, timeout=15).decode('utf-8').strip()
    try:
        resolved_head = git('rev-parse', '--verify', head + '^{commit}')
        checked_out_head = git('rev-parse', 'HEAD')
    except subprocess.SubprocessError as exc:
        raise ValueError('LOS event head is missing or inaccessible in the local Git object database') from exc
    if resolved_head != head or checked_out_head != head:
        raise ValueError('LOS event head does not match checked-out HEAD')
    try:
        if git('rev-parse', '--verify', base + '^{commit}') != base:
            raise ValueError('LOS event base identity mismatch')
        return {path: subprocess.check_output(['git', 'show', base + ':' + path], cwd=ROOT,
                                               stderr=subprocess.PIPE, timeout=15).decode('utf-8').replace('\r\n', '\n')
                for path in ADDITIONS}
    except subprocess.SubprocessError as exc:
        raise ValueError('LOS event base is missing or inaccessible in the local Git object database') from exc


def verify_adapters(base, current):
    base_has_core = base['civ13.dme'].count(ADDITIONS['civ13.dme']) == 1
    locations = {
        'code/_onclick/hud/hover_name.dm': '/obj/screen/hover_name/proc/target_visible(',
        'code/game/mob/mob.dm': '/mob/verb/examinate(',
        'code/game/mob/logout.dm': '/mob/Logout(',
        'code/modules/client/client_procs.dm': '/client/Del(',
    }
    for path, addition in ADDITIONS.items():
        if current[path].count(addition) != 1:
            raise AssertionError('LOS hook missing, altered or duplicated: ' + path)
        if base[path].count(addition) != int(base_has_core):
            raise AssertionError('Inconsistent LOS hooks in event base: ' + path)
        if path in locations and addition not in adapter_fragment(current[path], locations[path]):
            raise AssertionError('LOS hook moved out of its production adapter: ' + path)
        if base_has_core and path in locations and addition not in adapter_fragment(base[path], locations[path]):
            raise AssertionError('LOS hook moved in event base: ' + path)
        if path in ('code/game/mob/logout.dm', 'code/modules/client/client_procs.dm'):
            # Both retirement guards must be the first executable statement.
            # Removing a relocated hook would otherwise hide the ordering change.
            expected_start = '\n' + addition.rstrip('\n')
            body = adapter_fragment(current[path], locations[path])
            if not body.startswith(body.split('\n', 1)[0] + expected_start):
                raise AssertionError('LOS retirement guard is not first in ' + path)
            if base_has_core:
                body = adapter_fragment(base[path], locations[path])
                if not body.startswith(body.split('\n', 1)[0] + expected_start):
                    raise AssertionError('LOS retirement guard moved in event base: ' + path)
    examine = adapter_fragment(current['code/game/mob/mob.dm'], locations['code/game/mob/mob.dm'])
    if examine.count(TURN_GUARD) != 1:
        raise AssertionError('Disabled Examine turn guard missing')
    if base_has_core:
        # The full-body projection only proves the introducing change is inert.
        # Once the core is in the base, later PRs may edit these procedures;
        # hook presence, placement and retirement ordering remain enforced.
        return True
    for path, signature in locations.items():
        def project(source, has_core):
            body = adapter_fragment(source, signature)
            if has_core:
                if body.count(ADDITIONS[path]) != 1:
                    raise AssertionError('Ambiguous LOS adapter in ' + path)
                body = body.replace(ADDITIONS[path], '', 1)
            if path == 'code/modules/client/client_procs.dm':
                # Independently default-off root composition cleanup is not a
                # change to the older LOS retirement/legacy adapter contract.
                body = body.replace('\tif(CIV13_ROOT_TREE_PRESENTATION && root_tree_presenter)\n\t\troot_tree_presenter.retire()', '')
                body = '\n'.join(line for line in body.splitlines() if line)
            if path == 'code/game/mob/mob.dm' and has_core:
                if body.count(TURN_GUARD) != 1:
                    raise AssertionError('Disabled Examine turn guard missing')
                body = body.replace(TURN_GUARD, TURN_OFF, 1)
            return body
        if project(base[path], base_has_core) != project(current[path], True):
            raise AssertionError('Disabled adapter body differs from event base: ' + path)
    return True


def adapter_fragment(source, signature):
    lines = source.splitlines()
    starts = [i for i, line in enumerate(lines) if line.startswith(signature)]
    if len(starts) != 1:
        raise AssertionError('Missing or duplicate adapter: ' + signature)
    start = starts[0]
    selected = [lines[start]]
    for line in lines[start + 1:]:
        if re.match(r'^/[A-Za-z_]', line) or line.startswith('var/'):
            break
        if not line.strip() or line.lstrip().startswith('//'):
            continue
        # Do not truncate at a declaration-like line hidden inside a block
        # comment or silently project preprocessor branches. Review is required.
        if '/*' in line or '*/' in line or line.lstrip().startswith('#'):
            raise AssertionError('Unsupported adapter comment/directive: ' + signature)
        selected.append(line)
    return '\n'.join(selected)


def core_disabled(source):
    definitions = re.findall(r'(?m)^\s*#\s*define\s+CIV13_GEOMETRIC_LOS_CORE\s+(\S+)', source)
    return definitions == ['0'] and not re.search(r'(?m)^\s*#\s*undef\s+CIV13_GEOMETRIC_LOS_CORE\b', source)


class DMList(list):
    def __getitem__(self, index):
        return super().__getitem__(index-1)


def dm_list(*values):
    return DMList(values)


def fragment(source, signature):
    lines = source.splitlines()
    start = next(i for i, line in enumerate(lines) if line.startswith(signature))
    end = next((i for i in range(start+1, len(lines))
                if lines[i].startswith('/')), len(lines))
    return '\n'.join(lines[start:end]).rstrip()


def expression(text, method=False):
    text = text.replace('||', ' or ').replace('&&', ' and ')
    text = re.sub(r'!(?!=)', 'not ', text)
    for a, b in [('TRUE','True'),('FALSE','False'),('null','None'),('src','self')]:
        text = re.sub(r'\b'+a+r'\b', b, text)
    text = re.sub(r'\blist\(', 'dm_list(', text)
    if method:
        for name in ['revision','retired','mutations','owner']:
            text = re.sub(r'(?<!\.)\b'+name+r'\b', 'self.'+name, text)
        for name in ['retire','advance_revision','clear_audit_scene']:
            text = re.sub(r'(?<!\.)\b'+name+r'\(', 'self.'+name+'(', text)
        text = text.replace('self.mutations.len', 'len(self.mutations)')
    return text


def project(source, signature, env, method=False):
    body = fragment(source, signature).splitlines()
    header = re.fullmatch(r'.*/(\w+)\((.*)\)', body[0])
    if not header:
        raise AssertionError(body[0])
    name, args = header.groups()
    args = [a.strip().split('/')[-1] for a in args.split(',') if a.strip()]
    if method:
        args.insert(0, 'self')
    output = ['def '+name+'('+', '.join(args)+'):']
    for raw in body[1:]:
        line = raw.strip()
        if not line or line.startswith('//'):
            continue
        indent = len(raw)-len(raw.lstrip('\t'))
        line = re.sub(r'^var/(?:[\w]+/)*(\w+)\s*=', r'\1 =', line)
        if line.endswith(' = new'):
            line = line[:-3]+'Mutation()'
        line = expression(line, method)
        if line.startswith('if (') and line.endswith(')'):
            line = 'if '+line[4:-1]+':'
        elif line.startswith('else if (') and line.endswith(')'):
            line = 'elif '+line[9:-1]+':'
        elif line == 'else':
            line = 'else:'
        if line == 'self.mutations += M':
            line = 'self.mutations.append(M)'
        if line == 'self.mutations -= M':
            line = 'self.mutations.remove(M)'
        if line.endswith('++'):
            line = line[:-2]+' += 1'
        output.append('    '*indent+line)
    code = '\n'.join(output)+'\n'
    exec(compile(code, str(CORE)+':'+name, 'exec'), env)
    return env[name]


def projected_geometry(source=None):
    source = CORE.read_text() if source is None else source
    env = {'__builtins__': {}, 'min': min, 'max': max, 'abs': abs, 'dm_list': dm_list}
    for name in ['los_axis_separates','los_triangle_hits_cell','los_hull_axis_separates','los_footprint_hits_cell',
                 'los_ray_axis','los_ray_entry']:
        project(source, '/proc/'+name+'(', env)
    # Hills (los_terrain.dm) are absent from these flat projections: half-tile
    # eye quantization as in DM, and no terrain answer, as on a flat map.
    import math
    env.update(los_eye_quantized=lambda step: math.floor(step / 16 + 0.5) * 16,
               los_eye_bucket=lambda body: f'{math.floor(body.step_x / 16 + 0.5) * 16},{math.floor(body.step_y / 16 + 0.5) * 16}',
               los_terrain_for=lambda body, radius: None,
               los_terrain_target_visible=lambda S, target: True)
    return env


def cross(o,a,b):
    return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])


def hull(points):
    points = sorted(set(points)); low=[]; high=[]
    for p in points:
        while len(low)>1 and cross(low[-2],low[-1],p)<=0:
            low.pop()
        low.append(p)
    for p in reversed(points):
        while len(high)>1 and cross(high[-2],high[-1],p)<=0:
            high.pop()
        high.append(p)
    return low[:-1]+high[:-1]


def square(x,y,half):
    return [(Q(x)-half,Q(y)-half),(Q(x)+half,Q(y)-half),
            (Q(x)+half,Q(y)+half),(Q(x)-half,Q(y)+half)]


def reference_footprint_hit(ex,ey,tx,ty,cx,cy):
    a=hull([(Q(ex),Q(ey))]+square(tx,ty,Q(1,4))); b=square(cx,cy,Q(1,2))
    for poly in [a,b]:
        for i,p in enumerate(poly):
            q=poly[(i+1)%len(poly)]; axis=(-(q[1]-p[1]),q[0]-p[0])
            aa=[x*axis[0]+y*axis[1] for x,y in a]; bb=[x*axis[0]+y*axis[1] for x,y in b]
            if max(aa)<min(bb) or max(bb)<min(aa):
                return False
    return True


def reference_entry(ex,ey,tx,ty,cx,cy):
    lo,hi=Q(0),Q(1)
    for e,t,c in [(ex,tx,cx),(ey,ty,cy)]:
        d=t-e
        if not d:
            if not Q(c)-Q(1,2)<=e<=Q(c)+Q(1,2):
                return None
            continue
        a,b=sorted(((Q(c)-Q(1,2)-e)/d,(Q(c)+Q(1,2)-e)/d))
        lo,hi=max(lo,a),min(hi,b)
        if lo>hi:
            return None
    return lo


class Mutation:
    def __init__(self):
        self.context=None; self.closed=False


class Context:
    def __init__(self):
        self.retired=False; self.revision=1; self.mutations=[]; self.owner=None; self.audit_clears=0

    def clear_audit_scene(self):
        self.audit_clears+=1

    def retire(self):
        self.retired=True
        for token in self.mutations:
            token.context=None;token.closed=True
        self.mutations.clear()


def projected_context(source=None):
    source = CORE.read_text() if source is None else source
    env={'__builtins__':{},'len':len,'Mutation':Mutation,'CIV13_ROOT_TREE_PRESENTATION':False}
    cls=type('ProjectedContext',(Context,),{})
    for name in ['advance_revision','begin_change','finish_change']:
        setattr(cls,name,project(source,'/datum/los_context/proc/'+name+'(',env,True))
    return cls


def boundary_failures(core, hover, mob):
    failures=[]
    for label,token in [('same_tile_identity','target_tile_x == blocker_tile_x && target_tile_y == blocker_tile_y'),('surface_occlusion','if (los_footprint_hits_cell(0, 0, tx, ty, 0, cx, cy))'),('target_blocker_dispatch','S.blocks_target(tx, ty, target_tile_x, target_tile_y, target.opacity)'),('exact_blocker_route','los_target_blocked(tx, ty, B.cell_x, B.cell_y, target_tile_x, target_tile_y, B.tile_x, B.tile_y, opaque_target)')]:
        expected = 3 if label == 'exact_blocker_route' else 1
        if core.count(token) != expected:
            failures.append(label)
    hover_body=fragment(hover,'/obj/screen/hover_name/proc/target_visible(')
    examine=fragment(mob,'/mob/verb/examinate(')
    for label,part,guard,sink in [('hover_guard',hover_body,'los_read_allowed(parentmob','target.invisibility'),('examine_guard',examine,'los_read_allowed(src','to_chat')]:
        if guard not in part or part.index(guard)>part.index(sink):
            failures.append(label)
    return failures


class Geometry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.env=projected_geometry()

    def test_footprint_against_independent_hull(self):
        f=self.env['los_footprint_hits_cell']; count=0
        for tx in range(2,15,2):
            for ty in range(2,15,2):
                for cx in range(3,14,2):
                    for cy in range(3,14,2):
                        self.assertEqual(f(8,11,tx,ty,.25,cx,cy),reference_footprint_hit(8,11,tx,ty,cx,cy))
                        count+=1
        self.assertEqual(count,1764)

    def test_rational_segment_entry(self):
        f=self.env['los_ray_entry']
        for tx in range(2,15,2):
            for ty in range(2,15,2):
                for cx in range(3,14,2):
                    for cy in range(3,14,2):
                        actual=f(8,11,tx,ty,cx,cy)
                        actual=None if actual is None else Q(actual[1],actual[2])
                        self.assertEqual(actual,reference_entry(8,11,tx,ty,cx,cy))

    def test_partial_footprint_and_corner(self):
        f=self.env['los_footprint_hits_cell']; ray=self.env['los_ray_entry']
        self.assertIsNone(ray(8,11,12,11.75,10,12))
        self.assertTrue(f(8,11,12,11.75,.25,10,12))
        self.assertIsNotNone(ray(8,11,10,13,9,11))
        self.assertIsNone(ray(8,11,12,11,10,12))

    def test_opening_closed_door_and_rear_wall(self):
        ray=self.env['los_ray_entry']
        wall=[(10,y) for y in range(8,15) if y!=11]
        self.assertTrue(all(ray(8,11,12,11,*p) is None for p in wall))
        self.assertIsNotNone(ray(8,11,12,11,10,11))
        a,b=ray(8,11,12,11,10,11),ray(8,11,12,11,12,11)
        self.assertLess(Q(a[1],a[2]),Q(b[1],b[2]))

    def test_contact_omission_control(self):
        changed=CORE.read_text().replace('max(p, q, r) < center - radius','max(p, q, r) <= center - radius').replace('center + radius < min(p, q, r)','center + radius <= min(p, q, r)')
        witness=(8,11,9,11,8,12,9,12)
        self.assertTrue(self.env['los_triangle_hits_cell'](*witness))
        self.assertFalse(projected_geometry(changed)['los_triangle_hits_cell'](*witness))


class Ownership(unittest.TestCase):
    def test_nested_and_foreign_mutations(self):
        cls=projected_context(); a,b=cls(),cls(); outer=a.begin_change();inner=a.begin_change()
        self.assertFalse(b.finish_change(inner));self.assertEqual(len(a.mutations),2)
        self.assertTrue(a.finish_change(outer));self.assertEqual(a.mutations,[inner])
        self.assertFalse(a.finish_change(outer));self.assertTrue(a.finish_change(inner))
        self.assertEqual(a.revision,5);self.assertEqual(a.mutations,[])

    def test_revision_and_depth_exhaustion(self):
        cls=projected_context(); a=cls();a.revision=1000000
        self.assertIsNone(a.begin_change());self.assertTrue(a.retired)
        a=cls()
        for _ in range(16):
            self.assertIsNotNone(a.begin_change())
        self.assertIsNone(a.begin_change());self.assertTrue(a.retired)

    def test_ticket_identity_omission_control(self):
        source=CORE.read_text().replace(' || M.context != src','')
        cls=projected_context(source);a,b=cls(),cls();token=a.begin_change();b.mutations.append(token)
        self.assertTrue(b.finish_change(token))


class SourceBoundaries(unittest.TestCase):
    def test_disabled_no_argument_reads(self):
        class Bomb:
            def __getattribute__(self,key):
                raise AssertionError('OFF path read '+key)
        env={'__builtins__':{},'CIV13_GEOMETRIC_LOS_CORE':0,'LOS_DENY':0}
        f=project(CORE.read_text(),'/proc/los_read_allowed(',env)
        self.assertTrue(f(Bomb(),Bomb(),Bomb()))

    def test_disabled_projection_against_event_base(self):
        base = event_base()
        current = {path: (ROOT/path).read_text(encoding='utf-8') for path in ADDITIONS}
        self.assertTrue(verify_adapters(base, current))
        # Projection controls need a base without the core, as in its introducing PR.
        pre_core = {path: source.replace(ADDITIONS[path], '', 1) for path, source in current.items()}
        pre_core['code/game/mob/mob.dm'] = pre_core['code/game/mob/mob.dm'].replace(TURN_GUARD, TURN_OFF, 1)
        self.assertTrue(verify_adapters(pre_core, current))
        later = dict(current)
        later['code/modules/client/client_procs.dm'] = later['code/modules/client/client_procs.dm'].replace(
            '\thuman_subtile_release_visuals()\n', '\thuman_subtile_release_visuals()\n\tlater_unrelated_cleanup()\n', 1)
        self.assertTrue(verify_adapters(current, later))  # Later PRs may edit adapter bodies.
        with self.assertRaisesRegex(AssertionError, 'differs from event base'):
            verify_adapters(pre_core, later)
        base = pre_core
        unrelated = dict(current)
        with tempfile.TemporaryDirectory() as temp:
            included = Path(temp) / 'code' / 'unrelated.dm'
            included.parent.mkdir()
            included.write_text('/proc/unrelated_valid_include()\n\treturn TRUE\n', encoding='utf-8')
            unrelated['civ13.dme'] += '#include "code\\unrelated.dm"\n'
            unrelated['code/game/mob/mob.dm'] += '\n/mob/proc/unrelated_valid_change()\n\treturn TRUE\n'
            self.assertTrue(included.is_file())
            self.assertTrue(verify_adapters(base, unrelated))
        broken = dict(unrelated)
        broken['code/game/mob/mob.dm'] = broken['code/game/mob/mob.dm'].replace(ADDITIONS['code/game/mob/mob.dm'], '')
        with self.assertRaises(AssertionError):
            verify_adapters(base, broken)
        broken = dict(unrelated)
        broken['code/game/mob/mob.dm'] = broken['code/game/mob/mob.dm'].replace(TURN_GUARD, '\tif (FALSE)\n\t\tface_atom(A)')
        with self.assertRaises(AssertionError):
            verify_adapters(base, broken)
        broken = dict(unrelated)
        broken['code/game/mob/logout.dm'] = broken['code/game/mob/logout.dm'].replace('/mob/Logout()\n', '/mob/Logout()\n\treturn\n', 1)
        with self.assertRaises(AssertionError):
            verify_adapters(base, broken)
        for path, first in [('code/game/mob/logout.dm', '\tclient?.clear_hover_name()\n'),
                            ('code/modules/client/client_procs.dm', '\thuman_subtile_release_visuals()\n')]:
            broken = dict(unrelated)
            broken[path] = broken[path].replace(ADDITIONS[path], '', 1).replace(first, first + ADDITIONS[path], 1)
            for ordering_base in (base, current):
                with self.assertRaisesRegex(AssertionError, 'retirement guard'):
                    verify_adapters(ordering_base, broken)
        broken = dict(unrelated)
        broken['code/game/mob/logout.dm'] = broken['code/game/mob/logout.dm'].replace('client?.clear_hover_name()', '// column-zero comment\n\treturn\n\tclient?.clear_hover_name()', 1)
        with self.assertRaises(AssertionError):
            verify_adapters(base, broken)
        broken = dict(unrelated)
        broken['code/game/mob/logout.dm'] = broken['code/game/mob/logout.dm'].replace('client?.clear_hover_name()', '/*\n/proc/fake()\n*/\n\treturn\n\tclient?.clear_hover_name()', 1)
        with self.assertRaises(AssertionError):
            verify_adapters(base, broken)
        broken = dict(unrelated)
        broken['code/game/mob/mob.dm'] = broken['code/game/mob/mob.dm'].replace('\t\tface_atom(A)', '\t\treturn', 1)
        with self.assertRaises(AssertionError):
            verify_adapters(base, broken)
        self.assertTrue(verify_adapters(current, unrelated))  # Post-merge base already has the core.
        for path, old, new in [('code/game/mob/mob.dm', ADDITIONS['code/game/mob/mob.dm'], ''),
                               ('code/modules/client/client_procs.dm', ADDITIONS['code/modules/client/client_procs.dm'], ''),
                               ('code/game/mob/mob.dm', TURN_GUARD, TURN_OFF)]:
            broken = dict(current)
            broken[path] = broken[path].replace(old, new, 1)
            with self.assertRaises(AssertionError):
                verify_adapters(current, broken)

    def test_event_base_provenance_refuses_missing_and_wrong_ids(self):
        valid_head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        with patch.dict(os.environ, {'LOS_EVENT_BASE': '', 'LOS_EVENT_HEAD': '0' * 40}):
            with self.assertRaisesRegex(ValueError, 'explicit full commit'):
                event_base()
        with patch.dict(os.environ, {'LOS_EVENT_BASE': '', 'LOS_EVENT_HEAD': valid_head}):
            with self.assertRaisesRegex(ValueError, 'supply comparison_base'):
                event_base()
        with patch.dict(os.environ, {'LOS_EVENT_BASE': '0' * 40, 'LOS_EVENT_HEAD': 'f' * 40}):
            with self.assertRaises(ValueError):
                event_base()
        with patch.dict(os.environ, {'LOS_EVENT_BASE': 'f' * 40, 'LOS_EVENT_HEAD': valid_head}):
            with self.assertRaisesRegex(ValueError, 'base is missing or inaccessible'):
                event_base()

    def test_default_enabled_with_explicit_opt_out(self):
        core = CORE.read_text()
        self.assertIn('#ifndef CIV13_GEOMETRIC_LOS_CORE\n#define CIV13_GEOMETRIC_LOS_CORE 1', core)
        disabled = core.replace('#define CIV13_GEOMETRIC_LOS_CORE 1', '#define CIV13_GEOMETRIC_LOS_CORE 0')
        self.assertTrue(core_disabled(disabled))
        self.assertFalse(core_disabled(core))
        self.assertFalse(core_disabled(disabled + '\n#define CIV13_GEOMETRIC_LOS_CORE 1\n'))
        directive = r'(?m)^\s*#\s*(?:define|undef)\s+CIV13_GEOMETRIC_LOS_CORE\b'
        self.assertNotRegex((ROOT/'civ13.dme').read_text(), directive)

    def test_guards_before_information(self):
        hover=(ROOT/'code/_onclick/hud/hover_name.dm').read_text()
        self.assertLess(hover.index('los_read_allowed(parentmob'),hover.index('target.invisibility'))
        examine=fragment((ROOT/'code/game/mob/mob.dm').read_text(),'/mob/verb/examinate(')
        self.assertLess(examine.index('los_read_allowed'),examine.index('face_atom'))
        self.assertLess(examine.index('los_read_allowed'),examine.index('to_chat'))
        # Agent observations use the same authority before any light or name read.
        visible=fragment((ROOT/'code/modules/gameplay_bridge/bridge.dm').read_text(),'/datum/gameplay_bridge/proc/visible(')
        self.assertLess(visible.index('los_read_allowed(actor, A, "observe")'),visible.index('get_lumcount'))
        decision=fragment(CORE.read_text(),'/datum/los_context/proc/decision(')
        self.assertIn('operation != "observe"',decision.split('\n',3)[1])

    def test_runtime_opacity_toggles_invalidate_los(self):
        # Central setter: only a real change dirties nearby viewers.
        setter=fragment((ROOT/'code/modules/lighting/lighting_atom.dm').read_text(),'/atom/proc/set_opacity(')
        self.assertIn('if (old_opacity != new_opacity)\n\t\tlos_invalidate(src, TRUE)',setter)
        # Raw writers that toggle at runtime refresh at once instead of waiting
        # for the one-second presentation audit.
        for path,proc,count in [('code/game/turfs/wall_attacks.dm','/turf/wall/proc/toggle_open(',2),
                                ('code/game/objects/controls.dm','/obj/structure/gate/elevator_door/proc/toggle(',2),
                                ('code/game/objects/controls.dm','/obj/structure/gatecontrol/blastcontrol/attack_hand(',2),
                                ('code/game/objects/controls.dm','/obj/structure/gatecontrol/blastcontrol/garage/attack_hand(',2),
                                ('code/game/objects/structures/key_doors/key_door.dm','/obj/structure/simple_door/key_door/attackby(',1)]:
            body=fragment((ROOT/path).read_text(),proc)
            writes=re.findall(r'(?m)^\t+(?:G\.)?opacity = (?:TRUE|FALSE)\n\t+los_invalidate\((?:src|G), TRUE\)',body)
            self.assertEqual(len(writes),count,proc)
        self.assertIn('los_next_audit = world.time + 10',(ROOT/'code/modules/visibility/los_lifecycle.dm').read_text())

    def test_operation_type_cap_and_persistence_boundaries(self):
        source=CORE.read_text(); decision=fragment(source,'/datum/los_context/proc/decision(')
        self.assertLess(decision.index('operation != "hover" && operation != "examine"'),decision.index('capture()'))
        for token in ['world.maxx != 21','world.maxz != 1','++visits > 1024','los_active_contexts.len >= 2']:
            self.assertNotIn(token,source)
        for token in ['los_target_blocked(', 'B.tile_x = cx - S.eye_x','dimensions[1] > 63','dimensions[2] > 63']:
            self.assertIn(token,source)
        for name in ['los_cell','los_snapshot','los_mutation','los_context']:
            self.assertIn('should_save = FALSE',fragment(source,'/datum/'+name))

    def test_unsupported_operation_reads_no_targets(self):
        source=CORE.read_text();body=fragment(source,'/datum/los_context/proc/decision(')
        prefix=body.split('\n\tif (retired',1)[0]
        env={'__builtins__':{},'LOS_DENY':0}
        f=project(prefix,'/datum/los_context/proc/decision(',env)
        class Bomb:
            def __getattribute__(self,key):
                raise AssertionError('Denied operation read '+key)
        for op in ['fire','drag','agent','unknown']:
            self.assertEqual(f(Bomb(),Bomb(),op),0)
        # A click is a supported read: the operation gate lets it reach the context checks.
        self.assertIsNone(f(Bomb(),Bomb(),'click'))

    def test_hidden_world_click_acts_on_the_tile(self):
        click=(ROOT/'code/_onclick/click.dm').read_text()
        self.assertIn('usr.ClickOn(los_click_target(usr, src), params)',click)
        self.assertIn('usr.DblClickOn(los_click_target(usr, src), params)',click)
        class Atom:
            def __init__(self,loc=None,movable=True):self.loc=loc;self.movable=movable
        turf=Atom(movable=False);thing=Atom(turf);worn=Atom(Atom())
        allowed={};checks=[]
        class World:time=10
        class User:next_click=0
        user=User()
        def read(u,a,op):
            checks.append(a);return (op=='click') and allowed.get(id(a),False)
        env={'__builtins__':{},'world':World,'ismovable':lambda a:a.movable,'isturf':lambda a:a is turf,
             'los_read_allowed':read}
        f=project(click,'/proc/los_click_target(',env)
        self.assertIs(f(user,thing),turf)            # hidden world object -> its tile
        allowed[id(thing)]=True
        self.assertIs(f(user,thing),thing)           # visible -> unchanged
        self.assertIs(f(user,turf),turf)             # turfs are never redirected
        self.assertIs(f(user,worn),worn)             # inventory/screen objects are untouched
        # Inside the click cooldown ClickOn refuses the click, so no sight check runs.
        checks.clear();user.next_click=World.time
        self.assertIs(f(user,thing),turf);self.assertEqual([],checks)
        user.next_click=0
        # Omission control: returning the object itself would hand the hidden target to ClickOn.
        leaky=click.replace('\t\treturn A\n\treturn A.loc\n','\t\treturn A\n\treturn A\n',1)
        self.assertNotEqual(leaky,click)
        g=project(leaky,'/proc/los_click_target(',env)
        allowed.clear()
        self.assertIs(g(user,thing),thing)

    def test_read_only_examine_and_retirement(self):
        body=fragment((ROOT/'code/game/mob/mob.dm').read_text(),'/mob/verb/examinate(')
        self.assertIn('if (!CIV13_GEOMETRIC_LOS_CORE && dir != get_dir(src,A))',body)
        core=CORE.read_text()
        self.assertIn('persistence_active_operation',fragment(core,'/datum/los_context/proc/policy_key('))
        for path,sig in [('code/game/mob/logout.dm','/mob/Logout('),('code/modules/client/client_procs.dm','/client/Del(')]:
            self.assertIn('los_context.retire()',fragment((ROOT/path).read_text(),sig))

    def test_surface_and_adapter_omission_controls(self):
        core=CORE.read_text();hover=(ROOT/'code/_onclick/hud/hover_name.dm').read_text();mob=(ROOT/'code/game/mob/mob.dm').read_text()
        self.assertEqual(boundary_failures(core,hover,mob),[])
        for label,token in [('same_tile_identity','target_tile_x == blocker_tile_x && target_tile_y == blocker_tile_y'),('surface_occlusion','if (los_footprint_hits_cell(0, 0, tx, ty, 0, cx, cy))'),('target_blocker_dispatch','S.blocks_target(tx, ty, target_tile_x, target_tile_y, target.opacity)'),('exact_blocker_route','los_target_blocked(tx, ty, B.cell_x, B.cell_y, target_tile_x, target_tile_y, B.tile_x, B.tile_y, opaque_target)')]:
            self.assertEqual(boundary_failures(core.replace(token,'OMITTED',1),hover,mob),[label])
        self.assertEqual(boundary_failures(core,hover.replace('los_read_allowed(parentmob','OMITTED',1),mob),['hover_guard'])
        self.assertEqual(boundary_failures(core,hover,mob.replace('los_read_allowed(src','OMITTED',1)),['examine_guard'])


if __name__=='__main__':
    unittest.main()
