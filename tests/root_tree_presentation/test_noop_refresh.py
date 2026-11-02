"""Execute production no-op/publication decisions; no native FPS assertion."""
from collections import defaultdict
from types import SimpleNamespace as N
import unittest
import importlib.util
from pathlib import Path
_spec = importlib.util.spec_from_file_location('root_noop_contract', Path(__file__).with_name('test_contract.py'))
_contract = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_contract)
ROOT, TREE, P, Values, compile_proc, environment = (_contract.ROOT, _contract.TREE, _contract.P, _contract.Values, _contract.compile_proc, _contract.environment)

class NoOpRefresh(unittest.TestCase):
    def test_frame_publication_uses_owned_identity_and_withdrawal(self):
        env=environment()
        f=compile_proc(TREE,'/datum/root_tree_presenter/proc/frame_needs_publication(','self, T, frame, source_appearance=None',env,True)
        class Atom(N):
            __hash__=object.__hash__
        t=Atom(appearance=object());frame=object()
        r=N(published_frames=defaultdict(lambda:None),source_appearances=defaultdict(lambda:None))
        self.assertTrue(f(r,t,frame))
        r.published_frames[t]=frame;r.source_appearances[t]=t.appearance
        for _ in range(10):self.assertFalse(f(r,t,frame))
        # Image.icon getter identity is deliberately not an input to the guard.
        self.assertNotIn('I.icon',P.fragment(TREE,'/datum/root_tree_presenter/proc/frame_needs_publication('))
        self.assertTrue(f(r,t,object()))
        t.appearance=object();self.assertTrue(f(r,t,frame))
        r.source_appearances[t]=t.appearance;r.published_frames.pop(t)
        self.assertTrue(f(r,t,frame))
        invalidate=P.fragment(TREE,'/datum/root_tree_presenter/proc/invalidate(')
        self.assertIn('withdraw_tree(I.loc, I)',invalidate)
        release=P.fragment(TREE,'/datum/root_tree_presenter/proc/release_owned_scene(')
        self.assertIn('published_frames.Cut()',release)

    def test_repeated_withdrawal_writes_only_the_first_live_lease(self):
        class Map(defaultdict):
            def __isub__(self,key):self.pop(key,None);return self
        class Image:
            def __init__(self):self.__dict__.update(writes=[],icon='frame',overlays=['art'],underlays=[],maptext='x',mouse_opacity=1)
            def __setattr__(self,key,value):self.writes.append((key,value));self.__dict__[key]=value
        env=environment();f=compile_proc(TREE,'/datum/root_tree_presenter/proc/withdraw_tree(','self, T, I',env,True)
        tree=object();frame=object();r=N(published_frames=Map(lambda:None,{tree:frame}));im=Image()
        self.assertTrue(f(r,tree,im));self.assertEqual(len(im.writes),5)
        self.assertIsNone(im.icon);self.assertEqual(im.mouse_opacity,0)
        for _ in range(10):self.assertFalse(f(r,tree,im))
        self.assertEqual(len(im.writes),5)
        # Republishing re-arms the immediate first-withdraw obligation.
        r.published_frames[tree]=frame;self.assertTrue(f(r,tree,im));self.assertEqual(len(im.writes),10)
        mutant=TREE.replace('if(!I || !published_frames[T])','if(!I)')
        bad=compile_proc(mutant,'/datum/root_tree_presenter/proc/withdraw_tree(','self, T, I',env,True)
        self.assertTrue(bad(r,tree,im));self.assertEqual(len(im.writes),15)

    def test_frame_input_cache_is_separate_from_publication_and_raw_changes(self):
        env=environment();f=compile_proc(TREE,'/datum/root_tree_presenter/proc/frame_inputs_unchanged(','self, T, rgb, source_appearance',env,True)
        class Atom(N):
            __hash__=object.__hash__
        tree=Atom(dir=2);appearance=object();frame=object()
        r=N(frames=defaultdict(lambda:None),frame_appearances=defaultdict(lambda:None),frame_lights=defaultdict(lambda:None),frame_dirs=defaultdict(lambda:None),published_frames={},source_appearances={})
        self.assertFalse(f(r,tree,'#123456',appearance))
        r.frames[tree]=frame;r.frame_appearances[tree]=appearance;r.frame_lights[tree]='#123456';r.frame_dirs[tree]=tree.dir
        for _ in range(10):self.assertTrue(f(r,tree,'#123456',appearance))
        # Hidden but correctly cached frame is reusable; publication is still a
        # separate decision. Neither a stale publication nor same RGB permits
        # use after an actual source appearance change.
        self.assertFalse(r.published_frames)
        self.assertFalse(f(r,tree,'#654321',appearance))
        self.assertFalse(f(r,tree,'#123456',object()))
        tree.dir=4;self.assertFalse(f(r,tree,'#123456',appearance));tree.dir=2
        r.frames.pop(tree);self.assertFalse(f(r,tree,'#123456',appearance))
        for mutation in [' && frame_appearances[T] == source_appearance',' && frame_lights[T] == rgb']:
            bad=compile_proc(TREE.replace(mutation,''),'/datum/root_tree_presenter/proc/frame_inputs_unchanged(','self, T, rgb, source_appearance',env,True)
            r.frames[tree]=frame
            changed_appearance=object() if 'appearances' in mutation else appearance
            changed_rgb='#123456' if 'appearances' in mutation else '#654321'
            self.assertTrue(bad(r,tree,changed_rgb,changed_appearance))
            self.assertFalse(f(r,tree,changed_rgb,changed_appearance))
        refresh=P.fragment(TREE,'/datum/root_tree_presenter/proc/refresh(')
        self.assertLess(refresh.index('frame_inputs_unchanged'),refresh.index('json_encode(T.color)'))
        for field in ['frame_appearances','frame_lights','frame_dirs']:
            self.assertIn(field+' -= old',refresh)
            self.assertIn(field+'.Cut()',P.fragment(TREE,'/datum/root_tree_presenter/proc/release_owned_scene('))

    def commit_tail(self,old_invalidation=False):
        source=(ROOT/'code/modules/lighting/lighting_overlay.dm').read_text()
        proc=P.fragment(source,'/atom/movable/lighting_overlay/proc/update_overlay(')
        tail=proc[proc.index('\t// Check against last values'):]
        tail='\n'.join(line for line in tail.splitlines() if not line.strip().startswith('#'))+'\n'
        tail=tail.replace('for (var/i = 1; i <= L.len; i++)','for(var/i = 1, i <= 20, i++)')
        tail=tail.replace('if (','if(')
        if old_invalidation:
            tail=tail.replace('\troot_tree_light_changed(loc)\n','')
            tail='\troot_tree_light_changed(loc)\n'+tail
        code='/proc/commit_light()\n'+tail+'\treturn list(last_color, last_luminosity, color, luminosity)\n'
        calls=[];env=environment();env.update(root_tree_light_changed=lambda loc:calls.append(loc),loc='root')
        f=compile_proc(code,'/proc/commit_light(','L, new_luminosity, last_color, last_luminosity',env)
        return f,calls

    def test_identical_light_does_not_invalidate_but_real_commit_does(self):
        f,calls=self.commit_tail()
        old=Values([0.25]*20)
        self.assertIsNone(f(Values(old),True,old,True));self.assertEqual(calls,[])
        result=f(Values([0.5]*20),True,old,True)
        self.assertEqual(calls,['root']);self.assertEqual(result[1],[0.5]*20)
        f,calls=self.commit_tail();f(Values(old),False,old,True)
        self.assertEqual(calls,['root'])
        mutant,calls=self.commit_tail(old_invalidation=True)
        mutant(Values(old),True,old,True);self.assertEqual(calls,['root'])

    def test_one_neighborhood_materialization_for_audit_and_roots(self):
        refresh=P.fragment(TREE,'/datum/root_tree_presenter/proc/refresh(')
        self.assertEqual(refresh.count('range('),1)
        self.assertIn('composition_conflict(S, scene)',refresh)
        self.assertIn('scene_roots(scene)',refresh)
        self.assertLess(refresh.index('if(!roots.len)'),refresh.index('if(!setup_scene())'))


