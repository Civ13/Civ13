"""Source-derived root admission/snapshot/ownership contracts; not client pixels."""
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace as N
import unittest

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('existing_los',ROOT/'tests/los_context/test_offline.py')
P=importlib.util.module_from_spec(spec);spec.loader.exec_module(P)
SNAP=(ROOT/'code/modules/visibility/root_light_snapshot.dm').read_text()
TREE=(ROOT/'code/modules/visibility/root_tree_presenter.dm').read_text()

class Values(list):
    def __getitem__(self,i):return super().__getitem__(i-1)
    def __setitem__(self,i,v):super().__setitem__(i-1,v)
    def __iadd__(self,v):self.append(v);return self

class Items(list):
    def __bool__(self):return True
    def __ior__(self,v):
        if v not in self:self.append(v)
        return self
    def __isub__(self,v):
        for x in v if isinstance(v,list) else [v]:
            if x in self:self.remove(x)
        return self

class Matrix(N):pass
def identity():return Matrix(a=1,b=0,c=0,d=0,e=1,f=0)
def compile_proc(text,signature,args,env,method=False):
    name=signature.split('/')[-1].split('(')[0]
    lines=['def '+name+'('+args+'):']
    for raw in P.fragment(text,signature).splitlines()[1:]:
        line=raw.strip()
        if not line or line.startswith('//'):continue
        indent=len(raw)-len(raw.lstrip('\t'))
        line=re.sub(r'^var/(?:\w+/)*(\w+)\s*=',r'\1 =',line)
        increment=re.fullmatch(r'if\(\+\+(\w+) > (\d+)\)',line)
        if increment:
            lines.append('    '*indent+increment[1]+' += 1')
            line='if('+increment[1]+' > '+increment[2]+')'
        line=P.expression(line).replace('.Copy()','.copy()').replace('.Cut()','.clear()')
        line=re.sub(r'([A-Za-z_]\w*):([A-Za-z_]\w*)',r'\1.\2',line)
        assignment=re.fullmatch(r'(\w+) = (.+) \? (.+) : (.+)',line)
        if assignment:line=assignment[1]+' = '+assignment[3]+' if '+assignment[2]+' else '+assignment[4]
        line=line.replace('arglist(sample)','*sample')
        line=line.replace('"phase-[phase].ready.json"','f"phase-{phase}.ready.json"')
        line=re.sub(r'([\w.]+)\.len',r'len(\1)',line)
        line=line.replace('/turf/floor/plating',repr('/turf/floor/plating'))
        line=line.replace('/matrix',repr('/matrix'))
        for path in ['/obj/structure/wild/largejungle','/obj/structure/wild/jungle','/obj/structure/wild/palm','/obj/structure/wild/tree']:
            line=line.replace(path,repr(path))
        if method:
            for field in ['root_trees','owner','images','owned_images','retired','context','frames','frame_keys','frame_appearances','frame_lights','frame_dirs','published_frames','source_appearances','light_keys','light_values','screens','leased_planes','lease_targets','game_plane','original_filters','scene_plane','scene_active','fallback_reason','fallback_count','release_owned_scene']:
                line=re.sub(r'(?<![.\w])'+field+r'\b','self.'+field,line)
        if line.startswith('for(var/i = 1, i <= 20, i++)'):line='for i in range(1,21):'
        else:
            loop=re.fullmatch(r'for\(var/(?:\w+/)*(\w+) in (.+)\)',line)
            if loop:line='for '+loop[1]+' in '+loop[2]+':'
        if line.startswith('if(') and line.endswith(')'):line='if '+line[3:-1]+':'
        elif line.startswith('else if(') and line.endswith(')'):line='elif '+line[8:-1]+':'
        elif line=='else':line='else:'
        if line=='result += current[i]':line='result.append(current[i])'
        ternary=re.fullmatch(r'return (.+) \? (.+) : (.+)',line)
        if ternary:line='return '+ternary[2]+' if '+ternary[1]+' else '+ternary[3]
        if line.endswith('++'):line=line[:-2]+' += 1'
        if line.endswith('--'):line=line[:-2]+' -= 1'
        lines.append('    '*indent+line)
    if name=='retire':lines.insert(1,'    global root_tree_presenters')
    exec(compile('\n'.join(lines)+'\n','source:'+name,'exec'),env)
    return env[name]

