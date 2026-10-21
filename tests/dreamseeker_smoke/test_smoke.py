"""Synthetic oracle tests, never native renderer evidence."""
import unittest
import ast
from unittest.mock import patch
from PIL import Image
import run


class SmokeContracts(unittest.TestCase):
    def test_daemon_uses_trusted_loopback_arguments(self):
        arguments = run.server_arguments(1234)
        self.assertEqual(arguments, ['fixture.dmb', '1234', '-ip', '127.0.0.1',
                                     '-invisible', '-trusted', '-nowebclient'])
        source = (run.ROOT/'run.py').read_text()
        launches = [node for node in ast.walk(ast.parse(source))
                    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                    and node.func.id == 'launch' and node.args
                    and isinstance(node.args[0], ast.Constant) and node.args[0].value == 'dreamdaemon.exe']
        self.assertEqual(len(launches), 1)
        self.assertEqual(ast.unparse(launches[0].args[1]), 'server_arguments(port)')

    def test_safe_flag_negative_control_is_detected(self):
        arguments = run.server_arguments(1234)
        arguments[arguments.index('-trusted')] = '-safe'
        with patch.object(run, 'server_arguments', return_value=arguments):
            with self.assertRaises(AssertionError):
                self.test_daemon_uses_trusted_loopback_arguments()

    def test_pixels_require_phase_and_actor(self):
        for phase, color in [('red', 'red'), ('blue', 'blue')]:
            image = Image.new('RGB', (224, 224), color)
            self.assertFalse(run.pixel_contract(image, phase))
            image.paste((0, 255, 0), (96, 96, 128, 128))
            self.assertTrue(run.pixel_contract(image, phase))
            self.assertFalse(run.pixel_contract(image, 'blue' if phase == 'red' else 'red'))
            image.putpixel((0, 0), (0, 0, 255) if phase == 'red' else (255, 0, 0))
            self.assertFalse(run.pixel_contract(image, phase))

    def test_socket_policy(self):
        row = dict(protocol='tcp', address='127.0.0.1', remote='0.0.0.0', port=1234, state='listen')
        run.socket_contract([row], True, 1234)
        for changed in ({'address': '0.0.0.0'}, {'address': '::'}, {'remote': '8.8.8.8'},
                        {'protocol': 'udp'}, {'port': 4321}):
            with self.assertRaises(RuntimeError):
                run.socket_contract([dict(row, **changed)], True, 1234)
        with self.assertRaises(RuntimeError):
            run.socket_contract([row])
        run.socket_contract([dict(row, state='5', remote='127.0.0.1')])

    def test_source_scope(self):
        fixture = (run.ROOT/'fixture.dm').read_text()
        self.assertIn('copytext(key, 1, 7) == "Guest-"', fixture)
        self.assertIn('address != "127.0.0.1"', fixture)
        self.assertIn('spawn(600)', fixture)
        self.assertNotIn('civ13.dme', (run.ROOT/'fixture.dme').read_text())
        adapter = (run.ROOT/'windows.py').read_text()
        self.assertIn('limits.basic.active = 1', adapter)
        self.assertIn('startup.startup.show = 1 if visible else 0', adapter)
        self.assertIn('AssignProcessToJobObject', adapter)
        self.assertLess(adapter.index('AssignProcessToJobObject(self.job'), adapter.index('ResumeThread(process.thread)'))


if __name__ == '__main__':
    unittest.main()
