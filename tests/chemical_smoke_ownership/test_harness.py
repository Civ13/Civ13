"""Pure source preparation and evidence-parser adversaries; never launch BYOND."""
import importlib.util
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location('smoke_runner', Path(__file__).with_name('run.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

class HarnessTests(unittest.TestCase):
    def test_prepared_production_and_pinned_historical_bodies(self):
        for historical in (False, True):
            files = runner.prepare(runner.ROOT, '.smoke_test', historical)
            self.assertNotIn('.dmm"', files['.smoke_test.dme'])
            self.assertIn('/datum/global_init/New()\n\treturn\n', files['.smoke_test_world.dm'])
            self.assertEqual(files['.smoke_test_chem.dm'].count('smoke_fixture_observe('), 1)
            self.assertEqual('spawn_owned_smoke' in files['.smoke_test_chem.dm'], not historical)

    def test_strict_positive(self):
        runner.verify('DONE chemical smoke ownership\nPASS chemical smoke ownership\n', 0)

    def test_strict_historical_failure(self):
        runner.verify('FAIL automatic systems release hidden holders\nDONE chemical smoke ownership\n', 0, True)

    def test_rejects_infrastructure_and_wrong_controls(self):
        good = 'FAIL automatic systems release hidden holders\nDONE chemical smoke ownership\n'
        for log, code in [(good,1), (good+'RUNTIME null\n',0), (good+'Bad ref\n',0),
                          (good+'FAIL unrelated\n',0), (good.replace('hidden holders','changed'),0),
                          (good+'PASS chemical smoke ownership\n',0),
                          (good.replace('DONE chemical smoke ownership',''),0), (good+good,0)]:
            with self.subTest(log=log, code=code), self.assertRaises(ValueError):
                runner.verify(log, code, True)

if __name__ == '__main__': unittest.main()