def environment():
    env={'__builtins__':{},'len':len,'range':range,'abs':abs,'GAME_PLANE':1,'PLANE_MASTER':1,'CIV13_ROOT_TREE_PRESENTATION':True,
      'lighting_startup_in_progress':False,'created_lighting_corners_and_overlays':True,
      'isnum':lambda x:isinstance(x,(int,float)),'islist':lambda x:isinstance(x,list),
      'dm_list':lambda *xs:Values(xs),'isturf':lambda x:hasattr(x,'type') and x.type.startswith('/turf/'),
      'length':lambda x:0 if x is None else len(x),'ismovable':lambda x:hasattr(x,'vis_contents'),'qdel':lambda x:setattr(x,'deleted',True),
      'root_tree_presenters':Items(),'BLEND_OVERLAY':2,'ROOT_TREE_PLANE':6,'TILE_BOUND':8,
      'RESET_COLOR':16,'RESET_ALPHA':32,'RESET_TRANSFORM':64,
      'isnull':lambda x:x is None,'istype':lambda x,t:(t=='/matrix' and isinstance(x,Matrix)) or (hasattr(x,'type') and (x.type==t or x.type.startswith(t+'/')))}
    compile_proc(TREE,'/proc/root_tree_identity_transform(','M',env)
    compile_proc(TREE,'/proc/root_tree_family(','A',env)
    return env

def tree():
    return N(type='/obj/structure/wild/tree/live_tree',gcDestroyed=False,gc_destroyed=False,
      loc=N(type='/turf/floor/plating'),anchored=True,opacity=True,step_x=0,step_y=0,pixel_x=-16,pixel_y=0,
      bound_x=0,bound_y=0,bound_width=32,bound_height=32,plane=1,layer=5.11,pixel_w=0,pixel_z=0,appearance_flags=0,transform=identity(),filters=[],overlays=[],underlays=[],
      vis_contents=[],render_source=None,render_target=None,maptext='',icon='icons/obj/flora/bigtrees.dmi',mouse_opacity=1,alpha=255)

class Snapshot(unittest.TestCase):
    def setUp(self):
        self.env=environment();self.f=compile_proc(SNAP,'/proc/root_light_mask_snapshot(','root',self.env)
        self.root=N();self.overlay=N(loc=self.root,needs_update=False,color=Values(range(20)),last_color=Values(range(20)))
        self.root.lighting_overlay=self.overlay
    def test_distinct_owners_and_no_alias(self):
        a=self.f(self.root);other=N();other.lighting_overlay=N(loc=other,needs_update=False,color=Values([.2]*20),last_color=Values([.2]*20))
        b=self.f(other);a[1]=99;self.assertEqual(self.overlay.color[1],0);self.assertEqual(b[1],.2)
    def test_stale_foreign_pending_startup_and_nonmatrix_rejected(self):
        for case in ['foreign','pending','changed','startup','nonmatrix','short']:
            self.setUp()
            if case=='foreign':self.overlay.loc=object()
            elif case=='pending':self.overlay.needs_update=True
            elif case=='changed':self.overlay.color[1]=.8
            elif case=='startup':self.env['lighting_startup_in_progress']=True
            elif case=='nonmatrix':self.overlay.color='#ffffff'
            else:self.overlay.color=Values([1])
            self.assertIsNone(self.f(self.root),case)
    def test_committed_update_is_read_fresh(self):
        self.overlay.color=Values([.3]*20);self.overlay.last_color=Values([.3]*20)
        self.assertEqual(self.f(self.root),[.3]*20)
    def test_missing_owner_check_control(self):
        f=compile_proc(SNAP.replace(' || owner.loc != root',''),'/proc/root_light_mask_snapshot(','root',self.env)
        self.overlay.loc=object();self.assertIsNotNone(f(self.root))

