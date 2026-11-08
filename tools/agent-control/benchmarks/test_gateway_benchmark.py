"""Harness/production Python checks only; these do NOT validate the PHP prototype."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import unittest
from unittest.mock import patch
import urllib.parse

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("gateway_benchmark", HERE / "gateway_benchmark.py")
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


class GatewayBenchmarkTests(unittest.TestCase):
    def test_corpus_deterministic_and_synthetic(self):
        self.assertEqual(b.corpus(), b.corpus())
        cases = b.corpus()["cases"]
        self.assertEqual(len(cases), 5)
        self.assertTrue(all(c["action"] in b.agent.ACTIONS for c in cases))
        self.assertEqual([len(json.loads(c["reply_json"])["data"].get("nearby", [])) for c in cases], [0, 0, 0, 8, 128])

    def test_real_client_bytes_and_response_without_network(self):
        payload = {"corpus": b.corpus(), "mode": "parity"}
        with patch("socket.create_connection", side_effect=AssertionError("no network")):
            results = b.python_worker(payload)["results"]
        for case, result in zip(payload["corpus"]["cases"], results):
            packet = bytes.fromhex(result["packet_hex"])
            self.assertEqual(packet[:2], b"\x00\x83")
            self.assertEqual(struct.unpack(">H", packet[2:4])[0], len(packet) - 4)
            self.assertEqual(packet[-1:], b"\x00")
            params = dict(urllib.parse.parse_qsl(packet[10:-1].decode()))
            self.assertEqual(params["token"], b.DUMMY_TOKEN)
            self.assertEqual(params["agent"], b.DUMMY_AGENT)
            self.assertEqual(params["action"], case["action"])
            if case["args"]:
                self.assertEqual(json.loads(params["args"]), case["args"])
            else:
                self.assertNotIn("args", params)
            self.assertEqual(result["response"], json.loads(case["reply_json"]))

    def test_unicode_and_url_sensitive_characters(self):
        result = b.python_worker({"corpus": b.corpus(), "mode": "parity"})["results"][1]
        packet = bytes.fromhex(result["packet_hex"])
        self.assertIn(b"~", packet)
        self.assertIn(b"%2F", packet)
        self.assertIn(b"%5Cu6c34", packet)
        self.assertIn(b"%5Cud83c%5Cudf33", packet)

    def test_timing_checksum_scales_and_warmup_not_counted(self):
        def run(n, warmup):
            return b.python_worker({"corpus": b.corpus(), "mode": "timing", "iterations": n, "warmup": warmup})
        one, four = run(1, 0), run(4, 3)
        self.assertEqual(four["checksum"], one["checksum"] * 4)
        self.assertEqual(four["operations"], 20)
        self.assertGreater(four["elapsed_ns"], 0)

    def test_parity_gate_rejects_either_byte_or_semantic_change(self):
        reference = b.python_worker({"corpus": b.corpus(), "mode": "parity"})
        b.validate_parity(reference, copy.deepcopy(reference))
        for key in ("packet_hex", "response"):
            changed = copy.deepcopy(reference)
            changed["results"][0][key] = "different"
            with self.assertRaisesRegex(ValueError, "parity failed"):
                b.validate_parity(reference, changed)

    def test_parity_rejects_boolean_replaced_by_integer(self):
        reference = b.python_worker({"corpus": b.corpus(), "mode": "parity"})
        changed = copy.deepcopy(reference)
        changed["results"][0]["response"]["ok"] = 1
        with self.assertRaisesRegex(ValueError, "parity failed"):
            b.validate_parity(reference, changed)

    def test_missing_php_is_failure_not_silent_python_comparison(self):
        with patch("shutil.which", return_value=None):
            with self.assertRaisesRegex(FileNotFoundError, "No PHP comparison"):
                b.benchmark("nonexistent")

    def test_invalid_sampling_parameters(self):
        for samples, iterations, warmup in ((0, 1, 0), (1, 0, 0), (1, 1, -1)):
            with self.assertRaises(ValueError):
                b.benchmark("php", samples, iterations, warmup, True)

    def test_child_environment_excludes_secrets_and_startup_hooks(self):
        with patch.dict(os.environ, {"CIV13_AGENT_TOKEN": "secret", "OPENAI_API_KEY": "secret",
                                    "PHPRC": "bad.ini", "PYTHONSTARTUP": "bad.py"}):
            env = b.child_env()
        self.assertEqual(set(env) - {"PATH", "SYSTEMROOT", "WINDIR", "TEMP", "TMP", "PYTHONDONTWRITEBYTECODE"}, set())

    def test_worker_does_not_import_orchestrator_only_modules(self):
        guard = """import builtins, runpy, sys
original = builtins.__import__
def guarded(name, globals=None, *args, **kwargs):
    # Only the harness's own imports count; the production client may import what it needs.
    importer = (globals or {}).get('__file__', '')
    if importer.endswith('gateway_benchmark.py') and name.split('.')[0] in {'argparse', 'hashlib', 'shutil', 'statistics', 'subprocess'}:
        raise AssertionError('orchestrator import in worker: ' + name)
    return original(name, globals, *args, **kwargs)
builtins.__import__ = guarded
sys.argv = [sys.argv[1], '--worker']
runpy.run_path(sys.argv[0], run_name='__main__')
"""
        result = subprocess.run([sys.executable, "-I", "-B", "-c", guard,
                                 str(HERE / "gateway_benchmark.py")],
                                input=json.dumps({"corpus": b.corpus(), "mode": "parity"}),
                                text=True, capture_output=True, env=b.child_env(), timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(json.loads(result.stdout)["results"]), 5)

    def test_python_subprocess_smoke_is_labeled_no_comparison(self):
        report = b.benchmark("not-used", samples=2, iterations=3, warmup=1, python_only=True)
        self.assertEqual(report["parity"], "not run: Python only")
        self.assertEqual(set(report["warm_us_per_operation"]), {"python"})
        self.assertIsNone(report["php_config"])
        self.assertEqual(len(report["cold_process_ms"]["python"]["samples"]), 2)
        for key in ("corpus_sha256", "harness_source_sha256", "catalog_sha256", "python_source_sha256", "php_source_sha256"):
            self.assertEqual(len(report[key]), 64)

    def test_parity_failure_prevents_timing_runs(self):
        calls = []
        def fake(command, fixture, mode, iterations, warmup):
            if not calls:
                self.assertIn("-I", command)
                self.assertIn("-B", command)
            calls.append(mode)
            return {"version": "mock", "results": [len(calls)]}, 1
        with patch("shutil.which", return_value="php"), patch.object(b, "invoke", side_effect=fake):
            with self.assertRaisesRegex(ValueError, "parity failed"):
                b.benchmark("php", samples=1, iterations=1, warmup=0)
        self.assertEqual(calls, ["parity", "parity"])

    def test_response_packet_cannot_overflow_length_field(self):
        with self.assertRaisesRegex(ValueError, "fixture exceeds"):
            b.MockTransport("x" * 65534)


if __name__ == "__main__":
    unittest.main()
