"""Prepare by default; explicit reviewed Linux execution only. No game or real saves."""
import argparse
import json
import os
import re
import shutil
import stat
import sys
import time
import zipfile
from pathlib import Path

from prepare import HEAD, TREE, VERSION, MODES, build_fixture, verify_fixture, digest, dump
from owned_process_1688 import BoundedProcessError, run_bounded, proc_identity
from oracle import verify_result, verify_auxiliary, FATAL

ARCHIVE = "16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9"
OWNED_CONTROLLER = "b247b308ff088b832417466218b1b96f11be2f1a622e710749e92c77b451b1ea"
COMPILE = {"cpu": 150, "as": 2 * 1024**3, "file": 128 * 1024**2, "fds": 256}
RUNTIME = {"cpu": 20, "as": 1024**3, "file": 16 * 1024**2, "fds": 128}
TOTAL_WALL = 600
LOG_LIMIT = 4 * 1024**2
CONTROLLER_FILES = ("run.py", "prepare.py", "oracle.py", "owned_process_1688.py",
                    "source-bindings.json", "expected-assertions.json",
                    "fixtures/stubs.dm", "fixtures/probe.dm")
MEMBERS = ("DreamMaker", "DreamDaemon", "libbyond.so", "libext.so")
RUNTIME_FILES = {"snow-native.dmb", "snow-native.rsc", "daemon-start.json", "daemon-started.json",
                 "daemon-process.json", "daemon.log", "runtime.log", "input-hashes.json",
                 "snow-native-ready.json", "snow-native-go.json", "snow-native-result.json",
                 "listener-census.json", "output-hashes.json"}
COMPILE_FILES = {"binding.dm", "stubs.dm", "production-snow.dm", "production-process.dm",
                 "production-hooks.dm", "probe.dm", "icons/turf/snow.dmi", "snow-native.dme",
                 "mutation.diff", "snow-native.dmb", "snow-native.rsc", "compile-start.json",
                 "compile-started.json", "compile-process.json", "compile.log"}


def read(path, limit=LOG_LIMIT):
    if path.is_symlink() or any(p.is_symlink() for p in path.parents) or not path.is_file():
        raise ValueError("Missing or linked evidence: " + str(path))
    if path.stat().st_size > limit:
        raise ValueError("Evidence size exceeds bound: " + str(path))
    return path.read_text(encoding="utf-8-sig", errors="strict")


def binaries(directory, archive):
    if archive.is_symlink() or not archive.is_file() or archive.stat().st_size > 64 * 1024**2:
        raise ValueError("Invalid BYOND archive")
    if digest(archive.read_bytes()) != ARCHIVE:
        raise ValueError("Unreviewed BYOND archive bytes")
    rows = {}
    with zipfile.ZipFile(archive) as content:
        if len(content.namelist()) != len(set(content.namelist())):
            raise ValueError("Duplicate archive members")
        for name in MEMBERS:
            item = content.getinfo("byond/bin/" + name)
            if item.file_size > 64 * 1024**2:
                raise ValueError("Unexpected runtime member size")
            expected = digest(content.read(item))
            path = directory / name
            if path.is_symlink() or any(p.is_symlink() for p in path.parents) or not path.is_file():
                raise ValueError("Missing or linked runtime member")
            if path.stat().st_size != item.file_size:
                raise ValueError("Runtime member size differs: " + name)
            with path.open("rb") as stream:
                data = stream.read(item.file_size + 1)
            if len(data) != item.file_size or digest(data) != expected:
                raise ValueError("Runtime member bytes differ: " + name)
            rows[name] = expected
    return rows


def controller_hashes():
    root = Path(__file__).resolve().parent
    rows = {}
    for name in CONTROLLER_FILES:
        path = root / name
        if path.is_symlink() or any(p.is_symlink() for p in path.parents):
            raise ValueError("Linked controller source")
        rows[name] = digest(path.read_bytes())
    if rows["owned_process_1688.py"] != OWNED_CONTROLLER:
        raise ValueError("Reviewed retained-leader controller changed")
    return rows


PRIVATE_HOME = {"files": 16, "directories": 16, "depth": 4,
                "file_bytes": 256 * 1024, "total_bytes": 1024**2}
