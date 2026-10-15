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


class Ownership:
    """Explicit model token, not an OS lock."""
    def __init__(self):
        self.epoch = 1
        self.active = True

    def require(self, epoch):
        if not self.active or epoch != self.epoch:
            raise ValueError('ownership epoch lost')


class SnapshotOracle:
    """Frozen roster and counted copy model; no native format or OS proof."""
    def __init__(self, declared, levels=1, budget=MAX_BYTES):
        expected = ('manifest', 'metadata') + tuple(f'level-{i}' for i in range(1, levels + 1))
        if not 1 <= levels <= 14 or set(declared) != set(expected):
            raise ValueError('invalid mandatory frozen roster')
        captured = []
        for name in expected:
            record = declared[name]
            if type(record) not in (tuple, list) or len(record) != 2:
                raise ValueError('invalid declared member')
            digest, size = record
            if (type(size) is not int or size < 0 or size > budget or
                    type(digest) is not str or len(digest) != 64):
                raise ValueError('invalid declared member')
            captured.append((name, (digest, size)))
        self.roster = tuple(captured)
        if sum(size for _, (_, size) in self.roster) > budget:
            raise ValueError('aggregate capacity exceeded')
        self.budget = budget
        self.owner = Ownership()
        self.epoch = self.owner.epoch
        self.readers = {}
        self.acquired = []
        self.released = []
        self.clear_calls = 0
        self.consumed = []
        self.byte_count = 0

    def require(self, token=None):
        self.owner.require(self.epoch)
        if token is not None and (token[0] is not self or token[1] != self.epoch or token[2] not in self.readers):
            raise ValueError('wrong operation or member token')

    def acquire(self, paths, inject, reopen_control=False):
        try:
            self.require()
            if set(paths) != {name for name, _ in self.roster}:
                raise ValueError('paths differ from frozen roster')
            for name, expected in self.roster:
                inject('acquire', name)
                self.require()
                pieces = []
                member_count = 0
                with paths[name].open('rb') as source:
                    while True:
                        piece = source.read(CHUNK)
                        if not piece:
                            break
                        member_count += len(piece)
                        self.byte_count += len(piece)
                        if member_count > expected[1] or self.byte_count > self.budget:
                            raise ValueError('read byte capacity exceeded')
                        pieces.append(piece)
                data = b''.join(pieces)
                digest, size = stream_digest(chunks(data))
                if (digest, size) != expected:
                    raise ValueError('candidate differs before ClearMap')
                token = (self, self.epoch, name)
                self.readers[name] = (token, data)
                self.acquired.append(name)
                inject('hash', name)
                self.require(token)
            for name, expected in self.roster:
                token, data = self.readers[name]
                inject('validate', name)
                self.require(token)
                if stream_digest(chunks(data)) != expected:
                    raise ValueError('pinned bytes changed')
            self.require()
            self.clear_calls += 1
            for name, (token, data) in self.readers.items():
                inject('decode', name)
                self.require(token)
                if reopen_control:
                    data = paths[name].read_bytes()  # Intentional violating decoder only.
                self.consumed.append((name, data))
            return self.consumed
        finally:
            self.released.extend(self.acquired)
            self.readers.clear()
            self.owner.active = False


def fixture(folder, level=b'opaque-A\x00'):
    payloads = {'manifest': b'opaque-manifest', 'metadata': b'opaque-map', 'level-1': level}
    paths = {name: Path(folder) / name for name in payloads}
    for name, data in payloads.items():
        paths[name].write_bytes(data)
    declared = {name: stream_digest(chunks(data)) for name, data in payloads.items()}
    return payloads, paths, declared


def require_consumed_a(result, payloads):
    if dict(result) != payloads:
        raise AssertionError('PINNED_A_CONSUMPTION: decoder consumed changed bytes')


