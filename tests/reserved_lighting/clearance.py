"""Validate frozen declared static rectangles. Does not certify map completeness."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import zlib


def require(value, message):
    if not value:
        raise ValueError(message)


def integers(value, count):
    return type(value) is list and len(value) == count and all(type(n) is int for n in value)


def resource(path):
    require(path.stat().st_size <= 64 * 1024**2, 'Resource size bound')
    data = path.read_bytes()
    require(data[:8] == b'\x89PNG\r\n\x1a\n', 'Expected PNG/DMI resource')
    offset, description = 8, None
    while offset + 12 <= len(data):
        size, kind = struct.unpack('>I4s', data[offset:offset+8])
        require(offset+12+size <= len(data), 'Truncated PNG chunk')
        chunk = data[offset+8:offset+8+size]
        if kind == b'zTXt' and chunk.startswith(b'Description\0\0'):
            require(description is None, 'Duplicate DMI metadata')
            decoder = zlib.decompressobj()
            raw = decoder.decompress(chunk[len(b'Description\0\0'):], 256 * 1024 + 1)
            require(len(raw) <= 256 * 1024 and decoder.eof, 'DMI metadata bound')
            description = raw.decode('utf-8')
        offset += size+12
        if kind == b'IEND':
            break
    require(description is not None, 'DMI metadata absent')
    width = re.search(r'^\s*width\s*=\s*(\d+)\s*$', description, re.M)
    height = re.search(r'^\s*height\s*=\s*(\d+)\s*$', description, re.M)
    width, height = int(width[1]) if width else 32, int(height[1]) if height else 32
    require(1 <= width <= 1024 and 1 <= height <= 1024, 'Unsupported frame dimensions')
    return width, height, set(re.findall(r'^state\s*=\s*"([^"\n]*)"', description, re.M))


def validate(document, repo):
    require(type(document) is dict and set(document) == {'schema_version', 'bindings', 'world', 'region', 'omitted_cells', 'appearances', 'unknowns'}, 'Clearance schema fields')
    require(type(document['schema_version']) is int and document['schema_version'] == 1 and document['unknowns'] == [], 'Unknown appearance/death/state/transform coverage')
    world, region = document['world'], document['region']
    require(integers(world, 3) and all(1 <= n <= 1024 for n in world), 'World bounds')
    require(integers(region, 6) and all(1 <= region[i] <= region[i+3] <= world[i] for i in range(3)), 'Region bounds')
    bindings = document['bindings']
    require(type(bindings) is dict and 1 <= len(bindings) <= 256, 'Frozen source bindings')
    repo = repo.resolve()
    paths = {}
    for relative, expected in bindings.items():
        path = (repo/relative).resolve()
        require(path.is_relative_to(repo) and path.is_file() and not path.is_symlink(), 'Invalid bound source path')
        require(path.stat().st_size <= 64 * 1024**2 and type(expected) is str and re.fullmatch('[0-9a-f]{64}', expected), 'Source hash/size bound')
        require(hashlib.sha256(path.read_bytes()).hexdigest() == expected, 'Frozen source changed: ' + relative)
        paths[relative] = path
    cells = document['omitted_cells']
    require(type(cells) is list and len(cells) <= 65536 and all(integers(cell, 3) for cell in cells), 'Omission coordinates')
    omitted = {tuple(cell) for cell in cells}
    require(len(omitted) == len(cells), 'Duplicate omission coordinate')
    for cell in omitted:
        require(all(1 <= cell[i] <= world[i] for i in range(3)), 'Out-of-world omission')
        require(region[2] <= cell[2] <= region[5] and all(region[i] < cell[i] < region[i+3] for i in (0, 1)), 'Omission crosses graph halo')
    appearances = document['appearances']
    require(type(appearances) is list and len(appearances) <= 4096, 'Appearance inventory bound')
    affected = set()
    for appearance in appearances:
        require(type(appearance) is dict and set(appearance) == {'resource', 'states', 'anchor', 'pixel_x', 'pixel_y', 'transform', 'lifecycle', 'overlays', 'underlays'}, 'Appearance declaration fields')
        require(appearance['transform'] == 'identity' and appearance['lifecycle'] == 'frozen-static'
                and appearance['overlays'] == [] and appearance['underlays'] == [], 'Unsupported dynamic/death/transform/nested appearance')
        anchor = appearance['anchor']
        require(integers(anchor, 3) and all(1 <= anchor[i] <= world[i] for i in range(3)), 'Appearance anchor bounds')
        for axis in ('pixel_x', 'pixel_y'):
            require(integers(appearance[axis], 2) and -1024 <= appearance[axis][0] <= appearance[axis][1] <= 1024, 'Pixel offset bounds')
        require(appearance['resource'] in paths, 'Unbound resource')
        width, height, states = resource(paths[appearance['resource']])
        require(type(appearance['states']) is list and bool(appearance['states'])
                and all(type(state) is str and state in states for state in appearance['states']), 'Unknown declared state')
        # Use complete frame rectangles, never alpha, collision bounds or loc
        # visibility flags. Offset extrema conservatively cover every integer
        # placement in the declared range, on the declared anchor's z only.
        xmin = ((anchor[0]-1)*32 + appearance['pixel_x'][0]) // 32 + 1
        xmax = ((anchor[0]-1)*32 + appearance['pixel_x'][1] + width-1) // 32 + 1
        ymin = ((anchor[1]-1)*32 + appearance['pixel_y'][0]) // 32 + 1
        ymax = ((anchor[1]-1)*32 + appearance['pixel_y'][1] + height-1) // 32 + 1
        for cell in omitted:
            if cell[2] == anchor[2] and xmin <= cell[0] <= xmax and ymin <= cell[1] <= ymax:
                affected.add(cell)
    require(not affected, 'Omission intersects declared appearance: ' + str(sorted(affected)))
    return {'declared_clearance_valid': True, 'omitted_cells': len(omitted),
            'appearance_declarations': len(appearances), 'bound_files': len(bindings),
            'scope': 'Declared frozen static geometry only; inventory completeness and runtime immutability require independent source review; not gate authorization'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('declaration', type=Path)
    parser.add_argument('--repository', type=Path, required=True)
    args = parser.parse_args()
    require(args.declaration.stat().st_size <= 1024**2, 'Declaration size bound')
    print(json.dumps(validate(json.loads(args.declaration.read_text(encoding='utf-8')), args.repository)))
