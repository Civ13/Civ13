"""Offline tile-cadence projections; not engine movement or pixel evidence."""
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace as N
import unittest

ROOT=Path(__file__).resolve().parents[2]
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module
P=load('motion_geometry','tests/los_context/test_offline.py')
A=load('motion_adapter','tests/save_movement/source_adapter.py')
LIFE=(ROOT/'code/modules/visibility/los_lifecycle.dm').read_text()
CORE=(ROOT/'code/modules/visibility/los_context.dm').read_text()

class Tile:
    def __init__(self,x,y=1,z=1):self.x,self.y,self.z=x,y,z
class Contexts(list):
    def Copy(self):return self.copy()

class TileMotion(unittest.TestCase):
    def scene(self,source=LIFE):
        events=[]
        env=dict(CIV13_GEOMETRIC_LOS_CORE=True,abs=abs,list=lambda *a:a,
            typed_iter=lambda values,kind:values,ishuman=lambda a:getattr(a,'human',False),
            ismob=lambda a:getattr(a,'mob',False),get_turf=lambda a:a.loc,
            los_invalidate=lambda a,possible=False:events.append((a,possible)))
        before=A.project(source,'/proc/los_invalidate_movement','A',env)
        near=A.project(source,'/proc/los_movement_affects_context','V, old_turf, new_turf',env)
        env['los_movement_affects_context']=near
        after=A.project(source,'/proc/los_refresh_moved_viewer','A, force_refresh=False',env)
        tile=Tile(3)
        actor=N(human=True,mob=True,opacity=False,loc=tile,x=3,y=1,z=1,step_x=0,step_y=0)
        owner=N(los_dirty=False,captures=0)
        context=N(body=actor,owner=owner,retired=False,movement_turf=tile,viewport_radii=lambda:P.DMList([7,7]))
        actor.client=owner;owner.los_context=context
        geometry=P.projected_geometry()
        blocked=P.project(CORE,'/proc/los_target_blocked(',geometry)
        clients=[owner];contexts=Contexts([context])
        for x,z in [(1,1),(100,1),(1,2)]:
            c=N(los_dirty=False,captures=0,masked=False)
            contexts.append(N(body=N(x=x,y=1,z=z),owner=c,viewport_radii=lambda:P.DMList([7,7])))
            clients.append(c)
        def publish(c,body):
            c.captures+=1;c.los_dirty=False
            if c is not owner:
                # Real geometry with a fixed blocker; image storage is an adapter.
                c.masked=bool(body.z==actor.z and blocked(actor.x-body.x,0,4-body.x,0,
                    actor.x-body.x,0,4-body.x,0,False))
        for c,v in zip(clients,contexts):
            c.reconcile_geometric_los=lambda c=c,body=v.body:publish(c,body)
        env['los_active_contexts']=contexts
        return N(actor=actor,owner=owner,context=context,clients=clients,before=before,after=after,events=events)

    def test_offset_pulses_and_failed_moves_do_not_force_capture(self):
        s=self.scene()
        for offset in [2,4,8,12,16,24,30,-2,-8,0]:
            s.before(s.actor);s.actor.step_x=offset;s.after(s.actor)
        self.assertEqual(s.events,[])
        self.assertEqual([c.captures for c in s.clients],[0,0,0,0])
        s.owner.los_dirty=True
        s.before(s.actor);s.after(s.actor)
        self.assertTrue(s.owner.los_dirty)  # Pending door/light work is retained.

    def test_tile_transition_refreshes_nearby_hidden_character_before_return(self):
        s=self.scene();old=s.actor.loc
        s.before(s.actor);s.actor.loc=Tile(5);s.actor.x=5;s.after(s.actor)
        self.assertEqual([c.captures for c in s.clients],[1,1,0,0])
        self.assertTrue(s.clients[1].masked)
        self.assertIs(s.context.movement_turf,s.actor.loc)
        self.assertIn((old,False),s.events)
        count=len(s.events)
        s.actor.step_x=12;s.before(s.actor);s.after(s.actor)
        self.assertEqual(len(s.events),count)
        self.assertTrue(s.clients[1].masked)
        self.assertEqual(s.clients[1].captures,1)

    def test_force_refresh_and_z_transition_are_retained(self):
        s=self.scene();s.after(s.actor,True)
        self.assertEqual(s.owner.captures,1)
        s.actor.loc=Tile(3,z=2);s.actor.z=2;s.after(s.actor)
        self.assertEqual([c.captures for c in s.clients],[2,1,0,1])
        self.assertIs(s.context.movement_turf,s.actor.loc)
        source=(ROOT/'code/game/atoms_movable.dm').read_text()
        self.assertEqual(source.count('los_refresh_moved_viewer(src, TRUE)'),2)
        self.assertIn('root_tree_invalidate(src)',P.fragment(source,'/atom/movable/proc/forceMove('))

    def test_blockers_and_replaced_contexts_do_not_take_quiet_path(self):
        for change in ['opaque','retired','body','owner','no-context']:
            s=self.scene()
            if change=='opaque':s.actor.opacity=True
            if change=='retired':s.context.retired=True
            if change=='body':s.context.body=object()
            if change=='owner':s.context.owner=object()
            if change=='no-context':s.owner.los_context=None
            s.before(s.actor);self.assertTrue(s.events,change)
            if change not in ['body','owner']:
                s.after(s.actor)
                if change!='no-context':self.assertEqual(s.owner.captures,1)

    def test_quiet_path_and_neighbor_refresh_omission_controls(self):
        mutant=LIFE.replace('if(!force_refresh && !H.opacity && !V.retired && V.body == H && V.owner == H.client && T && V.movement_turf == T)','if(FALSE)',1)
        s=self.scene(mutant);s.after(s.actor)
        self.assertEqual(s.owner.captures,1)  # Old offset-driven behavior witness.
        mutant=LIFE.replace('C.reconcile_geometric_los()','C.los_dirty = TRUE',1)
        s=self.scene(mutant);s.actor.loc=Tile(5);s.actor.x=5;s.after(s.actor)
        self.assertEqual(s.owner.captures,1)
        self.assertEqual(s.clients[1].captures,0)
        self.assertFalse(s.clients[1].masked)

    def render_key(self,body,owner,anchored,source=CORE,time=0):
        # Evaluate the actual key template/offset branch, not a separate cache.
        policy=P.fragment(source,'/datum/los_context/proc/policy_key(')
        branch=re.search(r'var/offset_key = tile_anchored \? "([^"]*)" : "([^"]*)"',policy)
        self.assertIsNotNone(branch)
        offset_key=branch[1] if anchored else branch[2]
        template=re.search(r'\treturn "([^\n]*)"',policy)[1]
        names=dict(body=body,owner=owner,revision=1,offset_key=offset_key,world=N(time=time))
        def expression(code):
            if code=='config ? config.disable_fov : 1':return 1
            if ' ? ' in code:
                condition,values=code.split(' ? ');yes,no=values.split(' : ')
                return eval(yes if eval(condition,{'__builtins__':{}},names) else no,{'__builtins__':{}},names)
            return eval(code,{'__builtins__':{}},names)
        template=re.sub(r'\\ref\[([^\]]+)\]',lambda m:str(id(expression(m[1]))),template)
        for _ in range(2):
            template=re.sub(r'\[([^\]]+)\]',lambda m:str(expression(m[1])),template)
        return template

    def test_scheduled_identity_ignores_offsets_but_fresh_read_policy_does_not(self):
        body=N(x=3,y=1,z=1,step_x=0,step_y=0,sight=0,see_invisible=0,see_in_dark=2,
               dir=2,resting=False,lying=False,prone=False,pulling=None)
        owner=N(view=7,perspective=0,pixel_x=0,pixel_y=0,los_camera_union_until=-1,los_camera_radius_x=0,los_camera_radius_y=0)
        presentation=self.render_key(body,owner,True);physical=self.render_key(body,owner,False)
        body.step_x=12;body.step_y=-4
        self.assertEqual(self.render_key(body,owner,True),presentation)
        self.assertNotEqual(self.render_key(body,owner,False),physical)
        body.x+=1
        self.assertNotEqual(self.render_key(body,owner,True),presentation)
        self.assertIn('return policy_key(TRUE)',P.fragment(CORE,'/datum/los_context/proc/presentation_key('))
        self.assertIn('var/key = V.presentation_key()',LIFE)
        self.assertNotIn('var/key = V.policy_key()',LIFE)

    def test_authorization_remains_fresh_physical_and_presentation_explicit(self):
        capture=P.fragment(CORE,'/datum/los_context/proc/capture(')
        decision=P.fragment(CORE,'/datum/los_context/proc/decision_snapshot(')
        read=P.fragment(CORE,'/datum/los_context/proc/decision(')
        self.assertIn('capture(presentation = FALSE)',capture)
        self.assertIn('if (!presentation)\n\t\tS.eye_x += body.step_x / 32',capture)
        self.assertIn('S.eye_y += body.step_y / 32',capture)
        self.assertIn('(!S.presentation || !ishuman(target))',decision)
        self.assertIn('var/datum/los_snapshot/S = capture()',read)
        self.assertIn('S.policy != policy_key()',decision)
        self.assertIn('V.capture(TRUE)',LIFE)
        self.assertIn('los_next_audit = world.time + 5',LIFE)
        for path in ['los_presenter.dm','root_tree_presenter.dm']:
            self.assertIn('context.capture(TRUE)',(ROOT/'code/modules/visibility'/path).read_text())

