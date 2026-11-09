"""Minimal Python client for tools/savestream's helper pipe protocol.

Used by the offline tests and the benchmark tools; it speaks the same framed
protocol the 32-bit shim uses from inside Dream Daemon.
"""
from __future__ import annotations

import os
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tools" / "savestream" / "src"


def build_helper(out_dir: Path | None = None) -> Path:
    """Compile the 64-bit helper with the host C compiler."""
    cc = shutil.which(os.environ.get("CC", "cc")) or shutil.which("gcc")
    if not cc:
        # A Windows host usually has no C compiler; exercise the shipped
        # 64-bit helper at the repository root (the one Gaia runs) instead.
        shipped = ROOT / "savestream_helper.exe"
        if os.name == "nt" and shipped.is_file():
            return shipped
        raise RuntimeError("no C compiler available")
    out_dir = out_dir or Path(tempfile.mkdtemp(prefix="savestream-"))
    exe = out_dir / "savestream_helper"
    subprocess.run(
        [cc, "-O2", "-Wall", "-Wextra", "-std=c99", "-D_DEFAULT_SOURCE", "-D_GNU_SOURCE",
         "-o", str(exe), str(SRC / "savestream_helper.c"), "-lm"],
        check=True,
    )
    return exe


def tok_str(kind: str, text: str) -> str:
    return f"{kind}{len(text.encode())}:{text}"


def tok(value) -> str:
    """Encode a Python value as a wire token (None, float/int, str, list of pairs)."""
    if value is None:
        return "N"
    if isinstance(value, bool):
        return f"F{int(value)};"
    if isinstance(value, (int, float)):
        return f"F{float(value):.9g};"
    if isinstance(value, str):
        return tok_str("S", value)
    if isinstance(value, Path_):
        return tok_str("P", value.path)
    if isinstance(value, Raw):
        return tok_str("X", value.text)
    if isinstance(value, dict):
        return f"L{len(value)};" + "".join(tok(k) + "=" + tok(v) for k, v in value.items())
    if isinstance(value, list):
        return f"L{len(value)};" + "".join(tok(v) + "." for v in value)
    raise TypeError(value)


class Path_:
    def __init__(self, path: str):
        self.path = path


class Raw:
    def __init__(self, text: str):
        self.text = text


def record(path: str, value) -> str:
    return tok_str("W", path) + tok(value)


def subtree(base: str, text: str) -> str:
    body = f"{base}|{text}"
    return f"T{len(body.encode())}:{body}"


class Helper:
    def __init__(self, exe: Path, mode: str, file: Path):
        self.proc = subprocess.Popen([str(exe), mode, str(file)], stdin=subprocess.PIPE, stdout=subprocess.PIPE)

    def request(self, op: str, payload: str | bytes = b"") -> bytes:
        if isinstance(payload, str):
            payload = payload.encode()
        assert self.proc.stdin and self.proc.stdout
        self.proc.stdin.write(op.encode() + struct.pack("<I", len(payload)) + payload)
        self.proc.stdin.flush()
        head = self.proc.stdout.read(4)
        if len(head) < 4:
            raise RuntimeError("helper exited")
        (n,) = struct.unpack("<I", head)
        return self.proc.stdout.read(n)

    def close(self) -> None:
        try:
            self.request("Q")
        except (RuntimeError, BrokenPipeError):
            pass
        self.proc.wait(timeout=10)
        for stream in (self.proc.stdin, self.proc.stdout):
            if stream:
                stream.close()


def parse_token(data: bytes, i: int = 0):
    """Decode one wire token; returns (value, next_index). X tokens stay Raw."""
    t = chr(data[i])
    i += 1
    if t == "N":
        return None, i + 0
    if t == "F":
        j = data.index(b";", i)
        return float(data[i:j]), j + 1
    if t in "SPX":
        j = data.index(b":", i)
        n = int(data[i:j])
        text = data[j + 1:j + 1 + n].decode()
        value = text if t == "S" else Path_(text) if t == "P" else Raw(text)
        return value, j + 1 + n
    if t == "L":
        j = data.index(b";", i)
        n = int(data[i:j])
        i = j + 1
        items = []
        for _ in range(n):
            key, i = parse_token(data, i)
            marker = chr(data[i])
            i += 1
            if marker == "=":
                assoc, i = parse_token(data, i)
                items.append((key, assoc))
            else:
                items.append((key,))
        return items, i
    raise ValueError(f"bad token {t!r} at {i - 1}")