class Admission(unittest.TestCase):
    def setUp(self):
        self.env=environment();self.f=compile_proc(TREE,'/datum/los_context/proc/root_tree_admitted(','self, A',self.env,True)
    def test_real_gaia_families_without_fixture_registration(self):
        for kind in ['/obj/structure/wild/tree/live_tree/pine','/obj/structure/wild/palm',
                     '/obj/structure/wild/jungle/acacia']:
            t=tree();t.type=kind;t.loc.type='/turf/floor/grass';t.bound_width=64
            self.assertTrue(self.f(N(root_trees=[]),t),kind)
        for kind in ['/obj/item/wood','/obj/structure/wild/largejungle']:
            t.type=kind;self.assertFalse(self.f(N(),t))
        t=tree();t.layer=3.2;self.assertFalse(self.f(N(),t))
    def test_deleted_contained_or_other_plane_not_admitted(self):
        for field,value in [('gcDestroyed',True),('gc_destroyed',True),('loc',N(type='/obj/container')),('plane',14)]:
            t=tree();setattr(t,field,value);self.assertFalse(self.f(N(),t),field)
    def test_off_admission_reads_no_arguments(self):
        self.env['CIV13_ROOT_TREE_PRESENTATION']=False
        class Bomb:
            def __getattribute__(self,k):raise AssertionError(k)
        self.assertFalse(self.f(Bomb(),Bomb()))
    def test_identity_transform_checks_all_components(self):
        f=self.env['root_tree_identity_transform']
        self.assertTrue(f(None));self.assertTrue(f(identity()))
        for field in 'abcdef':
            m=identity();setattr(m,field,getattr(m,field)+.000001);self.assertFalse(f(m))
        mutant=TREE.replace('M.c == 0 && ','');env=environment()
        g=compile_proc(mutant,'/proc/root_tree_identity_transform(','M',env)
        m=identity();m.c=1;self.assertTrue(g(m))

class LightPolicy(unittest.TestCase):
    def setUp(self):
        self.env=environment();self.env.update(INVISIBILITY_LEVEL_TWO=45,istext=lambda x:isinstance(x,str))
        compile_proc(SNAP,'/proc/root_light_mask_snapshot(','root',self.env)
        self.f=compile_proc(SNAP,'/proc/root_light_rgb(','root, viewer',self.env)
        self.root=N(lighting_overlay=None,needs_fullbright_coverage=lambda:False)
        self.viewer=N(see_invisible=25)
        self.env['icon']=lambda *a:(_ for _ in ()).throw(AssertionError('Unexpected icon read'))
    def test_missing_unknown_mask_is_not_white(self):
        self.assertIsNone(self.f(self.root,self.viewer))
    def test_explicit_fullbright_and_native_bypass_are_white(self):
        self.root.needs_fullbright_coverage=lambda:True
        self.assertEqual(self.f(self.root,self.viewer),'#ffffff')
        self.root.needs_fullbright_coverage=lambda:False;self.viewer.see_invisible=45
        self.assertEqual(self.f(self.root,self.viewer),'#ffffff')
    def test_actual_mask_receives_copied_matrix_and_center_sample(self):
        calls=[]
        mask=N(Width=lambda:32,Height=lambda:32,MapColors=lambda *a:calls.append(a),GetPixel=lambda x,y:'#194766' if (x,y)==(16,16) else None)
        self.env['icon']=lambda *a:mask
        self.root.lighting_overlay=N(loc=self.root,needs_update=False,color=Values(range(20)),last_color=Values(range(20)),icon='mask',icon_state='',dir=2)
        self.assertEqual(self.f(self.root,self.viewer),'#194766')
        self.assertEqual(calls,[tuple(range(20))])
    def test_disabled_or_pending_never_reads_texture(self):
        self.env['CIV13_ROOT_TREE_PRESENTATION']=False
        self.assertIsNone(self.f(self.root,self.viewer))
        self.env['CIV13_ROOT_TREE_PRESENTATION']=True
        self.root.lighting_overlay=N(loc=self.root,needs_update=True)
        self.assertIsNone(self.f(self.root,self.viewer))

