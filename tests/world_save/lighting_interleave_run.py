"""Two-process synthetic lighting interleaving probe. Native run needs approval."""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tests/movement_save_chunks"))
import benchmark
import human_spatial_run as common
import human_scale_run as scale
import lighting_interleave_adapter as adapter

spec = importlib.util.spec_from_file_location("fixture_stage", ROOT / "tests/human_subtile/run.py")
stage_helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage_helper)

INPUTS = tuple(sorted((
    "code/modules/persistence/loading.dm", "tests/world_save/lighting_interleave_probe.dm",
    "tests/world_save/lighting_interleave_adapter.py", "tests/world_save/lighting_interleave_run.py",
    "tests/human_subtile/run.py", "tests/movement_save_chunks/benchmark.py",
    "tests/movement_save_chunks/human_spatial_run.py", "tests/movement_save_chunks/human_spatial_stage.py",
    "tests/movement_save_chunks/human_scale_run.py", "tests/movement_save_chunks/human_scale_stage.py",
    "tests/movement_save_chunks/diagnostic_cases.py", "tests/movement_save_chunks/datum_profile.py",
    "tests/movement_save_chunks/preflight_fixture.py", "scripts/byond_runtime.py",
    "scripts/byond_toolchain.py", "tools/byond/version.json")))
PHASE_SECONDS = 120
NATIVE_SECONDS = 360


def digest(data):
    return hashlib.sha256(data).hexdigest()


def scope():
    rows = {name: {"bytes": (ROOT / name).stat().st_size,
                   "sha256": digest((ROOT / name).read_bytes())} for name in INPUTS}
    body = {"schema": 1, "files": rows}
    return {"sha256": digest(json.dumps(body, sort_keys=True, separators=(",", ":")).encode()), **body}


def verify(head, expected_scope):
    common.require(re.fullmatch("[0-9a-f]{40}", head or "") is not None, "invalid reviewed head")
    common.require(re.fullmatch("[0-9a-f]{64}", expected_scope or "") is not None, "invalid reviewed scope")
    actual = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, timeout=15).decode().strip()
    common.require(actual == head, "reviewed head changed")
    approved = scope()
    common.require(approved["sha256"] == expected_scope, "reviewed fixture scope changed")
    return approved


