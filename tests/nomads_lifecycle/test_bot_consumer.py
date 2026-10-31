"""Pure consumer/backend contracts with inert files and injected native effects."""
import json
from pathlib import Path
import sys
import tempfile
import os
import subprocess
import time
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

SOURCE = Path(__file__).resolve().parents[2] / 'scripts/nomads-lifecycle'
sys.path.insert(0, str(SOURCE))
import bot_consumer as m
import prepared_backend as b
import supervisor as core
import canonical_update as canonical


class FakeBackend:
    def __init__(self, binding):
        self.binding = binding
        self.calls = []
        self.current = None
        self.error = None

    def master(self):
        self.calls.append('master')
        if self.error == 'offline':
            raise RuntimeError('offline')

    def observe(self):
        return self.current

    def process(self):
        return {'pid': 123, 'creation_filetime': '134367709910115498',
                'executable': self.binding['daemon'], 'working_directory': self.binding['runtime_directory'],
                'dmb_sha256': self.binding['expected']['dmb_sha256'], 'rsc_sha256': self.binding['expected']['rsc_sha256']}

    def execute(self, action, operation, before, *, before_effect):
        before_effect()
        self.calls.append(action)
        if self.error:
            raise RuntimeError('unknown')
        self.current = None if action == 'save-stop' else self.process()
        result = {'after': self.current, 'ready': action != 'save-stop'}
        if action != 'start':
            result.update(exit_acknowledged=True, save_complete=True,
                          saved_generation='round-v2:'+'d'*32, save_receipt_sha256='e'*64)
        if action != 'save-stop':
            result['restored_generation'] = 'round-v2:'+'d'*32 if action == 'restart' else self.binding['expected']['generation']
        return result


class ConsumerTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='native-consumer-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.run = self.root/'runs/owned'
        for name in ('software', 'runs/owned/config', 'bot-control', 'repository'):
            (self.root/name).mkdir(parents=True, exist_ok=True)
        for name in m.FILES:
            (self.root/'software'/name).write_text('inert '+name)
        for name in ('civ13.dmb', 'civ13.rsc'):
            (self.run/name).write_text('inert '+name)
        (self.root/'dd.exe').write_text('not executable')
        expected = {'revision': 'a'*40, 'map': 'NOMADS_GAIA', 'generation': 'round-v2:'+'b'*32,
                    'dmb_sha256': core.digest(self.run/'civ13.dmb'), 'rsc_sha256': core.digest(self.run/'civ13.rsc')}
        self.config = {'root': str(self.root), 'repository': str(self.root/'repository'), 'branch': 'master',
                'bind': '127.0.0.1', 'port': 1714, 'map': 'NOMADS_GAIA', 'daemon': str(self.root/'dd.exe'),
                'bot_control_protocol': m.PROTOCOL, 'bot_control_files': {name:core.digest(self.root/'software'/name) for name in sorted(m.FILES)}}
        self.config_path = self.root/'supervisor.json'
        self.config_path.write_text(json.dumps(self.config))
        settings = {'enabled': True, 'supervisor_root': str(self.root),
                'supervisor_sha256': core.digest(self.root/'software/supervisor.py'), 'guard_sha256': core.digest(self.root/'software/master_guard.py'),
                'config_sha256': core.digest(self.config_path), 'daemon': str(self.root/'dd.exe'),
                'daemon_sha256': core.digest(self.root/'dd.exe'), 'expected': expected}
        self.profile = {'schema':'civilizationbot.portable.v1', 'gitdir':str(self.root/'repository'),
                        'servers':{'test':{'enabled':True, 'basedir':str(self.run), 'ip':'127.0.0.1', 'port':1714, 'native_lifecycle':settings}}}
        self.profile_path = self.root/'portable.json'
        self.write_profile()
        binding, _ = m.binding(self.config_path, self.profile_path)
        self.backend = FakeBackend(binding)
        self.now = 1700000000
        self.consumer = m.Consumer(self.config_path, self.profile_path, self.backend, now=lambda: self.now)

    def write_profile(self):
        self.profile_path.write_text(json.dumps(self.profile))

    def canonical_fixture(self):
        game = self.root / 'canonical'
        root = game / 'data/desktop-supervisor'
        for path in (game / 'config', root / 'software', root / 'bot-control', root / 'runs'):
            path.mkdir(parents=True, exist_ok=True)
        for name in m.FILES | {'canonical_update.py'}:
            (root / 'software' / name).write_text('inert ' + name)
        for name in ('civ13.dmb', 'civ13.rsc'):
            (game / name).write_text('inert ' + name)
        config = {'root': str(root), 'repository': str(game), 'canonical_game_directory': str(game),
                  'config_directory': str(game / 'config'), 'canonical_update_enabled': True,
                  'canonical_bot_enabled': True, 'branch': 'master', 'bind': '127.0.0.1', 'port': 1714,
                  'map': 'NOMADS_GAIA', 'daemon': str(self.root/'dd.exe'), 'bot_control_protocol': m.PROTOCOL,
                  'bot_control_files': {name: core.digest(root/'software'/name) for name in sorted(m.FILES | {'canonical_update.py'})}}
        config_path = root / 'supervisor.json'
        config_path.write_text(json.dumps(config))
        settings = {'enabled': True, 'target_type': 'canonical', 'supervisor_root': str(root),
                    'supervisor_sha256': core.digest(root/'software/supervisor.py'),
                    'guard_sha256': core.digest(root/'software/master_guard.py'),
                    'config_sha256': core.digest(config_path), 'daemon': str(self.root/'dd.exe'),
                    'daemon_sha256': core.digest(self.root/'dd.exe'),
                    'expected': {'revision':'a'*40, 'map':'NOMADS_GAIA', 'generation':'round-v2:'+'b'*32,
                                 'dmb_sha256':core.digest(game/'civ13.dmb'), 'rsc_sha256':core.digest(game/'civ13.rsc')}}
        profile = {'schema':'civilizationbot.portable.v1', 'gitdir':str(game), 'servers':{'test':
                   {'enabled':True, 'basedir':str(game), 'ip':'127.0.0.1', 'port':1714, 'native_lifecycle':settings}}}
        profile_path = root/'profile.json'
        profile_path.write_text(json.dumps(profile))
        return game, root, config_path, profile_path, config, profile

    def test_canonical_target_is_explicit_fixed_and_default_disabled(self):
        game, root, config_path, profile_path, config, profile = self.canonical_fixture()
        bound, _ = m.binding(config_path, profile_path)
        self.assertEqual(bound['target_type'], 'canonical')
        self.assertEqual(bound['runtime_directory'], str(game))
        for field in ('canonical_bot_enabled', 'canonical_update_enabled'):
            changed = dict(config, **{field: False})
            config_path.write_text(json.dumps(changed))
            profile['servers']['test']['native_lifecycle']['config_sha256'] = core.digest(config_path)
            profile_path.write_text(json.dumps(profile))
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'disabled or mismatched'):
                m.binding(config_path, profile_path)
        config_path.write_text(json.dumps(config))
        profile['servers']['test']['native_lifecycle']['config_sha256'] = core.digest(config_path)
        for target in ('prepared', 'arbitrary'):
            profile['servers']['test']['native_lifecycle']['target_type'] = target
            profile_path.write_text(json.dumps(profile))
            with self.subTest(target=target), self.assertRaises(ValueError):
                m.binding(config_path, profile_path)

    def test_prepared_target_cannot_bypass_canonical_backend(self):
        self.config['canonical_game_directory'] = str(self.root/'repository')
        self.config_path.write_text(json.dumps(self.config))
        self.profile['servers']['test']['native_lifecycle']['config_sha256'] = core.digest(self.config_path)
        self.write_profile()
        with self.assertRaisesRegex(ValueError, 'config/run root mismatch'):
            m.binding(self.config_path, self.profile_path)

    def test_canonical_target_rejects_changed_paths_and_unpinned_backend(self):
        game, root, config_path, profile_path, config, profile = self.canonical_fixture()
        for field, value in (('canonical_game_directory', str(self.root/'repository')),
                             ('config_directory', str(self.root))):
            changed = dict(config, **{field:value})
            config_path.write_text(json.dumps(changed))
            profile['servers']['test']['native_lifecycle']['config_sha256'] = core.digest(config_path)
            profile_path.write_text(json.dumps(profile))
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'disabled or mismatched'):
                m.binding(config_path, profile_path)
        changed = dict(config, bot_control_files={name:value for name, value in config['bot_control_files'].items()
                                                 if name != 'canonical_update.py'})
        config_path.write_text(json.dumps(changed))
        profile['servers']['test']['native_lifecycle']['config_sha256'] = core.digest(config_path)
        profile_path.write_text(json.dumps(profile))
        with self.assertRaisesRegex(ValueError, 'source-pinned'):
            m.binding(config_path, profile_path)

    def packet(self, action='start'):
        cap = self.consumer.advertise()
        return {'protocol':m.PROTOCOL, 'operation':'f'*32, 'action':action, 'epoch':cap['epoch'],
                'sequence':cap['sequence'], 'binding_sha256':cap['binding_sha256'],
                'binding':self.consumer.binding, 'before':cap['process'],
                'issued_unix':self.now, 'expires_unix':self.now + 300}

    def publish(self, packet):
        m.create(self.root/'bot-control/pending.json', packet)
        m.create(self.root/'bot-control/request.json', packet)

    def test_complete_start_is_correlated_and_never_clears_bot_pending(self):
        packet = self.packet()
        self.publish(packet)
        self.assertTrue(self.consumer.consume_once())
        result = m.read(self.root/('bot-control/result-'+packet['operation']+'.json'))
        self.assertEqual(result['restored_generation'], self.consumer.binding['expected']['generation'])
        self.assertEqual(result['operation'], packet['operation'])
        self.assertTrue((self.root/'bot-control/pending.json').exists())
        self.assertFalse((self.root/'bot-control/request.json').exists())
        self.assertEqual(self.backend.calls.count('start'), 1)
        self.assertFalse(self.consumer.consume_once())

    def test_request_validation_blocks_nonce_binding_action_and_process_mutations(self):
        original = self.packet()
        for key, value in [('operation','../x'),('epoch','0'*32),('sequence',0),('action','shell'),('action','update'),
                           ('binding_sha256','0'*64),('before',{'pid':999})]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.consumer.validate(original | {key:value})
        for field in ('command', 'path', 'pid', 'url', 'executable'):
            with self.subTest(extra=field), self.assertRaises(ValueError):
                self.consumer.validate(original | {field:'anything'})
        self.assertNotIn('start', self.backend.calls)

    def test_version_one_and_invalid_lifetimes_are_rejected(self):
        packet = self.packet()
        old = {key: value for key, value in packet.items() if key not in ('issued_unix', 'expires_unix')}
        old['protocol'] = 'civilizationbot.native-supervisor.v1'
        invalid = [old, packet | {'issued_unix': True}, packet | {'issued_unix': self.now + 3},
                   packet | {'issued_unix': self.now - 301, 'expires_unix': self.now},
                   packet | {'expires_unix': self.now - 1}, packet | {'expires_unix': self.now + 301}]
        for value in invalid:
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.consumer.validate(value)
        self.now = float('nan')
        with self.assertRaises(ValueError):
            self.consumer.validate(packet)
        self.assertNotIn('start', self.backend.calls)

    def test_expiry_after_acceptance_preserves_evidence_without_mutation(self):
        packet = self.packet()
        self.publish(packet)
        original = self.backend.observe
        def delayed_observe():
            self.now += 301
            return original()
        self.backend.observe = delayed_observe
        with self.assertRaisesRegex(RuntimeError, 'outcome unknown'):
            self.consumer.consume_once()
        self.assertNotIn('start', self.backend.calls)
        self.assertTrue((self.root/'bot-control/inflight.json').exists())
        self.assertTrue((self.root/('bot-control/accepted-'+packet['operation']+'.json')).exists())
        self.assertTrue(m.read(self.root/'bot-control/consumer-state.json')['blocked'])

    def test_expiry_before_acceptance_retains_unaccepted_request(self):
        packet = self.packet()
        self.publish(packet)
        self.now += 301
        with self.assertRaisesRegex(RuntimeError, 'outcome unknown'):
            self.consumer.consume_once()
        self.assertTrue((self.root/'bot-control/request.json').exists())
        self.assertTrue((self.root/'bot-control/pending.json').exists())
        self.assertFalse((self.root/'bot-control/inflight.json').exists())
        self.assertNotIn('start', self.backend.calls)

    def test_spool_entrypoint_fails_closed_without_writer_verification(self):
        with patch.object(m.core, 'Supervisor') as supervisor, \
             patch.object(m.Consumer, 'advertise') as advertise, \
             self.assertRaisesRegex(RuntimeError, 'writer authorization cannot be verified'):
            m.main(self.config_path, self.profile_path)
        supervisor.assert_not_called()
        advertise.assert_not_called()

    def test_default_disabled_and_wrong_map_bind_or_source_are_rejected(self):
        self.profile['servers']['test']['native_lifecycle']['enabled'] = False
        self.write_profile()
        with self.assertRaises(RuntimeError):
            m.binding(self.config_path, self.profile_path)
        m.binding(self.config_path, self.profile_path, allow_disabled=True)
        self.profile['servers']['test']['native_lifecycle']['enabled'] = True
        self.write_profile()
        for name in ('software/supervisor.py','software/prepared_backend.py','software/master_guard.py','software/bot_consumer.py','runs/owned/civ13.dmb','dd.exe'):
            path = self.root/name
            original = path.read_bytes()
            path.write_bytes(b'changed')
            with self.subTest(name=name), self.assertRaises(ValueError):
                m.binding(self.config_path, self.profile_path)
            path.write_bytes(original)

    def test_halt_and_surviving_pending_refuse_consumer_restart(self):
        (self.root/'HALTED.json').write_text('preserve')
        with self.assertRaises(RuntimeError):
            m.Consumer(self.config_path, self.profile_path, self.backend)
        self.assertEqual((self.root/'HALTED.json').read_text(),'preserve')
        (self.root/'HALTED.json').unlink()  # Test-owned inert latch only.
        self.publish(self.packet())
        with self.assertRaisesRegex(RuntimeError,'survived restart'):
            m.Consumer(self.config_path, self.profile_path, self.backend)

    def test_failure_after_acceptance_latches_unknown_without_replay(self):
        self.publish(self.packet())
        self.backend.error = 'save failed'
        with self.assertRaisesRegex(RuntimeError,'outcome unknown'):
            self.consumer.consume_once()
        self.assertTrue((self.root/'bot-control/inflight.json').exists())
        self.assertTrue((self.root/'bot-control'/('accepted-'+'f'*32+'.json')).exists())
        self.assertTrue(m.read(self.root/'bot-control/consumer-state.json')['blocked'])
        self.assertFalse(self.consumer.consume_once())
        self.assertEqual(self.backend.calls.count('start'),1)

    def test_offline_before_acceptance_performs_no_native_action(self):
        packet = self.packet()
        self.publish(packet)
        self.backend.error = 'offline'
        with self.assertRaises(RuntimeError):
            self.consumer.consume_once()
        self.assertNotIn('start',self.backend.calls)

    def test_save_stop_advances_generation_and_cannot_restore_old_profile(self):
        self.backend.current = self.backend.process()
        self.publish(self.packet('save-stop'))
        self.consumer.consume_once()
        state = m.read(self.root/'bot-control/consumer-state.json')
        self.assertEqual(state['saved_generation'],'round-v2:'+'d'*32)
        self.assertTrue(self.consumer.blocked)
        # The bot acknowledges its own pending file after checking completion.
        (self.root/'bot-control/pending.json').unlink()
        with self.assertRaisesRegex(RuntimeError,'reconciliation'):
            m.Consumer(self.config_path,self.profile_path,self.backend)
        self.profile['servers']['test']['native_lifecycle']['expected']['generation'] = state['saved_generation']
        self.write_profile()
        next_consumer = m.Consumer(self.config_path,self.profile_path,self.backend)
        self.assertEqual(next_consumer.binding['expected']['generation'],state['saved_generation'])

    def test_failure_latch_preserves_prior_operation_and_generation(self):
        packet = self.packet()
        m.replace(self.root/'bot-control/consumer-state.json', {'sequence': self.consumer.sequence,
                  'blocked': False, 'binding_sha256': self.consumer.hash, 'last_operation': 'a'*32,
                  'saved_generation': self.consumer.binding['expected']['generation']})
        self.publish(packet)
        self.backend.error = 'unknown'
        with self.assertRaisesRegex(RuntimeError, 'outcome unknown'):
            self.consumer.consume_once()
        state = m.read(self.root/'bot-control/consumer-state.json')
        self.assertTrue(state['blocked'])
        self.assertEqual(state['last_operation'], 'a'*32)
        self.assertEqual(state['saved_generation'], self.consumer.binding['expected']['generation'])
        self.assertEqual(state['failed_operation'], packet['operation'])
        self.assertTrue((self.root/'bot-control/inflight.json').exists())

    def test_publication_lock_is_not_held_during_backend_execution(self):
        self.publish(self.packet())
        original = self.backend.execute
        def execute(*args, **kwargs):
            with core.exclusive_lock(self.root/'bot-control/adapter.lock'):
                return original(*args, **kwargs)
        self.backend.execute = execute
        self.consumer.consume_once()

    def test_same_owner_uses_held_supervisor_lock_without_reacquiring(self):
        original = core.exclusive_lock
        with original(self.root/'supervisor.lock') as lease:
            self.consumer.held_lock = lease
            def lock(path):
                if Path(path) == self.root/'supervisor.lock':
                    raise AssertionError('owner lock reacquired')
                return original(path)
            with patch.object(core, 'exclusive_lock', side_effect=lock):
                packet = self.packet()
                self.publish(packet)
                self.assertTrue(self.consumer.consume_once())
            self.assertEqual(self.backend.calls.count('start'), 1)
        with self.assertRaisesRegex(RuntimeError, 'lock is not held'):
            self.consumer.advertise()

    def test_canonical_update_revokes_old_capability_and_requires_repin(self):
        packet = self.packet()
        m.replace(self.root/'bot-control/consumer-state.json', {'sequence': self.consumer.sequence,
                  'blocked': False, 'binding_sha256': self.consumer.hash, 'last_operation': 'a'*32,
                  'saved_generation': self.consumer.binding['expected']['generation']})
        owner = core.Supervisor.__new__(core.Supervisor)
        owner.root = self.root
        self.backend.supervisor = owner
        with core.exclusive_lock(self.root/'supervisor.lock') as lease:
            self.consumer.held_lock = lease
            revocation = self.consumer.revoke_for_update()
            revocation.consume(owner, lease)
            with self.assertRaisesRegex(RuntimeError, 'revocation does not match'):
                revocation.consume(owner, lease)
        capability = m.read(self.root/'bot-control/capability.json')
        self.assertTrue(capability['busy'])
        self.assertFalse(capability['master_verified'])
        self.assertNotEqual(capability['epoch'], packet['epoch'])
        state = m.read(self.root/'bot-control/consumer-state.json')
        self.assertTrue(state['blocked'])
        self.assertEqual(state['last_operation'], 'a'*32)
        self.assertEqual(state['saved_generation'], self.consumer.binding['expected']['generation'])
        self.publish(packet)
        self.assertFalse(self.consumer.consume_once())
        self.assertTrue((self.root/'bot-control/request.json').exists())
        self.assertNotIn('start', self.backend.calls)

    def test_canonical_update_never_discards_queued_bot_evidence(self):
        packet = self.packet()
        self.publish(packet)
        owner = core.Supervisor.__new__(core.Supervisor)
        owner.root = self.root
        self.backend.supervisor = owner
        with core.exclusive_lock(self.root/'supervisor.lock') as lease:
            self.consumer.held_lock = lease
            with self.assertRaisesRegex(RuntimeError, 'requires reconciliation'):
                self.consumer.revoke_for_update()
        self.assertTrue((self.root/'bot-control/pending.json').exists())
        self.assertTrue((self.root/'bot-control/request.json').exists())
        self.assertFalse(self.consumer.blocked)

    def test_revocation_cannot_outlive_owner_lock(self):
        self.packet()
        owner = core.Supervisor.__new__(core.Supervisor)
        owner.root = self.root
        self.backend.supervisor = owner
        with core.exclusive_lock(self.root/'supervisor.lock') as lease:
            self.consumer.held_lock = lease
            revocation = self.consumer.revoke_for_update()
        with self.assertRaisesRegex(RuntimeError, 'lock is not held'):
            revocation.consume(owner, lease)

    def test_owner_main_injects_one_supervisor_and_lease_after_guard(self):
        owner, backend, consumer, dispatcher = Mock(), Mock(), Mock(), Mock()
        dispatcher.tick.side_effect = RuntimeError('synthetic halt')
        with patch.object(m, 'require_private_spool'), \
             patch.object(core, 'Supervisor', return_value=owner) as construct, \
             patch.object(b, 'PreparedBackend', return_value=backend) as backend_factory, \
             patch.object(m, 'Consumer', return_value=consumer) as consumer_factory, \
             patch.object(m, 'OwnerDispatcher', return_value=dispatcher) as dispatch_factory, \
             patch.object(m.time, 'sleep', side_effect=StopIteration('synthetic stop')), \
             self.assertRaises(StopIteration):
            m.main(self.config_path, self.profile_path)
        construct.assert_called_once_with(self.config)
        backend_factory.assert_called_once_with(self.config, self.consumer.binding, supervisor=owner)
        self.assertIs(consumer_factory.call_args.args[2], backend)
        self.assertIsInstance(consumer_factory.call_args.kwargs['held_lock'], core._HeldLock)
        self.assertFalse(consumer_factory.call_args.kwargs['held_lock'].active)
        self.assertIs(dispatch_factory.call_args.args[0], owner)
        self.assertIs(dispatch_factory.call_args.args[1], consumer)
        self.assertIs(dispatch_factory.call_args.args[2], consumer_factory.call_args.kwargs['held_lock'])
        owner.record.assert_called_once_with('dispatch_halted', error_class='RuntimeError')

    def test_dispatch_serializes_both_sources_and_blocks_stale_capability(self):
        packet = self.packet()
        owner = core.Supervisor.__new__(core.Supervisor)
        owner.root, owner.config, owner.state = self.root, self.config, {'phase':'ready'}
        self.backend.supervisor = owner
        self.consumer.binding['target_type'] = 'canonical'
        events = []
        coordinator = Mock()
        def update(*, before_update):
            before_update()
            events.append('update')
            return {'phase':'ready'}
        coordinator.poll_admin.side_effect = update
        with core.exclusive_lock(self.root/'supervisor.lock') as lease:
            self.consumer.held_lock = lease
            with patch.object(self.consumer, 'verify'):
                dispatcher = m.OwnerDispatcher(owner, self.consumer, lease,
                                               coordinator_factory=lambda config, supervisor, lock: coordinator)
                self.assertEqual(dispatcher.tick(), 'canonical-update')
                self.assertEqual(events, ['update'])
                self.publish(packet)
                self.assertEqual(dispatcher.tick(), 'blocked')
            self.assertTrue(m.read(self.root/'bot-control/consumer-state.json')['blocked'])
            self.assertTrue((self.root/'bot-control/request.json').exists())
            self.assertNotIn('start', self.backend.calls)
        with self.assertRaisesRegex(RuntimeError, 'lock is not held'):
            dispatcher.tick()

    def test_real_consumer_and_coordinator_share_owner_and_revoke_before_update(self):
        game, root, config_path, profile_path, config, _profile = self.canonical_fixture()
        binding, _ = m.binding(config_path, profile_path)
        owner = core.Supervisor.__new__(core.Supervisor)
        owner.root, owner.config, owner.state = root, config, {'phase':'ready'}
        owner.child, owner.token = Mock(), 'a'*32
        owner.alive = Mock(return_value=True)
        owner.require_owned_listener = Mock()
        owner.require_owned_session = Mock()
        owner.status = Mock(return_value={'session':'e'*32, 'maintenance_operation':'d'*32})
        backend = FakeBackend(binding)
        backend.supervisor = owner
        updater = Mock()
        events = []
        with core.exclusive_lock(root/'supervisor.lock') as lease:
            consumer = m.Consumer(config_path, profile_path, backend, held_lock=lease)
            old_capability = consumer.advertise()
            def update(**kwargs):
                capability = m.read(root/'bot-control/capability.json')
                self.assertTrue(capability['busy'])
                self.assertNotEqual(capability['epoch'], old_capability['epoch'])
                kwargs['bot_revocation'].consume(owner, lease)
                events.append('update')
                return {'phase':'ready'}
            updater.run.side_effect = update
            def coordinator(configuration, supervisor, held):
                self.assertIs(supervisor, owner)
                self.assertIs(held, lease)
                return canonical.CanonicalCoordinator(configuration, supervisor, held,
                    updater_factory=lambda configuration, supervisor: updater)
            dispatcher = m.OwnerDispatcher(owner, consumer, lease, coordinator_factory=coordinator)
            original_lock = core.exclusive_lock
            def no_reacquire(path):
                if Path(path) == root/'supervisor.lock':
                    raise AssertionError('lifetime lock was reacquired')
                return original_lock(path)
            with patch.object(core, 'exclusive_lock', side_effect=no_reacquire):
                self.assertEqual(dispatcher.tick(), 'canonical-update')
                self.assertEqual(dispatcher.tick(), 'blocked')
        self.assertEqual(events, ['update'])
        self.assertTrue(m.read(root/'bot-control/consumer-state.json')['blocked'])
        self.assertTrue((root/'admin-maintenance'/('d'*32+'.json')).is_file())

    def test_dispatch_rejects_another_owner_or_lease(self):
        owner = core.Supervisor.__new__(core.Supervisor)
        owner.root, owner.config, owner.state = self.root, self.config, {'phase':'ready'}
        self.backend.supervisor = object()
        with core.exclusive_lock(self.root/'supervisor.lock') as lease:
            self.consumer.held_lock = lease
            with self.assertRaisesRegex(RuntimeError, 'shared supervisor'):
                m.OwnerDispatcher(owner, self.consumer, lease)

    def test_dispatch_defers_while_bot_publication_lock_is_held(self):
        self.packet()
        owner = core.Supervisor.__new__(core.Supervisor)
        owner.root, owner.config, owner.state = self.root, self.config, {'phase':'ready'}
        self.backend.supervisor = owner
        self.consumer.binding['target_type'] = 'canonical'
        coordinator = Mock()
        coordinator.poll_admin.side_effect = lambda *, before_update: before_update()
        with core.exclusive_lock(self.root/'supervisor.lock') as lease:
            self.consumer.held_lock = lease
            dispatcher = m.OwnerDispatcher(owner, self.consumer, lease,
                                           coordinator_factory=lambda config, supervisor, lock: coordinator)
            with patch.object(self.consumer, 'verify'), core.exclusive_lock(self.root/'bot-control/adapter.lock'):
                self.assertEqual(dispatcher.tick(), 'deferred')
            self.assertFalse(self.consumer.blocked)
            self.assertFalse((self.root/'bot-control/consumer-state.json').exists())
            self.assertNotIn('start', self.backend.calls)

    def test_result_final_name_is_absent_until_complete_atomic_publication(self):
        final = self.root/'bot-control/result-test.json'
        original = m.create
        observations = []
        def create(path, value):
            observations.append(final.exists())
            original(path, value)
            observations.append(final.exists())
        with patch.object(m, 'create', side_effect=create):
            m.publish(final, {'complete':True,'operation':'f'*32})
        self.assertEqual(observations,[False,False])
        self.assertEqual(m.read(final),{'complete':True,'operation':'f'*32})
        with self.assertRaises(FileExistsError):
            m.publish(final, {'complete':False})
        self.assertTrue(m.read(final)['complete'])

    def test_php_publication_transition_contention_defers_without_acceptance(self):
        self.publish(self.packet())
        with core.exclusive_lock(self.root/'bot-control/adapter.lock'):
            self.assertFalse(self.consumer.consume_once())
        self.assertFalse(self.consumer.blocked)
        self.assertTrue((self.root/'bot-control/request.json').exists())
        self.assertTrue(self.consumer.consume_once())

    def test_shared_supervisor_contention_prevents_action(self):
        self.publish(self.packet())
        with core.exclusive_lock(self.root/'supervisor.lock'):
            with self.assertRaises(RuntimeError):
                self.consumer.consume_once()
        self.assertNotIn('start',self.backend.calls)

    def test_actual_php_adapter_and_python_consumer_roundtrip(self):
        bot = os.environ.get('CIV13_BOT_ADAPTER_ROOT')
        vendor = os.environ.get('CIV13_BOT_VENDOR')
        php = os.environ.get('CIV13_PHP')
        if not all((bot, vendor, php)):
            self.skipTest('Explicit reviewed PHP adapter/dependency inputs not supplied')
        self.consumer.now = time.time
        self.consumer.advertise()
        environment = {key: value for key, value in os.environ.items()
                       if key.upper() in {'SYSTEMROOT','WINDIR','PATH','TEMP','TMP','LD_LIBRARY_PATH','PHPRC','PHP_INI_SCAN_DIR'}}
        process = subprocess.Popen([php,str(Path(__file__).with_name('bot_peer.php')),bot,vendor,str(self.profile_path)],
                                   stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=environment)
        try:
            deadline = time.monotonic()+6
            while not (self.root/'bot-control/request.json').exists():
                if time.monotonic()>deadline or process.poll() is not None:
                    raise AssertionError('Inert PHP adapter did not publish its packet')
                time.sleep(.01)
            packet = m.read(self.root/'bot-control/request.json')
            self.assertEqual(packet['protocol'], m.PROTOCOL)
            self.assertEqual(packet['expires_unix'] - packet['issued_unix'], m.REQUEST_MAX_AGE_SECONDS)
            self.consumer.consume_once()
            output, error = process.communicate(timeout=10)
            self.assertEqual(process.returncode,0,error.decode(errors='replace'))
            result = json.loads(output)
            self.assertEqual(result['protocol'],m.PROTOCOL)
            self.assertEqual(result['restored_generation'],self.consumer.binding['expected']['generation'])
            self.assertFalse((self.root/'bot-control/pending.json').exists())
            self.assertEqual(self.backend.calls.count('start'),1)
        finally:
            if process.poll() is None:
                process.terminate()  # Exact inert PHP child handle owned by this test only.
                process.communicate(timeout=5)

    def test_actual_php_packet_expired_before_acceptance_preserves_both_records(self):
        bot = os.environ.get('CIV13_BOT_ADAPTER_ROOT')
        vendor = os.environ.get('CIV13_BOT_VENDOR')
        php = os.environ.get('CIV13_PHP')
        if not all((bot, vendor, php)):
            self.skipTest('Explicit reviewed PHP adapter/dependency inputs not supplied')
        self.consumer.now = time.time
        self.consumer.advertise()
        environment = {key: value for key, value in os.environ.items()
                       if key.upper() in {'SYSTEMROOT','WINDIR','PATH','TEMP','TMP','LD_LIBRARY_PATH','PHPRC','PHP_INI_SCAN_DIR'}}
        process = subprocess.Popen([php,str(Path(__file__).with_name('bot_peer.php')),bot,vendor,str(self.profile_path)],
                                   stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=environment)
        try:
            deadline = time.monotonic()+6
            while not (self.root/'bot-control/request.json').exists():
                if time.monotonic()>deadline or process.poll() is not None:
                    raise AssertionError('Inert PHP adapter did not publish its packet')
                time.sleep(.01)
            self.consumer.now = lambda: time.time() + m.REQUEST_MAX_AGE_SECONDS + 1
            with self.assertRaisesRegex(RuntimeError, 'outcome unknown'):
                self.consumer.consume_once()
            self.assertNotIn('start', self.backend.calls)
            self.assertTrue((self.root/'bot-control/request.json').exists())
            self.assertTrue((self.root/'bot-control/pending.json').exists())
            self.assertFalse((self.root/'bot-control/inflight.json').exists())
        finally:
            if process.poll() is None:
                process.terminate()  # Exact inert PHP child handle owned by this test only.
            process.communicate(timeout=5)

    def test_actual_php_canonical_binding_and_python_consumer_roundtrip(self):
        if os.environ.get('CIV13_BOT_CANONICAL_ADAPTER') != '1':
            self.skipTest('Paired canonical adapter is not explicitly selected')
        bot, vendor, php = (os.environ.get(name) for name in ('CIV13_BOT_ADAPTER_ROOT', 'CIV13_BOT_VENDOR', 'CIV13_PHP'))
        if not all((bot, vendor, php)):
            self.fail('Explicit canonical adapter/dependency inputs are required')
        game, root, config_path, profile_path, _config, _profile = self.canonical_fixture()
        binding, _ = m.binding(config_path, profile_path)
        backend = FakeBackend(binding)
        consumer = m.Consumer(config_path, profile_path, backend)
        consumer.advertise()
        environment = {key: value for key, value in os.environ.items()
                       if key.upper() in {'SYSTEMROOT','WINDIR','PATH','TEMP','TMP','LD_LIBRARY_PATH','PHPRC','PHP_INI_SCAN_DIR'}}
        process = subprocess.Popen([php, str(Path(__file__).with_name('bot_peer.php')), bot, vendor, str(profile_path)],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=environment)
        try:
            deadline = time.monotonic() + 6
            while not (root/'bot-control/request.json').exists():
                if time.monotonic() > deadline or process.poll() is not None:
                    raise AssertionError('Inert canonical PHP adapter did not publish its packet')
                time.sleep(.01)
            packet = m.read(root/'bot-control/request.json')
            self.assertEqual(packet['binding']['target_type'], 'canonical')
            self.assertEqual(packet['binding']['runtime_directory'], str(game))
            consumer.consume_once()
            output, error = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, error.decode(errors='replace'))
            self.assertEqual(json.loads(output)['restored_generation'], binding['expected']['generation'])
            self.assertEqual(backend.calls.count('start'), 1)
        finally:
            if process.poll() is None:
                process.terminate()  # Exact inert PHP child handle owned by this test only.
            process.communicate(timeout=5)


