"""Inert acquisition-only source wrapper; no default transport/storage/image backend.

Reuses strict no-auto-redirect/hash/size principles from native/Byond.cs and
the preflight's retained budgets/owned cleanup. Never invoke the CI bootstrap.
No CLI execution switch is supplied: a separately reviewed hosted wrapper must
provide admitted adapters, immutable identities and exact one-use grant.
"""
import argparse
import hashlib
import io
import json
import math
import lzma
from pathlib import Path, PurePosixPath
import re
import struct
import time
from urllib.parse import urlsplit
import zipfile
import zlib

SCOPE = 'civ13-reserved-toolchain-acquisition-only'
BASE = 'docker.io/library/python@sha256:57d96f71de145a98e7ceca18ee4ade77bba4103a33a72dfaea026b23625c6bf0'
BASE_ID = 'sha256:3c4d812a6efe003770aafbdba65f9c1960ba8234ab23a133934205a70bdcda77'
LIMITS = {'outer_seconds': 600, 'cleanup_seconds': 30, 'request_seconds': 10, 'download_total_bytes': 576*1024**2,
          'source_bytes': 2*1024**3, 'daemon_bytes': 8*1024**3, 'evidence_bytes': 128*1024**2,
          'export_bytes': 2*1024**3, 'rootfs_bytes': 512*1024**2, 'file_bytes': 64*1024**2,
          'members': 4096, 'receipt_bytes': 8*1024**2}
REGISTRY = ['registry-1.docker.io', 'auth.docker.io', 'production.cloudflare.docker.com']


def require(value, message):
    if not value: raise ValueError(message)


def digest(data): return hashlib.sha256(data).hexdigest()


def close_preserving(action, primary):
    try:
        action()
    except BaseException as failure:
        if primary is None: raise
        primary.add_note('Additional owned-handle cleanup failure: ' + str(failure)[:512])


def relative(value):
    require(isinstance(value, str) and 0 < len(value.encode('utf-8')) <= 512 and '\\' not in value and ':' not in value, 'Relative member path')
    require(str(PurePosixPath(value)) == value and not value.startswith('/')
            and all(part not in ('', '.', '..') for part in value.split('/')), 'Member escape/alias')
    return value


def route(url):
    value = urlsplit(url)
    require(value.scheme == 'https' and value.port in (None, 443) and not value.username and not value.password
            and not value.query and not value.fragment and value.netloc == value.hostname, 'Public HTTPS route required')
    allowed = (url == 'https://www.byond.com/download/build/516/516.1681_byond_linux.zip'
               or value.hostname == 'deb.debian.org' and value.path.startswith('/debian/pool/') and value.path.endswith('.deb'))
    require(allowed and all(part not in ('.', '..') for part in value.path.split('/')) and '%' not in value.path, 'Acquisition route not admitted')


def artifact(value, kind):
    require(value.get('kind') == kind and re.fullmatch('[0-9a-f]{64}', value.get('sha256') or ''), 'Unresolved download identity')
    route(value['url'])
    require(type(value.get('bytes')) is int and 0 < value['bytes'] <= LIMITS['file_bytes'], 'Download byte bound')
    require(type(value.get('members')) is dict and value['members'], 'Explicit member allowlist required')
    for name, target in value['members'].items():
        relative(name); relative(target['path'])
        require(target['path'].startswith(('opt/byond/', 'lib/', 'usr/lib/')), 'Rootfs destination outside toolchain/library closure')
        require(re.fullmatch('[0-9a-f]{64}', target.get('sha256') or '')
                and type(target.get('bytes')) is int and 0 < target['bytes'] <= LIMITS['file_bytes'], 'Unresolved rootfs member identity')


