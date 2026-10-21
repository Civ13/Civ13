"""Inert by default. Real HTTPS plus a dedicated hard-tmpfs capture backend.

This first acquisition stage captures candidate identities only. It neither
supplies the image-controller protocol nor executes/extracts downloaded code.
The caller must provision an isolated cgroup, outer watchdog and fresh mount.
"""
import argparse
from contextlib import contextmanager
import errno
import hashlib
import http.client
import io
import ipaddress
import json
import math
import os
from pathlib import Path
import re
import socket
import ssl
import stat
import struct
import sys
import time
import zipfile

URL = 'https://www.byond.com/download/build/516/516.1681_byond_linux.zip'
HOST = 'www.byond.com'
RESOURCE = '/download/build/516/516.1681_byond_linux.zip'
SCOPE = 'civ13-byond-official-identity-capture-only'
LIMITS = {'wall_seconds': 120, 'cleanup_seconds': 15, 'request_seconds': 10,
          'archive_bytes': 8*1024**2, 'expanded_bytes': 128*1024**2,
          'member_bytes': 64*1024**2, 'members': 512,
          'scratch_bytes': 16*1024**2, 'receipt_bytes': 256*1024}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data): return hashlib.sha256(data).hexdigest()


def canonical(value): return json.dumps(value, sort_keys=True, separators=(',', ':')).encode()


def cleanup_preserving(action, primary, label):
    try: action()
    except BaseException as failure:
        if primary is None: raise
        primary.add_note(label+': '+str(failure)[:512])


@contextmanager
def owned_file(handle):
    primary = None
    try: yield handle
    except BaseException as failure:
        primary = failure
        raise
    finally: cleanup_preserving(handle.close, primary, 'Additional owned file close failure')


def hosted_identity(request, environment=os.environ):
    require(sys.platform == 'linux' and environment.get('GITHUB_ACTIONS') == 'true'
            and environment.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
            and environment.get('GITHUB_REPOSITORY') == 'Civ13/Civ13'
            and environment.get('GITHUB_REPOSITORY_ID') == '141349998'
            and environment.get('GITHUB_SHA') == request.get('head')
            and environment.get('RUNNER_ENVIRONMENT') == 'github-hosted'
            and environment.get('RUNNER_OS') == 'Linux'
            and environment.get('GITHUB_RUN_ATTEMPT') == '1', 'Exact public hosted manual attempt1 required')
    # The dispatcher must independently verify repository visibility, literal
    # standard ubuntu-24.04 runner, workflow identity and no duplicate run.


class Budget:
    def __init__(self, ends, clock=time.monotonic, utc=time.time):
        self.clock, self.utc, self.ends = clock, utc, ends
        self.deadline = clock() + LIMITS['wall_seconds']

    def remaining(self): return min(self.deadline-self.clock(), self.ends-self.utc())

    def check(self, cleanup=False):
        require(self.remaining() > (0 if cleanup else LIMITS['cleanup_seconds']), 'Capture deadline/reserve')

    def timeout(self):
        self.check()
        return min(LIMITS['request_seconds'], self.remaining()-LIMITS['cleanup_seconds'])


