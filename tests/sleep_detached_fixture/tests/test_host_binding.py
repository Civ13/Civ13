"""Offline daemon-binding tests; no Docker command is executed."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('host_binding', ROOT / 'host_binding.py')
h = importlib.util.module_from_spec(spec); spec.loader.exec_module(h)

class Tests(unittest.TestCase):
    def test_stable_binding_and_each_mismatch(self):
        socket = {'device': 1, 'inode': 2, 'uid': 0, 'gid': 1}
        daemon = {'id': 'fixture', 'server_version': 'test'}
        expected = {'socket': socket, 'daemon': daemon}
        self.assertTrue(h.same_daemon('/docker', '/tmp/x', expected,
                        get_socket=lambda: socket, get_info=lambda *_: daemon))
        for sockets, observed in (([socket, dict(socket, inode=3)], daemon),
                                  ([dict(socket, inode=3)] * 2, daemon),
                                  ([socket] * 2, dict(daemon, id='other'))):
            values = iter(sockets)
            with self.assertRaises(ValueError):
                h.same_daemon('/docker', '/tmp/x', expected,
                              get_socket=lambda: next(values), get_info=lambda *_: observed)

    def test_fixed_endpoint_is_not_environment_selected(self):
        self.assertEqual(h.ENDPOINT, 'unix:///var/run/docker.sock')
        self.assertEqual(h.SOCKET, '/var/run/docker.sock')

if __name__ == '__main__':
    unittest.main()
