#!/usr/bin/env python3
"""Validate existing game evidence without launching a game or contacting services."""

import argparse
import csv
from datetime import datetime
import hashlib
import json
import math
from pathlib import Path
import re
import sys
from urllib.parse import urlparse


SCENARIO_CHECKS = {
    "season-memory": {"repeated-seasons", "memory-samples"},
    "save-roundtrip": {"roundtrip", "nested-values", "edge-turfs",
                       "missing-turf-rejected", "world-unchanged-after-rejection"},
    "gameplay": {"client-interaction"},
    "other": set(),
}
KINDS = {"log", "build-log", "screenshot", "video", "metrics", "save", "patch", "other"}
SCOPES = {"synthetic", "isolated-fixture", "isolated-game", "production-observation"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def nonempty(value):
    return isinstance(value, str) and bool(value.strip())


def text_list(value):
    return isinstance(value, list) and bool(value) and all(nonempty(item) for item in value)


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def contained_file(root, relative):
    require(nonempty(relative), "Artifact path must be a nonempty relative path")
    path = Path(relative)
    require(not path.is_absolute() and not path.drive, "Artifact path must be relative")
    resolved = (root / path).resolve()
    require(resolved.is_relative_to(root), "Artifact path escapes the evidence directory")
    require(resolved.is_file() and resolved.stat().st_size > 0,
            f"Artifact is missing or empty: {relative}")
    return resolved


def utc_timestamp(value):
    require(nonempty(value), "Run timestamps must be ISO 8601 UTC strings")
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    require(parsed.utcoffset() is not None and parsed.utcoffset().total_seconds() == 0,
            "Run timestamps must include UTC timezone")
    return parsed


def memory_summary(path, metadata, duration_seconds):
    """Summarize raw observations; deliberately make no leak/OOM verdict."""
    for key in ("metric", "process_identity", "settling_rule"):
        require(nonempty(metadata.get(key)), f"Memory evidence needs {key}")
    require(metadata["metric"] in {"private_bytes", "rss_bytes", "working_set_bytes"},
            "Use one explicit byte-based memory metric")
    with path.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        require(set(reader.fieldnames or []) == {"elapsed_seconds", "cycle", "phase", "bytes"},
                "Memory CSV columns must be elapsed_seconds,cycle,phase,bytes")
        rows = list(reader)
    require(bool(rows), "Memory CSV has no samples")
    cycles = {}
    previous_time = -1.0
    previous_cycle = 0
    phase_order = {"baseline": 0, "peak": 1, "settled": 2}
    for row in rows:
        require(None not in row and all(value is not None for value in row.values()),
                "Memory CSV rows must contain exactly four fields")
        elapsed, value = float(row["elapsed_seconds"]), float(row["bytes"])
        cycle, phase = int(row["cycle"]), row["phase"]
        require(math.isfinite(elapsed) and math.isfinite(value) and elapsed >= 0 and value >= 0,
                "Memory samples must be finite and nonnegative")
        require(value.is_integer(), "Memory bytes must be integers")
        require(elapsed > previous_time, "Memory sample times must strictly increase")
        require(elapsed <= duration_seconds, "Memory sample exceeds the declared run duration")
        require(cycle >= 1 and cycle >= previous_cycle, "Memory cycles must increase from 1")
        require(phase in phase_order, "Unknown memory phase")
        samples = cycles.setdefault(cycle, [])
        require(not samples or phase_order[phase] >= phase_order[samples[-1][0]],
                "Each cycle must progress baseline, peak, settled")
        samples.append((phase, elapsed, int(value)))
        previous_time, previous_cycle = elapsed, cycle
    require(list(cycles) == list(range(1, len(cycles) + 1)), "Memory cycle numbers must be contiguous")
    require(len(cycles) >= 2, "Repeated-season evidence needs at least two complete cycles")
    output = []
    for cycle, samples in cycles.items():
        require({item[0] for item in samples} == set(phase_order),
                "Every memory cycle needs baseline, peak, and settled samples")
        baseline = next(item[2] for item in samples if item[0] == "baseline")
        settled = samples[-1][2]
        output.append({"cycle": cycle, "baseline_bytes": baseline,
                       "observed_peak_bytes": max(item[2] for item in samples),
                       "settled_bytes": settled, "settled_delta_bytes": settled - baseline,
                       "settled_elapsed_seconds": samples[-1][1]})
    return {"metric": metadata["metric"], "process_identity": metadata["process_identity"],
            "settling_rule": metadata["settling_rule"], "cycles": output,
            "first_to_last_settled_delta_bytes": output[-1]["settled_bytes"] - output[0]["settled_bytes"],
            "interpretation": "Observations only; allocator retention, workload, sampling gaps, and run duration require review. No leak or OOM verdict."}


def validate(manifest_path, expected_commit):
    manifest_path = Path(manifest_path).resolve()
    data = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    require(isinstance(data, dict), "Manifest must be an object")
    require(data.get("schema_version") == 1, "Unsupported schema_version")
    require(re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", expected_commit or ""),
            "expected-commit must be a full lowercase Git commit hash")
    require(data.get("commit") == expected_commit, "Evidence commit differs from expected commit")
    require(nonempty(data.get("game")), "Game name is required")
    runtime = data.get("runtime", {})
    require(isinstance(runtime, dict), "runtime must be an object")
    for key in ("name", "version", "platform"):
        require(nonempty(runtime.get(key)), f"Runtime {key} is required")
    map_info = data.get("map", {})
    require(isinstance(map_info, dict), "map must be an object")
    require(nonempty(map_info.get("name")) and nonempty(map_info.get("source")),
            "Map name and source path or fixture identifier are required")
    dimensions = map_info.get("dimensions")
    grid_dimensions = isinstance(dimensions, list) and len(dimensions) == 3 and all(
        type(size) is int and size > 0 for size in dimensions)
    scene_without_grid = dimensions is None and nonempty(map_info.get("dimensions_reason")) and data["game"].casefold() != "civ13"
    require(grid_dimensions or scene_without_grid,
            "Map dimensions must be three positive integers, or a non-grid scene needs dimensions_reason")
    scenario = data.get("scenario")
    require(isinstance(scenario, str) and scenario in SCENARIO_CHECKS, "Unknown scenario")
    run = data.get("run", {})
    require(isinstance(run, dict), "run must be an object")
    require(isinstance(run.get("scope"), str) and run["scope"] in SCOPES, "Unknown run scope")
    require(type(run.get("dirty")) is bool, "Record run.dirty explicitly")
    started, finished = utc_timestamp(run.get("started_utc")), utc_timestamp(run.get("finished_utc"))
    require(finished >= started, "Run finish precedes start")
    require(text_list(data.get("steps")), "Record concrete reproduction steps")
    require(text_list(data.get("limitations")), "Record acceptance limits explicitly")
    media = data.get("media", {})
    require(isinstance(media, dict) and type(media.get("screenshot_required")) is bool and
            type(media.get("video_required")) is bool and nonempty(media.get("reason")),
            "Media requirements and their reason must be explicit")
    require(scenario != "gameplay" or media["screenshot_required"],
            "Gameplay evidence requires a real screenshot")
    artifacts = data.get("artifacts")
    require(isinstance(artifacts, list), "artifacts must be an array")
    indexed, observed = {}, []
    for item in artifacts:
        require(isinstance(item, dict), "Each artifact must be an object")
        identity, kind = item.get("id"), item.get("kind")
        require(nonempty(identity) and identity not in indexed, "Artifact IDs must be unique strings")
        require(isinstance(kind, str) and kind in KINDS, "Unknown artifact kind")
        require(("path" in item) != ("url" in item), "Artifact needs exactly one path or URL")
        record = dict(item)
        if "path" in item:
            path = contained_file(manifest_path.parent, item["path"])
            digest = sha256(path)
            require("sha256" not in item or item["sha256"] == digest, f"Artifact checksum mismatch: {identity}")
            record.update(sha256=digest, size_bytes=path.stat().st_size, availability="local-file-verified")
        else:
            require(nonempty(item["url"]), "Artifact URL must be a string")
            parsed = urlparse(item["url"])
            require(parsed.scheme == "https" and bool(parsed.netloc) and not parsed.username and not parsed.password,
                    "Artifact URL must use HTTPS without credentials")
            record["availability"] = "external-url-not-verified"
        indexed[identity] = record
        observed.append(record)
    kinds = {item["kind"] for item in observed}
    require(not run["dirty"] or "patch" in kinds, "Dirty test runs need a patch artifact")
    checks = data.get("checks")
    require(isinstance(checks, list) and bool(checks), "Record checks and their results")
    check_ids = set()
    for check in checks:
        require(isinstance(check, dict), "Each check must be an object")
        identity, result = check.get("id"), check.get("result")
        require(nonempty(identity) and identity not in check_ids, "Check IDs must be unique strings")
        require(result in ("passed", "failed", "not-run"), "Unknown check result")
        require(nonempty(check.get("description")), "Each check needs an observable criterion")
        require(nonempty(check.get("notes")), "Each check needs observed results or a skip reason")
        evidence = check.get("evidence")
        require(isinstance(evidence, list) and all(isinstance(ref, str) and ref in indexed for ref in evidence),
                "Checks must reference known artifact IDs")
        require(result == "not-run" or bool(evidence), "Executed checks need evidence")
        require(identity not in {"screenshot", "video"} or result != "not-run" or not evidence,
                "Skipped media checks need an empty evidence list")
        check_ids.add(identity)
    require(SCENARIO_CHECKS[scenario] <= check_ids, "Scenario checks are missing; mark unavailable checks not-run")
    for kind, required in (("screenshot", media["screenshot_required"]), ("video", media["video_required"])):
        require(not required or kind in kinds or any(check["id"] == kind and check["result"] == "not-run" for check in checks),
                f"Required {kind} evidence is missing")
    memory = None
    if "memory" in data:
        metadata = data["memory"]
        require(isinstance(metadata, dict), "memory must be an object")
        identity = metadata.get("artifact")
        require(isinstance(identity, str) and identity in indexed and indexed[identity]["kind"] == "metrics" and
                "path" in indexed[identity], "Memory samples require a local metrics artifact")
        memory = memory_summary(contained_file(manifest_path.parent, indexed[identity]["path"]),
                                metadata, (finished - started).total_seconds())
    require(not any(check["id"] == "memory-samples" and check["result"] == "passed" for check in checks) or memory,
            "A passed memory-samples check requires parsed memory observations")
    return {"schema_version": 1, "bundle_valid": True,
            "meaning": "Metadata, local file checksums, references, and supplied sample structure were checked. Game acceptance and external URL availability were not independently verified.",
            "manifest_sha256": sha256(manifest_path), "commit": data["commit"], "game": data["game"],
            "runtime": runtime, "map": map_info, "scenario": scenario, "run": run,
            "steps": data["steps"], "media": media, "checks": checks, "artifacts": observed,
            "memory_observations": memory, "limitations": data["limitations"],
            "missing_required_media": [kind for kind in ("screenshot", "video") if media[f"{kind}_required"] and kind not in kinds]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--expected-commit", required=True)
    parser.add_argument("--report", type=Path, help="Write a new JSON report; never overwrite an existing file")
    args = parser.parse_args()
    try:
        result = validate(args.manifest, args.expected_commit)
        output = json.dumps(result, indent=2, sort_keys=True, allow_nan=False) + "\n"
        if args.report:
            with args.report.open("x", encoding="utf-8", newline="\n") as stream:
                stream.write(output)
        else:
            print(output, end="")
    except (OSError, ValueError, TypeError, KeyError, csv.Error) as error:
        print(f"Evidence invalid: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