class HTTPS:
    """One fixed public IP, TLS hostname verification, no DNS/proxy/redirect/retry.

    http.client parses at most 100 bounded headers. Content framing and identity
    are checked separately. TLS certificate hash records observation, not a
    claim that the publisher signed a package checksum.
    """
    def __init__(self, peer_ip, connector=socket.create_connection, context=None):
        require(ipaddress.ip_address(peer_ip).is_global, 'Public frozen TLS peer required')
        self.peer_ip, self.connector = peer_ip, connector
        self.context = context or ssl.create_default_context()
        require(self.context.check_hostname and self.context.verify_mode == ssl.CERT_REQUIRED, 'Verified TLS required')
        self.context.minimum_version = ssl.TLSVersion.TLSv1_2
        self.raw = self.tls = self.response = None

    def open(self, budget):
        try:
            self.raw = self.connector((self.peer_ip, 443), timeout=budget.timeout())
            budget.check()
            self.raw.settimeout(budget.timeout())
            self.tls = self.context.wrap_socket(self.raw, server_hostname=HOST)
            require(self.tls.getpeername()[0] == self.peer_ip, 'TLS peer drift')
            self.tls.settimeout(budget.timeout())
            self.tls.sendall(('GET '+RESOURCE+' HTTP/1.1\r\nHost: '+HOST+
                              '\r\nAccept-Encoding: identity\r\nConnection: close\r\nUser-Agent: Civ13-identity-capture/1\r\n\r\n').encode('ascii'))
            self.response = http.client.HTTPResponse(self.tls)
            self.response.begin()
            budget.check()
            require(self.response.status == 200, 'Capture HTTP status/redirect rejected')
            headers = self.response.headers
            lengths = headers.get_all('Content-Length', [])
            require(len(lengths) == 1 and lengths[0].isascii() and lengths[0].isdigit(), 'Single exact HTTP length required')
            self.length = int(lengths[0])
            require(0 < self.length <= LIMITS['archive_bytes'], 'Archive byte bound')
            require(headers.get('Transfer-Encoding') is None and headers.get('Content-Encoding', 'identity') == 'identity', 'Ambiguous/encoded response rejected')
            return {'url': URL, 'peer_ip': self.peer_ip, 'certificate_sha256': sha(self.tls.getpeercert(binary_form=True)),
                    'bytes': self.length, 'last_modified': str(headers.get('Last-Modified', ''))[:128]}
        except BaseException:
            self.close()
            raise

    def read(self, budget):
        self.tls.settimeout(budget.timeout())
        block = self.response.read(65536)
        budget.check()
        return block

    def close(self):
        # Close errors may not replace an earlier transport error.
        failures = []
        for value in (self.response, self.tls, self.raw):
            if value is not None:
                try: value.close()
                except BaseException as failure: failures.append(str(failure)[:128])
        return failures


def member_path(name):
    require(isinstance(name, str) and 0 < len(name.encode()) <= 256 and '\\' not in name and ':' not in name,
            'Unsafe ZIP name')
    value = name.rstrip('/')
    require(not value.startswith('/') and all(part not in ('', '.', '..') for part in value.split('/')), 'ZIP traversal/alias')
    return value


def elf_dependencies(data):
    """Static ELF32 LE PT_DYNAMIC inspection only; never execute ldd/binaries."""
    if not data.startswith(b'\x7fELF'): return None
    require(len(data) >= 52 and data[4:7] == b'\x01\x01\x01', 'Expected ELF32 little-endian version1')
    header = struct.unpack_from('<16sHHIIIIIHHHHHH', data)
    require(header[2] == 3 and header[9] == 32 and header[10] <= 128, 'Expected bounded i386 ELF program headers')
    phoff, count = header[5], header[10]
    require(phoff+count*32 <= len(data), 'Truncated ELF program headers')
    segments = [struct.unpack_from('<IIIIIIII', data, phoff+i*32) for i in range(count)]
    for p in segments: require(p[1]+p[4] <= len(data), 'ELF segment outside member')
    dynamic = [p for p in segments if p[0] == 2]
    require(len(dynamic) <= 1, 'Ambiguous ELF dynamic table')
    if not dynamic: return []
    p = dynamic[0]
    require(p[4] <= 65536 and p[4] % 8 == 0, 'ELF dynamic table bound')
    tags, terminated = [], False
    for offset in range(p[1], p[1]+p[4], 8):
        tag, value = struct.unpack_from('<II', data, offset)
        if tag == 0:
            terminated = True
            break
        tags.append((tag, value))
    require(terminated, 'Unterminated ELF dynamic table')
    names = [value for tag, value in tags if tag == 1]
    if not names: return []
    tables, sizes = [v for t, v in tags if t == 5], [v for t, v in tags if t == 10]
    require(len(tables) == len(sizes) == 1 and 0 < sizes[0] <= 1024**2 and len(names) <= 128, 'ELF string-table bound')
    spans = [p for p in segments if p[0] == 1 and p[2] <= tables[0] and tables[0]+sizes[0] <= p[2]+p[4]]
    require(len(spans) == 1, 'ELF string table not uniquely file backed')
    base = spans[0][1]+tables[0]-spans[0][2]
    result = []
    for offset in names:
        require(offset < sizes[0], 'ELF dependency outside string table')
        end = data.find(b'\0', base+offset, base+sizes[0])
        require(end >= 0 and end-base-offset <= 128, 'ELF dependency string bound')
        name = data[base+offset:end].decode('ascii')
        require(re.fullmatch(r'[A-Za-z0-9_.+\-]+', name), 'ELF dependency path rejected')
        result.append(name)
    return sorted(set(result))


