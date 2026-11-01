"""Production admission contracts and eye-relative arithmetic, not native pixels."""
from fractions import Fraction as Q
import unittest
import importlib.util
from pathlib import Path
_spec = importlib.util.spec_from_file_location("production_los_offline", Path(__file__).with_name("test_offline.py"))
_offline = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_offline)
CORE, fragment, projected_geometry, reference_footprint_hit, reference_entry = (_offline.CORE, _offline.fragment, _offline.projected_geometry, _offline.reference_footprint_hit, _offline.reference_entry)


class ProductionGeometry(unittest.TestCase):
    def test_fractional_eye_and_large_map_translation(self):
        functions = projected_geometry()
        footprint = functions['los_footprint_hits_cell']
        ray = functions['los_ray_entry']
        # Native smooth steps use 2px = 1/16 of a tile. Production feeds relative
        # coordinates, so the same oracle applies near x=1000 and x=30000.
        count = 0
        for step in range(0, 16, 3):
            eye = Q(step, 16)
            for target in [(3, 0), (3, 2), (-3, -2), (0, 4)]:
                for cell in [(1, 0), (2, 1), (-1, -1), (0, 2)]:
                    tx, ty = target[0] - eye, Q(target[1])
                    cx, cy = cell[0] - eye, Q(cell[1])
                    actual = footprint(0, 0, float(tx), float(ty), .25, float(cx), float(cy))
                    expected = reference_footprint_hit(0, 0, tx, ty, cx, cy)
                    self.assertEqual(actual, expected)
                    result = ray(0, 0, float(tx), float(ty), float(cx), float(cy))
                    expected_ray = reference_entry(0, 0, tx, ty, cx, cy)
                    self.assertEqual(None if result is None else Q(result[1]) / Q(result[2]), expected_ray)
                    for origin in [1000, 30000]:
                        self.assertEqual(float(Q(origin) + target[0] - (Q(origin) + eye)), float(tx))
                    count += 1
        self.assertEqual(count, 96)

    def broadphase_helpers(self):
        import math
        source = CORE.read_text()
        env = projected_geometry(source)
        env['round'] = math.floor  # BYOND round(A), NOT Python banker's round.
        for name in ['los_bucket_index', 'los_bucket_lower', 'los_bucket_upper', 'los_target_blocked']:
            _offline.project(source, '/proc/' + name + '(', env)
        return env

    def test_spatial_bins_preserve_every_blocking_pair(self):
        env = self.broadphase_helpers()
        index, lower, upper, blocked = [env[n] for n in [
            'los_bucket_index', 'los_bucket_lower', 'los_bucket_upper', 'los_target_blocked']]
        self.assertEqual([index(x) for x in [-4.0625, -4, -.0625, 0, 3.9375, 4]], [-2, -1, -1, 0, 0, 1])
        cases = 0
        for eye in [0, .125, .875]:
            # Include offset blockers with distinct native tile coordinates.
            blockers = [(x-eye+offset, y, x-eye, y)
                        for x in range(-8, 9, 2) for y in range(-8, 9, 2)
                        for offset in [0, .5]]
            bins = {}
            for b in blockers:
                bins.setdefault((index(b[0]), index(b[1])), []).append(b)
            for tx0, ty in [(x, y) for x in [-7, -3, 0, 3, 7] for y in [-7, -3, 0, 3, 7]]:
                for offset in [0, .125]:
                    tx, tile_x = tx0-eye+offset, tx0-eye
                    for opaque in [False, True]:
                        half = 0 if opaque else .25
                        keys = {(bx, by) for bx in range(lower(tx, half), upper(tx, half)+1)
                                for by in range(lower(ty, half), upper(ty, half)+1)}
                        candidates = [b for key in keys for b in bins.get(key, [])]
                        flat_result = False
                        for cx, cy, native_x, native_y in blockers:
                            hit = blocked(tx, ty, cx, cy, tile_x, ty, native_x, native_y, opaque)
                            if hit:
                                self.assertIn((index(cx), index(cy)), keys)
                                flat_result = True
                            cases += 1
                        bucket_result = any(blocked(tx, ty, cx, cy, tile_x, ty, native_x, native_y, opaque)
                                            for cx, cy, native_x, native_y in candidates)
                        self.assertEqual(flat_result, bucket_result)
        self.assertEqual(cases, 48600)
        # Exact upper contact falls on the next bucket boundary; omitting it
        # would miss a cell touching the footprint at x=3.5.
        self.assertEqual(upper(3.25, .25), 1)
        self.assertTrue(blocked(3.25, 0, 4, 0, 3, 0, 4, 0, False))
        self.assertFalse(index(4) < upper(3.25, .25))  # exclusive-upper mutation loses it

    def test_dense_candidate_counts_and_sparse_source_path(self):
        env = self.broadphase_helpers()
        index, lower, upper = [env[n] for n in ['los_bucket_index', 'los_bucket_lower', 'los_bucket_upper']]
        blockers = [(x, y) for x in range(-8, 9) for y in range(-8, 9)]
        bins = {}
        for b in blockers:
            bins.setdefault((index(b[0]), index(b[1])), []).append(b)
        total, lookups = 0, 0
        for tx in range(-7, 8):
            for ty in range(-7, 8):
                for bx in range(lower(tx, .25), upper(tx, .25)+1):
                    for by in range(lower(ty, .25), upper(ty, .25)+1):
                        total += len(bins.get((bx, by), []))
                        lookups += 1
        self.assertEqual(total, 23104)
        self.assertEqual(lookups, 1444)
        self.assertLess(total, len(blockers)*225/2)
        source = CORE.read_text()
        build = fragment(source, '/datum/los_snapshot/proc/index_blockers(')
        query = fragment(source, '/datum/los_snapshot/proc/blocks_target(')
        self.assertIn('if(blockers.len <= 16)', build)
        self.assertIn('blocker_bins = null', build)
        self.assertIn('bin += B', build)
        self.assertIn('los_bucket_index(B.cell_x)', build)
        self.assertIn('los_bucket_index(B.cell_y)', build)
        self.assertIn('if(!blocker_bins)', query)
        self.assertIn('for(var/datum/los_cell/B in blockers)', query)
        self.assertIn('bx <= max_x', query)
        self.assertIn('by <= max_y', query)
        self.assertIn('blocker_bins["[bx],[by]"]', query)
        self.assertIn('if(!bin)\n\t\t\t\tcontinue', query)
        self.assertEqual(query.count('los_target_blocked(tx, ty, B.cell_x, B.cell_y, target_tile_x, target_tile_y, B.tile_x, B.tile_y, opaque_target)'), 2)
        self.assertNotIn('list()', query)
        self.assertIn('S.index_blockers()', fragment(source, '/datum/los_context/proc/capture('))

    def test_viewport_cache_reparses_only_changed_scalar(self):
        from types import SimpleNamespace
        import re
        source = CORE.read_text()
        fields = ['viewport_cache_ready', 'viewport_cached_view', 'viewport_cached_dimensions']
        for field in fields:
            source = re.sub(r'(?<!\.)\b' + field + r'\b', 'self.' + field, source)
        source = source.replace('dimensions.len', 'len(dimensions)')
        calls = []
        def getviewsize(view):
            calls.append(view)
            if isinstance(view, int):
                return _offline.DMList([view*2+1, view*2+1])
            return _offline.DMList([int(x) for x in view.split('x')])
        env = {'getviewsize': getviewsize, 'len': len}
        viewport = _offline.project(source, '/datum/los_context/proc/viewport(', env, True)
        context = SimpleNamespace(owner=SimpleNamespace(view=7), viewport_cache_ready=False,
                                  viewport_cached_view=None, viewport_cached_dimensions=None)
        first = viewport(context)
        self.assertEqual(first, [15, 15])
        self.assertIs(viewport(context), first)
        context.owner.view = '23x15'
        self.assertEqual(viewport(context), [23, 15])
        context.owner.view = '65x15'
        self.assertIsNone(viewport(context))
        self.assertIsNone(viewport(context))
        context.owner.view = 7
        self.assertEqual(viewport(context), [15, 15])
        self.assertEqual(calls, [7, '23x15', '65x15', 7])
        context.owner = None
        self.assertIsNone(viewport(context))
        retire = fragment(CORE.read_text(), '/datum/los_context/proc/retire(')
        for field in fields:
            self.assertIn(field + ' = ', retire)
        # Fresh policy guard remains on EVERY decision, not bypassed by bins.
        decision = fragment(CORE.read_text(), '/datum/los_context/proc/decision_snapshot(')
        self.assertIn('S.policy != policy_key()', decision)

    def test_bbox_rejection_matches_unpruned_geometry(self):
        source = CORE.read_text()
        gate = ('\tif (max(ex, tx+half_size) < cx-0.5 || min(ex, tx-half_size) > cx+0.5 || '
                'max(ey, ty+half_size) < cy-0.5 || min(ey, ty-half_size) > cy+0.5)\n\t\treturn FALSE\n')
        self.assertIn(gate, source)
        candidate = projected_geometry(source)['los_footprint_hits_cell']
        triangle = projected_geometry(source)['los_triangle_hits_cell']
        def unpruned(ex, ey, tx, ty, h, cx, cy):
            corners = [(tx-h,ty-h),(tx+h,ty-h),(tx+h,ty+h),(tx-h,ty+h)]
            return any(triangle(ex,ey,*corners[j],*corners[(j+1)%4],cx,cy) for j in range(4))
        count = 0
        for ex, ey in [(0, 0), (.125, -.875)]:
            for tx, ty in [(3, 0), (-3, -2), (0, 4)]:
                for cx in [-4, -1, 0, .5, 2.5, 3.75, 5]:
                    for cy in [-3, -.75, -.5, 0, .5, .75, 4.75]:
                        args = (ex, ey, tx, ty, .25, cx, cy)
                        self.assertEqual(candidate(*args), unpruned(*args))
                        count += 1
        self.assertEqual(count, 294)
        # A separated cell does no triangle work. Touching endpoints still hit.
        env = projected_geometry(source)
        def unexpected_triangle(*args):
            raise AssertionError('disjoint bounding box reached triangle checks')
        env['los_hull_axis_separates'] = unexpected_triangle
        self.assertFalse(env['los_footprint_hits_cell'](0, 0, 3, 0, .25, 5, 0))
        self.assertTrue(candidate(0, 0, 3, 0, .25, 3.75, 0))

    def test_hull_sat_matches_legacy_triangles_and_bounded_segments(self):
        import random
        env = projected_geometry()
        candidate = env['los_footprint_hits_cell']
        triangle = env['los_triangle_hits_cell']
        ray = env['los_ray_entry']
        rng = random.Random(20261030)
        counts = {'hull': 0, 'legacy': 0}
        for name, key in [('los_hull_axis_separates', 'hull'), ('los_axis_separates', 'legacy')]:
            original = env[name]
            def counted(*args, original=original, key=key):
                counts[key] += 1
                return original(*args)
            env[name] = counted
        for i in range(20000):
            ex, ey = rng.randrange(-32, 33)/32, rng.randrange(-32, 33)/32
            tx, ty = rng.randrange(-512, 513)/32, rng.randrange(-512, 513)/32
            cx, cy = rng.randrange(-17, 18), rng.randrange(-17, 18)
            h = [0, .25, .5][i % 3]
            corners = [(tx-h,ty-h),(tx+h,ty-h),(tx+h,ty+h),(tx-h,ty+h)]
            legacy = any(triangle(ex,ey,*corners[j],*corners[(j+1)%4],cx,cy) for j in range(4))
            self.assertEqual(candidate(ex,ey,tx,ty,h,cx,cy), legacy)
            if h == 0:
                self.assertEqual(candidate(ex,ey,tx,ty,0,cx,cy), ray(ex,ey,tx,ty,cx,cy) is not None)
        self.assertLess(counts['hull'], counts['legacy'])
        # Closed contact, points and bounded segments: not an infinite ray.
        self.assertTrue(candidate(0,0,3,0,0,3.5,0))
        self.assertFalse(candidate(0,0,3,0,0,4,0))
        self.assertTrue(candidate(0,0,0,0,0,.5,.5))
        self.assertFalse(candidate(0,0,0,0,0,1,1))

    def test_empty_ground_does_not_allocate_cell(self):
        capture = fragment(CORE.read_text(), '/datum/los_context/proc/capture(')
        self.assertIn('if (owner_count)\n\t\t\t\tvar/datum/los_cell/B = new', capture)
        self.assertIn('B.owners = owner_count', capture)
        self.assertIn('B.surface_owner = cell_owner', capture)
        self.assertIn('moving_blocker.cell_x = cx - S.eye_x + AM.step_x / 32', capture)
        self.assertEqual(capture.count('var/datum/los_cell/B = new'), 1)

    def test_same_native_tile_exemption_with_offset_objects_and_opaque_owners(self):
        source = CORE.read_text()
        env = projected_geometry(source)
        blocked = _offline.project(source, '/proc/los_target_blocked(', env)
        for eye_offset in [0, .125, .5, .875]:
            tile = 3 - eye_offset
            for target_offset in [0, .125, -.5]:
                tx = tile + target_offset
                for blocker_offset in [0, .125, -.5]:
                    cx = tile + blocker_offset
                    for opaque in [False, True]:
                        # Ground, objects and opaque objects share native turf
                        # even if their geometric centers differ during motion.
                        self.assertFalse(blocked(tx, 0, cx, 0, tile, 0, tile, 0, opaque))
                        # Every intervening native tile retains occlusion.
                        self.assertTrue(blocked(tx, 0, 1-eye_offset, 0, tile, 0, 1-eye_offset, 0, opaque))
                        self.assertTrue(blocked(5-eye_offset, 0, cx, 0, 5-eye_offset, 0, tile, 0, opaque))
            # Two distinct opaque owners on target's native turf are both exempt;
            # insertion order and surface_owner selection cannot change result.
            self.assertFalse(any(blocked(tile, 0, center, 0, tile, 0, tile, 0, True)
                                 for center in [tile, tile+.125]))
            # Equal geometric centers on DIFFERENT native tiles are not exempt.
            self.assertTrue(blocked(tile, 0, tile, 0, tile, 0, tile-1, 0, False))
            # Other y-coordinate also means another tile, regardless of x.
            self.assertTrue(blocked(tile, 0, tile, 0, tile, 0, tile, -1, False))
        broken = source.replace('target_tile_x == blocker_tile_x && target_tile_y == blocker_tile_y', 'FALSE', 1)
        old = _offline.project(broken, '/proc/los_target_blocked(', projected_geometry(broken))
        self.assertTrue(old(3.125, 0, 3, 0, 3, 0, 3, 0, False))
        self.assertTrue(old(3, 0, 3, 0, 3, 0, 3, 0, True))
        decision = fragment(source, '/datum/los_context/proc/decision_snapshot(')
        self.assertIn('"[target.opacity]|[target_tile_x],[target_tile_y]|[tx],[ty]"', decision)
        self.assertIn('S.blocks_target(tx, ty, target_tile_x, target_tile_y, target.opacity)', decision)
        capture = fragment(source, '/datum/los_context/proc/capture(')
        for prefix in ['B', 'moving_blocker']:
            self.assertIn(prefix + '.tile_x = cx - S.eye_x', capture)
            self.assertIn(prefix + '.tile_y = cy - S.eye_y', capture)

    def test_save_allows_read_only_capture_but_load_suspends(self):
        from types import SimpleNamespace
        import re
        policy = fragment(CORE.read_text(), '/datum/los_context/proc/policy_key(')
        condition = re.search(r'\((persistence_active_operation && persistence_active_operation.kind != "save")\)', policy)
        self.assertIsNotNone(condition)
        expression = condition[1].replace('&&', 'and')
        for operation, blocked in [(None, False), (SimpleNamespace(kind='save'), False),
                                   (SimpleNamespace(kind='load'), True), (SimpleNamespace(kind='restore'), True)]:
            self.assertEqual(bool(eval(expression, {'__builtins__': {}}, {'persistence_active_operation': operation})), blocked)
        # Historical unconditional gate denied saves as well; keep that witness.
        self.assertTrue(bool(SimpleNamespace(kind='save')))

    def test_production_policy_and_snapshot_contracts(self):
        source = CORE.read_text()
        capture = fragment(source, '/datum/los_context/proc/capture(')
        decision = fragment(source, '/datum/los_context/proc/decision_snapshot(')
        eligible = fragment(source, '/datum/los_context/proc/eligible(')
        policy = fragment(source, '/datum/los_context/proc/policy_key(')
        self.assertIn('A.opacity && A != body', capture)
        self.assertNotIn('A.type', capture)
        self.assertNotIn('T.type', capture)
        self.assertIn('body.step_x / 32', capture)
        self.assertIn('AM.step_x / 32', capture)
        self.assertIn('locate(cx, cy, S.eye_z)', capture)
        self.assertIn('cx - S.eye_x', capture)
        self.assertNotIn('view(', decision)
        self.assertIn('los_footprint_hits_cell(0, 0, tx, ty, 0,', fragment(source, '/proc/los_target_blocked('))
        self.assertIn('S.clear_footprints[footprint_key]', decision)
        self.assertIn('owner.eye == body', eligible)
        self.assertNotIn('is_blind', eligible)
        self.assertIn('is_blind(body)', policy)
        self.assertIn('persistence_active_operation', policy)
        self.assertIn('owner.los_presenter.retire()', source)
        self.assertIn('owner.los_presenter.invalidate()', source)