DIRECTORY_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW


def directory_fd(path):
    """Anchor a task path without following any symlink component."""
    path = path.absolute()
    if ".." in path.parts:
        raise ValueError("Inventory path contains parent traversal")
    fd = os.open(path.anchor, DIRECTORY_FLAGS)
    try:
        for part in path.parts[1:]:
            child = os.open(part, DIRECTORY_FLAGS, dir_fd=fd)
            os.close(fd)
            fd = child
        return fd
    except BaseException:
        os.close(fd)
        raise


def child_directory_fd(parent, name, observed):
    fd = os.open(name, DIRECTORY_FLAGS, dir_fd=parent)
    try:
        current = os.fstat(fd)
        if (not stat.S_ISDIR(current.st_mode) or
                (current.st_dev, current.st_ino) != (observed.st_dev, observed.st_ino)):
            raise ValueError("Inventory directory identity changed")
        return fd
    except BaseException:
        os.close(fd)
        raise


def private_home_inventory(work):
    """Inspect metadata only in fresh task HOME; never follow links or retain data."""
    totals = {"files": 0, "bytes": 0, "directories": 0}

    def visit(fd, depth):
        with os.scandir(fd) as entries:
            for entry in entries:
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,80}", entry.name):
                    raise ValueError("Unexpected private HOME entry name")
                if depth == 0 and entry.name != ".byond":
                    raise ValueError("Only .byond is permitted under private HOME")
                if depth + 1 > PRIVATE_HOME["depth"]:
                    raise ValueError("Private HOME depth exceeds bound")
                info = os.stat(entry.name, dir_fd=fd, follow_symlinks=False)
                if stat.S_ISDIR(info.st_mode):
                    totals["directories"] += 1
                    if totals["directories"] > PRIVATE_HOME["directories"]:
                        raise ValueError("Private HOME directory count exceeds bound")
                    child = child_directory_fd(fd, entry.name, info)
                    try:
                        visit(child, depth + 1)
                    finally:
                        os.close(child)
                elif stat.S_ISREG(info.st_mode) and depth > 0:
                    if info.st_nlink != 1:
                        raise ValueError("Private HOME hard links are not permitted")
                    totals["files"] += 1
                    totals["bytes"] += info.st_size
                    if (totals["files"] > PRIVATE_HOME["files"] or
                            info.st_size > PRIVATE_HOME["file_bytes"] or
                            totals["bytes"] > PRIVATE_HOME["total_bytes"]):
                        raise ValueError("Private HOME file count or size exceeds bound")
                else:
                    raise ValueError("Private HOME contains a link or non-regular entry")
    try:
        root = directory_fd(work)
        try:
            try:
                info = os.stat("home", dir_fd=root, follow_symlinks=False)
            except FileNotFoundError:
                return totals
            if not stat.S_ISDIR(info.st_mode):
                raise ValueError("Private HOME must be a real task directory")
            home = child_directory_fd(root, "home", info)
            try:
                visit(home, 0)
            finally:
                os.close(home)
        finally:
            os.close(root)
    except OSError as error:
        raise ValueError("Private HOME metadata inspection failed") from error
    return totals


def outside_home_entries(work):
    """Stream no-follow metadata; reject each directory before traversal resumes."""
    def visit(fd, prefix):
        with os.scandir(fd) as entries:
            for entry in entries:
                relative = prefix + entry.name
                info = os.stat(entry.name, dir_fd=fd, follow_symlinks=False)
                yield relative, info
                if stat.S_ISDIR(info.st_mode) and relative != "home":
                    child = child_directory_fd(fd, entry.name, info)
                    try:
                        yield from visit(child, relative + "/")
                    finally:
                        os.close(child)
    try:
        root = directory_fd(work)
        try:
            yield from visit(root, "")
        finally:
            os.close(root)
    except OSError as error:
        raise ValueError("Output metadata inspection failed") from error


