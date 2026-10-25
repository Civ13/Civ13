"""Bounded synthetic filesystem checks only; no native process or private data read."""
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import collect_evidence
import run


class PrivateHomeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="snow-private-home-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.private = self.home / ".byond"
        self.private.mkdir(parents=True)

    def both(self):
        run.compile_inventory(self.root)
        run.runtime_inventory(self.root)

    def test_empty_engine_directory_and_bounded_nested_files_allowed(self):
        self.both()
        nested = self.private / "cache" / "version"
        nested.mkdir(parents=True)
        (nested / "item.cfg").write_bytes(b"synthetic engine state")
        result = run.private_home_inventory(self.root)
        self.assertEqual(result, {"files": 1, "directories": 3, "bytes": 22})
        self.both()

    def test_home_not_yet_created_is_empty_inventory(self):
        with tempfile.TemporaryDirectory() as absent:
            self.assertEqual(run.private_home_inventory(Path(absent)),
                             {"files": 0, "directories": 0, "bytes": 0})

    def test_home_itself_cannot_be_a_file(self):
        self.private.rmdir()
        self.home.rmdir()
        self.home.write_text("not a directory")
        with self.assertRaises(ValueError):
            self.both()

    def test_only_byond_subdirectory_allowed(self):
        for entry in ("other", ".config"):
            path = self.home / entry
            path.mkdir()
            with self.assertRaisesRegex(ValueError, "Only .byond"):
                self.both()
            path.rmdir()
        (self.home / "file.txt").write_bytes(b"no")
        with self.assertRaises(ValueError):
            self.both()

    def test_byond_root_cannot_be_regular_file(self):
        self.private.rmdir()
        self.private.write_bytes(b"no")
        with self.assertRaises(ValueError):
            self.both()

    def test_file_and_total_byte_limits(self):
        size = run.PRIVATE_HOME["file_bytes"]
        for i in range(4):
            (self.private / str(i)).write_bytes(b"x" * size)
        self.both()
        (self.private / "extra").write_bytes(b"x")
        with self.assertRaisesRegex(ValueError, "count or size"):
            self.both()
        for p in self.private.iterdir():
            p.unlink()
        (self.private / "too-large").write_bytes(b"x" * (size + 1))
        with self.assertRaisesRegex(ValueError, "count or size"):
            self.both()

    def test_file_count_limit_even_for_empty_files(self):
        for i in range(run.PRIVATE_HOME["files"]):
            (self.private / str(i)).touch()
        self.both()
        (self.private / "extra").touch()
        with self.assertRaisesRegex(ValueError, "count or size"):
            self.both()

    def test_directory_count_limit(self):
        for i in range(run.PRIVATE_HOME["directories"] - 1):
            (self.private / str(i)).mkdir()
        self.both()
        (self.private / "extra").mkdir()
        with self.assertRaisesRegex(ValueError, "directory count"):
            self.both()

    def test_depth_limit(self):
        deep = self.private / "a" / "b" / "c"
        deep.mkdir(parents=True)
        self.both()
        (deep / "too-deep").touch()
        with self.assertRaisesRegex(ValueError, "depth"):
            self.both()

    def test_symlink_home_directory_and_private_file_rejected(self):
        target = self.root / "target"
        target.mkdir()
        for path in (self.private / "linked",):
            path.symlink_to(target, target_is_directory=True)
            with self.assertRaises(ValueError):
                run.private_home_inventory(self.root)
            path.unlink()
        self.private.rmdir()
        self.private.symlink_to(target, target_is_directory=True)
        with self.assertRaises(ValueError):
            run.private_home_inventory(self.root)
        self.private.unlink()
        self.home.rmdir()
        self.home.symlink_to(target, target_is_directory=True)
        with self.assertRaises(ValueError):
            run.private_home_inventory(self.root)

    def test_hardlinks_and_nonregular_files_rejected_without_opening(self):
        target = self.root / "synthetic-target"
        target.write_bytes(b"not read")
        link = self.private / "hardlink"
        os.link(target, link)
        with self.assertRaisesRegex(ValueError, "hard links"):
            run.private_home_inventory(self.root)
        link.unlink()
        os.mkfifo(self.private / "fifo")
        with self.assertRaisesRegex(ValueError, "non-regular"):
            run.private_home_inventory(self.root)

    def test_directory_swap_to_link_is_not_followed(self):
        child = self.private / "cache"
        child.mkdir()
        target = self.root / "synthetic-target"
        target.mkdir()
        real_open = os.open
        def swapped(name, flags, *args, **kwargs):
            if name == "cache":
                child.rmdir()
                child.symlink_to(target, target_is_directory=True)
            return real_open(name, flags, *args, **kwargs)
        with patch.object(os, "open", side_effect=swapped):
            with self.assertRaisesRegex(ValueError, "metadata inspection failed"):
                run.private_home_inventory(self.root)

    def test_private_contents_never_read_and_user_home_ignored(self):
        (self.private / "synthetic.cfg").write_text("not to be read")
        with patch.dict(os.environ, {"HOME": "/not-the-task-home"}), \
                patch.object(Path, "read_bytes", side_effect=AssertionError("No private reads")), \
                patch.object(Path, "read_text", side_effect=AssertionError("No private reads")):
            self.both()
            self.assertEqual(os.environ["HOME"], "/not-the-task-home")

    def test_outside_inventory_stays_strict(self):
        for relative in ("unexpected", "tmp/cache", "icons/unknown"):
            path = self.root / relative
            path.mkdir(parents=True)
            for checker in (run.compile_inventory, run.runtime_inventory):
                with self.subTest(relative=relative, checker=checker.__name__), self.assertRaises(ValueError):
                    checker(self.root)
            path.rmdir()
        (self.root / "real.sav").write_bytes(b"synthetic disallowed")
        for checker in (run.compile_inventory, run.runtime_inventory):
            with self.assertRaises(ValueError):
                checker(self.root)

    def test_no_private_home_path_is_artifact_candidate(self):
        evidence = self.root / "evidence"
        for phase in ("source", "run"):
            home = evidence / "cases/baseline" / phase / "home/.byond"
            home.mkdir(parents=True)
            (home / "synthetic.cfg").write_text("private fixture state")
        private_roots = [evidence / "cases/baseline" / phase / "home" for phase in ("source", "run")]
        real_read = Path.read_bytes
        def no_private(path):
            if any(path == root or root in path.parents for root in private_roots):
                raise AssertionError("Collector must not read private HOME")
            return real_read(path)
        with patch.object(Path, "read_bytes", no_private):
            result = collect_evidence.collect(evidence, self.root / "acquisition",
                        Path(__file__).resolve().parent, self.root / "retained")
        self.assertFalse(result["rejected"])
        self.assertFalse(any("home" in Path(row["path"]).parts for row in result["files"]))


if __name__ == "__main__":
    unittest.main()
