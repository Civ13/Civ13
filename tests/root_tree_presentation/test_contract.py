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

def compile_proc(text,signature,args,env,method=False):
    name=signature.split('/')[-1].split('(')[0]
    lines=['def '+name+'('+args+'):']
    for raw in P.fragment(text,signature).splitlines()[1:]:
        line=raw.strip()
        if not line or line.startswith('//'):continue
        indent=len(raw)-len(raw.lstrip('\t'))
        line=re.sub(r'^var/(?:\w+/)*(\w+)\s*=',r'\1 =',line)
        line=P.expression(line).replace('.Copy()','.copy()').replace('.Cut()','.clear()')
        line=line.replace('arglist(sample)','*sample')
        line=re.sub(r'([\w.]+)\.len',r'len(\1)',line)
        line=line.replace('/obj/structure/wild/tree/live_tree',repr('/obj/structure/wild/tree/live_tree'))
        line=line.replace('/turf/floor/plating',repr('/turf/floor/plating'))
        if method:
            for field in ['root_trees','owner','images','owned_images','shutter','retired','weather_copy','weather_plane','weather_target','context','driver_generation']:
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
        lines.append('    '*indent+line)
    if name=='retire':lines.insert(1,'    global root_tree_presenters')
    exec(compile('\n'.join(lines)+'\n','source:'+name,'exec'),env)
    return env[name]

def environment():
    return {'__builtins__':{},'len':len,'range':range,'abs':abs,'GAME_PLANE':1,'PLANE_MASTER':1,'CIV13_ROOT_TREE_PRESENTATION':True,
      'lighting_startup_in_progress':False,'created_lighting_corners_and_overlays':True,
      'isnum':lambda x:isinstance(x,(int,float)),'islist':lambda x:isinstance(x,list),
      'dm_list':lambda *xs:Values(xs),'isturf':lambda x:hasattr(x,'type') and x.type=='/turf/floor/plating',
      'length':lambda x:0 if x is None else len(x),'qdel':lambda x:setattr(x,'deleted',True),
      'root_tree_presenters':Items(),'BLEND_OVERLAY':2}