def inventory(data, budget):
    # Validate central directory bounds before ZipFile allocates per-member data.
    require(len(data) <= LIMITS['archive_bytes'], 'ZIP input bound')
    index = data.rfind(b'PK\x05\x06', max(0, len(data)-65557))
    require(index >= 0 and index+22 <= len(data), 'Missing ZIP end record')
    fields = struct.unpack_from('<4s4H2IH', data, index)
    require(fields[1:3] == (0, 0) and fields[3] == fields[4] and 0 < fields[4] <= LIMITS['members']
            and fields[5] <= 256*1024 and fields[6]+fields[5] == index and index+22+fields[7] == len(data), 'ZIP directory/multidisk/ZIP64 bound')
    rows, seen, total = [], set(), 0
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        entries = archive.infolist()
        require(len(entries) == fields[4], 'ZIP member count drift')
        for entry in entries:
            budget.check()
            name = member_path(entry.filename)
            require(name not in seen, 'Duplicate/aliased ZIP name')
            seen.add(name)
            mode = entry.external_attr >> 16
            require(not entry.flag_bits & 1 and entry.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)
                    and not stat.S_ISLNK(mode) and stat.S_IFMT(mode) in (0, stat.S_IFREG, stat.S_IFDIR), 'ZIP encryption/type/method rejected')
            require(0 <= entry.file_size <= LIMITS['member_bytes'], 'ZIP member expansion bound')
            total += entry.file_size
            require(total <= LIMITS['expanded_bytes'], 'ZIP aggregate expansion bound')
            if entry.is_dir():
                require(entry.file_size == 0, 'ZIP directory data')
                continue
            result, actual, elf = hashlib.sha256(), 0, bytearray()
            inspect = name.endswith(('/DreamMaker', '/DreamDaemon'))
            with archive.open(entry) as member:
                while True:
                    budget.check()
                    block = member.read(65536)
                    if not block: break
                    actual += len(block)
                    require(actual <= entry.file_size, 'ZIP member overflow')
                    result.update(block)
                    if inspect: elf.extend(block)
            require(actual == entry.file_size, 'ZIP member truncated')
            row = {'path': name, 'bytes': actual, 'sha256': result.hexdigest()}
            if inspect:
                row['elf_needed'] = elf_dependencies(elf)
                require(row['elf_needed'] is not None, 'Expected BYOND executable is not ELF')
            rows.append(row)
    require({'DreamMaker', 'DreamDaemon'} <= {r['path'].split('/')[-1] for r in rows if 'elf_needed' in r}, 'Missing compiler/daemon static identity')
    require(len(canonical(rows)) <= LIMITS['receipt_bytes']-8192, 'Inventory receipt bound')
    return rows


