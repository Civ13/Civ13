"""Offline reference contract only. SOURCE PREPARATION, UNRUN.

No BYOND, native extension, daemon, network or production save access. Python
immutable bytes model the private snapshot boundary, not an OS ownership lock.
Passing this oracle cannot establish the proposed native ABI or savefile pinning.
"""
from hashlib import sha256
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest


MAX_BYTES = 1048576
CHUNK = 4096


def stream_digest(chunks, limit=MAX_BYTES):
    digest = sha256()
    count = 0
    for chunk in chunks:
        if not isinstance(chunk, bytes) or len(chunk) > CHUNK:
            raise ValueError('invalid bounded binary chunk')
        count += len(chunk)
        if count > limit:
            raise ValueError('binary capacity exceeded')
        digest.update(chunk)
    return digest.hexdigest(), count


def chunks(data):
    for offset in range(0, len(data), CHUNK):
        yield data[offset:offset + CHUNK]


def canonical(value, active=None):
    """Proposed reference grammar. Native encoding and schema are separate gates."""
    active = set() if active is None else active
    if value is None:
        return b'N'
    if type(value) is bool:
        return b'T' if value else b'F'
    if type(value) is int:
        if not 0 <= value <= 16777214:
            raise ValueError('integer outside reviewed exact range')
        return b'I' + str(value).encode('ascii') + b';'
    if type(value) is str:
        data = value.encode('utf-8', errors='strict')
        return b'S' + str(len(data)).encode('ascii') + b':' + data
    if type(value) not in (list, dict) or id(value) in active:
        raise ValueError('unsupported or cyclic value')
    active.add(id(value))
    try:
        if type(value) is list:
            return b'A' + str(len(value)).encode('ascii') + b':' + b''.join(
                canonical(item, active) for item in value)
        if any(type(key) is not str for key in value):
            raise ValueError('record key must be text')
        keys = sorted(value, key=lambda key: key.encode('utf-8', errors='strict'))
        return b'R' + str(len(keys)).encode('ascii') + b':' + b''.join(
            canonical(key, active) + canonical(value[key], active) for key in keys)
    finally:
        active.remove(id(value))


class SnapshotOracle:
    """Test-owned copy model. No production host ownership assertion."""
    def __init__(self):
        self.readers = {}
        self.acquired = []
        self.released = []
        self.clear_calls = 0
        self.consumed = []

    def acquire(self, paths, declared, inject):
        try:
            for name, path in paths.items():
                inject('acquire', name)
                data = path.read_bytes()
                digest, size = stream_digest(chunks(data))
                if (digest, size) != declared[name]:
                    raise ValueError('candidate differs before ClearMap')
                self.readers[name] = data
                self.acquired.append(name)
                inject('hash', name)
            for name, data in self.readers.items():
                inject('validate', name)
                if stream_digest(chunks(data)) != declared[name]:
                    raise ValueError('pinned bytes changed')
            self.clear_calls += 1
            for name, data in self.readers.items():
                inject('decode', name)
                self.consumed.append((name, data))
            return self.consumed
        finally:
            self.released.extend(self.acquired)
            self.readers.clear()


