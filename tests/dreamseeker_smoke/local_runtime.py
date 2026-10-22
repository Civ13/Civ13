"""Fail-closed local runtime identity; no setup, installs or process launch."""
import os
import json
from pathlib import Path
import site
import sys
from guard_config import digest


def require(condition, message):
    if not condition:
        raise RuntimeError('Local runtime: ' + message)


def validate_observation(expected, actual):
    require(actual == expected, 'runtime/config/path/dependency identity differs')
    require(actual['flags'] == {'ignore_environment': True, 'no_user_site': True,
                               'dont_write_bytecode': True}, 'use -E -s -B')
    require(actual['user_site_enabled'] is False, 'user site enabled')
    require(actual['include_system_site_packages'] == 'false', 'system site enabled')
    require(actual['numpy_found'] is False, 'optional NumPy is available')
    require(actual['unsafe_files'] == [], 'pth/reparse/symlink present')
    require(set(actual['site_entries']) == {'PIL', 'pillow-10.4.0.dist-info'},
            'unexpected site packages')
    require(actual['prefix'] != actual['base_prefix'], 'normal isolated venv required')
    require(actual['files'], 'empty runtime manifest')
    base, venv = Path(actual['base_prefix']), Path(actual['prefix'])
    require(Path(actual['executable']) == venv / 'Scripts' / 'python.exe',
            'executable outside venv')
    allowed = {str(Path(__file__).resolve().parent), str(base / 'python312.zip'),
               str(base), str(base / 'DLLs'), str(base / 'Lib'), str(venv),
               str(venv / 'Lib'), str(venv / 'Lib' / 'site-packages')}
    require(all(entry in allowed for entry in actual['sys_path']), 'ambient sys.path')
    require(str(venv / 'Lib' / 'site-packages') in actual['sys_path'], 'missing venv site')


def observe_runtime(layout, check):
    """Layout and all resulting bytes must come from independent packet review.

    Trees include venv, base Lib (excluding only unreachable site-packages),
    base DLLs; explicit files bind base executable/runtime DLLs. OS libraries
    remain external platform dependencies, never claimed hermetic.
    """
    import importlib.util
    check()
    venv = Path(sys.prefix)
    config = venv / 'pyvenv.cfg'
    require(config.is_file() and not config.is_symlink(), 'missing venv config')
    pairs = [line.split('=', 1) for line in config.read_text().splitlines() if '=' in line]
    keys = [key.strip().lower() for key, _ in pairs]
    require(len(keys) == len(set(keys)), 'duplicate venv config keys')
    config_values = {key.strip().lower(): value.strip() for key, value in pairs}
    files, unsafe = {}, []
    roots = [Path(row['path']) for row in layout['trees']]
    require(len(roots) == 3 and roots[0] == venv
            and roots[1] == Path(sys.base_prefix) / 'Lib'
            and roots[2] == Path(sys.base_prefix) / 'DLLs', 'wrong runtime trees')
    for index, row in enumerate(layout['trees']):
        root = Path(row['path'])
        exclusions = row['exclude_names']
        require(exclusions == (['site-packages'] if index == 1 else []), 'unsupported tree exclusions')
        root_stat = root.stat(follow_symlinks=False)
        import stat
        require(stat.S_ISDIR(root_stat.st_mode) and not stat.S_ISLNK(root_stat.st_mode)
                and not getattr(root_stat, 'st_file_attributes', 0) & 0x400,
                'invalid runtime tree')
        # Resolve only the admitted root, never thousands of descendant paths.
        # Every intervening entry is independently rejected if a link/reparse.
        canonical_root = root.resolve(strict=True)
        pending = [root]
        while pending:
            check()
            parent = pending.pop()
            with os.scandir(parent) as entries:
                for entry in entries:
                    check()
                    info = entry.stat(follow_symlinks=False)
                    require(not stat.S_ISLNK(info.st_mode)
                            and not getattr(info, 'st_file_attributes', 0) & 0x400,
                            'reparse/symlink present: ' + entry.path)
                    path = Path(entry.path)
                    if stat.S_ISDIR(info.st_mode):
                        if entry.name not in exclusions:
                            pending.append(path)
                    else:
                        require(path.suffix.lower() != '.pth', 'pth present: ' + entry.path)
                        require(stat.S_ISREG(info.st_mode), 'nonregular runtime entry: ' + entry.path)
                        check()
                        files[str(canonical_root / path.relative_to(root))] = digest(path)
    mandatory_base = {str(path) for path in Path(sys.base_prefix).iterdir()
                      if path.is_file() and path.suffix.lower() in {'.exe', '.dll', '.zip', '._pth'}}
    require(set(layout['base_files']) == mandatory_base, 'incomplete base executable/DLL/zip inventory')
    require(not any(Path(name).suffix.lower() == '._pth' for name in mandatory_base),
            'base path override file present')
    for name in layout['base_files']:
        path = Path(name)
        require(path.parent == Path(sys.base_prefix) and path.is_file(),
                'base file escapes interpreter directory')
        require(not path.is_symlink() and not getattr(path.stat(),
                'st_file_attributes', 0) & 0x400, 'unsafe base file')
        check()
        files[str(path.resolve())] = digest(path)
    require({'python.exe', 'python312.dll', 'python3.dll'}.issubset(
            {Path(name).name.lower() for name in layout['base_files']}),
            'missing base interpreter identity')
    site_root = venv / 'Lib' / 'site-packages'
    check()
    return {'flags': {'ignore_environment': bool(sys.flags.ignore_environment),
                      'no_user_site': bool(sys.flags.no_user_site),
                      'dont_write_bytecode': bool(sys.flags.dont_write_bytecode)},
            'user_site_enabled': site.ENABLE_USER_SITE,
            'include_system_site_packages': config_values.get('include-system-site-packages'),
            'prefix': str(venv), 'base_prefix': sys.base_prefix,
            'executable': str(Path(sys.executable).resolve()),
            'sys_path': list(sys.path), 'config_values': config_values,
            'site_entries': sorted(path.name for path in site_root.iterdir()),
            'numpy_found': importlib.util.find_spec('numpy') is not None,
            'unsafe_files': sorted(set(unsafe)), 'files': files}


def verify_runtime(contract, check):
    # Keep the admission bounded: complete dependency inventories live in a
    # separately reviewed hash-bound manifest, never an oversized inline packet.
    require(set(contract) == {'manifest', 'sha256'}, 'invalid runtime contract')
    path = Path(contract['manifest'])
    require(path.is_file() and not path.is_symlink()
            and not getattr(path.stat(), 'st_file_attributes', 0) & 0x400
            and path.stat().st_size <= 16 * 1024**2, 'invalid runtime manifest')
    check()
    require(digest(path) == contract['sha256'], 'runtime manifest hash changed')
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, 'duplicate runtime manifest key')
            result[key] = value
        return result
    expected = json.loads(path.read_text(), object_pairs_hook=unique)
    require(set(expected) == {'layout', 'observation'}, 'invalid manifest fields')
    actual = observe_runtime(expected['layout'], check)
    validate_observation(expected['observation'], actual)
    check()
