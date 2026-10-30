"""Execute production no-op/publication decisions; no native FPS assertion."""
from collections import defaultdict
from types import SimpleNamespace as N
import unittest
from test_contract import ROOT, TREE, P, Values, compile_proc, environment

class NoOpRefresh(unittest.TestCase):
    def test_frame_publication_uses_owned_identity_and_withdrawal(self):
        env=environment()
        f=compile_proc(TREE,'/datum/root_tree_presenter/proc/frame_needs_publication(','self, T, frame',env,True)
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
        self.assertIn('published_frames -= I.loc',invalidate)
        release=P.fragment(TREE,'/datum/root_tree_presenter/proc/release_owned_scene(')
        self.assertIn('published_frames.Cut()',release)

    def commit_tail(self,old_invalidation=False):
        source=(ROOT/'code/modules/lighting/lighting_overlay.dm').read_text()
        proc=P.fragment(source,'/atom/movable/lighting_overlay/proc/update_overlay(')
        tail=proc[proc.index('\t// Check against last values'):]
        tail='\n'.join(line for line in tail.splitlines() if not line.strip().startswith('#'))+'\n'
        tail=tail.replace('for (var/i = 1; i <= L.len; i++)','for(var/i = 1, i <= 20, i++)')
        tail=tail.replace('if (','if(')
        if old_invalidation:
            tail=tail.replace('\troot_tree_invalidate(loc)\n','')
            tail='\troot_tree_invalidate(loc)\n'+tail
        code='/proc/commit_light()\n'+tail+'\treturn list(last_color, last_luminosity, color, luminosity)\n'
        calls=[];env=environment();env.update(root_tree_invalidate=lambda loc:calls.append(loc),loc='root')
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

if __name__=='__main__':unittest.main()
