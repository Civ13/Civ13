"""Exact-Git source binding and negative controls; no network or native run."""
import copy
import unittest
from unittest.mock import patch
import source_binding


class BindingControls(unittest.TestCase):
    def setUp(self):
        self.samples = {path: b'fake-' + path.encode() for path in source_binding.BLOBS}
        self.original = source_binding.blob
        source_binding.blob = lambda data: source_binding.BLOBS[data[5:].decode()]

    def tearDown(self):
        source_binding.blob = self.original

    def execute(self, cmd, timeout, env=None):
        self.assertEqual(timeout, 10)
        if cmd[-2] == 'rev-parse':
            return (source_binding.TREE + '\n').encode()
        return self.samples[cmd[-1].split(':', 1)[1]]

    def test_all_exact_paths_are_read(self):
        self.assertEqual(source_binding.read_inputs(['git'], source_binding.BASE, self.execute), self.samples)

    def test_other_head_and_tree_rejected(self):
        with self.assertRaises(ValueError):
            source_binding.read_inputs(['git'], '0' * 40, self.execute)
        def bad_tree(cmd, timeout, env=None):
            return b'0' * 40 if cmd[-2] == 'rev-parse' else self.execute(cmd, timeout)
        with self.assertRaises(ValueError):
            source_binding.read_inputs(['git'], source_binding.BASE, bad_tree)

    def test_changed_blob_rejected(self):
        path = next(iter(self.samples))
        self.samples[path] = b'fake-' + next(iter(list(self.samples)[1:])).encode()
        with self.assertRaises(ValueError):
            source_binding.read_inputs(['git'], source_binding.BASE, self.execute)

    def test_experiment_path_set_and_ancestor_fail_closed(self):
        head = 'b' * 40
        class Result:
            returncode = 0
        def output(cmd, timeout, env=None):
            if 'diff' in cmd:
                return b'\0'.join(x.encode() for x in sorted(source_binding.ALLOWED_DELTA)) + b'\0'
            return b'c' * 40 + b'\n'
        with patch.object(source_binding.subprocess, 'run', return_value=Result()), \
             patch.object(source_binding.subprocess, 'check_output', side_effect=output):
            self.assertEqual(source_binding.validate_head(['git'], head), 'c' * 40)
            with self.assertRaises(ValueError):
                source_binding.validate_head(['git'], 'invalid')
        def extra(cmd, timeout, env=None):
            if 'diff' in cmd:
                return output(cmd, timeout) + b'unreviewed.dm\0'
            return output(cmd, timeout)
        with patch.object(source_binding.subprocess, 'run', return_value=Result()), \
             patch.object(source_binding.subprocess, 'check_output', side_effect=extra):
            with self.assertRaises(ValueError):
                source_binding.validate_head(['git'], head)


if __name__ == '__main__':
    unittest.main()
