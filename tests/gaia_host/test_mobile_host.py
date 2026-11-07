"""Offline only: fake TLS/socket/host boundaries, no credentials or listeners."""
import hashlib
from http.client import HTTPMessage
import io
import json
from pathlib import Path
import ssl
import sys
import tempfile
import threading
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/gaia-host'))
import mobile_host as mobile


class FakeHost:
    def __init__(self):
        self.calls = []
        self.operation = {}
        self.busy = False
        self.failure = None

    def request(self, action):
        if self.busy:
            raise mobile.gaia_host.Refused('PRIVATE PATH / token')
        self.calls.append(action)
        if self.failure:
            raise self.failure
        self.busy = True
        self.operation = {'action': action, 'operation': 'a' * 32, 'phase': 'accepted'}
        return dict(self.operation, accepted=True)

    def status(self):
        return {'state': 'awake', 'busy': self.busy, 'world': {'clients': 3}, 'operation': self.operation}


class MobileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.host = FakeHost()
        self.now = 0
        self.controller = mobile.Controller(self.host, self.root, lambda: self.now)
        self.device = 'b' * 64  # inert identifier, not a credential

    def prepare(self, action='restart', device=None):
        return self.controller.prepare(device or self.device, action)['confirmation']

    def test_confirm_then_replay_dispatches_once_even_after_restart(self):
        token = self.prepare()
        first = self.controller.submit(self.device, 'restart', token)
        self.assertEqual(first['result'], 'accepted')
        self.controller = mobile.Controller(self.host, self.root)
        self.assertEqual(self.controller.submit(self.device, 'restart', token), first)
        self.assertEqual(self.host.calls, ['restart'])

    def test_real_host_request_uses_existing_detached_worker_and_lock(self):
        machine = Mock()
        machine.now.return_value = 123
        config = {'repository': str(self.root), 'state_dir': str(self.root / 'host-state'),
                  '_path': str(self.root / 'host-config'), 'port': 1714}
        host = mobile.gaia_host.Host(config, machine)
        host.precheck = Mock()  # no live process, save, credentials or port probes
        controller = mobile.Controller(host, self.root)
        token = controller.prepare(self.device, 'start')['confirmation']
        self.assertEqual(controller.submit(self.device, 'start', token)['result'], 'accepted')
        machine.detach.assert_called_once()
        argv = machine.detach.call_args.args[0]
        self.assertEqual(argv[-3:-1], ['--worker', 'start'])
        self.assertEqual(host.lock.read_text(), argv[-1])
        self.assertEqual(host.read_state()['operation'], argv[-1])
        fresh = mobile.Controller(host, self.root)
        fresh.submit(self.device, 'start', token)
        machine.detach.assert_called_once()

    def test_reconnect_reports_worker_result_and_retains_observed_completion(self):
        token = self.prepare()
        self.controller.submit(self.device, 'restart', token)
        self.host.operation['phase'] = 'done'
        self.host.busy = False
        self.controller = mobile.Controller(self.host, self.root)
        self.assertEqual(self.controller.status()['logs'][0]['progress']['phase'], 'done')
        self.host.operation = {'operation': 'c' * 32, 'phase': 'saving'}
        self.assertEqual(self.controller.status()['logs'][0]['progress']['phase'], 'done')

    def test_confirmation_bound_to_device_action_and_expiry(self):
        token = self.prepare()
        for device, action, candidate in [('c' * 64, 'restart', token), (self.device, 'stop', token),
                                           (self.device, 'restart', '../../file')]:
            with self.assertRaises(ValueError):
                self.controller.submit(device, action, candidate)
        self.now = 61
        with self.assertRaises(ValueError):
            self.controller.submit(self.device, 'restart', token)
        self.assertEqual(self.host.calls, [])

    def test_concurrent_double_submit_and_other_action(self):
        token = self.prepare()
        answers = []
        threads = [threading.Thread(target=lambda: answers.append(self.controller.submit(self.device, 'restart', token))) for _ in range(2)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()
        self.assertEqual(len(answers), 2)
        other = 'c' * 64
        result = self.controller.submit(other, 'stop', self.prepare('stop', other))
        self.assertEqual(result['result'], 'refused')
        self.assertEqual(self.host.calls, ['restart'])

    def test_uncertain_dispatch_is_reserved_and_blocks_new_actions(self):
        self.host.failure = OSError('private exception')
        token = self.prepare()
        self.assertEqual(self.controller.submit(self.device, 'restart', token)['result'], 'uncertain')
        self.assertEqual(self.controller.submit(self.device, 'restart', token)['result'], 'uncertain')
        with self.assertRaises(ValueError):
            self.controller.submit(self.device, 'start', self.prepare('start'))
        self.assertEqual(self.host.calls, ['restart'])

    def real_host(self, machine):
        config = {'repository': str(self.root), 'state_dir': str(self.root / 'host-state'),
                  '_path': str(self.root / 'host-config'), 'port': 1714}
        return mobile.gaia_host.Host(config, machine)

    def test_failure_before_host_lock_is_refused_and_does_not_block(self):
        machine = Mock()
        machine.now.return_value = 123
        host = self.real_host(machine)
        host.precheck = Mock(side_effect=RuntimeError('private precheck failure'))
        controller = mobile.Controller(host, self.root)
        token = controller.prepare(self.device, 'start')['confirmation']
        self.assertEqual(controller.submit(self.device, 'start', token)['result'], 'refused')
        self.assertFalse(host.lock.exists())
        machine.detach.assert_not_called()
        host.precheck = Mock()
        token = controller.prepare(self.device, 'start')['confirmation']
        self.assertEqual(controller.submit(self.device, 'start', token)['result'], 'accepted')

    def test_failure_after_host_lock_stays_uncertain(self):
        machine = Mock()
        machine.now.return_value = 123
        machine.detach.side_effect = OSError('private detach failure')
        host = self.real_host(machine)
        host.precheck = Mock()
        controller = mobile.Controller(host, self.root)
        token = controller.prepare(self.device, 'start')['confirmation']
        self.assertEqual(controller.submit(self.device, 'start', token)['result'], 'uncertain')
        with self.assertRaises(ValueError):
            controller.submit(self.device, 'stop', controller.prepare(self.device, 'stop')['confirmation'])

    def test_reconcile_unblocks_and_keeps_replay_evidence(self):
        self.host.failure = OSError('private exception')
        token = self.prepare()
        self.controller.submit(self.device, 'restart', token)
        config = self.root / 'mobile.json'
        config.write_text(json.dumps({'state_dir': str(self.root)}))
        with patch('sys.stdout', io.StringIO()):
            self.assertEqual(mobile.main(['--config', str(config), '--reconcile']), 0)
        self.assertEqual(self.controller.submit(self.device, 'restart', token)['result'], 'reconciled')
        self.host.failure = None
        self.assertEqual(self.controller.submit(self.device, 'start', self.prepare('start'))['result'], 'accepted')

    def test_companion_lock_refuses_second_holder_and_survives_stale_file(self):
        path = self.root / 'mobile.lock'
        path.write_text('12345')  # left behind by a crashed companion
        with mobile.hold_lock(path):
            with self.assertRaises(OSError):
                mobile.hold_lock(path)
            config = self.root / 'mobile.json'
            config.write_text(json.dumps({'state_dir': str(self.root)}))
            with patch('sys.stderr', io.StringIO()):
                self.assertEqual(mobile.main(['--config', str(config), '--reconcile']), 2)
        mobile.hold_lock(path).close()

    def test_reservation_write_failure_never_dispatches(self):
        token = self.prepare()
        with patch.object(self.controller, 'write_receipt', side_effect=OSError('disk full')):
            with self.assertRaises(OSError):
                self.controller.submit(self.device, 'restart', token)
        self.assertEqual(self.host.calls, [])

    def test_status_excludes_paths_tokens_raw_errors_and_unknown_fields(self):
        raw = {'state': 'SECRET', 'world': {'clients': True, 'map': 'SECRET'}, 'lifecycle_token': 'SECRET',
               'operation': {'phase': 'SECRET', 'action': 'SECRET', 'error': 'SECRET', 'backup': 'SECRET'}}
        clean = mobile.status_view(raw)
        self.assertNotIn('SECRET', json.dumps(clean))
        self.assertIsNone(clean['players'])
        self.assertTrue(clean['operation']['failed'])

    def test_rate_and_storage_are_bounded(self):
        self.assertTrue(all(self.controller.allow(self.device) for _ in range(30)))
        self.assertFalse(self.controller.allow(self.device))
        self.now = 60
        self.assertTrue(self.controller.allow(self.device))
        with patch.object(mobile, 'MAX_RECEIPTS', 0):
            with self.assertRaises(ValueError):
                self.controller.submit(self.device, 'restart', self.prepare())
        self.assertEqual(self.host.calls, [])

    def config(self, **changes):
        material = self.root / 'inert-material'
        material.write_text('NOT A CERTIFICATE OR KEY')
        cfg = dict(enabled=True, bind='192.168.1.8', lan_cidr='192.168.1.0/24', port=8443,
                   devices=[self.device], state_dir=str(self.root), certificate=str(material),
                   private_key=str(material), client_ca=str(material), host_config=str(material))
        cfg.update(changes)
        path = self.root / 'config'
        path.write_text(json.dumps(cfg))
        return path

    def test_config_fails_closed_for_disabled_public_wildcard_and_missing_auth(self):
        for change in ({'enabled': False}, {'bind': '0.0.0.0'}, {'bind': '8.8.8.8'},
                       {'lan_cidr': '0.0.0.0/0'}, {'lan_cidr': '192.168.0.0/16'},
                       {'devices': []}, {'private_key': ''}, {'port': True}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                mobile.load_config(self.config(**change))
        self.assertEqual(mobile.load_config(self.config())['origin'], 'https://192.168.1.8:8443')

    def test_bad_tls_material_never_binds_or_constructs_host(self):
        with patch.object(mobile, 'Server') as server, patch.object(mobile.gaia_host, 'Host') as host:
            self.assertEqual(mobile.main(['--config', str(self.config())]), 2)
            server.assert_not_called()
            host.assert_not_called()
        self.assertFalse((self.root / 'mobile.lock').exists())

    def test_tls_requires_ca_validated_client_certificate(self):
        context = Mock()
        with patch.object(mobile.ssl, 'SSLContext', return_value=context):
            context.options = 0
            cfg = mobile.load_config(self.config())
            mobile.tls_context(cfg)
        self.assertEqual(context.verify_mode, ssl.CERT_REQUIRED)
        self.assertEqual(context.minimum_version, ssl.TLSVersion.TLSv1_2)
        context.load_verify_locations.assert_called_once_with(cafile=cfg['client_ca'])
        context.load_cert_chain.assert_called_once()

    def handler(self, path='/api/action', body=None, **headers):
        handler = object.__new__(mobile.Handler)
        handler.path = path
        handler.connection = Mock()
        handler.connection.getpeercert.return_value = b'inert certificate bytes'
        fingerprint = hashlib.sha256(b'inert certificate bytes').hexdigest()
        handler.server = Mock()
        handler.server.cfg = {'devices': [fingerprint], 'authority': '192.168.1.8:8443', 'origin': 'https://192.168.1.8:8443'}
        handler.server.controller = self.controller
        raw = json.dumps(body or {'action': 'start'}).encode()
        handler.rfile = io.BytesIO(raw)
        handler.headers = HTTPMessage()
        for key, value in dict(Host='192.168.1.8:8443', Origin='https://192.168.1.8:8443',
                               **{'Content-Type': 'application/json', 'Content-Length': str(len(raw))}, **headers).items():
            handler.headers[key] = value
        handler.reply = Mock()
        return handler

    def test_cross_origin_unpaired_and_duplicate_host_are_rejected(self):
        for mode in ('origin', 'certificate', 'host'):
            handler = self.handler('/api/prepare')
            if mode == 'origin':
                handler.headers.replace_header('Origin', 'https://evil.example')
            elif mode == 'certificate':
                handler.connection.getpeercert.return_value = b'other'
            else:
                handler.headers['Host'] = 'evil.example'
            handler.do_POST()
            self.assertEqual(handler.reply.call_args.args[0], 403)
        self.assertEqual(self.host.calls, [])

    def test_http_prepare_and_confirm_reuses_same_paired_identity(self):
        prepare = self.handler('/api/prepare')
        prepare.do_POST()
        self.assertEqual(prepare.reply.call_args.args[0], 200)
        action = self.handler('/api/action', prepare.reply.call_args.args[1])
        action.do_POST()
        self.assertEqual(action.reply.call_args.args[1]['result'], 'accepted')
        self.assertEqual(self.host.calls, ['start'])

    def test_http_body_bound_unknown_fields_and_paths(self):
        for mode in ('length', 'fields', 'path', 'transfer'):
            handler = self.handler('/api/prepare', {'action': 'start', 'path': 'private'} if mode == 'fields' else None)
            if mode == 'length':
                handler.headers.replace_header('Content-Length', '513')
            elif mode == 'path':
                handler.path = '/../../private'
            elif mode == 'transfer':
                handler.headers['Transfer-Encoding'] = 'chunked'
            handler.do_POST()
            self.assertEqual(handler.reply.call_args.args[0], 400)
        self.assertEqual(self.host.calls, [])

    def test_peer_outside_lan_closed_before_tls(self):
        server = object.__new__(mobile.Server)
        server.cfg = {'network': mobile.ipaddress.ip_network('192.168.1.0/24')}
        server.context = Mock()
        connection = Mock()
        with patch.object(mobile.HTTPServer, 'get_request', return_value=(connection, ('8.8.8.8', 1234))):
            with self.assertRaises(OSError):
                server.get_request()
        connection.close.assert_called_once()
        server.context.wrap_socket.assert_not_called()


if __name__ == '__main__':
    unittest.main()
