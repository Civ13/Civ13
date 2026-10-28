"""Real Git/disk transactions with inert compiler/process transports only."""
import json
import hashlib
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[2] / 'scripts/nomads-lifecycle'
sys.path.insert(0, str(SCRIPTS))
import canonical_update as m


class CanonicalUpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='cu-')
        self.base = Path(self.temp.name).resolve()
        self.assertTrue(self.base.is_relative_to(Path(tempfile.gettempdir()).resolve()))
        self.addCleanup(self.temp.cleanup)
        self.game, self.remote = self.base / 'game', self.base / 'origin.git'
        self.game.mkdir()
        self.git('init', '--bare', '-b', 'master', str(self.remote), cwd=self.base)
        self.git('init', '-b', 'master')
        for name, content in {
            '.gitignore': 'data/\nSQL/\nmap_saves/\nciv13.dmb\nciv13.rsc\nconfig/lifecycle-*\n',
            'config/host.txt': 'DefaultHost',
            'config/local-options.txt': 'keep these options',
            'civ13.dme': '#include "maps/nomads/nomads_europe.dmm"\n',
            'UI/crafting-atlas.json': 'original atlas', 'source.txt': 'old source',
            'maps/nomads/nomads_gaia.dmm': 'Gaia map fixture',
            'maps/nomads/nomads_europe.dmm': 'Europe map fixture',
            'scripts/build-crafting-atlas.py': '# inert fixture',
        }.items():
            path = self.game / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        self.git('add', '.')
        self.git('commit', '-m', 'initial')
        self.git('remote', 'add', 'origin', str(self.remote))
        self.git('push', '-u', 'origin', 'master')
        self.git('remote', 'set-head', 'origin', 'master')
        self.old = self.git('rev-parse', 'HEAD').strip()
        self.dev = self.base / 'dev'
        self.git('clone', str(self.remote), str(self.dev), cwd=self.base)
        self.advance()
        self.root = self.game / 'data/desktop-supervisor'
        self.root.mkdir(parents=True)
        self.token = self.game / 'config/lifecycle-token.txt'
        self.token.write_text('a' * 32)
        (self.game / 'config/lifecycle-revision.txt').write_text(self.old)
        (self.game / 'config/host.txt').write_bytes(b'ApprovedLocalHost\r\n')
        (self.game / 'SQL').mkdir()
        (self.game / 'SQL/admins.txt').write_text('fixture;Admin;16254|||\n')
        self.compiler = self.base / 'inert-compiler'
        self.compiler.write_bytes(b'not an executable')
        self.daemon = self.base / 'inert-daemon'
        self.daemon.write_bytes(b'not an executable either')
        self.config = {'root': str(self.root), 'repository': str(self.game),
            'canonical_game_directory': str(self.game), 'config_directory': str(self.game / 'config'),
            'branch': 'master', 'map': 'NOMADS_GAIA', 'bind': '0.0.0.0', 'port': 1714,
            'git': 'git', 'python': sys.executable, 'compiler': str(self.compiler),
            'compiler_sha256': m.core.digest(self.compiler), 'canonical_update_enabled': True,
            'daemon': str(self.daemon), 'daemon_sha256': m.core.digest(self.daemon),
            'approved_host_sha256': m.core.digest(self.game / 'config/host.txt')}
        for name in ('civ13.dmb', 'civ13.rsc'):
            (self.game / name).write_bytes(b'old artifact ' + name.encode())
        self.state = {'phase': 'ready', 'revision': self.old, 'map': 'NOMADS_GAIA',
            'generation': None, 'host': {'pid': 123, 'creation_filetime': 456, 'workdir': str(self.game)},
            'binaries': {name: m.core.digest(self.game / name) for name in ('civ13.dmb', 'civ13.rsc')}}
        m.core.write_json(self.root / 'state.json', self.state)
        self.events = []
        owner = self

        class InertSupervisor(m.core.Supervisor):
            running = True
            tick = 0
            fail_save = False
            fail_compile = False
            stay_alive = False
            advance_during_compile = False
            damage_working_save = False
            wrong_dimensions = False
            frozen_heartbeat = False
            bad_compile_summary = False
            maintenance = None
            clients = 0

            def alive(self):
                return self.running

            def status(self):
                self.tick += 10
                return {'ok': 1, 'ready': 1, 'busy': 0, 'error': None, 'clients': self.clients,
                        'maintenance_operation': self.maintenance,
                        'session': 'e' * 32, 'map': 'NOMADS_GAIA',
                        'revision': self.state['revision'], 'restart_hold': 0, 'restart_intent': 0,
                        'generation': self.state.get('generation'),
                        'restart_import_complete': int(bool(self.state.get('generation'))),
                        'maxx': 501 if self.wrong_dimensions else 500, 'maxy': 350, 'maxz': 1,
                        'debug': {'tick': 1 if self.frozen_heartbeat else self.tick, 'runtime': {'total': 0}}}

            def stop_saved(self, operation, expected_session=None, admin_operation=False):
                owner.assertEqual(expected_session, 'e' * 32)
                if admin_operation:
                    owner.assertEqual(operation, self.maintenance)
                owner.events.append('save')
                if self.fail_save:
                    raise RuntimeError('injected save failure')
                folder = owner.make_generation(operation)
                backup = owner.root / 'backups' / operation
                generation = m.core.snapshot(folder, backup, operation, 'e' * 32, 'NOMADS_GAIA')
                if not self.stay_alive:
                    self.running = False
                    owner.events.append('exit')
                return backup, generation

            def command(self, arguments, cwd=None, log=None, timeout=1800):
                owner.assertFalse(self.running)
                if arguments[0] == owner.config['python']:
                    owner.events.append('atlas')
                    (owner.game / 'UI/crafting-atlas.json').write_text('generated Gaia atlas')
                    return ''
                if arguments[0] == str(owner.compiler):
                    owner.events.append('compile')
                    owner.assertIn('nomads_gaia.dmm', (owner.game / 'civ13.dme').read_text())
                    if self.fail_compile:
                        raise RuntimeError('injected compiler failure')
                    for name in ('civ13.dmb', 'civ13.rsc'):
                        (owner.game / name).write_bytes(b'new Gaia fixture ' + name.encode())
                    if self.advance_during_compile:
                        owner.advance('newer master')
                    if self.damage_working_save:
                        (owner.game / 'map_saves/1.sav').write_bytes(b'changed after save')
                    return '10 errors, 0 warnings' if self.bad_compile_summary else '0 errors, 0 warnings'
                return owner.git(*arguments[1:])

            def launch_prepared(self, run, manifest, generation, operation, backup=None, readiness_check=None):
                owner.events.append('load')
                owner.assertFalse(self.running)
                owner.assertEqual(run, owner.game)

                def spawn(*args, **kwargs):
                    owner.assertEqual(kwargs['cwd'], owner.game)
                    self.running = True
                    return type('InertChild', (), {'pid': 789})()

                # Exercise real startup/state/publication; only OS transports are inert.
                with patch.object(m.core.subprocess, 'Popen', side_effect=spawn), \
                     patch.object(m.core.socket, 'socket'), \
                     patch.object(m.core, 'process_identity', return_value=987):
                    return super().launch_prepared(run, manifest, generation, operation, backup,
                                                   readiness_check=readiness_check)

        self.sup = InertSupervisor(self.config)
        def observe_continuity_wait(seconds):
            owner.assertEqual(self.sup.state['phase'], 'starting')
            owner.assertNotIn('cycle_complete', (owner.root / 'events.jsonl').read_text())
            owner.events.append('continuity-before-ready')
        self.sup.sleep = observe_continuity_wait
        self.updater = m.CanonicalUpdater(self.config, supervisor=self.sup,
                                          guard=self.guard, quiet=self.quiet)

    def git(self, *args, cwd=None):
        result = subprocess.run(['git', '-c', 'user.name=Canonical fixture', '-c',
            'user.email=fixture@example.invalid', *args], cwd=cwd or self.game,
            capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def advance(self, text='new master'):
        (self.dev / 'source.txt').write_text(text)
        self.git('add', 'source.txt', cwd=self.dev)
        self.git('commit', '-m', text, cwd=self.dev)
        self.git('push', 'origin', 'master', cwd=self.dev)

    def guard(self, repo, git, **kwargs):
        callback = kwargs.get('mutation_guard')
        if callback is not None:
            def gated():
                self.events.append('source-gate')
                self.assertFalse(self.sup.running)
                callback()
            kwargs['mutation_guard'] = gated
        return m.master_guard.verified_master(repo, git, expected_origin=str(self.remote), **kwargs)

    def quiet(self, game, host, port):
        self.assertEqual((game, host, port), (self.game, self.state['host'], 1714))
        if self.sup.running:
            raise RuntimeError('owned process still alive')

    def make_generation(self, operation):
        folder = self.game / 'map_saves'
        folder.mkdir()
        generation = 'round-v2:' + 'c' * 32
        (folder / 'map.txt').write_text('NOMADS_GAIA')
        (folder / 'round.json').write_text(json.dumps({'version': 2, 'generation': generation,
            'map': 'NOMADS_GAIA', 'maxx': 500, 'maxy': 350, 'maxz': 1}))
        (folder / 'save_complete.txt').write_text(generation)
        (folder / '1.sav').write_bytes(b'saved Gaia fixture')
        (folder / 'restart_intent.json').write_text(json.dumps({'version': 1, 'generation': generation,
            'metadata': m.core.byond_text_md5(folder / 'map.txt'), 'round': m.core.byond_text_md5(folder / 'round.json'),
            'lifecycle_operation': operation, 'lifecycle_session': 'e' * 32}))
        return folder

    def test_save_exit_update_compile_restore_load_real_publication(self):
        protected = self.updater.protected_config()
        originals = [(self.game / p).read_bytes() for p in ('civ13.dme', 'UI/crafting-atlas.json')]
        result = self.updater.run()
        self.assertEqual(result['phase'], 'ready')
        self.assertNotEqual(result['revision'], self.old)
        self.assertEqual(self.events[:3], ['save', 'exit', 'source-gate'])
        self.assertLess(self.events.index('source-gate'), self.events.index('compile'))
        self.assertLess(self.events.index('compile'), self.events.index('load'))
        self.assertEqual(protected, self.updater.protected_config())
        self.assertEqual(originals, [(self.game / p).read_bytes() for p in ('civ13.dme', 'UI/crafting-atlas.json')])
        self.assertEqual(self.sup.state['phase'], 'ready')
        self.assertIn('continuity-before-ready', self.events)
        self.assertEqual((self.root / 'events.jsonl').read_text().count('cycle_complete'), 1)
        self.assertFalse((self.root / 'runs').exists())
        self.assertFalse((self.root / 'builds').exists())
        self.assertEqual(self.git('branch', '--show-current').strip(), 'master')
        self.assertEqual(self.git('status', '--porcelain'), ' M config/host.txt\n')

    def test_admin_request_with_connected_clients_runs_once(self):
        operation = 'd' * 32
        self.sup.maintenance = operation
        self.sup.clients = 2
        factory = lambda config, supervisor: self.updater
        result = m.consume_admin_once(self.config, supervisor=self.sup, updater_factory=factory)
        self.assertEqual(result['phase'], 'ready')
        self.assertEqual(self.events.count('save'), 1)
        receipt = self.root / 'admin-maintenance' / (operation + '.json')
        self.assertEqual(json.loads(receipt.read_text())['phase'], 'complete')
        with self.assertRaises(FileExistsError):
            m.consume_admin_once(self.config, supervisor=self.sup, updater_factory=factory)
        self.assertEqual(self.events.count('save'), 1)

    def test_admin_request_failure_is_retained_and_not_replayed(self):
        operation = 'd' * 32
        self.sup.maintenance = operation
        self.sup.fail_save = True
        factory = lambda config, supervisor: self.updater
        with patch.object(m.core, 'query') as query:
            with self.assertRaisesRegex(RuntimeError, 'save failure'):
                m.consume_admin_once(self.config, supervisor=self.sup, updater_factory=factory)
            query.assert_called_once_with(1714, self.sup.token, 'maintenance_failed', operation, 'e' * 32)
        receipt = self.root / 'admin-maintenance' / (operation + '.json')
        self.assertEqual(json.loads(receipt.read_text())['phase'], 'failed')
        with self.assertRaisesRegex(RuntimeError, 'halted'):
            m.consume_admin_once(self.config, supervisor=self.sup, updater_factory=factory)
        # Model operator reconciliation only in this isolated fixture; the
        # retained identity must still reject a replay after the latch is gone.
        (self.root / 'HALTED.json').unlink()
        with self.assertRaises(FileExistsError):
            m.consume_admin_once(self.config, supervisor=self.sup, updater_factory=factory)
        self.assertEqual(self.events, ['save'])

    def test_admin_session_or_operation_mismatch_refused_before_save(self):
        self.sup.maintenance = 'd' * 32
        for operation, session in [('d' * 32, 'f' * 32), ('c' * 32, 'e' * 32)]:
            with self.subTest(operation=operation, session=session), self.assertRaisesRegex(RuntimeError, 'request or process session'):
                self.updater.run(admin_operation=operation, expected_session=session)
        self.assertEqual(self.events, [])

    def test_save_boundary_rechecks_admin_request_before_network_mutation(self):
        self.sup.maintenance = 'c' * 32
        self.sup.clients = 2
        with patch.object(m.core, 'query') as query:
            with self.assertRaisesRegex(RuntimeError, 'request changed'):
                m.core.Supervisor.stop_saved(self.sup, 'd' * 32, expected_session='e' * 32, admin_operation=True)
            query.assert_not_called()

    def test_admin_compile_failure_keeps_old_artifacts_and_save(self):
        self.sup.maintenance = 'd' * 32
        self.sup.fail_compile = True
        factory = lambda config, supervisor: self.updater
        with self.assertRaisesRegex(RuntimeError, 'compiler failure'):
            m.consume_admin_once(self.config, supervisor=self.sup, updater_factory=factory)
        self.assertFalse(self.sup.running)
        self.assertNotIn('load', self.events)
        self.assertTrue(Path(self.updater.transaction['previous_artifacts']).is_file())
        self.assertTrue((Path(self.updater.transaction['backup']) / 'receipt.json').is_file())
        self.assertEqual(json.loads((self.root / 'admin-maintenance' / ('d' * 32 + '.json')).read_text())['phase'], 'failed')

    def test_admin_update_failure_keeps_backup_and_never_compiles(self):
        self.sup.maintenance = 'd' * 32
        original = self.updater.guard
        def fail_update(*args, **kwargs):
            if kwargs.get('update'):
                raise RuntimeError('injected update conflict')
            return original(*args, **kwargs)
        self.updater.guard = fail_update
        with self.assertRaisesRegex(RuntimeError, 'update conflict'):
            m.consume_admin_once(self.config, supervisor=self.sup, updater_factory=lambda config, supervisor: self.updater)
        self.assertNotIn('compile', self.events)
        self.assertNotIn('load', self.events)
        self.assertTrue((Path(self.updater.transaction['backup']) / 'receipt.json').exists())
        self.assertTrue(Path(self.updater.transaction['previous_artifacts']).exists())

    def test_admin_launch_or_restore_failure_never_reports_complete(self):
        self.sup.maintenance = 'd' * 32
        with patch.object(self.sup, 'launch_prepared', side_effect=RuntimeError('launch or restore failed')):
            with self.assertRaisesRegex(RuntimeError, 'launch or restore failed'):
                m.consume_admin_once(self.config, supervisor=self.sup, updater_factory=lambda config, supervisor: self.updater)
        receipt = json.loads((self.root / 'admin-maintenance' / ('d' * 32 + '.json')).read_text())
        self.assertEqual(receipt['phase'], 'failed')
        self.assertTrue((self.root / 'HALTED.json').exists())

    def test_save_failure_never_fetches_or_builds_or_loads(self):
        self.sup.fail_save = True
        with self.assertRaisesRegex(RuntimeError, 'save failure'):
            self.updater.run()
        self.assertTrue(self.sup.running)
        self.assertEqual(self.events, ['save'])
        self.assertEqual(self.git('rev-parse', 'HEAD').strip(), self.old)

    def test_returned_save_does_not_substitute_for_actual_exit(self):
        self.sup.stay_alive = True
        with self.assertRaisesRegex(RuntimeError, 'still alive'):
            self.updater.run()
        self.assertNotIn('source-gate', self.events)
        self.assertNotIn('compile', self.events)

    def test_session_changed_between_preflight_and_save_never_sends_mutation(self):
        with patch.object(m.core, 'query') as query:
            with self.assertRaisesRegex(RuntimeError, 'session changed'):
                m.core.Supervisor.stop_saved(self.sup, 'd' * 32, expected_session='f' * 32)
            query.assert_not_called()
        self.assertTrue(self.sup.running)

    def test_compile_failure_keeps_backup_and_original_inputs_no_load(self):
        self.sup.fail_compile = True
        dme = (self.game / 'civ13.dme').read_bytes()
        atlas = (self.game / 'UI/crafting-atlas.json').read_bytes()
        with self.assertRaisesRegex(RuntimeError, 'compiler failure'):
            self.updater.run()
        self.assertFalse(self.sup.running)
        self.assertNotIn('load', self.events)
        self.assertEqual((self.game / 'civ13.dme').read_bytes(), dme)
        self.assertEqual((self.game / 'UI/crafting-atlas.json').read_bytes(), atlas)
        self.assertTrue(Path(self.updater.transaction['previous_artifacts']).is_file())
        self.assertTrue((Path(self.updater.transaction['backup']) / 'receipt.json').is_file())

    def test_dirty_source_refused_before_save(self):
        (self.game / 'source.txt').write_text('operator change')
        with self.assertRaisesRegex(RuntimeError, 'local changes'):
            self.updater.run()
        self.assertEqual(self.events, [])
        self.assertTrue(self.sup.running)

    def test_detached_source_refused_before_save(self):
        self.git('checkout', '--detach')
        with self.assertRaises(RuntimeError):
            self.updater.run()
        self.assertEqual(self.events, [])

    def test_local_inspection_does_not_fetch_or_refresh_index(self):
        index = self.game / '.git/index'
        before = index.read_bytes()
        self.remote.rename(self.base / 'offline.git')
        result = self.updater.verify_source(inspect_only=True)
        self.assertFalse(result['fresh_remote_verified'])
        self.assertEqual(index.read_bytes(), before)
        self.assertEqual(self.events, [])

    def test_ungated_hosting_fetch_and_update_refused_before_network(self):
        for update in (False, True):
            with self.subTest(update=update), self.assertRaisesRegex(RuntimeError, 'serialized save/load'):
                m.master_guard.verified_master(self.game, expected_origin=str(self.remote),
                    update=update, approved_host_sha256=self.config['approved_host_sha256'])
        self.assertEqual(self.git('rev-parse', 'origin/master').strip(), self.old)

    def test_other_dirty_and_staged_host_refused_before_save(self):
        self.git('add', 'config/host.txt')
        with self.assertRaisesRegex(RuntimeError, 'local changes'):
            self.updater.run()
        self.assertEqual(self.events, [])

    def test_foreign_listener_or_identity_uncertainty_blocks_source_changes(self):
        def unknown(*args):
            raise RuntimeError('foreign listener or uncertain PID')
        self.updater.quiet = unknown
        with self.assertRaisesRegex(RuntimeError, 'foreign listener'):
            self.updater.run()
        self.assertNotIn('source-gate', self.events)

    def test_failure_during_loading_preserves_owned_state_and_does_not_retry(self):
        with patch.object(self.sup, 'launch_prepared', side_effect=RuntimeError('import failed')) as launch:
            with self.assertRaisesRegex(RuntimeError, 'import failed'):
                self.updater.run()
            launch.assert_called_once()
        self.assertTrue((self.root / 'HALTED.json').is_file())
        self.assertNotEqual(json.loads((self.root / 'update-state.json').read_text())['phase'], 'complete')

    def test_real_canonical_publisher_rejects_wrong_directory(self):
        outside = self.base / 'outside'
        outside.mkdir()
        with self.assertRaisesRegex(RuntimeError, 'Canonical game directory'):
            m.core.validate_prepared_directory(self.root, outside, self.game)

    def assert_no_ready_publication(self):
        self.assertEqual(self.sup.state['phase'], 'starting')
        self.assertEqual(json.loads(self.sup.state_path.read_text())['phase'], 'starting')
        events = (self.root / 'events.jsonl').read_text()
        self.assertNotIn('cycle_complete', events)
        self.assertEqual(json.loads((self.root / 'update-state.json').read_text())['phase'], 'failed')

    def test_loaded_dimension_mismatch_keeps_owned_world_and_halts(self):
        self.sup.wrong_dimensions = True
        with self.assertRaisesRegex(RuntimeError, 'continuity'):
            self.updater.run()
        self.assertTrue(self.sup.running)
        self.assertTrue((self.root / 'HALTED.json').exists())
        self.assert_no_ready_publication()

    def test_loaded_frozen_heartbeat_keeps_owned_world_and_halts(self):
        self.sup.frozen_heartbeat = True
        with self.assertRaisesRegex(RuntimeError, 'heartbeat'):
            self.updater.run()
        self.assertTrue(self.sup.running)
        self.assertTrue((self.root / 'HALTED.json').exists())
        self.assert_no_ready_publication()

    def test_nonzero_compile_summary_cannot_match_zero_substring(self):
        self.sup.bad_compile_summary = True
        with self.assertRaisesRegex(RuntimeError, 'zero errors'):
            self.updater.run()
        self.assertNotIn('load', self.events)

    def test_changed_tool_pin_refuses_before_save(self):
        self.compiler.write_bytes(b'changed tool')
        with self.assertRaisesRegex(RuntimeError, 'tool identity'):
            self.updater.run()
        self.assertEqual(self.events, [])

    def test_new_remote_master_after_compile_prevents_load(self):
        self.sup.advance_during_compile = True
        with self.assertRaisesRegex(RuntimeError, 'behind'):
            self.updater.run()
        self.assertNotIn('load', self.events)
        self.assertFalse(self.sup.running)

    def test_changed_working_save_is_not_replaced_or_loaded(self):
        self.sup.damage_working_save = True
        with self.assertRaisesRegex(RuntimeError, 'Working save differs'):
            self.updater.run()
        self.assertNotIn('load', self.events)
        self.assertEqual((self.game / 'map_saves/1.sav').read_bytes(), b'changed after save')

    def test_incomplete_transaction_cannot_replay(self):
        m.core.write_json(self.root / 'update-state.json', {'phase': 'loading'})
        with self.assertRaisesRegex(RuntimeError, 'incomplete'):
            self.updater.run()
        self.assertEqual(self.events, [])

    def test_default_off_and_legacy_cycle_cannot_mutate_canonical_source(self):
        self.config['canonical_update_enabled'] = False
        with self.assertRaisesRegex(RuntimeError, 'disabled'):
            self.updater.run()
        with patch.object(self.sup, 'candidate') as candidate:
            with self.assertRaisesRegex(RuntimeError, 'explicit save/load'):
                self.sup.cycle()
            candidate.assert_not_called()


if __name__ == '__main__':
    unittest.main()
