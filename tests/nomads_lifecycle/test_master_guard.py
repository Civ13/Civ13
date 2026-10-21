"""Real local Git positive/control cases; no external network or checkout reset."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'scripts/nomads-lifecycle'))
from master_guard import verified_master as real_verified_master


def verified_master(*args, **kwargs):
    # These repositories contain only inert Git fixture files, no runtime.
    kwargs.setdefault('mutation_guard', lambda: None)
    return real_verified_master(*args, **kwargs)


class MasterGuardTests(unittest.TestCase):
    def test_clean_master_and_preserved_dirty_pr_offline_controls(self):
        with tempfile.TemporaryDirectory(prefix='master-guard-') as directory:
            root = Path(directory)
            origin, runtime = root/'origin.git', root/'runtime'
            def git(*args):
                return subprocess.check_output(['git','-c','user.name=Fixture','-c','user.email=fixture@example.invalid',*args],stderr=subprocess.STDOUT).decode().strip()
            git('init','--bare',str(origin),'-b','master')
            git('clone',str(origin),str(runtime))
            def local(*args):
                return git('-C',str(runtime),*args)
            source = runtime/'source.txt'
            source.write_text('initial')
            local('add','source.txt')
            local('commit','-m','fixture')
            local('push','origin','master')
            local('remote','set-head','origin','master')
            revision = local('rev-parse','HEAD')
            self.assertEqual(verified_master(runtime,expected_origin=str(origin))['commit'],revision)
            source.write_text('unrelated user edit')
            with self.assertRaisesRegex(RuntimeError,'local changes'):
                verified_master(runtime,expected_origin=str(origin),update=True)
            self.assertEqual(source.read_text(),'unrelated user edit')
            local('add','source.txt')
            local('commit','-m','preserve local work')
            with self.assertRaisesRegex(RuntimeError,'ahead or diverged'):
                verified_master(runtime,expected_origin=str(origin),update=True)
            local('switch','-c','pr')
            with self.assertRaisesRegex(RuntimeError,'branch master'):
                verified_master(runtime,expected_origin=str(origin),update=True)
            local('switch','master')
            origin.rename(root/'offline.git')
            with self.assertRaisesRegex(RuntimeError,'fetch failed'):
                verified_master(runtime,expected_origin=str(origin))

    def test_default_upstream_detached_and_fast_forward_controls(self):
        with tempfile.TemporaryDirectory(prefix='master-default-') as directory:
            root = Path(directory)
            origin, seed, runtime = root/'origin.git', root/'seed', root/'runtime'
            def git(*args):
                return subprocess.check_output(['git','-c','user.name=Fixture','-c','user.email=fixture@example.invalid',*args],stderr=subprocess.STDOUT).decode().strip()
            git('init','--bare',str(origin),'-b','master')
            git('clone',str(origin),str(seed))
            (seed/'source.txt').write_text('first')
            git('-C',str(seed),'add','source.txt'); git('-C',str(seed),'commit','-m','first'); git('-C',str(seed),'push','origin','master')
            git('clone',str(origin),str(runtime))
            def local(*args): return git('-C',str(runtime),*args)
            self.assertEqual(verified_master(runtime,expected_origin=str(origin))['upstream'],'origin/master')
            (runtime/'notes.txt').write_text('operator notes')
            with self.assertRaisesRegex(RuntimeError,'untracked'): verified_master(runtime,expected_origin=str(origin),update=True)
            self.assertEqual((runtime/'notes.txt').read_text(),'operator notes')
            (runtime/'notes.txt').unlink()
            for flag, undo in [('--assume-unchanged','--no-assume-unchanged'),('--skip-worktree','--no-skip-worktree')]:
                local('update-index',flag,'source.txt')
                with self.assertRaisesRegex(RuntimeError,'hidden index'): verified_master(runtime,expected_origin=str(origin))
                local('update-index',undo,'source.txt')
            local('config','core.sparseCheckout','true')
            with self.assertRaisesRegex(RuntimeError,'sparse'): verified_master(runtime,expected_origin=str(origin))
            local('config','core.sparseCheckout','false')
            local('switch','--detach','HEAD')
            with self.assertRaises(RuntimeError): verified_master(runtime,expected_origin=str(origin))
            local('switch','master')
            local('branch','--unset-upstream')
            with self.assertRaises(RuntimeError): verified_master(runtime,expected_origin=str(origin))
            local('branch','--set-upstream-to=origin/master')
            local('symbolic-ref','refs/remotes/origin/HEAD','refs/remotes/origin/other')
            with self.assertRaisesRegex(RuntimeError,'local origin default'): verified_master(runtime,expected_origin=str(origin))
            local('remote','set-head','origin','master')
            git('-C',str(seed),'push','origin','master:main')
            local('fetch','origin','refs/heads/main:refs/remotes/origin/main')
            local('branch','--set-upstream-to=origin/main')
            with self.assertRaisesRegex(RuntimeError,'upstream'): verified_master(runtime,expected_origin=str(origin))
            local('branch','--set-upstream-to=origin/master')
            git('-C',str(origin),'symbolic-ref','HEAD','refs/heads/main')
            with self.assertRaisesRegex(RuntimeError,'remote default'): verified_master(runtime,expected_origin=str(origin))
            git('-C',str(origin),'symbolic-ref','HEAD','refs/heads/master')
            (seed/'source.txt').write_text('second')
            git('-C',str(seed),'add','source.txt'); git('-C',str(seed),'commit','-m','second'); git('-C',str(seed),'push','origin','master')
            before = local('rev-parse','HEAD')
            with self.assertRaisesRegex(RuntimeError,'behind'): verified_master(runtime,expected_origin=str(origin))
            self.assertEqual(local('rev-parse','HEAD'),before)
            target = git('-C',str(seed),'rev-parse','HEAD')
            self.assertEqual(verified_master(runtime,expected_origin=str(origin),update=True)['commit'],target)
            self.assertEqual(local('symbolic-ref','--short','HEAD'),'master')
            local('remote','set-url','origin',str(root/'unexpected.git'))
            with self.assertRaisesRegex(RuntimeError,'origin does not match'): verified_master(runtime,expected_origin=str(origin))
            self.assertEqual(local('rev-parse','HEAD'),target)
