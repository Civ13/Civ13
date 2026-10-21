import ast
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('gaia_prepare', Path(__file__).with_name('prepare.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class Preparation(unittest.TestCase):
    def test_actual_seed_command_uses_supported_trusted_flag(self):
        # Compile only the pure helper, never the native test_port.main entrypoint.
        source = Path(__file__).with_name('test_port.py').read_text(encoding='utf-8')
        tree = ast.parse(source)

        def arguments(text):
            helper = next(node for node in ast.parse(text).body
                          if isinstance(node, ast.FunctionDef) and node.name == 'daemon_arguments')
            scope = {}
            exec(compile(ast.Module(body=[helper], type_ignores=[]), '<seed-command>', 'exec'), scope)
            return scope['daemon_arguments'](Path('byond/dd.exe'))

        expected = [str(Path('byond/dd.exe')), 'probe.dmb', '-close', '-invisible', '-trusted',
                    '-params', 'gaia_intent_seed=1', '-log', 'native.log']
        self.assertEqual(arguments(source), expected)
        old_flag = source.replace("'-trusted'", "'-safe'")
        self.assertNotEqual(old_flag, source)
        with self.assertRaises(AssertionError):
            self.assertEqual(arguments(old_flag), expected)
        launches = [node for node in ast.walk(tree) if isinstance(node, ast.Call)
                    and isinstance(node.func, ast.Attribute)
                    and isinstance(node.func.value, ast.Name)
                    and (node.func.value.id, node.func.attr) == ('subprocess', 'Popen')]
        self.assertEqual(len(launches), 1)
        command = launches[0].args[0]
        self.assertIsInstance(command, ast.Call)
        self.assertEqual(ast.unparse(command), 'daemon_arguments(daemon)')

    def test_hash_guard_rejects_changed_file(self):
        with tempfile.TemporaryDirectory() as root:
            folder = Path(root)
            expected = m.EXPECTED
            try:
                m.EXPECTED = {'one': hashlib.sha256(b'original').hexdigest()}
                (folder / 'one').write_bytes(b'original')
                self.assertEqual(m.verify_originals(folder), m.EXPECTED)
                (folder / 'one').write_bytes(b'corrupt')
                with self.assertRaisesRegex(ValueError, 'hashes differ'):
                    m.verify_originals(folder)
            finally:
                m.EXPECTED = expected

    def test_reversible_observer_and_seed_branch(self):
        original = '/world/New()\n\tmap_storage.record_compiled_dimensions()\n\tpersistence_restart.detect_startup()\n/world/Topic(T, addr, master, key)\n\t..()\n'
        observed = m.instrument_world(original)
        seed = '\tif(world.params["gaia_intent_seed"] == "1")\n\t\tspawn(0) gaia_probe_seed_intent()\n\t\treturn\n'
        topic = '\tif("gaia_probe" in params2list(T))\n\t\treturn gaia_probe_topic(T, addr)\n'
        self.assertEqual(observed.replace(seed, '').replace(topic, '').replace('\tgaia_probe_seed_entry()\n', ''), original)
        self.assertLess(observed.index('gaia_probe_seed_intent()'), observed.index('persistence_restart.detect_startup()'))
        with self.assertRaises(ValueError):
            m.instrument_world(original + original)

    def test_immutable_digest_shape(self):
        self.assertEqual(set(m.EXPECTED), {'1.sav', '2.sav', 'map.txt', 'round.json', 'save_complete.txt'})
        self.assertTrue(all(len(value) == 64 and int(value, 16) for value in m.EXPECTED.values()))


if __name__ == '__main__':
    unittest.main()