class OwnershipAndComposition(unittest.TestCase):
    def model(self):
        env=environment()
        class Plane(N):
            __hash__=object.__hash__
        game=Plane(render_target='game',filters=[],deleted=False,color=None,alpha=255,transform=identity())
        roof=Plane(render_target='roof',deleted=False)
        r=N(retired=False,owner=N(screen=Items(['HUD',game,roof]),images=Items(['foreign','own']),root_tree_presenter=None),
            images={},owned_images=Items(['own']),frames={},published_frames={},frame_keys={},frame_appearances={},frame_lights={},frame_dirs={},source_appearances={},light_keys={},light_values={},screens=Items([roof]),
            leased_planes=Items([game,roof]),lease_targets={game:'game',roof:'roof'},game_plane=game,
            original_filters=['shadow'],scene_plane=None,scene_active=True,context=object())
        r.owner.root_tree_presenter=r
        r.release_owned_scene=compile_proc(TREE,'/datum/root_tree_presenter/proc/release_owned_scene(','self',env,True).__get__(r)
        r.retire=compile_proc(TREE,'/datum/root_tree_presenter/proc/retire(','self',env,True).__get__(r)
        env['root_tree_presenters'].append(r)
        return r,env,game,roof
    def test_retire_releases_only_owned_planes_and_images(self):
        for foreign in [False,True]:
            r,env,game,roof=self.model();owner=r.owner
            if foreign:game.render_target='foreign';game.filters=['replacement']
            r.retire()
            self.assertEqual(owner.images,['foreign']);self.assertEqual(owner.screen,['HUD',game])
            self.assertIsNone(owner.root_tree_presenter);self.assertTrue(roof.deleted)
            self.assertEqual(game.render_target,'foreign' if foreign else None)
            self.assertEqual(game.filters,['replacement'] if foreign else ['shadow'])
            self.assertEqual(len(env['root_tree_presenters']),0);self.assertIsNone(r.context)
            r.retire();self.assertEqual(owner.images,['foreign'])
    def test_one_client_cleanup_does_not_touch_another(self):
        a,_,_,_=self.model();b,_,game,_=self.model();owner=b.owner
        a.retire();self.assertIs(b.owner,owner);self.assertEqual(game.render_target,'game')
        self.assertEqual(owner.images,['foreign','own']);self.assertFalse(b.retired)
    def test_plane_lease_rejects_replacement_or_removed_screen(self):
        r,env,game,roof=self.model();r.owner.mob=N(hud_used=N(plane_masters={'[GAME_PLANE]':game}))
        f=compile_proc(TREE,'/datum/root_tree_presenter/proc/planes_admitted(','self',env,True)
        self.assertTrue(f(r));game.render_target='foreign';self.assertFalse(f(r));game.render_target='game'
        r.owner.screen.remove(roof);self.assertFalse(f(r));r.owner.screen.append(roof)
        r.owner.mob.hud_used.plane_masters['[GAME_PLANE]']=object();self.assertFalse(f(r))
    def test_mask_then_whole_sprite_tint_and_cache(self):
        rgb=P.fragment(SNAP,'/proc/root_light_rgb(')
        self.assertIn('mask.MapColors(arglist(sample))',rgb);self.assertIn('mask.GetPixel(16, 16)',rgb)
        refresh=P.fragment(TREE,'/datum/root_tree_presenter/proc/refresh(')
        self.assertLess(refresh.index('context.decision_snapshot'),refresh.index('cached_light(T)'))
        self.assertLess(refresh.index('cached_light(T)'),refresh.index('frame.Blend(rgb, ICON_MULTIPLY)'))
        self.assertIn('frame_keys[T] != frame_key',refresh)
        self.assertIn('icon(T.icon, T.icon_state, T.dir)',refresh)
        self.assertNotIn('frame.Width() != 64',refresh)
        setting=P.fragment(TREE,'/proc/root_tree_set_frame(')
        self.assertNotIn('I.color = sample',setting);self.assertIn('I.color = null',setting)
    def test_compositor_is_shared_not_per_tree_shadow(self):
        constructor=P.fragment(TREE,'/datum/root_tree_presenter/proc/setup_scene(')
        self.assertEqual(constructor.count('scene_plane.filters = original_filters.Copy()'),1)
        self.assertNotIn('drop_shadow',P.fragment(TREE,'/datum/root_tree_presenter/proc/refresh('))
        self.assertIn('make_lit_relay(roof_target, mask_target, ROOT_ROOF_PLANE',constructor)
        self.assertIn('make_relay(weather_target, ROOT_WEATHER_PLANE',constructor)
        relay=P.fragment(TREE,'/obj/screen/root_scene_relay')
        self.assertIn('screen_loc = "WEST,SOUTH"',relay)
        invalidate=P.fragment(TREE,'/datum/root_tree_presenter/proc/invalidate(')
        self.assertNotIn('owner.screen',invalidate);self.assertIn('withdraw_tree(I.loc, I)',invalidate)
        self.assertIn('I.icon = null',P.fragment(TREE,'/datum/root_tree_presenter/proc/withdraw_tree('))
    def test_lit_relay_uses_direct_mask_composite_and_preserves_source_alpha(self):
        env=environment();calls=[]
        def relay(source,number,order):
            r=N(render_source=source,plane=number,layer=order,filters=Values([]))
            calls.append(r);return r
        env.update(make_relay=relay,filter=lambda **kw:kw,FILTER_OVERLAY=1,BLEND_MULTIPLY=3)
        f=compile_proc(TREE,'/datum/root_tree_presenter/proc/make_lit_relay(','self, source, mask_source, number, order',env,True)
        for plane in [8,9]:
            r=f(N(),'raw-scene','committed-mask',plane,1)
            self.assertEqual((r.render_source,r.plane,r.layer),('raw-scene',plane,1))
            self.assertEqual(list(r.filters),[dict(type='layer',render_source='committed-mask',flags=1,blend_mode=3)])
        body=P.fragment(TREE,'/datum/root_tree_presenter/proc/make_lit_relay(')
        self.assertNotIn('overlays +=',body)
        self.assertNotIn('type="alpha"',body)
        # Algebraic contract, NOT a native renderer/pixel oracle. Multiply uses
        # destination alpha; the removed second alpha mask would square it.
        for alpha in [0,0.25,0.5,1]:
            for mask in [0,0.125,0.5,1]:
                source=(0.8,0.4,0.2,alpha)
                lit=tuple(channel*mask for channel in source[:3])+(alpha,)
                self.assertEqual(lit[3],source[3])
                self.assertEqual(lit[:3],(0.8*mask,0.4*mask,0.2*mask))
        self.assertNotEqual(0.5*0.5,0.5)  # old redundant-alpha negative control

    def test_default_activation_has_owned_lifecycle(self):
        core=(ROOT/'code/modules/visibility/los_context.dm').read_text()
        self.assertIn('#define CIV13_ROOT_TREE_PRESENTATION 1',core)
        self.assertIn('#define CIV13_GEOMETRIC_LOS_CORE 1',core)
        lifecycle=(ROOT/'code/modules/visibility/los_lifecycle.dm').read_text()
        self.assertIn('new /datum/root_tree_presenter(src, V)',lifecycle)
        self.assertIn('los_context.retire()',lifecycle)
        self.assertNotIn('spawn(',TREE);self.assertNotIn('sleep(',TREE)

    def test_attached_frame_uses_parent_visual_offsets_once(self):
        env=environment();f=compile_proc(TREE,'/proc/root_tree_set_frame(','I, T, frame',env)
        class Image:
            def __setattr__(self,name,value):
                if name=='appearance':self.__dict__.update(vars(value))
                else:object.__setattr__(self,name,value)
        for x,y in [(-16,0),(-24,0),(-8,16)]:
            t=tree();t.pixel_x=x;t.pixel_y=y;t.appearance=t;i=Image()
            f(i,t,object())
            self.assertEqual((x+i.pixel_x,y+i.pixel_y),(x,y))
            self.assertTrue(i.appearance_flags & env['RESET_COLOR']);self.assertTrue(i.appearance_flags & env['RESET_ALPHA'])
        mutant=TREE.replace('\tI.pixel_x = 0\n','').replace('\tI.pixel_y = 0\n','')
        omitted=compile_proc(mutant,'/proc/root_tree_set_frame(','I, T, frame',env)
        t=tree();t.pixel_x=-16;t.pixel_y=0;t.appearance=t;i=Image();omitted(i,t,object())
        self.assertEqual((t.pixel_x+i.pixel_x)-t.pixel_x,-16)
    def test_invalidation_precedes_native_mutation_and_has_omission_control(self):
        def check(source,signature,write):
            body=P.fragment(source,signature)
            self.assertLess(body.index('root_tree_invalidate('),body.index(write))
        for path,signature,write in [
            ('code/game/atoms_movable.dm','/atom/movable/proc/forceMove(','loc = destination'),
            ('code/game/atoms_movable.dm','/atom/movable/proc/persistence_set_loc(','loc = destination'),
            ('code/game/mob/mob_movement.dm','/atom/movable/Move(','persistence_movement_allowed'),
            ('code/game/mob/mob.dm','/mob/proc/reset_view(','client.perspective'),
            ('code/game/objects/structures/wild.dm','/obj/structure/wild/tree/live_tree/update_icon(','..()'),
            ('code/modules/lighting/lighting_overlay.dm','/atom/movable/lighting_overlay/proc/update_overlay(','last_color = L.Copy()')]:
            source=(ROOT/path).read_text();check(source,signature,write)
            mutant=source.replace('root_tree_invalidate(src)','removed_invalidation(src)').replace('root_tree_invalidate(loc)','removed_invalidation(loc)')
            with self.assertRaises(ValueError):check(mutant,signature,write)