def runtime_inventory(work):
    private = private_home_inventory(work)
    count = 0
    total = private["bytes"]
    for relative, info in outside_home_entries(work):
        if stat.S_ISLNK(info.st_mode):
            raise ValueError("Unexpected fixture output symlink")
        if stat.S_ISDIR(info.st_mode):
            if relative not in ("home", "tmp"):
                raise ValueError("Unexpected runtime directory: " + relative)
            continue
        if not stat.S_ISREG(info.st_mode) or relative not in RUNTIME_FILES:
            raise ValueError("Unexpected runtime output: " + relative)
        size = info.st_size
        if relative.endswith((".log", ".json")) and size > LOG_LIMIT:
            raise ValueError("Runtime output exceeds individual cap")
        count += 1
        total += size
        if count > 32 or total > 64 * 1024**2:
            raise ValueError("Aggregate runtime output cap exceeded")


def compile_inventory(work):
    private = private_home_inventory(work)
    total = private["bytes"]
    count = 0
    for relative, info in outside_home_entries(work):
        if stat.S_ISLNK(info.st_mode):
            raise ValueError("Unexpected compiler output symlink")
        if stat.S_ISDIR(info.st_mode):
            if relative not in ("icons", "icons/turf", "home", "tmp"):
                raise ValueError("Unexpected compiler directory: " + relative)
            continue
        if not stat.S_ISREG(info.st_mode) or relative not in COMPILE_FILES:
            raise ValueError("Unexpected compiler output: " + relative)
        size = info.st_size
        cap = 32 * 1024**2 if relative.endswith((".dmb", ".rsc")) else LOG_LIMIT
        if size > cap:
            raise ValueError("Compiler file exceeds individual cap")
        total += size
        count += 1
        if count > len(COMPILE_FILES) or total > 80 * 1024**2:
            raise ValueError("Aggregate compiler output cap exceeded")


def readiness(mode):
    return {"head": HEAD, "tree": TREE, "version": VERSION, "mode": mode, "port": 0}


def listener_ack(work, mode):
    state = {"acknowledged": False}

    def sample(pid, identity, observed):
        runtime_inventory(work)
        if state["acknowledged"]:
            return
        ready = work / "snow-native-ready.json"
        if not ready.exists():
            return
        ack = work / "snow-native-go.json"
        if ack.exists() or ack.is_symlink():
            raise ValueError("Preexisting listener acknowledgement")
        value = json.loads(read(ready, 16384))
        if value != readiness(mode) or type(value.get("port")) is not int:
            raise ValueError("Unbound closure readiness")
        current = proc_identity(pid)
        if current is None or current["start_ticks"] != identity["start_ticks"] or current["state"] in ("Z", "X"):
            raise ValueError("Leader not alive at closure census")
        sockets = set()
        seen = []
        for child, old in observed.items():
            current = proc_identity(child)
            if current is None or current["start_ticks"] != old["start_ticks"]:
                raise ValueError("Owned identity disappeared during census")
            if current["state"] in ("Z", "X"):
                continue
            for fd in Path(f"/proc/{child}/fd").iterdir():
                try:
                    link = os.readlink(fd)
                except FileNotFoundError as error:
                    raise ValueError("FD inventory raced during census") from error
                if link.startswith("socket:["):
                    sockets.add(link[8:-1])
            seen.append(current)
        listeners = []
        for table in ("tcp", "tcp6"):
            for line in Path(f"/proc/{pid}/net/{table}").read_text().splitlines()[1:]:
                fields = line.split()
                if fields[3] == "0A" and fields[9] in sockets:
                    listeners.append({"table": table, "local": fields[1], "inode": fields[9]})
        if listeners:
            raise ValueError("Owned listening socket at closure census")
        current = proc_identity(pid)
        if current is None or current["start_ticks"] != identity["start_ticks"] or current["state"] in ("Z", "X"):
            raise ValueError("Leader exited during closure census")
        dump(work / "listener-census.json", {"leader": identity, "owned": seen, "listeners": [], "port": 0})
        dump(ack, dict(value, ack="owned-listener-census-v1"))
        state["acknowledged"] = True

    return sample, state


