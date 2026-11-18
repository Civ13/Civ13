"""Offline tests for scripts/shard-group/battle_mapswap.py (TDM battle map rotation)."""
import importlib.util
import json
from pathlib import Path
import contextlib
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('battle_mapswap', ROOT / 'scripts/shard-group/battle_mapswap.py')
battle_mapswap = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(battle_mapswap)

REVISION = 'd' * 40
NEWER = 'e' * 40
DME = 'line\r\n// BEGIN_SELECTED_MAP\r\n#include "maps\\1943\\berlin.dmm"\r\n// END_SELECTED_MAP\r\ntail\r\n'


class FakeRunner:
    def __init__(self, compile_ok=True, crash_on_exit=False, writes_dmb=True):
        self.calls = []
        self.compile_ok = compile_ok
        self.crash_on_exit = crash_on_exit
        self.writes_dmb = writes_dmb

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
            if self.writes_dmb:
                (Path(cwd) / 'region.dmb').write_bytes(b'new dmb')
                (Path(cwd) / 'region.rsc').write_bytes(b'new rsc')
            if self.crash_on_exit:
                # DreamMaker 516.1688 seen on civ13.com: a clean save, then glibc aborts on exit.
                return 134, 'saving region.dmb (DEBUG mode)\nregion.dmb - 0 errors, 0 warnings\ndouble free or corruption (out)'
            return 0, 'region.dmb - 0 errors, 0 warnings'
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

    def test_a_crash_on_exit_after_a_clean_save_still_installs(self):
        battle_mapswap.rotate(self.region, 'karak', FakeRunner(crash_on_exit=True))
        self.assertEqual(b'new dmb', (self.region / 'region.dmb').read_bytes())

    def test_a_crash_without_a_new_dmb_is_a_failure(self):
        runner = FakeRunner()
        battle_mapswap.rotate(self.region, 'karak', runner)  # leaves an old region.dmb in the build tree
        (self.region / 'region.dmb').write_bytes(b'old dmb')
        with self.assertRaisesRegex(RuntimeError, 'compile failed'):
            battle_mapswap.rotate(self.region, 'karak', FakeRunner(crash_on_exit=True, writes_dmb=False))
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



class FakeHost:
    """The region host battle_mapswap asks for the group revision and records the build with."""
    def __init__(self, region, latest=NEWER, enabled=True):
        self.config = {'git': 'git', 'compiler': 'DreamMaker', 'group_config': 'tdm.json', 'region': 'battle'}
        self.platform = object()
        self.latest = latest
        self.enabled = enabled
        self.builds, self.server_builds, self.slots = [], [], []

    def update_when_empty(self):
        return self.enabled

    def latest_revision(self):
        return self.latest

    @contextlib.contextmanager
    def group_slot(self, name, what, record, wait_seconds):
        self.slots.append(name)
        yield

    def record_build(self, revision, file=None):
        self.builds.append((revision, file))

    def write_server_build(self, revision, dmb=None):
        self.server_builds.append(revision)


class FakeShardGroup:
    """shard_group's tree preparation: checks a worktree out and writes its region.dme."""
    def __init__(self, root, missing_map=False):
        self.root = root
        self.prepared = []
        self.missing_map = missing_map

    def load_group(self, path):
        return {'root': str(self.root), 'regions': [{'id': 'battle', 'kind': 'BATTLE', 'map': 'maps/1713/karak.dmm'}]}

    def prepare_tree(self, group, region, path, revision, platform, git, live=False):
        self.prepared.append((Path(path), revision, live))
        (Path(path) / 'maps' / '1713').mkdir(parents=True, exist_ok=True)
        if not self.missing_map:
            (Path(path) / 'maps' / '1713' / 'karak.dmm').write_text('x')
        (Path(path) / 'region.dme').write_text(DME.replace('1943\\berlin', '1713\\karak'), newline='')

    def place_map(self, group, region, path):
        return 'maps\\1713\\karak.dmm'