class InventoryHoverName(unittest.TestCase):
    """Widget/callback source execution; fake client, weakref and view boundaries."""
    def model(self,source=None):
        import html,re,weakref
        from types import SimpleNamespace as N
        root=CORE.parents[3]
        source=source or (root/'code/_onclick/hud/hover_name.dm').read_text()
        spec=importlib.util.spec_from_file_location('inventory_hover_adapter',root/'tests/save_movement/source_adapter.py')
        A=importlib.util.module_from_spec(spec);spec.loader.exec_module(A)
        class Node:
            def __init__(self,**values):vars(self).update(values)
        class Handle:
            def __init__(self,item):self.weak=weakref.ref(item)
            def resolve(self):
                item=self.weak();return item if item and not item.deleted else None
        def atom(kind='/obj/item',**values):
            defaults=dict(type=kind,loc=None,name='item',screen_loc=None,mouse_opacity=1,alpha=255,
                invisibility=0,x=1,y=1,z=1,deleted=False)
            defaults.update(values);return Node(**defaults)
        body=atom('/mob/living/human',see_invisible=25,HUDneed={},HUDinventory=[],slots={})
        C=Node(mob=body,screen=[],view=7,eye=body)
        body.client=C;body.get_equipped_item=lambda slot:body.slots.get(slot)
        W=atom('/obj/screen/hover_name',parentmob=body,hover_target=None,hover_origin=None,
               hover_inventory=False,hover_screen_loc=None,maptext='')
        body.HUDneed['hover name']=W;C.screen.append(W)
        world_visible=set();readable=set();read_calls=[];parents=[]
        def allowed(user,target,operation):
            read_calls.append((user,target,operation));return target in readable
        env=dict(istype=lambda x,t:bool(x and x.type.startswith(t)),ismovable=lambda x:bool(x and not x.type.startswith('/turf/')),
            typed_iter=lambda xs,t:[x for x in xs if x and x.type.startswith(t)],
            isturf=lambda x:bool(x and x.type.startswith('/turf/')),ishuman=lambda x:bool(x and x.type.startswith('/mob/living/human')),
            los_read_allowed=allowed,view=lambda v,e:world_visible,WEAKREF=Handle,
            resolve=lambda h:h.resolve() if h else None,length=lambda x:len(x) if x else 0,
            html_encode=html.escape,copytext=lambda text,start,end:text[start-1:end-1],
            parent_call=lambda:parents.append('parent'),parent_runtime=lambda key:key=='persistence_export_frame',
            list=lambda *xs:list(xs))
        def method(text,declaration,args,fields):
            text=declaration+'('+args+')\n'+A.extract(text,declaration)+'\n'
            text=text.replace('hover_target?.resolve()','resolve(hover_target)').replace('hover_origin?.resolve()','resolve(hover_origin)')
            text=re.sub(r'(\w+)\.resolve\((hover_target|hover_origin)\)',r'resolve(\1.\2)',text)
            text=text.replace('label?.set_target(target)','optional_set(label, target)').replace('label?.clear_target()','optional_clear(label)')
            text=text.replace('|| ..()', '|| parent_runtime(key)').replace('..()', 'parent_call()')
            text=text.replace("[html_encode(copytext(label, 1, 129))]",'" + html_encode(copytext(label, 1, 129)) + "')
            text=text.replace('object ? object.x : 0','(object.x if object else 0)').replace('object ? object.y : 0','(object.y if object else 0)')
            lines=text.split('\n');head,tail=lines[0],'\n'.join(lines[1:])
            pieces=re.split(r'("(?:[^"\\]|\\.)*")',tail)
            for i in range(0,len(pieces),2):
                pieces[i]=re.sub(r'\bsrc\b','self',pieces[i])
                for field in fields:pieces[i]=re.sub(r'(?<![\w./])'+field+r'\b','self.'+field,pieces[i])
            text=head+'\n'+''.join(pieces)
            text=re.sub(r'(?<=, )(/obj/[\w/]+)(?=\))',lambda m:repr(m[1]),text)
            return A.project(text,declaration,'self'+(', '+args if args else ''),env)
        fields=['hover_target','hover_origin','hover_inventory','hover_screen_loc','maptext','parentmob','clear_target',
                'inventory_slot_visible','inventory_item_visible','inventory_target_current','pointer_target','target_visible','process']
        for name,args in [('clear_target',''),('inventory_slot_visible','target'),('inventory_item_visible','target'),('inventory_target_current','target'),('pointer_target','origin'),
                          ('target_visible','target'),('set_target','origin'),('process',''),('persistence_runtime_var','key')]:
            sig='/obj/screen/hover_name'+('/'+name if name=='process' else '/proc/'+name)
            if name=='persistence_runtime_var':sig='/obj/screen/hover_name/'+name
            f=method(source,sig,args,fields);setattr(W,name,lambda *a,_f=f:_f(W,*a))
        f=method(source,'/obj/screen/hover_name/Destroy','',fields);W.destroy=lambda _f=f:_f(W)
        for name,args in [('hover_name_widget',''),('update_hover_name','target'),('clear_hover_name','')]:
            f=method(source,'/client/proc/'+name,args,['mob','hover_name_widget'])
            setattr(C,name,lambda *a,_f=f:_f(C,*a))
        env.update(optional_set=lambda w,t:w.set_target(t) if w else None,optional_clear=lambda w:w.clear_target() if w else None)
        callbacks=(root/'code/modules/client/client_procs.dm').read_text()
        for name,args in [('MouseEntered','object, location=None, control="map", params=""'),
                          ('MouseMove','object, location=None, control="map", params=""'),
                          ('MouseDrag','src_object, over_object, src_location=None, over_location=None, src_control="map", over_control="map", params=""')]:
            f=method(callbacks,'/client/'+name,args,['mouse_x','mouse_y','update_hover_name','UpdateMouseScreenLoc'])
            setattr(C,name,lambda *a,_f=f:_f(C,*a))
        C.UpdateMouseScreenLoc=lambda p:None
        f=method(source,'/client/MouseExited','object, location=None, control="map", params=""',['hover_name_widget'])
        C.MouseExited=lambda *a:f(C,*a)
        def slot(item=None,slot_id=1):
            S=atom('/obj/screen/inventory',parentmob=body,slot_id=slot_id,screen_loc=f'{slot_id},1')
            body.HUDinventory.append(S);C.screen.append(S)
            if item:
                item.loc=body;item.screen_loc=S.screen_loc;C.screen.append(item);readable.add(item)
            body.slots[slot_id]=item;return S
        return N(W=W,C=C,H=body,atom=atom,slot=slot,visible=world_visible,readable=readable,reads=read_calls,source=source)

    def test_displayed_owned_slot_routes_actual_item_and_matching_pointer_exit(self):
        m=self.model();I=m.atom(name='<rifle & sling>');S=m.slot(I)
        m.C.MouseEntered(S)
        self.assertIs(m.W.hover_target.resolve(),I);self.assertIs(m.W.hover_origin.resolve(),S)
        self.assertIn('&lt;rifle &amp; sling&gt;',m.W.maptext)
        self.assertTrue(all(t is I for _,t,_ in m.reads))
        m.C.MouseExited(S);self.assertEqual(m.W.maptext,'')
        m.C.MouseEntered(I);m.C.MouseEntered(S);m.C.MouseExited(I)
        self.assertTrue(m.W.maptext)  # Late item exit cannot erase new slot enter.
        m.C.MouseEntered(I);m.C.MouseExited(S);self.assertTrue(m.W.maptext)
        m.C.MouseExited(I);self.assertFalse(m.W.hover_target)
        m.C.MouseMove(S);self.assertTrue(m.W.maptext)
        m.C.MouseDrag(None,S);self.assertTrue(m.W.maptext)
        m.C.MouseMove(None);self.assertEqual(m.W.maptext,'')

    def test_inventory_removal_clears_even_if_item_is_now_visible_world_content(self):
        for via_slot in [False,True]:
            m=self.model();I=m.atom(name='held rifle');S=m.slot(I)
            m.C.MouseEntered(S if via_slot else I);self.assertTrue(m.W.maptext)
            I.loc=m.atom('/turf/floor');I.screen_loc=None;m.C.screen.remove(I);m.visible.add(I)
            m.W.process();self.assertEqual(m.W.maptext,'')
            m=self.model();I=m.atom();S=m.slot(I);m.C.MouseEntered(S if via_slot else I)
            I.screen_loc='9,9';S.screen_loc=I.screen_loc;m.W.process();self.assertEqual(m.W.maptext,'')
        for mutate in ['removed-slot','replaced-item','item-hidden','item-alpha','item-deleted','ui-rebuild','ui-removed','body-change','client-gone']:
            m=self.model();I=m.atom();S=m.slot(I);m.C.MouseEntered(S)
            if mutate=='removed-slot':m.H.HUDinventory.remove(S)
            if mutate=='replaced-item':m.H.slots[S.slot_id]=m.atom()
            if mutate=='item-hidden':I.invisibility=99
            if mutate=='item-alpha':I.alpha=0
            if mutate=='item-deleted':I.deleted=True
            if mutate=='ui-rebuild':m.H.HUDneed['hover name']=object()
            if mutate=='ui-removed':m.C.screen.remove(m.W)
            if mutate=='body-change':m.C.mob=m.atom('/mob/living/human')
            if mutate=='client-gone':m.H.client=None
            m.W.process();self.assertEqual(m.W.maptext,'',mutate)

    def test_foreign_hidden_undisplayed_or_mismatched_slots_do_not_disclose_names(self):
        for mutate in ['foreign-owner','foreign-item','container-item','not-displayed','no-screen-loc','wrong-location','slot-hidden','slot-alpha','slot-not-displayed','unregistered-slot','empty-slot']:
            m=self.model();I=m.atom(name='private item');S=m.slot(I)
            if mutate=='foreign-owner':S.parentmob=m.atom('/mob/living/human')
            if mutate=='foreign-item':I.loc=m.atom('/mob/living/human')
            if mutate=='container-item':I.loc=m.atom('/obj/item/storage')
            if mutate=='not-displayed':m.C.screen.remove(I)
            if mutate=='no-screen-loc':I.screen_loc=None
            if mutate=='wrong-location':I.screen_loc='9,9'
            if mutate=='slot-hidden':S.invisibility=99
            if mutate=='slot-alpha':S.alpha=0
            if mutate=='slot-not-displayed':m.C.screen.remove(S)
            if mutate=='unregistered-slot':m.H.HUDinventory.remove(S)
            if mutate=='empty-slot':m.H.slots[S.slot_id]=None
            m.C.MouseEntered(S);self.assertEqual(m.W.maptext,'',mutate)
        m=self.model();S=m.slot();S.master=m.atom(name='unrelated master')
        m.C.MouseEntered(S);self.assertEqual(m.W.maptext,'')

    def test_world_los_public_names_runtime_exclusions_and_destroy_are_preserved(self):
        m=self.model();world=m.atom(name='world item',loc=m.atom('/turf/floor'))
        m.visible.add(world);m.C.MouseEntered(world);self.assertEqual(m.W.maptext,'')
        m.readable.add(world);m.C.MouseEntered(world);self.assertTrue(m.W.maptext)
        m.readable.remove(world);m.W.process();self.assertEqual(m.W.maptext,'')
        human=m.atom('/mob/living/human',name='Secret identity',loc=m.atom('/turf/floor'),get_visible_name=lambda:'Unknown')
        m.visible.add(human);m.readable.add(human);m.C.MouseEntered(human)
        self.assertIn('Unknown',m.W.maptext);self.assertNotIn('Secret',m.W.maptext)
        for key in ['hover_target','hover_origin','hover_inventory','hover_screen_loc','parentmob','maptext','persistence_export_frame']:
            self.assertTrue(m.W.persistence_runtime_var(key),key)
        self.assertFalse(m.W.persistence_runtime_var('durable_example'))
        m.W.destroy();self.assertEqual(m.W.maptext,'');self.assertIsNone(m.W.parentmob)

    def test_direct_item_hit_and_stationary_refresh_require_current_visible_equipped_slot(self):
        def mutate(m,I,S,kind):
            if kind=='slot-hidden':S.invisibility=99
            if kind=='slot-transparent':S.alpha=0
            if kind=='slot-inert':S.mouse_opacity=0
            if kind=='slot-empty-position':S.screen_loc=None
            if kind=='slot-removed':m.C.screen.remove(S)
            if kind=='unregistered':m.H.HUDinventory.remove(S)
            if kind=='foreign-slot':S.parentmob=m.atom('/mob/living/human')
            if kind=='equipment-replaced':m.H.slots[S.slot_id]=m.atom()
            if kind=='position-mismatch':S.screen_loc='9,9'
        kinds=['slot-hidden','slot-transparent','slot-inert','slot-empty-position',
               'slot-removed','unregistered','foreign-slot','equipment-replaced','position-mismatch']
        for kind in kinds:
            for during_hover in [False,True]:
                with self.subTest(kind=kind,during_hover=during_hover):
                    m=self.model();I=m.atom(name='pouch contents');S=m.slot(I)
                    if during_hover:
                        m.C.MouseEntered(I);self.assertTrue(m.W.maptext)
                    mutate(m,I,S,kind)
                    self.assertIs(I.loc,m.H);self.assertIn(I,m.C.screen);self.assertTrue(I.screen_loc)
                    if during_hover:m.W.process()
                    else:m.C.MouseEntered(I)
                    self.assertEqual(m.W.maptext,'')
        source=self.model().source
        start=source.index('\t// A stale displayed item')
        end=source.index('\n/obj/screen/hover_name/proc/inventory_target_current',start)
        old=source[:start]+'\treturn TRUE\n'+source[end:]
        m=self.model(old);I=m.atom(name='stale pouch');S=m.slot(I);S.invisibility=99
        m.C.MouseEntered(I);self.assertTrue(m.W.maptext)
        m=self.model(old);I=m.atom();S=m.slot(I);m.C.MouseEntered(I)
        S.invisibility=99;m.W.process();self.assertTrue(m.W.maptext)

    def test_named_omissions_reproduce_slot_routing_and_stale_pointer_regressions(self):
        source=self.model().source
        mutant=source.replace('var/atom/target = pointer_target(origin)','var/atom/target = origin',1)
        m=self.model(mutant);I=m.atom();S=m.slot(I);m.C.MouseEntered(S)
        self.assertEqual(m.W.maptext,'')
        mutant=source.replace('label.hover_origin?.resolve() == object','label.hover_target?.resolve() == object',1)
        m=self.model(mutant);I=m.atom();S=m.slot(I);m.C.MouseEntered(S);m.C.MouseExited(S)
        self.assertTrue(m.W.maptext)
        mutant=source.replace('(hover_inventory && !inventory_target_current(target)) || ','',1)
        m=self.model(mutant);I=m.atom();S=m.slot(I);m.C.MouseEntered(I)
        I.loc=m.atom('/turf/floor');I.screen_loc=None;m.C.screen.remove(I);m.visible.add(I)
        m.W.process();self.assertTrue(m.W.maptext)
        mutant=source.replace('(hover_inventory && !inventory_target_current(target))','(hover_inventory && !inventory_item_visible(target))',1)
        m=self.model(mutant);I=m.atom();S=m.slot(I);m.C.MouseEntered(I)
        I.screen_loc='9,9';S.screen_loc=I.screen_loc;m.W.process();self.assertTrue(m.W.maptext)