class BackendTests(unittest.TestCase):
    def test_prepared_start_checks_listener_and_session_before_ready(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            backend = b.PreparedBackend.__new__(b.PreparedBackend)
            backend.run, backend.daemon = root, root/'inert-dd'
            backend.binding = {'expected': {'map':'NOMADS_GAIA'}}
            backend.config = {'port':1714}
            backend.observe = Mock(return_value=None)
            backend.assert_closed = Mock()
            backend.manifest = Mock(return_value={'revision':'a'*40})
            backend.observe_process = Mock(return_value={'pid':123})
            sup = backend.supervisor = Mock()
            sup.state = {'host':{'pid':123}, 'backup':None}
            sup.alive.return_value = True
            sup.status.return_value = {'session':'f'*32}
            def startup(*args, readiness_check, before_spawn):
                before_spawn()
                readiness_check({'session':'e'*32})
            sup.launch_prepared.side_effect = startup
            with patch.object(core, 'validate_generation', return_value=({'generation':'round-v2:'+'b'*32}, [])), \
                 self.assertRaisesRegex(RuntimeError, 'session changed during binding'):
                backend.start('c'*32, 'round-v2:'+'b'*32, before_effect=lambda: None)
            backend.observe_process.assert_called_once()
            sup.status.assert_called_once()
            self.assertEqual(backend.observe.call_count, 1)

    def test_listener_table_requires_unique_identified_owner(self):
        address = SimpleNamespace(ip='127.0.0.1', port=1714)
        owned = SimpleNamespace(status='LISTEN', laddr=address, pid=123)
        b.require_unique_loopback_listener(123, 1714, [owned], [owned], 'LISTEN')
        with self.assertRaisesRegex(RuntimeError, 'ambiguous'):
            b.require_unique_loopback_listener(123, 1714, [owned, owned], [owned], 'LISTEN')
        for rows in ([], [SimpleNamespace(status='LISTEN', laddr=address, pid=None)],
                     [owned, SimpleNamespace(status='LISTEN', laddr=address, pid=999)]):
            with self.subTest(rows=rows), self.assertRaisesRegex(RuntimeError, 'ambiguous'):
                b.require_unique_loopback_listener(123, 1714, [owned], rows, 'LISTEN')

    @unittest.skipUnless(os.name == 'nt', 'Windows process observation wrapper')
    def test_listener_observation_rejects_other_or_unknown_owner(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            daemon = root/'inert-dd'
            daemon.write_bytes(b'inert')
            address = SimpleNamespace(ip='127.0.0.1', port=1714)
            owned = SimpleNamespace(status='LISTEN', laddr=address, pid=123)
            process = Mock()
            process.exe.return_value, process.cwd.return_value = str(daemon), str(root)
            process.net_connections.return_value = [owned]
            psutil = SimpleNamespace(CONN_LISTEN='LISTEN', Process=Mock(return_value=process),
                                     net_connections=Mock(return_value=[owned]))
            host = {'pid': 123, 'creation_filetime': 456}
            with patch.dict(sys.modules, {'psutil': psutil}), patch.object(core, 'process_identity', return_value=456):
                self.assertEqual(b.windows_observation(host, daemon, root, 1714)['pid'], 123)
                for owner in (None, 999):
                    psutil.net_connections.return_value = [SimpleNamespace(status='LISTEN', laddr=address, pid=owner)]
                    with self.subTest(owner=owner), self.assertRaisesRegex(RuntimeError, 'ambiguous'):
                        b.windows_observation(host, daemon, root, 1714)
                psutil.net_connections.side_effect = PermissionError('inaccessible')
                with self.assertRaises(PermissionError):
                    b.windows_observation(host, daemon, root, 1714)

    def test_restart_expiry_is_checked_only_before_first_effect(self):
        backend = b.PreparedBackend.__new__(b.PreparedBackend)
        before = {'pid': 123}
        generation = 'round-v2:' + 'a'*32
        backend.binding = {'expected': {'generation': generation}}
        backend.master = Mock()
        backend.observe = Mock(return_value=before)
        admission = Mock(side_effect=[None, RuntimeError('expired after stop')])
        def stop(_operation, _before, *, before_effect):
            before_effect()
            return generation, 'b'*64
        def start(_operation, _generation, *, before_effect):
            before_effect()
            return {'pid': 456}
        backend.stop, backend.start = stop, start
        result = backend.execute('restart', 'c'*32, before, before_effect=admission)
        self.assertEqual(result['after']['pid'], 456)
        admission.assert_called_once()

    def test_spawn_admission_failure_never_creates_child(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            run, config = root/'runs/owned', root/'config'
            run.mkdir(parents=True)
            config.mkdir()
            (config/'lifecycle-token.txt').write_text('a'*32)
            for name in ('civ13.dmb', 'civ13.rsc'):
                (run/name).write_bytes(b'inert')
            manifest = {'revision': 'b'*40, 'map': 'NOMADS_GAIA',
                        'binaries': {name: core.digest(run/name) for name in ('civ13.dmb', 'civ13.rsc')}}
            sup = core.Supervisor({'root':str(root), 'config_directory':str(config), 'port':1714,
                                   'bind':'127.0.0.1', 'map':'NOMADS_GAIA', 'daemon':'inert-dd'})
            with patch.object(core.socket, 'socket'), patch.object(core.subprocess, 'Popen') as spawn, \
                 self.assertRaisesRegex(RuntimeError, 'expired'):
                sup.launch_prepared(run, manifest, None, 'c'*32,
                                    before_spawn=Mock(side_effect=RuntimeError('expired')))
            spawn.assert_not_called()

    def test_observation_refuses_unbound_listener_session(self):
        with tempfile.TemporaryDirectory() as directory:
            run = Path(directory).resolve()
            expected = {'revision': 'a'*40, 'map': 'NOMADS_GAIA',
                        'dmb_sha256': 'b'*64, 'rsc_sha256': 'c'*64}
            binding = {'runtime_directory': str(run), 'daemon': str(run/'inert-dd'), 'expected': expected}
            sup = Mock()
            sup.state = {'phase': 'ready', 'revision': expected['revision'], 'map': expected['map'],
                         'host': {'pid': 123, 'creation_filetime': 456, 'workdir': str(run)}}
            sup.alive.return_value = True
            sup.status.return_value = {'session': 'd'*32}
            sup.require_owned_session.side_effect = RuntimeError('owner session changed')
            observe = Mock(return_value={'pid': 123})
            backend = b.PreparedBackend({'port': 1714}, binding, supervisor=sup, observe=observe)
            with patch.object(backend, 'manifest'), self.assertRaisesRegex(RuntimeError, 'session changed'):
                backend.observe()
            observe.assert_called_once()
            sup.require_owned_session.assert_called_once_with('d'*32)
            sup.accept_ready.assert_not_called()

    def test_gaia_save_requires_matching_complete_generation_and_intent(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            generation = 'round-v2:'+'b'*32
            (folder/'map.txt').write_text('NOMADS_GAIA')
            (folder/'round.json').write_text(json.dumps({'version':2,'generation':generation,'map':'NOMADS_GAIA','maxx':500,'maxy':350,'maxz':2}))
            (folder/'save_complete.txt').write_text(generation)
            (folder/'1.sav').write_bytes(b'one')
            (folder/'2.sav').write_bytes(b'two')
            intent = {'version':1,'generation':generation,'metadata':core.byond_text_md5(folder/'map.txt'),'round':core.byond_text_md5(folder/'round.json')}
            (folder/'restart_intent.json').write_text(json.dumps(intent))
            state, names = core.validate_generation(folder,expected_map='NOMADS_GAIA')
            self.assertEqual(state['generation'],generation)
            self.assertEqual(len(names),6)
            with self.assertRaises(RuntimeError):
                core.validate_generation(folder)  # Europe default cannot adopt Gaia silently.
            (folder/'restart_intent.json').unlink()
            with self.assertRaises(FileNotFoundError):
                core.validate_generation(folder,expected_map='NOMADS_GAIA')

    def test_existing_supervisor_prepared_start_uses_fixed_loopback_argv_and_readiness(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            run = root/'runs/owned'
            run.mkdir(parents=True)
            config = root/'server-config'
            config.mkdir()
            (config/'lifecycle-token.txt').write_text('a'*32)
            for name in ('civ13.dmb','civ13.rsc'):
                (run/name).write_bytes(b'inert fixture')
            revision, generation = 'b'*40, 'round-v2:'+'c'*32
            manifest = {'revision':revision,'map':'NOMADS_GAIA','binaries':{name:core.digest(run/name) for name in ('civ13.dmb','civ13.rsc')}}
            sup = core.Supervisor({'root':str(root),'config_directory':str(config),'port':1714,'bind':'127.0.0.1','map':'NOMADS_GAIA','daemon':'pinned-dd.exe'})
            status = {'ok':1,'ready':1,'busy':0,'restart_hold':0,'restart_intent':0,'error':None,'revision':revision,'map':'NOMADS_GAIA','generation':generation,'restart_import_complete':1,'session':'d'*32}
            with patch.object(core.subprocess,'Popen',return_value=Mock(pid=123)) as spawn, patch.object(core,'process_identity',return_value=456), patch.object(core.socket,'socket') as socket, patch.object(sup,'alive',return_value=True), patch.object(sup,'status',return_value=status), patch.object(sup, 'require_owned_listener'):
                sup.launch_prepared(run,manifest,generation,'e'*32)
            self.assertEqual(spawn.call_args.args[0],['pinned-dd.exe','civ13.dmb','1714','-trusted','-invisible','-close','-log','supervisor-runtime.log','-ip','127.0.0.1'])
            self.assertEqual(spawn.call_args.kwargs['cwd'],run)
            socket.return_value.__enter__.return_value.bind.assert_called_with(('127.0.0.1',1714))
            self.assertEqual(sup.state['phase'],'ready')

    def test_changed_master_blocks_all_native_work(self):
        backend = b.PreparedBackend.__new__(b.PreparedBackend)
        backend.binding = {'repository':'inert','expected':{'revision':'a'*40}}
        backend.config = {'git':'inert'}
        backend.guard = Mock(return_value={'commit':'b'*40})
        backend.observe = Mock()
        with self.assertRaises(RuntimeError):
            backend.execute('start','a'*32,None,before_effect=lambda: None)
        backend.observe.assert_not_called()

    def test_wrong_owner_blocks_authenticated_stop(self):
        backend = b.PreparedBackend.__new__(b.PreparedBackend)
        backend.observe = Mock(return_value={'pid':99})
        backend.supervisor = Mock()
        with self.assertRaises(RuntimeError):
            backend.stop('a'*32,{'pid':123},before_effect=lambda: None)
        backend.supervisor.stop_saved.assert_not_called()

    def test_fresh_prepared_backend_cannot_adopt_persisted_host(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config_dir = root / 'private-config'
            config_dir.mkdir()
            (config_dir / 'lifecycle-token.txt').write_text('a' * 32)
            config = {'root':str(root), 'config_directory':str(config_dir), 'port':1714}
            core.write_json(root / 'state.json', {'phase':'ready', 'revision':'a'*40,
                'map':'NOMADS_GAIA', 'host':{'pid':123, 'creation_filetime':456, 'workdir':str(root)}})
            observer = Mock()
            binding = {'runtime_directory':str(root), 'daemon':str(root / 'inert-dd')}
            with patch.object(core, 'Supervisor') as constructor, \
                    self.assertRaisesRegex(RuntimeError, 'same-process supervisor owner'):
                b.PreparedBackend(config, binding, observe=observer)
            constructor.assert_not_called()
            owner = core.Supervisor(config)
            backend = b.PreparedBackend(config, binding, supervisor=owner, observe=observer)
            with patch.object(backend, 'manifest'), patch.object(core, 'process_identity') as identity, \
                    patch.object(core, 'query') as query:
                with self.assertRaisesRegex(RuntimeError, 'helper_lost'):
                    backend.observe()
                identity.assert_not_called()
                query.assert_not_called()
                observer.assert_not_called()

    def test_loopback_native_process_identity_checks_are_injected_not_executed(self):
        backend = b.PreparedBackend.__new__(b.PreparedBackend)
        backend.master = Mock()
        backend.observe = Mock(return_value=None)
        backend.binding = {'expected':{'generation':'round-v2:'+'a'*32}}
        backend.start = Mock(return_value={'pid':123})
        admission = Mock()
        result = backend.execute('start','b'*32,None,before_effect=admission)
        backend.start.assert_called_once_with('b'*32,'round-v2:'+'a'*32,before_effect=admission)
        self.assertTrue(result['ready'])


if __name__ == '__main__':
    unittest.main()