class SceneFallback(unittest.TestCase):
    def setUp(self):
        self.env=environment();self.env.update(FLOAT_PLANE=-32767,max=max,min=min)
        self.foreground=compile_proc(TREE,'/proc/root_tree_foreground_appearance(','A, inherited_plane, inherited_layer, depth=0, budget=None',self.env)
    def appearance(self,**changes):
        values=dict(plane=1,layer=3,icon='sprite',maptext='',render_source=None,render_target=None,
                    overlays=[],underlays=[],filters=[],vis_contents=[],alpha=255,invisibility=0,loc=None)
        values.update(changes);return N(**values)
    def test_foreground_roof_and_inherited_nested_layers(self):
        self.assertFalse(self.foreground(self.appearance(),1,3))
        for layer in [5.11,6,10.1,11.1]:
            self.assertTrue(self.foreground(self.appearance(layer=layer),1,3),layer)
        nested=self.appearance(plane=-32767,layer=11.1)
        self.assertTrue(self.foreground(self.appearance(overlays=[nested]),1,3))
        self.assertTrue(self.foreground(self.appearance(underlays=[nested]),1,3))
        self.assertFalse(self.foreground(self.appearance(plane=14,layer=20),1,3))
        inherited=self.appearance(plane=-32767,layer=-1)
        self.assertTrue(self.foreground(inherited,1,10.1))
        self.assertTrue(self.foreground(self.appearance(icon=None),1,3,depth=8))
    def test_omitted_nested_inspection_control(self):
        mutant=TREE.replace('root_tree_foreground_appearance(O, p, l, depth + 1, budget)','FALSE')
        env=environment();env.update(FLOAT_PLANE=-32767)
        f=compile_proc(mutant,'/proc/root_tree_foreground_appearance(','A, inherited_plane, inherited_layer, depth=0, budget=None',env)
        mixed=self.appearance(overlays=[self.appearance(layer=11.1)])
        self.assertTrue(self.foreground(mixed,1,3));self.assertFalse(f(mixed,1,3))
    def audit(self,atoms,client_images=(),owned=(),los_owned=()):
        body=N(z=2,see_invisible=25)
        self.env.update(range=lambda radius,b:atoms,get_turf=lambda a:a,get_dist=lambda a,b:0)
        c=N(body=body,root_tree_admitted=lambda a:getattr(a,'root',False))
        r=N(context=c,owner=N(images=list(client_images),los_presenter=N(owned_images=list(los_owned))),owned_images=list(owned))
        f=compile_proc(TREE,'/datum/root_tree_presenter/proc/composition_conflict(','self, S, scene=None',self.env,True)
        return f(r,N(radius_x=7,radius_y=7))
    def test_plain_root_success_and_native_world_conflicts(self):
        self.assertIsNone(self.audit([self.appearance(layer=5.11,root=True),self.appearance()]))
        self.assertEqual(self.audit([self.appearance(layer=10.1)]),'native foreground or mixed-layer appearance')
        self.assertEqual(self.audit([self.appearance(overlays=[self.appearance(layer=11.1)])]),'native foreground or mixed-layer appearance')
        self.assertEqual(self.audit([self.appearance(filters=['custom'])]),'unbounded game appearance')
        # Nested RESET_ALPHA can escape parent alpha; conservative audit must
        # not skip a whole appearance tree because its parent looks hidden.
        hidden=self.appearance(alpha=0,invisibility=100,overlays=[self.appearance(layer=11.1)])
        self.assertEqual(self.audit([hidden]),'native foreground or mixed-layer appearance')
    def test_audit_budgets_reject_broad_graphs_and_collections(self):
        leaf=self.appearance(icon=None)
        self.assertTrue(self.foreground(leaf,1,3,budget=Values([0])))
        budget=Values([2])
        self.assertFalse(self.foreground(leaf,1,3,budget=budget));self.assertEqual(budget[1],1)
        broad=self.appearance(icon=None,overlays=[leaf]*3)
        self.assertTrue(self.foreground(broad,1,3,budget=Values([2])))
        self.assertEqual(self.audit([], [leaf]*2049),'client image audit budget exceeded')
        # Admitted roots skip appearance recursion, independently exercising the
        # outer atom-visit limit instead of coincident recursive exhaustion.
        root=self.appearance(layer=5.11,root=True)
        self.assertEqual(self.audit([root]*4097),'scene atom audit budget exceeded')
        self.assertEqual(self.audit([self.appearance(icon=None,overlays=[leaf]*4097)]),'appearance audit budget exceeded')
    def test_client_images_not_borrowed_and_out_of_z_ignored(self):
        high=self.appearance(layer=11.1)
        self.assertEqual(self.audit([], [high]),'client-owned foreground image')
        self.assertIsNone(self.audit([], [high],owned=[high]))
        self.assertIsNone(self.audit([], [high],los_owned=[high]))
        high.loc=N(z=3,plane=1,layer=0)
        self.assertIsNone(self.audit([], [high]))
    def test_fallback_releases_scene_but_retains_owner_and_can_reactivate(self):
        helper=OwnershipAndComposition();r,env,game,roof=helper.model();owner=r.owner
        env.update(min=min,max=max,range=lambda radius,body:[])
        # Execute the production refresh admission prefix; rendering is tested
        # independently and is intentionally not simulated as native pixels.
        prefix=P.fragment(TREE,'/datum/root_tree_presenter/proc/refresh(').split('\tvar/list/current = list()')[0]+'\treturn TRUE\n'
        prefix=prefix.replace('composition_conflict(S, scene)','self.composition_conflict(S, scene)').replace('setup_scene()','self.setup_scene()').replace('scene_roots(scene)','self.scene_roots(scene)')
        r.context=N(body=object());r.fallback_reason=None;r.fallback_count=0;r.owner.los_context=r.context
        reason=['native foreground or mixed-layer appearance']
        r.composition_conflict=lambda S,scene:reason[0]
        r.scene_roots=lambda scene:[object()]
        activated=[]
        def setup():r.scene_active=True;activated.append(True);return True
        r.setup_scene=setup
        f=compile_proc(prefix,'/datum/root_tree_presenter/proc/refresh(','self, S',env,True)
        self.assertTrue(f(r,N(radius_x=7,radius_y=7)));self.assertFalse(r.scene_active)
        self.assertIs(r.owner,owner);self.assertIs(owner.root_tree_presenter,r)
        self.assertEqual(owner.images,['foreign']);self.assertEqual(game.filters,['shadow'])
        self.assertEqual(r.fallback_count,1);self.assertFalse(activated)
        self.assertTrue(f(r,N(radius_x=7,radius_y=7)));self.assertEqual(r.fallback_count,1)
        reason[0]=None;self.assertTrue(f(r,N(radius_x=7,radius_y=7)));self.assertTrue(r.scene_active)
        self.assertIsNone(r.fallback_reason);self.assertEqual(activated,[True])
        r.scene_roots=lambda scene:[]
        self.assertTrue(f(r,N(radius_x=7,radius_y=7)))
        self.assertFalse(r.scene_active);self.assertEqual(r.fallback_reason,'no root trees')
        self.assertEqual(activated,[True])

if __name__=='__main__':unittest.main()