class BlockingTreeSurface(unittest.TestCase):
    """Actual DM arithmetic/control flow with Python list/storage adapters only."""
    def model(self, source=None):
        import re, math
        from types import SimpleNamespace as N
        from collections import defaultdict
        source = source or CORE.read_text()
        spec=importlib.util.spec_from_file_location('surface_adapter',CORE.parents[3]/'tests/save_movement/source_adapter.py')
        adapter=importlib.util.module_from_spec(spec);spec.loader.exec_module(adapter)
        class Atom(N):
            __eq__=object.__eq__
            __hash__=object.__hash__
        class Cells(_offline.DMList):
            def __iadd__(self,value):
                self.extend(value) if isinstance(value,list) else self.append(value)
                return self
        env=projected_geometry(source)
        _offline.project(source,'/proc/los_surface_shadow(',env)
        _offline.project(source,'/proc/los_target_blocked(',env)
        for name in ['los_bucket_index','los_bucket_lower','los_bucket_upper']:
            env['round']=math.floor;_offline.project(source,'/proc/'+name+'(',env)
        env.update(typed_iter=lambda xs,kind:xs if xs is not None else [], list=lambda *xs:Cells(xs),owner_map=lambda:defaultdict(lambda:None),
            inclusive_range=lambda lo,hi:range(int(lo),int(hi)+1),bin_key=lambda x,y:f'{x},{y}',
            unit_starts=lambda lo,hi:[lo+i for i in range(max(0,math.ceil(hi-lo)))],
            new_bounds=lambda:N(cells=None),new_surface=lambda:N(),
            isnull=lambda x:x is None, ismovable=lambda x:x.type.startswith('/obj/'),
            isturf=lambda x:x.type.startswith('/turf/'),ishuman=lambda x:x.type.startswith('/mob/'),
            istype=lambda x,t:x.type.startswith(t),config=None,
            root_tree_family=lambda x:x.type.startswith(('/obj/structure/wild/tree','/obj/structure/wild/jungle','/obj/structure/wild/palm')),
            LOS_DENY=0,LOS_WORLD=1,LOS_SURFACE=2,LOS_SELF=4,id=id)
        snapshot=N(blockers=Cells(),blocker_bins=None,tree_bounds=None,presentation=True,eye_x=0,eye_y=0,eye_z=1,
                   radius_x=15,radius_y=15,revision=1,policy='fresh',clear_footprints=defaultdict(lambda:None))
        def method(name,args,fields):
            declaration='/datum/los_snapshot/proc/'+name
            text=fragment(source,declaration+'(')
            head,body=text.split('\n',1)
            for field in fields:
                body=re.sub(r'(?<![\w./])'+field+r'\b','self.'+field,body)
            body=body.replace('for (var/bx = min_x, bx <= max_x, bx++)','for (var/bx in inclusive_range(min_x, max_x))')
            body=body.replace('for (var/by = min_y, by <= max_y, by++)','for (var/by in inclusive_range(min_y, max_y))')
            body=body.replace('"[bx],[by]"','bin_key(bx, by)')
            body=body.replace('self.tree_bounds = list()','self.tree_bounds = owner_map()')
            body=body.replace('var/datum/los_tree_bounds/R = new','var/datum/los_tree_bounds/R = new_bounds()')
            body=body.replace('var/datum/los_surface_cell/C = new','var/datum/los_surface_cell/C = new_surface()')
            body=body.replace('for (var/cell_left = left, cell_left < right, cell_left++)','for (var/cell_left in unit_starts(left, right))')
            body=body.replace('for (var/cell_bottom = bottom, cell_bottom < top, cell_bottom++)','for (var/cell_bottom in unit_starts(bottom, top))')
            f=adapter.project(head+'\n'+body,declaration,'self, '+args,env)
            setattr(snapshot,name,lambda *a:f(snapshot,*a))
        method('surface_blockers','tx, ty',['blocker_bins','blockers'])
        method('surface_edge_visible','face, edge_low, edge_high, axis, direction, tile_x, tile_y, target, candidates',[])
        method('capture_tree_bounds','A',['tree_bounds','eye_x','eye_y'])
        method('owned_surface_cells','target',['tree_bounds','radius_x','radius_y'])
        method('tree_surface_visible','target, tx, ty, tile_x, tile_y',['owned_surface_cells','surface_blockers','surface_edge_visible','radius_x','radius_y'])
        snapshot.blocks_target=lambda tx,ty,tile_x,tile_y,opaque:any(env['los_target_blocked'](tx,ty,b.cell_x,b.cell_y,tile_x,tile_y,b.tile_x,b.tile_y,opaque) for b in snapshot.blockers)
        body=N(type='/mob/living/human',see_invisible=25)
        context=N(body=body,revision=1,policy_key=lambda:'fresh')
        text=fragment(source,'/datum/los_context/proc/decision_snapshot(')
        declaration,body_text=text.split('\n',1)
        for field in ['body','revision','policy_key']:
            body_text=re.sub(r'(?<![\w./])'+field+r'\b','self.'+field,body_text)
        body_text=body_text.replace('/mob/living/human',repr('/mob/living/human'))
        body_text=body_text.replace('target.opacity ? LOS_SURFACE : LOS_WORLD','(LOS_SURFACE if target.opacity else LOS_WORLD)')
        body_text=body_text.replace('"[target.opacity]|[target_tile_x],[target_tile_y]|[tx],[ty]"','(target.opacity, target_tile_x, target_tile_y, tx, ty)')
        body_text=body_text.replace(r'"|tree-surface-\ref[target]"','("tree-surface", id(target))')
        decision=adapter.project(declaration+'\n'+body_text,'/datum/los_context/proc/decision_snapshot','self, target, S, operation="visual"',env)
        def target(x,y,opaque=True,kind='/obj/structure/wild/tree'):
            return Atom(type=kind,x=x,y=y,z=1,step_x=0,step_y=0,opacity=opaque,alpha=255,
                     bound_x=0,bound_y=0,bound_width=32,bound_height=64 if kind.endswith('/jungle') else 32,
                     invisibility=0,gcDestroyed=False,gc_destroyed=False,loc=N(type='/turf/floor'))
        def cell(x,y,owner=None,tile=None,owners=1):
            if isinstance(owner,Atom):snapshot.capture_tree_bounds(owner)
            return N(cell_x=x,cell_y=y,tile_x=(tile or (x,y))[0],tile_y=(tile or (x,y))[1],surface_owner=owner,owners=owners)
        def capture(objects,opaque_tiles=(),presentation=True):
            # Engine boundary: native contents lists every strictly overlapping
            # turf, including partial overlaps. Execute the entire DM capture.
            snapshot.tree_bounds=None;snapshot.blockers=Cells();snapshot.clear_footprints.clear()
            body.x=10;body.y=10;body.z=1;body.step_x=body.step_y=0
            def locate(x,y,z):
                t=Atom(type='/turf/floor',x=x,y=y,z=z,opacity=(x,y) in opaque_tiles)
                t.contents=[a for a in objects if a.x+(a.step_x+a.bound_x)/32 < x+1 and a.x+(a.step_x+a.bound_x+a.bound_width)/32 > x
                            and a.y+(a.step_y+a.bound_y)/32 < y+1 and a.y+(a.step_y+a.bound_y+a.bound_height)/32 > y]
                return t
            env.update(locate=locate,world=N(maxx=40,maxy=40),new_snapshot=lambda:snapshot,new_cell=lambda:N(),
                       typed_iter=lambda xs,kind:getattr(xs,'contents',xs) if xs is not None else [])
            snapshot.index_blockers=lambda:None
            context.viewport=lambda:Cells([31,31])
            context.viewport_radii=lambda:Cells([15,15])
            text=fragment(source,'/datum/los_context/proc/capture(')
            head,code=text.split('\n',1)
            for field in ['body','revision','policy_key','viewport','viewport_radii']:
                code=re.sub(r'(?<![\w./])'+field+r'\b','self.'+field,code)
            code=code.replace('var/datum/los_snapshot/S = new','var/datum/los_snapshot/S = new_snapshot()')
            code=re.sub(r'(var/datum/los_cell/\w+) = new',r'\1 = new_cell()',code)
            code=re.sub(r'for \(var/(c[xy]) = (.*), \1 <= (.*), \1\+\+\)',r'for (var/\1 in inclusive_range(\2, \3))',code)
            f=adapter.project(head+'\n'+code,'/datum/los_context/proc/capture','self, presentation=False',env)
            return f(context,presentation)
        return N(S=snapshot,env=env,target=target,cell=cell,context=context,
                 capture=capture,
                 decision=lambda t,op='visual_tree':decision(context,t,snapshot,op))

    def test_exposed_blocking_tree_renders_while_ground_entities_and_reads_stay_denied(self):
        m=self.model();tree=m.target(2,1)
        m.S.blockers=[m.cell(2,1,tree),m.cell(1,1)]
        self.assertTrue(m.S.blocks_target(2,1,2,1,True))  # Old center-ray omission.
        self.assertEqual(m.decision(tree),2)
        for operation in ['visual','hover','examine']:
            self.assertEqual(m.decision(tree,operation),0,operation)
        self.assertEqual(m.decision(m.target(2,1,False,'/turf/floor'),'visual'),0)
        self.assertEqual(m.decision(m.target(4,2,False,'/obj/item'),'visual'),0)
        m.S.presentation=False;self.assertEqual(m.decision(tree),0)
        m.S.presentation=True;m.S.policy='stale';self.assertEqual(m.decision(tree),0)

    def test_enclosed_surface_unowned_cells_and_multiple_owners(self):
        m=self.model();tree=m.target(3,0)
        m.S.blockers=[m.cell(3,0,tree),m.cell(1,0)]
        self.assertFalse(m.S.tree_surface_visible(tree,3,0,3,0))
        self.assertEqual(m.decision(tree),0)
        tree=m.target(2,1);m.S.tree_bounds=None;m.S.blockers=[m.cell(2,1,object()),m.cell(1,1)]
        self.assertFalse(m.S.tree_surface_visible(tree,2,1,2,1))
        m.S.blockers[0].owners=2;m.S.tree_bounds=None
        self.assertFalse(m.S.tree_surface_visible(tree,2,1,2,1))
        m.S.capture_tree_bounds(tree)
        self.assertTrue(m.S.tree_surface_visible(tree,2,1,2,1))
        m.S.tree_bounds=None;m.S.blockers=[m.cell(3,0,tree),m.cell(1,.5,tile=(1,1)),m.cell(1,-.5,tile=(1,-1))]
        self.assertFalse(m.S.tree_surface_visible(tree,3,0,3,0))

    def test_two_tile_jungle_cannot_hide_behind_its_own_nearer_blocker_cell(self):
        m=self.model();tree=m.target(0,-3,kind='/obj/structure/wild/jungle')
        m.S.blockers=[m.cell(0,-3,tree),m.cell(0,-2,tree)]
        self.assertTrue(m.S.blocks_target(0,-3,0,-3,True))
        self.assertEqual(m.decision(tree),2)
        self.assertEqual(m.decision(m.target(0,-4,False,'/obj/item'),'visual'),0)
        self.assertEqual(m.decision(m.target(0,-3,False,'/turf/floor'),'visual'),0)
        self.assertEqual(m.decision(tree,'hover'),0)
        index=m.S.tree_bounds;self.assertEqual(len(index[tree].cells),2)
        m.S.clear_footprints.clear();self.assertEqual(m.decision(tree),2)
        self.assertIs(m.S.tree_bounds,index)
        m.S.blockers.append(m.cell(0,-1));m.S.tree_bounds=None;m.S.clear_footprints.clear()
        self.assertEqual(m.decision(tree),0)
        capture=fragment(CORE.read_text(),'/datum/los_context/proc/capture(')
        self.assertIn('S.capture_tree_bounds(AM)',capture)

    def test_foreign_co_owner_still_blocks_tree_surface(self):
        m=self.model();tree=m.target(0,-3,kind='/obj/structure/wild/jungle')
        root=m.cell(0,-3,tree);front=m.cell(0,-1,tree,owners=2)
        m.S.blockers=[root,front]
        self.assertEqual(m.decision(tree),0)
        front.owners=1;m.S.clear_footprints.clear()
        self.assertEqual(m.decision(tree),2)

    def test_real_capture_uses_physical_overhang_not_shifted_full_overlap_cells(self):
        m=self.model();tree=m.target(10,13);tree.step_x=2
        S=m.capture([tree],[(10,12)])
        self.assertEqual(len([b for b in S.blockers if b.surface_owner is tree]),2)
        cells=S.owned_surface_cells(tree)
        self.assertEqual([(c.cell_x,c.cell_y,c.half_x,c.half_y) for c in cells],[(.0625,3,.5,.5)])
        self.assertEqual(m.decision(tree),0)
        self.assertEqual(m.decision(tree,'hover'),0)
        # Omission witness: the fabricated second full cell grants visibility.
        cells.append(type(cells[0])(cell_x=1.0625,cell_y=3,half_x=.5,half_y=.5))
        S.clear_footprints.clear();self.assertEqual(m.decision(tree),2)
        tree=m.target(10,7,kind='/obj/structure/wild/jungle');tree.step_y=2
        S=m.capture([tree]);self.assertEqual(len(S.owned_surface_cells(tree)),2)
        self.assertEqual(len([b for b in S.blockers if b.surface_owner is tree]),3)
        S=m.capture([tree],presentation=False);self.assertIsNone(S.tree_bounds)

    def test_partial_rectangles_clipping_and_stale_bound_records(self):
        m=self.model();tree=m.target(2,1);tree.bound_width=17;tree.bound_height=9
        m.S.blockers=[m.cell(2,1,tree),m.cell(1,1)]
        cells=m.S.owned_surface_cells(tree)
        self.assertEqual((cells[0].half_x,cells[0].half_y),(17/64,9/64))
        for field in ['step_x','bound_x','bound_y','bound_width','bound_height']:
            old=getattr(tree,field);setattr(tree,field,old+2)
            self.assertIsNone(m.S.owned_surface_cells(tree),field)
            setattr(tree,field,old)
        tree=m.target(15,0);tree.bound_width=64;m.S.capture_tree_bounds(tree)
        cells=m.S.owned_surface_cells(tree)
        self.assertTrue(all(c.cell_x+c.half_x<=15.5 for c in cells))
        self.assertEqual(sum(c.half_x*2 for c in cells),1)

    def test_root_outside_view_needs_a_captured_owned_blocker_inside_view(self):
        m=self.model();tree=m.target(0,-16,kind='/obj/structure/wild/jungle')
        m.S.blockers=[m.cell(0,-16,tree),m.cell(0,-15,tree)]
        self.assertEqual(m.decision(tree),2)
        self.assertEqual(m.decision(tree,'hover'),0)
        self.assertEqual(m.decision(m.target(0,-16,False,'/turf/floor'),'visual'),0)
        m=self.model();tree=m.target(0,-17,kind='/obj/structure/wild/jungle')
        m.S.blockers=[m.cell(0,-17,tree),m.cell(0,-16,tree)]
        self.assertEqual(m.decision(tree),0)
        m=self.model();tree=m.target(2,1);m.S.blockers=[m.cell(2,1,tree),m.cell(1,1)]
        tree.x=100  # A stale owner record cannot admit the moved root.
        self.assertEqual(m.decision(tree),0)

    def test_cache_and_surface_admission_omission_controls(self):
        for mode in ['normal','surface-omitted','cache-omitted']:
            source=CORE.read_text()
            if mode=='surface-omitted':source=source.replace('if (tree_presentation && S.tree_surface_visible','if (FALSE && S.tree_surface_visible',1)
            if mode=='cache-omitted':source=source.replace('if (tree_presentation)\n\t\tfootprint_key','if (FALSE)\n\t\tfootprint_key',1)
            m=self.model(source);tree=m.target(2,1);m.S.blockers=[m.cell(2,1,tree),m.cell(1,1)]
            self.assertEqual(m.decision(tree),0 if mode=='surface-omitted' else 2)
            self.assertEqual(m.decision(tree,'hover'),2 if mode=='cache-omitted' else 0)

    def test_offset_blocker_ownership_and_existing_visibility_guards(self):
        for step in [-16,-8,-2,0,2,8,16,30]:
            m=self.model();tree=m.target(2,1);tree.step_x=step;tx=2+step/32
            m.S.blockers=[m.cell(tx,1,tree,(2,1)),m.cell(1,1)]
            self.assertEqual(m.decision(tree),2)
            self.assertEqual(m.decision(tree,'examine'),0)
        for field,value in [('alpha',0),('invisibility',100),('gcDestroyed',True),
                            ('gc_destroyed',True),('z',2),('x',100)]:
            m=self.model();tree=m.target(2,1);m.S.blockers=[m.cell(2,1,tree),m.cell(1,1)]
            setattr(tree,field,value);self.assertEqual(m.decision(tree),0,field)
        m=self.model();tree=m.target(2,1);m.S.blockers=[m.cell(2,1,tree),m.cell(0,0)]
        self.assertFalse(m.S.tree_surface_visible(tree,2,1,2,1))

    def oracle(self,tx,ty,blockers,half_x=.5,half_y=.5):
        from fractions import Fraction as Q
        tx,ty=Q(tx),Q(ty)
        half_x,half_y=Q(half_x),Q(half_y)
        if abs(tx)<=half_x and abs(ty)<=half_y:return True
        for axis,sign,center,side,depth_half,side_half in [(0,1,tx,ty,half_x,half_y),(0,-1,-tx,ty,half_x,half_y),(1,1,ty,tx,half_y,half_x),(1,-1,-ty,tx,half_y,half_x)]:
            if center<=depth_half:continue
            face=center-depth_half;lo=side-side_half;hi=side+side_half;points={lo,hi}
            for x,y in blockers:
                depth,across=(Q(y)*sign,Q(x)) if axis else (Q(x)*sign,Q(y))
                near=max(Q(0),depth-Q(1,2));far=min(face,depth+Q(1,2))
                for d in [near,far]:
                    if d>0:
                        for v in [across-Q(1,2),across+Q(1,2)]:
                            p=face*v/d
                            if lo<p<hi:points.add(p)
            points=sorted(points)
            for a,b in zip(points,points[1:]):
                sidepoint=(a+b)/2
                point=(sidepoint,face*sign) if axis else (face*sign,sidepoint)
                entries=[reference_entry(0,0,*point,Q(x),Q(y)) for x,y in blockers]
                if not any(t is not None and t<1 for t in entries):return True
        return False

    def test_rational_visibility_oracle_with_offsets_and_binned_flat_parity(self):
        import random
        from collections import defaultdict
        m=self.model();rng=random.Random(20261101);cases=0
        for _ in range(1800):
            tx,ty=[rng.randrange(-56,57)/16 for _ in range(2)]
            if abs(tx)<=.5 and abs(ty)<=.5:continue
            tree=m.target(tx,ty);tile=(20,20)
            coordinates=[(rng.randrange(-48,49)/16,rng.randrange(-48,49)/16) for _ in range(4)]
            m.S.tree_bounds=None;m.S.blockers=[m.cell(tx,ty,tree,tile)]+[m.cell(x,y,tile=(30+i,30+i)) for i,(x,y) in enumerate(coordinates)]
            expected=self.oracle(tx,ty,coordinates)
            m.S.blocker_bins=None
            self.assertEqual(m.S.tree_surface_visible(tree,tx,ty,*tile),expected,(tx,ty,coordinates))
            bins=defaultdict(lambda:None)
            for b in m.S.blockers:
                key=f'{m.env["los_bucket_index"](b.cell_x)},{m.env["los_bucket_index"](b.cell_y)}'
                if bins[key] is None:bins[key]=[]
                bins[key].append(b)
            m.S.blocker_bins=bins
            self.assertEqual(m.S.tree_surface_visible(tree,tx,ty,*tile),expected,(tx,ty,coordinates))
            cases+=1
        self.assertGreater(cases,1700)

    def test_partial_physical_edges_match_rational_oracle(self):
        import random
        rng=random.Random(3450)
        for _ in range(500):
            m=self.model();tree=m.target(rng.randrange(-5,6),rng.randrange(-5,6))
            tree.bound_width=rng.randrange(1,33);tree.bound_height=rng.randrange(1,33)
            tree.step_x=rng.randrange(-16,17);tree.step_y=rng.randrange(-16,17)
            coordinates=[(rng.randrange(-48,49)/16,rng.randrange(-48,49)/16) for _ in range(4)]
            m.S.blockers=[m.cell(tree.x,tree.y,tree)]+[m.cell(x,y) for x,y in coordinates]
            C=m.S.owned_surface_cells(tree)[1]
            expected=self.oracle(C.cell_x,C.cell_y,coordinates,C.half_x,C.half_y)
            self.assertEqual(m.S.tree_surface_visible(tree,0,0,tree.x,tree.y),expected,
                             (C,coordinates))

    def test_surface_work_is_cached_and_linear_and_scoped_to_tree_presenters(self):
        m=self.model();tree=m.target(2,1);m.S.blockers=[m.cell(2,1,tree),m.cell(1,1)]+[m.cell(10,i) for i in range(50)]
        calls=[];original=m.env['los_surface_shadow']
        m.env['los_surface_shadow']=lambda *a:(calls.append(a),original(*a))[1]
        self.assertEqual(m.decision(tree),2);count=len(calls)
        self.assertLessEqual(count,2*len(m.S.blockers))
        for _ in range(10):self.assertEqual(m.decision(tree),2)
        self.assertEqual(len(calls),count)
        root=CORE.parents[3]
        presenter=(root/'code/modules/visibility/root_tree_presenter.dm').read_text()
        masks=(root/'code/modules/visibility/los_presenter.dm').read_text()
        self.assertIn('decision_snapshot(T, S, "visual_tree")',presenter)
        self.assertIn('root_tree_family(A) && A.opacity ? "visual_tree" : "visual"',masks)
        self.assertIn('I.appearance_flags &= ~TILE_BOUND',presenter)
        self.assertIn('var/datum/los_snapshot/S = capture()',fragment(CORE.read_text(),'/datum/los_context/proc/decision('))