def validate(plan):
    require(plan.get('schema') == 1 and plan.get('status') == 'INDEPENDENTLY_REVIEWED' and plan.get('scope') == SCOPE,
            'Unresolved acquisition plan')
    require(re.fullmatch('[0-9a-f]{40}', plan.get('head') or '') and plan.get('executor'), 'Exact head/executor')
    require(plan.get('byond_version') == '516.1681' and plan.get('limits') == LIMITS
            and plan.get('base_image') == BASE and plan.get('base_image_id') == BASE_ID, 'Scope/bounds/base drift')
    require(re.fullmatch('[0-9a-f]{64}', plan.get('recipe_sha256') or '')
            and plan.get('image_output_mode') == 'CAPTURE_CANDIDATE_FOR_INDEPENDENT_REVIEW', 'Unresolved recipe/output contract')
    require(plan.get('dependency_closure_provenance') and plan.get('network_provenance') and plan.get('artifact_handoff_provenance'),
            'Missing independent dependency/network/storage provenance')
    artifact(plan['archive'], 'zip')
    require(0 < len(plan['dependencies']) <= 32, 'Pinned dependency closure required')
    for value in plan['dependencies']:
        artifact(value, 'deb')
        require(value.get('package') and value.get('version') and value.get('architecture') in ('i386', 'amd64', 'all')
                and value.get('package_metadata_provenance'), 'Dependency version/architecture/source required')
    downloads = [plan['archive'], *plan['dependencies']]
    urls = [value['url'] for value in downloads]
    require(len(urls) == len(set(urls)) and plan['routes'] == urls and plan['registry_hosts'] == REGISTRY, 'Exact network route set')
    require(sum(value['bytes'] for value in downloads) <= LIMITS['download_total_bytes'], 'Aggregate download bound')
    targets = [item for value in downloads for item in value['members'].values()]
    require(len(targets) <= LIMITS['members'] and len({item['path'] for item in targets}) == len(targets)
            and sum(item['bytes'] for item in targets) <= LIMITS['rootfs_bytes'], 'Aggregate rootfs bound/collision')
    require({'opt/byond/bin/DreamMaker', 'opt/byond/bin/DreamDaemon', 'lib/ld-linux.so.2'} <= {item['path'] for item in targets},
            'Compiler/daemon/32-bit loader closure missing')
    require(all(plan.get(key) == 0 for key in ('native_compile_count', 'native_daemon_count', 'dispatch_count')), 'No native work in acquisition')


class Budget:
    def __init__(self, ends, clock=None, utc=None):
        self.clock, self.utc, self.ends = clock or time.monotonic, utc or time.time, ends
        self.deadline = self.clock() + LIMITS['outer_seconds']

    def remaining(self): return min(self.deadline-self.clock(), self.ends-self.utc())

    def check(self, cleanup=False):
        require(self.remaining() > (0 if cleanup else LIMITS['cleanup_seconds']), 'Shared acquisition deadline reserve')

    def timeout(self, maximum, cleanup=False):
        self.check(cleanup)
        return min(maximum, self.remaining()-(0 if cleanup else LIMITS['cleanup_seconds']))

    def cleanup_timeout(self, maximum, reserve):
        require(self.remaining() > reserve, 'Shared cleanup/persistence reserve')
        return min(maximum, self.remaining()-reserve)


def download(value, transport, storage, budget, owner):
    """Adapter must prohibit implicit redirects and accept only frozen routes.

    Response protocol: status/url/headers/read(n, timeout)/close(). Real network
    policy and DNS/registry enforcement need independent acceptance; this code
    validates stream-level contracts and never accepts a same-hash redirect.
    """
    budget.check()
    response = transport.open(value['url'], timeout=budget.timeout(10), redirects=False)
    response_error = None
    try:
        require(response.status == 200 and response.url == value['url'], 'HTTP status/redirect drift')
        require(response.headers.get('Content-Encoding', 'identity') == 'identity', 'Encoded response not admitted')
        length = response.headers.get('Content-Length')
        require(length is not None and str(length).isdigit() and int(length) == value['bytes'], 'HTTP length identity')
        output = storage.create(owner, 'source', 'downloads/' + value['sha256'])
        total, sha = 0, hashlib.sha256()
        output_error = None
        try:
            while True:
                budget.check()
                block = response.read(65536, timeout=budget.timeout(10))
                require(type(block) is bytes, 'Binary transport required')
                if not block: break
                total += len(block)
                require(total <= value['bytes'], 'Download overflow')
                storage.write(output, block); sha.update(block)
            require(total == value['bytes'] and sha.hexdigest() == value['sha256'], 'Download hash/length mismatch')
        except BaseException as failure:
            output_error = failure
            raise
        finally:
            close_preserving(lambda: storage.close(output), output_error)
        budget.check()
        return storage.read_verified(owner, 'source', 'downloads/' + value['sha256'], value['sha256'], value['bytes'])
    except BaseException as failure:
        response_error = failure
        raise
    finally:
        close_preserving(response.close, response_error)


