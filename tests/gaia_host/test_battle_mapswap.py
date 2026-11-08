"""Offline tests for scripts/shard-group/battle_mapswap.py (TDM battle map rotation)."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('battle_mapswap', ROOT / 'scripts/shard-group/battle_mapswap.py')
battle_mapswap = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(battle_mapswap)

REVISION = 'd' * 40
DME = 'line\r\n// BEGIN_SELECTED_MAP\r\n#include "maps\\1943\\berlin.dmm"\r\n// END_SELECTED_MAP\r\ntail\r\n'


class FakeRunner:
    def __init__(self, compile_ok=True):
        self.calls = []
        self.compile_ok = compile_ok

    def __call__(self, argv, cwd, timeout):
        self.calls.append((list(argv), Path(cwd)))
        if argv[1:] == ['rev-parse', 'HEAD']:
            return 0, REVISION + '\n'
        if argv[1:3] == ['worktree', 'add']:
            path = Path(argv[5])
            path.mkdir(parents=True)
            (path / '.git').write_text('gitdir: elsewhere\n')
            return 0, ''
        if argv[-1] == 'region.dme':
            if not self.compile_ok:
                return 1, 'region.dme: error: bad'
            (Path(cwd) / 'region.dmb').write_bytes(b'new dmb')
            (Path(cwd) / 'region.rsc').write_bytes(b'new rsc')
            return 0, '0 errors'
        return 0, ''


class BattleMapswapTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.root = base / 'regions'
        self.region = self.root / 'battle'
        (self.region / 'maps' / '1943').mkdir(parents=True)
        (self.region / 'maps' / '1713').mkdir(parents=True)
        (self.region / 'config').mkdir()
        (self.region / 'maps' / '1943' / 'berlin.dmm').write_text('x')
        (self.region / 'maps' / '1713' / 'karak.dmm').write_text('x')
        (self.region / 'maps' / '1713' / 'karak_island.dmm').write_text('x')
        (self.region / 'region.dme').write_text(DME, newline='')
        (self.region / 'region.dmb').write_bytes(b'old dmb')
        (self.region / 'region.rsc').write_bytes(b'old rsc')
        settings = {'root': str(self.root), 'region': 'battle', 'git': 'git', 'compiler': 'DreamMaker'}
        (self.region / 'config' / 'shard_build.json').write_text(json.dumps(settings))

    def tearDown(self):
        self.tmp.cleanup()

    def test_find_map_prefers_an_exact_name(self):
        self.assertEqual('karak.dmm', battle_mapswap.find_map(self.region / 'maps', 'KARAK').name)
        self.assertEqual('karak_island.dmm', battle_mapswap.find_map(self.region / 'maps', 'island').name)
        self.assertIsNone(battle_mapswap.find_map(self.region / 'maps', 'atlantis'))

    def test_rotate_builds_beside_the_world_and_swaps_the_live_slot(self):
        runner = FakeRunner()
        include = battle_mapswap.rotate(self.region, 'KARAK', runner)
        self.assertEqual('maps\\1713\\karak.dmm', include)
        build = self.root / '.rotation' / 'battle'
        dme = (build / 'region.dme').read_text()
        self.assertIn('#include "maps\\1713\\karak.dmm"', dme)
        self.assertNotIn('berlin', dme)
        self.assertIn('\r\n', (build / 'region.dme').read_bytes().decode())
        self.assertEqual(b'new dmb', (self.region / 'region.dmb').read_bytes())
        self.assertEqual(b'new rsc', (self.region / 'region.rsc').read_bytes())
        # The worktree is checked out at the region's own commit, never another revision.
        add = [argv for argv, _ in runner.calls if argv[1:3] == ['worktree', 'add']][0]
        self.assertEqual(REVISION, add[-1])
        # The second rotation reuses the worktree.
        runner = FakeRunner()
        battle_mapswap.rotate(self.region, 'berlin', runner)
        self.assertIn(['git', 'checkout', '--force', '--detach', REVISION], [argv for argv, _ in runner.calls])

    def test_rotate_follows_the_handover_build_slot(self):
        (self.region / 'data' / 'shard-host').mkdir(parents=True)
        (self.region / 'data' / 'shard-host' / 'build.json').write_text(json.dumps({'file': 'region.b.dmb'}))
        battle_mapswap.rotate(self.region, 'karak', FakeRunner())
        self.assertEqual(b'new dmb', (self.region / 'region.b.dmb').read_bytes())
        self.assertEqual(b'new rsc', (self.region / 'region.b.rsc').read_bytes())
        self.assertEqual(b'old dmb', (self.region / 'region.dmb').read_bytes())

    def test_a_failed_compile_leaves_the_running_build(self):
        with self.assertRaisesRegex(RuntimeError, 'compile failed'):
            battle_mapswap.rotate(self.region, 'karak', FakeRunner(compile_ok=False))
        self.assertEqual(b'old dmb', (self.region / 'region.dmb').read_bytes())

    def test_refuses_bad_names(self):
        for name in ('../x', 'a b', '', 'k;rm'):
            with self.assertRaisesRegex(RuntimeError, 'invalid map id'):
                battle_mapswap.rotate(self.region, name, FakeRunner())
        with self.assertRaisesRegex(RuntimeError, 'no map named'):
            battle_mapswap.rotate(self.region, 'atlantis', FakeRunner())

    def test_main_records_the_state_the_world_waits_on(self):
        with mock.patch.object(battle_mapswap.Path, 'cwd', return_value=self.region), \
                mock.patch.object(battle_mapswap, 'rotate', return_value='maps\\1713\\karak.dmm'):
            self.assertEqual(0, battle_mapswap.main(['x', 'karak']))
        state = json.loads((self.region / 'data' / 'shard-host' / 'rotation.json').read_text())
        self.assertEqual(('ready', 'karak'), (state['state'], state['map']))
        with mock.patch.object(battle_mapswap.Path, 'cwd', return_value=self.region), \
                mock.patch.object(battle_mapswap, 'rotate', side_effect=RuntimeError('compile failed: x')):
            self.assertEqual(1, battle_mapswap.main(['x', 'karak']))
        state = json.loads((self.region / 'data' / 'shard-host' / 'rotation.json').read_text())
        self.assertEqual('failed', state['state'])


if __name__ == '__main__':
    unittest.main()
