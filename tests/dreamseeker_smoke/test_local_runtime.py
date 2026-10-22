"""Injected runtime identity and in-memory PNG contracts; no setup/capture."""
import ast
import copy
import io
from pathlib import Path
import unittest
from unittest.mock import patch
import local_runtime as runtime


# Frozen predecessor traversal for independent parity, never a production path.
PREVIOUS_OBSERVER = 'def observe_runtime(layout, check):\n    """Layout and all resulting bytes must come from independent packet review.\n\n    Trees include venv, base Lib (excluding only unreachable site-packages),\n    base DLLs; explicit files bind base executable/runtime DLLs. OS libraries\n    remain external platform dependencies, never claimed hermetic.\n    """\n    import importlib.util\n    check()\n    venv = Path(sys.prefix)\n    config = venv / \'pyvenv.cfg\'\n    require(config.is_file() and not config.is_symlink(), \'missing venv config\')\n    pairs = [line.split(\'=\', 1) for line in config.read_text().splitlines() if \'=\' in line]\n    keys = [key.strip().lower() for key, _ in pairs]\n    require(len(keys) == len(set(keys)), \'duplicate venv config keys\')\n    config_values = {key.strip().lower(): value.strip() for key, value in pairs}\n    files, unsafe = {}, []\n    roots = [Path(row[\'path\']) for row in layout[\'trees\']]\n    require(len(roots) == 3 and roots[0] == venv\n            and roots[1] == Path(sys.base_prefix) / \'Lib\'\n            and roots[2] == Path(sys.base_prefix) / \'DLLs\', \'wrong runtime trees\')\n    for index, row in enumerate(layout[\'trees\']):\n        root = Path(row[\'path\'])\n        exclusions = row[\'exclude_names\']\n        require(exclusions == ([\'site-packages\'] if index == 1 else []), \'unsupported tree exclusions\')\n        require(root.is_dir() and not root.is_symlink() and not getattr(\n                root.stat(), \'st_file_attributes\', 0) & 0x400, \'invalid runtime tree\')\n        for directory, dirs, names in os.walk(root, followlinks=False):\n            check()\n            parent = Path(directory)\n            for name in dirs + names:\n                path = parent / name\n                if path.is_symlink() or getattr(path.stat(follow_symlinks=False),\n                                                \'st_file_attributes\', 0) & 0x400:\n                    raise RuntimeError(\'Local runtime: reparse/symlink present: \' + str(path))\n            dirs[:] = [name for name in dirs if name not in exclusions]\n            for name in names:\n                path = parent / name\n                if path.suffix.lower() == \'.pth\':\n                    raise RuntimeError(\'Local runtime: pth present: \' + str(path))\n                if path.is_file():\n                    check()\n                    files[str(path.resolve())] = digest(path)\n    mandatory_base = {str(path) for path in Path(sys.base_prefix).iterdir()\n                      if path.is_file() and path.suffix.lower() in {\'.exe\', \'.dll\', \'.zip\', \'._pth\'}}\n    require(set(layout[\'base_files\']) == mandatory_base, \'incomplete base executable/DLL/zip inventory\')\n    require(not any(Path(name).suffix.lower() == \'._pth\' for name in mandatory_base),\n            \'base path override file present\')\n    for name in layout[\'base_files\']:\n        path = Path(name)\n        require(path.parent == Path(sys.base_prefix) and path.is_file(),\n                \'base file escapes interpreter directory\')\n        require(not path.is_symlink() and not getattr(path.stat(),\n                \'st_file_attributes\', 0) & 0x400, \'unsafe base file\')\n        check()\n        files[str(path.resolve())] = digest(path)\n    require({\'python.exe\', \'python312.dll\', \'python3.dll\'}.issubset(\n            {Path(name).name.lower() for name in layout[\'base_files\']}),\n            \'missing base interpreter identity\')\n    site_root = venv / \'Lib\' / \'site-packages\'\n    check()\n    return {\'flags\': {\'ignore_environment\': bool(sys.flags.ignore_environment),\n                      \'no_user_site\': bool(sys.flags.no_user_site),\n                      \'dont_write_bytecode\': bool(sys.flags.dont_write_bytecode)},\n            \'user_site_enabled\': site.ENABLE_USER_SITE,\n            \'include_system_site_packages\': config_values.get(\'include-system-site-packages\'),\n            \'prefix\': str(venv), \'base_prefix\': sys.base_prefix,\n            \'executable\': str(Path(sys.executable).resolve()),\n            \'sys_path\': list(sys.path), \'config_values\': config_values,\n            \'site_entries\': sorted(path.name for path in site_root.iterdir()),\n            \'numpy_found\': importlib.util.find_spec(\'numpy\') is not None,\n            \'unsafe_files\': sorted(set(unsafe)), \'files\': files}\n\n'


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
            path = Path(folder).resolve()/'runtime.json'
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
            root = Path(folder).resolve()
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
                        ignore_environment=1, no_user_site=1, dont_write_bytecode=1, optimize=0))()), \
                    patch.object(runtime.site, 'ENABLE_USER_SITE', False), \
                    patch.object(importlib.util, 'find_spec', return_value=None):
                # Compare actual predecessor and successor on identical real files.
                import types
                previous = types.ModuleType('previous_runtime')
                previous.__dict__.update(runtime.__dict__)
                exec(compile(PREVIOUS_OBSERVER, '<frozen-previous-observer>', 'exec'), previous.__dict__)
                callbacks = []
                expected = runtime.observe_runtime(layout, lambda: callbacks.append(True))
                self.assertEqual(expected, previous.observe_runtime(layout, lambda: None))
                self.assertGreaterEqual(len(callbacks), len(expected['files']))
                self.assertIn(str(cache.resolve()), expected['files'])
                self.assertEqual(expected['prefix'], str(venv.resolve()))
                self.assertEqual(expected['executable'], str(venv/'Scripts'/'python.exe'))
                runtime.validate_observation(expected, runtime.observe_runtime(layout, lambda: None))
                cache.write_bytes(b'changed cache')
                with self.assertRaisesRegex(RuntimeError, 'identity differs'):
                    runtime.validate_observation(expected, runtime.observe_runtime(layout, lambda: None))
                (site_root/'ambient.pth').write_text('/ambient')
                with self.assertRaisesRegex(RuntimeError, 'pth present'):
                    runtime.observe_runtime(layout, lambda: None)

    def test_scandir_rejects_reparse_before_hash_and_propagates_deadline(self):
        from types import SimpleNamespace
        from unittest.mock import Mock
        # Execute actual traversal using the existing real temporary tree setup,
        # replacing only one scandir entry metadata observation.
        original = runtime.os.scandir
        seen = []
        class Entries:
            def __init__(self, path):
                self.context = original(path)
            def __enter__(self):
                entries = self.context.__enter__()
                for entry in entries:
                    info = entry.stat(follow_symlinks=False)
                    proxy = Mock(path=entry.path, name=entry.name)
                    proxy.name = entry.name
                    proxy.stat.return_value = type('Info', (), dict(
                        st_mode=info.st_mode, st_file_attributes=0x400))()
                    seen.append(entry.path)
                    return iter([proxy])
                return iter([])
            def __exit__(self, *args):
                return self.context.__exit__(*args)
        with patch.object(runtime, 'os', SimpleNamespace(scandir=Entries)):
            with self.assertRaisesRegex(RuntimeError, 'reparse/symlink'):
                self.test_real_temporary_inventory_detects_changed_bytes_and_pth()
        self.assertTrue(seen)
        # The guard must interrupt before any enumeration, not after hashing.
        with patch.object(runtime.os, 'scandir') as scan:
            with self.assertRaisesRegex(RuntimeError, 'deadline sentinel'):
                runtime.observe_runtime({}, lambda: (_ for _ in ()).throw(
                    RuntimeError('deadline sentinel')))
            scan.assert_not_called()

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