class GenerationContract(unittest.TestCase):
    def test_path_mutations_restore_a_or_refuse_before_clear(self):
        a = b'valid-A\x00' + bytes(range(256))
        b = b'valid-B\x00' + bytes(reversed(range(256)))
        for phase in ('acquire', 'hash', 'validate', 'decode'):
            for mutation in ('replace', 'truncate', 'delete', 'rename'):
                with self.subTest(phase=phase, mutation=mutation), TemporaryDirectory() as folder:
                    path = Path(folder) / 'level.sav'
                    path.write_bytes(a)
                    oracle = SnapshotOracle()

                    def inject(at, name):
                        if at != phase:
                            return
                        if mutation == 'replace':
                            path.write_bytes(b)
                        elif mutation == 'truncate':
                            path.write_bytes(a[:3])
                        elif mutation == 'delete':
                            path.unlink()
                        else:
                            path.rename(path.with_suffix('.moved'))

                    try:
                        result = oracle.acquire({'level': path}, {'level': stream_digest(chunks(a))}, inject)
                    except (ValueError, OSError):
                        self.assertEqual(oracle.clear_calls, 0)
                    else:
                        self.assertEqual(result, [('level', a)])
                    self.assertEqual(oracle.released, oracle.acquired)
                    self.assertFalse(oracle.readers)

    def test_hash_then_reopen_negative_control_detects_wrong_bytes(self):
        with TemporaryDirectory() as folder:
            path = Path(folder) / 'level.sav'
            path.write_bytes(b'valid A')
            proof = stream_digest(chunks(path.read_bytes()))
            path.write_bytes(b'valid B')
            self.assertNotEqual(stream_digest(chunks(path.read_bytes())), proof,
                                'hash-then-reopen cannot satisfy pinned reader contract')

    def test_partial_acquisition_unwinds_exact_members(self):
        with TemporaryDirectory() as folder:
            first = Path(folder) / 'meta'
            first.write_bytes(b'metadata')
            missing = Path(folder) / 'missing.sav'
            oracle = SnapshotOracle()
            with self.assertRaises(OSError):
                oracle.acquire({'meta': first, 'level': missing},
                               {'meta': stream_digest(chunks(b'metadata'))}, lambda *_: None)
            self.assertEqual(oracle.acquired, ['meta'])
            self.assertEqual(oracle.released, ['meta'])
            self.assertEqual(oracle.clear_calls, 0)

    def test_metadata_level_and_manifest_share_acquisition_identity(self):
        payloads = {'metadata': b'mapA', 'v2-level': b'closed-v2-A\x00', 'manifest': b'manifestA'}
        with TemporaryDirectory() as folder:
            paths = {}
            for name, data in payloads.items():
                paths[name] = Path(folder) / name
                paths[name].write_bytes(data)
            oracle = SnapshotOracle()
            result = oracle.acquire(paths, {name: stream_digest(chunks(data)) for name, data in payloads.items()}, lambda *_: None)
            self.assertEqual(dict(result), payloads)
            self.assertEqual(oracle.acquired, list(payloads))
            self.assertEqual(oracle.released, list(payloads))
            self.assertEqual(oracle.clear_calls, 1)

    def test_binary_chunk_vectors_and_failure_not_empty(self):
        for size in (0, 1, 63, 64, 65, 65537, MAX_BYTES):
            data = (bytes(range(256)) * ((size + 255) // 256))[:size]
            self.assertEqual(stream_digest(chunks(data)), (sha256(data).hexdigest(), size))
        data = bytes(range(256)) * 257
        for stride in (1, 63, 64, 65, CHUNK):
            self.assertEqual(stream_digest(data[i:i + stride] for i in range(0, len(data), stride)),
                             (sha256(data).hexdigest(), len(data)))
        with self.assertRaises(ValueError):
            stream_digest([bytes(CHUNK + 1)])
        with self.assertRaises(ValueError):
            stream_digest(chunks(bytes(MAX_BYTES + 1)))
        with self.assertRaises(ValueError):
            stream_digest([None])
        def broken_reader():
            yield b'partial\x00'
            raise OSError('read failed')
        with self.assertRaises(OSError):
            stream_digest(broken_reader())

    def test_canonical_types_unicode_order_domains_and_cycles(self):
        self.assertEqual(canonical('é\x00'), b'S3:\xc3\xa9\x00')
        self.assertNotEqual(canonical('é'), canonical('e\u0301'))
        self.assertEqual(canonical({'b': 1, 'a': False}), canonical({'a': False, 'b': 1}))
        self.assertEqual(len({canonical(v) for v in (None, False, True, 0, 1, '1', [], {})}), 8)
        for invalid in (-1, 16777215, 1.0, float('nan'), '\ud800', {1: 'value'}):
            with self.assertRaises((ValueError, UnicodeError)):
                canonical(invalid)
        cyclic = []
        cyclic.append(cyclic)
        with self.assertRaises(ValueError):
            canonical(cyclic)
        intent = sha256(canonical(['civ13.world-handoff.intent.v1', {'owner': 'alice'}])).hexdigest()
        batch = sha256(canonical(['civ13.world-handoff.batch.v1', {'intent': intent}])).hexdigest()
        self.assertNotEqual(intent, batch)
        self.assertNotEqual(batch, sha256(canonical(['civ13.world-handoff.candidate.v1', {'intent': intent}])).hexdigest())


if __name__ == '__main__':
    unittest.main()