def deb_data(data):
    """Parse ar members without invoking dpkg/apt or package maintainer scripts."""
    require(data.startswith(b'!<arch>\n'), 'Invalid Debian ar header')
    cursor, result, seen = 8, None, set()
    while cursor < len(data):
        header = data[cursor:cursor+60]
        require(len(header) == 60 and header[-2:] == b'`\n', 'Invalid ar member header')
        name = header[:16].decode('ascii').strip().rstrip('/')
        require(name not in seen and name in ('debian-binary', 'control.tar.gz', 'control.tar.xz', 'data.tar.gz', 'data.tar.xz'), 'Unexpected/duplicate Debian member')
        seen.add(name)
        size = int(header[48:58].decode('ascii').strip())
        require(0 <= size <= len(data)-cursor-60, 'Invalid ar member size')
        value = data[cursor+60:cursor+60+size]
        if name == 'debian-binary': require(value == b'2.0\n', 'Debian format version')
        if name.startswith('data.'):
            require(result is None, 'Duplicate Debian data')
            result = value
        cursor += 60 + size + size % 2
    require(cursor == len(data) and 'debian-binary' in seen and result is not None, 'Truncated Debian archive')
    return result


def raw_tar(payload, budget):
    """Bound ALL decompressed bytes before interpreting any tar metadata.

    No tarfile pre-yield PAX/GNU allocation. Decoder output chunks and the xz
    dictionary are bounded; concatenated streams/trailing data are rejected.
    """
    gzip = payload.startswith(b'\x1f\x8b')
    require(gzip or payload.startswith(b'\xfd7zXZ\0'), 'Unsupported Debian compression')
    decoder = zlib.decompressobj(31) if gzip else lzma.LZMADecompressor(memlimit=64*1024**2)
    cursor, total, pending = 0, 0, b''
    while True:
        budget.check()
        if gzip and decoder.unconsumed_tail:
            pending = decoder.unconsumed_tail
        elif not gzip and not decoder.needs_input:
            pending = b''
        else:
            pending = payload[cursor:cursor+65536]; cursor += len(pending)
            require(pending, 'Truncated compressed Debian data')
        block = decoder.decompress(pending, max_length=65536)
        total += len(block)
        require(total <= LIMITS['rootfs_bytes'], 'Raw archive expansion bound')
        if block: yield block
        if decoder.eof:
            require(not decoder.unused_data and cursor == len(payload), 'Trailing/concatenated compressed stream')
            break


def tar_members(payload, budget, consume):
    chunks = iter(raw_tar(payload, budget))
    buffered = bytearray()
    def read(count):
        require(0 <= count <= 65536, 'Bounded tar read')
        while len(buffered) < count:
            budget.check()
            block = next(chunks, None)
            require(block is not None, 'Truncated raw tar')
            buffered.extend(block)
        result = bytes(buffered[:count]); del buffered[:count]
        return result
    def octal(field):
        value = field.strip(b'\0 ')
        require(value and re.fullmatch(b'[0-7]+', value), 'Unsupported tar numeric encoding')
        return int(value, 8)
    count = 0
    while True:
        header = read(512)
        if header == bytes(512):
            require(read(512) == bytes(512), 'Invalid tar end markers')
            require(not any(buffered), 'Trailing tar data')
            for block in chunks:
                require(not any(block), 'Trailing tar data')
            return
        count += 1; require(count <= LIMITS['members'], 'Raw tar member count bound')
        require(sum(header[:148]) + 8*32 + sum(header[156:]) == octal(header[148:156]), 'Tar header checksum')
        kind = header[156:157]
        require(kind in (b'0', b'\0', b'5', b'1', b'2'), 'Unsupported PAX/GNU/device tar extension')
        name = header[:100].split(b'\0', 1)[0].decode('utf-8')
        if header[257:263] == b'ustar\0':
            prefix = header[345:500].split(b'\0', 1)[0].decode('utf-8')
            if prefix: name = prefix + '/' + name
        size = octal(header[124:136]); remaining = size
        def member_read(maximum):
            nonlocal remaining
            value = read(min(maximum, remaining))
            remaining -= len(value)
            return value
        consume(name.rstrip('/'), size, kind in (b'0', b'\0'), member_read)
        while remaining: member_read(min(65536, remaining))
        if size % 512: read(512-size%512)


def zip_directory_bound(data):
    # Validate the bounded central-directory shape before ZipFile allocates its
    # Python metadata objects. ZIP64/multidisk/self-extracting inputs are excluded.
    position = data.rfind(b'PK\x05\x06', max(0, len(data)-65557))
    require(position >= 0 and len(data)-position >= 22, 'Missing ZIP end record')
    _, disk, start_disk, disk_count, count, size, offset, comment = struct.unpack('<4s4H2LH', data[position:position+22])
    require(disk == start_disk == 0 and 0 < count == disk_count <= LIMITS['members'] and size <= 4*1024**2
            and offset + size == position and position+22+comment == len(data) and data.startswith(b'PK\x03\x04'),
            'ZIP metadata/count/extent bound')


