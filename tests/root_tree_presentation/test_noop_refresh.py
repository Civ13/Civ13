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
        code='/proc/commit_light()\n'+tail+'\treturn list(color_committed, last_luminosity, color, luminosity)\n'
        calls=[];env=environment();env.update(root_tree_light_changed=lambda loc:calls.append(loc),loc='root')
        f=compile_proc(code,'/proc/commit_light(','L, new_luminosity, color_committed, color, last_luminosity',env)
        return f,calls

    def test_identical_light_does_not_invalidate_but_real_commit_does(self):
        f,calls=self.commit_tail()
        old=Values([0.25]*20)
        self.assertIsNone(f(Values(old),True,True,old,True));self.assertEqual(calls,[])
        result=f(Values([0.5]*20),True,True,old,True)
        self.assertEqual(calls,['root']);self.assertEqual(result[3],[0.5]*20);self.assertTrue(result[1])
        f,calls=self.commit_tail();f(Values(old),False,True,old,True)
        self.assertEqual(calls,['root'])
        # An overlay that has never committed (pool reset) always commits.
        f,calls=self.commit_tail();f(Values(old),True,False,old,True)
        self.assertEqual(calls,['root'])
        mutant,calls=self.commit_tail(old_invalidation=True)
        mutant(Values(old),True,True,old,True);self.assertEqual(calls,['root'])

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
        root.lighting_overlay=N(loc=root,needs_update=True,color=Values([.25]*20),color_committed=True)
        return env,f,root

    def test_pending_queue_uses_only_still_displayed_committed_matrix(self):
        env,f,root=self.snapshot()
        self.assertIsNone(f(root))  # Existing strict callers stay strict.
        self.assertEqual(f(root,True),[.25]*20)
        for case in ['foreign','missing','partial','changed','startup']:
            env,f,root=self.snapshot()
            if case=='foreign':root.lighting_overlay.loc=object()
            if case=='missing':root.lighting_overlay=None
            if case=='partial':root.lighting_overlay.color=Values([.25])
            if case=='changed':root.lighting_overlay.color_committed=False
            if case=='startup':env['lighting_startup_in_progress']=True
            self.assertIsNone(f(root,True),case)

    def test_queue_and_commit_mark_only_owners_without_withdrawing_frames(self):
        env=environment()
        changed=compile_proc(TREE,'/proc/root_tree_light_changed(','root',env)
        # Turf contents is the native lookup boundary; presenter images are
        # DM associative lists, so a missing key reads as null.
        class Keyed(dict):
            def __getitem__(self,k):return self.get(k)
        class Atom(N):__hash__=object.__hash__
        root,other=N(contents=[]),N(contents=[])
        mine,theirs=Atom(loc=root),Atom(loc=other)
        # Native contents also lists atoms that merely overlap the turf.
        overhang=Atom(loc=other)
        root.contents+=[mine,overhang];other.contents.append(theirs)
        own=N(retired=False,owner=N(los_dirty=False),images=Keyed({mine:'frame'}))
        foreign=N(retired=False,owner=N(los_dirty=False),images=Keyed({theirs:'foreign',overhang:'foreign'}))
        env['root_tree_presenters']=_contract.Items([own,foreign])
        for _ in range(10):changed(root)
        self.assertTrue(own.owner.los_dirty)
        self.assertFalse(foreign.owner.los_dirty)
        self.assertEqual(list(own.images.values()),['frame'])
        # A treeless turf marks nobody, however many presenters exist.
        bare=N(contents=[]);own.owner.los_dirty=False
        changed(bare)
        self.assertFalse(own.owner.los_dirty)
        self.assertFalse(foreign.owner.los_dirty)
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




STRIKE_SOURCE = (ROOT/'code/game/mob/animations.dm').read_text()

