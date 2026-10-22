"""Injected runtime identity and in-memory PNG contracts; no setup/capture."""
import ast
import copy
import io
from pathlib import Path
import unittest
from unittest.mock import patch
import local_runtime as runtime


class RuntimeContracts(unittest.TestCase):
    def observation(self):
        base, venv = Path('/base'), Path('/task/venv')
        return dict(flags=dict(ignore_environment=True, no_user_site=True,
                               dont_write_bytecode=True), user_site_enabled=False,
                    include_system_site_packages='false', numpy_found=False,
                    unsafe_files=[], site_entries=['PIL', 'pillow-10.4.0.dist-info'],
                    prefix=str(venv), base_prefix=str(base),
                    executable=str(venv/'Scripts'/'python.exe'),
                    sys_path=[str(Path(runtime.__file__).parent.resolve()),
                              str(base), str(base/'Lib'), str(base/'DLLs'),
                              str(venv/'Lib'/'site-packages')], files={'file': 'hash'})

    def test_exact_reviewed_observation_is_accepted(self):
        value = self.observation()
        runtime.validate_observation(copy.deepcopy(value), value)

    def test_changed_dependency_config_identity_or_path_is_rejected(self):
        expected = self.observation()
        for key, value in [('files', {'file': 'changed'}), ('prefix', '/other'),
                           ('base_prefix', '/other'), ('config_values', {'home': '/other'}),
                           ('sys_path', ['/ambient'])]:
            with self.subTest(key=key):
                actual = copy.deepcopy(expected)
                actual[key] = value
                with self.assertRaises(RuntimeError):
                    runtime.validate_observation(expected, actual)

    def test_unsafe_even_self_consistent_contract_is_rejected(self):
        cases = [('user_site_enabled', True), ('include_system_site_packages', 'true'),
                 ('numpy_found', True), ('unsafe_files', ['x.pth']),
                 ('site_entries', ['PIL', 'numpy']), ('files', {}),
                 ('sys_path', ['/ambient']), ('executable', '/base/python.exe')]
        for key, value in cases:
            with self.subTest(key=key):
                actual = self.observation()
                actual[key] = value
                with self.assertRaises(RuntimeError):
                    runtime.validate_observation(copy.deepcopy(actual), actual)
        for flag in ('ignore_environment', 'no_user_site', 'dont_write_bytecode'):
            value = self.observation()
            value['flags'][flag] = False
            with self.assertRaises(RuntimeError):
                runtime.validate_observation(copy.deepcopy(value), value)

    def test_verifier_observes_hash_bound_manifest_and_honors_guard(self):
        import json
        import tempfile
        value = self.observation()
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'runtime.json'
            path.write_text(json.dumps(dict(layout={'injected': True}, observation=value)))
            contract = dict(manifest=str(path), sha256=runtime.digest(path))
            checks = []
            with patch.object(runtime, 'observe_runtime', return_value=value) as observe:
                runtime.verify_runtime(contract, lambda: checks.append(True))
                self.assertEqual(observe.call_count, 1)
                self.assertTrue(checks)
            path.write_text('{}')
            with self.assertRaisesRegex(RuntimeError, 'manifest hash changed'):
                runtime.verify_runtime(contract, lambda: None)
            path.write_text('{"layout":{},"layout":{},"observation":{}}')
            contract['sha256'] = runtime.digest(path)
            with self.assertRaisesRegex(RuntimeError, 'duplicate runtime manifest key'):
                runtime.verify_runtime(contract, lambda: None)

    def test_load_binds_expiry_before_runtime_observation(self):
        import run as runner
        from unittest.mock import Mock
        admission = Path('/injected/admission.json')
        packet = dict(expires_unix=123, runtime={})
        events = []
        budget = Mock()
        budget.bind.side_effect = lambda expiry: events.append(('bind', expiry))
        def observe(*args):
            events.append(('runtime', None))
            raise RuntimeError('observation stop')
        with patch.object(runner.sys, 'platform', 'win32'), \
                patch.object(runner, 'read_json', return_value=packet), \
                patch.object(runner, 'digest', return_value='a'*64), \
                patch.object(runtime, 'verify_runtime', side_effect=observe):
            with self.assertRaisesRegex(RuntimeError, 'observation stop'):
                runner.load_local(admission, 'a'*64, Path('/output'), budget)
            self.assertEqual(events, [('bind', 123), ('runtime', None)])
            budget.bind.side_effect = RuntimeError('expired')
            events.clear()
            with self.assertRaisesRegex(RuntimeError, 'expired'):
                runner.load_local(admission, 'a'*64, Path('/output'), budget)
            self.assertEqual(events, [])

    def test_source_requires_runtime_before_native_boundary(self):
        source = Path(__file__).with_name('run.py').read_text()
        tree = ast.parse(source)
        load = next(node for node in tree.body if isinstance(node, ast.FunctionDef)
                    and node.name == 'load_local')
        calls = [node for node in ast.walk(load) if isinstance(node, ast.Call)
                 and isinstance(node.func, ast.Name) and node.func.id == 'verify_runtime']
        self.assertEqual(len(calls), 1)
        self.assertEqual(ast.unparse(calls[0].args[0]), "packet['runtime']")
        self.assertLess(source.index("verify_runtime(packet['runtime']"),
                        source.index("def admit_local_launch"))

    def test_real_temporary_inventory_detects_changed_bytes_and_pth(self):
        import tempfile
        import importlib.util
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            venv, base = root/'venv', root/'base'
            site_root = venv/'Lib'/'site-packages'
            for path in (site_root/'PIL', site_root/'pillow-10.4.0.dist-info',
                         base/'Lib'/'__pycache__', base/'DLLs', venv/'Scripts'):
                path.mkdir(parents=True, exist_ok=True)
            (venv/'pyvenv.cfg').write_text('include-system-site-packages = false\n')
            for name in ('python.exe', 'python312.dll', 'python3.dll'):
                (base/name).write_bytes(b'base fake offline bytes')
            cache = base/'Lib'/'__pycache__'/'module.pyc'
            cache.write_bytes(b'cached code is identity too')
            (site_root/'PIL'/'Image.py').write_bytes(b'fake package, never imported')
            layout = dict(trees=[dict(path=str(venv), exclude_names=[]),
                                 dict(path=str(base/'Lib'), exclude_names=['site-packages']),
                                 dict(path=str(base/'DLLs'), exclude_names=[])],
                          base_files=[str(base/name) for name in
                                      ('python.exe', 'python312.dll', 'python3.dll')])
            with patch.object(runtime.sys, 'prefix', str(venv)), \
                    patch.object(runtime.sys, 'base_prefix', str(base)), \
                    patch.object(runtime.sys, 'executable', str(venv/'Scripts'/'python.exe')), \
                    patch.object(runtime.sys, 'path', [str(site_root)]), \
                    patch.object(runtime.sys, 'flags', type('Flags', (), dict(
                        ignore_environment=1, no_user_site=1, dont_write_bytecode=1))()), \
                    patch.object(runtime.site, 'ENABLE_USER_SITE', False), \
                    patch.object(importlib.util, 'find_spec', return_value=None):
                expected = runtime.observe_runtime(layout, lambda: None)
                self.assertIn(str(cache.resolve()), expected['files'])
                runtime.validate_observation(expected, runtime.observe_runtime(layout, lambda: None))
                cache.write_bytes(b'changed cache')
                with self.assertRaisesRegex(RuntimeError, 'identity differs'):
                    runtime.validate_observation(expected, runtime.observe_runtime(layout, lambda: None))
                (site_root/'ambient.pth').write_text('/ambient')
                with self.assertRaisesRegex(RuntimeError, 'pth present'):
                    runtime.observe_runtime(layout, lambda: None)

    def test_png_serialization_preserves_rgba_and_rejects_bad_pixel(self):
        from PIL import Image
        for color in ((255, 0, 0, 255), (0, 0, 255, 255)):
            image = Image.new('RGBA', (8, 8), color)
            data = io.BytesIO()
            image.save(data, format='PNG')
            data.seek(0)
            with Image.open(data) as restored:
                self.assertEqual(restored.mode, 'RGBA')
                self.assertEqual(restored.size, (8, 8))
                self.assertEqual(set(restored.getdata()), {color})
                restored.putpixel((0, 0), (0, 0, 0, 0))
                with self.assertRaises(AssertionError):
                    self.assertEqual(set(restored.getdata()), {color})


if __name__ == '__main__':
    unittest.main()