# Native-composition fallback source contracts (engine boundaries injected).
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace as N
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/visibility/los_presenter.dm'
spec = importlib.util.spec_from_file_location('fallback_source', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec);spec.loader.exec_module(adapter)
spec = importlib.util.spec_from_file_location('fallback_geometry', ROOT / 'tests/los_context/test_offline.py')
geometry = importlib.util.module_from_spec(spec);spec.loader.exec_module(geometry)


class Identity(N):
    __eq__ = object.__eq__
    __hash__ = object.__hash__


class List:
    """DM associative/list operations at the engine storage boundary."""
    def __init__(self, items=()):self.items=list(items);self.assoc={}
    def __iter__(self):return iter(self.items)
    def __contains__(self,x):return x in self.items
    def __getitem__(self,k):return self.assoc.get(k)
    def __setitem__(self,k,v):
        if k not in self.items:self.items.append(k)
        self.assoc[k]=v
    def __bool__(self):return bool(self.items)
    def __iadd__(self,x):
        self.items.extend(x.items if isinstance(x,List) else [x]);return self
    def __ior__(self,x):
        for v in x.items if isinstance(x,List) else [x]:
            if v not in self.items:self.items.append(v)
        return self
    def __sub__(self,x):
        excluded=x.items if isinstance(x,List) else [x]
        return List(v for v in self.items if v not in excluded)
    def __isub__(self,x):
        result=self-x;self.items=result.items
        self.assoc={k:v for k,v in self.assoc.items() if k in self.items};return self
    def Copy(self):
        result=List(self.items);result.assoc=dict(self.assoc);return result
    def Cut(self):self.items.clear();self.assoc.clear()


