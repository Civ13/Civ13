"""Local-only OpenDream supervisor. Trusted profiles, no shell or PID discovery."""
import argparse
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
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value), encoding="utf-8")
    os.replace(temporary, path)


def read_json(path):
    path = Path(path)
    if path.stat().st_size > MAX_REQUEST:
        raise ValueError("Request exceeds size limit")
    return json.loads(path.read_text(encoding="utf-8"))


class Supervisor:
    def __init__(self, profile):
        self.profile_path = Path(profile).resolve(strict=True)
        self.profile = json.loads(self.profile_path.read_text(encoding="utf-8"))
        if self.profile.get("engine") != "opendream":
            raise ValueError("Only explicit opendream profiles are accepted")
        self.root = Path(self.profile["runtime_dir"]).resolve(strict=True)
        self.control = self.root / "SQL" / "opendream-control"
        self.control.mkdir(parents=True, exist_ok=True)
        self.child = None
        self.log = None
        self.pending_map = None
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
        self.child = subprocess.Popen(self.profile["server_command"], cwd=self.root,
                                      stdin=subprocess.DEVNULL, stdout=self.log, stderr=subprocess.STDOUT)

    def stop(self):
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
            if defer:
                self.pending_map = (staged, compiled)
                return
            # Compilation is complete before the owned server is touched.
            self.stop()
            os.replace(compiled, self.root / "civ13.json")
            os.replace(staged, dme)
            self.start()
        finally:
            if not self.pending_map:
                staged.unlink(missing_ok=True)
                compiled.unlink(missing_ok=True)

    def dispatch(self, request, from_game=False):
        action = request.get("action")
        if action == "status":
            return self.status()
        if action == "restart":
            self.stop()
            if self.pending_map:
                staged, compiled = self.pending_map
                os.replace(compiled, self.root / "civ13.json")
                os.replace(staged, self.root / "civ13.dme")
                self.pending_map = None
            self.start()
        elif action == "mapswap":
            self.mapswap(request.get("map"), defer=from_game)
        elif action == "stop":
            self.stop()
        else:
            raise ValueError("Unsupported action")
        return self.status()

    def run(self):
        lock = self.control / "supervisor.lock"
        # Never recover a stale PID by guessing which process it belongs to.
        with lock.open("x", encoding="utf-8") as handle:
            handle.write(str(os.getpid()))
        try:
            self.start()
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
                        result = self.dispatch(request, from_game=path.name == "game-request.json")
                    except (ValueError, OSError, subprocess.SubprocessError) as error:
                        result = {"ok": False, "error": str(error)}
                    result["id"] = request.get("id") if isinstance(request, dict) else None
                    if path.name == "game-request.json":
                        (self.control / "game-ready").unlink(missing_ok=True)
                    path.unlink(missing_ok=True)
                    atomic_json(self.control / ("game-result.json" if path.name.startswith("game-") else "result.json"), result)
                    if isinstance(request, dict) and request.get("action") == "stop" and result.get("ok"):
                        return
                time.sleep(0.1)
        finally:
            self.stop()
            (self.control / "enabled.json").unlink(missing_ok=True)
            lock.unlink(missing_ok=True)


def request(supervisor, action, map_id=None, timeout=200):
    directory = supervisor.control
    lock = directory / "request.lock"
    with lock.open("x", encoding="utf-8"):
        pass
    try:
        if (directory / "request.json").exists():
            raise ValueError("An unresolved request exists; inspect its receipt before retrying")
        token = uuid.uuid4().hex
        atomic_json(directory / "request.json", {"id": token, "action": action, "map": map_id})
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
    parser.add_argument("action", choices=["start", "stop", "restart", "status", "topic-status", "mapswap", "supervise"])
    parser.add_argument("map", nargs="?")
    args = parser.parse_args()
    try:
        supervisor = Supervisor(args.profile)
        if args.action == "topic-status":
            print(json.dumps({"ok": True, "topic_port": supervisor.profile["topic_port"],
                              "status": topic_status(supervisor.profile["topic_port"])}))
            return 0
        if args.action == "supervise":
            supervisor.run()
            return 0
        if args.action == "start":
            if not (supervisor.control / "supervisor.lock").exists():
                flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
                subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--profile",
                                  str(supervisor.profile_path), "supervise"], cwd=supervisor.root,
                                 stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                 creationflags=flags, start_new_session=os.name != "nt")
            result = request(supervisor, "status", timeout=20)
        else:
            if not (supervisor.control / "supervisor.lock").exists():
                if args.action == "status":
                    print(json.dumps(supervisor.status()))
                    return 0
                raise ValueError("No owned supervisor; refusing to target another server")
            result = request(supervisor, args.action, args.map)
        print(json.dumps(result))
        return 0 if result.get("ok") else 1
    except (ValueError, OSError, TimeoutError) as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        return 1


if __name__ == "__main__":
    sys.exit(main())

