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
    def __ior__(self,values):
        for v in (values if isinstance(values,(list,tuple)) else [values]) if values is not None else []:
            if not any(v is old for old in self):self.append(v)
        return self

class TileMotion(unittest.TestCase):
    def scene(self,source=LIFE,real_invalidation=False):
        events=[]
        env=dict(CIV13_GEOMETRIC_LOS_CORE=True,abs=abs,list=lambda *a:Contexts(a),
            typed_iter=lambda values,kind:values,ishuman=lambda a:getattr(a,'human',False),
            ismob=lambda a:getattr(a,'mob',False),get_turf=lambda a:a if isinstance(a,Tile) else a.loc,
            los_presentation_exempt=lambda a:False,ismovable=lambda a:not isinstance(a,Tile),
            los_eye_bucket=lambda a:f'{(a.step_x+8)//16*16},{(a.step_y+8)//16*16}',
            los_invalidate=lambda a,possible=False,viewer_refresh=False:(events.append((a,possible)) or Contexts(contexts[:2])))
        before=A.project(source,'/proc/los_invalidate_movement','A',env)
        near=A.project(source,'/proc/los_movement_affects_context','V, old_turf, new_turf',env)
        env['los_movement_affects_context']=near
        after=A.project(source,'/proc/los_refresh_moved_viewer','A, force_refresh=False, previous_contexts=None',env)
        tile=Tile(3)
        actor=N(human=True,mob=True,opacity=False,loc=tile,x=3,y=1,z=1,step_x=0,step_y=0)
        owner=N(los_dirty=False,captures=0,root_tree_presenter=None,los_presenter=None,noted=[])
        owner.los_note_mover=lambda m:owner.noted.append(m)
        context=N(body=actor,owner=owner,retired=False,movement_turf=tile,movement_bucket='0,0',viewport_radii=lambda:P.DMList([7,7]))
        actor.client=owner;owner.los_context=context
        geometry=P.projected_geometry()
        blocked=P.project(CORE,'/proc/los_target_blocked(',geometry)
        clients=[owner];contexts=Contexts([context])
        for x,z in [(1,1),(100,1),(1,2)]:
            c=N(los_dirty=False,captures=0,masked=False,root_tree_presenter=None,los_presenter=None,noted=[])
            c.los_note_mover=lambda m,c=c:c.noted.append(m)
            contexts.append(N(body=N(x=x,y=1,z=z),owner=c,viewport_radii=lambda:P.DMList([7,7])))
            c.los_context=contexts[-1]
            clients.append(c)
        def publish(c,body):
            c.captures+=1;c.los_dirty=False
            if c is not owner:
                # Real geometry with a fixed blocker; image storage is an adapter.
                c.masked=bool(body.z==actor.z and blocked(actor.x-body.x,0,4-body.x,0,
                    actor.x-body.x,0,4-body.x,0,False))
            return True
        for c,v in zip(clients,contexts):
            c.reconcile_geometric_los=lambda c=c,body=v.body:publish(c,body)
        env['los_active_contexts']=contexts
        if real_invalidation:
            env['los_invalidate']=A.project(source,'/proc/los_invalidate',
                'changed, possible_opacity=False, viewer_refresh=False',env)
        return N(actor=actor,owner=owner,context=context,clients=clients,before=before,after=after,events=events,invalidate=env['los_invalidate'])

    def test_offset_pulses_and_failed_moves_do_not_force_capture(self):
        s=self.scene()
        # Pulses inside one half-tile eye step change nothing.
        for offset in [1,2,5,7,0,-2,-7,3]:
            s.before(s.actor);s.actor.step_x=offset;s.after(s.actor)
        self.assertEqual(s.events,[])
        self.assertEqual([c.captures for c in s.clients],[0,0,0,0])

    def test_half_tile_eye_steps_refresh_only_the_moving_viewer(self):
        s=self.scene()
        for offset in [2,4,6,12,13,20,28,30]:
            s.before(s.actor);s.actor.step_x=offset;s.after(s.actor)
        # Buckets 0 -> 16 -> 32: two eye steps per tile, no neighbour refresh.
        self.assertEqual(s.events,[])
        self.assertEqual([c.captures for c in s.clients],[2,0,0,0])
        self.assertEqual(s.context.movement_bucket,'32,0')

    def test_dirty_unchanged_turf_recovers_before_return_without_neighbor_refresh(self):
        s=self.scene();old=s.actor.loc
        s.owner.los_dirty=True
        s.before(s.actor);s.actor.step_x=2;s.after(s.actor)
        self.assertEqual([c.captures for c in s.clients],[1,0,0,0])
        self.assertFalse(s.owner.los_dirty)
        self.assertIs(s.context.movement_turf,old)
        self.assertEqual(s.events,[])
        # Once settled, subsequent transparent offset pulses remain cheap.
        s.actor.step_x=3;s.after(s.actor)
        self.assertEqual(s.owner.captures,1)
        self.assertEqual(len(s.events),0)

    def test_owner_recovery_omission_reproduces_skipped_recovery(self):
        token='if((H.client.los_dirty || eye_moved) && !H.client.reconcile_geometric_los())'
        self.assertEqual(LIFE.count(token),1)
        s=self.scene(LIFE.replace(token,'if(FALSE)',1));s.owner.los_dirty=True
        s.after(s.actor)
        self.assertEqual(s.owner.captures,0)
        self.assertTrue(s.owner.los_dirty)

    def test_real_invalidation_does_not_ping_pong_between_clean_neighbors(self):
        def exercise(source):
            s=self.scene(source,real_invalidation=True)
            other=s.clients[1];body=other.los_context.body
            vars(body).update(human=True,mob=True,opacity=False,loc=Tile(1),
                step_x=0,step_y=0,client=other)
            vars(other.los_context).update(retired=False,movement_turf=body.loc,movement_bucket='0,0')
            s.owner.los_dirty=True
            # 1px pulses stay inside one half-tile eye step.
            for actor in [s.actor,body]*3:
                actor.step_x+=1;s.after(actor)
            return s
        s=exercise(LIFE)
        self.assertEqual([c.captures for c in s.clients],[1,0,0,0])
        self.assertEqual([c.los_dirty for c in s.clients],[False]*4)
        # Frozen rejected one-line strategy: dirty same-turf viewers fall through
        # the global invalidation path, so nearby transparent players wake each other.
        start=LIFE.index('\t\t\tif(!force_refresh && !H.opacity')
        end=LIFE.index('\t\t\tprevious_turf = V.movement_turf',start)
        rejected='\t\t\tif(!force_refresh && !H.opacity && !V.retired && V.body == H && V.owner == H.client && T && V.movement_turf == T && !H.client.los_dirty)\n\t\t\t\treturn\n'
        s=exercise(LIFE[:start]+rejected+LIFE[end:])
        self.assertEqual([c.captures for c in s.clients],[3,3,0,0])
        self.assertEqual([c.los_dirty for c in s.clients],[True,False,False,False])

    def test_real_opaque_and_turf_invalidation_still_reach_nearby_contexts(self):
        s=self.scene(real_invalidation=True)
        s.actor.opacity=True;s.after(s.actor)
        self.assertEqual([c.captures for c in s.clients],[1,1,0,0])
        self.assertEqual([c.los_dirty for c in s.clients],[False]*4)
        s=self.scene(real_invalidation=True)
        affected=s.invalidate(Tile(3),True)
        self.assertEqual([v.owner for v in affected],s.clients[:2])
        self.assertEqual([c.los_dirty for c in s.clients],[True,True,False,False])

    def test_dirty_same_turf_failed_reconciliation_stays_withdrawn(self):
        # Reconcile supplies admission/capture decisions. A failed or suspended
        # call must not turn this recovery path into retention of stale images.
        for result in [False,None]:
            s=self.scene();withdrawals=[];calls=[]
            s.owner.los_dirty=True
            s.owner.root_tree_presenter=N(invalidate=lambda:withdrawals.append('root'))
            s.owner.los_presenter=N(invalidate=lambda:withdrawals.append('fallback'))
            def reconcile():
                calls.append('reconcile');return result
            s.owner.reconcile_geometric_los=reconcile
            s.after(s.actor)
            self.assertEqual(calls,['reconcile'])
            self.assertEqual(withdrawals,['root','fallback'])
            self.assertTrue(s.owner.los_dirty)
            self.assertEqual([c.captures for c in s.clients],[0,0,0,0])

    def test_dirty_recovery_keeps_existing_admission_and_suspension_gates(self):
        # Source contracts only: eye changes and suspension are still decided
        # by normal reconciliation, not by a new optimistic publication path.
        eligible=P.fragment(CORE,'/datum/los_context/proc/eligible(')
        self.assertIn('owner.eye == body',eligible)
        reconcile=P.fragment(LIFE,'/client/proc/reconcile_geometric_los(')
        self.assertIn('V.mutations.len',reconcile)
        self.assertIn('persistence_active_operation.kind != "save"',reconcile)
        self.assertLess(reconcile.index('V.mutations.len'),reconcile.index('V.capture(TRUE)'))
        self.assertLess(reconcile.index('if(!key || !mob.hud_used)'),reconcile.index('V.capture(TRUE)'))
        self.assertIn('root_tree_presenter.retire()',reconcile)
        capture_failure=reconcile[reconcile.index('if(!S)'):reconcile.index('var/published')]
        self.assertIn('root_tree_presenter.invalidate()',capture_failure)
        self.assertIn('los_presenter.invalidate()',capture_failure)
        self.assertIn('los_dirty = TRUE',capture_failure)

    def test_tile_transition_refreshes_nearby_hidden_character_before_return(self):
        s=self.scene();old=s.actor.loc
        s.before(s.actor);s.actor.loc=Tile(5);s.actor.x=5;s.after(s.actor)
        self.assertEqual([c.captures for c in s.clients],[1,1,0,0])
        self.assertTrue(s.clients[1].masked)
        self.assertIs(s.context.movement_turf,s.actor.loc)
        # A transparent mover's old tile lost no blocker: no turf invalidation,
        # nearby viewers only re-decide the mover itself.
        self.assertNotIn((old,False),s.events)
        self.assertIn(s.actor,s.clients[1].noted)
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
        self.assertEqual(source.count('los_refresh_moved_viewer(src, TRUE, los_move_contexts)'),2)
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

    def test_opaque_nonclient_movers_refresh_dirty_viewers_before_return(self):
        for kind in ['object','npc']:
            s=self.scene()
            # Project native post-move handling with a stationary viewer. The
            # prior pre-write hook has already withdrawn a canopy conservatively.
            s.actor.human=False;s.actor.mob=kind=='npc';s.actor.client=None
            s.actor.opacity=True;s.owner.los_dirty=True
            s.after(s.actor)
            self.assertEqual(s.owner.captures,1,kind)
            self.assertFalse(s.owner.los_dirty)
        # Omission control reproduces waiting for the scheduled visibility tick.
        begin=LIFE.index('\tif(A.opacity)')
        end=LIFE.index('\tif(!M)',begin)
        s=self.scene(LIFE[:begin]+LIFE[end:])
        s.actor.human=False;s.actor.mob=False;s.actor.opacity=True
        s.owner.los_dirty=True;s.after(s.actor)
        self.assertEqual(s.owner.captures,0)
        self.assertTrue(s.owner.los_dirty)

    def test_every_failed_viewer_publication_revokes_deferred_trees(self):
        for result in [False,None]:
            s=self.scene();withdrawals=[]
            s.owner.root_tree_presenter=N(invalidate=lambda:withdrawals.append('root'))
            s.owner.los_presenter=N(invalidate=lambda:withdrawals.append('fallback'))
            s.owner.reconcile_geometric_los=lambda:result
            s.actor.loc=Tile(5);s.actor.x=5
            s.after(s.actor)
            self.assertEqual(withdrawals,['root','fallback'],result)

    def test_opaque_refresh_retains_old_neighborhood_but_not_unrelated_dirty_clients(self):
        s=self.scene();s.actor.human=False;s.actor.mob=False;s.actor.client=None
        s.actor.opacity=True
        # Current invalidation adapter returns only owner+nearby viewer. The old
        # hook supplies a third context reached before a distant teleport.
        for c in s.clients:c.los_dirty=True
        old_context=s.clients[2].los_context
        s.after(s.actor,True,Contexts([old_context]))
        self.assertEqual([c.captures for c in s.clients],[1,1,1,0])
        self.assertTrue(s.clients[3].los_dirty)
        # Retired/replaced context references cannot refresh a replacement owner.
        s=self.scene();s.actor.human=False;s.actor.mob=False;s.actor.opacity=True
        old=s.clients[2].los_context;s.clients[2].los_context=object()
        s.clients[2].los_dirty=True;s.after(s.actor,True,Contexts([old]))
        self.assertEqual(s.clients[2].captures,0)
        # Omit the old endpoint union: its conservative mask remains pending.
        mutant=LIFE.replace('affected |= previous_contexts','affected |= list()',1)
        s=self.scene(mutant);s.actor.human=False;s.actor.mob=False;s.actor.opacity=True
        s.clients[2].los_dirty=True
        s.after(s.actor,True,Contexts([s.clients[2].los_context]))
        self.assertEqual(s.clients[2].captures,0)

    def test_movement_frames_pass_invalidation_contexts_through_native_callbacks(self):
        movable=(ROOT/'code/game/atoms_movable.dm').read_text()
        movement=(ROOT/'code/game/mob/mob_movement.dm').read_text()
        self.assertEqual(movement.count('los_move_contexts = los_invalidate_movement(src)'),1)
        self.assertEqual(movement.count('los_refresh_moved_viewer(src, FALSE, los_move_contexts)'),3)
        self.assertEqual(movable.count('los_move_contexts = root_tree_invalidate(src)'),2)
        self.assertEqual(movable.count('los_refresh_moved_viewer(src, TRUE, los_move_contexts)'),2)
        atom=(ROOT/'code/datums/observation/moved.dm').read_text()
        self.assertIn('los_invalidate(am)',atom)  # Native Entered remains conservative.

    def test_refused_move_has_no_visibility_effect_even_with_los_enabled(self):
        movement=(ROOT/'code/game/mob/mob_movement.dm').read_text()
        body=P.fragment(movement,'/atom/movable/Move(').splitlines()[1:]
        body='\n'.join(body)
        body=body[:body.index('\tvar/datum/subtile_pull_pair')]
        code='/proc/admit_move(newloc)\n'+body+'\treturn TRUE\n'
        for admitted in [False,True]:
            events=[]
            def admit(actor,destination):
                events.append('admit');return admitted
            env=dict(src=object(),persistence_movement_allowed=admit,
                     los_invalidate_movement=lambda actor:events.append('invalidate'))
            f=A.project(code,'/proc/admit_move','newloc',env,
                        defines={'CIV13_ROOT_TREE_PRESENTATION':True})
            self.assertEqual(bool(f(object())),admitted)
            self.assertEqual(events,['admit','invalidate'] if admitted else ['admit'])

    def render_key(self,body,owner,anchored,source=CORE,time=0):
        # Evaluate the actual key template/offset branch, not a separate cache.
        policy=P.fragment(source,'/datum/los_context/proc/policy_key(')
        branch=re.search(r'var/offset_key = tile_anchored \? "([^"]*)" : "([^"]*)"',policy)
        self.assertIsNotNone(branch)
        offset_key=branch[1] if anchored else branch[2]
        template=re.search(r'\treturn "([^\n]*)"',policy)[1]
        names=dict(body=body,owner=owner,revision=1,offset_key=offset_key,world=N(time=time),
                   los_eye_bucket=lambda b:f'{(b.step_x+8)//16*16},{(b.step_y+8)//16*16}')
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
        body.step_x=3;body.step_y=2
        # Inside one half-tile eye step the scheduled identity holds.
        self.assertEqual(self.render_key(body,owner,True),presentation)
        self.assertNotEqual(self.render_key(body,owner,False),physical)
        body.step_x=12
        self.assertNotEqual(self.render_key(body,owner,True),presentation)
        body.step_x=0;body.step_y=0
        body.x+=1
        self.assertNotEqual(self.render_key(body,owner,True),presentation)
        self.assertIn('return policy_key(TRUE)',P.fragment(CORE,'/datum/los_context/proc/presentation_key('))
        self.assertIn('var/key = V.presentation_key()',LIFE)
        self.assertNotIn('var/key = V.policy_key()',LIFE)

    def test_authorization_remains_fresh_physical_and_presentation_explicit(self):
        capture=P.fragment(CORE,'/datum/los_context/proc/capture(')
        decision=P.fragment(CORE,'/datum/los_context/proc/decision_snapshot(')
        read=P.fragment(CORE,'/datum/los_context/proc/decision(')
        self.assertIn('capture(presentation = FALSE, atom/focus = null)',capture)
        self.assertIn('if (focus && !presentation && focus.z == S.eye_z)',capture)
        self.assertIn('if (presentation)\n\t\tS.eye_x = body.x + los_eye_quantized(body.step_x) / 32',capture)
        self.assertIn('else\n\t\tS.eye_x = body.x + body.step_x / 32\n\t\tS.eye_y = body.y + body.step_y / 32',capture)
        self.assertIn('(!S.presentation || !ishuman(target))',decision)
        self.assertIn('capture(FALSE, focus)',read)
        self.assertIn('S.policy != policy_key()',decision)
        self.assertIn('V.capture(TRUE)',LIFE)
        self.assertIn('los_next_audit = world.time + 10',LIFE)
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

    def camera(self,pan_x=0,pan_y=0,source=CORE,lifecycle=LIFE):
        import math
        from collections import defaultdict
        class Cells(P.DMList):
            def __iadd__(self,x):self.append(x);return self
            @property
            def len(self):return len(self)
        body=N(type='/mob/living/human',x=100,y=100,z=1,step_x=0,step_y=0,see_invisible=25)
        owner=N(view=7,pixel_x=pan_x,pixel_y=pan_y,los_camera_union_until=-1,los_camera_radius_x=0,los_camera_radius_y=0,los_camera_pan_x=0,los_camera_pan_y=0)
        context=N(body=body,owner=owner,revision=1,policy_key=lambda:f'{owner.pixel_x},{owner.pixel_y}',
                  verified_snapshot=None,verified_snapshot_time=-1,
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
        borders=None
        if '/datum/los_snapshot/proc/opaque_borders_visible(' in source:
            text=P.fragment(source,'/datum/los_snapshot/proc/opaque_borders_visible(')
            head,code=text.split('\n',1)
            for field in ['blocking_tiles','blockers','radius_x','radius_y','clear_footprints','blocks_target']:
                code=re.sub(r'(?<![\w./])'+field+r'\b','self.'+field,code)
            code=re.sub(r'for \(var/(d[xy]) = -1, \1 <= 1, \1\+\+\)',r'for (var/\1 in inclusive_range(-1, 1))',code)
            code=code.replace('self.blocking_tiles = list()','self.blocking_tiles = none_map()')
            code=code.replace('"[B.tile_x],[B.tile_y]"','(B.tile_x, B.tile_y)').replace('"[nx],[ny]"','(nx, ny)')
            code=code.replace('"0|[nx],[ny]|[nx],[ny]"','(0, nx, ny, nx, ny)')
            env['none_map']=lambda:defaultdict(lambda:None)
            borders=A.project(head+'\n'+code,'/datum/los_snapshot/proc/opaque_borders_visible','self, target_tile_x, target_tile_y',env)
        def snapshot():
            S=N(blockers=Cells(),clear_footprints=defaultdict(lambda:None),blocking_tiles=None)
            if borders:S.opaque_borders_visible=lambda x,y:borders(S,x,y)
            S.index_blockers=lambda:None  # Derived acceleration; flat cells remain authoritative.
            S.blocks_target=lambda tx,ty,tile_x,tile_y,opacity:any(env['los_target_blocked'](tx,ty,b.cell_x,b.cell_y,tile_x,tile_y,b.tile_x,b.tile_y,opacity) for b in S.blockers)
            return S
        env.update(locate=locate,new_snapshot=snapshot,new_cell=lambda:N())
        capture=method('capture','presentation=False, focus=None',['body','revision','policy_key','viewport_radii'])
        decision=method('decision_snapshot','target, S, operation="visual"',['body','revision','policy_key','verified_snapshot_time','verified_snapshot'])
        def target(x,y):
            return N(type='/obj/item',x=x,y=y,z=1,step_x=0,step_y=0,opacity=False,alpha=255,invisibility=0,
                     gcDestroyed=False,gc_destroyed=False,loc=N(type='/turf/floor'))
        text=P.fragment(lifecycle,'/client/proc/los_prepare_camera_pan(')
        head,code=text.split('\n',1)
        for field in ['view','pixel_x','pixel_y','los_camera_union_until','los_camera_radius_x','los_camera_radius_y','los_camera_pan_x','los_camera_pan_y','los_dirty']:
            code=re.sub(r'(?<![\w./])'+field+r'\b','self.'+field,code)
        prepare=A.project(head+'\n'+code,'/client/proc/los_prepare_camera_pan','self, target_x, target_y, animation_time, previous_view',env)
        return N(V=context,C=owner,body=body,capture=capture,decision=decision,target=target,opaque=opaque,visited=visited,
                 env=env,prepare=lambda x,y,d,old_view=None:prepare(owner,x,y,d,owner.view if old_view is None else old_view))

    def test_renderer_pass_checks_policy_once_and_only_for_its_own_live_snapshot(self):
        m=self.camera()
        calls=[]
        real_key=m.V.policy_key
        def counted():
            calls.append(1);return real_key()
        m.V.policy_key=counted
        def method(name,args):
            text=P.fragment(CORE,'/datum/los_context/proc/'+name+'(')
            head,code=text.split('\n',1)
            for field in ['revision','policy_key','verified_snapshot_time','verified_snapshot']:
                code=re.sub(r'(?<![\w./])'+field+r'\b','self.'+field,code)
            f=A.project(head+'\n'+code,'/datum/los_context/proc/'+name,'self'+(', '+args if args else ''),m.env)
            return lambda *a:f(m.V,*a)
        begin,end=method('begin_snapshot_pass','S'),method('end_snapshot_pass','')
        S=m.capture(True);targets=[m.target(100+dx,100+dy) for dx in range(-4,5) for dy in range(-4,5) if max(abs(dx),abs(dy))>=2]
        calls.clear()
        self.assertTrue(begin(S))
        self.assertEqual([m.decision(t,S) for t in targets],[1]*len(targets))
        self.assertEqual(len(calls),1)
        # Another snapshot, a later tick or an ended pass still check fresh.
        other=m.capture(True);calls.clear()
        m.decision(targets[0],other);self.assertEqual(len(calls),1)
        m.env['world'].time+=1;calls.clear()
        m.decision(targets[0],S);self.assertEqual(len(calls),1)
        m.env['world'].time-=1;end();calls.clear()
        m.decision(targets[0],S);self.assertEqual(len(calls),1)
        # A pass cannot start on a snapshot whose policy or revision is stale.
        m.C.pixel_x=32
        self.assertFalse(begin(S));self.assertIsNone(m.V.verified_snapshot)
        self.assertEqual(m.decision(targets[0],S),0)
        m.C.pixel_x=0;m.V.revision+=1
        self.assertFalse(begin(S));self.assertEqual(m.decision(targets[0],S),0)

    def test_both_renderers_end_the_pass_before_their_publication_recheck(self):
        presenter=(ROOT/'code/modules/visibility/los_presenter.dm').read_text()
        tree=(ROOT/'code/modules/visibility/root_tree_presenter.dm').read_text()
        for source,start in [(presenter,'/datum/los_presenter/proc/refresh('),(tree,'/datum/root_tree_presenter/proc/refresh(')]:
            body=P.fragment(source,start)
            begin=body.index('context.begin_snapshot_pass(S)')
            first=body.index('decision_snapshot(')
            end=body.index('context.end_snapshot_pass()')
            recheck=body.index('S.policy != context.policy_key() || S.revision != context.revision')
            self.assertLess(begin,first);self.assertLess(end,recheck)
            self.assertNotIn('sleep(',body[begin:end]);self.assertNotIn('return',body[begin:end])
        self.assertIn('end_snapshot_pass()',P.fragment(CORE,'/datum/los_context/proc/retire('))

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

    def reach_world(self,source=CORE):
        # Real click reach: turf/movable Adjacent() and ClickCross() are projected
        # from code/_onclick/adjacent.dm, then los_reach_admits() from the core.
        m=self.camera(source=source)
        adjacent=(ROOT/'code/_onclick/adjacent.dm').read_text()
        def one_liners(text):
            return re.sub(r'^(\t*)if \((.*)\) (return \w+|continue)$',lambda g:g[1]+'if ('+g[2]+')\n'+g[1]+'\t'+g[3],text,flags=re.M)
        grid={}
        class Turf:
            type='/turf/floor'
            def __init__(self,x,y):self.x,self.y,self.z=x,y,1;self.opacity=self.density=False;self.contents=[]
            def Adjacent(self,neighbor,target=None):return turf_adjacent(self,neighbor,target)
            def ClickCross(self,target_dir,border_only,target_atom=None):return click_cross(self,target_dir,border_only,target_atom)
        class Obj:
            def __init__(self,kind,T,opaque=False,dense=False):
                self.type,self.loc,self.opacity,self.density=kind,T,opaque,dense
                self.x,self.y,self.z=T.x,T.y,T.z;self.locs=[T];T.contents.append(self)
                self.flags=0;self.throwpass=False;self.dir=2;self.step_x=self.step_y=0
                self.alpha=255;self.invisibility=0;self.gcDestroyed=self.gc_destroyed=False
            def Adjacent(self,neighbor):return movable_adjacent(self,neighbor)
        def turf(x,y):
            if (x,y) not in grid:grid[x,y]=Turf(x,y)
            return grid[x,y]
        def wall(x,y):
            T=turf(x,y);T.type='/turf/wall';T.opacity=T.density=True
        def get_dir(a,b):
            dx,dy=b.x-a.x,b.y-a.y
            return (1 if dy>0 else 2 if dy<0 else 0)|(4 if dx>0 else 8 if dx<0 else 0)
        def get_step(T,d):
            return turf(T.x+(1 if d&4 else -1 if d&8 else 0),T.y+(1 if d&1 else -1 if d&2 else 0))
        def typed_iter(xs,kind):
            xs=getattr(xs,'contents',xs)
            if kind in ('/atom','/atom/movable'):return [a for a in xs if not a.type.startswith('/turf/')]
            return [a for a in xs if a.type.startswith(kind)]
        isturf=lambda a:a is not None and a.type.startswith('/turf/')
        env=dict(get_turf=lambda a:a if isturf(a) else a.loc,get_dist=lambda a,b:max(abs(a.x-b.x),abs(a.y-b.y)),
                 get_dir=get_dir,get_step=get_step,typed_iter=typed_iter,isturf=isturf,isnull=lambda a:a is None,
                 istype=lambda a,t=None:False,dm_list=lambda *a:list(a),ON_BORDER=512)
        env['list']=env['dm_list']
        bare=lambda text,names:re.sub(r'(?<![\w.])('+'|'.join(names)+r')\b(?!\s*=[^=])',r'src.\1',text)
        T_adj=bare(one_liners(P.fragment(adjacent,'/turf/Adjacent(')),['x','y','z']).replace('src.ClickCross','ClickCross')
        T_adj=re.sub(r'(?<![\w.])ClickCross\(','src.ClickCross(',T_adj)
        turf_adjacent=A.project(T_adj,'/turf/Adjacent','src, neighbor, target=None',env)
        click_cross=A.project(one_liners(P.fragment(adjacent,'/turf/proc/ClickCross(')),'/turf/proc/ClickCross','src, target_dir, border_only, target_atom=None',env)
        M_adj=bare(one_liners(P.fragment(adjacent,'/atom/movable/Adjacent(')),['loc','locs'])
        movable_adjacent=A.project(M_adj,'/atom/movable/Adjacent','src, neighbor',env)
        env['locate']=lambda x,y,z:turf(x,y)
        env['los_turf_blocks_sight']=A.project(source,'/proc/los_turf_blocks_sight','T, ignore=None',env) if '/proc/los_turf_blocks_sight(' in source else None
        reach=A.project(source,'/proc/los_reach_admits','body, target',env)
        calls=[]
        def spy(body,target):calls.append((target.x,target.y));return reach(body,target)
        m.env['los_reach_admits']=spy
        m.env['locate']=lambda x,y,z:turf(x,y)
        m.env['root_tree_family']=lambda a:False
        m.body.loc=turf(100,100)
        both=lambda target:[m.decision(target,m.capture(presentation)) for presentation in (True,False)]
        return N(m=m,turf=turf,wall=wall,Obj=Obj,reach=reach,calls=calls,both=both)

    WALL_FACE='if (target.opacity && !outside_view && !tree_presentation && !root_tree_family(target) && S.opaque_borders_visible(target_tile_x, target_tile_y))'

    def wall_world(self,source=CORE,walls=()):
        m=self.camera(source=source);m.env['root_tree_family']=lambda a:False
        m.opaque.update(walls)
        def wall(x,y):
            return N(type='/turf/wall',x=x,y=y,z=1,step_x=0,step_y=0,opacity=True,alpha=255,invisibility=0,
                     gcDestroyed=False,gc_destroyed=False,loc=None)
        both=lambda target:[m.decision(target,m.capture(presentation)) for presentation in (True,False)]
        return N(m=m,wall=wall,both=both)

    def test_wall_faces_bounding_visible_ground_render_like_native(self):
        legacy=CORE.replace(self.WALL_FACE,'if (FALSE)')
        self.assertNotEqual(legacy,CORE)
        row=[(x,103) for x in range(93,108)]
        back=[(x,104) for x in range(93,108)]
        # A long straight wall: grazing rays to far segments cross the nearer
        # segments, but each face borders open ground the viewer can see.
        far=[(106,103),(107,103),(93,103)]
        seen={}
        for source in (CORE,legacy):
            w=self.wall_world(source,row+back)
            seen[source]=[w.both(w.wall(x,y)) for x,y in far]
            self.assertEqual(w.both(w.wall(100,103)),[2,2])  # Faced head-on either way.
            # The second course of wall and anything beyond stay hidden.
            for x in (100,106):self.assertEqual(w.both(w.wall(x,104)),[0,0])
            self.assertEqual(w.both(w.m.target(106,105)),[0,0])
        self.assertTrue(all(r==[2,2] for r in seen[CORE]),seen[CORE])
        self.assertIn([0,0],seen[legacy])  # Control: the old ray test hid them.

    def test_room_inner_corner_renders_and_outside_stays_hidden(self):
        legacy=CORE.replace(self.WALL_FACE,'if (FALSE)')
        # 9x7 room interior 96..104 x 97..103, walls one tile outside it.
        walls={(x,y) for x in range(95,106) for y in (96,104)}|{(x,y) for y in range(96,105) for x in (95,105)}
        seen={}
        for source in (CORE,legacy):
            w=self.wall_world(source,walls)
            seen[source]=[w.both(w.wall(x,y)) for x,y in [(105,104),(95,96),(105,96),(95,104)]]
            self.assertEqual(w.both(w.m.target(107,100)),[0,0])  # Outside the room.
            self.assertEqual(w.both(w.wall(106,100)),[0,0])  # Wall behind a wall.
        self.assertTrue(all(r==[2,2] for r in seen[CORE]),seen[CORE])
        self.assertIn([0,0],seen[legacy])

    def test_wall_face_needs_a_visible_open_neighbour(self):
        # A wall whose open neighbours are all behind other walls stays hidden.
        w=self.wall_world(walls=[(x,102) for x in range(90,111)]+[(100,105)])
        self.assertEqual(w.both(w.wall(100,105)),[0,0])

    def test_reachable_diagonal_beside_a_wall_stays_rendered(self):
        legacy=CORE.replace('if (abs(target_tile_x) < 2 && abs(target_tile_y) < 2 && los_reach_admits(body, target))','if (FALSE)')
        self.assertNotEqual(legacy,CORE)
        for source,expected in [(CORE,[1,1]),(legacy,[0,0])]:
            w=self.reach_world(source);w.wall(101,100)
            item=w.Obj('/obj/item',w.turf(101,101))
            # Real Adjacent() reaches past one wall; the closed corner rule did not.
            self.assertTrue(item.Adjacent(w.m.body))
            self.assertEqual(w.both(item),expected)
        # Both shared cardinals walled: unreachable, so the corner stays hidden.
        w=self.reach_world();w.wall(101,100);w.wall(100,101)
        item=w.Obj('/obj/item',w.turf(101,101))
        self.assertFalse(item.Adjacent(w.m.body))
        self.assertEqual(w.both(item),[0,0])
        # Closed curtains (opaque, non-dense) on both shared cardinals: Adjacent()
        # still reaches through them, but touch must not see past that corner.
        w=self.reach_world()
        for x,y in [(101,100),(100,101)]:w.Obj('/obj/structure/curtain',w.turf(x,y),opaque=True)
        item=w.Obj('/obj/item',w.turf(101,101))
        self.assertTrue(item.Adjacent(w.m.body))
        self.assertFalse(w.reach(w.m.body,item))
        self.assertEqual(w.both(item),[0,0])
        # One curtain, one open cardinal: the ordinary reachable-corner case.
        w=self.reach_world();w.Obj('/obj/structure/curtain',w.turf(101,100),opaque=True)
        self.assertEqual(w.both(w.Obj('/obj/item',w.turf(101,101))),[1,1])
        # Two tiles away is never a reach candidate, even past the same corner.
        w=self.reach_world();w.wall(101,100)
        w.both(w.Obj('/obj/item',w.turf(102,101)));self.assertEqual(w.calls,[])

    def test_reach_preserves_destination_occlusion(self):
        # A closed door (opaque, dense) beside a wall corner. The door itself is
        # touchable, so it renders; foreign contents on its tile stay hidden.
        w=self.reach_world();w.wall(101,100)
        door=w.Obj('/obj/structure/door',w.turf(101,101),opaque=True,dense=True)
        item=w.Obj('/obj/item',w.turf(101,101))
        self.assertTrue(item.Adjacent(w.m.body))
        self.assertFalse(w.reach(w.m.body,item))
        self.assertTrue(w.reach(w.m.body,door))
        self.assertEqual(w.both(item),[0,0])
        self.assertEqual(w.both(door),[2,2])
        # Opaque destination turf: contents keep the ordinary decision too.
        w=self.reach_world();w.wall(101,100);w.wall(101,101)
        self.assertFalse(w.reach(w.m.body,w.Obj('/obj/item',w.turf(101,101))))
        # Cardinal neighbour sharing a closed door's tile: reach declines, and
        # the decision is exactly the pre-change geometric one.
        legacy=CORE.replace('if (abs(target_tile_x) < 2 && abs(target_tile_y) < 2 && los_reach_admits(body, target))','if (FALSE)')
        seen=[]
        for source in (CORE,legacy):
            w=self.reach_world(source);T=w.turf(101,100)
            w.Obj('/obj/structure/door',T,opaque=True,dense=True)
            item=w.Obj('/obj/item',T)
            if source is CORE:self.assertFalse(w.reach(w.m.body,item))
            seen.append(w.both(item))
        self.assertEqual(seen[0],seen[1])

    def test_viewer_inside_a_curtain_keeps_its_sight_policy(self):
        # Standing on a closed curtain (opaque, non-dense): Adjacent() ignores
        # it, but the viewer's own blocker still hides neighbours, as before.
        legacy=CORE.replace('if (abs(target_tile_x) < 2 && abs(target_tile_y) < 2 && los_reach_admits(body, target))','if (FALSE)')
        for x,y in [(101,100),(101,101)]:
            seen=[]
            for source in (CORE,legacy):
                w=self.reach_world(source)
                w.Obj('/obj/structure/curtain',w.turf(100,100),opaque=True)
                item=w.Obj('/obj/item',w.turf(x,y))
                self.assertTrue(item.Adjacent(w.m.body))
                if source is CORE:self.assertFalse(w.reach(w.m.body,item))
                seen.append(w.both(item))
            self.assertEqual(seen,[[0,0],[0,0]])
        # An opaque body is not its own blocker.
        w=self.reach_world();w.wall(101,100);w.m.body.opacity=True;w.m.body.contents=[]
        w.turf(100,100).contents.append(w.m.body)
        self.assertTrue(w.reach(w.m.body,w.Obj('/obj/item',w.turf(101,101))))

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
        m=self.camera(96);env=dict(typed_iter=lambda xs,t:xs,list=lambda *a:Contexts(a),abs=abs)
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
        m.C.root_tree_presenter=None;m.C.los_presenter=N(invalidate=lambda changed,possible,viewer_refresh=False:events.append((changed,possible)))
        env=dict(CIV13_GEOMETRIC_LOS_CORE=True,los_active_contexts=[m.V],get_turf=lambda a:a,
                 typed_iter=lambda xs,t:xs,abs=abs,los_presentation_exempt=lambda a:False,
                 ismovable=lambda a:not isinstance(a,Tile))
        env['list']=Contexts
        invalidate=A.project(LIFE,'/proc/los_invalidate','changed, possible_opacity=False, viewer_refresh=False',env)
        door=Tile(116,100);affected=invalidate(door,True);self.assertEqual(events,[(door,True)])
        self.assertEqual(affected,[m.V])
        events.clear();m.C.pixel_x=0;affected=invalidate(door,True);self.assertEqual(events,[])
        self.assertEqual(affected,[])

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
        self.assertEqual((m.V.viewport_radii()[1],m.V.viewport_radii()[2]),(17,15))
        m.env['world'].time=2;m.prepare(0,0,2);m.C.pixel_y=0
        self.assertEqual((m.V.viewport_radii()[1],m.V.viewport_radii()[2]),(17,15))
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
        mutant=CORE.replace('if (world.time <= owner.los_camera_union_until)','if (FALSE)')
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

    def test_growing_view_combines_previous_pan_and_active_lease_with_new_viewport(self):
        m=self.camera(96);m.C.view=12;m.prepare(0,96,3,7)
        m.C.pixel_x=0;m.C.pixel_y=96
        self.assertEqual((m.V.viewport_radii()[1],m.V.viewport_radii()[2]),(15,15))
        S=m.capture(True);self.assertEqual(m.decision(m.target(115,100),S),1)
        m.opaque.add((107,100));self.assertEqual(m.decision(m.target(115,100),m.capture(True)),0)
        # Rapid exit/re-entry: endpoint vars are zero, but the east pan is active.
        m=self.camera(96);m.prepare(0,0,2);m.C.pixel_x=0
        m.env['world'].time=1;m.C.view=12;m.prepare(0,96,3,7);m.C.pixel_y=96
        self.assertEqual((m.V.viewport_radii()[1],m.V.viewport_radii()[2]),(15,15))
        # A view update alone must expand the old in-flight pan's leading edge.
        m=self.camera(96);m.prepare(0,0,2);m.C.pixel_x=0;m.C.view=12
        self.assertEqual(m.V.viewport_radii()[1],15)
        m.env['world'].time=4;self.assertEqual(m.V.viewport_radii()[1],12)

    def test_collapsed_endpoint_radius_witness_misses_growing_view_pan(self):
        # Frozen prior source, not a Git-history dependency or native claim.
        legacy='''/client/proc/los_prepare_camera_pan(target_x, target_y, animation_time, previous_view)
\tvar/list/old_dimensions = getviewsize(previous_view)
\tvar/list/new_dimensions = getviewsize(view)
\tif(!old_dimensions || old_dimensions.len != 2 || !new_dimensions || new_dimensions.len != 2)
\t\treturn
\tvar/old_x = round(old_dimensions[1] / 2) - round(-abs(pixel_x) / 32)
\tvar/old_y = round(old_dimensions[2] / 2) - round(-abs(pixel_y) / 32)
\tvar/new_x = round(new_dimensions[1] / 2) - round(-abs(target_x) / 32)
\tvar/new_y = round(new_dimensions[2] / 2) - round(-abs(target_y) / 32)
\tif(world.time <= los_camera_union_until)
\t\told_x = max(old_x, los_camera_radius_x)
\t\told_y = max(old_y, los_camera_radius_y)
\tlos_camera_radius_x = max(old_x, new_x)
\tlos_camera_radius_y = max(old_y, new_y)
\tlos_camera_union_until = max(los_camera_union_until, world.time + max(0, animation_time) + 1)
\tlos_dirty = TRUE
'''
        m=self.camera(96,lifecycle=legacy);m.C.view=12;m.prepare(0,96,3,7)
        m.C.pixel_x=0;m.C.pixel_y=96
        self.assertEqual(m.V.viewport_radii()[1],12)  # Required extent is15.
        m=self.camera(96,lifecycle=legacy);m.prepare(0,0,2);m.C.pixel_x=0
        m.env['world'].time=1;m.C.view=12;m.prepare(0,96,3,7);m.C.pixel_y=96
        self.assertEqual(m.V.viewport_radii()[1],12)


if __name__=='__main__':unittest.main()
