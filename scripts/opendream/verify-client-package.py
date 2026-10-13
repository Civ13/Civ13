"""Read-only validation of an operator-selected coherent native client package."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import uuid

ENGINE_HEAD = 'ebc7a8289e7aea4ca1d2ed7c6c296ba97706649d'
ROBUST_HEAD = 'af2a7d0406b410c4d960f0f4b34513651c6dc742'
LOADER = 'RobustToolbox/bin/Client/Robust.Client.dll'


def pairs(items):
    result = {}
    for key, value in items:
        if key in result:
            raise ValueError('Duplicate JSON key: ' + key)
        result[key] = value
    return result


def read_json(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 16 * 1024 * 1024:
        raise ValueError('Invalid package metadata: ' + str(path))
    return json.loads(path.read_text(encoding='utf-8-sig'), object_pairs_hook=pairs)


def digest(path):
    with path.open('rb') as stream:
        value = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1048576), b''):
            value.update(chunk)
        return value.hexdigest()


def require_unlinked(path):
    for part in (path, *path.parents):
        if part.is_symlink() or getattr(part, 'is_junction', lambda: False)():
            raise ValueError('Linked package or native path is not allowed')


def safe_name(name):
    path = PurePosixPath(name)
    return (bool(name) and not path.is_absolute() and not any(p in ('.', '..') for p in name.split('/'))
            and '\\' not in name and ':' not in name and path.as_posix() == name)


def verify(package):
    package = Path(package)
    require_unlinked(package)
    if not package.is_absolute() or package.is_symlink():
        raise ValueError('Client package must be an absolute trusted directory')
    receipt = read_json(package / 'receipt.json')
    layout = read_json(package / 'standalone-layout.json')
    if (receipt.get('engine_head') != ENGINE_HEAD or receipt.get('robust_head') != ROBUST_HEAD
            or receipt.get('build') != 'passed'
            or receipt.get('standalone_startup', {}).get('sandboxed_headless_startup') != 'passed'):
        raise ValueError('Package lacks the required exact-head build and sandbox startup receipt')
    if (layout != receipt.get('standalone_layout') or layout.get('schema') != 1
            or layout.get('loader') != LOADER or layout.get('webview') != 'auth-webview'):
        raise ValueError('Standalone layout does not match the coherent receipt')
    declared = layout.get('files')
    if not isinstance(declared, dict) or not declared or len(declared) > 20000:
        raise ValueError('Invalid standalone inventory')
    folded = set()
    for name, entry in declared.items():
        if (not safe_name(name) or name.casefold() in folded or not isinstance(entry, dict)
                or set(entry) != {'sha256', 'bytes'} or type(entry['bytes']) is not int or entry['bytes'] < 0
                or not isinstance(entry['sha256'], str) or not re.fullmatch('[0-9a-f]{64}', entry['sha256'])):
            raise ValueError('Invalid standalone inventory entry: ' + name)
        folded.add(name.casefold())
    root = package / 'standalone'
    if root.is_symlink() or not root.is_dir():
        raise ValueError('Missing standalone root')
    actual = {}
    for path in root.rglob('*'):
        if path.is_symlink() or getattr(path, 'is_junction', lambda: False)():
            raise ValueError('Linked standalone path is not allowed')
        if path.is_file():
            name = path.relative_to(root).as_posix()
            if name not in declared or path.stat().st_size != declared[name]['bytes']:
                raise ValueError('Unexpected or changed standalone file: ' + name)
            actual[name] = {'bytes': path.stat().st_size, 'sha256': digest(path)}
    required = {LOADER, 'Resources/manifest.yml', 'bin/Content.Client/OpenDreamClient.dll',
                'bin/Content.Client/OpenDreamShared.dll', 'auth-webview/Robust.Client.WebView.dll'}
    if (actual != declared or not required.issubset(actual)
            or not any(p.startswith('RobustToolbox/Resources/') for p in actual)):
        raise ValueError('Standalone inventory is incomplete or altered')
    return {'engine_head': ENGINE_HEAD, 'root': str(root), 'loader': str(root / LOADER),
            'webview': str(root / 'auth-webview')}


def verify_native(byond_bin, observer):
    byond_bin, observer = Path(byond_bin), Path(observer)
    require_unlinked(byond_bin)
    require_unlinked(observer)
    if not byond_bin.is_absolute() or not observer.is_absolute():
        raise ValueError('Native paths must be absolute operator configuration')
    if not (byond_bin / 'DreamDaemon.exe').is_file():
        raise ValueError('Native DreamDaemon is unavailable')
    manifest = read_json(observer / 'native-observer.json')
    if (manifest.get('schema') != 1 or manifest.get('byond_version') != '516.1681'
            or manifest.get('source_commit') != ENGINE_HEAD):
        raise ValueError('Unsupported native observer manifest')
    files = manifest.get('files', {})
    for name in ('bridge.dmb', 'bridge.rsc'):
        path, expected = observer / name, files.get(name)
        if name == 'bridge.rsc' and name in files and expected is None:
            if path.exists():
                raise ValueError('Unbound native observer RSC')
            continue
        if (not isinstance(expected, str) or not re.fullmatch('[0-9a-fA-F]{64}', expected)
                or not path.is_file() or path.is_symlink() or path.stat().st_size > 4 * 1024 * 1024
                or digest(path) != expected.lower()):
            raise ValueError('Native observer file differs: ' + name)


def stage(package, parent):
    """Self-contained clients write user_data; keep those writes out of build inputs."""
    verify(package)
    parent = Path(parent)
    if not parent.is_absolute():
        raise ValueError('Runtime staging parent must be absolute')
    require_unlinked(parent)
    parent.mkdir(parents=True, exist_ok=True)
    target = parent / uuid.uuid4().hex
    target.mkdir()  # Exclusive allocation: cleanup below owns exactly this directory.
    try:
        shutil.copytree(Path(package) / 'standalone', target / 'standalone')
        for name in ('receipt.json', 'standalone-layout.json'):
            shutil.copy2(Path(package) / name, target / name)
        result = verify(target)
        result['staging_root'] = str(target)
        return result
    except BaseException:
        if target.resolve().parent != parent.resolve() or not re.fullmatch('[0-9a-f]{32}', target.name):
            raise RuntimeError('Unsafe staging cleanup target')
        shutil.rmtree(target)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', required=True)
    parser.add_argument('--byond-bin', required=True)
    parser.add_argument('--observer', required=True)
    parser.add_argument('--stage-parent')
    args = parser.parse_args()
    result = verify(args.package)
    verify_native(args.byond_bin, args.observer)
    if args.stage_parent:
        result = stage(args.package, args.stage_parent)
    print(json.dumps(result))


if __name__ == '__main__':
    main()
