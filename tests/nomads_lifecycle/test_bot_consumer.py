"""Pure consumer/backend contracts with inert files and injected native effects."""
import json
from pathlib import Path
import sys
import tempfile
import os
import subprocess
import time
import unittest
from unittest.mock import Mock, patch

SOURCE = Path(__file__).resolve().parents[2] / 'scripts/nomads-lifecycle'
sys.path.insert(0, str(SOURCE))
import bot_consumer as m
import prepared_backend as b
import supervisor as core


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

    def execute(self, action, operation, before):
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
        self.consumer = m.Consumer(self.config_path, self.profile_path, self.backend)

    def write_profile(self):
        self.profile_path.write_text(json.dumps(self.profile))

    def packet(self, action='start'):
        cap = self.consumer.advertise()
        return {'protocol':m.PROTOCOL, 'operation':'f'*32, 'action':action, 'epoch':cap['epoch'],
                'sequence':cap['sequence'], 'binding_sha256':cap['binding_sha256'],
                'binding':self.consumer.binding, 'before':cap['process']}

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
        for key, value in [('operation','../x'),('epoch','0'*32),('sequence',0),('action','shell'),
                           ('binding_sha256','0'*64),('before',{'pid':999})]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.consumer.validate(original | {key:value})
        with self.assertRaises(ValueError):
            self.consumer.validate(original | {'command':'anything'})
        self.assertNotIn('start', self.backend.calls)

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

    def test_publication_lock_is_not_held_during_backend_execution(self):
        self.publish(self.packet())
        original = self.backend.execute
        def execute(*args):
            with core.exclusive_lock(self.root/'bot-control/adapter.lock'):
                return original(*args)
        self.backend.execute = execute
        self.consumer.consume_once()

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


class BackendTests(unittest.TestCase):
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
            with patch.object(core.subprocess,'Popen',return_value=Mock(pid=123)) as spawn, patch.object(core,'process_identity',return_value=456), patch.object(core.socket,'socket') as socket, patch.object(sup,'alive',return_value=True), patch.object(sup,'status',return_value=status):
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
            backend.execute('start','a'*32,None)
        backend.observe.assert_not_called()

    def test_wrong_owner_blocks_authenticated_stop(self):
        backend = b.PreparedBackend.__new__(b.PreparedBackend)
        backend.observe = Mock(return_value={'pid':99})
        backend.supervisor = Mock()
        with self.assertRaises(RuntimeError):
            backend.stop('a'*32,{'pid':123})
        backend.supervisor.stop_saved.assert_not_called()

    def test_loopback_native_process_identity_checks_are_injected_not_executed(self):
        backend = b.PreparedBackend.__new__(b.PreparedBackend)
        backend.master = Mock()
        backend.observe = Mock(return_value=None)
        backend.binding = {'expected':{'generation':'round-v2:'+'a'*32}}
        backend.start = Mock(return_value={'pid':123})
        result = backend.execute('start','b'*32,None)
        backend.start.assert_called_once_with('b'*32,'round-v2:'+'a'*32)
        self.assertTrue(result['ready'])


if __name__ == '__main__':
    unittest.main()