def extract(value, data, storage, budget, owner):
    expected, found, seen, expanded = value['members'], set(), set(), 0
    def member(name, size, regular, reader):
        nonlocal expanded
        budget.check()
        # .deb tar paths commonly begin ./; normalize that single archive prefix.
        name = name[2:] if name.startswith('./') else name
        if not name or name == '.': return
        relative(name)
        require(name not in seen, 'Duplicate archive member'); seen.add(name)
        expanded += size
        require(0 <= size <= LIMITS['rootfs_bytes'] and expanded <= LIMITS['rootfs_bytes'], 'Archive aggregate expansion bound')
        if name not in expected: return
        require(regular and size == expected[name]['bytes'], 'Selected links/devices/size mismatch')
        found.add(name)
        output = storage.create(owner, 'source', 'rootfs/' + expected[name]['path'])
        total, sha = 0, hashlib.sha256()
        output_error = None
        try:
            while True:
                budget.check()
                block = reader(min(65536, size-total+1))
                if not block: break
                total += len(block)
                require(total <= size, 'Extracted member overflow')
                storage.write(output, block); sha.update(block)
            require(total == size and sha.hexdigest() == expected[name]['sha256'], 'Rootfs member hash mismatch')
        except BaseException as failure:
            output_error = failure
            raise
        finally:
            close_preserving(lambda: storage.close(output), output_error)
    if value['kind'] == 'zip':
        zip_directory_bound(data)
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            require(len(archive.infolist()) <= LIMITS['members'], 'ZIP count bound')
            zip_seen = set()
            for info in archive.infolist():
                name = info.filename.rstrip('/')
                require(name not in zip_seen, 'Duplicate ZIP member'); zip_seen.add(name)
                mode = (info.external_attr >> 16) & 0o170000
                require(not info.flag_bits & 1 and mode not in (0o120000, 0o060000, 0o020000), 'Encrypted/link/device ZIP')
                with archive.open(info) as source:
                    member(name, info.file_size, not info.is_dir(), source.read)
    else:
        payload = deb_data(data)
        tar_members(payload, budget, member)
    require(found == expected.keys(), 'Missing selected archive members')


