"""Validate and extract the pinned CAB payload, without executing the SFX."""
import hashlib
import json
import re
import struct
from pathlib import Path
import acquire

OUTER_SHA = '053f76dcbb28802e23341b6a787e3b0791c0fa5c8d4d011b1044172dbf89c73b'
OUTER_SIZE = 100275120
CAB_OFFSET = 155544
CAB_SIZE = 100094202
CAB_SHA = 'a2974015f82256b20e637f72d73d96edfbf11570925a5e2b639c4813a59aee8c'
MANIFEST_SHA = 'd5d7c9dc1e6118b81b28e836e4fce6bc28a4735c5069d17e5b2a3ae04b2b24c8'


def require(ok, code):
    if not ok:
        raise ValueError(code)


def validate_directory(header, manifest):
    require(len(header) >= 44 and header[:4] == b'MSCF', 'cab_header')
    a, size, b, file_offset, c, minor, major, folders, count, flags, _, index = struct.unpack_from('<IIIII BB HHHHH', header, 4)
    require(a == b == c == 0 and size == CAB_SIZE and (major, minor) == (1, 3) and
            folders == 1 and count == 157 and flags == 0 and index == 0 and file_offset == 44,
            'cab_header_fields')
    data_offset, _, _ = struct.unpack_from('<IHH', header, 36)
    require(file_offset <= data_offset <= len(header), 'cab_directory_bounds')
    expected = {r['name']: r['bytes'] for r in manifest}
    require(len(expected) == 157 and len({n.casefold() for n in expected}) == 157,
            'cab_manifest_count')
    observed = {}
    position = file_offset
    for _ in range(count):
        require(position + 16 <= data_offset, 'cab_record_bounds')
        length, _, folder, _, _, attrs = struct.unpack_from('<IIHHHH', header, position)
        end = header.find(b'\0', position + 16, data_offset)
        require(end >= 0, 'cab_name_bounds')
        try:
            name = header[position + 16:end].decode('ascii')
        except UnicodeDecodeError:
            raise ValueError('cab_name_encoding') from None
        require(re.fullmatch(r'[A-Za-z0-9_.-]+', name) is not None and name not in ('.', '..') and
                not name.endswith(('.', ' ')) and folder == 0 and attrs == 32 and name not in observed,
                'cab_unsafe_member')
        observed[name] = length
        position = end + 1
    require(position <= data_offset and observed == expected, 'cab_directory_mismatch')
    return {'files': count, 'bytes': sum(observed.values()), 'directory_end': position}


def write_payload(outer, destination, manifest_path, check_budget):
    outer, destination = Path(outer).absolute(), Path(destination).absolute()
    require(destination.parent == outer.parent, 'cab_destination_outside_workspace')
    acquire._plain_ancestors(outer.parent)
    acquire._plain(outer)
    acquire._plain(Path(manifest_path))
    require(not destination.exists() and not destination.is_symlink(), 'fresh_cab_required')
    raw_manifest = Path(manifest_path).read_bytes()
    require(hashlib.sha256(raw_manifest).hexdigest() == MANIFEST_SHA, 'cab_manifest_hash')
    manifest = json.loads(raw_manifest)
    require(outer.stat().st_size == OUTER_SIZE, 'cab_outer_size')
    digest = hashlib.sha256()
    with outer.open('rb') as src:
        while True:
            check_budget()
            block = src.read(1024*1024)
            if not block: break
            digest.update(block)
        require(digest.hexdigest() == OUTER_SHA, 'cab_outer_hash')
        src.seek(CAB_OFFSET)
        listing = validate_directory(src.read(65536), manifest)
        src.seek(CAB_OFFSET)
        remaining = CAB_SIZE
        cabinet_hash = hashlib.sha256()
        with destination.open('xb') as dst:
            while remaining:
                check_budget()
                block = src.read(min(1024*1024, remaining))
                require(bool(block), 'cab_truncated')
                cabinet_hash.update(block)
                dst.write(block)
                remaining -= len(block)
    require(cabinet_hash.hexdigest() == CAB_SHA, 'cab_payload_hash')
    return {'offset': CAB_OFFSET, 'bytes': CAB_SIZE, 'sha256': CAB_SHA, **listing}
