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
        context=N(body=actor,owner=owner,retired=False,movement_turf=tile,viewport=lambda:P.DMList([15,15]))
        actor.client=owner;owner.los_context=context
        geometry=P.projected_geometry()
        blocked=P.project(CORE,'/proc/los_target_blocked(',geometry)
        clients=[owner];contexts=Contexts([context])
        for x,z in [(1,1),(100,1),(1,2)]:
            c=N(los_dirty=False,captures=0,masked=False)
            contexts.append(N(body=N(x=x,y=1,z=z),owner=c,viewport=lambda:P.DMList([15,15])))
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

    def render_key(self,body,owner,anchored):
        # Evaluate the actual key template/offset branch, not a separate cache.
        policy=P.fragment(CORE,'/datum/los_context/proc/policy_key(')
        branch=re.search(r'var/offset_key = tile_anchored \? "([^"]*)" : "([^"]*)"',policy)
        self.assertIsNotNone(branch)
        offset_key=branch[1] if anchored else branch[2]
        template=re.search(r'\treturn "([^\n]*)"',policy)[1]
        names=dict(body=body,owner=owner,revision=1,offset_key=offset_key)
        def expression(code):
            if code=='config ? config.disable_fov : 1':return 1
            return eval(code,{'__builtins__':{}},names)
        template=re.sub(r'\\ref\[([^\]]+)\]',lambda m:str(id(expression(m[1]))),template)
        for _ in range(2):
            template=re.sub(r'\[([^\]]+)\]',lambda m:str(expression(m[1])),template)
        return template

    def test_scheduled_identity_ignores_offsets_but_fresh_read_policy_does_not(self):
        body=N(x=3,y=1,z=1,step_x=0,step_y=0,sight=0,see_invisible=0,see_in_dark=2,
               dir=2,resting=False,lying=False,prone=False,pulling=None)
        owner=N(view=7,perspective=0)
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

if __name__=='__main__':unittest.main()
