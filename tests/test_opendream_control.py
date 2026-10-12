"""Production supervisor contracts using isolated storage and owned dummy children."""
import importlib.util
import json
from pathlib import Path
import subprocess
import socket
import struct
import sys
import tempfile
import time
import threading
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/opendream/control.py"
spec = importlib.util.spec_from_file_location("opendream_control", SCRIPT)
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)


class Controls(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        (self.root / "maps").mkdir()
        (self.root / "maps/a.dmm").write_text("dummy", encoding="utf-8")
        (self.root / "maps/b.dmm").write_text("dummy", encoding="utf-8")
        (self.root / "civ13.dme").write_text('#include "code.dm"\n#include "maps/a.dmm"\n', encoding="utf-8")
        (self.root / "civ13.json").write_text('{"old":true}', encoding="utf-8")
        self.profile_path = self.root / "profile.json"
        self.profile = {"engine": "opendream", "runtime_dir": str(self.root),
                        "game_port": 18452, "topic_port": 18462,
                        "server_command": [sys.executable, "-c", "import time; time.sleep(300)"],
                        "compiler": sys.executable, "maps": {"B": "maps/b.dmm"}}
        self.profile_path.write_text(json.dumps(self.profile), encoding="utf-8")
        self.supervisor = control.Supervisor(self.profile_path)

    def tearDown(self):
        self.supervisor.stop()
        self.temporary.cleanup()

    def test_owned_restart_does_not_stop_unrelated_child(self):
        unrelated = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(300)"])
        try:
            self.supervisor.start()
            old = self.supervisor.child
            result = self.supervisor.dispatch({"action": "restart"})
            self.assertTrue(result["running"])
            self.assertIsNotNone(old.poll())
            self.assertNotEqual(old.pid, self.supervisor.child.pid)
            self.supervisor.stop()
            self.assertIsNone(unrelated.poll())
        finally:
            unrelated.terminate()
            unrelated.wait(timeout=10)

    def test_failed_compile_preserves_live_server_and_sources(self):
        self.supervisor.start()
        old = self.supervisor.child
        original = (self.root / "civ13.dme").read_bytes()
        with patch.object(control.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "compiler")):
            with self.assertRaises(subprocess.CalledProcessError):
                self.supervisor.mapswap("B")
        self.assertIsNone(old.poll())
        self.assertEqual(original, (self.root / "civ13.dme").read_bytes())
        self.assertEqual('{"old":true}', (self.root / "civ13.json").read_text())
        self.assertFalse((self.root / "opendream-staged.dme").exists())

    def test_map_commit_restarts_only_after_compiled_output(self):
        self.supervisor.start()
        old = self.supervisor.child
        def compile_output(*args, **kwargs):
            self.assertIsNone(old.poll())
            self.assertIn('maps/b.dmm', (self.root / "opendream-staged.dme").read_text())
            (self.root / "opendream-staged.json").write_text('{"new":true}')
        with patch.object(control.subprocess, "run", side_effect=compile_output):
            self.supervisor.mapswap("B")
        self.assertIsNotNone(old.poll())
        self.assertIn('maps/b.dmm', (self.root / "civ13.dme").read_text())
        self.assertEqual('{"new":true}', (self.root / "civ13.json").read_text())

    def test_unknown_or_escaping_map_does_not_stop_server(self):
        self.supervisor.start()
        old = self.supervisor.child
        for value in ("../outside", "B; shutdown", None):
            with self.assertRaises(ValueError):
                self.supervisor.mapswap(value)
        self.supervisor.profile["maps"]["ESCAPE"] = "../outside.dmm"
        outside = self.root.parent / "outside.dmm"
        # No external file creation needed; resolve(strict=True) rejects absence.
        with self.assertRaises((ValueError, FileNotFoundError)):
            self.supervisor.mapswap("ESCAPE")
        self.assertIsNone(old.poll())

    def test_missing_compiler_output_is_not_committed(self):
        self.supervisor.start()
        old = self.supervisor.child
        with patch.object(control.subprocess, "run"):
            with self.assertRaises(ValueError):
                self.supervisor.mapswap("B")
        self.assertIsNone(old.poll())

    def test_profile_requires_explicit_engine_and_separate_ports(self):
        for field, value in (("engine", "byond"), ("topic_port", 18452), ("game_port", 80),
                             ("server_command", ["DreamDaemon"])):
            profile = dict(self.profile, **{field: value})
            self.profile_path.write_text(json.dumps(profile))
            with self.assertRaises(ValueError):
                control.Supervisor(self.profile_path)

    def test_unknown_action_rejected(self):
        with self.assertRaises(ValueError):
            self.supervisor.dispatch({"action": "shell", "command": "anything"})

    def test_pending_request_not_replayed(self):
        control.atomic_json(self.supervisor.control / "request.json", {"id": "previous"})
        with self.assertRaises(ValueError):
            control.request(self.supervisor, "restart", timeout=.2)
        self.assertEqual("previous", control.read_json(self.supervisor.control / "request.json")["id"])

    def test_oversized_request_rejected(self):
        target = self.root / "oversized.json"
        target.write_text(" " * (control.MAX_REQUEST + 1))
        with self.assertRaises(ValueError):
            control.read_json(target)

    def topic_server(self, response):
        listener = socket.socket()
        listener.bind(("127.0.0.1", 0))
        listener.listen(1)
        port = listener.getsockname()[1]
        observed = []
        def serve():
            try:
                with listener.accept()[0] as connection:
                    observed.append(connection.recv(4096))
                    # Split all headers/body bytes to verify exact reads.
                    for byte in response:
                        connection.sendall(bytes([byte]))
            finally:
                listener.close()
        thread = threading.Thread(target=serve)
        thread.start()
        return port, thread, observed

    def test_topic_wire_protocol_and_fragmented_reply(self):
        payload = b'\x06{"players":0,"map_name":"test"}\0'
        port, thread, observed = self.topic_server(b'\x00\x83' + struct.pack('>H', len(payload)) + payload)
        self.assertEqual(0, control.topic_status(port)["players"])
        thread.join(timeout=5)
        packet = observed[0]
        self.assertEqual(b'\x00\x83', packet[:2])
        self.assertEqual(len(packet) - 4, struct.unpack('>H', packet[2:4])[0])
        self.assertEqual(b'?status=1&format=json\0', packet[9:])

    def test_topic_truncated_reply_rejected(self):
        port, thread, _ = self.topic_server(b'\x00\x83\x00\x05\x06x')
        with self.assertRaises(ValueError):
            control.topic_status(port)
        thread.join(timeout=5)

    def test_cli_and_game_spool(self):
        daemon = subprocess.Popen([sys.executable, str(SCRIPT), "--profile", str(self.profile_path), "supervise"])
        try:
            deadline = time.monotonic() + 10
            while not (self.supervisor.control / "enabled.json").exists():
                self.assertIsNone(daemon.poll())
                self.assertLess(time.monotonic(), deadline)
                time.sleep(.05)
            result = control.request(self.supervisor, "status", timeout=5)
            self.assertTrue(result["running"])
            self.assertEqual(str(self.root), result["runtime_dir"])
            control.atomic_json(self.supervisor.control / "game-request.json", {"action": "restart"})
            time.sleep(.3)
            # An incomplete DM fcopy must never be consumed.
            self.assertFalse((self.supervisor.control / "game-result.json").exists())
            (self.supervisor.control / "game-ready").write_text("ready")
            deadline = time.monotonic() + 5
            while not (self.supervisor.control / "game-result.json").exists():
                self.assertLess(time.monotonic(), deadline)
                time.sleep(.05)
            restarted = control.read_json(self.supervisor.control / "game-result.json")
            self.assertTrue(restarted["running"])
            self.assertNotEqual(result["server_pid"], restarted["server_pid"])
            control.request(self.supervisor, "stop", timeout=5)
            daemon.wait(timeout=10)
            self.assertFalse((self.supervisor.control / "supervisor.lock").exists())
        finally:
            if daemon.poll() is None:
                try:
                    control.request(self.supervisor, "stop", timeout=5)
                    daemon.wait(timeout=10)
                except Exception:
                    daemon.terminate()
                    daemon.wait(timeout=10)


if __name__ == "__main__":
    unittest.main()