class GenerationContract(unittest.TestCase):
    def test_path_mutations_restore_a_or_refuse_before_clear(self):
        a = b'valid-A\x00' + bytes(range(256))
        b = b'valid-B\x00' + bytes(reversed(range(256)))
        for phase in ('acquire', 'hash', 'validate', 'decode'):
            for mutation in ('replace', 'truncate', 'delete', 'rename'):
                with self.subTest(phase=phase, mutation=mutation), TemporaryDirectory() as folder:
                    payloads, paths, declared = fixture(folder, a)
                    path = paths['level-1']
                    oracle = SnapshotOracle(declared)

                    def inject(at, name):
                        if at != phase or name != 'level-1':
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
                        result = oracle.acquire(paths, inject)
                    except (ValueError, OSError):
                        self.assertEqual(oracle.clear_calls, 0)
                    else:
                        require_consumed_a(result, payloads)
                    self.assertEqual(oracle.released, oracle.acquired)
                    self.assertFalse(oracle.readers)

    def test_hash_then_reopen_negative_control_detects_wrong_bytes(self):
        for violating in (False, True):
            with TemporaryDirectory() as folder:
                payloads, paths, declared = fixture(folder)
                def inject(at, name):
                    if at == 'decode' and name == 'level-1':
                        paths[name].write_bytes(b'opaque-B\x00')
                result = SnapshotOracle(declared).acquire(paths, inject, reopen_control=violating)
                if violating:
                    with self.assertRaisesRegex(AssertionError, '^PINNED_A_CONSUMPTION:'):
                        require_consumed_a(result, payloads)
                else:
                    require_consumed_a(result, payloads)

    def test_partial_acquisition_unwinds_exact_members(self):
        with TemporaryDirectory() as folder:
            _, paths, declared = fixture(folder)
            paths['level-1'].unlink()
            oracle = SnapshotOracle(declared)
            with self.assertRaises(OSError):
                oracle.acquire(paths, lambda *_: None)
            self.assertEqual(oracle.acquired, ['manifest', 'metadata'])
            self.assertEqual(oracle.released, ['manifest', 'metadata'])
            self.assertEqual(oracle.clear_calls, 0)

    def test_metadata_level_and_manifest_share_acquisition_identity(self):
        with TemporaryDirectory() as folder:
            payloads, paths, declared = fixture(folder)
            oracle = SnapshotOracle(declared)
            result = oracle.acquire(paths, lambda *_: None)
            require_consumed_a(result, payloads)
            self.assertEqual(oracle.acquired, list(payloads))
            self.assertEqual(oracle.released, list(payloads))
            self.assertEqual(oracle.clear_calls, 1)
            with self.assertRaisesRegex(ValueError, 'ownership epoch lost'):
                oracle.require((oracle, oracle.epoch, 'manifest'))

    def test_roster_and_aggregate_budget_reject_before_clear(self):
        with TemporaryDirectory() as folder:
            _, paths, declared = fixture(folder)
            for names in ({}, {key: value for key, value in paths.items() if key != 'metadata'},
                          dict(paths, extra=paths['manifest'])):
                oracle = SnapshotOracle(declared)
                with self.assertRaisesRegex(ValueError, 'frozen roster'):
                    oracle.acquire(names, lambda *_: None)
                self.assertEqual(oracle.clear_calls, 0)
            for records in ({}, dict(declared, extra=declared['manifest']),
                            {key: value for key, value in declared.items() if key != 'level-1'}):
                with self.assertRaisesRegex(ValueError, 'mandatory frozen roster'):
                    SnapshotOracle(records)
            with self.assertRaisesRegex(ValueError, 'aggregate capacity'):
                SnapshotOracle(declared, budget=max(size for _, size in declared.values()))
            with self.assertRaises(ValueError):
                SnapshotOracle(declared, levels=15)

    def test_wrong_operation_token_and_ownership_loss(self):
        with TemporaryDirectory() as folder:
            _, paths, declared = fixture(folder)
            for phase in ('acquire', 'hash', 'validate', 'decode'):
                oracle = SnapshotOracle(declared)
                def inject(at, name):
                    if at == phase and name == 'manifest':
                        oracle.owner.epoch += 1
                with self.assertRaisesRegex(ValueError, 'ownership epoch lost'):
                    oracle.acquire(paths, inject)
                self.assertEqual(oracle.clear_calls, int(phase == 'decode'))
                self.assertEqual(oracle.released, oracle.acquired)
            oracle = SnapshotOracle(declared)
            other = SnapshotOracle(declared)
            def wrong_token(at, name):
                if at == 'hash':
                    oracle.require((other, other.epoch, name))
            with self.assertRaisesRegex(ValueError, 'wrong operation'):
                oracle.acquire(paths, wrong_token)
            self.assertEqual(oracle.clear_calls, 0)

    def test_caller_mutation_cannot_change_captured_proof_or_budget(self):
        with TemporaryDirectory() as folder:
            _, paths, declared = fixture(folder)
            caller = {name: list(record) for name, record in declared.items()}
            oracle = SnapshotOracle(caller)
            captured = oracle.roster
            budget = oracle.budget
            replacement = b'opaque-B-with-more-bytes\x00'
            replacement_proof = stream_digest(chunks(replacement))
            caller['level-1'][:] = replacement_proof
            caller['metadata'][1] = MAX_BYTES
            caller['extra'] = ['0' * 64, 0]
            paths['level-1'].write_bytes(replacement)
            self.assertEqual(oracle.roster, captured)
            self.assertEqual(dict(oracle.roster), declared)
            self.assertEqual(oracle.budget, budget)
            with self.assertRaisesRegex(ValueError, 'read byte capacity exceeded|candidate differs before ClearMap'):
                oracle.acquire(paths, lambda *_: None)
            self.assertEqual(oracle.clear_calls, 0)
            self.assertEqual(oracle.released, oracle.acquired)

    def test_file_growth_after_preflight_rejects_read_capacity(self):
        with TemporaryDirectory() as folder:
            _, paths, declared = fixture(folder)
            oracle = SnapshotOracle(declared)
            def inject(at, name):
                if at == 'acquire' and name == 'level-1':
                    paths[name].write_bytes(bytes(CHUNK + 1))
            with self.assertRaisesRegex(ValueError, 'read byte capacity exceeded'):
                oracle.acquire(paths, inject)
            self.assertEqual(oracle.clear_calls, 0)

    def test_fixed_sha_known_answers(self):
        # Fixed SHA-256 known answers, independent of the parity oracle call.
        self.assertEqual(stream_digest([]),
                         ('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 0))
        self.assertEqual(stream_digest([b'a', b'b', b'c']),
                         ('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', 3))

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
        self.assertEqual(canonical({'b': 1, 'a': False}), b'R2:S1:aFS1:bI1;')
        self.assertEqual(canonical(16777214), b'I16777214;')
        self.assertEqual(canonical(['civ13.world-handoff.intent.v1', {'owner': 'alice'}]),
                         b'A2:S29:civ13.world-handoff.intent.v1R1:S5:ownerS5:alice')
        self.assertEqual(canonical(['civ13.world-handoff.batch.v1', None]),
                         b'A2:S28:civ13.world-handoff.batch.v1N')
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