def tree():
    return N(type='/obj/structure/wild/tree/live_tree',gcDestroyed=False,gc_destroyed=False,
      loc=N(type='/turf/floor/plating'),anchored=True,opacity=True,step_x=0,step_y=0,pixel_x=-16,pixel_y=0,
      bound_x=0,bound_y=0,bound_width=32,bound_height=32,plane=1,layer=5.11,pixel_w=0,pixel_z=0,appearance_flags=0,transform=None,filters=[],overlays=[],underlays=[],
      vis_contents=[],render_source=None,render_target=None,maptext='',icon='icons/obj/flora/bigtrees.dmi')

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
    def test_exact_registered_root_only(self):
        t=tree();c=N(root_trees=[t]);self.assertTrue(self.f(c,t));self.assertFalse(self.f(N(root_trees=[]),t))
        t.type+='/pine';self.assertFalse(self.f(c,t))
    def test_production_random_offsets_are_preserved_not_hardcoded(self):
        for x,y in [(-24,0),(-8,16),(-16,0)]:
            t=tree();t.pixel_x=x;t.pixel_y=y;self.assertTrue(self.f(N(root_trees=[t]),t))
    def test_unknown_footprints_offsets_filters_and_deletion_rejected(self):
        for field,value in [('step_x',2),('pixel_x',64),('bound_width',64),('opacity',False),('gcDestroyed',True),('overlays',[1]),('filters',[1]),('transform',object())]:
            t=tree();setattr(t,field,value);self.assertFalse(self.f(N(root_trees=[t]),t),field)
    def test_off_admission_reads_no_arguments(self):
        self.env['CIV13_ROOT_TREE_PRESENTATION']=False
        class Bomb:
            def __getattribute__(self,k):raise AssertionError(k)
        self.assertFalse(self.f(Bomb(),Bomb()))

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
    def test_replaced_weather_or_changed_game_plane_rejected_on_refresh(self):
        env=environment()
        f=compile_proc(TREE,'/datum/root_tree_presenter/proc/planes_admitted(','self',env,True)
        weather=N(blend_mode=2,render_target='owned');game=N(filters=[],color=None,transform=None,alpha=255)
        masters={'[LIGHTING_PLANE]':weather,'[GAME_PLANE]':game}
        r=N(owner=N(mob=N(hud_used=N(plane_masters=masters)),screen=[weather,game]),weather_plane=weather,
            weather_copy=N(render_source='owned'),weather_target='owned')
        self.assertTrue(f(r))
        game.filters=['shadow'];self.assertFalse(f(r));game.filters=[]
        masters['[LIGHTING_PLANE]']=object();self.assertFalse(f(r));masters['[LIGHTING_PLANE]']=weather
        r.owner.screen.remove(weather);self.assertFalse(f(r));r.owner.screen.append(weather)
        weather.render_target='foreign';self.assertFalse(f(r))
        r.weather_plane=None;self.assertFalse(f(r))
    def model(self):
        env=environment();r=N(retired=False,driver_generation=1,owner=N(screen=Items(['HUD']),images=Items(['foreign']),root_tree_presenter=None),
           shutter=N(deleted=False),weather_copy=N(deleted=False),weather_plane=N(render_target='owned'),weather_target='owned',
           images={},owned_images=Items(),context=object())
        r.owner.root_tree_presenter=r
        r.invalidate=compile_proc(TREE,'/datum/root_tree_presenter/proc/invalidate(','self',env,True).__get__(r)
        r.retire=compile_proc(TREE,'/datum/root_tree_presenter/proc/retire(','self',env,True).__get__(r)
        env['root_tree_presenters'].append(r)
        return r,env
    def test_invalidation_blanks_only_owned_images_and_closes_view(self):
        r,_=self.model();i=N(icon='tree',mouse_opacity=1);r.owned_images.append(i);r.invalidate()
        self.assertIsNone(i.icon);self.assertEqual(i.mouse_opacity,0);self.assertIn(r.shutter,r.owner.screen)
        self.assertEqual(r.owner.images,['foreign'])
    def test_retire_cleans_ownership_and_restores_only_its_weather_lease(self):
        for foreign in [False,True]:
            r,env=self.model();owner=r.owner;wp=r.weather_plane
            r.owner.images.append('own');r.owned_images.append('own')
            if foreign:wp.render_target='other'
            r.retire();self.assertEqual(owner.images,['foreign']);self.assertIsNone(owner.root_tree_presenter)
            self.assertEqual(wp.render_target,'other' if foreign else None);self.assertIsNone(env['root_tree_presenters'])
    def test_one_client_cleanup_does_not_touch_another(self):
        a,_=self.model();b,_=self.model();other_owner=b.owner
        b.owner.images.append('second');b.owned_images.append('second')
        a.invalidate();a.retire()
        self.assertIs(b.owner,other_owner);self.assertEqual(b.owner.images,['foreign','second'])
        self.assertEqual(b.weather_plane.render_target,'owned');self.assertFalse(b.retired)
    def test_actual_mask_sample_before_whole_sprite_multiply(self):
        rgb=P.fragment(SNAP,'/proc/root_light_rgb(')
        self.assertIn('mask.MapColors(arglist(sample))',rgb);self.assertIn('mask.GetPixel(16, 16)',rgb)
        refresh=P.fragment(TREE,'/datum/root_tree_presenter/proc/refresh(')
        self.assertLess(refresh.index('context.decision'),refresh.index('root_light_rgb'))
        self.assertLess(refresh.index('root_light_rgb'),refresh.index('frame.Blend(rgb, ICON_MULTIPLY)'))
        self.assertNotIn('I.color = sample',refresh);self.assertIn('I.loc = T',refresh)
        self.assertIn('I.mouse_opacity = T.mouse_opacity',refresh);self.assertIn('I.appearance_flags |= TILE_BOUND',refresh)
        self.assertLess(refresh.index('if(!context.capture())'),refresh.index('owner.screen -= shutter'))
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
            ('code/modules/lighting/lighting_overlay.dm','/atom/movable/lighting_overlay/proc/update_overlay(','var/turf/T = loc')]:
            source=(ROOT/path).read_text();check(source,signature,write)
            mutant=source.replace('root_tree_invalidate(src)','removed_invalidation(src)').replace('root_tree_invalidate(loc)','removed_invalidation(loc)')
            with self.assertRaises(ValueError):check(mutant,signature,write)
    def test_no_unknown_fullbright_fallback_or_global_activation(self):
        self.assertIn('root.needs_fullbright_coverage()',SNAP)
        self.assertIn('return null',P.fragment(SNAP,'/proc/root_light_rgb('))
        core=(ROOT/'code/modules/visibility/los_context.dm').read_text()
        self.assertIn('#define CIV13_ROOT_TREE_PRESENTATION 0',core)
        self.assertIn('#define CIV13_GEOMETRIC_LOS_CORE 0',core)
        for p in (ROOT/'code').rglob('*.dm'):
            self.assertNotRegex(p.read_text(errors='replace'),r'new\s*/datum/root_tree_presenter')

if __name__=='__main__':unittest.main()
