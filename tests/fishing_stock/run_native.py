"""Bounded Linux fishing fixture; explicit opt-in only, never a Civ13 world."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
VERSION = "516.1688"
# Four compile/daemon pairs have 30-second command bounds. Leave 20 seconds
# inside the workflow's five-minute wall bound for cleanup/receipt finalization.
WORK_SECONDS = 280
MEMORY_BYTES = 512 * 1024**2
# Git defaults to a 1GiB pack mapping on 64-bit hosts, above our unchanged
# 512MiB process cap. Bound mappings/cache without relaxing any source checks.
GIT_MEMORY_ARGS = ("-c", "core.packedGitWindowSize=16m",
                   "-c", "core.packedGitLimit=64m",
                   "-c", "core.deltaBaseCacheLimit=16m")
PINS = {
    "tests/animal_registry/run_native.py": "da0c2d5c7bebf45f584a6b0c8b67d8ab0094798024cddf9fc899ad482ba19b1f",
    "tests/animal_registry/test_source_contract.py": "485e34f625efd0064e2ee9f35aac0075a5332d951a4b0828fa7592cd0385f08a",
    "scripts/byond_runtime.py": "43346f4a9f33af6b6d9cbe67f15d4f1843c400fa758d4cccba35002f0c30da4c",
    "scripts/byond_toolchain.py": "2fb8e2dbd3646124e366f17011fcbb7857ee47b913402d9a4c2a90dde0c957cc",
    "tools/byond/version.json": "662acc3d771988e91de44b7be6f648c256aee7b2173e42a64956b8aca3bad95d",
}


def digest_file(path):
    path = Path(path)
    if path.stat().st_size > 1024 * 1024:
        raise ValueError("source input exceeds bound: " + path.name)
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_shared():
    # Fail closed on lifecycle/provenance-helper drift. Imports define helpers;
    # they do not invoke the shared execute/main or acquisition functions.
    for path, expected in PINS.items():
        if digest_file(ROOT / path) != expected:
            raise ValueError("reviewed shared dependency changed: " + path)
    contract = load_module("fishing_animal_contract", ROOT / "tests/animal_registry/test_source_contract.py")
    missing = object()
    prior = sys.modules.get("test_source_contract", missing)
    try:
        sys.modules["test_source_contract"] = contract
        shared = load_module("fishing_animal_lifecycle", ROOT / "tests/animal_registry/run_native.py")
    finally:
        if prior is missing:
            sys.modules.pop("test_source_contract", None)
        else:
            sys.modules["test_source_contract"] = prior
    runtime = load_module("fishing_runtime_identity", ROOT / "scripts/byond_runtime.py")
    return shared, runtime


shared, runtime = load_shared()
prepare = load_module("fishing_preparation", HERE / "prepare_only.py")
TRACKED_INPUTS = (
    "tests/fishing_stock/run_native.py", "tests/fishing_stock/prepare_only.py",
    "tests/fishing_stock/adapters.dm", "tests/fishing_stock/fixture.dm",
    prepare.SOURCE_PATH, *PINS,
)


def remaining(deadline):
    value = deadline - time.monotonic()
    if value <= 0:
        raise RuntimeError("Aggregate fishing deadline expired")
    return value


def source_provenance(deadline):
    def git(*args):
        try:
            result = subprocess.run(["git", *GIT_MEMORY_ARGS, *args], cwd=ROOT, capture_output=True,
                                    timeout=min(5, remaining(deadline)), check=True)
        except subprocess.CalledProcessError as error:
            label = ("tracked source dirty" if args == ("diff", "--quiet", "HEAD")
                     and error.returncode == 1 else "Git provenance failure")
            detail = (error.stderr or b"").decode("utf-8", errors="replace")[-320:]
            # Keep exit1 distinct from infrastructure/pack failures such as128.
            # Bounded stderr survives both the job log and summary's500-char cap.
            raise RuntimeError(f"{label}; command={args[0]}; exit={error.returncode}; stderr={detail!r}") from error
        return result.stdout.decode("utf-8").strip()
    head = git("rev-parse", "--verify", "HEAD")
    if not re.fullmatch(r"[0-9a-f]{40}", head):
        raise ValueError("exact checked-out head required")
    git("diff", "--quiet", "HEAD")
    tracked = set(git("ls-files", "--error-unmatch", "--", *TRACKED_INPUTS).splitlines())
    if tracked != set(TRACKED_INPUTS):
        raise ValueError("native source inputs must be tracked at the exact head")
    return {"head": head, "tracked_dirty": False,
            "input_sha256": {path: digest_file(ROOT / path) for path in TRACKED_INPUTS}}


def identity(binary, archive, acquisition):
    requirement = runtime.pin.load()
    if requirement["version"] != VERSION:
        raise ValueError("reviewed engine profile changed")
    receipt = runtime.pin.read_download_receipt(acquisition, requirement, "linux")
    installed = runtime.verify_linux(binary, archive)
    if installed["version"] != VERSION:
        raise ValueError("installed engine version identity mismatch")
    return {"acquisition": receipt, "installed": installed}


def check_generated(work, files):
    for name, record in files.items():
        path = work / name
        if path.stat().st_size != record["bytes"] or digest_file(path) != record["sha256"]:
            raise ValueError("generated source changed: " + name)


def process_reaped(work, role):
    receipt = json.loads(shared.read_bounded(work / (role + "-process.json")))
    if receipt.get("reaped") is not True or receipt.get("returncode") != 0:
        raise ValueError("owned native process lacks successful reap receipt")


def verify_runtime(result, log, canonical, variant, hook_hash, head):
    errors = prepare.verify_receipt(result, variant, hook_hash, source_head=head)
    if errors:
        raise ValueError("; ".join(errors))
    if shared.DIAGNOSTIC.search(log) or "FISHING_RUNTIME_ERROR" in log:
        raise ValueError("native runtime diagnostic")
    if canonical.count("FISHING_DONE") != 1:
        raise ValueError("missing or duplicate native completion marker")
    pattern = r"World opened on network port ([0-9]+) for address ([^\s]+)\."
    bindings = re.findall(pattern, canonical)
    if (bindings != [(str(result["initial_port"]), "127.0.0.1")]
            or canonical.count("World no longer opened to new users.") != 1
            or not canonical.index("World opened on network port") < canonical.index("World no longer opened to new users.") < canonical.index("FISHING_DONE")):
        raise ValueError("require one loopback startup binding then closure")
    if any(address != "127.0.0.1" for _, address in re.findall(pattern, log)):
        raise ValueError("non-loopback listener evidence")


def execute(args, runner=None, provenance=None, verify_identity=None):
    runner = shared.run if runner is None else runner
    provenance = source_provenance if provenance is None else provenance
    verify_identity = identity if verify_identity is None else verify_identity
    injected = runner is not shared.run or provenance is not source_provenance or verify_identity is not identity
    if sys.platform != "linux" or args.expected_byond_version != VERSION:
        raise ValueError("explicit Linux BYOND 516.1688 profile required")
    deadline = time.monotonic() + WORK_SECONDS
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    summary = {"status": "incomplete", "version": VERSION, "injected_offline_test": injected,
               "native_attempted": False, "work_budget_seconds": WORK_SECONDS,
               "process_memory_bytes": MEMORY_BYTES, "modes": {}}
    try:
        before = provenance(deadline)
        summary["source_before"] = before
        manifest = prepare.prepare(ROOT / prepare.SOURCE_PATH, output / "prepared", VERSION, source_head=before["head"])
        summary["manifest"] = manifest
        binary = args.byond_bin.resolve(strict=True)
        archive = args.byond_archive.absolute()
        acquisition = args.acquisition_receipt.absolute()
        for variant in prepare.VARIANTS:
            row = manifest["variants"][variant]
            work = output / "prepared" / variant
            mode = summary["modes"][variant] = {"status": "prepared", "identity": {}}
            for role in ("compile", "daemon"):
                remaining(deadline)
                check_generated(work, row["files"])
                mode["identity"][role] = verify_identity(binary, archive, acquisition)
                remaining(deadline)
                command = ([str(binary / "DreamMaker"), "-max_errors", "0", "probe.dme"] if role == "compile" else
                           [str(binary / "DreamDaemon"), "probe.dmb", "-ip", "127.0.0.1", "-invisible", "-close", "-trusted", "-nowebclient", "-log", "runtime.log"])
                summary["native_attempted"] = not injected
                log = runner(command, work, role, deadline)
                process_reaped(work, role)
                check_generated(work, row["files"])
                if role == "compile":
                    runtime.pin.compiler_log(log, VERSION)
                    if shared.DIAGNOSTIC.search(log):
                        raise ValueError("compiler diagnostic")
                else:
                    canonical = shared.read_bounded(work / "runtime.log")
                    result = json.loads(shared.read_bounded(work / "result.json"), object_pairs_hook=runtime.pin.unique)
                    verify_runtime(result, log + "\n" + canonical, canonical, variant, row["hook_sha256"], before["head"])
                    mode["result"] = result
            mode["status"] = "passed"
            print(json.dumps({"variant": variant, "status": "passed", "cases": 24,
                              "expected_failed_cases": prepare.expected_failures(variant),
                              "injected_offline_test": injected}), flush=True)
        after = provenance(deadline)
        summary["source_after"] = after
        if after != before:
            raise ValueError("source changed during native fixture")
        remaining(deadline)
        summary["status"] = "passed"
    except Exception as error:
        summary["error"] = type(error).__name__ + ": " + str(error)[:500]
        for path in sorted(output.glob("prepared/*/*")):
            if path.name in ("compile.stdout", "compile.stderr", "daemon.stdout", "daemon.stderr", "runtime.log"):
                try:
                    print("RETAINED FISHING DIAGNOSTIC " + str(path.relative_to(output)), flush=True)
                    print(shared.read_bounded(path)[-16384:], flush=True)
                except (OSError, ValueError):
                    print("Output unavailable or reached its bound", flush=True)
        raise
    finally:
        (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", required=True)
    parser.add_argument("--byond-bin", type=Path, required=True)
    parser.add_argument("--byond-archive", type=Path, required=True)
    parser.add_argument("--acquisition-receipt", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-byond-version", choices=(VERSION,), required=True)
    args = parser.parse_args()
    if sys.platform != "linux":
        parser.error("Linux only")
    # Bound the Python coordinator too; the shared preexec applies the same
    # address-space bound plus CPU/file/core limits to every native child.
    import resource
    resource.setrlimit(resource.RLIMIT_AS, (MEMORY_BYTES, MEMORY_BYTES))
    execute(args)


if __name__ == "__main__":
    main()