class UpdateBetweenRoundsTests(unittest.TestCase):
    """Val (2026-11-18): the TDM battle takes the latest update between rounds."""
    setUp = BattleMapswapTests.setUp
    tearDown = BattleMapswapTests.tearDown

    def update(self, host=None, sg=None, runner=None, map_id='karak'):
        host = host or FakeHost(self.region)
        sg = sg or FakeShardGroup(self.root)
        return battle_mapswap.rotate_onto_update(self.region, map_id, host, sg, runner or FakeRunner()), host, sg

    def round_update(self):
        return json.loads((self.region / 'data' / 'shard-host' / 'round-update.json').read_text())

    def test_the_next_map_is_built_at_the_latest_revision_and_installed(self):
        include, host, sg = self.update()
        build = self.root / '.rotation' / 'battle'
        self.assertEqual('maps\\1713\\karak.dmm', include)
        self.assertEqual([(build, NEWER, False), (self.region, NEWER, True)], sg.prepared,
                         'built beside the world, then its worktree moved on without touching what it loaded')
        self.assertEqual(b'new dmb', (self.region / 'region.dmb').read_bytes())
        self.assertEqual(b'new rsc', (self.region / 'region.rsc').read_bytes())
        self.assertEqual([(NEWER, 'region.dmb')], host.builds)
        self.assertEqual([NEWER], host.server_builds)
        self.assertEqual(['compile.lock'], host.slots, 'never two compiles at once on the box')
        self.assertEqual(('installed', NEWER), (self.round_update()['phase'], self.round_update()['revision']))

    def test_nothing_new_or_updates_off_builds_nothing(self):
        for host in (FakeHost(self.region, latest=REVISION), FakeHost(self.region, enabled=False)):
            runner = FakeRunner()
            include, _, sg = self.update(host=host, runner=runner)
            self.assertIsNone(include)
            self.assertEqual([], sg.prepared)
            self.assertFalse([argv for argv, _ in runner.calls if argv[-1] == 'region.dme'])

    def test_never_goes_back_to_an_older_revision(self):
        class Newer(FakeRunner):
            def __call__(self, argv, cwd, timeout):
                if argv[1:3] == ['merge-base', '--is-ancestor']:
                    return 1, ''
                return FakeRunner.__call__(self, argv, cwd, timeout)
        include, _, sg = self.update(runner=Newer())
        self.assertIsNone(include)
        self.assertEqual([], sg.prepared)

    def test_a_failed_update_build_keeps_the_world_and_is_not_retried(self):
        with self.assertRaisesRegex(RuntimeError, 'compile failed'):
            self.update(runner=FakeRunner(compile_ok=False))
        self.assertEqual(b'old dmb', (self.region / 'region.dmb').read_bytes())
        self.assertEqual(('failed', NEWER), (self.round_update()['phase'], self.round_update()['revision']))
        include, _, sg = self.update()
        self.assertIsNone(include, 'the same broken revision waits for a newer one')
        include, _, _ = self.update(host=FakeHost(self.region, latest='f' * 40))
        self.assertEqual('maps\\1713\\karak.dmm', include)

    def test_a_voted_map_missing_from_the_update_is_a_failure(self):
        with self.assertRaisesRegex(RuntimeError, 'not in the update'):
            self.update(sg=FakeShardGroup(self.root, missing_map=True))
        self.assertEqual(b'old dmb', (self.region / 'region.dmb').read_bytes())

    def main(self, argument, host, sg, rotate=None):
        patches = [mock.patch.object(battle_mapswap.Path, 'cwd', return_value=self.region),
                   mock.patch.object(battle_mapswap, 'region_host', return_value=host),
                   mock.patch.object(battle_mapswap, 'shard_group_module', return_value=sg)]
        if rotate:
            patches.append(mock.patch.object(battle_mapswap, 'rotate', **rotate))
        with contextlib.ExitStack() as stack:
            for patch in patches:
                stack.enter_context(patch)
            code = battle_mapswap.main(['x', argument])
        return code, json.loads((self.region / 'data' / 'shard-host' / 'rotation.json').read_text())

    def test_main_falls_back_to_the_map_alone_when_the_update_fails(self):
        host, sg = FakeHost(self.region), FakeShardGroup(self.root, missing_map=True)
        with mock.patch.object(battle_mapswap, 'run', FakeRunner()):
            code, state = self.main('karak', host, sg, rotate={'return_value': 'maps\\1713\\karak.dmm'})
        self.assertEqual((0, 'ready', 'karak'), (code, state['state'], state['map']))
        self.assertEqual('failed', self.round_update()['phase'])

    def test_main_update_only_keeps_the_current_map(self):
        (self.region / 'data' / 'shard-host').mkdir(parents=True)
        (self.region / 'data' / 'shard-host' / 'rotation.json').write_text(json.dumps({'state': 'ready', 'map': 'karak'}))
        rotate = mock.MagicMock()
        with mock.patch.object(battle_mapswap, 'run', FakeRunner()):
            code, state = self.main('--update', FakeHost(self.region), FakeShardGroup(self.root),
                                    rotate={'new': rotate})
        self.assertEqual((0, 'ready', 'karak'), (code, state['state'], state['map']))
        self.assertEqual(b'new dmb', (self.region / 'region.dmb').read_bytes())
        rotate.assert_not_called()
        # Nothing new: the world reboots on the build it has, at once.
        with mock.patch.object(battle_mapswap, 'run', FakeRunner()):
            code, state = self.main('--update', FakeHost(self.region, latest=REVISION), FakeShardGroup(self.root),
                                    rotate={'new': rotate})
        self.assertEqual((0, 'ready', 'karak'), (code, state['state'], state['map']))
        rotate.assert_not_called()
        (self.region / 'data' / 'shard-host' / 'rotation.json').unlink()
        with mock.patch.object(battle_mapswap, 'run', FakeRunner()):
            code, state = self.main('--update', FakeHost(self.region, latest=REVISION), FakeShardGroup(self.root),
                                    rotate={'new': rotate})
        self.assertEqual((0, 'current'), (code, state['state']), 'no voted map: the configured one stays')


if __name__ == '__main__':
    unittest.main()