class Scratch:
    """Use an already mounted fresh private tmpfs, never mount/unmount here.

    Mount lifecycle and controller cgroup/watchdog belong to the named executor.
    All operations use the retained directory FD and O_NOFOLLOW. Cleanup only
    removes files this instance exclusively created with unchanged dev/inode.
    """
    def __init__(self, path, owner, mountinfo='/proc/self/mountinfo'):
        require(sys.platform == 'linux' and re.fullmatch('[0-9a-f]{32}', owner or ''), 'Linux/fresh owner required')
        require(str(path) == '/run/civ13-capture-'+owner, 'Exact isolated scratch path')
        self.path, self.owner, self.files = str(path), owner, {}
        self.fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            self.identity = os.fstat(self.fd)
            require(self.identity.st_uid == os.geteuid() and stat.S_IMODE(self.identity.st_mode) == 0o700, 'Scratch owner/mode drift')
            records = [line.split() for line in Path(mountinfo).read_text().splitlines()]
            rows = [r for r in records if len(r) > 9 and r[4] == self.path]
            require(len(rows) == 1, 'One exact dedicated mount required')
            row = rows[0]; sep = row.index('-')
            require(row[sep+1] == 'tmpfs' and {'rw', 'nosuid', 'nodev', 'noexec'} <= set(row[5].split(','))
                    and not any(x.startswith(('shared:', 'master:', 'propagate_from:')) for x in row[6:sep]), 'Private noexec hard tmpfs required')
            require(row[3] == '/' and row[2] == str(os.major(self.identity.st_dev))+':'+str(os.minor(self.identity.st_dev)), 'Mount identity drift')
            self.mount_id = row[0]
            volume = os.fstatvfs(self.fd)
            require(volume.f_blocks*volume.f_frsize == LIMITS['scratch_bytes'] and not os.listdir(self.fd), 'Exact empty hard scratch capacity required')
            with owned_file(self.create('owner.json')) as output: output.write(canonical({'owner': owner}))
        except BaseException:
            os.close(self.fd)
            raise

    def create(self, name):
        require(name in ('owner.json', 'capacity.bin', 'archive.zip') and name not in self.files, 'Exclusive named capture file')
        fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=self.fd)
        identity = os.fstat(fd)
        self.files[name] = (identity.st_dev, identity.st_ino)
        return os.fdopen(fd, 'wb', buffering=0)

    def remove(self, name):
        identity = os.stat(name, dir_fd=self.fd, follow_symlinks=False)
        require(stat.S_ISREG(identity.st_mode) and self.files.get(name) == (identity.st_dev, identity.st_ino), 'Owned file identity changed; no deletion')
        os.unlink(name, dir_fd=self.fd)
        del self.files[name]

    def capacity(self, budget):
        created, primary = False, None
        try:
            output = self.create('capacity.bin')
            created = True
            with owned_file(output):
                count = 0
                while count <= LIMITS['scratch_bytes']:
                    budget.check()
                    try:
                        written = output.write(b'\0'*65536)
                        require(type(written) is int and written > 0, 'Capacity write contract')
                        count += written
                    except OSError as failure:
                        require(failure.errno == 28, 'Expected Linux ENOSPC28')
                        return {'errno': 28, 'written': count, 'mount_id': self.mount_id, 'hard_bytes': LIMITS['scratch_bytes']}
                raise ValueError('No causal hard capacity bound')
        except BaseException as failure:
            primary = failure
            raise
        finally:
            if created: cleanup_preserving(lambda: self.remove('capacity.bin'), primary, 'Additional owned probe removal failure')

    def bytes(self):
        fd = os.open('archive.zip', os.O_RDONLY | os.O_NOFOLLOW, dir_fd=self.fd)
        with os.fdopen(fd, 'rb') as source:
            identity = os.fstat(source.fileno())
            require(self.files.get('archive.zip') == (identity.st_dev, identity.st_ino) and identity.st_size <= LIMITS['archive_bytes'], 'Archive identity/size drift')
            data = source.read(LIMITS['archive_bytes']+1)
            require(len(data) == identity.st_size, 'Archive read drift')
            return data

    def cleanup(self):
        try:
            for name in tuple(self.files): self.remove(name)
            require(not os.listdir(self.fd), 'Unexpected scratch writers; retain mount')
            return {'owned_files_removed': True, 'mount_requires_executor_retirement': True}
        finally: os.close(self.fd)