def acquire(plan, grant, owner, transport, storage, image, clock=None, utc=None):
    """Adapters are mandatory; no fallback to host filesystem/daemon/network.

    storage: independently accepted hard-volume proofs, exclusive writes,
    bounded reads/saves, ownership assertions and owned cleanup.
    image: independently accepted private-daemon lifecycle with hard data-root,
    anonymous exact registry egress, finite operation budget and no native RUN.
    """
    validate(plan)  # unresolved identities fail BEFORE any adapter action
    serialized = json.dumps(plan, sort_keys=True, separators=(',', ':')).encode()
    plan_sha = digest(serialized)
    now = (utc or time.time)()
    require(grant.get('scope') == SCOPE and grant.get('head') == plan['head'] and grant.get('executor') == plan['executor']
            and grant.get('plan_sha256') == plan_sha and grant.get('granted') is True
            and type(grant.get('starts')) in (int, float) and type(grant.get('ends')) in (int, float)
            and math.isfinite(grant['starts']) and math.isfinite(grant['ends'])
            and grant['starts'] <= now < grant['ends'], 'No exact acquisition admission')
    require(re.fullmatch('[0-9a-f]{32}', owner or ''), 'Fresh owner nonce required')
    require(grant.get('storage_accepted') is True and grant.get('network_accepted') is True and grant.get('private_daemon_accepted') is True,
            'Missing external acquisition controls')
    budget = Budget(grant['ends'], clock, utc)
    frozen = digest(serialized)
    result = {'scope': SCOPE, 'plan_sha256': plan_sha, 'owner': owner, 'complete': False, 'downloads': [], 'native_count': 0}
    claimed, daemon_owned = False, False
    def check():
        budget.check()
        require(digest(json.dumps(plan, sort_keys=True, separators=(',', ':')).encode()) == frozen, 'Acquisition plan drift')
        storage.assert_owned(owner)
    try:
        budget.check()
        try:
            storage.claim(owner, plan_sha); claimed = True
        except FileExistsError as failure:
            result['claim_error'] = str(failure)
            raise  # known failed exclusive create: never adopt an older claim
        except BaseException as failure:
            result['claim_error'] = str(failure)
            try:
                claimed = storage.reconcile_owned(owner, plan_sha) is True
            except BaseException as reconcile:
                result['claim_reconciliation_error'] = str(reconcile)
            raise
        proof = storage.proofs(owner)
        expected = {key: LIMITS[key+'_bytes'] for key in ('source', 'daemon', 'evidence', 'export')}
        require(proof.get('hard_capacities') == expected and proof.get('separate_filesystems') is True
                and proof.get('no_links_or_escapes') is True and proof.get('enospc_controls') is True, 'Hard shared storage controls missing')
        recipe = storage.recipe_bytes(owner)
        directives = [line.split(None, 1)[0].upper() for line in recipe.decode('utf-8').splitlines() if line.strip() and not line.lstrip().startswith('#')]
        require(digest(recipe) == plan['recipe_sha256'] and directives == ['FROM', 'COPY', 'ENV', 'USER', 'WORKDIR', 'ENTRYPOINT']
                and ('FROM ' + BASE) in recipe.decode('utf-8'), 'Image recipe drift/native instructions prohibited')
        require(image.preflight(owner, BASE, BASE_ID, REGISTRY, budget.timeout(30)) == {'accepted_private_daemon': True, 'native_commands': 0},
                'Unaccepted image backend')
        for value in [plan['archive'], *plan['dependencies']]:
            check()
            data = download(value, transport, storage, budget, owner)
            extract(value, data, storage, budget, owner)
            result['downloads'].append({'url': value['url'], 'sha256': value['sha256'], 'bytes': value['bytes']})
            storage.save(owner, 'evidence', 'acquisition.json', result, LIMITS['receipt_bytes'])
        check()
        inventory = {item['path']: {'sha256': item['sha256'], 'bytes': item['bytes']}
                     for value in [plan['archive'], *plan['dependencies']] for item in value['members'].values()}
        require(storage.inventory(owner, 'source', 'rootfs') == inventory, 'Original rootfs inventory drift')
        # backend must retain identity BEFORE returning/throwing from create.
        # Its cleanup inspects only that exact fresh owner; no shared daemon.
        daemon_owned = True
        built = image.build_owned(owner, plan, storage, budget.timeout(240))
        require(re.fullmatch('sha256:[0-9a-f]{64}', built.get('image_id') or '') and built.get('base_id') == BASE_ID
                and built.get('native_commands') == 0 and built.get('rootfs_verified') is True, 'Image provenance/readback mismatch')
        check()
        exported = image.export_owned(owner, storage, budget.timeout(60))
        require(exported.get('bytes', 0) > 0 and exported['bytes'] <= LIMITS['export_bytes']
                and re.fullmatch('[0-9a-f]{64}', exported.get('sha256') or ''), 'Bounded image export evidence missing')
        result.update(image=built, export=exported, artifact_status='CANDIDATE_REQUIRES_INDEPENDENT_REVIEW_NOT_NATIVE_ADMISSION')
        check()
        require(storage.inventory(owner, 'source', 'rootfs') == inventory and digest(storage.recipe_bytes(owner)) == plan['recipe_sha256'],
                'Original rootfs/recipe changed during image preparation')
    except BaseException as failure:
        result['error'] = str(failure)
        result['error_notes'] = getattr(failure, '__notes__', [])[:8]
    finally:
        cleanup = {}
        if daemon_owned:
            try: cleanup['daemon'] = image.cleanup_owned(owner, budget.cleanup_timeout(15, reserve=15))
            except BaseException as failure: cleanup['daemon'] = {'all_exited': False, 'error': str(failure)}
        if claimed:
            try:
                require(not daemon_owned or cleanup.get('daemon', {}).get('all_exited') is True,
                        'Daemon lifetime unconfirmed; retain owned hard-volume state for reconciliation')
                cleanup['storage'] = storage.cleanup_owned(owner, preserve=('evidence', 'export'), timeout=budget.cleanup_timeout(10, reserve=5))
            except BaseException as failure: cleanup['storage'] = {'owned_scratch_retired': False, 'error': str(failure)}
        result['cleanup'] = cleanup
        result['complete'] = not result.get('error') and cleanup.get('daemon', {}).get('all_exited') is True and cleanup.get('storage', {}).get('owned_scratch_retired') is True
        if claimed:
            try:
                budget.check(cleanup=True)
                storage.save(owner, 'evidence', 'acquisition.json', result, LIMITS['receipt_bytes'], timeout=budget.cleanup_timeout(5, reserve=0))
                budget.check(cleanup=True)  # completed persistence is part of pass acceptance
            except BaseException as failure:
                result['complete'] = False
                result.setdefault('error', str(failure))
                result['persistence_error'] = str(failure)
                # Bounded failure closeout only; never restart acquisition/work.
                # If this cannot persist, the caller retains an incomplete result.
                try: storage.save(owner, 'evidence', 'acquisition.json', result, LIMITS['receipt_bytes'], timeout=1)
                except BaseException as final_failure: result['failure_receipt_error'] = str(final_failure)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    print(Path(__file__).with_name('plan.json').read_text())
