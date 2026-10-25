"""Stage only bounded, fixed-path source/diagnostic receipts. Never copy binaries."""
import argparse
import hashlib
import json
from pathlib import Path
from prepare import MODES

MAX_FILE = 8 * 1024**2
MAX_TOTAL = 64 * 1024**2
MAX_FILES = 256
TOP = ("preparation.json", "result.json", "runtime-binding.json", "mode-results.json")
SOURCES = ("binding.dm", "stubs.dm", "production-snow.dm", "production-process.dm",
           "production-hooks.dm", "probe.dm", "snow-native.dme", "mutation.diff")
COMPILE = ("compile-start.json", "compile-started.json", "compile-process.json", "compile.log")
RUN = ("daemon-start.json", "daemon-started.json", "daemon-process.json", "daemon.log", "runtime.log",
       "input-hashes.json", "output-hashes.json", "snow-native-ready.json", "snow-native-go.json",
       "snow-native-result.json", "listener-census.json")
ACQUISITION = ("source-identity.txt", "controller-identity.txt", "controller-paths.txt",
               "download.json", "archive.sha256")
TOOLING = ("run.py", "prepare.py", "oracle.py", "owned_process_1688.py", "collect_evidence.py",
           "source-bindings.json", "expected-assertions.json", "test_proposal.py",
           "test_review_controls.py", "test_workflow.py", "README.md", "fixtures/stubs.dm", "fixtures/probe.dm")


def collect(evidence, acquisition, tooling, output):
    output = output.absolute()
    if ".." in output.parts:
        raise ValueError("Retained output path must not contain parent traversal")
    if output.is_symlink() or any(p.is_symlink() for p in output.parents):
        raise ValueError("Retained output path contains a symlink")
    if output.exists():
        raise ValueError("Fresh retained directory required")
    output.mkdir(parents=True)
    candidates = [(evidence / name, "receipts/" + name) for name in TOP]
    candidates += [(acquisition / name, "acquisition/" + name) for name in ACQUISITION]
    candidates += [(tooling / name, "tooling/" + name) for name in TOOLING]
    candidates.append((evidence / "inputs/tests/snowfall_ground/native_probe.dm", "reference/native_probe.dm"))
    for mode in MODES:
        root = evidence / "cases" / mode
        candidates.append((root / "compiled.json", "cases/" + mode + "/compiled.json"))
        candidates += [(root / "source" / name, "cases/" + mode + "/compile/" + name)
                       for name in (*SOURCES, *COMPILE)]
        candidates += [(root / "run" / name, "cases/" + mode + "/run/" + name) for name in RUN]
    kept, missing, rejected = [], [], []
    total = 0
    for source, relative in candidates:
        if not source.exists() and not source.is_symlink():
            missing.append(relative)
            continue
        try:
            if source.is_symlink() or any(p.is_symlink() for p in source.parents) or not source.is_file():
                raise ValueError("Not a regular non-symlink file")
            size = source.stat().st_size
            if size > MAX_FILE or total + size > MAX_TOTAL - 1024**2 or len(kept) >= MAX_FILES:
                raise ValueError("Retained evidence bound exceeded")
            data = source.read_bytes()
            if len(data) != size:
                raise ValueError("File changed during staging")
            target = output / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            total += size
            kept.append({"path": relative, "bytes": size, "sha256": hashlib.sha256(data).hexdigest()})
        except (OSError, ValueError) as error:
            rejected.append({"path": relative, "reason": str(error)[:200]})
    report = {"status": "bounded-evidence-staged" if not rejected else "partial-evidence-rejected",
              "bytes": total, "files": kept, "missing": missing, "rejected": rejected,
              "native_execution_performed_by_collector": False,
              "limits": {"file": MAX_FILE, "total": MAX_TOTAL, "files": MAX_FILES}}
    (output / "retention.json").write_text(json.dumps(report, indent=2) + "\n")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("evidence", "acquisition", "tooling", "output"):
        parser.add_argument("--" + name, required=True, type=Path)
    args = parser.parse_args()
    report = collect(args.evidence, args.acquisition, args.tooling, args.output)
    if report["rejected"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
