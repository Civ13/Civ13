"""Synthetic owned-row tests only; no sockets, Windows APIs or native processes."""
import json
from datetime import datetime, timedelta, timezone
from itertools import product
import unittest
from run_scene import OwnedSocketViolation, socket_contract, checked_owned_sockets, require_game_listener, require_outbound_window, OUTBOUND_DEADLINE


def row(**changes):
    value = dict(protocol='tcp', address='127.0.0.1', port=54321, state='5', remote='127.0.0.1')
    value.update(changes)
    return value


class Adapter:
    def __init__(self, rows, exited=False):
        self.rows, self.has_exited = rows, exited
    def sockets(self, process):
        return self.rows
    def identity(self, process):
        return dict(pid=1234, creation_filetime=123456789, image='not retained')
    def exited(self, process):
        return self.has_exited


class SocketDiagnostics(unittest.TestCase):
    def test_existing_loopback_connections_and_intended_listener_pass(self):
        socket_contract([row()])
        socket_contract([row(state='listen', port=6000, remote='0.0.0.0')], True, 6000)

    def test_same_policy_rejects_udp_wildcard_ipv6_external_and_wrong_listener(self):
        cases = [row(protocol='udp', remote=None, state='None'), row(address='0.0.0.0'),
                 row(address='::1', remote='::1'), row(remote='203.0.113.10'),
                 row(state='listen'), row(state='listen', port=6001)]
        for value in cases:
            with self.subTest(row=value), self.assertRaises(OwnedSocketViolation):
                socket_contract([value], True, 6000)

    def test_acceptance_predicate_is_identical_to_original_guard(self):
        # Complete small cross-product, including legitimate-looking bindings
        # which the deliberately narrow original policy still must reject.
        for protocol, address, remote, state, server, port in product(
                ('tcp', 'udp'), ('127.0.0.1', '0.0.0.0', '::1'),
                ('127.0.0.1', '0.0.0.0', '203.0.113.10', None),
                ('5', 'listen', 'None'), (False, True), (6000, 6001)):
            value = row(protocol=protocol, address=address, remote=remote, state=state, port=port)
            expected = (protocol == 'tcp' and address == '127.0.0.1' and
                        remote in ('0.0.0.0', '127.0.0.1') and
                        (state != 'listen' or (server and port == 6000)))
            try:
                socket_contract([value], server, 6000)
                accepted = True
            except OwnedSocketViolation:
                accepted = False
            self.assertEqual(accepted, expected, value)

    def test_exact_first_owned_violation_and_bound_identity_retained(self):
        first = row(protocol='udp', address='0.0.0.0', remote=None, state='None', port=23456)
        adapter = Adapter([row(), first, row(remote='203.0.113.10')])
        with self.assertRaises(OwnedSocketViolation) as caught:
            checked_owned_sockets('client', adapter, object())
        evidence = caught.exception.evidence
        self.assertEqual(evidence['socket'], first)
        self.assertEqual(evidence['role'], 'client')
        self.assertEqual(evidence['pid'], 1234)
        self.assertEqual(evidence['creation_filetime'], 123456789)
        self.assertTrue(evidence['retained_handle_live_after_query'])
        self.assertLessEqual(len(json.dumps(evidence)), 1024)
        self.assertNotIn('203.0.113.10', json.dumps(evidence))
        self.assertNotIn('not retained', json.dumps(evidence))

    def test_extra_unreviewed_row_fields_are_not_retained(self):
        value = row(protocol='udp', remote=None, state='None', unrelated_data='must not retain')
        with self.assertRaises(OwnedSocketViolation) as caught:
            checked_owned_sockets('client', Adapter([value]), object())
        self.assertEqual(set(caught.exception.evidence['socket']), {'protocol','address','port','state','remote'})
        self.assertNotIn('must not retain', json.dumps(caught.exception.evidence))

    def test_exit_after_query_prevents_attribution_without_passing_guard(self):
        with self.assertRaisesRegex(RuntimeError, 'attribution unavailable') as caught:
            checked_owned_sockets('client', Adapter([row(address='0.0.0.0')], exited=True), object())
        self.assertNotIsInstance(caught.exception, OwnedSocketViolation)

    def test_unbound_role_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, 'retained identity unavailable'):
            checked_owned_sockets('unowned', Adapter([row(address='0.0.0.0')]), object())

    def test_malformed_or_oversized_diagnostics_stop(self):
        for value in [row(address='x'*46), row(address='0.0.0.0', port=-1), row(address='0.0.0.0', state='x'*17)]:
            with self.subTest(row=value), self.assertRaises(RuntimeError):
                socket_contract([value])

    def test_approved_outbound_is_limited_to_retained_server_and_client(self):
        external = row(address='10.1.0.81', remote='203.0.113.10')
        for role in ('server', 'client'):
            observations = []
            values = [external]
            self.assertIs(checked_owned_sockets(role, Adapter(values), object(), role == 'server', 6000, observations), values)
            self.assertEqual(observations[0]['socket'], external)
            self.assertEqual(observations[0]['role'], role)
        with self.assertRaises(OwnedSocketViolation):
            checked_owned_sockets('compiler', Adapter([external]), object())

    def test_approval_does_not_allow_udp_or_unexpected_listeners(self):
        invalid = [row(protocol='udp', remote=None, state='None'),
                   row(address='0.0.0.0', state='listen', port=6000, remote='0.0.0.0'),
                   row(state='listen', port=6001, remote='0.0.0.0')]
        for value in invalid:
            for role in ('server', 'client'):
                with self.subTest(role=role, socket=value), self.assertRaises(OwnedSocketViolation):
                    checked_owned_sockets(role, Adapter([value]), object(), role == 'server', 6000)
        listener = row(state='listen', port=6000, remote='0.0.0.0')
        checked_owned_sockets('server', Adapter([listener]), object(), True, 6000)
        with self.assertRaises(OwnedSocketViolation):
            checked_owned_sockets('client', Adapter([listener]), object(), False, 6000)
        with self.assertRaises(OwnedSocketViolation):
            checked_owned_sockets('server', Adapter([listener, listener]), object(), True, 6000)

    def test_game_listener_remains_exact_and_required_after_readiness(self):
        listener = row(state='listen', port=6000, remote='0.0.0.0')
        self.assertEqual(require_game_listener([listener, row(remote='203.0.113.10')], 6000), [listener])
        for rows in ([], [row()], [listener, listener], [row(state='listen', port=6000, address='0.0.0.0')]):
            with self.subTest(rows=rows), self.assertRaises(RuntimeError):
                require_game_listener(rows, 6000)

    def test_approved_connection_metadata_is_deduplicated_and_bounded(self):
        values = [row(address='10.1.0.81', remote='203.0.113.10')]
        observations = []
        for _ in range(3):
            checked_owned_sockets('client', Adapter(values), object(), observations=observations)
        self.assertEqual(len(observations), 1)
        for port in range(31):
            checked_owned_sockets('client', Adapter([row(port=port)]), object(), observations=observations)
        self.assertEqual(len(observations), 32)
        self.assertLessEqual(len(json.dumps(observations)), 32 * 512)
        with self.assertRaisesRegex(RuntimeError, 'observation limit'):
            checked_owned_sockets('client', Adapter([row(port=99)]), object(), observations=observations)

    def test_client_cannot_be_mislabeled_as_listener_owner(self):
        with self.assertRaisesRegex(RuntimeError, 'role/listener contract mismatch'):
            checked_owned_sockets('client', Adapter([]), object(), True, 6000)

    def test_client_native_http_listener_is_high_port_loopback_and_pinned(self):
        for port in (49152, 54416, 65535):
            binding = {}
            listener = row(state='listen', port=port, remote='0.0.0.0')
            checked_owned_sockets('client', Adapter([listener]), object(), False, 6000,
                                  client_listener_binding=binding)
            self.assertEqual(binding, {'pid':1234, 'creation_filetime':123456789,
                                      'protocol':'tcp', 'address':'127.0.0.1', 'port':port})
            checked_owned_sockets('client', Adapter([]), object(), False, 6000,
                                  client_listener_binding=binding)
            checked_owned_sockets('client', Adapter([listener]), object(), False, 6000,
                                  client_listener_binding=binding)

    def test_client_listener_exception_does_not_allow_other_bindings(self):
        valid = row(state='listen', port=54416, remote='0.0.0.0')
        invalid = [row(**{**valid, 'port':49151}), row(**{**valid, 'port':65536}),
                   row(**{**valid, 'address':'0.0.0.0'}), row(**{**valid, 'address':'::1'}),
                   row(**{**valid, 'remote':'127.0.0.1'}), row(**{**valid, 'protocol':'udp'})]
        for value in invalid:
            with self.subTest(row=value), self.assertRaises(RuntimeError):
                checked_owned_sockets('client', Adapter([value]), object(), False, 6000,
                                      client_listener_binding={})
        for values, game_port in (([valid, valid], 6000), ([valid], 54416), ([valid], None)):
            with self.assertRaises(OwnedSocketViolation):
                checked_owned_sockets('client', Adapter(values), object(), False, game_port,
                                      client_listener_binding={})
        for role in ('server', 'compiler'):
            with self.assertRaises(OwnedSocketViolation):
                checked_owned_sockets(role, Adapter([valid]), object(), role == 'server', 6000,
                                      client_listener_binding={})

    def test_client_listener_cannot_change_port_or_retained_owner(self):
        listener = row(state='listen', port=54416, remote='0.0.0.0')
        binding = {}
        checked_owned_sockets('client', Adapter([listener]), object(), False, 6000,
                              client_listener_binding=binding)
        with self.assertRaisesRegex(OwnedSocketViolation, 'identity/port changed'):
            checked_owned_sockets('client', Adapter([row(**{**listener, 'port':54417})]), object(), False, 6000,
                                  client_listener_binding=binding)
        class OtherBirth(Adapter):
            def identity(self, process):
                return dict(pid=1234, creation_filetime=999999, image='not retained')
        with self.assertRaisesRegex(OwnedSocketViolation, 'identity/port changed'):
            checked_owned_sockets('client', OtherBirth([listener]), object(), False, 6000,
                                  client_listener_binding=binding)
        self.assertEqual(binding['port'], 54416)
        self.assertEqual(binding['creation_filetime'], 123456789)

    def test_client_listener_needs_live_bound_record(self):
        listener = row(state='listen', port=54416, remote='0.0.0.0')
        with self.assertRaisesRegex(RuntimeError, 'binding record required'):
            checked_owned_sockets('client', Adapter([listener]), object(), False, 6000)
        binding = {}
        with self.assertRaisesRegex(RuntimeError, 'attribution unavailable'):
            checked_owned_sockets('client', Adapter([listener], exited=True), object(), False, 6000,
                                  client_listener_binding=binding)
        self.assertEqual(binding, {})

    def test_expiring_outbound_authorization_and_start_reserve(self):
        self.assertEqual(OUTBOUND_DEADLINE, datetime(2026,11,1,16,36,18,tzinfo=timezone.utc))
        require_outbound_window(OUTBOUND_DEADLINE-timedelta(minutes=6), start=True)
        require_outbound_window(OUTBOUND_DEADLINE-timedelta(seconds=1))
        for now, start in ((OUTBOUND_DEADLINE-timedelta(minutes=5), True),
                           (OUTBOUND_DEADLINE, False), (OUTBOUND_DEADLINE+timedelta(seconds=1), False)):
            with self.assertRaisesRegex(RuntimeError, 'authorization window'):
                require_outbound_window(now, start)

    def test_success_returns_only_supplied_owned_rows(self):
        values = [row()]
        self.assertIs(checked_owned_sockets('client', Adapter(values), object()), values)


if __name__ == '__main__':
    unittest.main(verbosity=2)