class DistanceCamera(unittest.TestCase):
    HUMAN=(ROOT/'code/game/mob/living/carbon/human/human.dm').read_text()

    def ui(self,source=None):
        source=source or self.HUMAN
        objects=[];calls=[]
        body=N(client=N(screen=objects),contents=[],looking=True)
        body.using_look=lambda:body.looking
        body.client.reconcile_geometric_los=lambda:calls.append('refresh')
        text=P.fragment(source,'/mob/living/human/proc/handle_ui_visibility(')
        text=re.sub(r'\bsrc\b','self',text)
        text=text.replace('"Look into Distance ([self])"','scope_name(self)')
        text=re.sub(r'(?<=, )(/(?:obj|datum)/[\w/]+)(?=\))',lambda m:repr(m[1]),text)
        env=dict(CIV13_GEOMETRIC_LOS_CORE=True,typed_iter=lambda xs,t:[x for x in xs if x.type.startswith(t)],
                 istype=lambda x,t:x.type.startswith(t),scope_name=lambda h:'look-button')
        f=A.project(text,'/mob/living/human/proc/handle_ui_visibility','self',env)
        def screen(path,**values):
            item=N(type='/obj/screen/'+path,invisibility=0,scoped_invisible=False,owner=None,name='other')
            vars(item).update(values);objects.append(item);return item
        return N(body=body,screen=screen,run=lambda:f(body),calls=calls)

    def test_enter_exit_repeat_and_renderer_lifecycle_preserve_world_and_hide_hud(self):
        m=self.ui()
        infrastructure=[m.screen(p) for p in ['plane_master/game_world','plane_master/lighting','plane_master/light_mask',
                                               'plane_master/hud','root_scene_master','root_scene_relay']]
        hud=m.screen('inventory');invisible=m.screen('other',invisibility=25)
        aim=m.screen('aiming_cross');look=m.screen('movable/action_button',name='look-button')
        scope=m.screen('movable/action_button',owner=N(type='/datum/action/toggle_scope'))
        other_action=m.screen('movable/action_button')
        for _ in range(3):
            m.body.looking=True;m.run();m.run()
            self.assertTrue(all(x.invisibility==0 and not x.scoped_invisible for x in infrastructure+[aim,look,scope]))
            self.assertEqual((hud.invisibility,other_action.invisibility),(100,100))
            self.assertEqual(invisible.invisibility,25)
            # Replacement renderer in an active scope must remain visible too.
            replacement=m.screen('root_scene_relay');m.run();self.assertEqual(replacement.invisibility,0)
            m.body.looking=False;m.run()
            self.assertEqual((hud.invisibility,other_action.invisibility),(0,0))
            self.assertFalse(hud.scoped_invisible)
        self.assertEqual(len(m.calls),12)
        old_hidden=m.screen('root_scene_master',invisibility=100,scoped_invisible=True)
        m.body.looking=True;m.run();self.assertEqual(old_hidden.invisibility,0)
        m.body.client=None;m.run()

    def test_scope_renderer_exemption_omission_reproduces_hidden_compositor(self):
        start=self.HUMAN.index('\t\t\t\t// Scope mode hides controls')
        end=self.HUMAN.index('\t\t\t\tif (O.invisibility)',start)
        m=self.ui(self.HUMAN[:start]+self.HUMAN[end:])
        renderer=m.screen('root_scene_relay');m.run()
        self.assertEqual(renderer.invisibility,100)
        m.body.looking=False;m.run();self.assertEqual(renderer.invisibility,0)

    def camera(self,pan_x=0,pan_y=0,source=CORE):
        import math
        from collections import defaultdict
        class Cells(P.DMList):
            def __iadd__(self,x):self.append(x);return self
            @property
            def len(self):return len(self)
        body=N(type='/mob/living/human',x=100,y=100,z=1,step_x=0,step_y=0,see_invisible=25)
        owner=N(view=7,pixel_x=pan_x,pixel_y=pan_y,los_camera_union_until=-1,los_camera_radius_x=0,los_camera_radius_y=0)
        context=N(body=body,owner=owner,revision=1,policy_key=lambda:f'{owner.pixel_x},{owner.pixel_y}',
                  viewport=lambda:Cells([owner.view*2+1,owner.view*2+1]))
        env=P.projected_geometry(source)
        P.project(source,'/proc/los_target_blocked(',env)
        env.update(round=math.floor,list=lambda *xs:Cells(xs),typed_iter=lambda xs,t:getattr(xs,'contents',xs),isnull=lambda x:x is None,
            ismovable=lambda a:not a.type.startswith('/turf/'),ishuman=lambda a:a.type.startswith('/mob/living/human'),
            isturf=lambda a:a.type.startswith('/turf/'),istype=lambda a,t:a.type.startswith(t),config=None,
            LOS_DENY=0,LOS_WORLD=1,LOS_SURFACE=2,LOS_SELF=4,
            world=N(maxx=200,maxy=200,time=0),inclusive_range=lambda lo,hi:range(int(lo),int(hi)+1),
            getviewsize=lambda v:Cells([v*2+1,v*2+1]))
        def method(name,args,fields):
            text=P.fragment(source,'/datum/los_context/proc/'+name+'(')
            head,code=text.split('\n',1)
            for field in fields:code=re.sub(r'(?<![\w./])'+field+r'\b','self.'+field,code)
            code=code.replace('var/datum/los_snapshot/S = new','var/datum/los_snapshot/S = new_snapshot()')
            code=re.sub(r'(var/datum/los_cell/\w+) = new',r'\1 = new_cell()',code)
            code=re.sub(r'for \(var/(c[xy]) = (.*), \1 <= (.*), \1\+\+\)',r'for (var/\1 in inclusive_range(\2, \3))',code)
            code=code.replace('/mob/living/human',repr('/mob/living/human'))
            code=code.replace('target.opacity ? LOS_SURFACE : LOS_WORLD','(LOS_SURFACE if target.opacity else LOS_WORLD)')
            code=code.replace('"[target.opacity]|[target_tile_x],[target_tile_y]|[tx],[ty]"','(target.opacity,target_tile_x,target_tile_y,tx,ty)')
            f=A.project(head+'\n'+code,'/datum/los_context/proc/'+name,'self, '+args,env)
            return lambda *a:f(context,*a)
        context.viewport_radii=method('viewport_radii','',['viewport','owner'])
        opaque=set();visited=[]
        def locate(x,y,z):
            visited.append((x,y));return N(type='/turf/floor',x=x,y=y,z=z,opacity=(x,y) in opaque,contents=[])
        def snapshot():
            S=N(blockers=Cells(),clear_footprints=defaultdict(lambda:None))
            S.index_blockers=lambda:None  # Derived acceleration; flat cells remain authoritative.
            S.blocks_target=lambda tx,ty,tile_x,tile_y,opacity:any(env['los_target_blocked'](tx,ty,b.cell_x,b.cell_y,tile_x,tile_y,b.tile_x,b.tile_y,opacity) for b in S.blockers)
            return S
        env.update(locate=locate,new_snapshot=snapshot,new_cell=lambda:N())
        capture=method('capture','presentation=False',['body','revision','policy_key','viewport_radii'])
        decision=method('decision_snapshot','target, S, operation="visual"',['body','revision','policy_key'])
        def target(x,y):
            return N(type='/obj/item',x=x,y=y,z=1,step_x=0,step_y=0,opacity=False,alpha=255,invisibility=0,
                     gcDestroyed=False,gc_destroyed=False,loc=N(type='/turf/floor'))
        text=P.fragment(LIFE,'/client/proc/los_prepare_camera_pan(')
        head,code=text.split('\n',1)
        for field in ['view','pixel_x','pixel_y','los_camera_union_until','los_camera_radius_x','los_camera_radius_y','los_dirty']:
            code=re.sub(r'(?<![\w./])'+field+r'\b','self.'+field,code)
        prepare=A.project(head+'\n'+code,'/client/proc/los_prepare_camera_pan','self, target_x, target_y, animation_time, previous_view',env)
        return N(V=context,C=owner,body=body,capture=capture,decision=decision,target=target,opaque=opaque,visited=visited,
                 env=env,prepare=lambda x,y,d,old_view=None:prepare(owner,x,y,d,owner.view if old_view is None else old_view))

    def test_panned_leading_edges_capture_from_real_body_and_keep_intervening_blockers(self):
        for dx,dy in [(3,0),(-3,0),(0,3),(0,-3),(3,3)]:
            m=self.camera(dx*32,dy*32)
            tx,ty=100+(10 if dx>0 else -10 if dx<0 else 0),100+(10 if dy>0 else -10 if dy<0 else 0)
            S=m.capture(True);target=m.target(tx,ty)
            self.assertEqual((S.eye_x,S.eye_y),(100,100))
            self.assertEqual(m.decision(target,S),1)
            self.assertIn((tx,ty),m.visited)
            m.opaque.add((100+(5 if dx>0 else -5 if dx<0 else 0),100+(5 if dy>0 else -5 if dy<0 else 0)))
            self.assertEqual(m.decision(target,m.capture(True)),0)
            m.C.pixel_x=m.C.pixel_y=0
            self.assertEqual(m.decision(target,S),0)  # Pan identity rejects old capture.
            self.assertEqual(m.decision(target,m.capture(True)),0)  # Outside normal view.
        m=self.camera(96,0);m.body.step_x=2
        self.assertEqual(m.capture(False).eye_x,100.0625)
        self.assertEqual(m.capture(True).eye_x,100)

    def test_camera_pan_key_rounding_bounds_and_offset_cadence(self):
        motion=TileMotion();body=N(x=3,y=1,z=1,step_x=0,step_y=0,sight=0,see_invisible=0,
            see_in_dark=2,dir=2,resting=False,lying=False,prone=False,pulling=None)
        owner=N(view=7,perspective=0,pixel_x=0,pixel_y=0,los_camera_union_until=-1,los_camera_radius_x=0,los_camera_radius_y=0)
        key=motion.render_key(body,owner,True);owner.pixel_x=96
        self.assertNotEqual(motion.render_key(body,owner,True),key)
        key=motion.render_key(body,owner,True);body.step_x=2
        self.assertEqual(motion.render_key(body,owner,True),key)
        for px,pad in [(0,0),(1,1),(-1,1),(32,1),(33,2),(96,3),(1024,32),(4096,128)]:
            self.assertEqual(self.camera(px).V.viewport_radii()[1],7+pad)
        # Panned neighbors use the same expanded bounds for synchronous refresh.
        m=self.camera(96);env=dict(typed_iter=lambda xs,t:xs,list=lambda *a:a,abs=abs)
        near=A.project(LIFE,'/proc/los_movement_affects_context','V, old_turf, new_turf',env)
        self.assertTrue(near(m.V,Tile(116,100),Tile(116,100)))
        self.assertFalse(near(m.V,Tile(117,100),Tile(117,100)))

    def test_pan_radius_and_policy_omission_controls_and_blocker_notifications(self):
        mutant=CORE.replace(' + pan_x','').replace(' + pan_y','')
        m=self.camera(96,source=mutant)
        self.assertEqual(m.decision(m.target(110,100),m.capture(True)),0)
        motion=TileMotion();body=N(x=3,y=1,z=1,step_x=0,step_y=0,sight=0,see_invisible=0,
            see_in_dark=2,dir=2,resting=False,lying=False,prone=False,pulling=None)
        owner=N(view=7,perspective=0,pixel_x=0,pixel_y=0,los_camera_union_until=-1,los_camera_radius_x=0,los_camera_radius_y=0)
        mutant=CORE.replace('|[owner.pixel_x],[owner.pixel_y]','')
        key=motion.render_key(body,owner,True,mutant);owner.pixel_x=96
        self.assertEqual(motion.render_key(body,owner,True,mutant),key)
        m=self.camera(96);events=[]
        m.C.root_tree_presenter=None;m.C.los_presenter=N(invalidate=lambda *a:events.append(a))
        env=dict(CIV13_GEOMETRIC_LOS_CORE=True,los_active_contexts=[m.V],get_turf=lambda a:a,
                 typed_iter=lambda xs,t:xs,abs=abs)
        invalidate=A.project(LIFE,'/proc/los_invalidate','changed, possible_opacity=False',env)
        door=Tile(116,100);invalidate(door,True);self.assertEqual(events,[(door,True)])
        events.clear();m.C.pixel_x=0;invalidate(door,True);self.assertEqual(events,[])

    def test_exit_shrink_axis_change_and_rapid_toggle_retain_previous_animation_extents(self):
        m=self.camera(96);m.prepare(0,0,2);m.C.pixel_x=0
        for time in [0,1,2,3]:
            m.env['world'].time=time
            self.assertEqual(m.V.viewport_radii()[1],10,time)
            m.visited.clear();S=m.capture(True);self.assertEqual(S.radius_x,10)
            self.assertIn((110,100),m.visited)
        m.opaque.add((105,100))
        self.assertEqual(m.decision(m.target(110,100),m.capture(True)),0)
        m.env['world'].time=4;self.assertEqual(m.V.viewport_radii()[1],7)
        # Shrinking both zoom/view and pan retains the old full viewport.
        m=self.camera(160);m.C.view=12;m.prepare(32,0,3);m.C.view=7;m.C.pixel_x=32
        self.assertEqual(m.V.viewport_radii()[1],17)
        # A new orthogonal animation must retain both earlier axes and deadline.
        m.env['world'].time=1;m.prepare(0,96,3);m.C.pixel_x=0;m.C.pixel_y=96
        self.assertEqual((m.V.viewport_radii()[1],m.V.viewport_radii()[2]),(17,12))
        m.env['world'].time=2;m.prepare(0,0,2);m.C.pixel_y=0
        self.assertEqual((m.V.viewport_radii()[1],m.V.viewport_radii()[2]),(17,12))
        self.assertEqual(m.C.los_camera_union_until,5)
        m.env['world'].time=5;self.assertEqual(m.V.viewport_radii()[1],17)
        m.env['world'].time=6;self.assertEqual(m.V.viewport_radii()[1],7)
        # A fresh sequence after expiry must not retain ancient extrema.
        m.prepare(32,0,3);m.C.pixel_x=32
        self.assertEqual(m.V.viewport_radii()[1],8)

    def test_animation_lease_expiry_changes_policy_and_each_call_precedes_animate(self):
        motion=TileMotion();body=N(x=3,y=1,z=1,step_x=0,step_y=0,sight=0,see_invisible=0,
            see_in_dark=2,dir=2,resting=False,lying=False,prone=False,pulling=None)
        m=self.camera(96);m.C.perspective=0;m.prepare(0,0,2);m.C.pixel_x=0
        active=motion.render_key(body,m.C,True,time=3)
        expired=motion.render_key(body,m.C,True,time=4)
        self.assertNotEqual(active,expired)
        for field in ['los_camera_radius_x','los_camera_radius_y','los_camera_union_until']:
            self.assertIn('/client/var/tmp/'+field,LIFE)
            self.assertNotIn(field,P.fragment(CORE,'/datum/los_context/proc/retire('))
        body.step_x=2;self.assertEqual(motion.render_key(body,m.C,True,time=3),active)
        mutant=CORE.replace('if (world.time <= owner.los_camera_union_until)','if (FALSE)',1)
        broken=self.camera(96,source=mutant);broken.prepare(0,0,2);broken.C.pixel_x=0
        self.assertEqual(broken.V.viewport_radii()[1],7)  # Old endpoint-only gap.
        look=P.fragment(self.HUMAN,'/mob/living/human/proc/look_into_distance(')
        self.assertEqual(look.count('los_prepare_camera_pan('),3)
        self.assertLess(look.index('var/old_camera_view = user.client.view'),look.index('user.client.view +='))
        for line in look.splitlines():
            if 'animate(user.client,' in line:
                previous=look[:look.index(line)].rstrip().splitlines()[-1]
                self.assertIn('los_prepare_camera_pan(',previous)
                duration=re.search(r'time = (\d+)',line)[1]
                self.assertIn(', '+duration+', old_camera_view)',previous)


if __name__=='__main__':unittest.main()
