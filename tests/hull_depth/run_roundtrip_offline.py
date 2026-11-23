"""Opt-in BYOND whole-world salvage probe; no socket may exist before startup.

Compile the fixture first with compile_roundtrip.py. Maintainer approval is
still required before using --run-native. No workflow automatically runs this.
"""
from argparse import ArgumentParser
from hashlib import sha256
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def checked_binary(value):
    path = value.resolve(strict=True)
    if not path.is_file() or not os.access(path, os.X_OK):
        raise ValueError(f"Not executable: {path}")
    return path


def run_checked(command, cwd, env, log, seconds=180):
    with log.open("x") as output:
        result = subprocess.run(command, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                                stdout=output, stderr=subprocess.STDOUT,
                                timeout=seconds, close_fds=True, check=False)
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}); see {log}")


def empty_runtime(home, byond_system):
    (home / "tmp").mkdir(parents=True)
    return {
        "PATH": "/usr/bin:/bin",
        "HOME": str(home),
        "XDG_CONFIG_HOME": str(home / "config"),
        "XDG_DATA_HOME": str(home / "data"),
        "TMPDIR": str(home / "tmp"),
        "BYOND_SYSTEM": str(byond_system),
        "PARENT_NET": os.readlink("/proc/self/ns/net"),
        "LANG": "C",
        "REQUEST_METHOD": "GET",
    }


def guarded(guard, args):
    return ["unshare", "--user", "--map-root-user", "--net", "--pid", "--fork",
            "--kill-child", "--mount-proc", str(guard), sys.executable,
            str(HERE / "prove_network_denial.py"), "--exec", *map(str, args)]


def fixture_bytes(compiled):
    receipt = json.loads((compiled / "receipt.json").read_text())
    if receipt.get("probe") != "roundtrip":
        raise ValueError("This runner accepts only the two-stage roundtrip fixture")
    pin = json.loads((ROOT / "tools/byond/version.json").read_text())["version"]
    if receipt["compiler"] != pin:
        raise ValueError("Fixture was not compiled with the repository pin")
    payload = {}
    for name in ("probe.dmb", "probe.rsc"):
        value = (compiled / name).read_bytes()
        if sha256(value).hexdigest() != receipt["artifacts_sha256"].get(name):
            raise ValueError(f"Fixture artifact does not match compile receipt: {name}")
        payload[name] = value
    return payload


def install_names(work):
    # Only the public, tracked character-name tables; never copy host config.
    tracked = subprocess.check_output(
        ["git", "-C", str(ROOT), "ls-files", "-z", "config/names/*.txt"])
    if not tracked:
        raise RuntimeError("Missing repository character-name tables")
    (work / "config/names").mkdir(parents=True)
    for name in tracked.decode().split("\0")[:-1]:
        source = ROOT / name
        if not name.startswith("config/names/") or source.is_symlink() or not source.is_file():
            raise ValueError(f"Unexpected tracked name table: {name}")
        shutil.copyfile(source, work / name)


def run(args):
    qemu, loader, daemon = map(checked_binary, (args.qemu, args.loader, args.daemon))
    libs = args.library_path.resolve(strict=True)
    if not libs.is_dir() or daemon.name != "DreamDaemon":
        raise ValueError("Expected the pinned DreamDaemon and its i386 library directory")
    payload = fixture_bytes(args.compiled.resolve(strict=True))
    output = args.output.resolve()
    output.mkdir()  # Deliberately refuse the live world or a previous evidence directory.
    guard, obj, guest = [output / name for name in ("deny_network", "guard_guest.o", "guard_guest")]
    subprocess.run(["cc", "-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror", "-O2",
                    str(HERE / "deny_network.c"), "-o", str(guard)],
                   cwd=output, check=True, timeout=30)
    subprocess.run(["as", "--32", str(HERE / "i386_guard_probe.s"), "-o", str(obj)],
                   cwd=output, check=True, timeout=30)
    subprocess.run(["ld", "-m", "elf_i386", str(obj), "-o", str(guest)],
                   cwd=output, check=True, timeout=30)
    byond_system = daemon.parent.parent
    run_checked(guarded(guard, [qemu, guest]), output,
                empty_runtime(output / "guard_home", byond_system),
                output / "guard-proof.log", seconds=30)
    modes = ("physical",) if args.physical_only else ("writer", "reader")
    for mode in modes:
        work = output / mode
        work.mkdir()
        install_names(work)
        for name, value in payload.items():
            (work / name).write_bytes(value)
        if mode == "reader":
            save = output / "writer" / "map_saves"
            if not save.is_dir() or any(p.is_symlink() for p in (save, *save.rglob("*"))):
                raise ValueError("Missing synthetic writer generation or unexpected symlink")
            shutil.copytree(save, work / "map_saves")
        env = empty_runtime(work / "home", byond_system)
        command = guarded(guard, [qemu, loader, "--library-path", f"{libs}:{daemon.parent}",
                                  daemon, "probe.dmb", "-cgi", "-invisible", "-trusted",
                                  "-params", f"salvage_mode={mode}", "-log", "world.log"])
        run_checked(command, work, env, work / "supervisor.log")
        result_path = work / "result.txt"
        if not result_path.is_file():
            raise RuntimeError(f"{mode}: confined daemon exited without a fixture receipt; see {work}")
        value = result_path.read_text().strip()
        if value != f"PASS: {mode}":
            raise RuntimeError(f"{mode}: {value}")
        log = (work / "world.log").read_text()
        if "runtime error" in log.lower() or "runtime_error" in log.lower():
            raise RuntimeError(f"{mode}: runtime error in {work / 'world.log'}")
        print(f"{value}; {sum(line.startswith('PASS: ') for line in log.splitlines())} assertions")
    outcome = "same-process physical salvage only" if args.physical_only else "two-process synthetic salvage round trip"
    (output / "result.txt").write_text(f"PASS: {outcome}\n")


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--run-native", action="store_true", required=True,
                        help="Maintainer approved the confined native fixture run")
    parser.add_argument("--physical-only", action="store_true", help="Exercise same-process sink/repair/refloat without save/load")
    for name in ("compiled", "output", "qemu", "loader", "daemon", "library-path"):
        parser.add_argument("--" + name, required=True, type=Path)
    run(parser.parse_args())