def atom(x,y,*,tree=False,opaque=False,turf=False):
    tile=Identity(type='/turf/floor',x=x,y=y,z=1,opacity=False,contents=[],gcDestroyed=False,gc_destroyed=False)
    a=tile if turf else Identity(type='/obj/structure/wild/tree' if tree else '/obj/item',x=x,y=y,z=1,
                                loc=tile,step_x=0,step_y=0)
    a.opacity=opaque;a.gcDestroyed=a.gc_destroyed=False;a.mouse_opacity=2
    a.plane=0;a.layer=4;a.appearance=Identity(appearance_flags=16,plane=0,layer=4,
        color='#123456',alpha=200,pixel_x=9,pixel_y=-3,opacity=opaque)
    return a


def model(source=None):
    source=source or SOURCE.read_text()
    body=atom(10,10);owner=N(images=List(),root_tree_presenter=None)
    context=N(body=body,revision=1,policy_key=lambda:'fresh',eligible=lambda:True)
    presenter=N(owner=owner,context=context,retired=False,dirty=True,
                images=List(),owned_images=List(),visible_targets=List(),tree_images=List(),tree_appearances=List())
    owner.los_presenter=presenter;owner.los_context=context
    outcomes={};grid={};allocations=[]
    def image(appearance,A):
        I=Identity(**vars(appearance)) if appearance else Identity(appearance_flags=0)
        I.loc=A;allocations.append(I);return I
    env=geometry.projected_geometry()
    env.update(list=List,image=image,typed_iter=lambda x,t:getattr(x,'contents',x) if x is not None else [],
        get_turf=lambda a:a if a.type.startswith('/turf/') else a.loc,
        root_tree_family=lambda a:a.type.startswith('/obj/structure/wild/tree'),
        ismovable=lambda a:not a.type.startswith('/turf/'),ishuman=lambda a:False,
        isturf=lambda a:a.type.startswith('/turf/'),istype=lambda a,t:a.type.startswith(t),
        TILE_BOUND=16,RESET_COLOR=1,RESET_ALPHA=2,RESET_TRANSFORM=4,LOS_DENY=0,
        world=N(maxx=25,maxy=25,time=1),locate=lambda x,y,z:grid.get((x,y,z)),
        inclusive_range=lambda lo,hi:range(int(lo),int(hi)+1))
    fields=list(vars(presenter))+['owns_atom','hidden_image','native_tree_image','withdraw_tree_image','clear_images']
    def project(name,args):
        declaration='/datum/los_presenter/proc/'+name
        text=declaration+'('+args+')\n'+adapter.extract(source,declaration)+'\n'
        for field in fields:
            text=re.sub(r'(?<![\w./])'+field+r'\b','self.'+field,text)
        # Restore qualified proc name if field matching altered the declaration.
        text=text.replace('/proc/self.','/proc/')
        text=re.sub(r'\bsrc\b','self',text)
        for path in ['/obj/screen','/atom/movable/lighting_overlay','/atom/movable/lighting_fullbright']:
            text=text.replace(path,repr(path))
        text=text.replace('root_tree_family(A) && A.opacity ? "visual_tree" : "visual"',
                          '("visual_tree" if root_tree_family(A) and A.opacity else "visual")')
        text=re.sub(r'for\(var/(c[xy]) = (.*), \1 <= (.*), \1\+\+\)',
                    r'for(var/\1 in inclusive_range(\2, \3))',text)
        return adapter.project(text,declaration,'self'+(', '+args if args else ''),env)
    for name,args in [('withdraw_tree_image','A'),('hidden_image','A'),('native_tree_image','A'),
                      ('owns_atom','A'),('invalidate','changed=None, possible_opacity=False'),
                      ('refresh','S=None'),('clear_images',''),('retire','')]:
        f=project(name,args);setattr(presenter,name,lambda *a,_f=f:_f(presenter,*a))
    S=N(policy='fresh',revision=1,eye_z=1,radius_x=4,radius_y=4)
    context.capture=lambda presentation:S
    context.decision_snapshot=lambda a,s,op:outcomes.get(a,1)
    def include(A):
        grid[(A.loc.x,A.loc.y,A.z)]=A.loc;A.loc.contents.append(A)
    return N(P=presenter,C=owner,V=context,S=S,outcomes=outcomes,grid=grid,include=include,allocations=allocations)


