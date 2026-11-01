"""Sidecar path and refusal contracts; source/model tests, not BYOND I/O."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def lookup(sidecar, ref):
    if type(ref) is not int or ref < 1:
        raise ValueError('identity')
    try:
        value = sidecar[str((ref - 1) // 512)][str(ref)]['transforming']
    except (KeyError, TypeError):
        raise ValueError('missing geometry') from None
    if type(value) is not int or value not in (0, 1):
        raise ValueError('invalid geometry')
    return value


class SidecarTests(unittest.TestCase):
    def test_shard_boundaries(self):
        saved = {'0': {'1': {'transforming': 0}, '512': {'transforming': 1}},
                 '1': {'513': {'transforming': 0}}}
        self.assertEqual(lookup(saved, 1), 0)
        self.assertEqual(lookup(saved, 512), 1)
        self.assertEqual(lookup(saved, 513), 0)

    def test_missing_and_corrupt_values_fail_closed(self):
        for data, ref in (({}, 1), ({'0': {}}, 1), ({'0': {'1': {}}}, 1),
                          ({'0': {'1': {'transforming': 2}}}, 1),
                          ({'0': {'1': {'transforming': '0'}}}, 1),
                          ({'0': {'1': {'transforming': None}}}, 1), ({}, 0)):
            with self.subTest(data=data, ref=ref), self.assertRaises(ValueError):
                lookup(data, ref)

    def test_writer_and_reader_use_same_existing_entry_shard_formula(self):
        saving = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        writer = saving.split('/map_storage/proc/BuildVarDirectory(', 1)[1].split('\n/datum/', 1)[0]
        reader = saving.split('/map_storage/proc/human_candidate_turf_transforming(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        self.assertIn('var/geometry_shard = round((ref - 1) / 512)', writer)
        self.assertIn('/human_geometry/[geometry_shard]/[ref]/transforming', writer)
        self.assertIn('var/shard = round((ref - 1) / 512)', reader)
        for part in ('Human turf geometry identity is invalid', 'Human turf geometry metadata is missing',
                     'Human turf geometry shard is missing', 'Human turf geometry entry is missing',
                     'Human turf transform observation is missing', 'Human turf transform observation is invalid'):
            self.assertIn(part, reader)
        self.assertIn('/human_geometry/[shard]/[ref]', reader)


if __name__ == '__main__':
    unittest.main()
