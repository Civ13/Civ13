#!/usr/bin/env python3
"""Offline Python/PHP Topic-boundary comparison; never opens a game connection."""
from __future__ import annotations

import json
from pathlib import Path
import struct
import sys
import time

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import civ13_agent as agent  # noqa: E402

SCHEMA = 1
DUMMY_AGENT = "offline-benchmark"
DUMMY_TOKEN = "not-a-real-token"


def corpus():
    """Synthetic integer/string fixtures, not saved player or server data."""
    cases = [
        {"name": "status", "action": "status", "args": {}, "response": {"ok": True, "data": {"revision": 1}}},
        {"name": "unicode-action", "action": "character_act", "args": {
            "character": "[0x1000001]", "do": "say", "text": "Hello ~ / + & = ? café 水 🌳",
        }, "response": {"ok": True, "data": {"revision": 2, "accepted": True}}},
        {"name": "queue", "action": "character_queue", "args": {
            "character": "[0x1000001]", "steps": [
                {"do": "move", "dir": "north"},
                {"do": "say", "text": "Benchmark only", "optional": None, "enabled": False},
            ]}, "response": {"ok": True, "data": {"revision": 3, "queued": 2}}},
    ]
    for count in (8, 128):
        cases.append({"name": f"observe-{count}", "action": "character_observe", "args": {
            "character": "[0x1000001]", "radius": 7, "since_rev": 40,
        }, "response": {"ok": True, "data": {"revision": 41, "nearby": [
            {"ref": f"[0x{0x2000000 + i:x}]", "name": "synthetic tree", "x": i % 15,
             "y": i // 15, "z": 1, "dense": True} for i in range(count)
        ]}}})
    # Serialize identical fixture replies once, outside measured loops.
    for case in cases:
        case["reply_json"] = json.dumps(case.pop("response"), ensure_ascii=False, separators=(",", ":"))
    return {"schema": SCHEMA, "actions": list(agent.ACTIONS), "cases": cases}


class MockTransport:
    def __init__(self, reply_json):
        body = b"\x06" + reply_json.encode("utf-8") + b"\x00"
        if len(body) > 0xFFFF:
            raise ValueError("fixture exceeds Topic response limit")
        self.reply = b"\x00\x83" + struct.pack(">H", len(body)) + body
        self.packet = b""

    def __call__(self, host, port, query, timeout):
        # No socket or environment/token lookup. Exercise production framing.
        self.packet = agent.encode_topic(query)
        return agent.decode_topic(self.reply)


def python_worker(payload):
    fixture = payload["corpus"]
    if fixture["schema"] != SCHEMA:
        raise ValueError("unsupported corpus schema")
    cases = fixture["cases"]
    transports = [MockTransport(c["reply_json"]) for c in cases]
    clients = [agent.AgentClient(DUMMY_AGENT, DUMMY_TOKEN, transport=t) for t in transports]

    def cycle():
        checksum = 0
        for case, client, transport in zip(cases, clients, transports):
            response = client.request(case["action"], case["args"])
            checksum += len(transport.packet) + response["data"]["revision"]
        return checksum

    if payload["mode"] == "parity":
        results = []
        for case, client, transport in zip(cases, clients, transports):
            response = client.request(case["action"], case["args"])
            results.append({"name": case["name"], "packet_hex": transport.packet.hex(), "response": response})
        return {"version": sys.version.split()[0], "results": results}
    for _ in range(payload["warmup"]):
        cycle()
    start = time.perf_counter_ns()
    checksum = 0
    for _ in range(payload["iterations"]):
        checksum += cycle()
    elapsed_ns = time.perf_counter_ns() - start
    return {"version": sys.version.split()[0], "elapsed_ns": elapsed_ns,
            "operations": payload["iterations"] * len(cases), "checksum": checksum}


def child_env():
    import os

    # Do not propagate API keys, agent tokens, startup hooks or user PHP config.
    env = {k: os.environ[k] for k in ("PATH", "SYSTEMROOT", "WINDIR", "TEMP", "TMP") if k in os.environ}
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    return env


def invoke(command, fixture, mode, iterations, warmup):
    import subprocess

    payload = json.dumps({"corpus": fixture, "mode": mode, "iterations": iterations, "warmup": warmup})
    start = time.perf_counter_ns()
    result = subprocess.run(command, input=payload, text=True, encoding="utf-8", capture_output=True,
                            check=True, timeout=180, env=child_env(), cwd=HERE)
    wall_ns = time.perf_counter_ns() - start
    return json.loads(result.stdout), wall_ns


def validate_parity(reference, candidate):
    # Gate timings on both exact outgoing bytes and parsed incoming values.
    canonical = lambda rows: json.dumps(rows, sort_keys=True, separators=(",", ":"), allow_nan=False)
    if canonical(reference["results"]) != canonical(candidate["results"]):
        raise ValueError("Python/PHP parity failed; no comparative timings are valid")


def summarize(samples):
    import math
    import statistics

    ordered = sorted(samples)
    return {"median": statistics.median(ordered), "p95": ordered[math.ceil(len(ordered) * .95) - 1],
            "min": ordered[0], "max": ordered[-1], "samples": samples}


def benchmark(php, samples=7, iterations=2000, warmup=100, python_only=False):
    import hashlib
    import platform
    import shutil

    if samples < 1 or iterations < 1 or warmup < 0:
        raise ValueError("samples and iterations must be positive; warmup must be nonnegative")
    fixture = corpus()
    commands = {"python": [sys.executable, "-I", "-B", str(Path(__file__).resolve()), "--worker"]}
    if not python_only:
        resolved = shutil.which(php)
        if not resolved:
            raise FileNotFoundError("PHP CLI missing; install it with operator approval or use --python-only. No PHP comparison was run.")
        commands["php"] = [resolved, "-n", str(HERE / "gateway_worker.php")]
    parity = {name: invoke(cmd, fixture, "parity", 1, 0)[0] for name, cmd in commands.items()}
    if "php" in parity:
        validate_parity(parity["python"], parity["php"])
    cold, warm = {n: [] for n in commands}, {n: [] for n in commands}
    checksums = {}
    for i in range(samples):
        order = list(commands) if i % 2 == 0 else list(reversed(commands))
        for name in order:
            # Cold includes interpreter startup, imports, fixture JSON and one cycle.
            _, wall = invoke(commands[name], fixture, "timing", 1, 0)
            cold[name].append(wall / 1_000_000)
            # Warm excludes all startup, input parsing and fixture construction.
            result, _ = invoke(commands[name], fixture, "timing", iterations, warmup)
            warm[name].append(result["elapsed_ns"] / result["operations"] / 1000)
            checksums.setdefault(name, set()).add(result["checksum"])
    if len(set.union(*checksums.values())) != 1:
        raise ValueError("inconsistent checksum; discard timings")
    encoded = json.dumps(fixture, ensure_ascii=True, sort_keys=True, separators=(",", ":")).encode()
    return {"schema": SCHEMA, "scope": "synthetic Topic client boundary; no network, DM or model inference",
            "corpus_sha256": hashlib.sha256(encoded).hexdigest(),
            "harness_source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "catalog_sha256": hashlib.sha256((HERE.parent / "catalog.py").read_bytes()).hexdigest(),
            "python_source_sha256": hashlib.sha256((HERE.parent / "civ13_agent.py").read_bytes()).hexdigest(),
            "php_source_sha256": hashlib.sha256((HERE / "gateway_worker.php").read_bytes()).hexdigest(),
            "platform": platform.platform(), "machine": platform.machine(),
            "versions": {n: p["version"] for n, p in parity.items()},
            "php_config": {"argv": "-n", "runtime": parity["php"]["runtime"]} if "php" in commands else None,
            "parity": "passed" if "php" in commands else "not run: Python only",
            "cases": [c["name"] for c in fixture["cases"]], "samples": samples,
            "iterations_per_sample": iterations, "warmup_cycles": warmup,
            "cold_process_ms": {n: summarize(s) for n, s in cold.items()},
            "warm_us_per_operation": {n: summarize(s) for n, s in warm.items()},
            "checksum": next(iter(checksums["python"]))}


def main():
    # Avoid measuring orchestrator imports as Python client cold-start cost.
    if sys.argv[1:] == ["--worker"]:
        print(json.dumps(python_worker(json.load(sys.stdin))))
        return
    import argparse
    import subprocess

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--php", default="php", help="PHP 8+ executable, not a shell command")
    parser.add_argument("--samples", type=int, default=7)
    parser.add_argument("--iterations", type=int, default=2000)
    parser.add_argument("--warmup", type=int, default=100)
    parser.add_argument("--python-only", action="store_true", help="explicitly omit PHP and make no comparison")
    args = parser.parse_args()
    try:
        result = benchmark(args.php, args.samples, args.iterations, args.warmup, args.python_only)
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        parser.exit(1, f"Benchmark failed: {exc}\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