class ResourceStrikes(unittest.TestCase):
    """Execute the new ownership/LOS gate and cleanup; not a pixel renderer."""
    class Ref(N):
        __hash__ = object.__hash__
        def __eq__(self, other):
            return self is other

    class Map(defaultdict):
        def __init__(self, values=()):
            super().__init__(lambda: None, values)
        def __getitem__(self, key):
            return self.get(key)
        def copy(self):
            return dict(self)
        def __isub__(self, key):
            self.pop(key, None)
            return self
        def Cut(self):
            self.clear()
        def Copy(self):
            return self.copy()

    class Images(list):
        def __iadd__(self, item):
            self.append(item)
            return self
        def __isub__(self, item):
            if item in self:
                self.remove(item)
            return self

    def subject(self, rgb='#123456'):
        atom = self.Ref(appearance=object())
        worker = self.Ref()
        prototype = self.Ref(appearance=object(), loc=atom)
        producer = self.Ref(target=atom, actor=worker, strike=prototype,
                            strike_appearance=prototype.appearance, valid=lambda: True)
        C = self.Ref(images=self.Images(), los_dirty=False)
        V = self.Ref(root_tree_admitted=lambda t: t is atom,
                     capture=lambda presentation: self.Ref(),
                     decision_snapshot=lambda target, snapshot, operation: 1)
        frame = object()
        P = self.Ref(retired=False, scene_active=True, owner=C, context=V,
                     work_images=self.Map(), owned_images=self.Images(),
                     published_frames=self.Map({atom: frame}),
                     source_appearances=self.Map({atom: atom.appearance}),
                     frame_lights=self.Map({atom: rgb}))
        C.root_tree_presenter, C.los_context = P, V
        env = environment()
        env.update(LOS_DENY=0, planes_admitted=lambda: True,
                   image=lambda appearance, target: self.Ref(appearance=appearance, loc=target,
                       plane=1, color=None, appearance_flags=0, override=False, mouse_opacity=1))
        return atom, worker, producer, P, env

    def gate(self, source=STRIKE_SOURCE):
        # Each subject supplies its own lease oracle and image constructor.
        def run(P, A, overrides=None):
            scope = self.subject()[-1]
            scope.update(overrides or {})
            f = compile_proc(source, '/datum/root_tree_presenter/proc/resource_strike(',
                             'self, A', scope, True)
            return f(P, A)
        return run

    def test_two_viewers_keep_forest_and_root_lighting_during_strike(self):
        T, actor, A, unused, unused_env = self.subject()
        viewers = []
        for rgb in ('#123456', '#c0d0e0'):
            unused_t, unused_actor, unused_a, P, env = self.subject(rgb)
            P.context.root_tree_admitted = lambda target: target is T
            P.published_frames = self.Map({T: object()})
            P.source_appearances = self.Map({T: T.appearance})
            P.frame_lights = self.Map({T: rgb})
            ordinary = object()
            P.owner.images.append(ordinary)
            before = (dict(P.published_frames), dict(P.source_appearances), P.scene_active)
            seen = []
            P.context.decision_snapshot = lambda target, snapshot, operation: seen.append((target, operation)) or 1
            I = self.gate()(P, A)
            self.assertIsNotNone(I)
            self.assertEqual(I.plane, env['ROOT_TREE_PLANE'])
            self.assertEqual(I.color, rgb)
            self.assertFalse(I.override)
            self.assertEqual(I.mouse_opacity, 0)
            self.assertIs(I.loc, T)
            self.assertIs(I.appearance, A.strike_appearance)
            self.assertEqual(seen, [(T, 'visual'), (actor, 'visual')])
            self.assertIn(I, P.owned_images)
            self.assertIs(P.work_images[I], T)
            self.assertIn(ordinary, P.owner.images)
            self.assertEqual(before, (dict(P.published_frames), dict(P.source_appearances), P.scene_active))
            viewers.append((P, I))
        first, first_image = viewers[0]
        second, second_image = viewers[1]
        env = environment()
        remove = compile_proc(TREE, '/datum/root_tree_presenter/proc/remove_work_image(', 'self, I', env, True)
        remove(first, first_image)
        self.assertIn(second_image, second.owner.images)
        self.assertEqual(second_image.color, '#c0d0e0')

    def test_hidden_actor_target_or_unsettled_lease_withholds_only_effect(self):
        changes = [
            lambda T, A, P, e: setattr(P, 'retired', True),
            lambda T, A, P, e: setattr(P, 'scene_active', False),
            lambda T, A, P, e: setattr(P.owner, 'root_tree_presenter', object()),
            lambda T, A, P, e: setattr(P.owner, 'los_context', object()),
            lambda T, A, P, e: setattr(P.owner, 'los_dirty', True),
            lambda T, A, P, e: e.update(planes_admitted=lambda: False),
            lambda T, A, P, e: setattr(A, 'valid', lambda: False),
            lambda T, A, P, e: setattr(A.strike, 'appearance', object()),
            lambda T, A, P, e: setattr(A.strike, 'loc', object()),
            lambda T, A, P, e: setattr(P.context, 'root_tree_admitted', lambda target: False),
            lambda T, A, P, e: P.published_frames.clear(),
            lambda T, A, P, e: setattr(T, 'appearance', object()),
            lambda T, A, P, e: P.frame_lights.clear(),
            lambda T, A, P, e: setattr(P.context, 'capture', lambda presentation: None),
            lambda T, A, P, e: setattr(P.context, 'decision_snapshot', lambda target, snapshot, operation: 0 if target is T else 1),
            lambda T, A, P, e: setattr(P.context, 'decision_snapshot', lambda target, snapshot, operation: 0 if target is A.actor else 1),
            lambda T, A, P, e: P.work_images.update({object(): T for _ in range(64)}),
        ]
        for change in changes:
            T, actor, A, P, env = self.subject()
            change(T, A, P, env)
            before = dict(P.published_frames)
            f = compile_proc(STRIKE_SOURCE, '/datum/root_tree_presenter/proc/resource_strike(', 'self, A', env, True)
            self.assertIsNone(f(P, A), change)
            self.assertFalse(P.owner.images)
            self.assertEqual(before, dict(P.published_frames))

    def test_removing_authorization_or_seal_guards_is_detected(self):
        controls = [
            (' || owner.los_dirty', lambda T, A, P: setattr(P.owner, 'los_dirty', True)),
            (' || A.strike.appearance != A.strike_appearance', lambda T, A, P: setattr(A.strike, 'appearance', object())),
            (' || context.decision_snapshot(A.actor, S, "visual") == LOS_DENY',
             lambda T, A, P: setattr(P.context, 'decision_snapshot', lambda target, snapshot, operation: 0 if target is A.actor else 1)),
            (' || context.decision_snapshot(T, S, "visual") == LOS_DENY',
             lambda T, A, P: setattr(P.context, 'decision_snapshot', lambda target, snapshot, operation: 0 if target is T else 1)),
        ]
        for deleted, change in controls:
            self.assertIn(deleted, STRIKE_SOURCE)
            T, actor, A, P, env = self.subject()
            change(T, A, P)
            self.assertIsNone(self.gate()(P, A))
            self.assertIsNotNone(self.gate(STRIKE_SOURCE.replace(deleted, '', 1))(P, A))

    def test_removal_is_scoped_idempotent_and_all_invalidation_paths_clear_fx(self):
        T, actor, A, P, env = self.subject()
        I = self.gate()(P, A)
        other_root = object()
        other_image = self.Ref()
        P.work_images[other_image] = other_root
        P.owned_images += other_image
        P.owner.images += other_image
        remove = compile_proc(TREE, '/datum/root_tree_presenter/proc/remove_work_image(', 'self, I', env, True)
        env['remove_work_image'] = lambda image: remove(P, image)
        clear = compile_proc(TREE, '/datum/root_tree_presenter/proc/clear_work_images(', 'self, T=None', env, True)
        clear(P, T)
        clear(P, T)
        self.assertNotIn(I, P.owner.images)
        self.assertIn(other_image, P.owner.images)
        self.assertIn(other_image, P.owned_images)
        clear(P)
        self.assertFalse(P.owner.images)
        self.assertFalse(P.work_images)
        invalid = globals()['P'].fragment(TREE, '/datum/root_tree_presenter/proc/invalidate(')
        self.assertLess(invalid.index('clear_work_images()'), invalid.index('if(viewer_refresh'))
        refresh = globals()['P'].fragment(TREE, '/datum/root_tree_presenter/proc/refresh(')
        self.assertLess(refresh.index('clear_work_images(T)'), refresh.index('root_tree_set_frame(I, T, frame)'))
        self.assertIn('clear_work_images(old)', refresh)
        self.assertIn('clear_work_images(T)', globals()['P'].fragment(TREE, '/datum/root_tree_presenter/proc/withdraw_tree('))
        self.assertIn('work_images.Cut()', globals()['P'].fragment(TREE, '/datum/root_tree_presenter/proc/release_owned_scene('))

    def test_foreign_foreground_images_still_fall_back_and_producer_owns_cleanup(self):
        audit = P.fragment(TREE, '/datum/root_tree_presenter/proc/composition_conflict(')
        self.assertNotIn('resource_work_animation', audit)
        self.assertNotIn('work_images', audit)
        self.assertIn('if(presenter_images[I])', audit)
        self.assertIn('"client-owned foreground image"', audit)
        animation = (ROOT/'code/game/mob/animations.dm').read_text()
        show = P.fragment(animation, '/datum/resource_work_animation/proc/show_strike(')
        self.assertLess(show.index('strike_appearance = strike.appearance'), show.index('P.resource_strike(src)'))
        self.assertIn('if (P && P.scene_active && root_tree_family(target))', show)
        self.assertIn('animate(I, alpha = 175', show)
        cleanup = P.fragment(animation, '/datum/resource_work_animation/proc/clear_projected_strikes(')
        self.assertIn('P.remove_work_image(I)', cleanup)
        self.assertIn('C.images -= I', cleanup)
        self.assertIn('projected_strikes.Cut()', cleanup)
        self.assertIn('projection_owners.Cut()', cleanup)
        self.assertIn('clear_projected_strikes()', P.fragment(animation, '/datum/resource_work_animation/proc/clear_strike('))


    def test_actual_foreground_audit_accepts_owned_strike_but_rejects_lookalike(self):
        T, actor, A, presenter, env = self.subject()
        T.z, T.plane, T.layer = 2, 1, 5.11
        I = self.gate()(presenter, A)
        audit = _contract.SceneFallback()
        audit.setUp()
        self.assertIsNone(audit.audit([], presenter.owner.images, presenter.owned_images))
        foreign = audit.appearance(layer=6.11, loc=T)
        self.assertEqual(audit.audit([], [foreign]), 'client-owned foreground image')
        # A foreign image remains rejected even beside our owned projection.
        self.assertEqual(audit.audit([], [I, foreign], presenter.owned_images),
                         'client-owned foreground image')

    def test_producer_cleanup_executes_per_client_and_leaves_unrelated_art(self):
        T, actor, A, first, env = self.subject()
        I = self.gate()(first, A)
        unused_t, unused_actor, unused_a, second, unused_env = self.subject()
        J = self.gate()(second, unused_a)
        unrelated = object()
        first.owner.images.append(unrelated)
        remove = compile_proc(TREE, '/datum/root_tree_presenter/proc/remove_work_image(', 'self, I', env, True)
        first.remove_work_image = lambda image: remove(first, image)
        second.remove_work_image = lambda image: remove(second, image)
        projections = self.Map({first.owner: I, second.owner: J})
        owners = self.Map({first.owner: first, second.owner: second})
        env.update(projected_strikes=projections, projection_owners=owners)
        source = STRIKE_SOURCE.replace('for (', 'for(').replace('if (', 'if(')
        clear = compile_proc(source, '/datum/resource_work_animation/proc/clear_projected_strikes(', '', env)
        clear()
        clear()
        self.assertEqual(first.owner.images, [unrelated])
        self.assertFalse(second.owner.images)
        self.assertFalse(first.work_images)
        self.assertFalse(second.work_images)
        self.assertFalse(projections)
        self.assertFalse(owners)

    def test_transparent_equip_custody_does_not_withdraw_two_viewers_forest(self):
        calls = []
        env = environment()
        env.update(withdraw_tree=lambda tree, image: calls.append(tree),
                   clear_work_images=lambda *args: None)
        invalid = compile_proc(TREE, '/datum/root_tree_presenter/proc/invalidate(',
                               'self, changed=None, possible_opacity=False, viewer_refresh=False', env, True)
        axe = N(opacity=False)
        for owner_body in (object(), object()):
            presenter = N(retired=False, owner=N(los_dirty=False),
                          context=N(body=owner_body), owned_images=[N(loc=object())])
            # forceMove invalidates the transparent item before/after custody;
            # neither recipient body is the changed item.
            invalid(presenter, axe)
            invalid(presenter, axe)
            self.assertTrue(presenter.owner.los_dirty)
        self.assertEqual(calls, [])
        atom_source = (ROOT/'code/game/atoms.dm').read_text()
        self.assertNotIn('los_invalidate', P.fragment(atom_source, '/atom/Entered('))
        inventory = (ROOT/'code/game/mob/living/carbon/human/inventory.dm').read_text()
        equip = P.fragment(inventory, '/mob/living/human/equip_to_slot(')
        self.assertIn('!W.forceMove(src)', equip)
        self.assertNotIn('prepare_resource_work_animation', inventory)
        icons = (ROOT/'code/game/mob/living/carbon/human/update_icons.dm').read_text()
        for hand in ('r', 'l'):
            held = P.fragment(icons, '/mob/living/human/update_inv_'+hand+'_hand(')
            self.assertIn('layer = layer+0.02', held)
        progress = (ROOT/'code/datums/progressbar.dm').read_text()
        self.assertIn('bar.plane = HUD_PLANE', progress)

if __name__=='__main__':unittest.main()