def run_native(output, receipt, binary, archive, summary):
    if receipt.get("source_authentication") != "clean-git":
        raise ValueError("Native execution requires independently verified clean Git source")
    deadline = time.monotonic() + TOTAL_WALL
    runtime_hashes = binaries(binary, archive)
    expected_controller = controller_hashes()
    if receipt.get("controller_sha256") != expected_controller:
        raise ValueError("Controller differs from preparation receipt")
    dump(output / "runtime-binding.json", runtime_hashes)
    results = {}

    def execute(command, work, family, mode, profile, wall, callback=None):
        phase = {"role": family, "mode": mode, "attempted": True, "started": False,
                 "terminated": False, "completed": False}
        summary[family + "_attempted"] = True
        summary["phases"].append(phase)
        dump(output / "result.json", summary)
        # Reserve eight seconds for bounded shutdown/drain/group confirmation.
        remaining = min(wall, deadline - time.monotonic() - 8)
        if remaining <= 0:
            raise ValueError("Aggregate ten-minute deadline exhausted")
        verify_fixture(output, receipt)
        if controller_hashes() != expected_controller or binaries(binary, archive) != runtime_hashes:
            raise ValueError("Controller or runtime changed")
        for folder in ("home", "tmp"):
            (work / folder).mkdir()
        environment = {"HOME": str(work / "home"), "TMPDIR": str(work / "tmp"),
                       "LANG": "C", "LC_ALL": "C", "TZ": "UTC",
                       "BYOND_SYSTEM": str(binary.parent), "LD_LIBRARY_PATH": str(binary)}
        role = "compile" if family == "compiler" else "daemon"
        dump(work / (role + "-start.json"), {"command": command, "limits": profile,
             "wall_seconds": remaining, "head": HEAD, "tree": TREE, "mode": mode})

        def started(pid, identity):
            phase.update(started=True, pid=pid, initial_identity=identity)
            summary[family + "_started"] = True
            summary["native_executed"] = True
            dump(work / (role + "-started.json"), {"pid": pid, "identity": identity,
                 "head": HEAD, "tree": TREE, "mode": mode, "command": command})
            dump(output / "result.json", summary)

        try:
            if family == "compiler":
                callback = lambda pid, identity, observed: compile_inventory(work)
            # Hashing and other preflight IO consumed part of the aggregate budget.
            remaining = min(wall, deadline - time.monotonic() - 8)
            if remaining <= 0:
                raise ValueError("Aggregate ten-minute deadline exhausted before spawn")
            dump(work / (role + "-start.json"), {"command": command, "limits": profile,
                 "wall_seconds": remaining, "head": HEAD, "tree": TREE, "mode": mode})
            process = run_bounded(command, work, work / (role + ".log"), remaining,
                                  LOG_LIMIT, environment, profile, callback, started)
        except BaseException as error:
            phase["error"] = str(error)
            if isinstance(error, BoundedProcessError):
                process = dict(error.receipt)
                if process.get("process_started") is True:
                    phase.update(started=True, pid=process.get("pid"))
                    summary[family + "_started"] = True
                    summary["native_executed"] = True
                phase.update(terminated=process.get("termination_observed") is True,
                             exit_code=process.get("exit_code"),
                             cleanup_verified=process.get("cleanup_verified") is True,
                             owned_identity=process.get("owned_leader_identity"))
                process.update(error=str(error), phase=dict(phase))
            else:
                process = {"error": str(error), "cleanup_verified": False,
                           "phase": dict(phase)}
            # Preserve final cleanup observations even though the phase failed.
            # This never increments completed counts or permits later phases.
            dump(work / (role + "-process.json"), process)
            dump(output / "result.json", summary)
            raise
        phase.update(terminated=True, exit_code=process["exit_code"],
                     cleanup_verified=process.get("cleanup_verified") is True,
                     owned_identity=process.get("owned_leader_identity"))
        dump(work / (role + "-process.json"), process)
        dump(output / "result.json", summary)
        if family == "compiler":
            compile_inventory(work)
        if (process.get("cleanup_verified") is not True or
                process["exit_code"] != 0 or process["stop_reason"] or process["log_truncated"] or
                not process["cleanup_no_observed_live_descendants"] or
                not process["cleanup_process_group_absent"] or not process["owned_child_listing_available"]):
            raise ValueError("Process or cleanup failed: " + mode + "/" + role)
        if time.monotonic() > deadline:
            raise ValueError("Aggregate ten-minute deadline exceeded during cleanup")
        phase["completed"] = True
        summary[family + "_completed_phases"] += 1
        summary[family + "_completed"] = summary[family + "_completed_phases"] == len(MODES)
        dump(output / "result.json", summary)
        return read(work / (role + ".log"))

    for mode in MODES:
        root = output / "cases" / mode / "source"
        compile_log = execute([str(binary / "DreamMaker"), "-max_errors", "0", "snow-native.dme"],
                              root, "compiler", mode, COMPILE, 180)
        if ("DM compiler version 516.1688" not in compile_log or not re.search(r"(?<!\d)0 errors, 0 warnings(?!\d)", compile_log)
                or re.search(r"\berror:|\bwarning:|invalid file", compile_log, re.I)):
            raise ValueError("Exact-version clean native compile required")
        compiled = {}
        for name in ("snow-native.dmb", "snow-native.rsc"):
            path = root / name
            if path.is_symlink() or not path.is_file() or path.stat().st_size > 32 * 1024**2:
                raise ValueError("Invalid compiled fixture")
            compiled[name] = digest(path.read_bytes())
        dump(output / "cases" / mode / "compiled.json", compiled)
        work = output / "cases" / mode / "run"
        work.mkdir()
        for name, expected in compiled.items():
            data = (root / name).read_bytes()
            if digest(data) != expected:
                raise ValueError("Compiled fixture changed during copy")
            (work / name).write_bytes(data)
        dump(work / "input-hashes.json", compiled)
        sample, closure = listener_ack(work, mode)
        daemon_log = execute([str(binary / "DreamDaemon"), "snow-native.dmb", "-ip", "127.0.0.1",
                              "-invisible", "-close", "-trusted", "-nowebclient", "-log", "runtime.log"],
                             work, "daemon", mode, RUNTIME, 30, sample)
        runtime_inventory(work)
        if not closure["acknowledged"]:
            raise ValueError("Missing owned-listener acknowledgement")
        for name, expected in compiled.items():
            if digest((work / name).read_bytes()) != expected:
                raise ValueError("Runtime changed compiled fixture")
        result = json.loads(read(work / "snow-native-result.json"))
        runtime = read(work / "runtime.log")
        verdict = verify_result(mode, result, runtime)
        verify_auxiliary({"runtime.log": runtime, "daemon.log": daemon_log})
        results[mode] = {"verdict": verdict, "result": result}
        dump(output / "mode-results.json", results)
        dump(work / "output-hashes.json", {p.name: digest(p.read_bytes()) for p in work.iterdir()
             if p.is_file() and p.name not in compiled})
    verify_fixture(output, receipt)
    return results


