"""Exact public Git staging; no compiler, toolchain acquisition or live inputs.

An inventory is not independent ancestry proof: the trusted Git archive step
and its reviewed receipt establish the link to head. Consumers rehash all bytes.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile

MAX_FILES = 50000
MAX_BYTES = 4 * 1024**3
RESOURCE_DIRS = ('icons', 'sound', 'UI', 'interface', 'code/js')
TOOLS = {'prepare.py', 'compare.py', 'measurement.py', 'probe.dm', 'containment_pilot.py'}
NATIVE = {'Dockerfile', 'toolchain.json', 'prepare.py', 'run.py', 'test_preflight.py', 'README.md'}


def require(value, message):
    if not value:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def relative(value):
    require(isinstance(value, str) and value and '\\' not in value and ':' not in value,
            'Invalid relative path')
    path = PurePosixPath(value)
    require(not path.is_absolute() and str(path) == value and all(x not in ('', '.', '..') for x in value.split('/')),
            'Path escape/alias')
    return value


def public(path, names):
    relative(path)
    if path.endswith(('.dmb', '.rsc', '.dll', '.so', '.exe', '.zip')):
        return False
    return (path in {'civ13.dme', 'tools/byond/version.json'} or path in names or path.startswith('code/')
            or any(path.startswith(part + '/') for part in RESOURCE_DIRS)
            or path in {'tests/reserved_lighting/' + x for x in TOOLS}
            or path in {'tests/reserved_lighting/native_preflight/' + x for x in NATIVE})


def name_paths(source):
    # Match the existing strict runtime manifest contract, without importing code
    # from an unverified staging tree. No other config subtree is admitted.
    values = re.findall(r'file2list\s*\(\s*"([^"\r\n]+)"', source.decode('utf-8'))
    require(len(values) == 146 and len(set(values)) == 146, 'Expected exact 146 literal public names')
    for value in values:
        require(re.fullmatch(r'config/names/[a-z0-9_]+\.txt', relative(value)), 'Public name path')
    return set(values)


def tree_entries(data):
    entries = {}
    for record in data.split(b'\0'):
        if not record:
            continue
        meta, raw = record.split(b'\t', 1)
        mode, kind, blob = meta.decode('ascii').split()
        path = relative(raw.decode('utf-8'))
        require(path not in entries, 'Duplicate Git path')
        entries[path] = (mode, kind, blob)
    return entries


def extract(archive, entries, destination, head, names):
    require(re.fullmatch('[0-9a-f]{40}', head or ''), 'Exact Git head required')
    allowed = {p: meta for p, meta in entries.items() if public(p, names)}
    require(names <= allowed.keys() and 'civ13.dme' in allowed and 'code/names.dm' in allowed and 'tools/byond/version.json' in allowed, 'Missing source inputs')
    require(0 < len(allowed) <= MAX_FILES, 'Source count bound')
    require(all(mode in ('100644', '100755') and kind == 'blob'
                and re.fullmatch('[0-9a-f]{40}', blob) for mode, kind, blob in allowed.values()),
            'Links/submodules/non-regular Git inputs')
    require(not destination.exists(), 'Fresh destination required')
    destination.mkdir()
    inventory = {}
    total = 0
    # Streaming extraction never trusts tarfile.extract or tar ownership/mode.
    # Failure leaves the partial directory for inspection; no delete/retry.
    with tarfile.open(fileobj=archive, mode='r|') as stream:
        for member in stream:
            path = relative(member.name)
            if member.isdir():
                require(any(p.startswith(path + '/') for p in allowed), 'Unexpected archive directory')
                continue
            require(member.isfile() and path in allowed and path not in inventory, 'Unexpected/duplicate/link archive member')
            require(0 <= member.size <= MAX_BYTES - total, 'Source byte bound')
            target = destination / path
            target.parent.mkdir(parents=True, exist_ok=True)
            sha = hashlib.sha256()
            blob_hash = hashlib.sha1(('blob ' + str(member.size) + '\0').encode())
            copied = 0
            with stream.extractfile(member) as source, target.open('xb') as output:
                while True:
                    block = source.read(min(1024**2, member.size - copied + 1))
                    if not block:
                        break
                    copied += len(block)
                    require(copied <= member.size, 'Archive size drift')
                    output.write(block); sha.update(block); blob_hash.update(block)
            require(copied == member.size and blob_hash.hexdigest() == allowed[path][2], 'Git blob mismatch')
            inventory[path] = {'sha256': sha.hexdigest(), 'git_blob': allowed[path][2], 'bytes': copied}
            total += copied
    require(inventory.keys() == allowed.keys(), 'Missing archive files')
    require(name_paths((destination / 'code/names.dm').read_bytes()) == names, 'Names source drift')
    manifest = {'schema': 1, 'head': head, 'provenance': 'git-archive exact-head; regular public allowlist',
                'files': inventory, 'total_bytes': total, 'compiled_artifacts': 0}
    (destination / 'source.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    return manifest


def validate(root, manifest):
    require(re.fullmatch('[0-9a-f]{40}', manifest.get('head') or ''), 'Source head')
    names = name_paths((root / 'code/names.dm').read_bytes())
    require(names <= manifest['files'].keys() and 'tools/byond/version.json' in manifest['files']
            and 0 < len(manifest['files']) <= MAX_FILES
            and all(public(path, names) for path in manifest['files']), 'Staged allowlist')
    require(sum(info['bytes'] for info in manifest['files'].values()) == manifest['total_bytes'] <= MAX_BYTES, 'Staged aggregate bound')
    expected = set(manifest['files']) | {'source.json'}
    actual = set()
    for path in root.rglob('*'):
        require(not path.is_symlink(), 'Staged link')
        if path.is_file():
            actual.add(path.relative_to(root).as_posix())
    require(actual == expected, 'Missing/unexpected staged files')
    for path, info in manifest['files'].items():
        target = root / relative(path)
        size = target.stat().st_size
        value = hashlib.sha256()
        blob = hashlib.sha1(('blob ' + str(size) + '\0').encode())
        with target.open('rb') as source:
            for block in iter(lambda: source.read(1024**2), b''):
                value.update(block); blob.update(block)
        require(size == info['bytes'] and value.hexdigest() == info['sha256']
                and blob.hexdigest() == info['git_blob'], 'Staged input changed')


def prepare(repo, destination, head):
    require(re.fullmatch('[0-9a-f]{40}', head or ''), 'Exact head required')
    def git(*args):
        return subprocess.check_output(['git', '-C', str(repo), *args], timeout=30)
    require(git('rev-parse', head + '^{commit}').decode().strip() == head, 'Head resolution changed')
    entries = tree_entries(git('ls-tree', '-r', '-z', head))
    names = name_paths(git('show', head + ':code/names.dm'))
    paths = sorted(p for p in entries if public(p, names))
    # Archive stdout is consumed incrementally and stopped on extraction error.
    child = subprocess.Popen(['git', '-C', str(repo), 'archive', '--format=tar', head, '--', *paths],
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    try:
        result = extract(child.stdout, entries, destination, head, names)
        require(child.wait(timeout=30) == 0, 'Git archive failed')
        validate(destination, result)
        return result
    finally:
        child.stdout.close()
        if child.poll() is None:
            child.kill(); child.wait(timeout=3)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--head', required=True)
    args = parser.parse_args()
    print(json.dumps(prepare(args.repo, args.output, args.head), indent=2))
