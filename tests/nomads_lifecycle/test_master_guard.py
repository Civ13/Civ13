"""Real local Git positive/control cases; no external network or checkout reset."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'scripts/nomads-lifecycle'))
from master_guard import verified_master


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
