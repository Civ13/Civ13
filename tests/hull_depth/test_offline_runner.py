"""Checks for the opt-in runner, without starting either BYOND binary."""
from hashlib import sha256
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase
from unittest.mock import patch
import json

spec = spec_from_file_location("hull_depth_offline_runner", Path(__file__).with_name("run_roundtrip_offline.py"))
runner = module_from_spec(spec)
spec.loader.exec_module(runner)


class OfflineRunner(TestCase):
    def test_rejects_unpinned_or_modified_fixture(self):
        pin = json.loads((runner.ROOT / "tools/byond/version.json").read_text())["version"]
        with TemporaryDirectory() as work:
            work = Path(work)
            blobs = {"probe.dmb": b"synthetic DMB", "probe.rsc": b"synthetic RSC"}
            receipt = {"probe": "roundtrip", "compiler": pin, "artifacts_sha256": {}}
            for name, data in blobs.items():
                (work / name).write_bytes(data)
                receipt["artifacts_sha256"][name] = sha256(data).hexdigest()
            receipt_path = work / "receipt.json"
            receipt_path.write_text(json.dumps(receipt))
            self.assertEqual(runner.fixture_bytes(work), blobs)
            receipt["probe"] = "pressure"
            receipt_path.write_text(json.dumps(receipt))
            with self.assertRaisesRegex(ValueError, "two-stage roundtrip fixture"):
                runner.fixture_bytes(work)
            receipt["probe"] = "roundtrip"
            receipt["compiler"] = "0.0"
            receipt_path.write_text(json.dumps(receipt))
            with self.assertRaisesRegex(ValueError, "repository pin"):
                runner.fixture_bytes(work)
            receipt["compiler"] = pin
            receipt_path.write_text(json.dumps(receipt))
            (work / "probe.dmb").write_bytes(b"changed")
            with self.assertRaisesRegex(ValueError, "does not match compile receipt"):
                runner.fixture_bytes(work)

    def test_environment_is_fresh_allowlist_for_cgi(self):
        with TemporaryDirectory() as work, patch.dict("os.environ", {"BYOND_USER": "sentinel", "LD_PRELOAD": "sentinel"}):
            work = Path(work)
            with patch.object(runner.os, "readlink", return_value="net:[synthetic]"):
                env = runner.empty_runtime(work / "synthetic_home", work / "byond")
            self.assertEqual(env["REQUEST_METHOD"], "GET")
            self.assertTrue(Path(env["TMPDIR"]).is_dir())
            self.assertEqual(env["HOME"], str(work / "synthetic_home"))
            self.assertNotIn("BYOND_USER", env)
            self.assertNotIn("LD_PRELOAD", env)
