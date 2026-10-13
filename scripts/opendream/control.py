"""Local-only OpenDream supervisor. Trusted profiles, no shell or PID discovery."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import socket
import struct
import subprocess
import sys
import time
import uuid

MAX_REQUEST = 4096
MAX_OPERATIONS = 256
OPERATION_SCHEMA = "civ13.lifecycle.v1"
ACTIONS = {"start", "stop", "restart", "mapswap"}


def operation_binding(request, profile_digest, origin):
    """Canonical identity excludes transport timing; the digest is not authentication."""
    if not isinstance(request, dict) or not isinstance(origin, str) or origin not in {"cli", "game", "bootstrap"}:
        raise ValueError("Invalid operation origin or request")
    if not isinstance(profile_digest, str) or not re.fullmatch(r"[0-9a-f]{64}", profile_digest):
        raise ValueError("Invalid profile digest")
    identity = request.get("id")
    if not isinstance(identity, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,80}", identity):
        raise ValueError("Invalid operation identity")
    action, map_id = request.get("action"), request.get("map")
    if not isinstance(action, str) or action not in ACTIONS or (action != "mapswap" and map_id is not None):
        raise ValueError("Invalid operation action")
    if action == "mapswap" and (not isinstance(map_id, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", map_id)):
        raise ValueError("Invalid operation map")
    if set(request) - {"id", "action", "map", "profile_digest"}:
        raise ValueError("Unknown operation fields")
    if request.get("profile_digest", profile_digest) != profile_digest:
        raise ValueError("Operation profile mismatch")
    body = {"action": action, "map_id": map_id, "profile_digest": profile_digest, "origin": origin}
    digest = hashlib.sha256(json.dumps(body, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return identity, body, digest


class OperationStore:
    """Bounded durable no-replay barriers. Pending operations require operator recovery."""
    def __init__(self, directory, profile_digest, checkpoint=None):
        self.directory = Path(directory) / "operations"
        if self.directory.is_symlink():
            raise ValueError("Refusing linked operation directory")
        self.directory.mkdir(exist_ok=True)
        self.profile_digest = profile_digest
        self.checkpoint = checkpoint or (lambda phase: None)

    def path(self, identity):
        if not isinstance(identity, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,80}", identity):
            raise ValueError("Invalid operation identity")
        return self.directory / (hashlib.sha256(identity.encode("ascii")).hexdigest() + ".json")

    def inspect(self, identity):
        path = self.path(identity)
        if not path.exists():
            return None
        receipt = read_json(path)
        if (not isinstance(receipt, dict) or receipt.get("schema") != OPERATION_SCHEMA
                or receipt.get("operation_id") != identity or not isinstance(receipt.get("outcome"), str)
                or receipt.get("outcome") not in {"pending", "committed"}
                or not isinstance(receipt.get("request"), dict)):
            raise ValueError("Invalid operation receipt; recovery required")
        expected = {"schema", "operation_id", "binding_digest", "request", "outcome", "result"}
        if receipt["outcome"] == "committed":
            expected.add("launch_identity")
        if set(receipt) != expected:
            raise ValueError("Unknown receipt fields; recovery required")
        body = receipt["request"]
        if set(body) != {"action", "map_id", "profile_digest", "origin"}:
            raise ValueError("Invalid receipt request; recovery required")
        _, validated, _ = operation_binding(
            {"id": identity, "action": body["action"], "map": body["map_id"],
             "profile_digest": body["profile_digest"]}, self.profile_digest, body["origin"])
        if body != validated:
            raise ValueError("Invalid receipt request binding; recovery required")
        digest = hashlib.sha256(json.dumps(body, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        if receipt.get("binding_digest") != digest:
            raise ValueError("Invalid receipt binding; recovery required")
        if receipt["outcome"] == "committed" and (not isinstance(receipt.get("result"), dict) or receipt["result"].get("ok") is not True):
            raise ValueError("Invalid terminal receipt; recovery required")
        if receipt["outcome"] == "committed":
            result = receipt["result"]
            if set(result) - {"ok", "engine", "running", "game_port", "topic_port", "runtime_dir", "server_pid"}:
                raise ValueError("Unknown terminal result; recovery required")
            if "running" in result and type(result["running"]) is not bool:
                raise ValueError("Invalid terminal process state; recovery required")
            launch = receipt["launch_identity"]
            if launch is not None and (not isinstance(launch, dict)
                    or set(launch) != {"schema", "instance_id", "profile_digest", "build_id", "map_id", "ready", "server_pid"}
                    or launch.get("schema") != "civ13.launch.v1"
                    or launch.get("profile_digest") != self.profile_digest or launch.get("ready") is not False
                    or not isinstance(launch.get("instance_id"), str)
                    or not re.fullmatch(r"[A-Za-z0-9_-]{1,80}", launch["instance_id"])):
                raise ValueError("Invalid terminal launch identity; recovery required")
        if receipt["outcome"] == "pending" and receipt.get("result") is not None:
            raise ValueError("Invalid pending receipt; recovery required")
        return receipt

    @staticmethod
    def response(receipt):
        if receipt["outcome"] == "pending":
            return {"ok": False, "error": "operation_pending", "id": receipt["operation_id"], "receipt": receipt}
        return dict(receipt["result"], id=receipt["operation_id"], receipt=receipt)

    def perform(self, request, origin, effect):
        identity, body, digest = operation_binding(request, self.profile_digest, origin)
        path = self.path(identity)
        lock = path.with_suffix(".lock")
        with lock.open("x", encoding="ascii"):
            pass
        try:
            existing = self.inspect(identity)
            if existing is not None:
                if existing["binding_digest"] != digest:
                    raise ValueError("Operation identity conflict")
                return self.response(existing)
            allocation = self.directory / "allocation.lock"
            with allocation.open("x", encoding="ascii"):
                pass
            try:
                if len(list(self.directory.glob("*.json"))) >= MAX_OPERATIONS:
                    raise ValueError("Operation history full; no receipts are automatically discarded")
                receipt = {"schema": OPERATION_SCHEMA, "operation_id": identity, "binding_digest": digest,
                           "request": body, "outcome": "pending", "result": None}
                atomic_json(path, receipt)
            finally:
                allocation.unlink(missing_ok=True)
            self.checkpoint("pending_published")
            result = effect()
            self.checkpoint("effect_completed")
            if not isinstance(result, dict) or result.get("ok") is not True:
                raise ValueError("Uncertain operation outcome; pending barrier retained")
            result = dict(result)
            launch = result.pop("launch_identity", None)
            receipt = dict(receipt, outcome="committed", result=result, launch_identity=launch)
            atomic_json(path, receipt)
            self.checkpoint("terminal_published")
            return self.response(receipt)
        finally:
            lock.unlink(missing_ok=True)


def topic_status(port):
    """Read-only standard BYOND Topic packet to the explicit loopback Topic port."""
    body = b"\0" * 5 + b"?status=1&format=json\0"
    with socket.create_connection(("127.0.0.1", port), timeout=5) as connection:
        connection.sendall(b"\x00\x83" + struct.pack(">H", len(body)) + body)
        def receive(size):
            data = b""
            while len(data) < size:
                chunk = connection.recv(size - len(data))
                if not chunk:
                    raise ValueError("Incomplete Topic response")
                data += chunk
            return data
        header = receive(4)
        if header[:2] != b"\x00\x83":
            raise ValueError("Unexpected Topic response header")
        length = struct.unpack(">H", header[2:])[0]
        if not 2 <= length <= 32768:
            raise ValueError("Invalid Topic response length")
        response = receive(length)
        if response[0] != 6 or response[-1] != 0:
            raise ValueError("Expected a terminated string Topic status response")
        result = json.loads(response[1:-1].decode("ascii"))
        if not isinstance(result, dict) or "players" not in result:
            raise ValueError("Not a Civ13 status response")
        return result


def atomic_json(path, value):
    path = Path(path)
    if path.is_symlink():
        raise ValueError("Refusing linked control publication")
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
    try:
        with temporary.open("x", encoding="utf-8") as handle:
            handle.write(json.dumps(value))
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def read_json(path):
    path = Path(path)
    if path.is_symlink():
        raise ValueError("Refusing linked control input")
    if path.stat().st_size > MAX_REQUEST:
        raise ValueError("Request exceeds size limit")
    return json.loads(path.read_text(encoding="utf-8"))


class Supervisor:
    def __init__(self, profile):
        self.profile_path = Path(profile).resolve(strict=True)
        if self.profile_path.stat().st_size > 65536:
            raise ValueError("Profile exceeds size limit")
        profile_bytes = self.profile_path.read_bytes()
        self.profile_digest = hashlib.sha256(profile_bytes).hexdigest()
        self.profile = json.loads(profile_bytes)
        if self.profile.get("engine") != "opendream":
            raise ValueError("Only explicit opendream profiles are accepted")
        self.root = Path(self.profile["runtime_dir"]).resolve(strict=True)
        self.control = self.root / "SQL" / "opendream-control"
        self.control.mkdir(parents=True, exist_ok=True)
        self.child = None
        self.log = None
        self.pending_map = None
        self.map_id = self.profile.get("map_id")
        self.instance_id = None
        self.operations = OperationStore(self.control, self.profile_digest)
        active = self.control / "active-map.json"
        if active.exists():
            record = read_json(active)
            if (not isinstance(record, dict) or set(record) != {"schema", "profile_digest", "map_id", "dme_sha256", "json_sha256"}
                    or record.get("schema") != "civ13.active-map.v1"
                    or record.get("profile_digest") != self.profile_digest
                    or not isinstance(record.get("map_id"), str)
                    or record.get("map_id") not in self.profile.get("maps", {})):
                raise ValueError("Active map identity uncertain; operator recovery required")
            for path, field in ((self.root / "civ13.dme", "dme_sha256"), (self.root / "civ13.json", "json_sha256")):
                if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest() != record.get(field):
                    raise ValueError("Active map bytes changed; operator recovery required")
            self.map_id = record["map_id"]
        self.restore_map_stage()
        for field in ("build_id", "map_id"):
            value = self.profile.get(field)
            if value is not None and (not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,80}", value)):
                raise ValueError("Invalid trusted launch identity")
        for name in ("game_port", "topic_port"):
            port = self.profile[name]
            if type(port) is not int or not 1024 <= port <= 65535:
                raise ValueError("Invalid " + name)
        if self.profile["game_port"] == self.profile["topic_port"]:
            raise ValueError("Game and Topic ports must differ")
        command = self.profile["server_command"]
        if not isinstance(command, list) or not command or not all(isinstance(x, str) for x in command):
            raise ValueError("server_command must be a trusted argv list")
        if not Path(command[0]).is_absolute():
            raise ValueError("Executable must be absolute")

    def restore_map_stage(self):
        marker = self.control / "staged-map.json"
        if not marker.exists():
            return
        record = read_json(marker)
        if (not isinstance(record, dict) or set(record) != {"schema", "profile_digest", "map_id", "state", "dme_sha256", "json_sha256"}
                or record.get("schema") != "civ13.map-stage.v1"
                or record.get("profile_digest") != self.profile_digest
                or record.get("state") != "staged"
                or not isinstance(record.get("map_id"), str)
                or record.get("map_id") not in self.profile.get("maps", {})):
            raise ValueError("Map stage uncertain; operator recovery required")
        staged = self.root / "opendream-staged.dme"
        compiled = self.root / "opendream-staged.json"
        for path, field in ((staged, "dme_sha256"), (compiled, "json_sha256")):
            if path.is_symlink() or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != record.get(field):
                raise ValueError("Map stage changed; operator recovery required")
        self.pending_map = (staged, compiled, record["map_id"])

    def commit_map_stage(self):
        # Validate bytes before stopping. Applying survives interrupted multi-file replacement.
        self.restore_map_stage()
        staged, compiled, map_id = self.pending_map
        marker = self.control / "staged-map.json"
        atomic_json(marker, dict(read_json(marker), state="applying"))
        self.stop()
        os.replace(compiled, self.root / "civ13.json")
        os.replace(staged, self.root / "civ13.dme")
        record = read_json(marker)
        atomic_json(self.control / "active-map.json", {
            "schema": "civ13.active-map.v1", "profile_digest": self.profile_digest,
            "map_id": map_id, "dme_sha256": record["dme_sha256"], "json_sha256": record["json_sha256"]})
        self.map_id = map_id
        self.pending_map = None
        marker.unlink()

    def status(self):
        return {"ok": True, "engine": "opendream", "running": bool(self.child and self.child.poll() is None),
                "game_port": self.profile["game_port"], "topic_port": self.profile["topic_port"],
                "runtime_dir": str(self.root), "server_pid": self.child.pid if self.child else None}

    def start(self):
        if self.child and self.child.poll() is None:
            return
        if self.log:
            self.log.close()
        self.log = (self.control / "server.log").open("ab")
        # This identity is ownership correlation, not authentication or game readiness.
        self.instance_id = uuid.uuid4().hex
        identity = {"schema": "civ13.launch.v1", "instance_id": self.instance_id,
                    "profile_digest": self.profile_digest, "build_id": self.profile.get("build_id"),
                    "map_id": self.map_id, "ready": False, "server_pid": None}
        atomic_json(self.control / "launch.json", identity)
        self.child = subprocess.Popen(self.profile["server_command"], cwd=self.root,
                                      stdin=subprocess.DEVNULL, stdout=self.log, stderr=subprocess.STDOUT)
        atomic_json(self.control / "launch.json", dict(identity, server_pid=self.child.pid))

    def stop(self):
        launch = self.control / "launch.json"
        if launch.exists():
            atomic_json(launch, dict(read_json(launch), ready=False))
        if self.child and self.child.poll() is None:
            self.child.terminate()
            try:
                self.child.wait(timeout=15)
            except subprocess.TimeoutExpired:
                self.child.kill()
                self.child.wait(timeout=5)
        if self.log:
            self.log.close()
            self.log = None

    def mapswap(self, map_id, defer=False):
        if self.pending_map:
            raise ValueError("A compiled game map is pending the round restart")
        maps = self.profile.get("maps", {})
        if not isinstance(map_id, str) or map_id not in maps:
            raise ValueError("Map is not allowed by this profile")
        target = (self.root / maps[map_id]).resolve(strict=True)
        if not target.is_relative_to(self.root) or target.suffix.lower() != ".dmm":
            raise ValueError("Map must be a DMM inside runtime_dir")
        dme = self.root / "civ13.dme"
        source = dme.read_text(encoding="utf-8-sig")
        pattern = r'^\s*#include\s+"[^"\r\n]+\.dmm"\s*$'
        if len(re.findall(pattern, source, re.MULTILINE | re.IGNORECASE)) != 1:
            raise ValueError("Expected exactly one map include")
        replacement = '#include "' + target.relative_to(self.root).as_posix() + '"'
        staged = self.root / "opendream-staged.dme"
        compiled = staged.with_suffix(".json")
        if staged.is_symlink() or compiled.is_symlink():
            raise ValueError("Refusing linked map stage files")
        try:
            staged.write_text(re.sub(pattern, lambda _: replacement, source,
                                    flags=re.MULTILINE | re.IGNORECASE), encoding="utf-8")
            compiler = Path(self.profile["compiler"])
            if not compiler.is_absolute():
                raise ValueError("Compiler must be absolute")
            compiler = compiler.resolve(strict=True)
            with (self.control / "compile.log").open("wb") as log:
                subprocess.run([str(compiler), "--version=516.1681", str(staged)], cwd=self.root,
                               stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                               timeout=180, check=True)
            if not compiled.is_file() or compiled.stat().st_size == 0:
                raise ValueError("Compiler produced no JSON; running server preserved")
            atomic_json(self.control / "staged-map.json", {
                "schema": "civ13.map-stage.v1", "profile_digest": self.profile_digest,
                "map_id": map_id, "state": "staged",
                "dme_sha256": hashlib.sha256(staged.read_bytes()).hexdigest(),
                "json_sha256": hashlib.sha256(compiled.read_bytes()).hexdigest()})
            self.pending_map = (staged, compiled, map_id)
            if defer:
                return
            # Compilation is complete before the owned server is touched.
            self.commit_map_stage()
            self.start()
        finally:
            if not self.pending_map:
                staged.unlink(missing_ok=True)
                compiled.unlink(missing_ok=True)

    def dispatch(self, request, from_game=False):
        action = request.get("action")
        if action == "status":
            return self.status()
        if action == "start":
            self.start()
        elif action == "restart":
            if self.pending_map:
                self.commit_map_stage()
            else:
                self.stop()
            self.start()
        elif action == "mapswap":
            self.mapswap(request.get("map"), defer=from_game)
        elif action == "stop":
            self.stop()
        else:
            raise ValueError("Unsupported action")
        return self.status()

    def operate(self, request, origin="cli"):
        if hashlib.sha256(self.profile_path.read_bytes()).hexdigest() != self.profile_digest:
            raise ValueError("Controller profile changed; explicit review required")
        if request.get("action") == "status":
            return dict(self.status(), id=request.get("id"))
        def effect():
            result = self.dispatch(request, from_game=origin == "game")
            path = self.control / "launch.json"
            result["launch_identity"] = read_json(path) if path.exists() else None
            return result
        return self.operations.perform(request, origin, effect)

    def run(self):
        lock = self.control / "supervisor.lock"
        # Never recover a stale PID by guessing which process it belongs to.
        with lock.open("x", encoding="utf-8") as handle:
            handle.write(str(os.getpid()))
        try:
            for receipt_path in self.operations.directory.glob("*.json"):
                record = read_json(receipt_path)
                if not isinstance(record, dict) or not isinstance(record.get("operation_id"), str):
                    raise ValueError("Corrupt operation history; recovery required")
                receipt = self.operations.inspect(record["operation_id"])
                if receipt_path != self.operations.path(record["operation_id"]) or receipt["outcome"] == "pending":
                    raise ValueError("Uncertain operation history; refusing a new supervisor")
            if not (self.control / "request.json").exists():
                self.operate({"id": uuid.uuid4().hex, "action": "start", "map": None}, "bootstrap")
            atomic_json(self.control / "enabled.json", {"enabled": True})
            while True:
                paths = [self.control / "game-request.json", self.control / "request.json"]
                for path in paths:
                    if not path.exists():
                        continue
                    if path.name == "game-request.json" and not (self.control / "game-ready").exists():
                        continue
                    request = {}
                    try:
                        request = read_json(path)
                        if not isinstance(request, dict):
                            raise ValueError("Request must be an object")
                        if path.name == "game-request.json" and "id" not in request:
                            request["id"] = uuid.uuid4().hex
                            atomic_json(path, request)
                        result = self.operate(request, "game" if path.name == "game-request.json" else "cli")
                    except (ValueError, OSError, subprocess.SubprocessError) as error:
                        result = {"ok": False, "error": str(error)}
                        if isinstance(request, dict) and isinstance(request.get("id"), str) and re.fullmatch(r"[A-Za-z0-9_-]{1,80}", request["id"]):
                            receipt = self.operations.inspect(request["id"])
                            if receipt and receipt["outcome"] == "pending":
                                result = self.operations.response(receipt)
                    result["id"] = request.get("id") if isinstance(request, dict) else None
                    # Both the durable terminal receipt and transport reply precede request removal.
                    atomic_json(self.control / ("game-result.json" if path.name.startswith("game-") else "result.json"), result)
                    if path.name == "game-request.json":
                        (self.control / "game-ready").unlink(missing_ok=True)
                    path.unlink(missing_ok=True)
                    if result.get("error") == "operation_pending":
                        # Quarantine the writer, not just this request, after an uncertain effect.
                        return
                    if isinstance(request, dict) and request.get("action") == "stop" and result.get("ok"):
                        return
                time.sleep(0.1)
        finally:
            self.stop()
            (self.control / "enabled.json").unlink(missing_ok=True)
            lock.unlink(missing_ok=True)


def request(supervisor, action, map_id=None, timeout=200, operation_id=None, start_hook=None):
    directory = supervisor.control
    lock = directory / "request.lock"
    with lock.open("x", encoding="utf-8"):
        pass
    try:
        token = operation_id or uuid.uuid4().hex
        body = {"id": token, "action": action, "map": map_id, "profile_digest": supervisor.profile_digest}
        if action in ACTIONS:
            _, _, digest = operation_binding(body, supervisor.profile_digest, "cli")
            previous = supervisor.operations.inspect(token)
            if previous:
                if previous["binding_digest"] != digest:
                    raise ValueError("Operation identity conflict")
                return supervisor.operations.response(previous)
        if (directory / "request.json").exists():
            raise ValueError("An unresolved request exists; inspect its receipt before retrying")
        atomic_json(directory / "request.json", body)
        if start_hook:
            start_hook()
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                result = read_json(directory / "result.json")
                if result.get("id") == token:
                    return result
            except FileNotFoundError:
                pass
            time.sleep(0.1)
        raise TimeoutError("Control request timed out; do not replay until its receipt is inspected")
    finally:
        lock.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", required=True)
    parser.add_argument("action", choices=["start", "stop", "restart", "status", "topic-status", "mapswap", "supervise", "operation-status"])
    parser.add_argument("map", nargs="?")
    parser.add_argument("--operation-id", help="Immutable lifecycle identity; reuse only to inspect the same action/map/profile")
    args = parser.parse_args()
    try:
        supervisor = Supervisor(args.profile)
        if args.action == "operation-status":
            receipt = supervisor.operations.inspect(args.operation_id)
            if receipt and receipt["request"].get("profile_digest") != supervisor.profile_digest:
                raise ValueError("Operation profile mismatch")
            print(json.dumps({"ok": True, "schema": OPERATION_SCHEMA,
                              "operation_status": receipt["outcome"] if receipt else "not_found", "receipt": receipt}))
            return 0
        if args.action == "topic-status":
            print(json.dumps({"ok": True, "topic_port": supervisor.profile["topic_port"],
                              "status": topic_status(supervisor.profile["topic_port"])}))
            return 0
        if args.action == "supervise":
            supervisor.run()
            return 0
        if args.action == "start":
            def launch_supervisor():
                if (supervisor.control / "supervisor.lock").exists():
                    return
                flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
                subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--profile",
                                  str(supervisor.profile_path), "supervise"], cwd=supervisor.root,
                                 stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                 creationflags=flags, start_new_session=os.name != "nt")
            result = request(supervisor, "start", timeout=20, operation_id=args.operation_id, start_hook=launch_supervisor)
        else:
            if not (supervisor.control / "supervisor.lock").exists():
                if args.action == "status":
                    print(json.dumps(supervisor.status()))
                    return 0
                raise ValueError("No owned supervisor; refusing to target another server")
            result = request(supervisor, args.action, args.map, operation_id=args.operation_id)
        print(json.dumps(result))
        return 0 if result.get("ok") else 1
    except (ValueError, OSError, TimeoutError) as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        return 1


if __name__ == "__main__":
    sys.exit(main())

