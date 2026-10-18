"""Compile-only isolated bridge closure. Never launches DreamDaemon or a client.

The CLI is for the separately allocated CI compiler slot, not runtime activation.
Preparation copies only frozen tracked source/static assets, no server config.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile
import tempfile

from prepare_native import git, isolated_startup, selected_files


def compile_dme(source):
    # Compile the real module with feature macro but WITHOUT any wait marker.
    source = re.sub(r'^#include "[^"\n]+\.dmm"\s*$', "", source, flags=re.M)
    replacements = {"code\\world.dm": "compile_generated/world.dm",
                    "code\\controllers\\mc\\globals.dm": "compile_generated/globals.dm"}
    for old, new in replacements.items():
        if source.count(old) != 1:
            raise ValueError("compile include anchor drift")
        source = source.replace(old, new, 1)
    if "CIV13_GAMEPLAY_BRIDGE" in source or "code/modules/gameplay_bridge/bridge.dm" in source:
        raise ValueError("bridge unexpectedly activated")
    return ('#define CIV13_GAMEPLAY_BRIDGE\n' + source +
            '\n#include "code/modules/gameplay_bridge/bridge.dm"\n' +
            '#include "tests/gameplay_bridge/native/compile_probe.dm"\n')


def prepare(root, output, expected):
    root, output = Path(root).resolve(), Path(output).resolve()
    if not re.fullmatch(r"[0-9a-f]{40}", expected):
        raise ValueError("full expected commit required")
    if output.exists() or output == root or root in output.parents:
        raise ValueError("fresh output outside checkout required")
    if git(root, "rev-parse", "HEAD").decode().strip() != expected or git(root, "status", "--porcelain", "--untracked-files=no").strip():
        raise ValueError("exact clean frozen HEAD required")
    tracked = set(git(root, "ls-files", "-z").decode().split("\0")) - {""}
    selected = [p for p in selected_files(root, tracked)
                if not p.startswith("config/") and p != "rust_g.dll"]
    read = lambda p: git(root, "show", expected + ":" + p).decode("utf-8-sig").replace("\r\n", "\n")
    helper = read("code/_helpers/mobs.dm")
    if "CIV13_GAMEPLAY_WAIT_GUARDS" in helper:
        raise ValueError("compile-only no-hook premise changed; review fixture")
    world, globals_source = isolated_startup(read("code/world.dm"), read("code/controllers/mc/globals.dm"))
    dme = compile_dme(read("civ13.dme"))
    # Compress archive arguments without admitting runtime config or private files.
    prefixes = ["code/", "icons/", "sound/", "UI/", "interface/", "scripts/gameplay_bridge/", "tests/gameplay_bridge/native/"]
    archive_paths = [p.rstrip("/") for p in prefixes if any(f.startswith(p) for f in selected)]
    archive_paths += [p for p in selected if not p.startswith(tuple(prefixes))]
    archive = git(root, "archive", "--format=tar", expected, "--", *archive_paths)
    source_root = output / "source"
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:") as tar:
        for member in tar:
            rel = PurePosixPath(member.name)
            if rel.is_absolute() or ".." in rel.parts or not (member.isfile() or member.isdir()):
                raise ValueError("unsafe archive entry")
            if member.isfile() and rel.as_posix() not in selected:
                raise ValueError("unselected archive file")
    # Validate the entire archive before creating output.
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:") as tar:
        for member in tar:
            if member.isfile():
                target = source_root.joinpath(*PurePosixPath(member.name).parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(tar.extractfile(member).read())
    generated = source_root / "compile_generated"
    generated.mkdir()
    for name, text in (("world.dm", world), ("globals.dm", globals_source)):
        (generated / name).write_text(text, encoding="utf-8", newline="\n")
    (source_root / "bridge_compile.dme").write_text(dme, encoding="utf-8", newline="\n")
    manifest = {"commit": expected, "compile_only": True, "native_runtime": "not_run",
                "wait_marker": False, "dimensions": [1, 1, 1],
                "sha256": {p.relative_to(source_root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                           for p in sorted(source_root.rglob("*")) if p.is_file()}}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return source_root


def verify_log(text, returncode):
    if returncode != 0 or not re.search(r"compiler version\s+516\.1681\b", text):
        raise ValueError("wrong compiler or compilation failed")
    if not re.search(r"\b0 errors,\s*0 warnings\b", text):
        raise ValueError("compiler errors/warnings or incomplete log")


def run(root, output, expected, byond_bin):
    source = prepare(root, output, expected)
    byond_bin = Path(byond_bin).resolve()
    candidates = [byond_bin / "DreamMaker", byond_bin / "dm.exe"]
    compiler = next((p for p in candidates if p.is_file()), None)
    if compiler is None:
        raise ValueError("pinned compiler executable missing")
    log = Path(output) / "compiler.log"
    with log.open("wb") as stream:
        result = subprocess.run([str(compiler), "-max_errors", "0", "bridge_compile.dme"],
                                cwd=source, stdout=stream, stderr=subprocess.STDOUT, timeout=180)
    if log.stat().st_size > 2097152:
        raise ValueError("compiler log exceeded review bound")
    verify_log(log.read_text(encoding="utf-8", errors="replace"), result.returncode)
    return {"commit": expected, "compile": "passed", "byond": "516.1681",
            "errors": 0, "warnings": 0, "runtime": "not_run"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--byond-bin", type=Path, required=True)
    parser.add_argument("--expected-commit", required=True)
    parser.add_argument("--evidence-dir", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    if args.evidence_dir:
        result = run(root, args.evidence_dir, args.expected_commit, args.byond_bin)
    else:
        with tempfile.TemporaryDirectory(prefix="civ13-bridge-compile-") as temp:
            result = run(root, Path(temp) / "packet", args.expected_commit, args.byond_bin)
    print(json.dumps(result))


if __name__ == "__main__":
    main()
