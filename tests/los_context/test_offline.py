"""Offline production-source projection; never compiles or executes DM.

Only five arithmetic helpers and three mutation methods use the constrained
projection below. Native view, client events, persistence and pixels are NOT
evaluated. Integer/half/quarter inputs stay exactly representable in float32
on the admitted 21x21 slice. The independent oracle uses rational convex hulls.
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
        raise ValueError('LOS event base and head must be explicit full commit IDs; workflow_dispatch has no event base: run as a PR/push with a known base, or run locally with LOS_EVENT_BASE and LOS_EVENT_HEAD set to full commit IDs')
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
    for path, signature in locations.items():
        def project(source, has_core):
            body = adapter_fragment(source, signature)
            if has_core:
                if body.count(ADDITIONS[path]) != 1:
                    raise AssertionError('Ambiguous LOS adapter in ' + path)
                body = body.replace(ADDITIONS[path], '', 1)
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
        for name in ['revision','retired','mutations']:
            text = re.sub(r'(?<!\.)\b'+name+r'\b', 'self.'+name, text)
        for name in ['retire','advance_revision']:
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
    for name in ['los_axis_separates','los_triangle_hits_cell','los_footprint_hits_cell',
                 'los_ray_axis','los_ray_entry']:
        project(source, '/proc/'+name+'(', env)
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
        self.retired=False; self.revision=1; self.mutations=[]

    def retire(self):
        self.retired=True
        for token in self.mutations:
            token.context=None;token.closed=True
        self.mutations.clear()


def projected_context(source=None):
    source = CORE.read_text() if source is None else source
    env={'__builtins__':{},'len':len,'Mutation':Mutation}
    cls=type('ProjectedContext',(Context,),{})
    for name in ['advance_revision','begin_change','finish_change']:
        setattr(cls,name,project(source,'/datum/los_context/proc/'+name+'(',env,True))
    return cls


def boundary_failures(core, hover, mob):
    failures=[]
    for label,token in [('unique_surface','first.owners != 1'),('surface_identity','first.surface_owner != target'),('surface_tie','tied ||')]:
        if token not in core:
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

    def test_event_base_provenance_refuses_missing_and_wrong_ids(self):
        valid_head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        with patch.dict(os.environ, {'LOS_EVENT_BASE': '', 'LOS_EVENT_HEAD': '0' * 40}):
            with self.assertRaisesRegex(ValueError, 'explicit full commit'):
                event_base()
        with patch.dict(os.environ, {'LOS_EVENT_BASE': '', 'LOS_EVENT_HEAD': valid_head}):
            with self.assertRaisesRegex(ValueError, 'workflow_dispatch has no event base'):
                event_base()
        with patch.dict(os.environ, {'LOS_EVENT_BASE': '0' * 40, 'LOS_EVENT_HEAD': 'f' * 40}):
            with self.assertRaises(ValueError):
                event_base()
        with patch.dict(os.environ, {'LOS_EVENT_BASE': 'f' * 40, 'LOS_EVENT_HEAD': valid_head}):
            with self.assertRaisesRegex(ValueError, 'base is missing or inaccessible'):
                event_base()

    def test_default_off_and_no_activation_callers(self):
        core = CORE.read_text()
        self.assertTrue(core_disabled(core))
        self.assertFalse(core_disabled(core.replace('#define CIV13_GEOMETRIC_LOS_CORE 0', '#define CIV13_GEOMETRIC_LOS_CORE 1')))
        self.assertFalse(core_disabled(core + '\n#define CIV13_GEOMETRIC_LOS_CORE 1\n'))
        directive = r'(?m)^\s*#\s*(?:define|undef)\s+CIV13_GEOMETRIC_LOS_CORE\b'
        self.assertNotRegex((ROOT/'civ13.dme').read_text(), directive)
        for path in (ROOT/'code').rglob('*.dm'):
            if path!=CORE:
                content = path.read_text(errors='replace')
                self.assertNotRegex(content, r'new\s*/datum/los_context')
                self.assertNotRegex(content, directive)

    def test_guards_before_information(self):
        hover=(ROOT/'code/_onclick/hud/hover_name.dm').read_text()
        self.assertLess(hover.index('los_read_allowed(parentmob'),hover.index('target.invisibility'))
        examine=fragment((ROOT/'code/game/mob/mob.dm').read_text(),'/mob/verb/examinate(')
        self.assertLess(examine.index('los_read_allowed'),examine.index('face_atom'))
        self.assertLess(examine.index('los_read_allowed'),examine.index('to_chat'))

    def test_operation_type_cap_and_persistence_boundaries(self):
        source=CORE.read_text(); decision=fragment(source,'/datum/los_context/proc/decision(')
        self.assertLess(decision.index('operation != "hover" && operation != "examine"'),decision.index('capture()'))
        self.assertNotIn('istype(',fragment(source,'/datum/los_context/proc/capture('))
        for token in ['world.maxx != 21','world.maxz != 1','++visits > 1024','los_active_contexts.len >= 2','first.owners != 1','first.surface_owner != target']:
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
        for op in ['click','fire','drag','agent','unknown']:
            self.assertEqual(f(Bomb(),Bomb(),op),0)

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
        for label,token in [('unique_surface','first.owners != 1'),('surface_identity','first.surface_owner != target'),('surface_tie','tied ||')]:
            self.assertEqual(boundary_failures(core.replace(token,'OMITTED',1),hover,mob),[label])
        self.assertEqual(boundary_failures(core,hover.replace('los_read_allowed(parentmob','OMITTED',1),mob),['hover_guard'])
        self.assertEqual(boundary_failures(core,hover,mob.replace('los_read_allowed(src','OMITTED',1)),['examine_guard'])


if __name__=='__main__':
    unittest.main()
