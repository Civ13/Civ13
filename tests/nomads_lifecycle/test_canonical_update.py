"""Real Git/disk transactions with inert compiler/process transports only."""
import json
import hashlib
import io
import struct
from contextlib import redirect_stdout
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

SCRIPTS = Path(__file__).resolve().parents[2] / 'scripts/nomads-lifecycle'
sys.path.insert(0, str(SCRIPTS))
import canonical_update as m
import bot_consumer as bot


class CanonicalUpdateTests(unittest.TestCase):
    def setUp(self):
        # The process and listener transports are inert in these source tests.
        self.listener_guard = m.require_owned_listener
        listener_patch = patch.object(m, 'require_owned_listener')
        listener_patch.start()
        self.addCleanup(listener_patch.stop)
        observation_patch = patch.object(m.core, 'windows_listener_observation', return_value={})
        self.listener_observation = observation_patch.start()
        self.addCleanup(observation_patch.stop)
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
        self.clone_arguments = None
        owner = self

        class InertSupervisor(m.core.Supervisor):
            running = True
            tick = 0
            fail_save = False
            fail_compile = False
            stay_alive = False
            advance_during_compile = False
            damage_working_save = False
            damage_old_binary = False
            damage_staged_source = False
            damage_before_freeze = False
            damage_dme_before_freeze = False
            damage_atlas_before_freeze = False
            invalid_generated_atlas = False
            damage_archive_during_compile = False
            replace_archive_and_digest = False
            wrong_dimensions = False
            frozen_heartbeat = False
            bad_compile_summary = False
            maintenance = None
            clients = 0
            persistence_mode = 1
            mode_after_launch = None

            def alive(self):
                return self.running

            def status(self):
                self.tick += 10
                return {'ok': 1, 'ready': 1, 'busy': 0, 'error': None, 'clients': self.clients,
                        'maintenance_operation': self.maintenance,
                        'session': 'e' * 32, 'map': 'NOMADS_GAIA', 'persistence_mode': self.persistence_mode,
                        'revision': self.state['revision'], 'restart_hold': 0, 'restart_intent': 0,
                        'generation': self.state.get('generation') or '',
                        'restart_import_complete': int(bool(self.state.get('generation'))),
                        'maxx': 501 if self.wrong_dimensions else 500, 'maxy': 350, 'maxz': 1,
                        'debug': {'tick': 1 if self.frozen_heartbeat else self.tick, 'runtime': {'total': 0}}}

            def stop_saved(self, operation, expected_session=None, admin_operation=False, expected_persistence=None, before_mutation=None):
                owner.assertEqual(expected_session, 'e' * 32)
                owner.assertEqual(expected_persistence, self.persistence_mode)
                if before_mutation is not None:
                    before_mutation()
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
                if arguments[0] == owner.config['git'] and arguments[1] == 'clone':
                    owner.clone_arguments = list(arguments)
                if arguments[0] == owner.config['python']:
                    owner.events.append('atlas')
                    output = Path(arguments[arguments.index('--game-catalog') + 1])
                    owner.assertNotEqual(output, Path(cwd) / 'UI/crafting-atlas.json')
                    output.write_text('not JSON' if self.invalid_generated_atlas else
                                      json.dumps({'acquisition': {}, 'recipes': [], 'resources': {}}))
                    if self.damage_before_freeze:
                        (Path(cwd) / 'source.txt').write_text('unexpected before freeze')
                    if self.damage_dme_before_freeze:
                        with (Path(cwd) / 'civ13.dme').open('a') as dme:
                            dme.write('\n#include "unexpected.dm"\n')
                    if self.damage_atlas_before_freeze:
                        (Path(cwd) / 'UI/crafting-atlas.json').write_text('unexpected direct atlas edit')
                    return ''
                if arguments[0] == str(owner.compiler):
                    owner.events.append('compile')
                    owner.assertIn('nomads_gaia.dmm', (Path(cwd) / 'civ13.dme').read_text())
                    if self.fail_compile:
                        raise RuntimeError('injected compiler failure')
                    for name in ('civ13.dmb', 'civ13.rsc'):
                        (Path(cwd) / name).write_bytes(b'new Gaia fixture ' + name.encode())
                    if self.damage_old_binary:
                        (owner.game / 'civ13.dmb').write_bytes(b'unexpected concurrent replacement')
                    if self.damage_staged_source:
                        (Path(cwd) / 'source.txt').write_text('unexpected staged source edit')
                    if self.advance_during_compile:
                        owner.advance('newer master')
                    if self.damage_working_save:
                        (owner.game / 'map_saves/1.sav').write_bytes(b'changed after save')
                    if self.damage_archive_during_compile:
                        Path(owner.updater.transaction['previous_artifacts']).write_bytes(b'damaged archive')
                    if self.replace_archive_and_digest:
                        archive_path = Path(owner.updater.transaction['previous_artifacts'])
                        with m.zipfile.ZipFile(archive_path, 'w') as archive:
                            archive.writestr('civ13.dmb', b'wrong artifact')
                            archive.writestr('civ13.rsc', b'wrong artifact')
                        owner.updater.transaction['previous_artifacts_sha256'] = m.core.digest(archive_path)
                    return '10 errors, 0 warnings' if self.bad_compile_summary else '0 errors, 0 warnings'
                return owner.git(*arguments[1:], cwd=cwd).strip()

            def launch_prepared(self, run, manifest, generation, operation, backup=None, readiness_check=None, before_spawn=None):
                owner.events.append('load')
                owner.assertFalse(self.running)
                owner.assertEqual(run, owner.game)

                def spawn(*args, **kwargs):
                    owner.assertEqual(kwargs['cwd'], owner.game)
                    if self.mode_after_launch is not None:
                        self.persistence_mode = self.mode_after_launch
                    self.running = True
                    return type('InertChild', (), {'pid': 789})()

                # Exercise real startup/state/publication; only OS transports are inert.
                with patch.object(m.core.subprocess, 'Popen', side_effect=spawn), \
                     patch.object(m.core.socket, 'socket'), \
                     patch.object(m.core, 'process_identity', return_value=987):
                    return super().launch_prepared(run, manifest, generation, operation, backup,
                                                   readiness_check=readiness_check, before_spawn=before_spawn)

        self.sup = InertSupervisor(self.config)
        self.sup.owned_session = 'e' * 32
        self.sup.child = Mock(pid=123)
        self.now = 0
        def observe_continuity_wait(seconds):
            owner.assertEqual(self.sup.state['phase'], 'starting')
            owner.assertNotIn('cycle_complete', (owner.root / 'events.jsonl').read_text())
            owner.events.append('continuity-before-ready')
            self.now += seconds
        self.sup.sleep = observe_continuity_wait
        self.sup.clock = lambda: self.now
        self.updater = m.CanonicalUpdater(self.config, supervisor=self.sup,
                                          guard=self.guard, quiet=self.quiet)
        run = self.updater.run
        def run_with_lock(*args, held_lock=None, **kwargs):
            if held_lock is not None:
                return run(*args, held_lock=held_lock, **kwargs)
            with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease:
                return run(*args, held_lock=lease, **kwargs)
        self.updater.run = run_with_lock

    def test_fresh_canonical_updater_cannot_adopt_persisted_host(self):
        updater = m.CanonicalUpdater(self.config, guard=self.guard, quiet=self.quiet)
        with patch.object(m.core, 'process_identity') as identity, patch.object(m.core, 'query') as query:
            with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease:
                with self.assertRaisesRegex(RuntimeError, 'same-process supervisor owner'):
                    updater.run(held_lock=lease)
            identity.assert_not_called()
            query.assert_not_called()
        self.assertFalse((self.root / 'HALTED.json').exists())

    def test_unverified_listener_guard_fails_closed(self):
        self.listener_observation.side_effect = PermissionError('listener unavailable')
        with patch.object(m, 'require_owned_listener', self.listener_guard), \
             patch.object(self.sup, 'status') as status, \
             self.assertRaisesRegex(PermissionError, 'listener unavailable'):
            m.consume_admin_once(self.config, self.sup)
        status.assert_not_called()
        self.assertFalse((self.root / 'admin-maintenance').exists())

    def test_same_process_coordinator_uses_existing_owner_and_lock(self):
        operation = 'd' * 32
        self.sup.maintenance = operation
        updater = Mock()
        updater.run.return_value = {'phase': 'ready'}
        factory = Mock(return_value=updater)
        with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease:
            coordinator = m.CanonicalCoordinator(self.config, self.sup, lease, updater_factory=factory)
            with patch.object(m.core, 'exclusive_lock', side_effect=AssertionError('lock reacquired')):
                self.assertEqual(coordinator.poll_admin(), {'phase': 'ready'})
            factory.assert_called_once_with(self.config, supervisor=self.sup)
            updater.run.assert_called_once_with(admin_operation=operation, expected_session='e' * 32, held_lock=lease)
            self.assertEqual(json.loads((self.root / 'admin-maintenance' / (operation + '.json')).read_text())['phase'], 'complete')
        with self.assertRaisesRegex(RuntimeError, 'lock is not held'):
            coordinator.poll_admin()
        self.assertEqual(updater.run.call_count, 1)

    def test_admin_update_revokes_bot_capability_before_updater(self):
        operation = 'd' * 32
        self.sup.maintenance = operation
        events = []
        updater = Mock()
        updater.run.side_effect = lambda **kwargs: events.append('update') or {'phase': 'ready'}
        with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease:
            coordinator = m.CanonicalCoordinator(self.config, self.sup, lease, updater_factory=lambda config, supervisor: updater)
            coordinator.poll_admin(before_update=lambda: events.append('revoke'))
        self.assertEqual(events, ['revoke', 'update'])

    def test_failed_bot_revocation_refuses_admin_receipt_and_update(self):
        operation = 'd' * 32
        self.sup.maintenance = operation
        factory = Mock()
        with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease:
            coordinator = m.CanonicalCoordinator(self.config, self.sup, lease, updater_factory=factory)
            with self.assertRaisesRegex(RuntimeError, 'queued'):
                coordinator.poll_admin(before_update=Mock(side_effect=RuntimeError('queued')))
        factory.assert_not_called()
        self.assertFalse((self.root / 'admin-maintenance' / (operation + '.json')).exists())

    def test_missing_revocation_proof_refuses_admin_receipt_and_update(self):
        operation = 'd' * 32
        self.sup.maintenance = operation
        self.config['canonical_bot_enabled'] = True
        factory = Mock()
        with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease:
            coordinator = m.CanonicalCoordinator(self.config, self.sup, lease, updater_factory=factory)
            with self.assertRaisesRegex(RuntimeError, 'revocation is required'):
                coordinator.poll_admin(before_update=Mock(return_value=None))
        factory.assert_not_called()
        self.assertFalse((self.root / 'admin-maintenance' / (operation + '.json')).exists())

    def test_dispatcher_and_canonical_coordinator_share_owner_and_lease(self):
        operation = 'd' * 32
        self.sup.maintenance = operation
        self.config['canonical_bot_enabled'] = True
        updater = Mock()
        events = []
        updater.run.side_effect = lambda **kwargs: events.append('update') or {'phase': 'ready'}
        with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease:
            consumer = Mock()
            consumer.root, consumer.held_lock = self.root, lease
            consumer.backend.supervisor = self.sup
            consumer.binding, consumer.blocked = {'target_type': 'canonical'}, False
            def revoke():
                events.append('revoke')
                consumer.blocked = True
                return m.core._BotRevocation(self.sup, lease)
            consumer.revoke_for_update.side_effect = revoke
            def coordinator(config, owner, held):
                self.assertIs(owner, self.sup)
                self.assertIs(held, lease)
                return m.CanonicalCoordinator(config, owner, held,
                    updater_factory=lambda config, supervisor: updater)
            dispatcher = bot.OwnerDispatcher(self.sup, consumer, lease, coordinator_factory=coordinator)
            with patch.object(m.core, 'exclusive_lock', side_effect=AssertionError('lock reacquired')):
                self.assertEqual(dispatcher.tick(), 'canonical-update')
                self.assertEqual(dispatcher.tick(), 'blocked')
        self.assertEqual(events, ['revoke', 'update'])
        consumer.advertise.assert_not_called()
        consumer.consume_once.assert_not_called()
        self.assertIsInstance(updater.run.call_args.kwargs['bot_revocation'], m.core._BotRevocation)

    def test_canonical_update_refuses_missing_or_stale_bot_revocation(self):
        self.config['canonical_bot_enabled'] = True
        with m.core.exclusive_lock(self.root/'supervisor.lock') as lease:
            with self.assertRaisesRegex(RuntimeError, 'revocation is required'):
                self.updater.run(held_lock=lease)
            foreign = m.core.Supervisor.__new__(m.core.Supervisor)
            with self.assertRaisesRegex(RuntimeError, 'revocation does not match'):
                self.updater.run(held_lock=lease, bot_revocation=m.core._BotRevocation(foreign, lease))
        self.assertNotIn('save', self.events)
        self.assertNotIn('compile', self.events)

    def test_owner_loss_before_acceptance_leaves_no_receipt_or_mutation(self):
        operation = 'd' * 32
        self.sup.maintenance = operation
        factory = Mock()
        with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease:
            coordinator = m.CanonicalCoordinator(self.config, self.sup, lease, updater_factory=factory)
            with patch.object(self.sup, 'require_owned_session', side_effect=[None, RuntimeError('owner lost')]), \
                 patch.object(m.core, 'query') as query, \
                 self.assertRaisesRegex(RuntimeError, 'owner lost'):
                coordinator.poll_admin()
        self.assertFalse((self.root / 'admin-maintenance' / (operation + '.json')).exists())
        factory.assert_not_called()
        query.assert_not_called()

    def test_same_process_direct_update_uses_bound_owner_and_lock(self):
        updater = Mock()
        updater.run.return_value = {'phase':'ready'}
        factory = Mock(return_value=updater)
        with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease:
            coordinator = m.CanonicalCoordinator(self.config, self.sup, lease, updater_factory=factory)
            with patch.object(m.core, 'exclusive_lock', side_effect=AssertionError('lock reacquired')):
                self.assertEqual(coordinator.update_once(), {'phase':'ready'})
            factory.assert_called_once_with(self.config, supervisor=self.sup)
            updater.run.assert_called_once_with(held_lock=lease)

    def test_same_process_coordinator_runs_real_updater_with_inert_effects(self):
        self.sup.maintenance = 'd' * 32
        self.sup.clients = 2
        with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease:
            coordinator = m.CanonicalCoordinator(self.config, self.sup, lease,
                                                updater_factory=lambda config, supervisor: self.updater)
            with patch.object(m.core, 'exclusive_lock', side_effect=AssertionError('lock reacquired')):
                result = coordinator.poll_admin()
            self.assertEqual(result['phase'], 'ready')
            self.assertEqual(self.events.count('save'), 1)
            self.assertEqual(self.events.count('load'), 1)
            self.assertEqual(json.loads((self.root / 'admin-maintenance' / ('d' * 32 + '.json')).read_text())['phase'], 'complete')

    def test_updater_requires_live_lock_even_for_injected_owner(self):
        updater = m.CanonicalUpdater(self.config, supervisor=self.sup, guard=self.guard, quiet=self.quiet)
        with patch.object(m.core, 'query') as query:
            with self.assertRaisesRegex(RuntimeError, 'lock lease required'):
                updater.run()
            query.assert_not_called()

    def test_real_supervisor_launch_and_coordinator_share_one_owner(self):
        # Only the OS process and status transports are injected. All state,
        # lock and publication paths use this same Supervisor instance.
        owner = m.core.Supervisor(self.config)
        child = Mock(pid=123, poll=Mock(return_value=None))
        status = self.sup.status()
        status['maintenance_operation'] = 'd' * 32
        manifest = {'revision':self.old, 'map':'NOMADS_GAIA', 'binaries':self.state['binaries']}
        updater = Mock()
        updater.run.return_value = {'phase':'ready'}
        factory = Mock(return_value=updater)
        with patch.object(m.core.socket, 'socket'), \
                patch.object(m.core.subprocess, 'Popen', return_value=child), \
                patch.object(m.core, 'process_identity', return_value=456), \
                patch.object(owner, 'status', return_value=status), \
                patch.object(m.core, 'query') as query:
            with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease:
                owner.launch_prepared(self.game, manifest, None, 'c' * 32)
                self.assertIs(owner.child, child)
                self.assertEqual(owner.owned_session, 'e' * 32)
                coordinator = m.CanonicalCoordinator(self.config, owner, lease, updater_factory=factory)
                with patch.object(m.core, 'exclusive_lock', side_effect=AssertionError('lock reacquired')):
                    self.assertEqual(coordinator.poll_admin(), {'phase':'ready'})
                factory.assert_called_once_with(self.config, supervisor=owner)
                updater.run.assert_called_once_with(admin_operation='d' * 32, expected_session='e' * 32, held_lock=lease)
            query.assert_not_called()

    def test_same_process_coordinator_refuses_unowned_or_replaced_session(self):
        self.sup.maintenance = 'd' * 32
        factory = Mock()
        with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease:
            self.sup.child = None
            with self.assertRaisesRegex(RuntimeError, 'same-process supervisor owner'):
                m.CanonicalCoordinator(self.config, self.sup, lease, updater_factory=factory)
            self.sup.child = Mock(pid=123)
            coordinator = m.CanonicalCoordinator(self.config, self.sup, lease, updater_factory=factory)
            status = self.sup.status()
            status['session'] = 'f' * 32
            with patch.object(self.sup, 'status', return_value=status):
                with self.assertRaisesRegex(RuntimeError, 'session changed'):
                    coordinator.poll_admin()
            with patch.object(self.sup, 'alive', side_effect=[True, False]):
                with self.assertRaisesRegex(RuntimeError, 'exited before listener verification'):
                    coordinator.poll_admin()
        factory.assert_not_called()
        self.assertFalse((self.root / 'admin-maintenance').exists())

    def test_same_process_coordinator_does_not_signal_replacement_on_failure(self):
        self.sup.maintenance = 'd' * 32
        updater = Mock()
        def fail(**_kwargs):
            self.sup.owned_session = 'f' * 32
            raise RuntimeError('injected failure')
        updater.run.side_effect = fail
        with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease, patch.object(m.core, 'query') as query:
            coordinator = m.CanonicalCoordinator(self.config, self.sup, lease,
                                                updater_factory=lambda config, supervisor: updater)
            with self.assertRaisesRegex(RuntimeError, 'injected failure'):
                coordinator.poll_admin()
            query.assert_not_called()
        receipt = self.root / 'admin-maintenance' / ('d' * 32 + '.json')
        self.assertEqual(json.loads(receipt.read_text())['phase'], 'failed')

    def test_listener_change_blocks_maintenance_failure_signal(self):
        self.sup.maintenance = 'd' * 32
        self.listener_observation.side_effect = [None, None, None, RuntimeError('listener changed')]
        updater = Mock()
        updater.run.side_effect = RuntimeError('injected failure')
        with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease, patch.object(m.core, 'query') as query:
            coordinator = m.CanonicalCoordinator(self.config, self.sup, lease,
                                                updater_factory=lambda config, supervisor: updater)
            with self.assertRaisesRegex(RuntimeError, 'injected failure'):
                coordinator.poll_admin()
            query.assert_not_called()
        receipt = self.root / 'admin-maintenance' / ('d' * 32 + '.json')
        self.assertEqual(json.loads(receipt.read_text())['phase'], 'failed')

    def test_lost_lock_preserves_accepted_receipt_and_sends_no_signal(self):
        self.sup.maintenance = 'd' * 32
        updater = Mock()
        with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease, patch.object(m.core, 'query') as query:
            def lose_lock(**_kwargs):
                lease.active = False
                raise RuntimeError('injected interruption')
            updater.run.side_effect = lose_lock
            coordinator = m.CanonicalCoordinator(self.config, self.sup, lease,
                                                updater_factory=lambda config, supervisor: updater)
            with self.assertRaisesRegex(RuntimeError, 'lock is not held'):
                coordinator.poll_admin()
            query.assert_not_called()
        receipt = self.root / 'admin-maintenance' / ('d' * 32 + '.json')
        self.assertEqual(json.loads(receipt.read_text())['phase'], 'accepted')

    def test_same_process_coordinator_rejects_foreign_or_missing_lock(self):
        with m.core.exclusive_lock(self.root / 'other.lock') as foreign:
            with self.assertRaisesRegex(RuntimeError, 'lock is not held'):
                m.CanonicalCoordinator(self.config, self.sup, foreign)
        with self.assertRaisesRegex(RuntimeError, 'lock lease required'):
            m.CanonicalCoordinator(self.config, self.sup, None)

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
        self.assertIn('--single-branch', self.clone_arguments)
        self.assertEqual(self.clone_arguments[self.clone_arguments.index('--branch') + 1], 'master')
        self.assertEqual(protected, self.updater.protected_config())
        self.assertEqual(originals, [(self.game / p).read_bytes() for p in ('civ13.dme', 'UI/crafting-atlas.json')])
        self.assertEqual(self.sup.state['phase'], 'ready')
        self.assertEqual((self.root / 'events.jsonl').read_text().count('cycle_complete'), 1)
        self.assertFalse((self.root / 'runs').exists())
        self.assertFalse((self.root / 'builds').exists())
        self.assertEqual(self.git('branch', '--show-current').strip(), 'master')
        self.assertEqual(self.git('status', '--porcelain'), ' M config/host.txt\n')

    def test_v2_restart_preserves_pinned_binaries_and_never_updates(self):
        self.config['canonical_bot_enabled'] = True
        originals = {name: (self.game / name).read_bytes() for name in ('civ13.dmb', 'civ13.rsc')}
        first_effect = Mock()
        with patch.object(self.updater, 'build', side_effect=AssertionError('unexpected build')), \
                patch.object(self.updater, 'switch_build', side_effect=AssertionError('unexpected binary switch')):
            result = self.updater.run(bot_action='restart', bot_operation='a' * 32, before_effect=first_effect)
        first_effect.assert_called_once()
        self.assertEqual(result['phase'], 'ready')
        self.assertEqual(result['revision'], self.old)
        self.assertEqual(originals, {name: (self.game / name).read_bytes() for name in originals})
        self.assertNotIn('source-gate', self.events)
        self.assertNotIn('compile', self.events)
        self.assertEqual(self.events[:2], ['save', 'exit'])
        self.assertIn('load', self.events)

    def test_v2_canonical_actions_are_disabled_without_explicit_flag(self):
        with self.assertRaisesRegex(RuntimeError, 'Invalid fixed bot operation'):
            self.updater.run(bot_action='restart', bot_operation='a' * 32, before_effect=Mock())
        self.assertNotIn('save', self.events)

    def test_v2_save_stop_retains_generation_and_old_artifact_archive(self):
        self.config['canonical_bot_enabled'] = True
        result = self.updater.run(bot_action='save-stop', bot_operation='a' * 32, before_effect=Mock())
        self.assertEqual(result['phase'], 'stopped-for-repin')
        self.assertEqual(self.sup.state['phase'], 'stopped')
        self.assertTrue(Path(self.updater.transaction['previous_artifacts']).is_file())
        self.assertTrue((Path(self.updater.transaction['backup']) / 'receipt.json').is_file())
        self.assertNotIn('compile', self.events)
        self.assertNotIn('load', self.events)

    def test_v2_expiry_before_first_effect_keeps_original_binary_and_world(self):
        self.config['canonical_bot_enabled'] = True
        original = (self.game / 'civ13.dmb').read_bytes()
        with self.assertRaisesRegex(RuntimeError, 'expired'):
            self.updater.run(bot_action='restart', bot_operation='a' * 32,
                             before_effect=Mock(side_effect=RuntimeError('expired')))
        self.assertEqual((self.game / 'civ13.dmb').read_bytes(), original)
        self.assertTrue(self.sup.running)
        self.assertNotIn('save', self.events)

    def canonical_binding(self, generation):
        return {'target_type': 'canonical', 'supervisor_root': str(self.root),
                'runtime_directory': str(self.game), 'repository': str(self.game), 'daemon': str(self.daemon),
                'expected': {'revision': self.old, 'map': 'NOMADS_GAIA', 'generation': generation,
                             'dmb_sha256': self.state['binaries']['civ13.dmb'],
                             'rsc_sha256': self.state['binaries']['civ13.rsc']}}

    def bot_backend(self, binding, lease):
        self.config['canonical_bot_enabled'] = True
        return m.CanonicalBotBackend(self.config, binding, self.sup, lease,
            guard=lambda *_args, **_kwargs: {'commit': self.old},
            updater_factory=lambda config, supervisor: self.updater)

    def test_canonical_bot_restart_uses_same_owner_and_preserves_v2_pins(self):
        generation = 'round-v2:' + 'b' * 32
        self.sup.state['generation'] = generation
        m.core.write_json(self.sup.state_path, self.sup.state)
        binding = self.canonical_binding(generation)
        originals = {name: (self.game / name).read_bytes() for name in ('civ13.dmb', 'civ13.rsc')}
        with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease:
            backend = self.bot_backend(binding, lease)
            before = backend.observe()
            result = backend.execute('restart', 'a' * 32, before, before_effect=Mock())
        self.assertEqual(result['restored_generation'], result['saved_generation'])
        self.assertNotEqual(result['after']['creation_filetime'], before['creation_filetime'])
        self.assertEqual(originals, {name: (self.game / name).read_bytes() for name in originals})
        self.assertNotIn('source-gate', self.events)
        self.assertNotIn('compile', self.events)

    def test_canonical_bot_ambiguous_save_preserves_world_journal_and_old_binary(self):
        generation = 'round-v2:' + 'b' * 32
        self.sup.state['generation'] = generation
        m.core.write_json(self.sup.state_path, self.sup.state)
        binding = self.canonical_binding(generation)
        old_binary = (self.game/'civ13.dmb').read_bytes()
        def ambiguous(operation, **kwargs):
            kwargs['before_mutation']()
            self.make_generation(operation)
            raise TimeoutError('save outcome unknown')
        with m.core.exclusive_lock(self.root/'supervisor.lock') as lease:
            backend = self.bot_backend(binding, lease)
            before = backend.observe()
            with patch.object(self.sup, 'stop_saved', side_effect=ambiguous), \
                    self.assertRaisesRegex(TimeoutError, 'outcome unknown'):
                backend.execute('restart', 'a'*32, before, before_effect=Mock())
        self.assertTrue(self.sup.running)
        self.assertEqual((self.game/'civ13.dmb').read_bytes(), old_binary)
        self.assertTrue((self.game/'map_saves/save_complete.txt').is_file())
        self.assertEqual(json.loads((self.root/'update-state.json').read_text())['phase'], 'failed')
        self.assertTrue((self.root/'HALTED.json').is_file())
        self.assertNotIn('compile', self.events)
        self.assertNotIn('load', self.events)

    def test_canonical_bot_saved_stop_requires_repin_before_saved_start(self):
        generation = 'round-v2:' + 'b' * 32
        self.sup.state['generation'] = generation
        m.core.write_json(self.sup.state_path, self.sup.state)
        binding = self.canonical_binding(generation)
        with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease:
            backend = self.bot_backend(binding, lease)
            before = backend.observe()
            stopped = backend.execute('save-stop', 'a' * 32, before, before_effect=Mock())
            self.assertIsNone(stopped['after'])
            with self.assertRaisesRegex(RuntimeError, 'binding differs'):
                backend.observe()
            binding['expected']['generation'] = stopped['saved_generation']
            reviewed = self.bot_backend(binding, lease)
            self.assertIsNone(reviewed.observe())
            started = reviewed.execute('start', 'f' * 32, None, before_effect=Mock())
        self.assertEqual(started['restored_generation'], stopped['saved_generation'])
        self.assertEqual(started['after']['dmb_sha256'], binding['expected']['dmb_sha256'])

    def test_canonical_saved_start_expiry_preserves_journal_and_backup(self):
        generation = 'round-v2:' + 'b' * 32
        self.sup.state['generation'] = generation
        m.core.write_json(self.sup.state_path, self.sup.state)
        binding = self.canonical_binding(generation)
        old_binary = (self.game / 'civ13.dmb').read_bytes()
        with m.core.exclusive_lock(self.root / 'supervisor.lock') as lease:
            backend = self.bot_backend(binding, lease)
            stopped = backend.execute('save-stop', 'a' * 32, backend.observe(), before_effect=Mock())
            binding['expected']['generation'] = stopped['saved_generation']
            reviewed = self.bot_backend(binding, lease)
            with self.assertRaisesRegex(RuntimeError, 'expired'):
                reviewed.execute('start', 'f' * 32, None, before_effect=Mock(side_effect=RuntimeError('expired')))
        self.assertEqual((self.game / 'civ13.dmb').read_bytes(), old_binary)
        self.assertFalse(self.sup.running)
        self.assertEqual(json.loads((self.root / 'update-state.json').read_text())['phase'], 'failed')
        self.assertTrue((self.root/'HALTED.json').is_file())
        self.assertTrue((self.root/'backups'/('a'*32)/'receipt.json').is_file())
        self.assertTrue((self.root/'updates'/('a'*32+'-artifacts.zip')).is_file())

    def initial_bot_binding(self):
        self.sup.state = {}
        self.sup.child = None
        self.sup.running = False
        self.sup.state_path.unlink()
        self.make_generation('e' * 32)
        generation = 'round-v2:' + 'c' * 32
        self.config['canonical_initial_start_enabled'] = True
        self.config['canonical_initial_generation'] = generation
        self.updater.quiet = Mock()
        return self.canonical_binding(generation)

    def test_canonical_initial_start_requires_explicit_matching_generation(self):
        binding = self.initial_bot_binding()
        for field, value in (('canonical_initial_start_enabled', False),
                             ('canonical_initial_generation', 'round-v2:' + 'f'*32)):
            previous = self.config[field]
            self.config[field] = value
            with self.subTest(field=field), m.core.exclusive_lock(self.root/'supervisor.lock') as lease:
                backend = self.bot_backend(binding, lease)
                with self.assertRaisesRegex(RuntimeError, 'disabled or lacks'):
                    backend.observe()
            self.config[field] = previous
        self.assertFalse(self.sup.state_path.exists())
        self.assertFalse((self.root/'update-state.json').exists())

    def test_canonical_initial_start_rejects_incomplete_save_without_writes(self):
        binding = self.initial_bot_binding()
        (self.game/'map_saves/restart_intent.json').unlink()
        with m.core.exclusive_lock(self.root/'supervisor.lock') as lease:
            backend = self.bot_backend(binding, lease)
            with self.assertRaises(FileNotFoundError):
                backend.observe()
        self.assertFalse(self.sup.state_path.exists())
        self.assertFalse((self.root/'update-state.json').exists())

    def test_canonical_initial_start_snapshots_save_and_old_binaries(self):
        binding = self.initial_bot_binding()
        before = (self.game/'civ13.dmb').read_bytes()
        with m.core.exclusive_lock(self.root/'supervisor.lock') as lease:
            backend = self.bot_backend(binding, lease)
            self.assertIsNone(backend.observe())
            result = backend.execute('start', 'a'*32, None, before_effect=Mock())
        self.assertEqual(result['restored_generation'], binding['expected']['generation'])
        self.assertEqual((self.game/'civ13.dmb').read_bytes(), before)
        self.assertTrue((self.root/'backups'/('a'*32)/'receipt.json').is_file())
        self.assertTrue((self.root/'updates'/('a'*32+'-artifacts.zip')).is_file())
        self.assertNotIn('compile', self.events)

    def test_canonical_only_initial_start_reuses_pinned_preservation_without_bot(self):
        binding = self.initial_bot_binding()
        self.config['canonical_bot_enabled'] = False
        self.config['canonical_owner_enabled'] = True
        expected = binding['expected']
        self.config.update(canonical_owner_revision=expected['revision'],
                           canonical_owner_dmb_sha256=expected['dmb_sha256'],
                           canonical_owner_rsc_sha256=expected['rsc_sha256'])
        before = (self.game/'civ13.dmb').read_bytes()
        with m.core.exclusive_lock(self.root/'supervisor.lock') as lease:
            with self.assertRaisesRegex(RuntimeError, 'disabled or lacks'):
                self.updater.validate_initial(expected=expected, held_lock=lease)
            for field in ('revision', 'dmb_sha256', 'rsc_sha256', 'map'):
                with self.subTest(field=field), self.assertRaisesRegex(RuntimeError, 'binding differs'):
                    self.updater.validate_initial(expected=dict(expected, **{field: 'wrong'}),
                                                  held_lock=lease, authority='owner')
            result = self.updater.start_initial(operation='a'*32, expected=expected, held_lock=lease,
                                                before_effect=Mock(), authority='owner')
        self.assertEqual(result['generation'], expected['generation'])
        self.assertEqual((self.game/'civ13.dmb').read_bytes(), before)
        self.assertTrue((self.root/'backups'/('a'*32)/'receipt.json').is_file())
        self.assertTrue((self.root/'updates'/('a'*32+'-artifacts.zip')).is_file())
        self.assertNotIn('compile', self.events)

    def test_canonical_initial_start_expiry_preserves_original_save(self):
        binding = self.initial_bot_binding()
        marker = (self.game/'map_saves/save_complete.txt').read_bytes()
        with m.core.exclusive_lock(self.root/'supervisor.lock') as lease:
            backend = self.bot_backend(binding, lease)
            with self.assertRaisesRegex(RuntimeError, 'expired'):
                backend.execute('start', 'a'*32, None, before_effect=Mock(side_effect=RuntimeError('expired')))
        self.assertFalse(self.sup.running)
        self.assertEqual((self.game/'map_saves/save_complete.txt').read_bytes(), marker)
        self.assertTrue((self.root/'backups'/('a'*32)/'receipt.json').is_file())
        self.assertTrue((self.root/'updates'/('a'*32+'-artifacts.zip')).is_file())
        self.assertTrue((self.root/'HALTED.json').is_file())

    def test_nonpersistent_save_is_retained_but_fresh_world_does_not_import(self):
        self.sup.persistence_mode = 0
        result = self.updater.run()
        self.assertFalse(result['restored'])
        self.assertIsNone(self.sup.state['generation'])
        self.assertEqual(list((self.game / 'map_saves').iterdir()), [])
        retained = Path(self.updater.transaction['retained_working_save'])
        self.assertTrue((retained / 'restart_intent.json').is_file())
        self.assertTrue((Path(self.updater.transaction['backup']) / 'receipt.json').is_file())
        self.assertEqual(self.sup.state['phase'], 'ready')

    def test_missing_or_invalid_mode_stops_before_save(self):
        for value in (None, '1', 2, True):
            self.sup.persistence_mode = value
            with self.subTest(value=value), self.assertRaisesRegex(RuntimeError, 'persistence mode'):
                self.updater.run()
            self.assertEqual(self.events, [])

    def test_mode_changed_before_save_sends_no_mutation(self):
        self.sup.persistence_mode = 0
        with patch.object(m.core, 'query') as query:
            with self.assertRaisesRegex(RuntimeError, 'mode changed'):
                m.core.Supervisor.stop_saved(self.sup, 'd' * 32, expected_session='e' * 32,
                                            expected_persistence=1)
            query.assert_not_called()

    def test_save_acknowledgement_must_match_bound_mode(self):
        with patch.object(m.core, 'query', return_value={'operation': 'd' * 32, 'persistence_mode': 0}) as query:
            with self.assertRaisesRegex(RuntimeError, 'did not bind persistence mode'):
                m.core.Supervisor.stop_saved(self.sup, 'd' * 32, expected_session='e' * 32,
                                            expected_persistence=1)
            query.assert_called_once_with(1714, 'a' * 32, 'save_shutdown', 'd' * 32, 'e' * 32, 1)
        self.assertTrue(self.sup.running)

    def test_existing_transport_encodes_explicit_zero_mode(self):
        body = b'\x06{"ok":1}\x00'
        class Connection:
            def __init__(self):
                self.response = bytearray(b'\x00\x83' + struct.pack('>H', len(body)) + body)
                self.sent = b''
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def sendall(self, data): self.sent = data
            def recv(self, count):
                data = bytes(self.response[:count])
                del self.response[:count]
                return data
        connection = Connection()
        with patch.object(m.core.socket, 'create_connection', return_value=connection):
            self.assertEqual(m.core.query(1714, 'a' * 32, 'save_shutdown', 'd' * 32, 'e' * 32, 0), {'ok': 1})
        self.assertIn(b'expected_persistence=0', connection.sent)

    def test_compile_failure_never_switches_old_binaries(self):
        old = {name: (self.game / name).read_bytes() for name in ('civ13.dmb', 'civ13.rsc')}
        self.sup.fail_compile = True
        with self.assertRaisesRegex(RuntimeError, 'compiler failure'):
            self.updater.run()
        self.assertEqual(old, {name: (self.game / name).read_bytes() for name in old})
        self.assertNotIn('load', self.events)

    def test_partial_binary_switch_halts_with_recovery_archive(self):
        real_replace = m.os.replace
        def fail_second(source, destination):
            if Path(destination) == self.game / 'civ13.rsc':
                raise OSError('injected switch failure')
            return real_replace(source, destination)
        with patch.object(m.os, 'replace', side_effect=fail_second):
            with self.assertRaisesRegex(OSError, 'switch failure'):
                self.updater.run()
        self.assertNotIn('load', self.events)
        self.assertTrue(Path(self.updater.transaction['previous_artifacts']).is_file())
        self.assertEqual(self.updater.transaction['failed_phase'], 'switching')
        self.assertTrue((self.root / 'HALTED.json').exists())

    def test_changed_canonical_binary_is_not_overwritten(self):
        self.sup.damage_old_binary = True
        with self.assertRaisesRegex(RuntimeError, 'artifacts changed'):
            self.updater.run()
        self.assertEqual((self.game / 'civ13.dmb').read_bytes(), b'unexpected concurrent replacement')
        self.assertNotIn('load', self.events)

    def test_changed_staged_source_refuses_candidate_before_switch(self):
        self.sup.damage_staged_source = True
        old = (self.game / 'civ13.dmb').read_bytes()
        with self.assertRaisesRegex(RuntimeError, 'Staged source has unexpected edits'):
            self.updater.run()
        self.assertEqual((self.game / 'civ13.dmb').read_bytes(), old)
        self.assertNotIn('load', self.events)

    def test_staged_edit_before_freezing_is_refused(self):
        self.sup.damage_before_freeze = True
        with self.assertRaisesRegex(RuntimeError, 'Staged source has unexpected edits'):
            self.updater.run()
        self.assertNotIn('compile', self.events)
        self.assertNotIn('load', self.events)

    def test_derived_dme_edit_before_freezing_is_refused(self):
        old = {name: (self.game / name).read_bytes() for name in ('civ13.dmb', 'civ13.rsc')}
        self.sup.damage_dme_before_freeze = True
        with self.assertRaisesRegex(RuntimeError, 'Staged DME changed'):
            self.updater.run()
        self.assertEqual(old, {name: (self.game / name).read_bytes() for name in old})
        self.assertNotIn('compile', self.events)
        self.assertNotIn('load', self.events)

    def test_recovery_archive_damage_before_switch_refuses_replacement(self):
        old = {name: (self.game / name).read_bytes() for name in ('civ13.dmb', 'civ13.rsc')}
        self.sup.damage_archive_during_compile = True
        with self.assertRaisesRegex(RuntimeError, 'Previous artifact archive changed'):
            self.updater.run()
        self.assertEqual(old, {name: (self.game / name).read_bytes() for name in old})
        self.assertNotIn('load', self.events)

    def test_direct_atlas_edit_during_generation_is_refused(self):
        old = {name: (self.game / name).read_bytes() for name in ('civ13.dmb', 'civ13.rsc')}
        self.sup.damage_atlas_before_freeze = True
        with self.assertRaisesRegex(RuntimeError, 'Staged source has unexpected edits'):
            self.updater.run()
        self.assertEqual(old, {name: (self.game / name).read_bytes() for name in old})
        self.assertNotIn('compile', self.events)
        self.assertNotIn('load', self.events)

    def test_archive_contents_are_checked_even_when_digest_matches(self):
        old = {name: (self.game / name).read_bytes() for name in ('civ13.dmb', 'civ13.rsc')}
        self.sup.replace_archive_and_digest = True
        with self.assertRaisesRegex(RuntimeError, 'Previous artifact archive contents changed'):
            self.updater.run()
        self.assertEqual(old, {name: (self.game / name).read_bytes() for name in old})
        self.assertNotIn('load', self.events)

    def test_archive_rechecked_between_binary_replacements(self):
        old_rsc = (self.game / 'civ13.rsc').read_bytes()
        real_replace = m.os.replace
        def damage_after_first(source, destination):
            result = real_replace(source, destination)
            if Path(destination) == self.game / 'civ13.dmb':
                Path(self.updater.transaction['previous_artifacts']).write_bytes(b'damaged after first switch')
            return result
        with patch.object(m.os, 'replace', side_effect=damage_after_first):
            with self.assertRaisesRegex(RuntimeError, 'Previous artifact archive changed'):
                self.updater.run()
        self.assertEqual((self.game / 'civ13.rsc').read_bytes(), old_rsc)
        self.assertEqual(self.updater.transaction['failed_phase'], 'switching')
        self.assertTrue((self.root / 'HALTED.json').exists())
        self.assertNotIn('load', self.events)

    def test_invalid_generated_atlas_refuses_compile_and_switch(self):
        old = {name: (self.game / name).read_bytes() for name in ('civ13.dmb', 'civ13.rsc')}
        self.sup.invalid_generated_atlas = True
        with self.assertRaisesRegex(RuntimeError, 'Generated atlas is not valid JSON'):
            self.updater.run()
        self.assertEqual(old, {name: (self.game / name).read_bytes() for name in old})
        self.assertNotIn('compile', self.events)
        self.assertNotIn('load', self.events)

    def test_fresh_launch_with_wrong_mode_never_publishes_ready(self):
        self.sup.persistence_mode = 0
        self.sup.mode_after_launch = 1
        with self.assertRaisesRegex(RuntimeError, 'mode'):
            self.updater.run()
        self.assert_no_ready_publication()

    def test_dry_run_never_queries_or_constructs_supervisor(self):
        path = self.base / 'config.json'
        path.write_text(json.dumps(self.config))
        output = io.StringIO()
        with patch.object(sys, 'argv', ['canonical_update.py', 'dry-run', '--config', str(path)]), \
             patch.object(m.core, 'Supervisor') as supervisor, patch.object(m.core, 'query') as query, \
             redirect_stdout(output):
            m.main()
        supervisor.assert_not_called()
        query.assert_not_called()
        result = json.loads(output.getvalue())
        self.assertIn('unknown', result['persistence_mode'])
        self.assertIn('stage and validate build', result['plan'])

    def test_standalone_mutating_cli_rejects_without_creating_owner(self):
        path = self.base / 'config.json'
        path.write_text(json.dumps(self.config))
        for action in ('watch-admin', 'update-once'):
            with self.subTest(action=action), \
                 patch.object(sys, 'argv', ['canonical_update.py', action, '--config', str(path)]), \
                 patch.object(m.core, 'Supervisor') as supervisor, patch.object(m.core, 'query') as query, \
                 self.assertRaises(SystemExit) as stopped:
                m.main()
            self.assertEqual(stopped.exception.code, 2)
            supervisor.assert_not_called()
            query.assert_not_called()
        self.assertFalse((self.root / 'HALTED.json').exists())

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

    def test_upstream_configuration_change_refused_before_fast_forward(self):
        (self.dev / 'config/local-options.txt').write_text('upstream changed config')
        self.git('add', 'config/local-options.txt', cwd=self.dev)
        self.git('commit', '-m', 'change config', cwd=self.dev)
        self.git('push', 'origin', 'master', cwd=self.dev)
        before = (self.game / 'config/local-options.txt').read_bytes()
        with self.assertRaisesRegex(RuntimeError, 'configuration changes'):
            self.updater.run()
        self.assertEqual(self.git('rev-parse', 'HEAD').strip(), self.old)
        self.assertEqual((self.game / 'config/local-options.txt').read_bytes(), before)
        self.assertNotIn('compile', self.events)
        self.assertNotIn('load', self.events)

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