def capture(request, grant, transport, scratch_factory=Scratch, clock=time.monotonic, utc=time.time):
    require(request.get('scope') == SCOPE and request.get('url') == URL and request.get('limits') == LIMITS, 'Exact capture-only request')
    require(re.fullmatch('[0-9a-f]{40}', request.get('head') or '') and re.fullmatch('[0-9a-f]{32}', request.get('owner') or '')
            and request.get('executor') and ipaddress.ip_address(request['peer_ip']).is_global, 'Unresolved source/owner/executor/TLS peer')
    require(all(request.get(x) == 0 for x in ('image_count', 'compile_count', 'daemon_count', 'package_install_count')), 'No executable acquisition in capture')
    now = utc()
    require(grant.get('granted') is True and grant.get('scope') == SCOPE and grant.get('request_sha256') == sha(canonical(request))
            and grant.get('head') == request['head'] and grant.get('executor') == request['executor']
            and all(type(grant.get(k)) in (int, float) and math.isfinite(grant[k]) for k in ('starts', 'ends'))
            and grant['starts'] <= now < grant['ends'], 'No exact one-use capture grant')
    require(grant.get('external_controls_reviewed') is True, 'External watchdog/cgroup/mount/egress controls unresolved')
    frozen, budget = sha(canonical(request)), Budget(grant['ends'], clock, utc)
    result = {'scope': SCOPE, 'request_sha256': frozen, 'complete': False, 'native_count': 0, 'status': 'INCOMPLETE'}
    scratch = None
    try:
        budget.check()
        scratch = scratch_factory('/run/civ13-capture-'+request['owner'], request['owner'])
        result['capacity'] = scratch.capacity(budget)
        result['transport'] = transport.open(budget)
        require(result['transport'].get('url') == URL and result['transport'].get('peer_ip') == request['peer_ip']
                and re.fullmatch('[0-9a-f]{64}', result['transport'].get('certificate_sha256') or '')
                and type(result['transport'].get('bytes')) is int and 0 < result['transport']['bytes'] <= LIMITS['archive_bytes'], 'Transport identity drift')
        count, hashed = 0, hashlib.sha256()
        with owned_file(scratch.create('archive.zip')) as output:
            while True:
                block = transport.read(budget)
                require(type(block) is bytes, 'Binary capture stream required')
                if not block: break
                count += len(block)
                require(count <= min(LIMITS['archive_bytes'], result['transport']['bytes']), 'Capture length overflow')
                require(output.write(block) == len(block), 'Short archive write')
                hashed.update(block)
        budget.check()
        require(count == result['transport']['bytes'], 'Capture length mismatch')
        data = scratch.bytes()
        require(len(data) == count and sha(data) == hashed.hexdigest(), 'Captured file changed before inventory')
        result.update(archive_sha256=hashed.hexdigest(), archive_bytes=count, members=inventory(data, budget))
        require(sha(canonical(request)) == frozen, 'Request changed during capture')
        budget.check()
    except BaseException as failure:
        result['error'] = str(failure)[:512]
        result['error_notes'] = [str(note)[:512] for note in getattr(failure, '__notes__', [])[:8]]
    finally:
        try:
            failures = transport.close()
            if failures: result['transport_cleanup_errors'] = failures
        except BaseException as failure: result['transport_cleanup_errors'] = [str(failure)[:512]]
        if scratch is not None:
            try:
                budget.check(cleanup=True)
                result['cleanup'] = scratch.cleanup()
                budget.check(cleanup=True)
            except BaseException as failure: result['cleanup_error'] = str(failure)[:512]
        result['complete'] = not any(k in result for k in ('error', 'cleanup_error', 'transport_cleanup_errors')) and result.get('cleanup', {}).get('owned_files_removed') is True
        result['status'] = 'CANDIDATE_IDENTITIES_ONLY_REQUIRES_REVIEW' if result['complete'] else 'INCOMPLETE'
    require(len(canonical(result)) <= LIMITS['receipt_bytes'], 'Final capture receipt bound')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    parser.add_argument('--request', type=Path)
    parser.add_argument('--grant', type=Path)
    args = parser.parse_args()
    if not args.capture:
        print(json.dumps({'scope': SCOPE, 'status': 'INERT_NO_CAPTURE', 'limits': LIMITS}, sort_keys=True))
    else:
        raise ValueError('Standalone capture is disabled; use the reviewed outer launcher and atomic single-use record')
