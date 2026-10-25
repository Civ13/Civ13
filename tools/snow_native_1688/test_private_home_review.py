"""Independent offline inventory race checks using synthetic temporary files only."""
import errno
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch

import run


class PrivateHomeRaceReviewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="snow-inventory-review-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.work = self.base / "work"
        self.work.mkdir()
        self.outside = self.base / "synthetic-outside"
        self.outside.mkdir()
        (self.outside / "synthetic-marker").write_bytes(b"synthetic, never read")

    def assert_fds_closed(self, descriptors):
        leaked = []
        for fd in descriptors:
            try:
                os.fstat(fd)
            except OSError as error:
                self.assertEqual(error.errno, errno.EBADF)
            else:
                leaked.append(fd)
                os.close(fd)
        self.assertEqual(leaked, [], "Inventory left an opened descriptor behind")

    def track_opens(self, descriptors):
        real_open = os.open

        def tracked(*args, **kwargs):
            fd = real_open(*args, **kwargs)
            descriptors.add(fd)
            return fd

        return patch.object(os, "open", side_effect=tracked)

    def test_yielded_directory_swapped_to_symlink_is_not_traversed(self):
        directory = self.work / "tmp"
        directory.mkdir()
        descriptors = set()
        with self.track_opens(descriptors):
            walker = run.outside_home_entries(self.work)
            relative, observed = next(walker)
            self.assertEqual(relative, "tmp")
            self.assertTrue(stat.S_ISDIR(observed.st_mode))
            directory.rmdir()
            directory.symlink_to(self.outside, target_is_directory=True)
            with self.assertRaisesRegex(ValueError, "metadata inspection failed"):
                next(walker)
        self.assert_fds_closed(descriptors)

    def test_yielded_directory_swapped_to_another_directory_is_rejected(self):
        directory = self.work / "tmp"
        directory.mkdir()
        walker = run.outside_home_entries(self.work)
        self.assertEqual(next(walker)[0], "tmp")
        directory.rename(self.base / "original-tmp")
        directory.mkdir()
        with self.assertRaisesRegex(ValueError, "identity changed"):
            next(walker)

    def test_nested_directory_swapped_after_yield_is_not_traversed(self):
        nested = self.work / "icons" / "turf"
        nested.mkdir(parents=True)
        walker = run.outside_home_entries(self.work)
        self.assertEqual(next(walker)[0], "icons")
        self.assertEqual(next(walker)[0], "icons/turf")
        nested.rmdir()
        nested.symlink_to(self.outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "metadata inspection failed"):
            next(walker)

    def test_linked_work_and_linked_work_ancestor_are_rejected(self):
        (self.work / "home" / ".byond").mkdir(parents=True)
        alias = self.base / "alias"
        alias.symlink_to(self.work, target_is_directory=True)
        ancestor = self.base / "ancestor"
        ancestor.symlink_to(self.base, target_is_directory=True)
        for work in (alias, ancestor / "work"):
            with self.subTest(work=work):
                descriptors = set()
                with self.track_opens(descriptors):
                    with self.assertRaisesRegex(ValueError, "metadata inspection failed"):
                        run.private_home_inventory(work)
                    with self.assertRaisesRegex(ValueError, "metadata inspection failed"):
                        list(run.outside_home_entries(work))
                self.assert_fds_closed(descriptors)

    def test_parent_traversal_is_rejected_before_opening(self):
        with patch.object(os, "open", side_effect=AssertionError("Must reject before opening")):
            with self.assertRaisesRegex(ValueError, "parent traversal"):
                run.directory_fd(self.work / ".." / "work")

    def test_home_replacement_between_stat_and_open_is_rejected(self):
        home = self.work / "home"
        (home / ".byond").mkdir(parents=True)
        real_open = os.open
        replaced = False
        descriptors = set()

        def swap_then_open(name, flags, *args, **kwargs):
            nonlocal replaced
            if name == "home" and not replaced:
                replaced = True
                home.rename(self.base / "original-home")
                (home / ".byond").mkdir(parents=True)
            fd = real_open(name, flags, *args, **kwargs)
            descriptors.add(fd)
            return fd

        with patch.object(os, "open", side_effect=swap_then_open):
            with self.assertRaisesRegex(ValueError, "identity changed"):
                run.private_home_inventory(self.work)
        self.assertTrue(replaced)
        self.assert_fds_closed(descriptors)

    def test_child_fstat_failure_closes_newly_opened_descriptor(self):
        child = self.work / "home"
        child.mkdir()
        observed = child.lstat()
        parent = os.open(self.work, run.DIRECTORY_FLAGS)
        descriptors = set()
        try:
            with self.track_opens(descriptors), \
                    patch.object(os, "fstat", side_effect=OSError(errno.EIO, "Synthetic metadata failure")):
                with self.assertRaises(OSError):
                    run.child_directory_fd(parent, "home", observed)
            self.assert_fds_closed(descriptors)
        finally:
            os.close(parent)

    def test_explicitly_closing_paused_walker_releases_its_descriptors(self):
        (self.work / "icons" / "turf").mkdir(parents=True)
        descriptors = set()
        with self.track_opens(descriptors):
            walker = run.outside_home_entries(self.work)
            self.assertEqual(next(walker)[0], "icons")
            self.assertEqual(next(walker)[0], "icons/turf")
            walker.close()
        self.assert_fds_closed(descriptors)

    def test_private_rejection_closes_all_opened_directory_descriptors(self):
        private = self.work / "home" / ".byond" / "cache"
        private.mkdir(parents=True)
        (private / "linked").symlink_to(self.outside, target_is_directory=True)
        descriptors = set()
        with self.track_opens(descriptors):
            with self.assertRaisesRegex(ValueError, "link or non-regular"):
                run.private_home_inventory(self.work)
        self.assert_fds_closed(descriptors)

    def test_unexpected_outside_directory_is_rejected_before_it_is_opened(self):
        (self.work / "unexpected").mkdir()
        real_open = os.open

        def no_unexpected_open(name, *args, **kwargs):
            self.assertNotEqual(name, "unexpected", "Caller must reject before traversal")
            return real_open(name, *args, **kwargs)

        descriptors = set()
        with patch.object(os, "open", side_effect=no_unexpected_open):
            with self.track_opens(descriptors):
                for checker in (run.compile_inventory, run.runtime_inventory):
                    with self.subTest(checker=checker.__name__), \
                            self.assertRaisesRegex(ValueError, "Unexpected .* directory"):
                        checker(self.work)
        self.assert_fds_closed(descriptors)

    def test_private_metadata_inspection_only_opens_directories(self):
        private = self.work / "home" / ".byond" / "cache"
        private.mkdir(parents=True)
        (private / "synthetic.cfg").write_bytes(b"must not be opened")
        real_open = os.open

        def directories_only(name, flags, *args, **kwargs):
            self.assertTrue(flags & os.O_DIRECTORY)
            self.assertTrue(flags & os.O_NOFOLLOW)
            self.assertNotEqual(name, "synthetic.cfg")
            return real_open(name, flags, *args, **kwargs)

        with patch.object(os, "open", side_effect=directories_only), \
                patch.object(os, "read", side_effect=AssertionError("No private file reads")):
            result = run.private_home_inventory(self.work)
        self.assertEqual(result, {"files": 1, "bytes": 18, "directories": 2})


if __name__ == "__main__":
    unittest.main()