class ViewerPublication(unittest.TestCase):
    def test_root_lease_survives_only_postmove_transparent_viewer_refresh(self):
        env=environment();calls=[]
        env['withdraw_tree']=lambda tree,image:calls.append(tree)
        f=compile_proc(TREE,'/datum/root_tree_presenter/proc/invalidate(',
                       'self, changed=None, possible_opacity=False, viewer_refresh=False',env,True)
        body=N(opacity=False);tree=N(loc=object());image=N(loc=tree)
        r=N(retired=False,owner=N(los_dirty=False),context=N(body=body),owned_images=[image])
        f(r,body,False,True);self.assertEqual(calls,[])
        self.assertTrue(r.owner.los_dirty)
        for changed,opacity,refresh in [(body,False,False),(body,True,True),(None,False,True)]:
            body.opacity=opacity;f(r,changed,False,refresh)
        self.assertEqual(len(calls),3)
        lifecycle=(ROOT/'code/modules/visibility/los_lifecycle.dm').read_text()
        capture=P.fragment(lifecycle,'/client/proc/reconcile_geometric_los(')
        failed=capture[capture.index('if(!S)'):capture.index('var/published = TRUE')]
        self.assertIn('root_tree_presenter.invalidate()',failed)
        self.assertIn('los_presenter.invalidate()',failed)

