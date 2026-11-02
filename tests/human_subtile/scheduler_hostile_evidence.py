"""Independent host validation for the bounded hostile-fallback receipt."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile
import time

HERE = Path(__file__).resolve().parent


def module(name):
    spec = importlib.util.spec_from_file_location(name, HERE / (name + ".py"))
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def require(value, reason):
    if not value:
        raise ValueError(reason)


def replace_once(text, old, new):
    require(text.count(old) == 1, "fixture reconstruction preimage")
    return text.replace(old, new, 1)


def validate(data, head, suite, git, git_env, deadline):
    contract = module("scheduler_hostile_contract")
    stage = module("scheduler_hostile_stage")
    binding = module("scheduler_hostile_binding")
    require(suite == "hostile05", "suite")
    binding.validate_source(git, git_env, head, deadline)

    def source(path):
        remaining = deadline - time.monotonic()
        require(remaining > 0, "evidence deadline")
        return subprocess.check_output(git + ["show", head + ":" + path], env=git_env, timeout=min(10, remaining))

    def record(raw):
        return {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}

    with tarfile.open(fileobj=io.BytesIO(data), mode="r:") as archive:
        entries = archive.getmembers()
        names = [e.name for e in entries]
        allowed = {"harness-status.json", "smoke-summary.json", "npc-smoke/cloud-manifest.json",
                   "npc-smoke/stage/compile-stdout.log", "npc-smoke/stage/compile-stderr.log"}
        allowed.update("npc-smoke/runtime/" + name for name in
            ("receipt.json", "result.txt", "port-closed.txt", "runtime.log", "daemon-stdout.log", "daemon-stderr.log"))
        allowed.update(f"abi/abi-{i}-{part}.log" for i in range(6) for part in ("stdout", "stderr"))
        require(len(allowed) == 23 and len(names) == len(set(names)) and set(names) == allowed
                and sum(e.size for e in entries) <= 16 * 1024**2
                and all(e.isfile() and e.size <= 4 * 1024**2
                        and not PurePosixPath(e.name).is_absolute()
                        and ".." not in PurePosixPath(e.name).parts for e in entries),
                "incomplete or unsafe hostile package")

        def read(name):
            return archive.extractfile(name).read()

        status = json.loads(read("harness-status.json"))
        summary = json.loads(read("smoke-summary.json"))
        require(status.get("head") == head and status.get("suite") == suite
                and status.get("phase") == "complete" and status.get("outcome") == "passed"
                and status.get("fixture_dme_only") is True and summary.get("head") == head
                and summary.get("suite") == suite and summary.get("tick") == 0.5
                and summary.get("fixture_dme_only") is True and summary.get("observation_complete") is True
                and summary.get("parity_established") is False and summary.get("scope") == stage.SCOPE
                and summary.get("limits") == {"compile_seconds": 120, "daemon_seconds": 90,
                    "setup_seconds": 60, "work_seconds": 490, "whole_seconds": 600}, "summary identity")
        manifest = json.loads(read("npc-smoke/cloud-manifest.json"))
        require(manifest.get("head") == head and manifest.get("hostile_scope") == stage.SCOPE
                and manifest.get("native_executed") is False, "staged identity")
        originals = {path: source(path) for path in binding.PINNED}
        excluded = ('civ13.dme', stage.PROBE, stage.base.ANIMAL, stage.base.AI, stage.base.CAT)
        expected = {path: raw for path, raw in originals.items() if path not in excluded}
        overlays = stage.base.instrument({path: originals[path].decode('utf-8')
                                        for path in (stage.base.ANIMAL, stage.base.AI, stage.base.CAT)})
        expected.update({path: text.encode('utf-8') for path, text in overlays.items()})
        expected[stage.PROBE] = stage.adapted_probe(originals[stage.PROBE].decode('utf-8')).encode('utf-8')
        dme = re.sub(r'^#include ".*\.dmm"\s*$', '', originals['civ13.dme'].decode('utf-8'), flags=re.M)
        dme += '\n#include "tests\\human_subtile\\mining.dm"\n#include "tests\\human_subtile\\probe.dm"\n'
        dme += '\n#include "tests\\human_subtile\\scheduler_core_draft.dm"\n'
        expected['human_subtile.dme'] = stage.adapted_dme(dme).encode('utf-8')
        for path, raw in expected.items():
            require(manifest.get("stage_files", {}).get(path) == record(raw),
                    "adapted source mismatch: " + path)
        for path in binding.PINNED:
            require(manifest.get("original_git_files", {}).get(path) == record(source(path)),
                    "original source mismatch: " + path)

        phase = summary.get("compile", {})
        require(phase.get("returncode") == 0 and phase.get("timed_out") is False
                and phase.get("oversized_log") is False and phase.get("deadline") == 120, "compile phase")
        npc = module("run-npc")
        npc.current.legacy.validate_compile((read("npc-smoke/stage/compile-stdout.log")
            + read("npc-smoke/stage/compile-stderr.log")).decode(errors="replace"), "human_subtile.dmb")
        states, artifacts = summary.get("resource_states"), summary.get("artifacts")
        require(isinstance(states, dict) and set(states) == {"hostile"}
                and status.get("runtime_resources") == states and status.get("resource_copies_independent") is True
                and isinstance(artifacts, dict)
                and isinstance(artifacts.get("human_subtile.rsc"), dict), "resource states")
        state = states["hostile"]
        before, after = state.get("before", {}), state.get("after", {})
        require(before == artifacts["human_subtile.rsc"] and state.get("integrity_verified") is True
                and "daemon_error" not in state and "integrity_error" not in state
                and type(state.get("changed")) is bool and state["changed"] == (before != after), "resource integrity")
        for value in (before, after):
            require(type(value.get("bytes")) is int and 0 < value["bytes"] <= 1024**3
                    and value.get("mode") == 0o600 and re.fullmatch("[0-9a-f]{64}", value.get("sha256") or ""),
                    "resource identity")
        phase = summary.get("result", {}).get("daemon", {})
        require(phase.get("returncode") == 0 and phase.get("timed_out") is False
                and phase.get("oversized_log") is False and phase.get("deadline") == 90, "daemon phase")
        prefix = "npc-smoke/runtime/"
        require(read(prefix + "result.txt") == b"PASS\n" and read(prefix + "port-closed.txt") == b"closed\n",
                "daemon result")
        receipt = read(prefix + "receipt.json")
        require(summary["result"].get("receipt_sha256") == hashlib.sha256(receipt).hexdigest(), "receipt hash")
        require(contract.validate_receipt(json.loads(receipt), head) == summary.get("observation"), "observation mismatch")
        timings = [summary["compile"].get("seconds"), phase.get("seconds")]
        require(all(contract.number(v) and 0 <= v <= limit for v, limit in zip(timings, (120, 90)))
                and contract.number(summary.get("child_elapsed"))
                and abs(sum(timings) - summary["child_elapsed"]) < 0.000001
                and contract.number(summary.get("comparison_elapsed"))
                and contract.number(summary.get("setup_seconds"))
                and abs(summary["comparison_elapsed"] - summary["child_elapsed"] - summary["setup_seconds"]) < 0.000001
                and 0 <= summary["setup_seconds"] <= 60, "elapsed budget")