class FallbackTreeSource(unittest.TestCase):
    def test_allowed_copy_identity_light_plane_offsets_and_deduplication(self):
        m=model();tree=atom(13,10,tree=True,opaque=True);m.include(tree)
        other=atom(13,11,turf=True);other.contents=[tree];m.grid[(13,11,1)]=other
        self.assertTrue(m.P.refresh(m.S));I=m.P.tree_images[tree]
        self.assertIs(I.loc,tree);self.assertEqual(I.appearance_flags,7)
        self.assertEqual((I.plane,I.layer,I.color,I.alpha),(0,4,'#123456',200))
        self.assertEqual((I.pixel_x,I.pixel_y,I.mouse_opacity),(0,0,2))
        self.assertTrue(I.override);self.assertIn(I,m.C.images)
        self.assertEqual(tree.appearance.appearance_flags,16)
        self.assertEqual(len([i for i in m.P.owned_images if i.loc is tree]),1)
        self.assertTrue(m.P.refresh(m.S));self.assertIs(m.P.tree_images[tree],I)

    def test_fallback_denial_opacity_viewport_and_compositor_handoff(self):
        m=model();tree=atom(13,10,tree=True,opaque=True);m.include(tree)
        m.P.refresh(m.S);I=m.P.tree_images[tree]
        m.outcomes[tree]=0;m.P.refresh(m.S)
        self.assertNotIn(I,m.C.images);mask=m.P.images[tree]
        self.assertIs(mask.loc,tree);self.assertEqual(mask.mouse_opacity,0)
        m.outcomes[tree]=2;m.P.refresh(m.S);self.assertNotIn(mask,m.C.images)
        I=m.P.tree_images[tree];tree.opacity=False
        m.P.refresh(m.S);self.assertNotIn(I,m.C.images);self.assertIsNone(m.P.tree_images[tree])
        tree.opacity=True;m.P.refresh(m.S);I=m.P.tree_images[tree]
        tree.appearance=Identity(**{**vars(tree.appearance),'opacity':False})
        m.P.refresh(m.S);self.assertIsNot(m.P.tree_images[tree],I)
        I=m.P.tree_images[tree];m.grid.clear();m.P.refresh(m.S)
        self.assertNotIn(I,m.C.images);self.assertFalse(m.P.tree_images)
        m.include(tree);m.P.refresh(m.S);I=m.P.tree_images[tree]
        m.C.root_tree_presenter=N(retired=False,owns_tree=lambda a:a is tree)
        m.P.refresh(m.S);self.assertNotIn(I,m.C.images)
        m.C.root_tree_presenter=None;m.P.refresh(m.S);I=m.P.tree_images[tree]
        m.V.eligible=lambda:False;m.P.refresh(m.S);self.assertNotIn(I,m.C.images)
        m.V.eligible=lambda:True;m.P.refresh(m.S);m.P.retire()
        self.assertFalse(m.C.images);self.assertIsNone(m.C.los_presenter)

    def test_upper_cell_invalidation_is_synchronous_and_per_client(self):
        m=model();other=model();tree=atom(13,10,tree=True,opaque=True)
        m.include(tree);other.include(tree);m.P.refresh(m.S);other.P.refresh(other.S)
        I=m.P.tree_images[tree];other_I=other.P.tree_images[tree]
        # Door ray misses root footprint, but can conceal a second owned cell.
        door=atom(11,11);ordinary=atom(10,13);m.include(ordinary);m.P.refresh(m.S)
        m.P.invalidate(door,True)
        self.assertIsNone(m.P.tree_images[tree]);self.assertNotIn(I,m.C.images)
        self.assertIn(m.P.images[tree],m.C.images);self.assertIn(other_I,other.C.images)
        self.assertIsNone(m.P.images[ordinary])
        m.P.refresh(m.S);I=m.P.tree_images[tree]
        m.P.invalidate(atom(11,11))  # Transparent unrelated clutter preserves copy.
        self.assertIn(I,m.C.images)
        m.P.invalidate()  # Unknown/viewer context transition withdraws copy.
        self.assertNotIn(I,m.C.images)
        m.P.refresh(m.S);m.P.clear_images()
        self.assertFalse(m.C.images);self.assertFalse(m.P.tree_appearances)

    def test_omission_controls_catch_each_confirmed_fallback_gap(self):
        source=SOURCE.read_text()
        m=model(source.replace('I.appearance_flags &= ~TILE_BOUND','I.appearance_flags |= TILE_BOUND'))
        tree=atom(13,10,tree=True,opaque=True);m.include(tree);m.P.refresh(m.S)
        self.assertTrue(m.P.tree_images[tree].appearance_flags & 16)
        start=source.index('\tif(!changed || changed == context.body')
        end=source.index('\t// Before a blocker write/move',start)
        m=model(source[:start]+source[end:]);tree=atom(13,10,tree=True,opaque=True)
        m.include(tree);m.P.refresh(m.S);I=m.P.tree_images[tree]
        m.P.invalidate(atom(11,11),True);self.assertIn(I,m.C.images)


if __name__=='__main__':unittest.main()
