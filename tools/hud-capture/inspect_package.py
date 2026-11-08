"""Read-only PE/ZIP inspection. Never loads or executes inspected binaries."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile


def pe_imports(data):
    def u16(offset):
        return struct.unpack_from('<H', data, offset)[0]
    def u32(offset):
        return struct.unpack_from('<I', data, offset)[0]
    if len(data) < 64 or data[:2] != b'MZ':
        raise ValueError('Not PE')
    pe = u32(0x3c)
    if data[pe:pe+4] != b'PE\0\0':
        raise ValueError('Not PE')
    machine, count, optsize = u16(pe+4), u16(pe+6), u16(pe+20)
    opt = pe + 24
    if machine != 0x14c or u16(opt) != 0x10b or count > 32 or optsize < 224:
        raise ValueError('Expected bounded x86 PE32')
    imagebase, headers = u32(opt+28), u32(opt+60)
    sections = []
    for i in range(count):
        offset = opt + optsize + i * 40
        sections.append((u32(offset+12), u32(offset+16), u32(offset+20)))
    def offset(rva, size=1):
        for va, rawsize, raw in sections:
            if va <= rva and rva + size <= va + rawsize:
                result = raw + rva - va
                if result + size <= len(data):
                    return result
        if rva + size <= min(headers, len(data)):
            return rva
        raise ValueError('Unbacked PE RVA')
    def string(rva):
        start = offset(rva)
        end = data.find(b'\0', start, min(start+256, len(data)))
        if end < start:
            raise ValueError('Unbounded PE name')
        return data[start:end].decode('ascii').lower()
    result = {'machine': '0x014c', 'imports': [], 'delay_imports': []}
    for directory, width, namefield, target in [(1, 20, 12, 'imports'), (13, 32, 4, 'delay_imports')]:
        rva, size = u32(opt+96+directory*8), u32(opt+100+directory*8)
        if not rva:
            continue
        if not 0 < size <= 65536:
            raise ValueError('Unbounded import table')
        for i in range(min(size//width, 512)):
            at = offset(rva+i*width, width)
            if data[at:at+width] == b'\0'*width:
                break
            name = u32(at+namefield)
            if directory == 13 and not (u32(at) & 1):
                name -= imagebase
            result[target].append(string(name))
        else:
            raise ValueError('Unterminated import table')
    return result


def inspect(archive):
    data = archive.read_bytes()
    if len(data) != 8602470 or hashlib.sha256(data).hexdigest() != '9079f29b0747719233715dfeff223641e6fb69bd16b8ba9676d5cd42cfcd0148':
        raise ValueError('Not the reviewed 516.1688 ZIP')
    result = {'archive_bytes': len(data), 'archive_sha256': hashlib.sha256(data).hexdigest(), 'executed': False, 'binaries': {}}
    with zipfile.ZipFile(archive) as z:
        members = z.infolist()
        if len(members) > 256 or sum(i.file_size for i in members) > 128*1024*1024:
            raise ValueError('Archive bounds exceeded')
        result['files'] = [i.filename for i in members if not i.is_dir()]
        for item in members:
            if item.filename.startswith('byond/bin/') and item.filename.lower().endswith(('.exe', '.dll')):
                raw = z.read(item)
                result['binaries'][item.filename] = dict(bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest(), **pe_imports(raw))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('archive', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.write_text(json.dumps(inspect(args.archive), indent=2)+'\n')
