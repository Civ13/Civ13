"""Passive Linux runtime identity from the reviewed archive; never execute BYOND."""
import argparse
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import zipfile

_spec = importlib.util.spec_from_file_location('runtime_byond_pin', Path(__file__).with_name('byond_toolchain.py'))
pin = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pin)

MEMBERS = ('DreamMaker', 'DreamDaemon', 'libbyond.so', 'libext.so')
MAX_MEMBER_BYTES = 32 * 1024 * 1024


def _unlinked_path(path):
    path = Path(path).absolute()
    if '..' in path.parts:
        raise ValueError('Parent traversal is not a runtime identity path')
    for parent in reversed(path.parents):
        info = parent.lstat()
        if not stat.S_ISDIR(info.st_mode) or getattr(info, 'st_file_attributes', 0) & 0x400:
            raise ValueError('Runtime identity paths require ordinary unlinked directories')
    return path


def _read_regular(path, expected_bytes, maximum):
    path = _unlinked_path(path)
    before = path.lstat()
    if (not stat.S_ISREG(before.st_mode) or getattr(before, 'st_file_attributes', 0) & 0x400
            or before.st_size != expected_bytes or not 0 < expected_bytes <= maximum):
        raise ValueError('Runtime identity file is linked, nonregular or has an unexpected size')
    # The no-follow open and matching descriptor reject leaf substitution. Parent
    # checks are repeated, but this is not an atomic filesystem snapshot/lock.
    fd = os.open(path, os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0) | getattr(os, 'O_NONBLOCK', 0)
                 | getattr(os, 'O_BINARY', 0))
    with os.fdopen(fd, 'rb') as stream:
        opened = os.fstat(stream.fileno())
        if (not stat.S_ISREG(opened.st_mode)
                or (opened.st_dev, opened.st_ino, opened.st_size) != (before.st_dev, before.st_ino, before.st_size)):
            raise ValueError('Runtime identity file changed while opening')
        data = stream.read(expected_bytes + 1)
        after = os.fstat(stream.fileno())
    current = _unlinked_path(path).lstat()
    identity = lambda info: (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)
    if (len(data) != expected_bytes or identity(before) != identity(after)
            or identity(after) != identity(current)):
        raise ValueError('Runtime identity file changed while reading')
    return data


def verify_linux(bin_dir, archive_path):
    """Verify four installed members against exact pinned ZIP bytes, without effects.

    Call again immediately before each compiler/daemon launch. The returned target
    version is bound to archive identity, not an observed native version banner.
    System loader libraries, external extensions and gameplay are outside scope.
    """
    requirement = pin.load()
    archive = requirement['linux']
    data = _read_regular(archive_path, archive['bytes'], pin.MAX_BYTES)
    if hashlib.sha256(data).hexdigest() != archive['sha256']:
        raise ValueError('Linux archive differs from the reviewed SHA-256')
    bin_dir = _unlinked_path(bin_dir)
    if not stat.S_ISDIR(bin_dir.lstat().st_mode):
        raise ValueError('Runtime bin directory is not an ordinary unlinked directory')
    members = {}
    with zipfile.ZipFile(io.BytesIO(data)) as package:
        entries = package.infolist()
        for name in MEMBERS:
            matches = [entry for entry in entries if entry.filename == 'byond/bin/' + name]
            if len(matches) != 1:
                raise ValueError('Missing or duplicate reviewed runtime archive member: ' + name)
            entry = matches[0]
            if (entry.create_system != 3 or not stat.S_ISREG(entry.external_attr >> 16)
                    or entry.flag_bits & 1 or not 0 < entry.file_size <= MAX_MEMBER_BYTES):
                raise ValueError('Runtime archive member is not a bounded regular file: ' + name)
            with package.open(entry) as stream:
                expected = stream.read(entry.file_size + 1)
            if len(expected) != entry.file_size:
                raise ValueError('Runtime archive member size differs: ' + name)
            digest = hashlib.sha256(expected).hexdigest()
            installed = _read_regular(bin_dir / name, entry.file_size, MAX_MEMBER_BYTES)
            if hashlib.sha256(installed).hexdigest() != digest:
                raise ValueError('Installed runtime differs from the reviewed archive: ' + name)
            members[name] = {'sha256': digest, 'bytes': entry.file_size}
    return {'version': requirement['version'], 'platform': 'linux',
            'identity_basis': 'exact-member-match-to-pinned-linux-archive',
            'archive': {'sha256': archive['sha256'], 'bytes': archive['bytes']},
            'members': members}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--byond-archive', type=Path, required=True)
    args = parser.parse_args(argv)
    print(json.dumps(verify_linux(args.byond_bin, args.byond_archive), indent=2))


if __name__ == '__main__':
    main()