class PendingLightPublication(unittest.TestCase):
    def snapshot(self):
        env=environment()
        f=compile_proc(_contract.SNAP,'/proc/root_light_mask_snapshot(','root, allow_pending=False',env)
        root=N(type='/turf/floor')
        root.lighting_overlay=N(loc=root,needs_update=True,color=Values([.25]*20),last_color=Values([.25]*20))
        return env,f,root

    def test_pending_queue_uses_only_still_displayed_committed_matrix(self):
        env,f,root=self.snapshot()
        self.assertIsNone(f(root))  # Existing strict callers stay strict.
        self.assertEqual(f(root,True),[.25]*20)
        for case in ['foreign','missing','partial','changed','startup']:
            env,f,root=self.snapshot()
            if case=='foreign':root.lighting_overlay.loc=object()
            if case=='missing':root.lighting_overlay=None
            if case=='partial':root.lighting_overlay.last_color=Values([.25])
            if case=='changed':root.lighting_overlay.color[1]=.5
            if case=='startup':env['lighting_startup_in_progress']=True
            self.assertIsNone(f(root,True),case)

    def test_queue_and_commit_mark_only_owners_without_withdrawing_frames(self):
        env=environment()
        changed=compile_proc(TREE,'/proc/root_tree_light_changed(','root',env)
        root,other=object(),object()
        class Atom(N):__hash__=object.__hash__
        own=N(retired=False,owner=N(los_dirty=False),images={Atom(loc=root):'frame'})
        foreign=N(retired=False,owner=N(los_dirty=False),images={Atom(loc=other):'foreign'})
        env['root_tree_presenters']=_contract.Items([own,foreign])
        for _ in range(10):changed(root)
        self.assertTrue(own.owner.los_dirty)
        self.assertFalse(foreign.owner.los_dirty)
        self.assertEqual(list(own.images.values()),['frame'])
        light=(ROOT/'code/modules/lighting/lighting_overlay.dm').read_text()
        corner=(ROOT/'code/modules/lighting/lighting_corner.dm').read_text()
        self.assertIn('root_tree_light_changed(T)',corner)
        self.assertNotIn('root_tree_invalidate(T)',corner)
        self.assertIn('root_tree_light_changed(loc)',light)
        cached=P.fragment(TREE,'/datum/root_tree_presenter/proc/cached_light(')
        self.assertIn('root_light_mask_snapshot(root, TRUE)',cached)
        self.assertIn('root_light_rgb(root, context.body, TRUE)',cached)

    def test_legacy_queue_rejects_same_committed_pending_mask_control(self):
        env,f,root=self.snapshot()
        old=_contract.SNAP.replace('(owner.needs_update && !allow_pending)','owner.needs_update')
        reject=compile_proc(old,'/proc/root_light_mask_snapshot(','root, allow_pending=False',env)
        self.assertEqual(f(root,True),[.25]*20)
        self.assertIsNone(reject(root,True))

if __name__=='__main__':unittest.main()