def initial_summary():
    return {"head": HEAD, "tree": TREE, "version": VERSION, "status": "prepared-only",
            "native_executed": False, "compiler_attempted": False, "compiler_started": False,
            "compiler_completed": False, "compiler_completed_phases": 0,
            "daemon_attempted": False, "daemon_started": False, "daemon_completed": False,
            "daemon_completed_phases": 0, "phases": []}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-export", action="store_true", help="Prepare-only exact-blob export input")
    parser.add_argument("--reviewed-native", action="store_true")
    parser.add_argument("--byond-bin", type=Path)
    parser.add_argument("--byond-archive", type=Path)
    args = parser.parse_args()
    if args.source_export and args.reviewed_native:
        parser.error("Source-export preparation cannot execute native processes")
    if args.reviewed_native and (sys.platform != "linux" or not args.byond_bin or not args.byond_archive):
        parser.error("Reviewed Linux runtime inputs required")
    receipt = build_fixture(args.source, args.output, require_git=not args.source_export)
    receipt["controller_sha256"] = controller_hashes()
    dump(args.output / "preparation.json", receipt)
    summary = initial_summary()
    dump(args.output / "result.json", summary)
    try:
        if args.reviewed_native:
            summary["status"] = "native-requested"
            dump(args.output / "result.json", summary)
            summary["modes"] = run_native(args.output.absolute(), receipt, args.byond_bin.absolute(),
                                           args.byond_archive.absolute(), summary)
            summary["status"] = "passed"
    except BaseException as error:
        summary.update(status="failed", error=str(error))
        raise
    finally:
        dump(args.output / "result.json", summary)


if __name__ == "__main__":
    main()