def stage(output, head, expected_scope):
    approved = verify(head, expected_scope)
    manifest = stage_helper.prepare(ROOT, output, "human")
    common.require(manifest["head"] == head, "archived head changed")
    root = output / "stage"
    loader = root / "code/modules/persistence/loading.dm"
    raw = (ROOT / "code/modules/persistence/loading.dm").read_bytes()
    common.require(digest(raw) == approved["files"]["code/modules/persistence/loading.dm"]["sha256"], "loader overlay changed")
    candidate = raw.decode("utf-8")
    loader.write_text(adapter.instrument_loading(candidate), encoding="utf-8", newline="\n")
    probe = root / "tests/human_subtile/probe.dm"
    source = probe.read_text(encoding="utf-8")
    common.require(source.count("/world/New()") == 1, "startup seam changed")
    source = source.replace("/world/New()", "/world/proc/unused_interleave_startup()", 1)
    source = source.replace("\tturf = /turf/floor/plating/subtile_fixture",
                            "\tturf = /turf/floor/dirt", 1)
    probe.write_text(source, encoding="utf-8", newline="\n")
    fixture = root / "tests/human_subtile/lighting_interleave_probe.dm"
    fixture_source = (HERE / "lighting_interleave_probe.dm").read_bytes()
    common.require(digest(fixture_source) == approved["files"]["tests/world_save/lighting_interleave_probe.dm"]["sha256"], "fixture overlay changed")
    fixture.write_bytes(fixture_source)
    dme = output / manifest["dme"]
    with dme.open("a", encoding="utf-8", newline="\n") as f:
        f.write('\n#include "tests\\human_subtile\\lighting_interleave_probe.dm"\n')
    manifest["review_scope"] = approved
    manifest["stage_files"] = common.hashes(root, total_limit=2 * 1024**3, max_entries=12000)
    verify(head, expected_scope)
    (output / "lighting-interleave-manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest


def validate_receipt(row, head, phase):
    common.require(isinstance(row, dict) and row.get("head") == head and row.get("phase") == phase,
                   "wrong fixture identity")
    common.require((row.get("version"), row.get("build"), row.get("port")) == (516, 1688, 0),
                   "wrong engine or port")
    common.require(row.get("ok") == 1 and not row.get("error"), "fixture assertion failed")
    if phase == "writer":
        common.require(isinstance(row.get("generation"), str) and
                       re.fullmatch(r"round-v[12]:[0-9a-f]{32}", row["generation"]) is not None,
                       "invalid writer generation")
    else:
        common.require(row.get("cases") == list(adapter.CASES), "missing or reordered controls")


def run(output, head, expected_scope):
    common.require(sys.platform.startswith("linux"), "hosted Linux only")
    output = scale.checked_output(output, __import__("os").environ)
    scale.free_space(output.parent, scale.MIN_FREE_START)
    byond, archive = scale.pinned_runtime_paths(ROOT / "BYOND/byond/bin", ROOT / "BYOND/pinned.zip")
    approved = verify(head, expected_scope)
    manifest = stage(output, head, expected_scope)
    verify(head, expected_scope)
    source = output / "stage"
    source_bytes = sum(row["bytes"] for row in manifest["stage_files"].values())
    deadline = time.monotonic() + NATIVE_SECONDS
    report = {"head": head, "scope": expected_scope, "execution": "running", "phases": [],
              "plan": ["compile", "writer", "reader"],
              "limits": {"phase_seconds": PHASE_SECONDS, "native_sequence_seconds": NATIVE_SECONDS,
                         "address_space_per_process_bytes": 1024**3, "per_file_bytes": common.MAX_BYTES,
                         "sampled_runtime_bytes": common.MAX_BYTES, "sampled_log_bytes": common.MAX_LOG,
                         "sampled_leader_rss_bytes": 1024**3, "egress_sandbox": False}}
    receipt_path = output / "lighting-interleave-run.json"
    def record():
        receipt_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    def phase(command, cwd, name):
        verify(head, expected_scope)
        benchmark.verify_runtime(byond, archive)
        report["phases"].append({"phase": name, "status": "starting"})
        record()
        try:
            row = common.launch(command, cwd, name, PHASE_SECONDS, deadline, byond,
                                source_bytes if name == "compile" else 0)
            report["phases"][-1].update(status="exited", result=row)
        except Exception as exc:
            report["phases"][-1].update(status="failed", error=str(exc))
            record()
            raise
        record()
    def runtime(name):
        work = output / name
        work.mkdir()
        for filename, sha in report["artifacts"].items():
            common.require(common.digest(source / filename) == sha, "compiled artifact changed")
            shutil.copy2(source / filename, work / filename)
            common.require(common.digest(work / filename) == sha, "compiled artifact copy changed")
        shutil.copytree(source / "config", work / "config")
        (work / "map_saves").mkdir()
        (work / "map_backups").mkdir()
        return work
    def execute(work, name):
        phase([str(byond / "DreamDaemon"), "human_subtile.dmb", "-trusted", "-ip", "127.0.0.1",
               "-nowebclient", "-log", "runtime.log", "-params",
               "tested_commit=" + head + "&phase=" + name], work, name)
        row = common.json_read(work / "lighting-interleave-result.json")
        validate_receipt(row, head, name)
        return row
    try:
        record()
        common.require(common.hashes(source, total_limit=2 * 1024**3, max_entries=12000) == manifest["stage_files"], "stage changed")
        phase([str(byond / "DreamMaker"), "-max_errors", "0", "human_subtile.dme"], source, "compile")
        log = (source / "compile-stdout.log").read_text(errors="replace") + (source / "compile-stderr.log").read_text(errors="replace")
        common.require(benchmark.compile_ok({"status": "exited", "returncode": 0}, log, source / "human_subtile.dmb"), "compile failed")
        common.require(all((source / name).is_file() and common.digest(source / name) == row["sha256"]
                           for name, row in manifest["stage_files"].items()), "source changed during compile")
        report["artifacts"] = {p.name: common.digest(p) for p in
                               (source / "human_subtile.dmb", source / "human_subtile.rsc") if p.is_file()}
        common.require("human_subtile.dmb" in report["artifacts"], "missing DMB")
        writer = runtime("writer")
        saved = execute(writer, "writer")
        seed = common.hashes(writer / "map_saves")
        common.require((writer / "map_saves/save_complete.txt").read_text().strip() == saved["generation"], "writer marker mismatch")
        reader = runtime("reader")
        shutil.copytree(writer / "map_saves", reader / "map_saves", dirs_exist_ok=True)
        common.require(common.hashes(reader / "map_saves") == seed, "seed copy mismatch")
        restored = execute(reader, "reader")
        common.require(restored.get("generation") == saved["generation"], "reader generation mismatch")
        common.require(common.hashes(reader / "map_saves") == seed, "reader changed synthetic seed")
        common.require(common.hashes(writer / "map_saves") == seed, "writer seed changed")
        common.require(time.monotonic() < deadline, "sequence deadline")
        report["execution"] = "passed"
    except Exception as exc:
        report.update(execution="failed", error=str(exc))
        raise
    finally:
        started = {p["phase"] for p in report["phases"]}
        report["not_started"] = [p for p in report["plan"] if p not in started]
        record()
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--review-scope", action="store_true")
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--run-native", action="store_true")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--expected-head")
    parser.add_argument("--expected-scope-sha256")
    args = parser.parse_args()
    if args.review_scope:
        if args.prepare_only or args.run_native or args.output: parser.error("scope is read-only")
        print(json.dumps(scope(), indent=2))
    elif args.prepare_only != args.run_native and args.output and args.expected_head and args.expected_scope_sha256:
        if args.prepare_only:
            print(json.dumps(stage(args.output, args.expected_head, args.expected_scope_sha256)["review_scope"]))
        else:
            print(json.dumps(run(args.output, args.expected_head, args.expected_scope_sha256)))
    else:
        parser.error("choose prepare-only or run-native with output and exact reviewed head/scope")
